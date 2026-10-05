# Obsługa zdarzeń Barracuda CGF

Skrypty z tego katalogu pomagają przekazać kontekst zdarzenia generowanego przez Barracuda CloudGen Firewall (CGF) do dalszej analizy lub automatyzacji. Można je skonfigurować jako akcję **Execute Program** w ustawieniach powiadomień CGF. Dokładne nazwy i dostępność pól zdarzenia zależą od konfiguracji i wersji CGF.

## Skrypty

| Plik | Przeznaczenie |
| --- | --- |
| `dump_event.py` | Wersja dla Python 2.7: zapisuje zmienne środowiskowe procesu do JSON na standardowe wyjście i do `/tmp/barracuda_event_dump.json`. |
| `dump_cgf_event_environment_to_json.p3.py` | Wersja dla Python 3, z takim samym działaniem jak `dump_event.py`. |
| `event.py` | Wersja Python 3: wyciąga adres IPv4 z `EVENT_DATA` i może dodać go do skonfigurowanego obiektu sieciowego CGF przez REST API. |
| `add_event_ip_to_cgf_network_object.p3.py` | Wariant Python 3 skryptu `event.py`; nazwa opisuje jego efekt uboczny. |

Konfiguracja skryptów `event.py` i `add_event_ip_to_cgf_network_object.p3.py` znajduje się poza repozytorium, domyślnie w `/etc/barracuda-event-forwarder.json`. Przykładowy format jest w [`event-forwarder.json.example`](event-forwarder.json.example). Można wskazać inną lokalizację zmienną `BARRACUDA_CONFIG`.

Utwórz prywatny plik konfiguracyjny na firewallu, ustaw właściwe obiekty, poświadczenia i adres API, a następnie ogranicz jego uprawnienia:

```bash
sudo install -o root -g root -m 600 event-forwarder.json.example /etc/barracuda-event-forwarder.json
sudoedit /etc/barracuda-event-forwarder.json
```

Plik JSON musi zawierać pola pokazane w przykładzie. Nie kopiuj prawdziwych poświadczeń do repozytorium. Plik `event-forwarder.json` jest ignorowany przez Git.

### Zrzut zdarzenia

`dump_event.py` i `dump_cgf_event_environment_to_json.p3.py` odczytują środowisko procesu uruchomionego przez CGF i serializują je do JSON. Ułatwia to sprawdzenie, jakie dane CGF przekazuje skryptowi, oraz zbudowanie dalszego przetwarzania na podstawie dostępnych pól.

W konfiguracji powiadomień CGF włącz **Execute Program** i wskaż pełną ścieżkę do wybranego skryptu. Przykładowy sposób testowania:

```bash
python3 /ścieżka/do/dump_cgf_event_environment_to_json.p3.py
```

Uruchomienie ręczne nie odtworzy zmiennych środowiskowych przekazywanych przez CGF. Plik `/tmp/barracuda_event_dump.json` jest nadpisywany przy każdym uruchomieniu i znajduje się w katalogu tymczasowym.

Zrzut obejmuje **całe środowisko procesu**, a nie tylko pola zdarzenia. Może zawierać dane wrażliwe. Używaj go do diagnostyki w kontrolowanym środowisku, ogranicz dostęp do pliku wynikowego i usuń go po zakończeniu analizy.

### Reakcja na adres IP ze zdarzenia

`event.py` i `add_event_ip_to_cgf_network_object.p3.py` realizują bardziej konkretny scenariusz automatyzacji:

1. Odczytują `EVENT_DATA`, `EVENT_TYPE_ID` i `EVENT_TYPE_NAME` z otoczenia procesu.
2. Szukają w `EVENT_DATA` adresu IPv4 zapisanego w nawiasach. Jeśli nie znajdą pasującego adresu, kończą bez zmiany konfiguracji.
3. Pobierają przez REST API wpisy z obiektu wykluczeń i pomijają IP, które pasuje do wpisu adresowego lub zakresu CIDR.
4. Sprawdzają, czy dokładny adres IP już istnieje w obiekcie docelowym.
5. Jeśli adres nie jest wykluczony ani już obecny, wysyłają go do obiektu docelowego jako wpis z komentarzem ustawionym na nazwę typu zdarzenia.

Ten skrypt nie przekazuje pełnego zdarzenia do kolejnego systemu ani nie wysyła go do webhooka. Jego dalszym skutkiem jest zmiana obiektu sieciowego CGF, który można wykorzystać w regułach lub innych scenariuszach. Nazwy obiektów, adres API i sposób uwierzytelniania wymagają konfiguracji dla konkretnej instalacji.

Nazwy obiektu docelowego i obiektu wykluczeń ustawia się w pliku JSON. Wartości `API-TEST` i `API-ADMIN` w pliku przykładowym są nazwami obiektów testowych, a nie wymaganymi nazwami CGF; zastąp je nazwami odpowiednich obiektów ze swojej konfiguracji.

## Bezpieczeństwo i stan przed użyciem

- Token API i nagłówek Basic Auth należy przechowywać wyłącznie w pliku konfiguracyjnym poza repozytorium, z uprawnieniami ograniczonymi do konta uruchamiającego skrypt. Jeśli wcześniejsze poświadczenia z kodu są prawdziwe lub były używane, unieważnij je i wygeneruj nowe.
- Skrypt obsługuje weryfikację HTTPS przez niezaufany kontekst TLS, a konfiguracja przykładowa używa HTTP. Przed użyciem produkcyjnym skonfiguruj HTTPS z weryfikacją certyfikatu i ogranicz uprawnienia API do niezbędnego minimum.
- Tryb debugowania jest włączony. Logi mogą zawierać treść zdarzeń, adresy IP i dane pobrane z obiektów CGF; chroń je zgodnie z polityką firmy.
- Błąd pobierania obiektu wykluczeń jest logowany, ale skrypt zwraca pustą listę. W rezultacie dalsze sprawdzanie i dodanie IP może być kontynuowane bez potwierdzenia whitelisty. Zweryfikuj to zachowanie przed użyciem w automatycznej blokadzie.
- Przed uruchomieniem ustaw poprawne obiekty docelowy i wykluczeń, sprawdź format `EVENT_DATA` dla wybranych typów zdarzeń oraz przetestuj skrypt na nieprodukcyjnej konfiguracji CGF.
