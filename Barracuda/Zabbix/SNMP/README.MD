# Barracuda NG Firewall SNMP Template

Zabbix 7.4 template for monitoring Barracuda CloudGen / NG Firewall over SNMP. It includes interface discovery through linked templates, appliance and firewall metrics, service and VPN discovery, and HA-aware alerting based on the floating VIP.

## Requirements

- Zabbix 7.4
- SNMP interface configured on each host with a working community or SNMPv3 credentials
- Linked templates `Template Module ICMP` and `Template Module Interfaces Simple SNMP`
- The `IP-MIB::ipAdEntAddr` table available through SNMP for VIP-aware HA monitoring

## Import and Host Setup

1. Import `Template Barracuda NG Firewall SNMP.json` into Zabbix.
2. Link `Template Barracuda NG Firewall SNMP` to each Barracuda host.
3. Configure the host's SNMP interface with its own management IP and credentials.
4. Configure applicable host-level macros from the table below.
5. Run discovery or wait for the configured discovery intervals.

The template's host should represent one firewall node and use that node's management address, not a shared cluster address.

## HA and VIP Monitoring

The template polls the local IPv4 address table using `walk[.1.3.6.1.2.1.4.20.1.1]`. A dependent item, `cgf_ha_vip_present`, checks whether the configured VIP is assigned locally:

- `1`: VIP is present; treat this node as active.
- `0`: VIP is absent; treat this node as passive.

Service and VPN trigger prototypes are gated by this item, so expected service or VPN inactivity on the passive member does not produce an alarm. After failover, the VIP moves and the role indication changes on the next walk (default interval: 1 minute).

For the current pair, the confirmed VIP is `172.24.5.1`: it is present on `172.24.5.210` and absent on `172.24.5.211`.

Set `{$CGF.HA.VIP}` as a **host-level macro on both HA hosts** to the same floating IPv4 address. Do not set it only on one member. For standalone firewalls, leave the default `0.0.0.0`; the template treats them as active.

The separate `Template Barracuda NG Firewall SNMP HA - for inactive members` is not required when using this VIP-aware template. Avoid linking both unless duplicate service alerts are intended.

## Macros

| Macro | Default | Purpose |
| --- | --- | --- |
| `{$CGF.HA.VIP}` | `0.0.0.0` | Floating IPv4 address shared by HA members. Set on both HA hosts; leave default for standalone. |
| `{$CGF.NET.IF.IFNAME.MATCHES}` | `^.*$` | Include filter for discovered VPN names. |
| `{$CGF.NET.IF.IFNAME.NOT_MATCHES}` | `(^PGRP-.* | ^IGRP-.*)` | Exclude filter for discovered VPN names. |
| `{$DISK_SPACE_HIGH}` | `80` | Warning threshold for filesystem use, percent. |
| `{$DISK_SPACE_DISASTER}` | `90` | Critical threshold for filesystem use, percent. |
| `{$NUMBER_FW_SESSIONS}` | `65536` | Firewall session threshold. |
| `{$SNMP.TIMEOUT}` | `5m` | SNMP availability trigger window. |
| `{$TOTALCPUCORES}` | `2` | CPU load threshold baseline. Override for the appliance model. |
| `{$TOTALCPUCORES.DELAY}` | `30m` | Evaluation window for the CPU load trigger. |

## Monitoring and Triggers

Top-level items include firewall sessions and throughput, CPU load, firmware release, VPN user count, local IPv4 addresses, VIP presence, and SNMP availability.

Discovery rules cover hardware sensors, box services, server services, disk partitions, and VPN tunnels. Service-state triggers use the server-service table and alert when a service is not running on the active node. VPN triggers alert only when the MIB state is `-1` (`down`); state `0` (`down-disabled`) is not treated as an outage.

ICMP ping, packet-loss, and response-time items are inherited from the linked `Template Module ICMP`; this template does not define a duplicate local `icmpping` item. The SNMP-availability trigger is configured to depend on `Unavailable by ICMP ping`, so the linked module must provide that trigger.

The box-service trigger prototype is disabled in this export. The enabled service trigger prototype is under `NG Server-Service Discovery`.

## HA Limitations

The installed `PHION-MIB` does not expose a dedicated primary/secondary role OID. HA role is inferred from local presence of the configured VIP instead. This requires the VIP to appear in `IP-MIB::ipAdEntAddr` only on the active member. If the VIP is not visible in that table, `cgf_ha_vip_present` will not identify the role correctly.

On the passive member, the VPN table may return `No Such Object` because its VPN server is not running there. VPN discovery can therefore be unsupported on that node; VPN alerting is intended to run on the active VIP owner.
