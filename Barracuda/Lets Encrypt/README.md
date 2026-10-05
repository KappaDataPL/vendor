# Import wildcard z NPM do Barracuda CGF

Dokumentacja automatyzacji, która kopiuje certyfikat wildcard `*.fix-it.com.pl`
(Let's Encrypt, wystawiany przez Nginx Proxy Manager) do magazynu certyfikatów
Barracuda CloudGen Firewall (CGF) przez REST API i sprawdza, czy usługi CGF
serwują już nowy certyfikat.

Stan na: 2026-10-03.

## Spis treści

1. Architektura
2. Pliki i lokalizacje
3. Konfiguracja (`.env`)
4. Jak działa skrypt
5. Obsługa na co dzień
6. Cron i logi
7. Ważne ustalenia (dlaczego jest tak, a nie inaczej)
8. Rozwiązywanie problemów
9. Odtworzenie od zera
10. Bezpieczeństwo
11. API CGF używane przez skrypt

## 1. Architektura

```text
NPM (kontener nginx-app-1, host 192.168.101.65)
  └─ Let's Encrypt, DNS-01 przez Cloudflare, certyfikat RSA 2048 (lineage npm-3)
       │  pliki: /data/compose/4/letsencrypt/live/npm-3/{fullchain,privkey}.pem
       ▼
/root/cgf-import-cert.sh   (cron 4:15 codziennie)
       │  REST API (HTTP, X-API-Token)
       ▼
CGF 192.168.101.220:8080  →  magazyn certyfikatów, wpis "wildcard-fix-it"
       │  referencja z konfiguracji usług
       ▼
VPN  → ssl.fix-it.com.pl  (192.168.101.3, portal SSL VPN)
NGFW → auth.fix-it.com.pl (192.168.101.2)
```

Certyfikat musi mieć klucz **RSA**. Dropdown *Default Server Certificate* w usłudze
VPN CGF pokazuje wyłącznie wpisy z kluczem RSA, a NPM domyślnie wystawia EC P-384.
Dlatego w NPM istnieje osobny certyfikat RSA (`npm-3`). Stary certyfikat EC (`npm-2`)
nadal obsługuje hosty w NPM i nie jest importowany do CGF.

## 2. Pliki i lokalizacje

| Ścieżka | Rola |
| --- | --- |
| `/root/cgf-import-cert.sh` | Skrypt importu i weryfikacji |
| `/root/cgf-import-cert.sh.bak` | Kopia skryptu sprzed dodania weryfikacji URL |
| `/root/.cgf-import.env` | Konfiguracja i token API (uprawnienia 600) |
| `/root/cgf-roots/isrg-root-x1.pem` | Samopodpisany ISRG Root X1 (dla łańcucha RSA, `npm-3`) |
| `/root/cgf-roots/isrg-root-x2.pem` | Samopodpisany ISRG Root X2 (dla łańcucha EC, `npm-2`) |
| `/var/lib/cgf-import-cert/wildcard-fix-it.sha256` | Fingerprint ostatnio zaimportowanego certyfikatu |
| `/etc/cron.d/cgf-import-cert` | Harmonogram (codziennie 4:15) |
| `/etc/logrotate.d/cgf-import` | Rotacja logu (miesięcznie, 6 archiwów, kompresja) |
| `/var/log/cgf-import.log` | Log z crona (uprawnienia 600) |
| `/root/Barracuda CGF 10.5.1.swagger.json` | Specyfikacja API CGF 10.5.1 |
| `/data/compose/4/letsencrypt/live/npm-3/` | Aktualny certyfikat RSA z NPM (dowiązania do `archive/`) |

## 3. Konfiguracja (`.env`)

Plik `/root/.cgf-import.env` jest czytany przez skrypt (`source`). Przykład bez tokenu:

```bash
CGF_SCHEME=http
CGF_HOST=192.168.101.220
CGF_PORT=8080
CGF_TOKEN=<token X-API-Token>
CGF_CERT_NAME=wildcard-fix-it
LIVE_DIR=/data/compose/4/letsencrypt/live/npm-3
CGF_VERIFY="ssl.fix-it.com.pl:443=service-container/VPN auth.fix-it.com.pl:443=service-container/NGFW"
```

Wszystkie zmienne (wartości domyślne w nawiasach):

| Zmienna | Znaczenie |
| --- | --- |
| `CGF_HOST` | Adres CGF (wymagana) |
| `CGF_TOKEN` | Token REST API, nagłówek `X-API-Token` (wymagana) |
| `CGF_SCHEME` (`https`) | `http` lub `https` |
| `CGF_PORT` (`8443`) | Port REST API (tu `8080`) |
| `CGF_CERT_NAME` (`wildcard-fix-it`) | Nazwa wpisu w magazynie CGF |
| `CGF_COMMENT` | Komentarz wpisu |
| `CGF_INSECURE` (`1`) | `1` = `curl -k` (dotyczy tylko HTTPS) |
| `CGF_CACERT` | Plik CA do weryfikacji HTTPS, gdy `CGF_INSECURE=0` |
| `LIVE_DIR` (`.../live/npm-2`) | Katalog z `fullchain.pem` i `privkey.pem` |
| `ROOT_CA_DIR` (`/root/cgf-roots`) | Katalog z samopodpisanymi rootami |
| `ROOT_CA_FILE` | Wymusza konkretny root (pomija automat) |
| `STATE_FILE` | Plik z fingerprintem ostatniego importu |
| `CGF_VERIFY` | Lista `host:port=ścieżka-usługi` do weryfikacji i restartu (puste = wyłączone) |
| `CGF_VERIFY_GRACE` (`30`) | Sekundy czekania po imporcie, zanim uznamy, że usługa sama nie podmieniła certyfikatu |
| `CGF_VERIFY_WAIT` (`90`) | Sekundy czekania na nowy certyfikat po restarcie |
| `CGF_VERIFY_DRYRUN` (`0`) | `1` = tylko loguj niezgodność, bez restartu |
| `FORCE` (`0`) | `1` = importuj mimo braku zmiany fingerprintu |
| `DRY_RUN` (`0`) | `1` = pokaż co zostałoby zrobione, bez połączenia z CGF |
| `ENV_FILE` | Inny plik konfiguracji (uwaga: wartości z pliku nadpisują zmienne środowiskowe) |

Uwaga: zmienne ustawione w pliku `.env` mają pierwszeństwo przed tymi z linii poleceń.
Żeby nadpisać coś jednorazowo (np. `CGF_VERIFY` w teście), użyj `ENV_FILE` ze
skopiowanym `.env` bez danej zmiennej.

## 4. Jak działa skrypt

1. Sprawdza narzędzia (`curl`, `jq`, `openssl`) i obecność plików certyfikatu.
2. Sprawdza, czy klucz prywatny pasuje do certyfikatu.
3. Liczy fingerprint SHA-256 certyfikatu. Jeśli jest taki sam jak w pliku stanu
   (i `FORCE` nie jest ustawione), pomija import, ale **nadal wykonuje weryfikację
   usług** (krok 9). Dzięki temu nieudany restart z poprzedniej nocy zostanie ponowiony.
4. Konwertuje klucz z PKCS#8 (`BEGIN PRIVATE KEY`) do formatu tradycyjnego
   (`BEGIN EC/RSA PRIVATE KEY`).
5. Wybiera samopodpisany root z `ROOT_CA_DIR`: pierwszy certyfikat z łańcucha, którego
   issuer jest samopodpisanym rootem z tego katalogu.
6. Buduje paczkę: certyfikaty z `fullchain.pem` (bez cross-signowanej kopii roota)
   plus samopodpisany root.
7. `GET` wpisu w CGF. Jeśli nie istnieje (404), tworzy placeholder przez `POST`
   z kluczem tego samego typu co importowany (EC lub RSA).
8. `PUT` z `{"action":"import","certificates": paczka + klucz}`, potem `GET` jako
   weryfikacja i zapis fingerprintu do pliku stanu.
9. Weryfikacja usług (`CGF_VERIFY`): dla każdego `host:port` pobiera certyfikat
   serwowany przez TLS i porównuje fingerprint z nowym.
   - zgodny: `OK`,
   - inny: restart usługi (`POST .../restart`), czekanie na stan `up`, ponowne sprawdzenie,
   - brak odpowiedzi TLS: **bez restartu**, ostrzeżenie w logu i kod wyjścia 1.

Kod wyjścia: `0` = wszystko w porządku, `1` = błąd importu albo problem z weryfikacją.

## 5. Obsługa na co dzień

```bash
# Normalne uruchomienie (jak z crona)
/root/cgf-import-cert.sh

# Wymuś import mimo braku zmian
FORCE=1 /root/cgf-import-cert.sh

# Tylko sprawdź, co zostałoby zrobione (bez łączenia z CGF)
DRY_RUN=1 /root/cgf-import-cert.sh

# Log
tail -n 50 /var/log/cgf-import.log
```

Po ręcznym odnowieniu w NPM (*SSL Certificates → certyfikat RSA → Renew Now*)
wystarczy uruchomić skrypt albo poczekać na cron.

Sprawdzenie, co serwują usługi:

```bash
for h in ssl.fix-it.com.pl auth.fix-it.com.pl; do
  echo | openssl s_client -connect $h:443 -servername $h 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256
done
cat /var/lib/cgf-import-cert/wildcard-fix-it.sha256
```

## 6. Cron i logi

`/etc/cron.d/cgf-import-cert`:

```text
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
15 4 * * * root /root/cgf-import-cert.sh >> /var/log/cgf-import.log 2>&1
```

W dni bez zmian w logu pojawi się `Certyfikat bez zmian ... pomijam import` oraz
`OK: <host> serwuje aktualny certyfikat`. Skrypt nie wysyła alertów. Błędy trzeba
sprawdzać w logu (opcjonalnie można dodać `zabbix_sender`, bo na hoście działa
`zabbix-agent2`).

## 7. Ważne ustalenia

Rzeczy, które wyszły podczas wdrożenia i wyjaśniają obecną budowę skryptu:

- **Klucz musi być w polu `certificates`.** CGF zwraca błąd `asn1 encoding routines::too large`,
  gdy klucz jest w osobnym polu `key`. Działa dopiero PEM klucza doklejony do
  `certificates` (po certyfikatach).
- **CGF wymaga samopodpisanego roota w łańcuchu.** `fullchain.pem` z Let's Encrypt
  zawiera tylko cross-signowane certyfikaty i import kończy się błędem
  `root certificate not found`. Dlatego root jest dodawany z `/root/cgf-roots`
  (pobrany z <https://letsencrypt.org/certs/>, fingerprint zweryfikowany). Cross-signowana
  kopia roota jest pomijana.
- **Dropdown VPN pokazuje tylko klucze RSA.** Certyfikat EC (domyślny w NPM 2.16,
  `key_type = ecdsa`) nie jest widoczny w *Default Server Certificate*. Rozwiązanie:
  osobny certyfikat RSA w NPM (*Key Type: RSA 2048*).
- **Nie można zmienić typu klucza w istniejącym wpisie.** `PUT` zwraca `409`
  (`cannot replace key ... by a different key type`). Przy zmianie EC/RSA trzeba
  usunąć wpis (`DELETE`) i utworzyć go ponownie. Skrypt sam tworzy placeholder
  właściwego typu, jeśli wpisu nie ma.
- **Kody HTTP.** `POST` zwraca `201`, `PUT` i `DELETE` zwracają `204`. Skrypt akceptuje każde 2xx.
- **Nazwa wpisu.** Podkreślnik jest niedozwolony (`Certificate name contains invalid characters`),
  myślnik działa.
- **Automatyczna podmiana w usługach.** Usługi, które mają certyfikat wybrany z magazynu
  przez referencję, same przeładowały nowy certyfikat w ciągu kilkunastu sekund po
  imporcie (sprawdzone na odnowieniu 2026-10-03, restart nie był potrzebny).
  Restart w skrypcie jest tylko zabezpieczeniem. Gałąź restartu przetestowana wyłącznie
  w trybie `DRYRUN`.
- **Łańcuch Let's Encrypt się zmienia.** Pośrednie CA bywają różne (`YR1`, `YR2`, `YE1`),
  więc root wybierany jest automatycznie z katalogu. W razie nowego roota trzeba
  dodać jego samopodpisany plik `.pem` do `/root/cgf-roots`.

## 8. Rozwiązywanie problemów

| Objaw | Przyczyna / działanie |
| --- | --- |
| `połączenie z ... nieudane` | CGF niedostępny, zły port lub wyłączone REST API. Sprawdź `curl http://192.168.101.220:8080/rest/config/v1/box/store/certificates` z tokenem |
| `autoryzacja odrzucona (HTTP 401/403)` | Zły lub nieaktywny token, brak IP hosta w ACL REST API |
| `root certificate not found` | Brak samopodpisanego roota dla nowego łańcucha. Dodaj plik do `/root/cgf-roots` |
| `Import of key failed ... too large` | Klucz przekazany w polu `key`. Skrypt używa pola `certificates` |
| `cannot replace key ... by a different key type` | Zmiana EC/RSA. `DELETE` wpisu i ponowny import |
| `klucz prywatny nie pasuje do certyfikatu` | `LIVE_DIR` wskazuje niespójne pliki. Sprawdź `fullchain.pem` i `privkey.pem` |
| `brak odpowiedzi TLS z host:port` | Adres niedostępny z hosta NPM (sieć, DNS, firewall). Skrypt celowo nie restartuje usługi |
| `host:port serwuje inny certyfikat` | Usługa nie przeładowała certyfikatu albo używa innego wpisu. Skrypt restartuje usługę |
| Certyfikat nie widać w dropdownie CGF | Klucz EC (wymagany RSA) albo nieodświeżony Firewall Admin |

## 9. Odtworzenie od zera

1. W NPM utwórz certyfikat: *Add SSL Certificate → Let's Encrypt via DNS*,
   domena `*.fix-it.com.pl`, **Key Type: RSA 2048**, DNS Cloudflare (token z uprawnieniem
   Zone → DNS → Edit). Zanotuj nowy katalog `live/npm-N`.
2. W CGF włącz REST API, wygeneruj token i dopuść IP hosta z NPM w ACL.
3. Skopiuj skrypt, utwórz `/root/.cgf-import.env` (uprawnienia 600) według sekcji 3.
4. Pobierz samopodpisane rooty do `/root/cgf-roots` i sprawdź fingerprint:
   - ISRG Root X1: `96:BC:EC:06:26:49:76:F3:74:60:77:9A:CF:28:C5:A7:CF:E8:A3:C0:AA:E1:1A:8F:FC:EE:05:C0:BD:DF:08:C6`
   - ISRG Root X2: `69:72:9B:8E:15:A8:6E:FC:17:7A:57:AF:B7:17:1D:FC:64:AD:D2:8C:2F:CA:8C:F1:50:7E:34:45:3C:CB:14:70`
5. Uruchom `/root/cgf-import-cert.sh`. Wpis zostanie utworzony i zaimportowany.
6. W CGF wybierz wpis w *Default Server Certificate* usług (VPN, NGFW) i aktywuj konfigurację.
7. Dodaj cron i logrotate według sekcji 6.

## 10. Bezpieczeństwo

- Token API leży w `/root/.cgf-import.env` (600). Został wklejony w czacie podczas
  wdrożenia, więc **należy go wygenerować od nowa** i zaktualizować `.env`.
- API CGF działa po **HTTP** (`:8080`), więc token i klucz prywatny przechodzą po sieci
  jawnie. Zalecane przełączenie na HTTPS: `CGF_SCHEME=https`, `CGF_PORT=8443`,
  opcjonalnie `CGF_INSECURE=0` i `CGF_CACERT`.
- Klucz prywatny jest przetwarzany w plikach tymczasowych (`mktemp`, 600), usuwanych
  przy wyjściu ze skryptu.
- Token Cloudflare dla NPM jest zapisany przez NPM w bazie i w pliku
  `/data/compose/4/letsencrypt/credentials/`.

## 11. API CGF używane przez skrypt

Źródło: `Barracuda CGF 10.5.1.swagger.json`. Uwierzytelnianie: nagłówek `X-API-Token`.

| Metoda i ścieżka | Użycie |
| --- | --- |
| `GET /rest/config/v1/box/store/certificates/{name}` | Sprawdzenie, czy wpis istnieje, i weryfikacja po imporcie |
| `POST /rest/config/v1/box/store/certificates` | Utworzenie placeholdera (nazwa, komentarz, typ klucza) |
| `PUT /rest/config/v1/box/store/certificates/{name}` | Import: `{"action":"import","certificates":"<PEM>","comment":"..."}` |
| `DELETE /rest/config/v1/box/store/certificates/{name}` | Ręcznie, przy zmianie typu klucza |
| `GET /rest/control/v1/service-container/{VPN\|NGFW}` | Stan usługi (`up`) po restarcie |
| `POST /rest/control/v1/service-container/{VPN\|NGFW}/restart` | Restart usługi, tylko przy niezgodności certyfikatu |
