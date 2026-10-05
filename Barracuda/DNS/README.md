# Zewnętrzne listy blokowania DNS w Barracuda CGF

`dns.black.list.sh` rozwija podejście opisane w [Barracuda Best Practice: Integrate External DNS Block Lists with the CloudGen Firewall](https://documentation.campus.barracuda.com/wiki/spaces/CGFv105/pages/379094215/Best+Practice+-+How+to+Integrate+External+DNS+Block+Lists+with+the+CloudGen+Firewall). Zamiast korzystać wyłącznie z lokalnego pliku listy, skrypt pobiera listy domen z zewnętrznych źródeł, scala je i aktualizuje niestandardową strefę RPZ używaną przez usługę Caching DNS na CGF.

Po zastosowaniu strefy Caching DNS zwraca `NXDOMAIN` dla domen z listy. To rozwiązanie wpływa na odpowiedzi DNS klientów korzystających z tej usługi, więc przed wdrożeniem należy sprawdzić zawartość źródeł oraz skutki blokowania.

## Źródła list

Domyślnie skrypt pobiera:

- [CERT Polska: lista domen](https://hole.cert.pl/domains/v2/domains.txt) w formacie tekstowym z domenami.
- [StevenBlack/hosts](https://github.com/StevenBlack/hosts), z którego wybiera drugą kolumnę wierszy zaczynających się od adresu IPv4.

Adresy źródeł są zdefiniowane w tablicy `DNSBL_URLS` na początku skryptu. Można ją dostosować do własnych, zaufanych źródeł. Każde źródło musi być zgodne z oczekiwanym formatem albo wymagać osobnego parsera.

## Działanie

1. Pobiera każdą listę przez HTTPS i zapisuje połączone domeny w pliku wejściowym.
2. Dla listy StevenBlack/hosts wyodrębnia domenę z wierszy mapujących nazwę na IPv4; pozostałe źródło traktuje jako listę domen.
3. Oblicza SHA-256 połączonego pliku. Jeśli jego zawartość nie zmieniła się od poprzedniego uruchomienia, kończy pracę bez aktualizacji strefy.
4. Wstawia bieżący czas Unix jako numer seryjny SOA do szablonu RPZ i dodaje dla każdej domeny rekord `CNAME .`.
5. Zastępuje plik strefy, ponownie ustawia na nim atrybut immutable i uruchamia `/sbin/rndc reload`.

## Wymagania i wdrożenie

- Barracuda CloudGen Firewall z usługą Caching DNS skonfigurowaną zgodnie z dokumentacją Barracudy dla używanej wersji systemu.
- Uruchamianie na firewallu z uprawnieniami pozwalającymi zapisywać pliki systemowe, używać `chattr` oraz wykonać `rndc reload`.
- Bash, `curl`, `grep`, `awk`, `sha256sum`, `sed`, `date`, `touch`, `cat`, `mv` i `chattr` dostępne w środowisku.
- Dostęp sieciowy firewalla do wszystkich skonfigurowanych źródeł HTTPS.

Ścieżki pliku wejściowego, szablonu strefy, plików tymczasowych i aktywnej strefy są obecnie wpisane na stałe w skrypcie. Przed uruchomieniem sprawdź je i dostosuj do wersji CGF oraz konfiguracji urządzenia. Skrypt powinien być przechowywany w wydzielonym katalogu skryptów na firewallu i uruchamiany cyklicznie, na przykład przez cron skonfigurowany zgodnie z dokumentacją Barracudy.

## Bezpieczeństwo i obsługa

- Lista może zawierać błędne wpisy lub domeny powodujące fałszywe trafienia. Zweryfikuj źródła, ich licencje i wpływ na użytkowników przed wdrożeniem; monitoruj zmiany list.
- Każdy wpis trafia do strefy RPZ jako `CNAME .`, więc będzie blokowany przez Caching DNS. Nie uruchamiaj skryptu z niezweryfikowanym lub niezgodnym formatem źródła.
- Skrypt modyfikuje aktywny plik strefy oraz wykonuje przeładowanie DNS. Przetestuj procedurę na środowisku nieprodukcyjnym i przygotuj sposób przywrócenia poprzedniej strefy.
- Przechowywany w `/tmp/dnsbl-zone.timestamp` stan jest skrótem SHA-256 poprzednio pobranej listy, a nie czasem jej pobrania.
- W razie problemów sprawdź kod wyjścia skryptu, dostępność źródeł, plik szablonu, uprawnienia do ścieżek CGF oraz wynik polecenia `rndc reload`.

## Możliwe ulepszenia

Przed użyciem produkcyjnym warto rozważyć walidację i deduplikację nazw domen, pobieranie przez `curl --fail` z limitami czasu, bezpieczne przerwanie pracy przy błędzie któregokolwiek źródła oraz zapis skrótu dopiero po poprawnym przeładowaniu strefy. Obecna wersja nie wykonuje tych kontroli.
