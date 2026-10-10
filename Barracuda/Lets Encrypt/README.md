# Certificate Sync to Barracuda CGF

`cgf-import-cert.sh` imports a TLS certificate renewed by Nginx Proxy Manager (NPM), along with its private key, into the Barracuda CloudGen Firewall (CGF) certificate store through the REST API. It does not issue or renew certificates; it reads the current `fullchain.pem` and `privkey.pem` files from the NPM directory specified by `LIVE_DIR`.

The certificate used by this integration must use an **RSA** key. Select RSA when issuing the Let's Encrypt certificate in NPM; NPM may use ECDSA by default. RSA is required for use by the target CGF services. The script checks that the private key matches the certificate but does not enforce the RSA requirement itself.

Optionally, the script checks the certificate presented by configured CGF services. If a service still presents a different certificate after import, the script can request a service restart and check again. Verification and restart requests are disabled when `CGF_VERIFY` is empty.

## Requirements

- Bash on Linux.
- An NPM-managed Let's Encrypt certificate using an RSA key, with access to its `fullchain.pem` and `privkey.pem` files.
- Connectivity to the CGF REST API and a token with permissions to read, create, and import certificate entries. Service restart checks also require control permissions.
- `curl`, `jq`, `openssl`, and `timeout`.
- A trusted CA certificate for HTTPS. TLS verification is enabled by default (`CGF_INSECURE=0`); configure `CGF_CACERT` if a custom CA is required. Do not use unencrypted HTTP on an untrusted network.

## Workflow

1. Reads the current certificate and key from the NPM directory specified by `LIVE_DIR`, then checks that the required files and tools are available.
2. Checks that the private key matches the certificate and calculates its SHA-256 fingerprint. The script does not check that the key is RSA.
3. Skips the import if the fingerprint has not changed since the previous run, unless `FORCE=1` is set.
4. Prepares the certificate chain and key format required by the CGF API.
5. Checks for the certificate entry in CGF, creates a placeholder if needed, and imports the certificate.
6. Reads the entry again to confirm the import and saves the fingerprint as local state.
7. If `CGF_VERIFY` is configured, compares the fingerprint served by each target service. It requests a restart only when it can confirm that the service presents a different certificate.

Exit code `0` indicates success and `1` indicates an import or verification error. With `CGF_VERIFY_DRYRUN=1`, a detected mismatch is logged without a restart request and does not make the command fail.

## Configuration

Copy `.cgf-import.env.example` to `/root/.cgf-import.env`, set values for your environment, and restrict access to the file:

```bash
sudo install -o root -g root -m 600 .cgf-import.env.example /root/.cgf-import.env
sudoedit /root/.cgf-import.env
```

The script reads `/root/.cgf-import.env` by default. Set `ENV_FILE` to use another file. The file is sourced as shell code, so only a trusted administrator should be able to modify it.

| Variable | Description |
| --- | --- |
| `CGF_HOST` | CGF hostname or address; required. |
| `CGF_TOKEN` | REST API token sent in the `X-API-Token` header; required. |
| `CGF_SCHEME` | `https` or `http`; default `https`. |
| `CGF_PORT` | REST API port; default `8443`. |
| `CGF_CERT_NAME` | Certificate-store entry name; default `letsencrypt-certificate`. |
| `CGF_COMMENT` | Comment for the certificate entry. |
| `CGF_INSECURE` | Set to `1` to disable TLS verification in `curl`; default `0`. |
| `CGF_CACERT` | Optional CA certificate path when `CGF_INSECURE=0`. |
| `LIVE_DIR` | NPM directory containing the current `fullchain.pem` and `privkey.pem`; required. |
| `ROOT_CA_DIR` | Directory of trusted, self-signed root CA certificates; default `/root/cgf-roots`. |
| `ROOT_CA_FILE` | Optional path to a specific root CA instead of automatic selection. |
| `STATE_FILE` | Fingerprint file for the last imported certificate; default `/var/lib/cgf-import-cert/<name>.sha256`. |
| `CGF_VERIFY` | Space-separated `host:port=service-path` targets; empty disables service verification. The port can be omitted for HTTPS/443. |
| `CGF_VERIFY_GRACE` | Wait for automatic certificate reload before requesting a restart; default 30 seconds. |
| `CGF_VERIFY_WAIT` | Wait for the new certificate after restart; default 90 seconds. |
| `CGF_VERIFY_DRYRUN` | Set to `1` to log required restarts without sending restart requests. |
| `FORCE` | Set to `1` to import even if the fingerprint has not changed. |
| `DRY_RUN` | Set to `1` to print the import plan without connecting to CGF. |

The configuration file is sourced before the script runs and can override values supplied in the environment. Use a separate file selected with `ENV_FILE` for testing.

If your CGF version requires a self-signed root in the import bundle, copy the required certificate into `ROOT_CA_DIR`. The `cgf-root/` directory contains public root CA certificates, not private keys. Verify each certificate's validity and fingerprint against the issuer's official source before use. The script selects a root based on the certificate chain. If no matching root is found, it uses `fullchain.pem` alone, which CGF may reject.

## Run

Run with the default configuration:

```bash
sudo /root/cgf-import-cert.sh
```

Force an import or preview the planned import:

```bash
sudo FORCE=1 /root/cgf-import-cert.sh
sudo DRY_RUN=1 /root/cgf-import-cert.sh
```

`DRY_RUN=1` exits before connecting to CGF. `CGF_VERIFY_DRYRUN=1` checks configured services without requesting a restart; a detected mismatch is logged but does not produce a non-zero exit status.

## Scheduling and Logs

The script does not install a schedule or configure system logging. Run it manually or add it to a system scheduler after testing. Adapt cron entries and log handling to the operating system, script location, and operational policy.

The script writes messages to standard output and standard error. It does not send notifications. Monitor its exit status and protect logs according to local policy.

## Security and Limitations

- The private key is used for the CGF import and stored temporarily in a restricted-permission file; temporary files are removed when the script exits.
- The API token is protected in transit only when HTTPS is configured. `CGF_INSECURE=1` disables server certificate verification and increases the risk of exposing the token and key.
- NPM is responsible for issuing and renewing the certificate. The script expects ready-to-use PEM files and must be run after renewal; NPM renewal alone does not invoke it.
- The script does not enforce RSA. Check the certificate key type in NPM before running; ECDSA certificates do not meet the target CGF service requirement for this integration.
- Not every service configuration reloads a certificate automatically after import. Configure `CGF_VERIFY` only after confirming service identifiers and restart impact.
- The script accepts HTTP 2xx responses. Supported endpoints and formats may depend on the CGF API version.
- Before production use, verify token permissions, the certificate chain, service paths, and restart behavior in your environment.

## REST API Endpoints

The script uses the following CGF endpoints:

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/rest/config/v1/box/store/certificates/{name}` | Check the entry and read it after import. |
| `POST` | `/rest/config/v1/box/store/certificates` | Create a placeholder if the entry does not exist. |
| `PUT` | `/rest/config/v1/box/store/certificates/{name}` | Import the certificate chain and key. |
| `GET` | `/rest/control/v1/{service-path}` | Check service state after a restart. |
| `POST` | `/rest/control/v1/{service-path}/restart` | Optionally restart a service when a certificate mismatch is detected. |

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Connection error | Check the CGF address and port, REST API availability, DNS, network route, and firewall rules. |
| HTTP 401 or 403 | Check token validity, permissions, and the CGF REST API client allowlist. |
| Certificate files missing | Confirm `LIVE_DIR` points to a directory containing readable `fullchain.pem` and `privkey.pem` files. |
| Key does not match certificate | Confirm both files came from the same renewal. |
| Unknown root CA or rejected chain | Check that the root CA directory contains the correct trusted certificate. Verify its source and fingerprint before use. |
| Entry rejects a different key type | Check the CGF version's constraints. Changing key type may require manually recreating the entry. |
| Service still presents the old certificate | Check `CGF_VERIFY`, the service path, TLS reachability, and token permissions for control operations. |
