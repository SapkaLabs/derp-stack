# DERP relay and certificate lifecycle research

Research date: **2026-11-17**. Scope: upstream relay/certificate behavior and an implementable lifecycle proposal for this private DERP stack. **Verified** means inspected official documentation or source at the cited revision; it does not mean exercised in a running stack. **Proposed** means an implementation recommendation. **Untested** identifies runtime evidence still needed.

Repository instructions: checked ancestor/workspace `AGENTS.md` locations and the existing repository files; none were present when inspected. Read the research skill and repository README. This investigation is the requested research sub-agent work; no further agents were started. The only checkout artifact created by this investigation is this file. No builds, certificate requests, deployments, infrastructure changes, image publication, tracker changes, commits, or pushes were performed. Architecture, Docker/firewall implementation, browser/Playwriter integration, and acceptance/ticket authoring remain with the parent.

## Recommendation and revision inventory

**Proposed:** pin `tailscale.com/cmd/derper` to **v1.104.7**, resolved to `cbc74fe48ef1b1649f69a4d9a602319427e25102`, and lego to **v5.6.0**, resolved to `226c09fbe704ea412bea76cb268414f67686be1d`. Both were non-prerelease latest releases returned by the respective GitHub release APIs on the research date. Preserve these exact revisions rather than using floating `latest` at implementation time. The relay recommendation is supported by the protocol/handler comparison below, **not** by a completed Tailcat interoperability test. [Tailscale release][ts-release], [lego release][lego-release], [release APIs][release-apis-ts], [lego release API][release-apis-lego].

| Component | Version / immutable source revision | Upstream timestamp (UTC) | Role |
| --- | --- | --- | --- |
| Tailcat | `e00cdde6ff787f801361ff85ed085775c775d4c5` | Commit: 2026-11-05 15:10:22 | Required client baseline. [Commit][tc-commit] |
| Tailcat's Tailscale dependency | `v1.105.0-pre.0.20261013225543-fb79793d99f5`; full SHA `fb79793d99f5ccedabe1ab428f0af852f49d0c62` | Commit: 2026-10-13 22:55:43 | Actual dependency in pinned Tailcat `go.mod`; **not a stable release**. [Module][tc-mod], [commit][dep-commit] |
| Recommended derper | `v1.104.7`; `cbc74fe48ef1b1649f69a4d9a602319427e25102` | Commit: 2026-11-12 18:22:32; release: 2026-11-12 22:56:51 | Stable server source. [Commit][ts-commit], [release][ts-release] |
| Recommended lego | `v5.6.0`; `226c09fbe704ea412bea76cb268414f67686be1d` | Commit: 2026-10-28 12:04:29; release: 2026-10-28 13:01:28 | Stable ACME CLI/provider source. [Commit][lego-commit], [release][lego-release] |
| Go TLS loader examined | `go1.27.4`; `7b2881024c95a11ddb86663a616340aa3a88b67f` | Commit: 2026-11-10 16:47:23 | Confirms PEM parsing, key matching, and separate file reads. [Commit][go-commit], [TLS source][go-tls] |

**Verified toolchain declarations:** Tailcat's pinned module declares Go `1.27.2`; selected Tailscale declares `1.27.4`; selected lego declares `1.26.0` and module path `github.com/go-acme/lego/v5`. These are source requirements, not proof that any particular builder image is available or suitable. Image selection/digests and builds are outside this investigation. [Tailcat module][tc-mod], [Tailscale module][ts-mod], [lego module][lego-mod].

Official moving documentation was consulted on 2026-11-17: lego Cloudflare and obtain pages displayed 2026-11-16; Let's Encrypt challenge documentation displayed 2026-02-12; Cloudflare token documentation displayed 2026-11-06. systemd pages identified version 262. Docker, Linux man-pages, and Tailscale documentation links below are explanatory references; revision-pinned code governs claims about the selected binaries. Host systemd/Docker versions have not been inspected.

## DERP and browser transport compatibility

**Verified:** pinned Tailcat uses Tailscale's data plane without a control plane or Tailscale account. Its backend supplies a DERP map and advertises `tailcat-client` or `tailcat-server` as the DERP app name. These app names are informational client strings, not an authentication mechanism. [Tailcat README][tc-readme], [backend configuration][tc-source], [dependency client options][dep-client].

The following comparison supports selecting stable derper rather than automatically building its client dependency's prerelease:

- The entire `derp/derp.go` file is byte-identical between the selected stable server and Tailcat's dependency. Both define `ProtocolVersion = 2`; the source states that wire-incompatible changes bump this version. The independently computed file SHA-256 for each is `0acf63997e8f96d69681196e1fe1a906d7350f69c2f3087e3deeba3a2dae1e7f`. [Stable protocol][ts-protocol], [dependency protocol][dep-protocol].
- The browser `derp/derphttp/websocket.go` source is identical at both revisions. Browser/JS builds select WebSockets; the client requests the `derp` WebSocket subprotocol and carries binary messages through `wsconn.NetConn`. The inspected `net/wsconn/wsconn.go` files also match byte-for-byte (SHA-256 `52e07e374027a69fe5475e821799d8ece6d453d9b13da28b0263e23bb3c35736`). [Dependency WebSocket client][dep-ws], [stable WebSocket client][ts-ws-client], [dependency wsconn][dep-wsconn], [stable wsconn][ts-wsconn].
- Comparing `derphttp_client.go` found only a bounded error-response read and revised error text in stable, not a change to successful connection negotiation. Native clients send `GET /derp` with `Upgrade: DERP` and `Connection: Upgrade`; the JS path uses the WebSocket dialer and then the DERP client. [Dependency HTTP client][dep-http], [stable HTTP client][ts-http].
- Selected `cmd/derper` explicitly wraps `derpserver.Handler(s)` with `derpserver.AddWebSocketSupport(s, handler)` at `/derp`. This is already in upstream stable; no custom WebSocket patch is indicated by this source inspection. The wrapper recognizes `Upgrade: websocket` plus the `derp` subprotocol, accepts cross-origin requests via `OriginPatterns: ["*"]`, disables compression, and passes binary traffic to the same DERP server. Native requests pass through to the base handler. [Route wiring][derper], [WebSocket handler][ts-ws-server], [native handler][ts-handler].

**Inference, not runtime proof:** the selected stable relay is a defensible compatibility baseline. Matching framing and handler negotiation cannot prove browser trust-store behavior, reconnect timing, packet forwarding, or the exact Tailcat application flow. In particular, HTTP `101` alone does not prove the DERP authentication/packet exchange completed. Browser-origin access accepted by the handler is also not an access-control policy.

## derper flags, routes, identity, and ports

**Verified flag contract** for selected source (values below are defaults or synthetic examples, not deployment configuration):

| Flag | Relevant behavior |
| --- | --- |
| `-a :443` | Defaults to all interfaces, TCP 443. TLS is selected for the production-443 address condition **or whenever `-certmode=manual`**, including a different TCP port. |
| `-hostname relay.example.com` | Selects certificate filename and exact expected DNS SNI in manual mode. Explicitly set it. |
| `-certmode manual` / `-certdir /certs/current` | Uses operator-provided files; no built-in ACME challenge service in this mode. |
| `-http-port -1` | Disables additional HTTP listener. Default is 80. DNS-01 issuance does not require it. |
| `-stun=true` / `-stun-port 3478` | Enables a separate UDP STUN listener; true/3478 are defaults. `-stun=false` disables it. |
| `-derp=true` | Enables packet relay; true is default. Probe routes still exist when false. |
| `-c /state/derper.json` | Explicit persistent relay-key configuration location. |
| `-verify-clients=false` | Default; required for the ordinary accountless Tailcat model described below. |
| `-verify-client-url` | Optional custom admission endpoint, distinct from local tailscaled verification; leave unset for the baseline. Its failure-open option defaults true. |
| `-home blank` | Optional blank root page. This is presentation behavior, not authentication. |
| `-disallow-app-names` | Optional blocklist; do not block Tailcat app names if Tailcat is intended to connect. |

All flag entries above derive from [flag definitions and server startup][derper]. STUN uses `net.ListenUDP`, not TCP and not a WebSocket endpoint. The listener host is derived from `-a`. Its startup is launched in a goroutine without checking the returned `ListenAndServe` error in `main`; successful HTTPS probes therefore do not establish a working STUN socket. [STUN source][stun], [startup][derper].

**Verified route/health semantics:**

| Route | Behavior and limitation |
| --- | --- |
| `/derp` | Actual upgrade endpoint. An ordinary non-upgrade request returns **426**. A successful native non-fast-start handshake responds **101**, then carries DERP. Browser mode is real WebSocket framing. |
| `/derp/probe`, `/derp/latency-check` | GET/HEAD yield an empty **200** with `Access-Control-Allow-Origin: *`; other methods yield **405**. These support latency measurement, including clients lacking UDP, and remain present with DERP disabled. |
| `/generate_204` | **204** captive-portal response; not an end-to-end relay test. |
| `/bootstrap-dns` | Bootstrap-name service; not a DERP map endpoint and not an ACME DNS authority. |
| `/debug/check` | **200** with a consistency message or **500** for internal consistency failure; access-controlled debug route. |
| `/debug/vars`, `/debug/varz` | Go/Prometheus metrics through `tsweb.Debugger`; debug access restrictions apply. |
| `/healthz` | No dedicated route registered in the inspected startup. Do not specify it as a supported health API. |

Sources: [routing][derper], [probe/native handler][ts-handler], [debug routes][ts-debug], [debug access policy][ts-web]. Debug access allows certain local/Tailscale/trusted addresses or an explicitly configured debug key; loopback inside a container and traffic arriving through a host bridge are not necessarily equivalent. **Proposed:** use a hostname/SNI-valid HTTPS request to `/derp/probe` for limited listener liveness, then separately verify real relay traffic and STUN. Do not use `-k`/disabled TLS verification as the normal certificate health check. Acceptance design remains with the parent.

**Persistent identity:** `-c` names a JSON document containing `PrivateKey`, not the TLS PEM private key. Missing files cause a new `key.NodePrivate` to be generated and atomically written with mode `0600`. Existing JSON is read at startup; malformed JSON fails startup. Without `-c`, root defaults to `/var/lib/derper/derper.key`, while non-root exits. Development mode creates an ephemeral key. **Proposed:** use an explicit persistent directory, restrictive ownership, no `-dev`, and preserve the relay configuration across certificate renewals/container replacement. Directory creation in upstream uses `0777` subject to umask, so the specification should not assume the directory is private merely because the key file is `0600`. [Configuration implementation][derper].

**Why local `verify-clients` conflicts with accountless Tailcat:** when enabled, derper calls local tailscaled `WhoIsNodeKey` for each non-mesh client's node key and rejects an unknown peer or lookup failure. Accountless Tailcat node keys are not enrolled as peers of that tailscaled tailnet. Merely installing tailscaled beside derper does not solve this. A separately designed admission controller could implement another policy, but it is neither necessary for protocol compatibility nor included here. With both verification mechanisms disabled, a reachable relay is not account-restricted; the parent must express the intended private reachability separately. [Verification function][ts-server], [Tailcat accountless model][tc-readme].

STUN assists native endpoint discovery/NAT traversal; DERP relay traffic itself uses TCP/TLS. The browser path can operate without UDP and uses HTTPS probes for latency. DNS-01's lack of inbound challenge ports does not imply that intended relay clients need no path to the relay. No host exposure, firewall, or DERP-map values are selected here. [Tailcat transport overview][tc-readme], [probe rationale][ts-handler], [STUN implementation][stun].

## Manual certificate contract and restart requirement

**Verified:** for `-hostname relay.example.com`, derper expects exactly `relay.example.com.crt` and `relay.example.com.key` beneath `-certdir`. The name is constructed by removing characters outside ASCII letters, digits, hyphen, and dot. Use an ordinary lowercase DNS hostname; do not assume wildcard output names or case variants map automatically. The certificate may contain additional SANs, but the selected hostname must verify against the leaf. [Manual manager][derper-cert].

The `.crt` must contain PEM certificate blocks, **leaf first, then intermediates**; `.key` must contain a supported unencrypted PEM private key matching the leaf. Go's loader checks the public/private key match, and derper additionally calls `VerifyHostname`. Neither this loader nor the manual manager establishes full public trust or current validity simply by successfully loading the files. Validate chain trust, dates, and expected names before publication. [Go TLS loader][go-tls], [manual manager][derper-cert].

The manual manager loads the pair **once during construction**, stores it in memory, and returns copies of that cached certificate from `GetCertificate`. It does not watch files, poll mtimes, or reread at handshake time. For a DNS hostname, the callback rejects a ClientHello whose SNI does not exactly equal the configured hostname, including an empty SNI. A health probe to an IP literal with only an HTTP `Host` header is insufficient. [Manual manager][derper-cert].

**Verified reload limitation:** replacing files, switching a symlink, or changing their timestamps will not refresh a running manual-mode server. The SIGHUP watcher in selected derper reloads **rate configuration**, and is only started when a rate-config path is set. It is not a certificate reload facility. **Proposed:** restart the derper process after a validated change. Existing relay connections cannot survive that process replacement; reconnect behavior and interruption duration remain untested. Routine renewal/no-op/failure should not stop it. [Manual cache][derper-cert], [SIGHUP/startup][derper].

The relay appends a DERP metadata certificate to the served TLS chain through `ModifyTLSConfigToAddMetaCert`, using a copy rather than mutating the manual manager's chain. Therefore, a deployed TLS chain may contain this additional certificate beyond lego's stored chain. **Proposed:** compare the served **leaf fingerprint** with the candidate leaf to confirm activation, and independently validate browser/system trust; do not expect raw served-chain bytes to equal the stored `.crt`. [TLS metadata wrapper][ts-server].

## lego v5 contract, Cloudflare credentials, and DNS visibility

**Verified major-version distinction:** v5.6.0's CLI has `run` for **both initial obtain and renewal**. There is no top-level `renew` command in the inspected command registry. `run` chooses obtain when no certificate resource is loaded, otherwise renewal. Most operational flags belong after `run`. Consequently, a v4 recipe such as `lego ... renew --days ...` must not be carried into this pin. [Command registry][lego-root], [run selection and certificate ID][lego-run], [flag definitions][lego-flags], [official usage][lego-obtain-doc].

**Proposed invocation contract only; not executed:** a one-shot service whose entrypoint is `lego` can use the equivalent of:

```text
lego run --path /lego --dns cloudflare --domains relay.example.com
  --cert.name relay.example.com --key-type ec256 --accept-tos
```

The line wrap is illustrative, not shell syntax. Production ACME directory/contact policy and staging separation belong in explicit operator configuration. `--path` persists ACME account material and certificate resources; do not persist only the two files handed to derper. `--cert.name` makes the output ID unambiguous; otherwise the first requested domain is used. `ec256` is the selected source's default as well as the proposed explicit key type. No issuance was attempted. [Run lookup][lego-run], [flags][lego-flags], [names of flags][lego-flag-names].

**Verified minimal provider permissions:** Cloudflare's lego provider needs zone lookup plus DNS record creation/deletion. Use `Zone / Zone / Read` and `Zone / DNS / Edit`, scoped to the single required zone, `example.com` in this document. One token can carry both permissions and be supplied as `CLOUDFLARE_DNS_API_TOKEN`; an alternative is separate read and edit tokens through `CLOUDFLARE_ZONE_API_TOKEN` and `CLOUDFLARE_DNS_API_TOKEN`. No account-wide Global API Key is required. These are zone-level permissions; do not claim the token is limited to one `_acme-challenge` TXT record. [Pinned provider][lego-cf], [provider API separation][lego-cf-wrapper], [lego Cloudflare documentation][lego-cf-doc], [Cloudflare token resource scoping][cf-token-doc].

**Verified file secrets:** `CLOUDFLARE_DNS_API_TOKEN_FILE=/run/secrets/cloudflare_dns_api_token` is supported, as are the optional zone-token `_FILE` variable and `CF_*` aliases. `GetOrFile` uses a nonempty direct environment value before its `_FILE`, reads the file, and removes trailing CR/LF, not arbitrary whitespace. An unreadable secret file logs a warning and resolves to an empty value. The provider first tries the legacy email/API-key pair before token configuration. **Proposed:** supply only intended token `_FILE` variables, mount their files only into lego, and omit stale direct token/legacy variables. This avoids accidental precedence and keeps DNS credentials out of derper. [Provider credential selection][lego-cf], [environment resolution][lego-env].

**Verified DNS-01 property:** the CA validates a TXT record at `_acme-challenge.relay.example.com`; it does not connect to the relay's HTTP/TLS listener for this challenge. A private web/relay endpoint can therefore obtain a public certificate without inbound WAN TCP 80/443 for validation. The client still needs outbound ACME HTTPS, Cloudflare API HTTPS, and appropriate DNS resolution/authoritative queries. Public authoritative DNS must be reachable by the CA. [Let's Encrypt DNS-01 documentation][le-challenges], [lego provider][lego-cf].

**Public authority versus split DNS:** private A/AAAA answers for `relay.example.com` may direct intended clients to a private address, while the public authoritative zone exposes the ACME TXT record. A TXT record present only in an internal split-DNS view is insufficient. Cloudflare must actually host the public authoritative zone or a deliberately delegated challenge target; being only the registrar or containing an unused zone copy is insufficient. Let's Encrypt supports CNAME/NS delegation of challenge names. Delegation is optional and its exact operation with the chosen provider remains a runtime verification item. [Let's Encrypt DNS validation/delegation][le-challenges], [provider zone lookup][lego-cf-wrapper].

**Version-specific propagation behavior:** lego v5.6.0 checks both recursive and authoritative nameservers by default. It first resolves any challenge CNAME, then checks the expected TXT at recursive servers and authoritative servers. `--dns.resolvers` controls recursive resolution, apex discovery, and propagation checks; choosing a public-view resolver does **not** turn authoritative queries off. Split-horizon SOA/NS/TXT answers and restricted authoritative DNS egress can therefore break prechecks even when the provider API succeeded. Keep propagation checks enabled; select resolvers that see public delegation rather than hiding the problem with check-disable flags. Cloudflare defaults include a 120-second TTL, two-minute propagation timeout, and 30-second HTTP timeout; actual DNS behavior must be measured before adjusting them. [Precheck][lego-dns-precheck], [nameserver queries][lego-dns-ns], [resolver flags][lego-flags], [provider defaults][lego-cf].

## Output files, renewal outcomes, and change detection

**Verified output:** under `/lego/certificates`, certificate ID `relay.example.com` yields `.crt`, `.key`, `.issuer.crt`, and `.json`. The `.crt` contains the leaf and issuer chain by default (`Bundle: !no-bundle`); `.issuer.crt` is issuer material, not the server leaf. Generated RSA/ECDSA private keys are unencrypted PKCS#8 PEM (`PRIVATE KEY`) in this lego version. Additional `.pem`/`.pfx` outputs are optional and unnecessary for derper. Preserve default bundling and copy `.crt` plus `.key` to derper's expected hostname filenames. Do not append `.issuer.crt` again to an already bundled `.crt`. [Storage names][lego-storage], [writer][lego-writer], [bundle option][lego-setup], [chain handling][lego-chain], [key encoding][lego-crypto], [official output description][lego-obtain-doc].

**Verified storage is not pair-transactional:** lego writes certificate, issuer, private key, and JSON resource sequentially with `os.WriteFile`, mode `0600`; newly created storage directories use `0700`. A failure can leave partially updated state. It does not publish an atomic certificate/key generation. Derper must not consume this mutable ACME work directory directly. Existing-file modes also require deliberate ownership/permission management; the proposed host publisher must arrange readable but restricted files for derper's UID/GID. [Writer][lego-writer], [storage directory creation][lego-storage].

**Verified renewal decision and status:**

- Not due: renewal returns `nil` before obtain/save/deploy hook. CLI success is therefore also a no-op success. [Renewal implementation][lego-renew].
- Due: ARI may trigger renewal; otherwise the default lifetime-based threshold is one-third remaining, or one-half for certificates whose rounded lifetime is at most ten days. The code falls back to this threshold when ARI provides no actionable renewal time; do not describe ARI as an unconditional veto. Explicit `--renew-days`, `--renew-force`, configuration changes, and domain changes alter decisions. [Renewal algorithm][lego-renew].
- Noninteractive renewal can sleep randomly for up to eight minutes. `--ari-wait-to-renew-duration` can additionally permit an ARI-directed wait; its CLI zero value means no extra configured wait. Scheduler timeouts must allow the chosen delay/timeout policy. Do not assume a hard-coded 90-day certificate lifetime or force renewal every scheduled run. [Renewal timing][lego-renew], [flags][lego-flags].
- Obtain, validation, storage, or deploy-hook errors propagate to the CLI and ordinarily exit **1**. Successful CLI completion exits **0**. ARI-fetch problems may instead log warnings and fall back, and deferred post-hook errors are ignored by this renewal path. Thus logs, exit status, changed files, and successful service activation are different facts. [Main][lego-main], [fatal exit][lego-log], [renewal][lego-renew], [hook manager][lego-hooks].
- A deploy hook is called after successful storage and only on effective obtain/renew, but can itself fail after files changed. A post hook runs after attempted work even when it fails. Neither is a reason to give lego a Docker socket. [Renewal ordering][lego-renew], [hook behavior][lego-hooks].

**Proposed change detection:** require successful one-shot completion and a fully validated output pair, then compare a digest over both published file contents with the candidate pair (use unambiguous framing or two separate hashes). Do not use mtime, log text, private-key change alone, JSON resource changes, or exit zero as the renewal signal. Key reuse is supported, so a renewed certificate can have the same private key. Include the full chain in the stored digest so an intermediate-chain change can trigger activation too. Keep private-key digests in restricted state; do not log key contents. [Key reuse and save behavior][lego-renew], [output writer][lego-writer].

Compare candidates with the **last successfully activated generation**, not only with lego's files immediately before this run. This matters if a preceding run obtained a certificate but publication/restart failed: the next ACME run can legitimately be a no-op while that certificate still needs activation. Track issued, published, and activated states separately. This is a proposed recovery invariant, not functionality supplied by lego.

## Proposed host-controlled lifecycle

**Design disposition:** the final [architecture](../architecture.md) and [operations specification](../operations.md) select literal immutable-generation bind mounts for each TLS consumer, rather than the moving `current` symlink illustrated below. That is the immutable-reader alternative in step 7: each Docker restart reads one complete generation, and activation recreates containers with new literal mounts. The following sequence records the investigated alternative and its safety constraints; it is not a second competing implementation requirement.

This is a specification-level proposal, **not implementation or deployed configuration**. Keep derper continuously running during ACME work; a changed certificate requires a bounded process replacement. A single manually loaded derper process cannot promise zero interruption during activation. No container gets the Docker socket.

1. **Separate state and permissions.** Persist relay identity separately from ACME account/certificate state. Keep a host-owned published-certificate tree containing immutable generation directories and a `current` relative symlink. Give derper read-only access to the stable parent tree, and lego write access only to its ACME work state plus read-only DNS token secrets. Do not bind-mount individual replaceable cert files or the resolved `current` target and then assume changing a host symlink retargets that mount. Exact Compose mounts, ownership and startup supervision are for the parent to implement and verify.
2. **Serialize all lifecycle operations.** A host lock covers initial obtain, renewal, candidate validation, publication, activation, rollback, and boot/manual reconciliation. Only the host orchestrates Docker. Use a foreground one-shot equivalent to `docker compose run --rm --no-deps -T lego …`, with a fixed project/config context and approved pinned/local image policy. This is an invocation shape, not a command run here. Docker documents that `run` creates a separate one-off container, does not publish service ports by default, and supports dependency suppression/removal. [Compose run][compose-run].
3. **Retain recoverable ACME state.** Before mutation, retain a restricted last-consistent snapshot of account/resource/certificate state, or run against a recoverable working generation. A failed/incomplete lego save must not become input for publication merely because some files changed. On failure preserve the active relay generation, record failure, and reconcile damaged ACME state before retrying; do not delete account/resource files and blindly issue a new certificate. The v5 `run` path treats a missing/unreadable resource path differently from invalid JSON, so careless state loss can select issuance. [Run dispatch][lego-run], [resource reader][lego-reader], [sequential writer][lego-writer].
4. **Bootstrap explicitly.** If no active certificate exists, obtain and validate one before starting derper. Never start DNS-hostname manual mode expecting it to request a certificate, and do not hide failure with a dummy/self-signed production certificate. Keep staging ACME state and outputs separate; never publish a staging-chain certificate into the production relay tree. If a valid active generation already exists, an ACME failure must not prevent that generation from serving.
5. **Validate a complete candidate.** After lego exits successfully and has stopped writing, copy both files into a fresh unpublished generation. Parse all PEM blocks, require leaf-first chain, verify matching key, intended SAN/hostname, server usage, current validity and an appropriate remaining-validity margin, and validate the chain against the intended trust roots. Reject unexpected input types/paths and arrange final permissions. Do not infer trust/expiry from derper's successful `LoadX509KeyPair`. [Loader boundary][go-tls], [manual checks][derper-cert].
6. **Decide whether activation is needed.** If validated candidate content equals the successfully activated pair and the expected process is serving it, do nothing. Otherwise prepare a durable transaction record with old/new generation identifiers and a pending activation state. This also handles pending activation from an earlier failed run without forcing another ACME order.
7. **Exclude readers during the switch.** Go opens the certificate and private-key paths separately. Even a single atomic `current` switch can fall between those reads if derper starts concurrently. For this unmodified derper, the conservative activation sequence is: validate while the old relay runs; mark pending; stop derper and confirm it has exited; switch `current`; start derper while publication remains locked. Boot/manual recovery must use the same coordination, and no automatic start should race the switch. This is a brief stop/start activation, not a stop for the duration of DNS validation. A design that keeps a reader running through publication must instead guarantee it resolves and uses one immutable generation for both reads. [Separate loader reads][go-tls], [startup-only cache][derper-cert].
8. **Publish the pair and start the process.** Before stopping the old process, flush the new files and directory and prepare a relative `current.next` symlink to that generation on the same filesystem. Once step 7 has confirmed the old process has exited, atomically rename it over `current`; flush the parent directory for crash durability. Start derper while publication remains locked. Two independent renames of `.crt` and `.key` are not an atomic pair operation. Linux rename atomically replaces a symlink directory entry; fsync of a file alone does not guarantee durability of the directory entry. [Linux rename][rename-doc], [Linux fsync][fsync-doc].
9. **Verify activation, then commit state.** Require a fresh TLS handshake using `relay.example.com` SNI, validate trust/name/time, compare the served leaf with the candidate, and check the probe response. Mark the generation activated only after these succeed. If startup/verification fails, stop the failing instance, atomically restore the previous known-good generation, and start/verify it; keep the renewal job failed and report the error even if rollback succeeds. A previous generation that has expired is not a successful rollback. Keep the persistent relay key unchanged throughout.
10. **Recover interruption explicitly.** Reconcile pending transactions at boot and before the next scheduled run. If the pointer switched but activation was never confirmed, start/verify the candidate or restore the valid old generation; if the container was stopped before the switch, restore service. Do not trust a marker alone as evidence of the leaf currently served. Never automatically discard the only working generation or restart the relay on every no-op.

Certificate generation identifiers, filesystem paths, and service names above are illustrative contracts. Their crash-recovery implementation and Docker bind-mount behavior are **untested**.

**Proposed systemd scheduling:** a host `Type=oneshot` service runs the entire locked transaction, with a calendar timer several times daily, randomized delay, and `Persistent=true`. Use `RemainAfterExit=no` so future activations occur. Set a bounded timeout long enough for lego's configured random wait, DNS propagation, ACME work, and verification; define cancellation cleanup so killing the host CLI does not leave an untracked lego container writing state. Network readiness ordering is useful but not evidence of remote reachability. Preserve job failures, report expiry independently, and retry on subsequent timer activations rather than restarting derper after an ACME failure. systemd does not start another instance when the target service is already active, but the host lock is still needed for manual invocations and recovery. `Persistent=true` catches missed calendar activations after downtime; it is not continuous execution while the host is down. [systemd timer][systemd-timer], [oneshot semantics][systemd-service].

## Explicit runtime uncertainties and parent handoff

No runtime behavior was exercised. The following remain **untested**, even where source support is strong:

- Native pinned Tailcat and browser/WASM Tailcat completing DERP handshakes and bidirectional forwarding against v1.104.7; browser certificate trust and the actual app-origin/network policy. Handler compatibility does not substitute for the parent's browser integration work.
- Reconnection and session/application interruption during certificate activation; no zero-downtime claim is made.
- STUN socket availability and request/response behavior independent of HTTPS liveness; IPv4/IPv6 binding and selected network exposure.
- ACME staging and production issuance/renewal, actual CA-provided chain/lifetime/ARI behavior, Cloudflare least-privilege token scope, secret-file permissions, public delegation and split-DNS resolver behavior. No token or real domain was used.
- Host-side validator/tool availability and correctness, clock synchronization, trust roots, Linux filesystem rename/fsync behavior, ownership mappings, mount visibility, and process-start serialization on the actual Docker host.
- Success/no-op/failure handling, partial lego state writes, pending activation retry, host reboot at each transition, rollback, timer timeout/cancellation, expiry alerting, and storage exhaustion.
- Actual host systemd/Compose versions and image/compiler reproducibility. The inventory pins source revisions, not built-image digests or approved deployments.

The parent can use these findings to define architecture and acceptance work. The critical specification requirements are the manual-certificate restart, stable-vs-prerelease compatibility boundary, lego **v5** command semantics, public DNS-01 visibility, separate mutable/active certificate state, and activation based on validated changed content rather than a successful renewal command alone.

## Primary-source references

[tc-commit]: https://github.com/tailscale/tailcat/commit/e00cdde6ff787f801361ff85ed085775c775d4c5
[tc-mod]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/go.mod
[tc-readme]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/README.md
[tc-source]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/tailcat.go
[dep-commit]: https://github.com/tailscale/tailscale/commit/fb79793d99f5ccedabe1ab428f0af852f49d0c62
[dep-protocol]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/derp/derp.go
[dep-client]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/derp/derp_client.go
[dep-http]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/derp/derphttp/derphttp_client.go
[dep-ws]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/derp/derphttp/websocket.go
[dep-wsconn]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/net/wsconn/wsconn.go
[ts-release]: https://github.com/tailscale/tailscale/releases/tag/v1.104.7
[ts-commit]: https://github.com/tailscale/tailscale/commit/cbc74fe48ef1b1649f69a4d9a602319427e25102
[release-apis-ts]: https://api.github.com/repos/tailscale/tailscale/releases/latest
[ts-mod]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/go.mod
[ts-protocol]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derp.go
[ts-http]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derphttp/derphttp_client.go
[ts-ws-client]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derphttp/websocket.go
[ts-wsconn]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/net/wsconn/wsconn.go
[derper]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/cmd/derper/derper.go
[derper-cert]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/cmd/derper/cert.go
[ts-handler]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derpserver/handler.go
[ts-ws-server]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derpserver/websocket.go
[ts-server]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derpserver/derpserver.go
[ts-debug]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/tsweb/debug.go
[ts-web]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/tsweb/tsweb.go
[stun]: https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/net/stunserver/stunserver.go
[go-commit]: https://github.com/golang/go/commit/7b2881024c95a11ddb86663a616340aa3a88b67f
[go-tls]: https://github.com/golang/go/blob/7b2881024c95a11ddb86663a616340aa3a88b67f/src/crypto/tls/tls.go
[lego-release]: https://github.com/go-acme/lego/releases/tag/v5.6.0
[lego-commit]: https://github.com/go-acme/lego/commit/226c09fbe704ea412bea76cb268414f67686be1d
[release-apis-lego]: https://api.github.com/repos/go-acme/lego/releases/latest
[lego-mod]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/go.mod
[lego-root]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/cmd_root.go
[lego-run]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/cmd_run.go
[lego-flags]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/flags/flags.go
[lego-flag-names]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/flags/names.go
[lego-renew]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/cmd_run_renew.go
[lego-cf]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/providers/dns/cloudflare/cloudflare.go
[lego-cf-wrapper]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/providers/dns/cloudflare/wrapper.go
[lego-env]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/platform/env/env.go
[lego-storage]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/storage/storage_certificates.go
[lego-writer]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/storage/storage_certificates_writer.go
[lego-reader]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/storage/storage_certificates_reader.go
[lego-setup]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/setup.go
[lego-chain]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/acme/api/certificate.go
[lego-crypto]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/certcrypto/crypto.go
[lego-hooks]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/cmd/internal/hook/manager.go
[lego-main]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/main.go
[lego-log]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/log/logger.go
[lego-dns-precheck]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/challenge/dns01/dns_challenge_precheck.go
[lego-dns-ns]: https://github.com/go-acme/lego/blob/226c09fbe704ea412bea76cb268414f67686be1d/challenge/dns01/client_nameservers.go
[lego-cf-doc]: https://go-acme.github.io/lego/dns/cloudflare/
[lego-obtain-doc]: https://go-acme.github.io/lego/obtain/
[cf-token-doc]: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/
[le-challenges]: https://letsencrypt.org/docs/challenge-types/
[compose-run]: https://docs.docker.com/reference/cli/docker/compose/run/
[systemd-timer]: https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
[systemd-service]: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html
[rename-doc]: https://man7.org/linux/man-pages/man2/rename.2.html
[fsync-doc]: https://man7.org/linux/man-pages/man2/fsync.2.html
