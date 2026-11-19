# derp-stack

Docker Compose package for a LAN-hosted Tailscale `derper` v1.104.7 and a static HTTPS DERP map, with optional Let's Encrypt DNS-01 issuance and renewal using upstream `lego` v5.6.0.

## Start with a supplied certificate

1. Point LAN DNS for your relay hostname at the Docker host's private IPv4 address. Allow TCP 443 for DERP and TCP 9443 for the map from the intended LAN clients. Keep the bind address and firewall policy private to the deployment. The relay accepts reachable Tailcat clients without a tailnet membership check.
2. Put the PEM full chain (leaf first) and matching unencrypted key in a dedicated private directory outside the checkout. Name the files `<hostname>.crt` and `<hostname>.key`. Create `/etc/derp-stack/relay.env` with your values in plain `KEY=value` form.

   ```dotenv
   DERP_HOSTNAME=derp.example.com
   LAN_BIND_IPV4=192.168.50.10
   DERP_CERT_DIR=/var/lib/derp-stack/supplied-tls
   ```

3. From the checkout, start the relay. Compose mounts the pair read-only and keeps the relay identity in the `relay-state` volume across container replacement.

   ```sh
   docker compose --env-file /etc/derp-stack/relay.env up -d --build derper
   ```

4. Check the leaf and its trust chain from a LAN client. For a private CA, add `-CAfile /path/to/ca.pem`.

   ```sh
   relay=derp.example.com
   openssl s_client -connect "$relay:443" -servername "$relay" \
     -verify_hostname "$relay" -verify_return_error </dev/null
   ```

The same container publishes `https://derp.example.com:9443/derpmap.json` with the relay's certificate. The JSON advertises a single region `900` and the relay on port `443`. Set `DERP_MAP_PORT` in `relay.env` if you need a different host port for the map. Use the full map URL in clients that ask for it.

## Issue and renew with lego

On a Linux Docker host with systemd, Bash, `flock` and OpenSSL, place the stack at `/opt/derp-stack` with administrator-only write access. Use a hostname in a public Cloudflare zone you control. DNS-01 needs public TXT records and outbound DNS and HTTPS. The relay hostname can resolve to the private IPv4 address on the LAN.

1. Set `DERP_CERT_DIR=/var/lib/derp-stack/tls/current` in `relay.env`. Create `/var/lib/derp-stack/tls` and `/var/lib/derp-stack/lego` as private, root-owned directories. Leave `current` absent for first issuance. To migrate a running relay, make `current` a symlink to the existing pair directory before running the job.
2. Save a Cloudflare API token with **Zone DNS Edit** and **Zone Zone Read** for the relevant zone in a root-only file. Create `/etc/derp-stack/acme.env` with the settings below. lego reads the token from a mounted secret file. Set `ACME_DNS_RESOLVER` if you need a resolver other than the default `1.1.1.1:53`. Use a resolver with a public view of the zone. If local DNS interception prevents lego from checking public propagation, set `ACME_DNS_PROPAGATION_WAIT=45s` to use a fixed delay before Let's Encrypt performs its public DNS validation.

   ```dotenv
   ACME_EMAIL=operator@example.com
   LEGO_STATE_DIR=/var/lib/derp-stack/lego
   CLOUDFLARE_TOKEN_FILE=/etc/derp-stack/cloudflare-token
   ```

3. Build the relay, install the units and invoke the certificate job on demand. First issuance validates the pair and starts the relay. The same service checks for renewal on later runs.

   ```sh
   cd /opt/derp-stack
   sudo docker compose --env-file /etc/derp-stack/relay.env build derper
   sudo install -m 0644 systemd/derp-stack-renew.{service,timer} /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl start derp-stack-renew.service
   sudo journalctl -u derp-stack-renew.service -n 30 --no-pager
   sudo systemctl enable --now derp-stack-renew.timer
   ```

The timer checks every six hours with up to 15 minutes of jitter. A changed, trusted pair triggers a brief container replacement. The job verifies the new leaf over TLS on both the relay and map ports. An unchanged pair or a failed lego run leaves the running relay alone. Keep the lego state directory for future renewals. If you recreate a managed relay by hand, pass the resolved certificate directory so Docker binds that specific generation.

```sh
sudo env DERP_CERT_DIR="$(sudo realpath /var/lib/derp-stack/tls/current)" \
  docker compose --env-file /etc/derp-stack/relay.env up -d --build derper
```

## Check a relayed transfer

Use two [official Tailcat v0.7.0 clients](https://github.com/tailscale/tailcat/releases/tag/v0.7.0) that trust the relay's CA. For this check, isolate the peers from each other while allowing each to reach the relay on TCP 443. For example, attach each client to its own internal Docker bridge and attach the relay to both with its DNS hostname as a network alias. Use a disposable Tailcat configuration and share the session address privately.

On the receiver:

```sh
export XDG_CONFIG_HOME="$(mktemp -d)"
tailcat genkey --key=default --region=derp.example.com
tailcat --verbose >received.txt
```

On the sender, using the address printed by the receiver:

```sh
printf '%s\n' 'derp-stack-mvp payload 01' | tailcat --verbose "$TAILCAT_ADDRESS"
```

Check `received.txt` against the sent payload. Use `tailcat parse "$TAILCAT_ADDRESS"` locally to confirm the embedded relay hostname, and check both verbose logs for the DERP connection. Confirm the test network or firewall rules blocked a direct peer path.

## Observed MVP checks

The Linux/amd64 Docker Desktop lab used two internal bridges with one stock Tailcat client on each. Only the relay joined both bridges. Both peer route lookups returned `Network unreachable`, both clients reported a DERP connection, and the receiver got `derp-stack-mvp payload 01` byte for byte. A verified TLS handshake served the mounted lab leaf, serial `01`.

On-demand systemd runs exercised lego against a local Pebble CA with a test DNS-01 server. Each served leaf below was verified for the lab hostname and trusted by the probe. The relay identity persisted through container replacement.

| On-demand check | Result | Served leaf serial |
| --- | --- | --- |
| Initial issuance | New certificate activated | `610FF1144EF8DD77` |
| Renewal check before due date | Unchanged certificate and container | `610FF1144EF8DD77` |
| Forced lab renewal | Replacement certificate activated | `5672C1BCEC9A773E` |
| Cloudflare provider with empty token | Job failed. Certificate and container stayed in place. | `5672C1BCEC9A773E` |
| Fresh ACME state and no active pair | Issued and started the relay | `210D036D5D4583F7` |

A LAN deployment also passed live Let's Encrypt DNS-01 issuance, an on-demand renewal no-op, and a stock Tailcat transfer with direct UDP disabled. Playwriter's map validator accepted the bundled HTTPS endpoint. Wall-clock timer observation remains pending.

The [MVP tickets](docs/tickets.md) and [implementation goal](docs/implementation-goal.md) define scope. Earlier [architecture](docs/architecture.md), [operations](docs/operations.md) and [acceptance](docs/acceptance.md) documents describe a broader qualification effort. See the [upstream relay and certificate research](docs/research/relay-certificates.md) for implementation details.

Keep real deployment configuration, credentials, certificates, keys and session addresses outside this repository and its public issues.
