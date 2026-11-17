# Certificate lifecycle and operations specification

Status: proposed behavior only. Nothing in this runbook has been executed against infrastructure. Use [architecture](architecture.md) for service/configuration choices and [upstream certificate evidence](research/relay-certificates.md) for version-specific facts.

## State and invariants

Host configuration lives outside Git under `/etc/derp-stack`; writable state under `/var/lib/derp-stack`. Proposed state subdivisions:

| State | Owner and purpose |
| --- | --- |
| `relay/derper.json` | UID 10001, mode 0600; persistent relay identity, independent of TLS |
| `acme/production/` and `acme/staging/` | UID 10003, 0700; separate account keys, registrations, certificate resources and output |
| `acme-snapshots/` | Restricted host-only recoverable copies; never a relay mount |
| `tls/generations/<opaque-id>/` | Immutable validated `.crt`/`.key` pair; root:10004, 0750/0640 |
| `activation/` | Root-only transaction journal, selected generation/image/map revisions, last successful activation, generated local Compose override |
| `map/` | Root-owned local rendered map, read-only to map service |
| `diagnostics/` | Restricted local results only, bounded retention |

The runtime Compose override binds a literal generation directory to `/certs` in each TLS consumer. It never mounts mutable lego output or resolves a moving `current` link inside a container. No generation directory is modified after validation. Only the pair is mounted; ACME accounts and Cloudflare secrets stay out. The small amount of host activation state may use atomic pointer/manifest replacement, but each running or restarting container keeps one immutable generation until explicitly recreated. This chooses the immutable-reader alternative described in the research and avoids a symlink race between separate cert/key reads.

The lock `/run/lock/derp-stack-lifecycle.lock` covers bootstrap, all certificate attempts, publication, service recreation, rollback, upgrades and restore. Use a host `flock` or equivalent kernel lock; never rely on an ordinary PID file. Scheduled contention skips with a recorded busy state, manual operations can wait up to a bounded deadline. Killing the lock holder must release the lock, but orphan one-shot containers must also be stopped/verified before a new ACME writer starts. Use fixed Compose project/config paths and root-owned executable/config files; no caller-controlled project or path interpolation.

Maintain distinct **issued**, **validated**, **selected**, and **activated** states. A successful lego exit or changed mtime is not activation. An active TLS leaf must be verified on both ports. The full certificate-chain bytes plus key bytes define a generation, with separate hashes in restricted state; public evidence never includes key hashes or key material. Never overwrite the last known-good pair during issuance.

## Initial issuance

1. Preflight the selected platform, exact locked images, clock, disk space, permissions, private DNS from both endpoints, approved firewall rules and DNS/HTTPS egress. Validate local configuration and Cloudflare token-file readability inside only the intended one-shot service. Do not print secrets or expanded Compose configuration.
2. Verify public NS/SOA/CAA behavior independently of UniFi. Use explicit public recursive resolvers for lego propagation checks and allow its authoritative queries; never disable propagation checks to hide split-DNS failures. Public TXT visibility is the ACME requirement. No inbound WAN listener is needed. [DNS and provider evidence](research/relay-certificates.md#lego-v5-contract-cloudflare-credentials-and-dns-visibility).
3. Test the flow using staging directory, separate state and test TLS endpoint. Do not install staging roots into ordinary browsers or activate staging output on production listeners. Staging/production differ in ACME directory, account/state and trust validation policy.
4. When actual deployment is authorized, use lego **v5.6.0 `run`**, with explicit path, Cloudflare DNS provider, domain, certificate name equal to hostname, `ec256`, directory URL and ToS acceptance. This version uses `run` for issuance and renewal, not v4's `renew` command. ACME contact registration, when configured, stays local. Before implementation freezes commands, exercise this exact version's CLI help and staging flow. [v5 contract](research/relay-certificates.md#lego-v5-contract-cloudflare-credentials-and-dns-visibility).
5. If issuance fails, leave the stack unbootstrapped and report failure; do not substitute a self-signed certificate. If valid service already exists, failure leaves it serving. Recover the ACME state as described below.
6. Successful output produces `<hostname>.crt`, `.key`, `.issuer.crt` and `.json` under lego's certificate directory. Default `.crt` is already bundled. Stage only `.crt` and `.key` for derper/map; keep all ACME resources in persistent ACME state. Never duplicate the issuer chain by appending it again.
7. Validate and activate using the transaction below, then enable renewal and expiry monitoring. Initial startup is successful only when both TLS ports serve trusted matching leaves and actual relaying passes its separate acceptance gate.

## Renewal schedule and change detection

Proposed host units: `derp-stack-renew.service` (`Type=oneshot`, no `RemainAfterExit`) and a calendar timer at 00:00, 06:00, 12:00 and 18:00 UTC with up to 15 minutes jitter and `Persistent=true`. Use a 30-minute overall job timeout, zero additional configured ARI wait, and bounded DNS/API timeouts. Selected lego can itself wait randomly up to eight minutes during noninteractive renewal; include that in the budget. Start after Docker/network readiness; those dependencies do not prove external services are reachable. [lego renewal evidence](research/relay-certificates.md#lego-v5-contract-cloudflare-credentials-and-dns-visibility), [systemd timers](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html).

Each attempt runs a foreground one-shot container with no service ports/dependencies and removes it when complete. The host records its exact container ID locally and guarantees cancellation cleanup before another writer. Containers never control Docker. No deployment hooks run inside lego. Preserve the CLI failure status even if cleanup succeeds.

Use lego's ARI/lifetime-aware decision, not forced renewal on every timer. A zero exit may mean not due. On failure retain the active generation, record a sanitized error category, retain/recover consistent ACME state and retry at the next six-hour activation. Do not retry a rate-limited order in a tight loop; honor Retry-After where reported. Operator-triggered retry uses the same lock. Unchanged output produces **zero service recreations**. If a previously issued valid candidate still awaits activation, a later no-op ACME run may correctly trigger that pending activation; classify it separately from a renewal no-op.

Before running lego, take a recoverable restricted snapshot of consistent ACME account/resource/certificate state. A failed run can leave sequential partial writes. On failure quarantine the work result, restore the consistent state after stopping the writer, and record whether an order might have succeeded remotely. Do not delete account/resource state to force issuance. For an ambiguous post-order storage failure, inspect/reconcile order resources before a new order and report the uncertainty; avoid automatic repeated issuance. Keep the prior service untouched. Treat disk-full/invalid JSON as recovery faults, not permission to issue afresh.

## Validate, publish, activate, roll back

The future publisher must implement the following transaction and expose fault-injection points for each durable step:

1. Acquire lock; recover any previous pending transaction or orphan writer. Check sufficient disk/inodes and trusted system time. Read expected active generation and actual container configuration. Verify any already-running service before deciding an activation is necessary.
2. After successful lego completion, copy candidate output into a new unpublished directory on the same filesystem as generation storage. Reject symlinks, nonregular files, path traversal and extra unexpected content. Bound file sizes (1 MiB certificate chain, 64 KiB key proposal).
3. Validate PEM parsing; leaf-first chain; matching private/public key; exact configured DNS hostname; server authentication usage; valid current dates; chain against production trust roots; and remaining lifetime. For a newly published certificate require at least 24 hours remaining and at least one-quarter of its actual lifetime; do not assume 90 days. Reject staging chains under production policy. Existing valid generations may continue below this new-publication threshold while urgent renewal is attempted.
4. Compare complete pair content to the activated generation. Same pair and same served leaves: record healthy no-op, keep container IDs/start times unchanged. Changed chain with the same leaf/key is still a changed generation. A leaf check alone does not prove full-chain activation; also record the exact new container mount/config generation and validate its trust.
5. Set final ownership/modes, flush files and directory, atomically rename the staging directory to an opaque immutable generation name and flush its parent. Write/flush a pending transaction containing old/new generation, exact image set and per-service activation progress. No service has been stopped yet.
6. Write and atomically select a root-only local Compose override that binds the literal new directory. Recreate map first, then derper using the already-built image set and no builds/pulls. Only these service recreations should occur. Each process loads a complete matching pair; Docker crash-restart may temporarily run the previous immutable configuration and cannot mix files. Hold the lifecycle lock throughout. A running derper ignores changed files; no SIGHUP certificate reload is assumed.
7. For each service require a new trusted TLS handshake to the hostname with correct SNI, matching served leaf fingerprint, correct container generation/mount and route response. Bound verification to 60 seconds after process start. Internal probes may dial loopback, but must set TLS ServerName and validate trust; an IP URL with only an HTTP Host header does not suffice. Derper appends metadata to its served chain, so compare the leaf rather than raw chain equality. [Manual TLS behavior](research/relay-certificates.md#manual-certificate-contract-and-restart-requirement).
8. On success atomically commit activated state and remove the pending marker. Retain at least the previous two successful generations and all currently mounted/pending generations; prune only under lock. Active-session disruption is expected when derper is recreated; measure it and report it locally.
9. On failure stop the failing new consumer, restore old immutable mount/image selections, recreate affected consumers and verify them. Rollback is successful only if the old certificate is still valid/trusted. Keep the lifecycle job failed and alert even if service recovery succeeds. Do not loop repeatedly between generations. If no valid fallback exists, report an outage and continue urgent recovery; never disable TLS verification.

Generation activation is atomic per consumer, not simultaneous across both ports. A brief interval with old and new valid certificates is acceptable; both identify the same hostname. No transaction promises zero outage or preservation of active Playwriter operations. Do not automatically replay a CDP command whose outcome is unknown after a transport break. Client integration must expose failure and permit explicit new sessions.

## Restart, reboot, extended outage and monitoring

Docker `unless-stopped` handles process crashes and daemon/VM restarts after successful initial creation. A deliberately stopped service stays stopped under that policy; host reconciliation honors a durable maintenance-stop marker so it cannot undo an operator stop. Boot reconciliation may restore a transaction-stopped service when no maintenance stop is recorded. Compose health failure alerts; it is not an automatic process-kill policy.

A host boot oneshot and periodic reconciliation recover pending state under the same lock. They must work without external ACME connectivity when a valid persisted generation exists. Inspect actual mounts/served certificates; markers alone are insufficient. Recover a crash before generation selection, after override selection, between map/derper recreation and after both start but before commit. Reuse a valid candidate instead of obtaining another certificate. Docker may briefly start an old immutable generation before reconciliation; it must still pass normal client certificate validation, and recovery is incomplete until the expected generation is verified.

After an extended outage, `Persistent=true` causes a missed timer activation to run; it cannot renew while the VM is off. If the stored certificate is expired, trusted clients correctly reject it. Restore clock/DNS/egress, attempt ACME renewal, validate and activate. Do not require the relay's own HTTPS health to succeed before ACME can repair it. Alert until recovery succeeds; no self-signed or public-relay fallback.

Run a separate hourly expiry/status job and at boot. Check both on-disk active leaf and fresh served leaves, timer last attempt/success, pending transactions, container state/health, disk space and unexpected restart counts. Warn when remaining lifetime is less than the larger of seven days or one-third of actual lifetime; critical at less than the larger of 48 hours or one-tenth. Also warn if no renewal job attempt completed in 12 hours. Thresholds need qualification against the actual CA profile; no fixed certificate lifetime assumption.

Write bounded structured status locally without domains, keys, descriptors or raw API responses in default summaries. A root-owned local alert command receives status categories and opaque generation IDs. Initial installation requires an operator-visible tested failure notification path; a failed systemd unit alone is insufficient if nobody observes it. An independent existing LAN/VPN monitor should report VM/service absence (a powered-off VM cannot alert about itself). Selecting the local alert destination and monitor is installation configuration, not a request to create external infrastructure in this phase.

## Installation and daily operation outline

1. Select a reviewed source/lock revision; inventory host compatibility locally; retain a rollback plan for any later host configuration changes.
2. Build all images locally or import verified local image archives. Check binary/source manifests, architecture and no embedded deployment data. No registry publication.
3. Create local configuration/secret/state directories with specified owners; render local map/profile; establish UniFi resolution and LAN/VPN firewall controls during the separately authorized deployment phase.
4. Exercise synthetic lifecycle tests and ACME staging; bootstrap production only after those gates pass and actual issuance is authorized.
5. Verify listener health, actual private relay traffic, no public fallback, reboot and expiry alerting. Enable routine timers and encrypted backup schedule.
6. Daily status reports separate process/listener health, map availability, certificate freshness, timer health and end-to-end canary result. A canary uses disposable keys/PSKs held only on endpoint test processes; do not mount endpoint keys into relay services.
7. Maintenance stop records intent under lock and stops daemon containers without deleting state. Start clears intent after validation. Direct uncoordinated Compose lifecycle actions are unsupported operating practice because they bypass the transaction, though immutable mounts still protect pair consistency.

## Upgrade, backup, restore and rollback outline

**Upgrade:** refresh source security/release review and explicitly update locks; never auto-follow upstream latest. Build/test new images locally before disturbing runtime. Snapshot state under lock, preserve old image IDs/archives, validate configuration compatibility, recreate only changed services and run native/browser canaries. Roll back image and compatible configuration if checks fail. Avoid unnecessary certificate issuance during software upgrades. Changing `versions.lock` does not itself authorize deployment.

**Backup:** encrypted local/offline or approved private backup target; daily baseline and before changes. Capture relay identity, ACME account/resources, active/previous TLS generations, local map/config/profile policy, activation journal, manifests/image archives and recovery instructions consistently under lock. Credential files may be separately escrowed or reprovisioned; document which, and test recovery without silently assuming a backed-up token. VM snapshots alone do not demonstrate application-consistent or off-VM recovery. Never put backups in GitHub artifacts/releases.

**Restore:** isolate a replacement VM from clients, verify backup integrity, restore ownership/modes, locked images and state, reconcile pending transactions, check time and certificate validity, and renew if needed. Verify identity continuity locally, TLS/map and relay canaries before routing clients to it. Keep the previous VM offline during identity reuse; do not run two uncoordinated copies. Record recovery time/data age locally.

**Rollback:** select previous verified image/config set and a still-valid TLS generation under lock. Retain current ACME account state unless there is explicit evidence of corruption; software rollback is not blanket restoration of stale ACME resources. If an expired prior certificate is the only alternative, renew or repair forward rather than claiming successful rollback.

## Troubleshooting guide

| Symptom | Checks, in order |
| --- | --- |
| Hostname unavailable | VPN route and DNS server, exact UniFi A answer from both endpoints, browser secure-DNS setting, no unexpected AAAA, TCP/firewall counters |
| Map fetch fails | Trust/SNI/clock, TCP 8443, exact path, selected profile digest, extension site access/CSP, OPTIONS/CORS headers, enterprise LNA policy; no security bypass |
| HTTPS probe passes but connection fails | `/derp` native upgrade vs WebSocket subprotocol, `-derp=true`, selected region/hostname, actual two-peer packet exchange, resource limits |
| Cloudflare authorization error | Token file mode/mount, direct-variable precedence, scoped Zone Read/DNS Edit, correct public authority; never print token |
| DNS propagation fails | Public recursive/authoritative TXT visibility and DNS egress, split-zone shadowing, stale records/delegation/CAA; retain checks |
| Renewal says success but leaf unchanged | May be a legitimate no-op; inspect candidate/activated pair hashes locally and pending state; never restart based on exit zero alone |
| New files but old served leaf | Manual-mode cache requires recreation; check immutable mount generation, transaction progress and correct SNI |
| Failure after outage | Clock, expired leaf, ACME state/egress, missed persistent timer, pending transaction and maintenance marker |
| Unhealthy but running | Docker health does not restart it automatically; inspect bounded local diagnostics and end-to-end check before coordinated restart |
| Secret/descriptor accidentally disclosed locally or publicly | Stop publication; revoke affected token or endpoint session, rotate exposed keys as appropriate, review history/artifacts; do not merely delete a working-tree file |

Only sanitized, allowlisted summaries leave the machine. Review raw diagnostics locally; exact operational identifiers and packet captures are not publishable evidence.
