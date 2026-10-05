# Synchronizacja certyfikatów z Barracuda CGF

Skrypt `cgf-import-cert.sh` importuje przez REST API certyfikat TLS odnawiany przez Nginx Proxy Manager (NPM) oraz odpowiadający mu klucz prywatny do magazynu certyfikatów Barracuda CloudGen Firewall (CGF). Skrypt nie wystawia ani nie odnawia certyfikatu; odczytuje aktualne pliki `fullchain.pem` i `privkey.pem` z katalogu NPM wskazanego przez `LIVE_DIR`.

Certyfikat używany w tej integracji musi mieć klucz **RSA**. W NPM wybierz typ klucza RSA podczas wystawiania certyfikatu Let's Encrypt; domyślnie NPM może użyć ECDSA. Klucz RSA jest wymagany, aby certyfikat był dostępny do użycia w docelowych usługach CGF.

Opcjonalnie skrypt sprawdza certyfikat prezentowany przez skonfigurowane usługi CGF. Jeśli po imporcie usługa nadal prezentuje poprzedni certyfikat, może zlecić restart wskazanej usługi i ponowić weryfikację. Weryfikacja i restarty są wyłączone, gdy `CGF_VERIFY` jest puste.

## Wymagania

- Bash na systemie Linux.
- Certyfikat Let's Encrypt zarządzany przez NPM, wystawiony z kluczem RSA, oraz dostęp do jego plików `fullchain.pem` i `privkey.pem`.
- Łączność z REST API CGF i token z uprawnieniami wymaganymi do odczytu, tworzenia i importu wpisów certyfikatów. Do restartowania usług potrzebne są również odpowiednie uprawnienia kontrolne.
- Narzędzia `curl`, `jq`, `openssl` i `timeout`.
- Zaufany certyfikat CA dla HTTPS. Skrypt domyślnie weryfikuje certyfikat TLS (`CGF_INSECURE=0`); skonfiguruj `CGF_CACERT`, jeśli wymagany jest niestandardowy urząd CA. Nie używaj niezabezpieczonego połączenia HTTP w niezaufanej sieci.

## Przepływ działania

1. Odczytuje aktualny certyfikat i klucz z katalogu NPM wskazanego przez `LIVE_DIR`, a następnie sprawdza wymagane pliki i narzędzia.
2. Weryfikuje, czy klucz prywatny odpowiada certyfikatowi RSA, a następnie oblicza fingerprint SHA-256.
3. Pomija ponowny import, jeśli fingerprint nie zmienił się od poprzedniego uruchomienia, chyba że ustawiono `FORCE=1`.
4. Przygotowuje łańcuch certyfikatów i format klucza wymagany przez API CGF.
5. Sprawdza wpis w magazynie CGF, tworzy go w razie potrzeby i importuje certyfikat.
6. Odczytuje wpis ponownie, aby potwierdzić import, i zapisuje fingerprint jako lokalny stan.
7. Jeśli skonfigurowano `CGF_VERIFY`, porównuje fingerprint certyfikatu prezentowanego przez każdą wskazaną usługę. Restartuje usługę tylko wtedy, gdy może potwierdzić, że prezentuje ona inny certyfikat.

Kod wyjścia `0` oznacza powodzenie, a `1` błąd importu lub weryfikacji.

## Konfiguracja

Skopiuj `.cgf-import.env.example` do `/root/.cgf-import.env`, uzupełnij wartości dla własnego środowiska i ogranicz dostęp do pliku:

```bash
sudo install -o root -g root -m 600 .cgf-import.env.example /root/.cgf-import.env
sudoedit /root/.cgf-import.env
```

Skrypt wczytuje `/root/.cgf-import.env` domyślnie. Zmienną `ENV_FILE` można wskazać inny plik. Plik jest wczytywany jako kod powłoki, dlatego powinien być zapisywalny wyłącznie przez zaufanego administratora.

| Zmienna | Znaczenie |
| --- | --- |
| `CGF_HOST` | Nazwa hosta lub adres CGF; wymagana. |
| `CGF_TOKEN` | Token REST API przesyłany w nagłówku `X-API-Token`; wymagany. |
| `CGF_SCHEME` | `https` lub `http`; domyślnie `https`. |
| `CGF_PORT` | Port REST API; domyślnie `8443`. |
| `CGF_CERT_NAME` | Nazwa wpisu w magazynie certyfikatów; domyślnie `letsencrypt-certificate`. |
| `CGF_COMMENT` | Komentarz do wpisu certyfikatu. |
| `CGF_INSECURE` | `1` wyłącza weryfikację TLS przez `curl`; domyślnie `0`. |
| `CGF_CACERT` | Opcjonalna ścieżka do certyfikatu CA używana, gdy `CGF_INSECURE=0`. |
| `LIVE_DIR` | Katalog NPM zawierający aktualne `fullchain.pem` i `privkey.pem`; wymagany. |
| `ROOT_CA_DIR` | Katalog z zaufanymi, samopodpisanymi certyfikatami root CA; domyślnie `/root/cgf-roots`. |
| `ROOT_CA_FILE` | Opcjonalnie wskazuje konkretny root CA zamiast automatycznego wyboru. |
| `STATE_FILE` | Plik fingerprintu ostatnio zaimportowanego certyfikatu; domyślnie `/var/lib/cgf-import-cert/<nazwa>.sha256`. |
| `CGF_VERIFY` | Rozdzielana spacjami lista `host:port=ścieżka-usługi`; pusta wartość wyłącza weryfikację usług. Dla portu 443 można pominąć `:port`. |
| `CGF_VERIFY_GRACE` | Czas oczekiwania na automatyczne przeładowanie certyfikatu przed restartem; domyślnie 30 sekund. |
| `CGF_VERIFY_WAIT` | Czas oczekiwania na nowy certyfikat po restarcie; domyślnie 90 sekund. |
| `CGF_VERIFY_DRYRUN` | Ustaw `1`, aby nie wysyłać żądań restartu podczas weryfikacji usług. |
| `FORCE` | Ustaw `1`, aby wymusić import mimo niezmienionego fingerprintu. |
| `DRY_RUN` | Ustaw `1`, aby wyświetlić plan importu bez łączenia z CGF. |

Wartości z pliku konfiguracji są wczytywane przed uruchomieniem skryptu i mogą nadpisać wartości przekazane w środowisku. Do testów użyj osobnego pliku wskazanego przez `ENV_FILE`.

Jeśli dana wersja CGF wymaga samopodpisanego roota w imporcie, skopiuj wymagany certyfikat do `ROOT_CA_DIR`. Katalog `cgf-root/` zawiera publiczne certyfikaty root CA, a nie klucze prywatne; przed użyciem sprawdź aktualność certyfikatu i jego fingerprint w oficjalnym źródle wystawcy. Skrypt dobiera root na podstawie łańcucha certyfikatu. Bez pasującego roota użyje samego `fullchain.pem`, co może nie być akceptowane przez CGF.

## Uruchomienie

Uruchomienie z domyślną konfiguracją:

```bash
sudo /root/cgf-import-cert.sh
```

Wymuszenie importu lub podgląd planowanego importu:

```bash
sudo FORCE=1 /root/cgf-import-cert.sh
sudo DRY_RUN=1 /root/cgf-import-cert.sh
```

`DRY_RUN=1` kończy działanie przed połączeniem z CGF. `CGF_VERIFY_DRYRUN=1` pozwala wykonać weryfikację usług bez zlecania restartu.

## Harmonogram i logi

Skrypt nie instaluje harmonogramu ani nie konfiguruje systemu logowania. Można uruchamiać go ręcznie albo dodać do harmonogramu systemowego po przetestowaniu konfiguracji. Przykładowe wpisy cron i logi należy dostosować do dystrybucji, lokalizacji skryptu oraz polityki operacyjnej danego środowiska.

Skrypt wypisuje komunikaty na standardowe wyjście i błędy. Nie wysyła powiadomień. Zadbaj o monitorowanie kodu wyjścia i ochronę logów zgodnie z lokalnymi zasadami.

## Bezpieczeństwo i ograniczenia

- Klucz prywatny jest używany do importu do CGF i przechowywany tymczasowo w pliku z ograniczonymi uprawnieniami; pliki tymczasowe są usuwane po zakończeniu skryptu.
- Token API jest przekazywany przez HTTPS tylko wtedy, gdy skonfigurowano HTTPS. Użycie `CGF_INSECURE=1` pozwala na połączenie bez weryfikacji certyfikatu serwera i zwiększa ryzyko przechwycenia tokenu oraz klucza.
- NPM odpowiada za wystawienie i odnowienie certyfikatu. Skrypt oczekuje gotowych plików PEM i powinien być uruchamiany po odnowieniu; samo odnowienie w NPM nie uruchamia go automatycznie.
- Skrypt nie wymusza typu RSA w kodzie. Sprawdź typ klucza certyfikatu w NPM przed uruchomieniem; dla tej integracji certyfikaty ECDSA nie spełniają wymagań docelowych usług CGF.
- Nie każda konfiguracja usług automatycznie przeładowuje certyfikat po imporcie. Włącz `CGF_VERIFY` dopiero po sprawdzeniu identyfikatorów usług i skutków ich restartowania.
- Skrypt akceptuje odpowiedzi HTTP 2xx. Szczegóły obsługiwanych endpointów i formatów zależą od wersji API CGF.
- Nie uruchamiaj skryptu na produkcji przed weryfikacją uprawnień tokenu, łańcucha certyfikatów, nazw usług i zachowania restartów w swoim środowisku.

## Endpointy REST API

Skrypt korzysta z następujących endpointów CGF:

| Metoda | Ścieżka | Cel |
| --- | --- | --- |
| `GET` | `/rest/config/v1/box/store/certificates/{name}` | Sprawdzenie wpisu i odczyt po imporcie. |
| `POST` | `/rest/config/v1/box/store/certificates` | Utworzenie wpisu zastępczego, jeśli wpis nie istnieje. |
| `PUT` | `/rest/config/v1/box/store/certificates/{name}` | Import łańcucha certyfikatów i klucza. |
| `GET` | `/rest/control/v1/{service-path}` | Sprawdzenie stanu usługi po restarcie. |
| `POST` | `/rest/control/v1/{service-path}/restart` | Opcjonalny restart usługi po wykryciu niezgodnego certyfikatu. |

## Rozwiązywanie problemów

| Objaw | Co sprawdzić |
| --- | --- |
| Błąd połączenia | Adres i port CGF, dostępność REST API, DNS, trasę sieciową i zaporę. |
| HTTP 401 lub 403 | Ważność tokenu, jego zakres uprawnień i listę dozwolonych adresów klienta w CGF. |
| Brak plików certyfikatu | Czy `LIVE_DIR` wskazuje katalog z czytelnymi `fullchain.pem` i `privkey.pem`. |
| Klucz nie pasuje do certyfikatu | Czy oba pliki pochodzą z tego samego odnowienia. |
| Nieznany root CA lub odrzucony łańcuch | Czy katalog root CA zawiera właściwy, zaufany certyfikat. Weryfikuj jego źródło i fingerprint przed użyciem. |
| Wpis nie przyjmuje innego typu klucza | Sprawdź ograniczenia wersji CGF. Zmiana typu klucza może wymagać ręcznego odtworzenia wpisu. |
| Usługa nadal prezentuje stary certyfikat | Sprawdź `CGF_VERIFY`, ścieżkę usługi, dostępność TLS i uprawnienia tokenu do operacji kontrolnych. |
