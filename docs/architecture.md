# Private DERP architecture and configuration contract

Status: **recommended design, not implemented or deployed**. Evidence and revision boundaries: [feasibility](research/feasibility.md) and [relay/certificate source investigation](research/relay-certificates.md). Examples below are documentation only.

## Scope and topology

One Linux VM on Proxmox runs one Compose project with three locally built images: `derper`, a small static HTTPS `map` service, and one-shot `lego`. A host-side lifecycle command and systemd timers manage issuance, certificate activation, reconciliation and expiry checks. Only the host can control Docker. Browser and controller access the VM over LAN/VPN. Tailcat runs at the endpoints; no Playwriter relay runs on the browser machine. The existing controller-side Playwriter adapter/relay remains part of client integration, not this VM stack.

```text
Browser extension / WASM Tailcat ---- WSS TCP 443 -----+
                                                    | derper
Controller / native Tailcat -------- TLS TCP 443 -----+ (opaque packet forwarding)
       both ------------------------ HTTPS TCP 8443 --- map /derpmap.json

Host lifecycle job ---- one-shot lego ---- outbound HTTPS ---- ACME + Cloudflare
                                     ---- public DNS queries
         |
         +-- validate immutable certificate generation
         +-- recreate TLS consumers only when activation is needed
```

DERP is directly published; neither an HTTP reverse proxy nor Cloudflare proxying is proposed. Native `Upgrade: DERP` and browser WebSocket `derp` subprotocol share `/derp`; generic WebSocket proxy settings alone are insufficient evidence of compatibility. A separate map port avoids patching derper or inserting a protocol intermediary. Source support: [protocol findings](research/relay-certificates.md#derp-and-browser-transport-compatibility).

The map service is proposed new local code, not an existing derper feature. Keep it small: Go standard-library HTTPS, a prevalidated static map, bounded requests, exact routes, explicit CORS, no directory listing, no upstream proxying, no authentication database. It may share a locally built health/validation helper. Its implementation is ticket S03.

## Initial support and build contract

- Reference deployment: Debian 13, Linux `amd64`, systemd, rootful Docker Engine with **iptables firewall backend**, Compose v2, local POSIX filesystem, synchronized clock. This is a proposed validation baseline, not a finding about the owner's VM. No OS replacement is authorized. A different existing Linux distribution can be qualified by the same tests before declaring support.
- Initial endpoint acceptance: Windows x64 native controller and packaged Edge MV3 extension, matching the inspected Playwriter MVP; also run a Chrome smoke test. Record exact browser and client artifact versions during implementation. Additional platforms are future qualification work.
- Use a maintained stable Engine (29 or newer) and Compose v2 release. S01 records exact package versions, engine backend and kernel used by acceptance. Neither an arbitrary newer version nor an untested nftables backend is automatically qualified.
- Initial VM sizing proposal: 2 vCPU, 2 GiB RAM, 20 GiB local disk for runtime. Local builds may require more RAM/disk, particularly lego's provider dependency graph; allow a separate Linux-capable local builder and transfer via `docker save/load`. No registry push. These are starting budgets, not measured capacity.

Pin derper **v1.104.7 / `cbc74fe48ef1b1649f69a4d9a602319427e25102`**, lego **v5.6.0 / `226c09fbe704ea412bea76cb268414f67686be1d`**, and Go **1.27.4** for server images. Keep Playwriter's separate Tailcat/Go pin unchanged unless its integration work explicitly updates it. [Revision evidence](research/relay-certificates.md#recommendation-and-revision-inventory).

The future `versions.lock.json` must additionally pin builder base image platform digest, toolchain/archive checksums if used, CA-bundle source/digest, module graph/sums, BuildKit version, build flags and source commit for local helper code. Resolve and verify these in S01 before building. Never invent digest values in these specifications. A multi-stage build compiles pinned source with `CGO_ENABLED=0`, `GOTOOLCHAIN=local`, `-mod=readonly`, `-trimpath`, and controlled VCS/build metadata; final scratch images contain only binaries, CA roots where needed and license notices. No package-manager `latest`, runtime downloads, real config, certificates, keys or build secrets in image layers. [Docker build guidance](https://docs.docker.com/build/building/best-practices/).

Use local immutable image tags tied to source/lock revision, `pull_policy: never` at runtime, and explicit builds. Fail when the expected local image is missing; do not pull a same-named image. Compare binaries from two clean builds and record hashes and input provenance locally. Whole OCI archive hashes can differ due to metadata; do not claim byte-identical images unless that too is tested and normalized. Keep previous images/archives for rollback. Source pinning specifies repeatable inputs; completed reproducibility evidence is a later gate.

## Compose services

| Service | Runtime contract | Mounts and state | Initial limits and checks |
| --- | --- | --- | --- |
| `derper` | UID/GID `10001:10001`; container TLS port 8443 published as VM TCP 443; `restart: unless-stopped` | `/state` RW for persistent DERP identity; `/certs` RO bind to **one immutable generation directory**, containing only the selected hostname's `.crt` and `.key` | 1 CPU, 256 MiB memory and no extra swap, 128 PIDs, `nofile` 4096; SNI-valid `/derp/probe` every 30 s, timeout 5 s, 3 failures, startup allowance 30 s |
| `map` | UID/GID `10002:10002`; TLS port 8443 published as VM TCP 8443; `restart: unless-stopped` | `/map/derpmap.json` RO; same immutable `/certs` generation RO; no persistent writable data | 0.25 CPU, 64 MiB, 64 PIDs; HTTPS map/schema check on same interval |
| `lego` | UID/GID `10003:10003`; automation profile; one-shot `restart: no`; no published ports | `/lego` RW only for ACME state; Cloudflare secret RO only here | 0.5 CPU, 256 MiB, 128 PIDs; job exit/status/validation, no daemon healthcheck |

All services: read-only root filesystem, `cap_drop: ALL`, `no-new-privileges`, ordinary default seccomp, no privileged mode/TUN/host networking/Docker socket, bounded tmpfs where necessary (16 MiB proposal), bounded logs (10 MiB × 3 per daemon). Numeric limits are initial constraints to test, not throughput promises. Use Compose service-level `cpus`, `mem_limit`, `memswap_limit`, `pids_limit`, and `ulimits`; verify Docker inspect shows enforcement. [Compose service contract](https://docs.docker.com/reference/compose-file/services/).

Host source directories must already exist; missing bind paths fail rather than becoming root-owned empty directories. Give the published pair root ownership and group `10004`, modes `0750` directory / `0640` files; grant only derper and map supplementary GID 10004. Relay state is `0700`, owned 10001; ACME state `0700`, owned 10003. Cloudflare source file is root-owned, group 10003, mode `0640`, inside a root-only parent; its container mount is read-only. Runtime UID mapping and actual readability are acceptance checks. Standalone Compose file secrets do not reliably remap host ownership through `uid/gid/mode`; provision permissions explicitly. [Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/).

Use separate default-NAT bridge networks for relay, map and automation; no interservice data traffic is required. Disable IPv6 on these bridges initially. Retain Docker's firewall management; do not set `iptables=false`. ACME needs outbound DNS and HTTPS. Persistent services need established reply traffic; no Tailscale control-plane login is required.

**Proposed derper argument contract:** `-a :8443`, `-hostname <DERP_HOSTNAME>`, `-certmode manual`, `-certdir /certs`, `-c /state/derper.json`, `-http-port -1`, `-stun=false`, `-derp=true`, `-verify-clients=false`, `-home blank`. Leave custom verification URL, mesh and development mode unset. Manual mode enables TLS on this unprivileged internal port. [Verified flags](research/relay-certificates.md#derper-flags-routes-identity-and-ports).

The root host lifecycle job performs ordered bootstrap: preflight and firewall verification → local image availability → certificate acquisition/validation → durable generation selection → start derper and map → SNI/TLS checks → enable timers. There is no permanent `depends_on: lego`; renewal failure cannot prevent a healthy relay from continuing. Once bootstrapped, derper and map can start independently from durable immutable mounts. Docker owns crash restart; systemd runs reconciliation jobs, not a competing foreground process supervisor. Health status alone does not trigger Docker restarts. [Restart behavior](https://docs.docker.com/engine/containers/start-containers-automatically/), [Compose ordering](https://docs.docker.com/compose/how-tos/startup-order/).

## Ports and access control

| Direction | Port | Purpose and restriction |
| --- | --- | --- |
| LAN/VPN → VM selected IPv4 | TCP 443 | DERP native TLS and browser WSS; approved source CIDRs only |
| LAN/VPN → VM selected IPv4 | TCP 8443 | HTTPS map; same source restrictions |
| Inbound | UDP 3478, TCP 80 | Closed/unpublished; STUN and HTTP disabled |
| Inbound IPv6 | All stack ports | Closed/unpublished; no local AAAA for this service |
| VM/automation → external | TCP 443; UDP/TCP 53 as needed | ACME, Cloudflare API, configured recursive and authoritative DNS; host time sync and maintenance separately |

Do not expose controller loopback ports, Docker API, map debug endpoints or derper diagnostics as separate published services. A local HTTPS liveness probe is not admission control and cannot prove packet relaying.

Bind published ports explicitly to `<LAN_BIND_IPV4>`, never blank/`0.0.0.0`. Treat binding as destination selection, not source authorization. Initial firewall design: approved-source allowlist and default deny for the two stack ports in a dedicated chain reached from `DOCKER-USER`; match DNAT/original port correctly with conntrack, preserve established traffic and outbound responses, and scope rules so unrelated containers are unaffected. Reject direct routed bypasses; leave Docker direct-routing options disabled. Apply equivalent IPv6 deny policy even if the initial Compose bridge is IPv4-only. UFW INPUT rules alone are insufficient. [Docker iptables](https://docs.docker.com/engine/network/firewall-iptables/), [publishing](https://docs.docker.com/engine/network/port-publishing/).

Provide an independently enforced deny/allow boundary at the Proxmox VM virtual NIC firewall (or a verified equivalent outside Docker) so Docker startup/rule restoration has no permissive window. Router/UniFi LAN/VPN policy provides another boundary but cannot alone filter same-subnet traffic. Future installation must verify the available VM-firewall mechanism without assuming an installed Proxmox version/backend. If unavailable, qualify a boot-persistent host forwarding policy that denies before Docker starts; do not declare network acceptance until the boot race is tested. No WAN forwarding/UPnP mapping and no public proxy record. The chosen rules must survive Docker daemon restart and VM reboot and block disallowed hosts on both the same and routed networks.

## HTTPS map contract

Endpoint: `https://relay.example.com:8443/derpmap.json` (synthetic). Use a real owner-controlled hostname at deployment. Minimal selected topology:

```json
{
  "omitDefaultRegions": true,
  "Regions": {
    "900": {
      "RegionID": 900,
      "RegionCode": "private",
      "RegionName": "Private relay",
      "Nodes": [
        {
          "Name": "900a",
          "RegionID": 900,
          "HostName": "relay.example.com",
          "IPv6": "none",
          "DERPPort": 443,
          "STUNPort": -1
        }
      ]
    }
  }
}
```

Region 900 is in the source's end-user range. Node IPv4 is omitted to use local DNS; `IPv6:"none"` and `STUNPort:-1` are documented schema sentinels. `omitDefaultRegions` is lower camel case as defined by its JSON tag. Tailcat uses the supplied map directly; this flag alone is **not** a no-fallback enforcement mechanism. Never include public regions, `InsecureForTests`, `CertName` overrides, STUN-only nodes or public fallback URLs. [Pinned schema](https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/tailcfg/derpmap.go).

Map service requirements: validate a maximum 64 KiB file at startup; require exactly the approved region/node/hostname/ports initially; fail startup for malformed/empty/unknown policy fields; return JSON on GET and headers on HEAD; stable content hash ETag; 304 support; `Cache-Control: no-cache`; 404 for other paths and 405 for unsupported methods; 5-second header and 10-second request timeouts; no request bodies or redirects; no reflected arbitrary origins. CORS requirements are in [browser findings](research/feasibility.md#browser-cors-tls-and-private-destinations). CORS allowlists contain local extension origins and are not committed. Keep the map and hostname generic; no deployment inventory in `RegionName`.

Local clients must resolve the hostname to the VM's private address through UniFi, including over VPN. Public authoritative DNS only needs the publicly visible validation records and applicable CAA/NS chain. Cloudflare's HTTPS proxy is not in the data path. No `/derpmap.json` route is assumed on upstream derper.

## Configuration and secret contract

Actual values belong outside the checkout, proposed host root `/etc/derp-stack` and state root `/var/lib/derp-stack`. These generic paths are not owner inventory. The future loader must validate types/limits and reject unresolved placeholders, shell evaluation, unsafe path traversal, relative secret paths and ambiguous hostnames. Configuration values are data, never sourced as executable shell text.

| Input | Contract / placeholder | Consumer |
| --- | --- | --- |
| `DERP_HOSTNAME` | `<REAL_DNS_HOSTNAME>`; lowercase ASCII FQDN; no wildcard or IP literal | derper, map, certificate validator/lego |
| `LAN_BIND_IPV4` | `<VM_PRIVATE_IPV4>`; address exists on selected VM | Compose/firewall preflight |
| `ALLOWED_SOURCE_CIDRS` | `<LAN_CIDRS>,<VPN_CIDRS>`; no allow-all default | host policy; never injected into images |
| `DERP_PORT`, `MAP_PORT` | 443 and 8443 initially; conflicts fail preflight | host publishing, map/profile |
| `REGION_ID` | 900 initially; positive, consistent key/region/node ID | generated local map and profile |
| `CORS_ALLOWED_ORIGINS` | `<EXTENSION_ORIGIN>` plus explicit test origins only | map |
| `ACME_DIRECTORY_URL` | explicit production or staging directory; separate state roots | lego/validator |
| `ACME_EMAIL` | `<ACME_CONTACT_EMAIL>` stored locally if registration uses a contact | lego only |
| `DNS_RESOLVERS` | `<PUBLIC_RECURSOR_IP:53>` list; must resolve public challenge authority | lego only |
| `CLOUDFLARE_DNS_API_TOKEN_FILE` | `/run/secrets/cloudflare_dns_api_token` in lego; host source `<ABSOLUTE_SECRET_FILE>` | lego only |
| `STATE_ROOT`, `CONFIG_ROOT` | absolute local roots; writable state on one local filesystem for atomic publication | host lifecycle |
| `CERT_GENERATION` | host-generated opaque generation identifier; never operator-supplied path | restricted activation override |
| `IMAGE_SET` | exact local image IDs/tags and lock revision; no pulls | host lifecycle |
| `ALERT_COMMAND` | local approved executable plus structured arguments; no shell fragment | host monitor only |

One Cloudflare token: Zone/DNS/Edit and Zone/Zone/Read restricted to the necessary zone. No Global API Key, account-wide permission or token in `.env`, command arguments, image layers or Docker metadata. The file path variable is not itself a secret. Clear direct token and legacy-key environment variables so they cannot override `_FILE`. API token scope is zone-wide, not one-record-only. [Cloudflare/lego evidence](research/relay-certificates.md#lego-v5-contract-cloudflare-credentials-and-dns-visibility).

Persist relay identity, full ACME account/resources, immutable certificate generations, transaction/activation records, local map/config, version manifests and local diagnostic status separately. Backups contain sensitive material and are encrypted/access-controlled outside GitHub. The relay's identity key must never be confused with the endpoint PSK or endpoint private keys, which this stack never stores.

## Proposed repository layout and publication boundary

Only the Markdown documents exist in this phase. Future paths below are a layout proposal, not files to implement now:

```text
README.md
docs/                         # research, design, operations, acceptance, ticket drafts
compose.yaml                  # placeholders, explicit mounts, no real environment
images/{derper,lego,map}/      # reproducible Dockerfiles
cmd/{mapd,stack-health,stack-cert}/
scripts/                      # host lifecycle/preflight/diagnostic entrypoints
systemd/                      # service/timer templates
examples/                     # synthetic config, map, firewall and profile examples
tests/                        # synthetic fixtures and acceptance harness
versions.lock.json            # public source/build pins only
.gitignore
.dockerignore
```

Specify ignore rules in S01 for `.env`, `.env.*` (allow only explicitly synthetic `.env.example`), `.local/`, `local/`, `secrets/`, `state/`, `certs/`, `backups/`, `artifacts/`, `logs/`, `tmp/`, `compose.override.y*ml`, `*.local.*`, `*.pem`, `*.key`, `*.crt`, `*.p12`, `*.pfx`, `*.pcap*`, and `*.log`. Add explicit exceptions only for reviewed synthetic templates. Use a minimal allowlisted Docker build context in addition to ignores. Ignores do not protect already tracked files or force-adds.

Before any publication, inspect the complete staged diff and all proposed issue/PR text, screenshots, logs, CI output and artifacts. Secret scanning is supplemental: reviewers must also remove real domains, IPs, VLANs, machine/VM/account identifiers, contacts, inventory, descriptors and certificate material. Build tests use synthetic data; production diagnostics never enter public CI. Publish only an allowlisted summary regenerated from local results and manually reviewed. No raw `docker inspect`, Compose expansion, ACME logs, packet captures or session descriptors in tickets. Public upstream URLs and source SHAs are citations, not deployment values.

## Client integration policy (separate repository)

Define private descriptor v2 with `transport:'playwriter-tailcat'`, `port:1`, `relayMode:'private'`, short `addr`, and `derpMapURL`. Both endpoints must have an explicitly selected local private profile approving the exact canonical HTTPS URL, region 900, relay hostname/port and map content digest. Reject credentials, fragments, query strings, redirects, unknown regions, embedded destinations and TLS bypass fields. Reject descriptor/profile mismatches before native launch or network fetch. Keep existing v1 public parsing separate and only available after explicit public-mode selection; never reinterpret a failed private descriptor as public/local mode.

Use a stable map body for the initial single-node deployment. Profile provisioning records its SHA-256 and validated topology locally. Private mode must validate the actual map used by Tailcat, not only a preliminary separate fetch. The native launcher performs its own bounded HTTPS fetch with redirect rejection, validates bytes/topology, then supplies a private per-session `DERPMapCache` returning only those frozen validated bytes for the exact URL as fresh; its `Put` must reject any unexpected replacement. Keep the URL explicit on `Client`. Bound transport startup to the existing 60-second deadline. No process-global cache supplies private mode.

For WASM, select a small **owned Playwriter bridge extension** for private mode, built against the unchanged pinned Tailcat module: accept the validated map bytes plus expected region, validate again, and construct `tailcat.Server` with an explicit `Region`. Return a short address with that selected RegionID and a nonzero PSK. This follows upstream `web/main_js.go`'s server construction but bypasses its map-fetch/cache step in private mode. Keep the public API behavior intact. This is separate client implementation work; the current upstream WASM API takes a URL and does not expose a supplied-map/cache argument. Do not rely on an unverified global fetch interception. Private-key JSON remains inside the worker. [WASM construction](https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/web/main_js.go), [native cache API](https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/tailcat.go).

Each newly started private session requires a fresh successful bounded HTTPS map validation, with public redirects prohibited; per-session validated in-memory copies are allowed for transport startup. No stale-map bootstrap on map failure in private mode. Existing sessions may continue when only the map service is unavailable. Map updates require explicit local profile revision; certificate renewal leaves map bytes unchanged. This deliberate stricter policy overrides Tailcat's ordinary stale-cache behavior. User-facing failures distinguish map/TLS/private-relay unavailability without printing descriptors. No public map fetch or public relay dialing is allowed in private mode, even when a private connection fails.

## Future external access

Internet exposure is not an initial acceptance requirement. Do not reuse LAN-only assumptions for a public listener. A separate design must address compatible Tailcat admission (no assumption that tailscaled `WhoIsNodeKey` accepts accountless keys), a fail-closed admission service if chosen, quotas/rate limits, bandwidth billing, denial-of-service response, patch cadence, abuse contacts, metrics/retention/privacy, IPv6, DNS/proxy topology, HA and tested recovery. PSKs protect endpoint sessions; they do not prevent arbitrary reachable clients from consuming an unverified relay's resources.
