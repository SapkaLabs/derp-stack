# Acceptance specification

**Every case below is NOT RUN.** This phase inspected source and wrote specifications only. Checkboxes must remain open until runtime evidence exists. Acceptance has two milestones: server stack qualification (S tickets), then Playwriter private integration (P tickets). Server completion alone is not a working Playwriter deployment.

## Evidence and prerequisites

Use a disposable test profile and harmless synthetic browser page. Capture exact source SHAs, image IDs, host/kernel/Docker/Compose versions, browser version/policies, Tailcat build manifest and timestamps **locally**. Never publish real configuration, hostname/IP inventory, PSKs, `tc…` addresses, certificates, keys, accounts, packet captures or raw logs. Publish only human-reviewed summaries using synthetic labels. Packet capture for path proof stays restricted and is deleted according to local retention policy.

Default target budgets are acceptance requirements to qualify, not measured results: initial private connection within 60 seconds, service listener recovery within 120 seconds of Docker/network readiness after reboot, certificate activation or successful rollback within 120 seconds after validated candidate publication, and explicit new session success within 60 seconds after relay recovery. Record actual durations locally; if a requirement cannot be met, change the design/requirement explicitly rather than reporting a pass.

Private path tests must monitor all relevant DNS and network destinations, not just UI labels. Map availability, relay health and end-to-end success are separate outcomes. For negative no-fallback tests, keep public Internet access available where practical while capturing traffic; a blanket Internet block alone cannot prove the client never attempted a public fallback. Also run a restricted-egress positive case allowing only the selected private map/relay plus necessary local services.

## Server stack qualification

### A01 — Repeatable local builds and safe artifacts (S01, S02, S03)

- [ ] Two clean builds from the same lock/source produce identical derper, lego and helper binary hashes; image manifest inputs and any metadata-only differences are explained. No build occurs during ordinary startup.
- [ ] Images run as selected numeric users, expose only selected ports, and contain no real config, token, account, certificate, key, inventory or session material. Missing local image fails without registry pull. No push/publication occurs.
- [ ] Wrong architecture, changed source/checksum and floating/missing build pins are rejected. All runtime images/CA roots/licenses are attributable to pinned inputs.
- [ ] A previous image archive loads and runs locally for rollback. Docker/Compose exact versions and iptables backend are recorded.

### A02 — Clean installation and permissions (S02–S06)

- [ ] Empty state boots through authorized staging validation and production issuance in order; missing certificate prevents daemon startup, not a self-signed fallback.
- [ ] Existing valid state starts when Cloudflare/ACME is unreachable, without renewal blocking service.
- [ ] Derper can create/read only its identity state and read its pair. Map can read only map/pair. Lego can read token and mutate only its ACME state. Neither persistent service can read the token or ACME account; no container can access the Docker socket.
- [ ] Incorrect ownership, missing bind directory, invalid hostname, unresolved placeholder, unsafe config path, low disk and clock error produce bounded actionable failures.
- [ ] Docker inspect confirms caps, read-only roots, no-new-privileges, memory/CPU/PID/file-descriptor limits and log bounds. Actual identifiers remain local.

### A03 — DNS, LAN/VPN isolation and firewall (S05)

- [ ] Browser and controller resolve the selected hostname to the intended private IPv4 through UniFi, including VPN routing and browser secure-DNS behavior. No unexpected IPv6 route/AAAA bypass exists.
- [ ] Approved LAN and VPN sources can reach TCP 443 and 8443. A disallowed same-subnet source and a disallowed routed source cannot reach either.
- [ ] WAN has no forwarding/UPnP exposure; IPv6 and unbound VM interfaces cannot access stack ports. TCP 80 and UDP 3478 remain closed. Direct container routing does not bypass policy.
- [ ] Repeat negative checks during Docker restart and VM boot with continuous probes; no permissive interval occurs. Verify counters on the intended forwarding/VM firewall path, not only an INPUT rule listing.
- [ ] Firewall changes are scoped to this stack and preserve unrelated authorized services and ACME/DNS response traffic.

### A04 — Real DERP interoperability and health boundaries (S02, S07)

- [ ] Pinned native Tailcat completes DERP negotiation and bidirectional payload exchange with another endpoint through selected v1.104.7 derper.
- [ ] Packaged browser/WASM completes `wss://<hostname>/derp` with `derp` subprotocol and exchanges data with the native endpoint. TLS trust is enabled. HTTP 101 alone is not a pass.
- [ ] Repeat with UDP unavailable at endpoints and relay; only TCP 443/8443 required. Record startup time to expose an unacceptable netcheck delay.
- [ ] Correlate disposable flow timing/byte counts between endpoint observations and relay diagnostics/capture; verify destination is the VM and exchanged synthetic payload matches. Force relay use by preventing endpoint-to-endpoint data routes in this test. Do not infer relaying merely from an established DERP socket; native Tailcat may support direct paths in other contexts.
- [ ] `/derp/probe` trusted HTTPS returns 200 while actual forwarding works. Deliberately disable/break DERP forwarding while leaving HTTPS healthy: listener check can stay green, end-to-end check must fail. No fictitious `/healthz` route is used.
- [ ] Server mounts/environment/files contain only DERP identity and TLS keys, never endpoint WireGuard private keys or session PSKs. A wrong PSK fails the application connection; transport capture shows encrypted payload rather than the synthetic application marker. Source cryptography plus path evidence support encryption; absence of a readable marker alone is not a cryptographic proof.

### A05 — Map service and client-facing HTTP contract (S03)

- [ ] Minimal map parses with the pinned Tailcat schema; region/node IDs, hostname, port, no-STUN and no-IPv6 settings match. Exactly one approved private region/node exists.
- [ ] GET/HEAD/OPTIONS/304 work; ETag is stable for unchanged bytes and changes on map change. Unsupported paths/methods, oversized/malformed/empty maps and unexpected policy fields are rejected.
- [ ] Allowed extension/test origins receive correct CORS on successful and error responses; preflight allows `Tailcat-Mode` and `If-None-Match`; ETag is exposed. Disallowed origins receive no allow-origin approval; native No-Origin requests work.
- [ ] Map has no cookies, redirects, dynamic upstream fetch, directory listing or leaked inventory. Stop map only: established relay sessions may continue; fresh private sessions fail clearly under the integration contract.

### A06 — Certificate issuance and ordinary renewal (S04, S06)

- [ ] Least-privilege scoped Cloudflare token succeeds with public DNS-01 and no inbound WAN access. Removing DNS Edit or Zone Read fails safely. Only token-file path appears in container metadata.
- [ ] Public TXT propagation succeeds through explicit public resolvers; local-only TXT does not satisfy validation. Check cleanup and stale TXT handling without indiscriminate zone deletion.
- [ ] Staging and production account/state/trust are separated. Production rejects staging output, wrong hostname, expired/not-yet-valid certificate, mismatched key, reversed/incomplete chain and malformed PEM.
- [ ] Successful initial issuance and a genuinely due renewal produce valid bundled output and a new activated pair. Use staging or controlled short-lived test certificates for repeatable timing; do not exhaust production issuance limits with forced tests.
- [ ] An ordinary not-due run exits successfully but leaves derper/map container IDs, process start times and active sessions unchanged. A modified mtime alone causes no recreation. A renewed certificate reusing its key still activates; an intermediate-chain change also activates.

### A07 — Failed renewal and publication faults (S04, S06)

- [ ] Invalid token, DNS/API outage, CA error/rate limit, timeout, lock contention and disk-full are injected independently. Existing valid relay connections remain; failure is reported and retries are bounded.
- [ ] Simulate failure between lego's certificate/key/resource writes. No partial output becomes active; consistent ACME state can be recovered without blindly creating new accounts/orders.
- [ ] Concurrent scheduled/manual/upgrade requests result in one writer. Kill the host CLI: no orphan container continues writing when a second job begins.
- [ ] Failed and unchanged renewal attempts trigger no unnecessary relay restart. Verify this through container identity/start time and uninterrupted synthetic traffic, not only a log message.

### A08 — Certificate replacement and crash reconciliation (S04, S06)

- [ ] Replacing files alone does not change the manual-mode served leaf. Coordinated recreation switches it; both ports verify trust/name/time and selected generation. Correct SNI is required.
- [ ] Crash at each transition: candidate copied, generation renamed, pending recorded, override selected, map recreated, derper recreated, verification complete, commit pending. On recovery only a complete immutable generation is mounted and state reconciles.
- [ ] Candidate startup/verification failure restores previous valid generation within budget and reports a failed activation even after recovery. Expired prior certificate cannot count as rollback success.
- [ ] A certificate obtained previously but not activated is activated on a later no-op ACME run without a new order. A stale activation marker cannot hide a different served leaf.
- [ ] Record active-session interruption during derper recreation. New sessions recover within budget; no lost command is silently replayed. Report whether existing sessions fail or reconnect, without promising continuity.

### A09 — Persistence, outages and monitoring (S06, S07)

- [ ] Container replacement, Docker restart and VM reboot preserve relay identity, ACME account, selected pair/map and local policy. Listeners recover within budget without certificate reissuance when persisted cert is valid.
- [ ] Intentional maintenance stop survives reboot; a transaction-interrupted stop is recovered. Timers are enabled, persistent and do not duplicate active work.
- [ ] Simulated extended outage/expired certificate triggers urgent renewal on return; no healthy relay prerequisite blocks repair. Clients fail closed until a trusted valid certificate is served.
- [ ] Warning/critical expiry, stale timer, pending transaction, failed activation, unhealthy relay and low disk each generate operator-visible alerts. An independent monitor detects VM disappearance. No sensitive content is included in notifications.
- [ ] Synthetic load of five concurrent endpoint pairs for 30 minutes stays within selected limits without OOM/unbounded memory/log growth; record throughput/latency locally as qualification data, not a general capacity claim. Exhaustion yields bounded failures and recoverable service.

### A10 — Upgrade, backup, restore and privacy (S01, S07)

- [ ] Restore an encrypted backup into an isolated VM; verify identity/account/config continuity, permissions, images, TLS and relaying before switching client routing. No simultaneous production copy of the same identity is left active.
- [ ] Upgrade to a candidate image, inject a failed canary, roll back old images/config and still-valid TLS without forced ACME issuance. Backups and previous images survive normal cleanup.
- [ ] Repository/build context tests reject synthetic secret markers and disallowed local artifacts; ignore rules are verified with `git check-ignore`, but tracked/staged content is reviewed separately.
- [ ] Regenerate a summary from a strict allowlist, manually inspect it, and verify it contains no actual identifiers, domains, IPs, certificates, keys, descriptors, raw logs or inventories before any later authorized publication. Public CI uses only synthetic fixtures and never collects production evidence.

## Playwriter integration qualification (separate repository)

### A11 — Explicit private selection and browser/native success (P01–P03)

- [ ] Extension settings explicitly select a private profile and display its local identity before sharing. Selected URL/topology/digest pass unchanged through descriptor, controller, wrapper and launcher.
- [ ] Private descriptor v2 is accepted only against the controller's explicitly selected matching profile; v1 public behavior remains available only under explicit public selection. Existing unrelated WS/local flows retain compatibility.
- [ ] Full Playwriter flow performs a harmless CDP read and controlled page update through the VM, with no browser-side Playwriter relay process. Correlate actual relay path evidence as in A04.
- [ ] Packaged Edge and Chrome tests cover cold worker/cache, permission withheld/granted, offscreen recreation, normal TLS, no security flags and current enterprise policy. Native tests record the owned launcher's artifact hash and cleanup after controller exit.
- [ ] Empty/private URL mismatch, unknown/embedded region, zero PSK, bad descriptor version, unapproved map digest, public node insertion, redirect and invalid TLS fail before unapproved dialing. Diagnostics redact address capabilities and real topology from publishable output.

### A12 — Relay loss, map loss and no public fallback (P02–P04)

- [ ] Keep public Internet reachable; start private mode and record DNS/fetch/socket destinations. Only approved private map/relay destinations are used for this transport. Also prove operation under an egress policy that denies public DERP/maps.
- [ ] Stop/block private derper during active traffic and during cold startup. Operations fail or time out within documented client deadlines; no public map request, public relay dial, local-relay fallback, silent mode change or automatic command replay occurs.
- [ ] Restore private derper; an explicit new session succeeds. Rotate certificate during traffic and repeat failure/recovery observations.
- [ ] Stop/block map service with cold and warm caches. A fresh private session fails even with stale cached maps; an existing established session may continue. Changing server map bytes requires explicit profile update, not automatic trust expansion.
- [ ] Switching profiles disposes prior worker/native generation and cache; public cache entries cannot seed private mode. Stop/revoke kills owned endpoint state. Tests observe attempted destinations, not only successful sockets.

## Sign-off

Server sign-off requires A01–A10. User-objective sign-off additionally requires A11–A12 and successful Playwriter integration tickets. Record failures/waivers explicitly; never convert an unexecuted case to passed based on source inspection. Future Internet hosting needs its own threat/admission/abuse/operations acceptance and is not implied by either milestone.
