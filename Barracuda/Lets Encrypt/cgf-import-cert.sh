#!/usr/bin/env bash
# Import wildcard cert z Nginx Proxy Manager (Let's Encrypt) do magazynu certyfikatów Barracuda CGF.
# API: PUT /rest/config/v1/box/store/certificates/{name}  {"action":"import", certificates, key}
# Wymaga: curl, jq, openssl. Konfiguracja przez /root/.cgf-import.env lub zmienne środowiskowe.
set -uo pipefail

ENV_FILE="${ENV_FILE:-/root/.cgf-import.env}"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

CGF_HOST="${CGF_HOST:?Ustaw CGF_HOST (np. 10.0.0.1)}"
CGF_SCHEME="${CGF_SCHEME:-https}"
CGF_PORT="${CGF_PORT:-8443}"
CGF_TOKEN="${CGF_TOKEN:?Ustaw CGF_TOKEN (X-API-Token z CGF)}"
CGF_CERT_NAME="${CGF_CERT_NAME:-wildcard-fix-it}"      # nazwa w magazynie CGF (bez spacji/znaków specjalnych)
CGF_COMMENT="${CGF_COMMENT:-Imported from NPM - LetsEncrypt}"
CGF_INSECURE="${CGF_INSECURE:-1}"                      # 1 = curl -k (CGF zwykle ma self-signed na 8443); ustaw 0 + CGF_CACERT
CGF_CACERT="${CGF_CACERT:-}"
# CGF wymaga samopodpisanego root CA w łańcuchu (fullchain z LE go nie zawiera - ma tylko cross-signed).
ROOT_CA_DIR="${ROOT_CA_DIR:-/root/cgf-roots}"   # samopodpisane root CA (*.pem); wybierany automatycznie wg lancucha
ROOT_CA_FILE="${ROOT_CA_FILE:-}"                 # opcjonalnie wymus konkretny root

LIVE_DIR="${LIVE_DIR:-/data/compose/4/letsencrypt/live/npm-2}"
FULLCHAIN="$LIVE_DIR/fullchain.pem"
PRIVKEY="$LIVE_DIR/privkey.pem"
STATE_FILE="${STATE_FILE:-/var/lib/cgf-import-cert/${CGF_CERT_NAME}.sha256}"
# Weryfikacja po imporcie (i przy kazdym uruchomieniu): lista "host:port=sciezka-uslugi", spacja jako separator, np.
#   "ssl.fix-it.com.pl:443=service-container/VPN auth.fix-it.com.pl:443=service-container/NGFW"
# Skrypt pobiera cert serwowany przez host:port; jesli jego fingerprint != nowy cert -> restart uslugi
# (POST /rest/control/v1/<sciezka>/restart) i ponowne sprawdzenie. Puste = bez weryfikacji/restartu.
CGF_VERIFY="${CGF_VERIFY:-}"
CGF_VERIFY_GRACE="${CGF_VERIFY_GRACE:-30}"        # s czekania po imporcie, zanim uznamy ze usluga nie podmienila certa sama
CGF_VERIFY_WAIT="${CGF_VERIFY_WAIT:-90}"          # s czekania na nowy cert po restarcie
CGF_VERIFY_DRYRUN="${CGF_VERIFY_DRYRUN:-0}"       # 1 = tylko loguj "zrestartowalbym", bez POST restart
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

log() { echo "[$(date '+%F %T')] $*"; }
die() { log "BŁĄD: $*" >&2; exit 1; }

for b in curl jq openssl; do command -v "$b" >/dev/null || die "brak $b"; done
[ -r "$FULLCHAIN" ] && [ -r "$PRIVKEY" ] || die "brak plików $FULLCHAIN / $PRIVKEY"

# sprawdź, że klucz pasuje do certyfikatu
pub_cert=$(openssl x509 -in "$FULLCHAIN" -noout -pubkey | openssl sha256)
pub_key=$(openssl pkey -in "$PRIVKEY" -pubout | openssl sha256)
[ "$pub_cert" = "$pub_key" ] || die "klucz prywatny nie pasuje do certyfikatu"

CURL=(curl -sS --connect-timeout 10 --max-time 60 -H "X-API-Token: $CGF_TOKEN" -H "Content-Type: application/json")
if [ "$CGF_INSECURE" = "1" ]; then CURL+=(-k); elif [ -n "$CGF_CACERT" ]; then CURL+=(--cacert "$CGF_CACERT"); fi
BASE="$CGF_SCHEME://$CGF_HOST:$CGF_PORT/rest/config/v1/box/store/certificates"

# api <METHOD> <URL> [json-file]  -> ustawia $HTTP_CODE i $BODY
api() {
  local method="$1" url="$2" data="${3:-}" out
  local args=(-X "$method" -w $'\n%{http_code}' "$url")
  [ -n "$data" ] && args+=(--data-binary "@$data")
  out=$("${CURL[@]}" "${args[@]}") || die "połączenie z $CGF_HOST:$CGF_PORT nieudane"
  HTTP_CODE="${out##*$'\n'}"; BODY="${out%$'\n'*}"
}


served_fp() {  # served_fp host port -> SHA256 fingerprint certu serwowanego przez host:port (puste = brak polaczenia)
  echo | timeout 10 openssl s_client -connect "$1:$2" -servername "$1" 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2
}

# verify_services <grace_s>  -> 0 gdy wszystkie uslugi serwuja aktualny cert (po ewentualnym restarcie)
verify_services() {
  local grace="$1" rc=0 pair target svc host port t cur state CTRL
  [ -n "$CGF_VERIFY" ] || return 0
  CTRL="$CGF_SCHEME://$CGF_HOST:$CGF_PORT/rest/control/v1"
  for pair in $CGF_VERIFY; do
    target="${pair%%=*}"; svc="${pair#*=}"; host="${target%%:*}"; port="${target##*:}"
    [ "$port" = "$target" ] && port=443
    t=0; cur=""
    while :; do
      cur=$(served_fp "$host" "$port")
      if [ "$cur" = "$fp" ]; then log "OK: $host:$port serwuje aktualny certyfikat"; continue 2; fi
      [ "$t" -ge "$grace" ] && break
      sleep 5; t=$((t+5))
    done
    if [ -z "$cur" ]; then
      log "UWAGA: brak odpowiedzi TLS z $host:$port - nie restartuje $svc (nie moge potwierdzic niezgodnosci)" >&2; rc=1; continue
    fi
    log "UWAGA: $host:$port serwuje inny certyfikat ($cur) - restart $svc"
    if [ "$CGF_VERIFY_DRYRUN" = "1" ]; then log "DRYRUN: zrestartowalbym $svc"; continue; fi
    api POST "$CTRL/$svc/restart"
    case "$HTTP_CODE" in 2??) ;; *) log "BŁĄD: restart $svc: HTTP $HTTP_CODE: $BODY" >&2; rc=1; continue ;; esac
    t=0; state=""
    while [ "$t" -lt 120 ]; do   # czekaj az usluga wroci do "up"
      sleep 5; t=$((t+5))
      api GET "$CTRL/$svc"; state=$(echo "$BODY" | jq -r '.state // empty' 2>/dev/null)
      [ "$HTTP_CODE" = "200" ] && [ "$state" = "up" ] && break
    done
    [ "$state" = "up" ] || { log "UWAGA: $svc po restarcie w stanie '${state:-brak odpowiedzi}'" >&2; rc=1; }
    t=0
    while :; do   # czekaj az host:port zacznie serwowac nowy cert
      cur=$(served_fp "$host" "$port")
      [ "$cur" = "$fp" ] && { log "OK po restarcie: $host:$port serwuje aktualny certyfikat"; continue 2; }
      [ "$t" -ge "$CGF_VERIFY_WAIT" ] && break
      sleep 5; t=$((t+5))
    done
    log "BŁĄD: $host:$port nadal serwuje inny certyfikat po restarcie $svc (${cur:-brak odpowiedzi})" >&2; rc=1
  done
  return $rc
}

# nie importuj ponownie, jeśli nic się nie zmieniło
fp=$(openssl x509 -in "$FULLCHAIN" -noout -fingerprint -sha256 | cut -d= -f2)
if [ "$FORCE" != "1" ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$fp" ]; then
  log "Certyfikat bez zmian ($fp) - pomijam import."
  verify_services 0
  exit $?
fi

if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN: zaimportowałbym $FULLCHAIN do '$CGF_CERT_NAME' na $CGF_HOST ($fp)"
  exit 0
fi

TMP=$(mktemp); BUNDLE=$(mktemp); KEYFILE=$(mktemp); trap 'rm -f "$TMP" "$BUNDLE" "$KEYFILE"' EXIT
chmod 600 "$TMP" "$BUNDLE" "$KEYFILE"

# CGF oczekuje klucza w formacie tradycyjnym (BEGIN EC/RSA PRIVATE KEY), LE daje PKCS#8
openssl pkey -in "$PRIVKEY" -traditional -out "$KEYFILE" || die "konwersja klucza nieudana"

# Auto-wybor roota: pierwszy cert z lancucha, ktorego issuer jest samopodpisanym rootem z ROOT_CA_DIR
if [ -z "$ROOT_CA_FILE" ] && [ -d "$ROOT_CA_DIR" ]; then
  ADIR=$(mktemp -d)
  awk -v d="$ADIR" '/BEGIN CERTIFICATE/{n++} {print > (d "/a" n ".pem")}' "$FULLCHAIN"
  for f in $(ls "$ADIR"/a*.pem | sort -V); do
    iss=$(openssl x509 -in "$f" -noout -issuer | sed 's/^issuer=//')
    for r in "$ROOT_CA_DIR"/*.pem; do
      [ -r "$r" ] || continue
      [ "$(openssl x509 -in "$r" -noout -subject | sed 's/^subject=//')" = "$iss" ] \
        && [ "$(openssl x509 -in "$r" -noout -issuer | sed 's/^issuer=//')" = "$iss" ] && { ROOT_CA_FILE="$r"; break 2; }
    done
  done
  rm -rf "$ADIR"
  [ -n "$ROOT_CA_FILE" ] && log "Wybrany root CA: $ROOT_CA_FILE"
fi

# Paczka: certyfikaty z fullchain (bez cross-signowanej kopii roota) + samopodpisany root
if [ -n "$ROOT_CA_FILE" ] && [ -r "$ROOT_CA_FILE" ]; then
  root_subj=$(openssl x509 -in "$ROOT_CA_FILE" -noout -subject)
  [ "$root_subj" = "$(openssl x509 -in "$ROOT_CA_FILE" -noout -issuer | sed 's/^issuer/subject/')" ] \
    || die "$ROOT_CA_FILE nie jest samopodpisanym root CA"
  CDIR=$(mktemp -d); trap 'rm -rf "$CDIR"; rm -f "$TMP" "$BUNDLE" "$KEYFILE"' EXIT
  awk -v d="$CDIR" '/BEGIN CERTIFICATE/{n++} {print > (d "/c" n ".pem")}' "$FULLCHAIN"
  for f in "$CDIR"/c*.pem; do
    [ "$(openssl x509 -in "$f" -noout -subject)" = "$root_subj" ] || cat "$f" >> "$BUNDLE"
  done
  cat "$ROOT_CA_FILE" >> "$BUNDLE"
else
  log "UWAGA: nie znaleziono pasujacego roota w $ROOT_CA_DIR - importuje sam fullchain."
  cat "$FULLCHAIN" > "$BUNDLE"
fi
log "Paczka łańcucha: $(grep -c 'BEGIN CERT' "$BUNDLE") certyfikaty."

# 1. Czy wpis istnieje? Jeśli nie - utwórz placeholder (PUT import wymaga istniejącego obiektu).
api GET "$BASE/$CGF_CERT_NAME"
case "$HTTP_CODE" in
  200) log "Wpis '$CGF_CERT_NAME' istnieje - aktualizuję." ;;
  404|400)
    log "Wpis '$CGF_CERT_NAME' nie istnieje - tworzę placeholder."
    # placeholder musi mieć ten sam typ klucza co importowany (EC/RSA)
    pubtxt=$(openssl x509 -in "$FULLCHAIN" -noout -pubkey | openssl pkey -pubin -noout -text)
    if echo "$pubtxt" | grep -q 'ASN1 OID'; then
      curve=$(echo "$pubtxt" | sed -n 's/.*ASN1 OID: *//p')
      keyspec=$(jq -n --arg c "$curve" '{cryptosystem:"EC", curve:$c}')
    else
      bits=$(echo "$pubtxt" | sed -n 's/.*Public-Key: (\([0-9]*\) bit).*/\1/p')
      keyspec=$(jq -n --argjson b "${bits:-2048}" '{cryptosystem:"RSA", size:$b}')
    fi
    jq -n --arg n "$CGF_CERT_NAME" --arg c "$CGF_COMMENT" --argjson k "$keyspec" \
      '{name:$n, comment:$c, key:$k, certificate:{subject:{commonName:"placeholder"}}}' > "$TMP"
    api POST "$BASE" "$TMP"
    case "$HTTP_CODE" in 2??) ;; *) false;; esac || die "POST create: HTTP $HTTP_CODE: $BODY" ;;
  401|403) die "autoryzacja odrzucona (HTTP $HTTP_CODE) - sprawdź token / uprawnienia / ACL REST API" ;;
  *) die "GET: HTTP $HTTP_CODE: $BODY" ;;
esac

# 2. Import: CGF przyjmuje klucz tylko doklejony do pola "certificates" (osobne pole "key" -> blad ASN1 "too large")
cat "$BUNDLE" "$KEYFILE" > "$TMP.pem"
jq -n --rawfile c "$TMP.pem" --arg cm "$CGF_COMMENT" \
  '{action:"import", certificates:$c, comment:$cm}' > "$TMP"
rm -f "$TMP.pem"
api PUT "$BASE/$CGF_CERT_NAME" "$TMP"
case "$HTTP_CODE" in 2??) ;; *) false;; esac || die "PUT import: HTTP $HTTP_CODE: $BODY"

# 3. Weryfikacja
api GET "$BASE/$CGF_CERT_NAME"
[ "$HTTP_CODE" = "200" ] || die "weryfikacja GET: HTTP $HTTP_CODE"
log "Zaimportowano '$CGF_CERT_NAME'. Odpowiedź CGF:"
echo "$BODY" | jq -c '.' 2>/dev/null | cut -c1-400

mkdir -p "$(dirname "$STATE_FILE")" && echo "$fp" > "$STATE_FILE"

# 4. Weryfikacja uslug i ewentualny restart (CGF_VERIFY)
rc=0
verify_services "$CGF_VERIFY_GRACE" || rc=1
log "OK ($fp, ważny do: $(openssl x509 -in "$FULLCHAIN" -noout -enddate | cut -d= -f2))"
exit "$rc"
