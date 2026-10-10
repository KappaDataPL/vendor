# External DNS Blocklists for Barracuda CGF

`dns.black.list.sh` adapts the approach described in [Barracuda Best Practice: Integrate External DNS Block Lists with the CloudGen Firewall](https://documentation.campus.barracuda.com/wiki/spaces/CGFv105/pages/379094215/Best+Practice+-+How+to+Integrate+External+DNS+Block+Lists+with+the+CloudGen+Firewall). It downloads domain lists, combines them, and updates a custom RPZ zone used by the Caching DNS service on Barracuda CloudGen Firewall (CGF).

When applied, the RPZ zone returns `NXDOMAIN` for listed domains. This changes DNS responses for clients using the service, so review the sources and expected impact before deployment.

## Sources

By default, the script downloads:

- [CERT Polska domain list](https://hole.cert.pl/domains/v2/domains.txt), a text list of domains.
- [StevenBlack/hosts](https://github.com/StevenBlack/hosts), from which it extracts the second field on lines beginning with an IPv4 address.

Source URLs are defined in the `DNSBL_URLS` array near the top of the script. You can replace or extend them. Each source must match the expected input format or have a corresponding parser.

## Operation

1. Downloads each source over HTTPS and combines the content in the input file.
2. Parses the StevenBlack hosts file for mapped hostnames; the other source is treated as a plain domain list.
3. Calculates the combined file's SHA-256 hash. If it matches the saved hash, the script exits without regenerating the zone.
4. Replaces the SOA serial in the RPZ template with the current Unix timestamp and adds a `CNAME .` record for each non-empty, non-comment line.
5. Replaces the active zone file, sets its immutable attribute, and runs `/sbin/rndc reload`.

## Requirements and Deployment

- Barracuda CloudGen Firewall with Caching DNS configured for the relevant CGF version.
- Bash and the utilities used by the script: `curl`, `grep`, `awk`, `sha256sum`, `sed`, `date`, `touch`, `cat`, `mv`, and `chattr`.
- Network access from the firewall to each configured HTTPS source.
- Permissions to modify the CGF zone files, run `chattr`, and execute `rndc reload`.

Input, template, temporary, and active zone paths are hard-coded in the script. Review and adapt them to the target CGF version and configuration before use. Install the script in an appropriate location on the firewall and schedule it only after testing, for example through a system scheduler supported by the appliance.

## Safety and Limitations

- Review source contents, licensing, and false-positive impact before deployment. The script does not validate or deduplicate domain names.
- Every accepted line is written as `CNAME .` and will be blocked by Caching DNS. Do not use unreviewed sources or unexpected source formats.
- The saved SHA-256 hash is written before zone generation, file replacement, and DNS reload. If a later step fails, an unchanged source list may not trigger another update on the next run.
- The script does not check the exit status of `chattr`, `mv`, or `rndc reload`, and it does not enable strict shell error handling. Its final success message or exit status does not prove that the zone was successfully reloaded.
- Zone paths and commands are CGF-specific. Test on a non-production appliance and prepare a way to restore the previous zone.
- Downloads use `curl -s` without `--fail` or a timeout. An HTTP error response may not be handled as a failed download if it contains a body.

For production use, consider adding domain validation and deduplication, download failure and timeout handling, checked exit statuses for zone updates and reloads, and saving the hash only after a successful reload.
