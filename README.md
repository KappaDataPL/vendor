# KappaDataPL: skrypty i integracje

Repozytorium zawiera skrypty i przykłady integracji, które mogą być dostosowane do środowisk klientów. Każdy katalog opisuje przeznaczenie narzędzia, wymagania, konfigurację i sposób uruchomienia.

## Dostępne narzędzia

### Barracuda CloudGen Firewall

Skrypt w [`Barracuda/Lets Encrypt`](Barracuda/Lets%20Encrypt/) importuje do Barracuda CloudGen Firewall (CGF) certyfikat Let's Encrypt odnawiany przez Nginx Proxy Manager (NPM). Certyfikat używany w tej integracji musi być wystawiony z kluczem RSA. Opcjonalnie skrypt sprawdza certyfikat prezentowany przez wskazane usługi CGF i może zlecić ich restart, jeśli certyfikat nie został przeładowany.

Zobacz [instrukcję skryptu](Barracuda/Lets%20Encrypt/README.md) oraz [przykładową konfigurację](Barracuda/Lets%20Encrypt/.cgf-import.env.example).

## Bezpieczeństwo

- Przed użyciem sprawdź wymagania i skutki działania skryptu w docelowej wersji CGF.
- Nie umieszczaj w repozytorium tokenów, kluczy prywatnych, rzeczywistych certyfikatów, adresów usług ani konfiguracji konkretnej instalacji.
- Przechowuj konfigurację zawierającą token poza repozytorium i ogranicz jej uprawnienia do konta uruchamiającego skrypt.
- Testuj konfigurację w środowisku nieprodukcyjnym. Weryfikacja usług może wywołać ich restart.
