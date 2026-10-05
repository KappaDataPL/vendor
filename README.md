# KappaDataPL: skrypty i integracje

Repozytorium zawiera skrypty i przykłady integracji, które mogą być dostosowane do środowisk klientów. Każdy katalog opisuje przeznaczenie narzędzia, wymagania, konfigurację i sposób uruchomienia.

## Dostępne narzędzia

### Barracuda CloudGen Firewall

Skrypt w [`Barracuda/Lets Encrypt`](Barracuda/Lets%20Encrypt/) importuje do Barracuda CloudGen Firewall (CGF) certyfikat Let's Encrypt odnawiany przez Nginx Proxy Manager (NPM). Certyfikat używany w tej integracji musi być wystawiony z kluczem RSA. Opcjonalnie skrypt sprawdza certyfikat prezentowany przez wskazane usługi CGF i może zlecić ich restart, jeśli certyfikat nie został przeładowany.

Zobacz [instrukcję skryptu](Barracuda/Lets%20Encrypt/README.md) oraz [przykładową konfigurację](Barracuda/Lets%20Encrypt/.cgf-import.env.example).

#### Zewnętrzne listy DNS

Skrypt w [`Barracuda/DNS`](Barracuda/DNS/) pobiera i scala zewnętrzne listy domen, konwertuje je do strefy RPZ i przeładowuje usługę Caching DNS w Barracuda CGF po wykryciu zmian. Opis źródeł, działania i wymagań znajduje się w [README skryptu DNS](Barracuda/DNS/README.md).

#### Obsługa zdarzeń

Skrypty w [`Barracuda/Eventing`](Barracuda/Eventing/) pozwalają zrzucić zmienne środowiskowe przekazane przez zdarzenie CGF do JSON albo uruchomić reakcję na adres IP wyodrębniony ze zdarzenia. Szczegóły przepływu, konfiguracji i ograniczeń są w [README Eventing](Barracuda/Eventing/README.md).

## Bezpieczeństwo

- Przed użyciem sprawdź wymagania i skutki działania skryptu w docelowej wersji CGF.
- Nie umieszczaj w repozytorium tokenów, kluczy prywatnych, rzeczywistych certyfikatów, adresów usług ani konfiguracji konkretnej instalacji.
- Przechowuj konfigurację zawierającą token poza repozytorium i ogranicz jej uprawnienia do konta uruchamiającego skrypt.
- Testuj konfigurację w środowisku nieprodukcyjnym. Weryfikacja usług może wywołać ich restart.
