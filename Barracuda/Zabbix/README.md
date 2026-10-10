# Monitoring Barracuda CGF w Zabbix

`Template Barracuda NG Firewall API.json` to eksport template'u dla Zabbix 7.4. Zbiera dane z REST API Barracuda CloudGen Firewall (CGF) przy użyciu itemów HTTP agent, a odpowiedzi JSON przetwarza przez itemy zależne i reguły discovery. Template nie wymaga agenta Zabbix na firewallu.

## Zakres monitoringu

Template obejmuje 82 itemy, dwie reguły discovery i sześć wykresów. Monitoruje:

- **Dostępność i stan systemu:** odpowiedź API, stany serwera, procesów, dysku, systemu, sieci i licencji, uptime, hostname, model, wydanie, strefę czasową i liczbę użytkowników.
- **Zasoby:** liczbę rdzeni, obciążenie CPU, użycie i wolną pamięć oraz stan i wolne miejsce głównego systemu plików.
- **Usługi CGF i HA:** stany wybranych usług, pamięć RESTD oraz stan, rolę i aktywność węzłów HA.
- **Sieć:** ruch, pakiety, błędy, stan, prędkość, duplex i negocjację interfejsów. Interfejsy są wykrywane dynamicznie.
- **Firewall:** ruch i pakiety dla klas forward, local, loopback oraz pasm QoS 0–7.
- **VPN:** inwentaryzację tuneli site-to-site, ich stan i parametry, próbki zdrowia tuneli oraz 24-godzinne statystyki księgowe.
- **Sesje administracyjne:** liczbę aktywnych sesji zarządzania.

## Obsługiwane itemy

Poniżej znajduje się komplet 82 itemów zdefiniowanych bezpośrednio w template'cie. Itemy opisane jako `Raw` pobierają odpowiedź API; pozostałe przetwarzają tę odpowiedź lub obliczają wartości pochodne.

### Stan i informacje o urządzeniu

| Item | Klucz |
| --- | --- |
| Raw box status | `raw_cgf_box_status` |
| Box status serverState | `cgf_box_server_state` |
| Box status procState | `cgf_box_proc_state` |
| Box status diskState | `cgf_box_disk_state` |
| Box status systemState | `cgf_box_system_state` |
| Box status netState | `cgf_box_net_state` |
| Box status eventOperativeState | `cgf_box_event_operative_state` |
| Box status eventSecurityState | `cgf_box_event_security_state` |
| Box status licState | `cgf_box_lic_state` |
| Raw box info | `raw_cgf_box_info` |
| Host model | `cgf_box_model` |
| Host release | `cgf_box_release` |
| Host hostname | `cgf_box_hostname` |
| Host appliance | `cgf_box_appliance` |
| Host hypervisor | `cgf_box_hypervisor` |
| Host uptime seconds | `cgf_box_uptime` |
| Host timezone | `cgf_box_timezone` |
| Host users count | `cgf_box_users` |

### CPU i pamięć

| Item | Klucz |
| --- | --- |
| CPU cores | `cgf_box_cpu_cores` |
| CPU load average 1m | `cgf_box_cpu_load_1m` |
| CPU load average 5m | `cgf_box_cpu_load_5m` |
| CPU load average 15m | `cgf_box_cpu_load_15m` |
| Memory usage % | `cgf_box_memory_usage` |
| Memory used MB | `cgf_box_memory_used` |
| Memory free MB | `cgf_box_memory_free` |
| Memory total MB | `cgf_box_memory_total` |
| Raw CPU usage | `raw_cgf_cpu` |
| CPU Idle | `cgf.body.details.idle` |
| CPU iowait | `cgf.body.details.iowait` |
| CPU irq | `cgf.body.details.irq` |
| CPU nice | `cgf.body.details.nice` |
| CPU softirq | `cgf.body.details.softirq` |
| CPU system | `cgf.body.details.system` |
| CPU user | `cgf.body.details.user` |
| CPU usage % | `cgf_cpu_usage` |
| CPU usage avg 5 minut % | `cpu.usage.avg5m` |
| CPU usage avg 15 minut % | `cpu.usage.avg15m` |

### Dyski, usługi i HA

| Item | Klucz |
| --- | --- |
| Raw box disks | `raw_cgf_box_disks` |
| Root disk state | `cgf_disk_root_state` |
| Root disk free kB | `cgf_disk_root_free` |
| Raw box services | `raw_cgf_box_services` |
| Service RESTD state | `cgf_service_restd_state` |
| Service RESTD memory | `cgf_service_restd_memory` |
| Service control state | `cgf_service_control_state` |
| Service boxfw state | `cgf_service_boxfw_state` |
| Service bsnmp state | `cgf_service_bsnmp_state` |
| Raw HA info | `raw_cgf_ha_info` |
| HA box state | `cgf_ha_box_state` |
| HA primary active | `cgf_ha_primary_active` |
| HA secondary active | `cgf_ha_secondary_active` |
| HA status | `cgf_ha_status` |

### Firewall i sesje

| Item | Klucz |
| --- | --- |
| Raw firewall live statistics | `raw_cgf_fw_live` |
| Firewall Forwarded: bytes per second | `cgf_fw.traffic.forward.bps` |
| Firewall Forwarded: packets per second | `cgf_fw.traffic.forward.packets` |
| Firewall Local: bytes per second | `cgf_fw.traffic.local.bps` |
| Firewall Local: packets per second | `cgf_fw.traffic.local.packets` |
| Firewall Loopback: bytes per second | `cgf_fw.traffic.loopback.bps` |
| Firewall Loopback: packets per second | `cgf_fw.traffic.loopback.packets` |
| Raw active management sessions | `raw_cgf_box_sessions` |
| Active management sessions | `cgf_box_sessions_count` |

Pasma QoS mają itemy dla bajtów i pakietów na sekundę dla każdego pasma od 0 do 7. Klucze mają postać `cgf_fw.traffic.bandN.bps` oraz `cgf_fw.traffic.bandN.packets`, gdzie `N` to numer pasma.

### VPN

| Item | Klucz |
| --- | --- |
| Raw site-to-site VPN accounting (24h) | `raw_cgf_vpn_s2s_accounting` |
| Site-to-site VPN bytes in (24h) | `cgf_vpn.s2s.accounting.bytes_in_24h` |
| Site-to-site VPN bytes out (24h) | `cgf_vpn.s2s.accounting.bytes_out_24h` |
| Site-to-site VPN sessions (24h) | `cgf_vpn.s2s.accounting.sessions_24h` |
| Raw VPN tunnel inventory | `raw_cgf_vpn_tunnels` |

### Itemy tworzone przez discovery

Reguła **Network interface discovery** tworzy poniższe 10 itemów dla każdego wykrytego interfejsu. W kluczach `{#IFNAME}` jest zastępowane nazwą interfejsu:

| Item | Klucz prototypu |
| --- | --- |
| Inbound bytes per second | `cgf_if.bytes_in["{#IFNAME}"]` |
| Outbound bytes per second | `cgf_if.bytes_out["{#IFNAME}"]` |
| Inbound packets per second | `cgf_if.packets_in["{#IFNAME}"]` |
| Outbound packets per second | `cgf_if.packets_out["{#IFNAME}"]` |
| Link state | `cgf_if.link["{#IFNAME}"]` |
| Errors per second | `cgf_if.errors["{#IFNAME}"]` |
| Link speed | `cgf_if.speed["{#IFNAME}"]` |
| Duplex mode | `cgf_if.duplex["{#IFNAME}"]` |
| Link negotiation | `cgf_if.negotiation["{#IFNAME}"]` |
| Interface type | `cgf_if.medium["{#IFNAME}"]` |

Reguła **Site-to-site VPN tunnel discovery** filtruje tunele przez makro `{$CGF.VPN.S2S.TYPE.MATCHES}` i tworzy poniższe 23 itemy dla każdego dopasowanego tunelu. `{#TUNNEL}` i `{#TUNNEL_NAME}` są zastępowane danymi tunelu:

| Item | Klucz prototypu |
| --- | --- |
| Status | `cgf_vpn.s2s.status["{#TUNNEL}"]` |
| Type | `cgf_vpn.s2s.type["{#TUNNEL}"]` |
| Local address | `cgf_vpn.s2s.local["{#TUNNEL}"]` |
| Peer address | `cgf_vpn.s2s.peer["{#TUNNEL}"]` |
| Transport | `cgf_vpn.s2s.transport["{#TUNNEL}"]` |
| Encryption | `cgf_vpn.s2s.encryption["{#TUNNEL}"]` |
| Authentication | `cgf_vpn.s2s.hashing["{#TUNNEL}"]` |
| Raw health samples | `raw_cgf_vpn_s2s_health["{#TUNNEL}"]` |
| Latency (API units) | `cgf_vpn.s2s.health.latency_raw["{#TUNNEL}"]` |
| Effective bandwidth local (API units) | `cgf_vpn.s2s.health.effective_bw_local_raw["{#TUNNEL}"]` |
| Effective bandwidth peer (API units) | `cgf_vpn.s2s.health.effective_bw_peer_raw["{#TUNNEL}"]` |
| Latest sample bytes local | `cgf_vpn.s2s.health.bytes_local["{#TUNNEL}"]` |
| Latest sample bytes local ND | `cgf_vpn.s2s.health.bytes_local_nd["{#TUNNEL}"]` |
| Latest sample packets local | `cgf_vpn.s2s.health.packets_local["{#TUNNEL}"]` |
| Latest sample packets local ND | `cgf_vpn.s2s.health.packets_local_nd["{#TUNNEL}"]` |
| Latest sample drops local | `cgf_vpn.s2s.health.drops_local["{#TUNNEL}"]` |
| Latest sample drops local ND | `cgf_vpn.s2s.health.drops_local_nd["{#TUNNEL}"]` |
| Latest sample bytes peer | `cgf_vpn.s2s.health.bytes_peer["{#TUNNEL}"]` |
| Latest sample bytes peer ND | `cgf_vpn.s2s.health.bytes_peer_nd["{#TUNNEL}"]` |
| Latest sample packets peer | `cgf_vpn.s2s.health.packets_peer["{#TUNNEL}"]` |
| Latest sample packets peer ND | `cgf_vpn.s2s.health.packets_peer_nd["{#TUNNEL}"]` |
| Latest sample drops peer | `cgf_vpn.s2s.health.drops_peer["{#TUNNEL}"]` |
| Latest sample drops peer ND | `cgf_vpn.s2s.health.drops_peer_nd["{#TUNNEL}"]` |

Discovery interfejsów dodaje ponadto trigger stanu łącza i wykres ruchu. Discovery tuneli dodaje trigger dostępności tunelu i wykres efektywnej przepustowości.

## Import i konfiguracja

1. Zaimportuj `Template Barracuda NG Firewall API.json` przez **Data collection → Templates → Import**. Przed wdrożeniem sprawdź uwagi w sekcji „Do sprawdzenia przed produkcją”.
2. Podłącz template do hosta reprezentującego firewall.
3. Ustaw makra hosta lub template'u:

| Makro | Wymaganie |
| --- | --- |
| `{$API_URL}` | Bazowy adres REST API, np. `https://firewall.example:8443`; bez końcowego ukośnika. Eksport podaje przykład HTTP, ale w produkcji używaj HTTPS z weryfikacją certyfikatu. |
| `{$API_AUTH}` | Token API przesyłany w nagłówku `X-API-Token`. Traktuj jako sekret i ogranicz jego widoczność w Zabbix. |
| `{$CGF.MEMORY.USAGE.MAX}` | Próg ostrzegawczy pamięci w procentach; domyślnie `90`. |
| `{$CGF.CPU.LOAD.PERCORE.MAX}` | Próg 5-minutowego load average na rdzeń; domyślnie `1.5`. |
| `{$CGF.DISK.ROOT.FREE.MIN}` | Próg wolnego miejsca `/` w KB; domyślnie `2048000`. |
| `{$CGF.VPN.S2S.TYPE.MATCHES}` | Wyrażenie regularne filtrujące typy tuneli site-to-site; domyślnie `(?i).*(site.*site\|s2s).*`. Dopasuj do wartości zwracanych przez własne API. |

Itemy HTTP odpytywane są bezpośrednio przez Zabbix server lub proxy obsługujący hosta. Z tego miejsca musi być osiągalny adres API, a certyfikat TLS firewalla musi być zaufany przez środowisko Zabbix. Szczegółowe uprawnienia tokenu i wymagane endpointy zweryfikuj dla używanej wersji CGF.

## Alarmy i wykresy

Template zawiera alarmy dla braku odpowiedzi API, nieprawidłowych stanów firewalla i licencji, wysokiego użycia pamięci lub CPU, niskiej ilości wolnego miejsca na `/`, niedostępnych wybranych usług, stanu interfejsu innego niż `up` oraz tunelu S2S innego niż `UP`. Alarmy usług RESTD, control, boxfw i bsnmp uwzględniają stan HA, aby oceniać usługi na aktywnym węźle.

Dostępne wykresy obejmują obciążenie CPU, użycie pamięci, wolne miejsce na `/`, ruch i pakiety firewalla według klasy oraz przepustowość pasm QoS. Reguły discovery tworzą elementy i wykresy ruchu dla interfejsów oraz elementy, alarm i wykres przepustowości dla wykrytych tuneli S2S.

## Do sprawdzenia przed produkcją

- **Jawny typ wartości CPU:** itemy `cgf_cpu_usage`, `cpu.usage.avg5m` i `cpu.usage.avg15m` nie mają w eksporcie pola `value_type`. Sprawdź import na docelowej wersji Zabbix i ustaw typ numeryczny zgodny z danymi, jeśli Zabbix go nie uzupełni.
- **Interpretacja metryk zdrowia VPN:** itemy nazwane `Latest sample` używają JSONPath z wildcardem `TunnelHealthSamples[*]` i funkcją `sum()`, natomiast opóźnienie używa `avg()`. Zweryfikuj na rzeczywistej odpowiedzi API, czy agregacja odpowiada oczekiwanemu zakresowi i jednostkom; opis eksportu wskazuje, że jednostka opóźnienia i efektywnej przepustowości nie jest określona w Swagger.
- **Dane opcjonalne QoS:** brak pasma QoS 0–7 jest zamieniany na `0`. Odróżnij brak pola od rzeczywistego zerowego ruchu podczas interpretacji wykresów.
- **Reset liczników interfejsów:** ruch, pakiety i błędy są przeliczane na sekundę z liczników przez `CHANGE_PER_SECOND`. Po restarcie urządzenia lub wyzerowaniu licznika sprawdź wartości początkowe i ewentualne skoki.
- **Filtr tuneli:** domyślne wyrażenie regularne opiera się na nazwie typu zwracanej przez API. Potwierdź, że obejmuje wszystkie właściwe tunele i nie włącza tuneli klienckich.
- **Wersja API i dane odpowiedzi:** ścieżki JSON, nazwy pól i endpointy pochodzą z założeń template'u. Potwierdź je na firewallu i wersji CGF używanych w danym wdrożeniu.

## Bezpieczeństwo

- Przechowuj token jako makro sekretne lub w odpowiednim vault Zabbix, ogranicz dostęp do konfiguracji hosta/template'u i nie zapisuj prawdziwych tokenów w repozytorium.
- Preferuj HTTPS z poprawnie zweryfikowanym certyfikatem. Nie wyłączaj weryfikacji TLS jako obejścia problemów z certyfikatem.
- Ogranicz token do wymaganych uprawnień odczytu i udostępnij API tylko z zaufanej sieci monitoringu.
- Surowe odpowiedzi API są przechowywane jako itemy typu LOG; część z nich ma `history: 0`, ale pozostałe nie. Przed wdrożeniem sprawdź retencję, dostęp do historii i ewentualną obecność danych wrażliwych w odpowiedziach.
- Przetestuj import, preprocessing, discovery i alarmy na urządzeniu testowym przed podłączeniem template'u do środowiska produkcyjnego.
