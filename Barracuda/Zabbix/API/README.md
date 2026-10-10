# Barracuda CGF API Monitoring in Zabbix

`Template Barracuda NG Firewall API.json` is a Zabbix 7.4 template export. It collects data from the Barracuda CloudGen Firewall (CGF) REST API using HTTP agent items, then processes JSON responses through dependent items and discovery rules. No Zabbix agent is required on the firewall.

## Zakres monitoringu

The template includes 82 static items, two discovery rules, and six graphs. It monitors:

- **Availability and system state:** API response, server, process, disk, system, network, and license states; uptime, hostname, model, release, timezone, and user count.
- **Resources:** CPU core count and load, memory usage and free memory, and root filesystem state and free space.
- **CGF services and HA:** selected service states, RESTD memory, and HA state, role, and node activity.
- **Networking:** interface traffic, packets, errors, link state, speed, duplex, and negotiation. Interfaces are discovered dynamically.
- **Firewall:** traffic and packet rates for forward, local, loopback, and QoS bands 0-7.
- **VPN:** site-to-site tunnel inventory, state and properties, tunnel health samples, and 24-hour accounting statistics.
- **Management sessions:** active management session count.

## Supported Items

The following is the full list of 82 items defined directly in the template. Items named `Raw` fetch API responses; the others process those responses or calculate derived values.

### Device State and Information

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

### CPU and Memory

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

### Disks, Services, and HA

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

QoS bands have byte-rate and packet-rate items for each band from 0 through 7. Their keys are `cgf_fw.traffic.bandN.bps` and `cgf_fw.traffic.bandN.packets`, where `N` is the band number.

### VPN

| Item | Klucz |
| --- | --- |
| Raw site-to-site VPN accounting (24h) | `raw_cgf_vpn_s2s_accounting` |
| Site-to-site VPN bytes in (24h) | `cgf_vpn.s2s.accounting.bytes_in_24h` |
| Site-to-site VPN bytes out (24h) | `cgf_vpn.s2s.accounting.bytes_out_24h` |
| Site-to-site VPN sessions (24h) | `cgf_vpn.s2s.accounting.sessions_24h` |
| Raw VPN tunnel inventory | `raw_cgf_vpn_tunnels` |

### Items Created by Discovery

The **Network interface discovery** rule creates the following 10 items for each discovered interface. `{#IFNAME}` is replaced by the interface name in the keys:

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

The **Site-to-site VPN tunnel discovery** rule filters tunnels using `{$CGF.VPN.S2S.TYPE.MATCHES}` and creates the following 23 items for each matching tunnel. `{#TUNNEL}` and `{#TUNNEL_NAME}` are replaced with tunnel values:

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

Interface discovery also adds a link-state trigger and traffic graph. Tunnel discovery adds a tunnel-availability trigger and effective-bandwidth graph.

## Import and Configuration

1. Import `Template Barracuda NG Firewall API.json` through **Data collection → Templates → Import**. Review [Pre-production Checks](#pre-production-checks) before deployment.
2. Link the template to a host representing the firewall.
3. Set the following host or template macros:

| Macro | Description |
| --- | --- |
| `{$API_URL}` | Base REST API URL, for example `https://firewall.example:8443`, without a trailing slash. The export's example uses HTTP; use HTTPS with certificate verification in production. |
| `{$API_AUTH}` | API token sent in the `X-API-Token` header. Treat it as a secret and restrict its visibility in Zabbix. |
| `{$CGF.MEMORY.USAGE.MAX}` | Memory warning threshold in percent; default `90`. |
| `{$CGF.CPU.LOAD.PERCORE.MAX}` | Five-minute load-average threshold per CPU core; default `1.5`. |
| `{$CGF.DISK.ROOT.FREE.MIN}` | Minimum free space on `/` in KB; default `2048000`. |
| `{$CGF.VPN.S2S.TYPE.MATCHES}` | Regular expression for site-to-site tunnel types; default `(?i).*(site.*site\|s2s).*`. Adapt it to values returned by your API. |

HTTP items are polled directly by the Zabbix server or proxy responsible for the host. The API must be reachable from that system, and the firewall's TLS certificate must be trusted by the Zabbix environment. Verify token permissions and required endpoints for the CGF version in use.

## Triggers and Graphs

The template has triggers for a missing API response, unhealthy firewall or license states, high memory or CPU usage, low free space on `/`, unavailable selected services, an interface link state other than `up`, and an S2S tunnel state other than `UP`. RESTD, control, boxfw, and bsnmp service triggers account for HA state when evaluating the active node.

Available graphs cover CPU load, memory usage, free space on `/`, firewall traffic and packet rate by class, and QoS-band throughput. Discovery creates interface items and traffic graphs, plus S2S tunnel items, an availability trigger, and an effective-bandwidth graph.

## Pre-production Checks

- **Explicit CPU value types:** `cgf_cpu_usage`, `cpu.usage.avg5m`, and `cpu.usage.avg15m` have no `value_type` field in the export. Test the import on the target Zabbix version and set a numeric type if Zabbix does not supply one.
- **VPN health metric interpretation:** items named `Latest sample` use JSONPath wildcards over `TunnelHealthSamples[*]` with `sum()`, while latency uses `avg()`. Check the actual API response to confirm the aggregation window and units. The export notes that Swagger does not specify units for latency or effective bandwidth.
- **Optional QoS data:** missing QoS bands 0-7 are converted to `0`. Distinguish an absent field from actual zero traffic when reading graphs.
- **Interface counter resets:** traffic, packet, and error counters are converted to per-second rates using `CHANGE_PER_SECOND`. Check initial values and possible spikes after a device restart or counter reset.
- **Tunnel filter:** the default regular expression relies on the tunnel type returned by the API. Confirm that it includes the intended site-to-site tunnels and excludes client tunnels.
- **API version and response data:** JSON paths, field names, and endpoints are assumptions in the template. Confirm them against the firewall and CGF version used in your deployment.

## Security

- Store the token as a secret macro or in an appropriate Zabbix vault, restrict access to host/template configuration, and do not commit real tokens.
- Prefer HTTPS with a properly verified certificate. Do not disable TLS verification to work around certificate problems.
- Restrict the token to required read permissions and expose the API only to trusted monitoring systems.
- Raw API responses are stored as LOG items; some have `history: 0`, while others do not. Review retention, history access, and whether responses may contain sensitive data before deployment.
- Test import, preprocessing, discovery, and triggers on a non-production appliance before linking the template to production hosts.
