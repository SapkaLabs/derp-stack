# Ordered implementation tickets

Created in GitHub on 2026-11-17 and read back to verify titles, bodies, open state and dependency links. All are **not started**. Links below are the canonical tracker items. Every ticket operates under the public-safe configuration/evidence policy in [architecture](architecture.md); all examples/fixtures are synthetic. Actual deployment/issuance is a later authorized phase. Acceptance IDs refer to [acceptance.md](acceptance.md); each ticket closes only when its named cases have recorded evidence, not merely when code exists.

For a bounded coding phase using the goal tools, use [the implementation goal prompt](implementation-goal.md). It keeps real deployment and certificate issuance outside the coding goal while preserving their acceptance gates.

## Order and dependency graph

Suggested order: S01 → S02 → S03 → S04 → S05 → S06 → S07. Client contract P01 can start after S03's map contract is frozen; P02/P03 follow P01 independently; P04 follows both and S07. Server work and Playwriter integration remain separate repositories and separate reviews. No server ticket silently edits Playwriter. No ticket publishes a container image.

| Ticket | Repository | Depends on | Deliverable |
| --- | --- | --- | --- |
| [S01](https://github.com/SapkaLabs/derp-stack/issues/1) | derp-stack | Approved specifications | Build/config/privacy contracts and resolved input locks |
| [S02](https://github.com/SapkaLabs/derp-stack/issues/2) | derp-stack | S01 | Local derper image and hardened Compose baseline |
| [S03](https://github.com/SapkaLabs/derp-stack/issues/3) | derp-stack | S01, S02 | Local HTTPS map service and validated map contract |
| [S04](https://github.com/SapkaLabs/derp-stack/issues/4) | derp-stack | S01–S03 | Local lego image and transactional certificate lifecycle |
| [S05](https://github.com/SapkaLabs/derp-stack/issues/5) | derp-stack | S02, S03 | Platform preflight, DNS and firewall installation workflow |
| [S06](https://github.com/SapkaLabs/derp-stack/issues/6) | derp-stack | S04, S05 | Scheduling, crash reconciliation and monitoring |
| [S07](https://github.com/SapkaLabs/derp-stack/issues/7) | derp-stack | S01–S06 | Operational runbooks, restore/rollback and server qualification |
| [P01](https://github.com/SapkaLabs/playwriter/issues/12) | playwriter | S03 contract | Versioned explicit private profile/descriptor policy |
| [P02](https://github.com/SapkaLabs/playwriter/issues/13) | playwriter | P01 | Extension/WASM private-map selection and enforcement |
| [P03](https://github.com/SapkaLabs/playwriter/issues/14) | playwriter | P01 | Controller/native launcher private-map enforcement |
| [P04](https://github.com/SapkaLabs/playwriter/issues/15) | playwriter | P02, P03, S07 | Real private end-to-end/no-fallback qualification |

## S01 — Freeze reproducible inputs and public-safe configuration

**Problem/outcome:** source pins alone do not produce a reproducible or privacy-safe deployment. Establish exact build inputs, local configuration paths, and reviewable synthetic templates before images or automation exist.

**Scope:** resolve derper v1.104.7 / lego v5.6.0 commits and Go 1.27.4 into a checked lock; pin platform builder digest, CA bundle, module sums, build metadata and BuildKit. Define target Debian 13/amd64 and exact validated Docker/Compose packages/backend; do not replace the owner's OS. Add documented schema/templates and ignore/build-context exclusions. Record license provenance. Define local-only image transfer and retention. No production values.

**Completion criteria:**

- Lock has no floating/unresolved inputs; checker rejects an altered source checksum or missing base digest. All selected artifacts have official provenance.
- Config validation rejects placeholders and unsafe paths without executing values or exposing secrets. Tests use hostile synthetic values to check shell/path handling.
- `.gitignore` and `.dockerignore` exclude the specified local state, certificate, secret, log, capture and artifact paths; staged/tracked-content review is documented separately.
- Build contexts contain only approved inputs; later image builds have enough metadata to perform A01. Privacy tests in A10 pass with synthetic marker fixtures; no GitHub production secrets/CI uploads are introduced.

## S02 — Build and contain direct upstream derper

**Problem/outcome:** a directly reachable relay must support both Tailcat transport forms without a proxy or endpoint keys.

**Scope:** multi-stage local image from pinned upstream; explicit manual-TLS flags; persistent relay identity; numeric user; immutable certificate-directory mount; direct private-address TCP 443 publication to internal 8443; no UDP/HTTP publishing; bounded service resources/logs; trust/SNI-aware health helper. No patches to upstream DERP protocol, no tailscaled verification dependency.

**Completion criteria:**

- A01 verifies repeatable derper/helper builds and no deployment material in layers. Version provenance matches lock.
- A02 verifies flags, resource/security constraints and isolated permissions. Missing/invalid cert or identity state fails visibly; identity survives container replacement.
- Synthetic local TLS tests prove HTTPS probe semantics and both upgrade handlers. A04 real native/browser interoperability remains required at S07; S02 must not label a synthetic listener test as full client acceptance.
- `-stun=false`, `-http-port -1` and selected private bind are observable; no Docker socket/endpoint private key/PSK appears in runtime mounts.

## S03 — Serve a strict private DERP map over HTTPS

**Problem/outcome:** upstream derper does not serve the required map, and adding a relay proxy creates avoidable protocol risk.

**Scope:** minimal Go static map service, local image, exact HTTPS path on TCP 8443, immutable pair mount, one-region map generation/validation, explicit CORS/ETag/method/body/time limits. Publish map schema/profile contract for Playwriter; include no real origins or hostname in repository defaults.

**Completion criteria:**

- A05 HTTP/map/CORS cases pass, including preflight custom headers, 304 and errors. Map parses using pinned Tailcat schema with region 900, STUN disabled and no default regions.
- Invalid/empty/oversized/public-node maps cannot silently become active. Unsupported paths are not file-server traversal or listings.
- Native and packaged-extension-origin requests can fetch using valid TLS in the later test environment; standalone CORS tests pass now. Private route remains direct to derper.
- Pair readability is limited to selected map user/group; map service has neither DNS token nor ACME account. Map-only failure leaves an established relay path intact.

## S04 — Implement local lego and recoverable certificate activation

**Problem/outcome:** lego output is sequential, manual derper TLS is cached, and exit zero can mean renewal no-op. Implement the state machine in [operations](operations.md), not an unconditional restart hook.

**Scope:** pinned local lego v5 image; `run` command semantics; per-service `_FILE` secret; separate staging/production state; ACME snapshot/recovery; host validation/publisher; immutable generations; literal mount overrides; serialized map/derper recreation and rollback; durable issued/selected/activated records. Host controls Docker; no socket or hook-based restart inside lego.

**Completion criteria:**

- Binary/image reproducibility and file-secret permissions pass A01/A02. Only scoped Zone Read/DNS Edit token is required in authorized staging A06.
- Validator rejects all bad pairs/chains/hostnames/dates in A06; publication exposes a complete pair only and preserves the active pair during ACME work.
- A06/A07 prove successful change, key reuse, no-op, mtime-only change, failed DNS/API/CA/save, and partial state recovery. No restart occurs for ordinary no-op or failed acquisition.
- All A08 crash transitions and rollback cases pass with synthetic certificates; repeat real replacement once authorized. Pending activation can complete without a new ACME order.
- Concurrent/cancelled attempts leave one writer and no orphan container. Old/pending/mounted generations are never garbage-collected. No live session continuity is falsely promised.

## S05 — Qualify VM networking, split DNS and Docker-aware restrictions

**Problem/outcome:** Docker port publishing can bypass ordinary host INPUT firewall rules. Installation must remain LAN/VPN-only across startup and reboot.

**Scope:** read-only preflight and documented, later-authorized installation steps for the chosen platform; exact UniFi host record; public challenge authority checks; explicit IPv4 binding; iptables forwarding allowlist and external VM-firewall boundary; DNS/ACME egress; maintenance/revert procedure. No real inventory in templates. Do not auto-reconfigure an unsupported firewall backend.

**Completion criteria:**

- A03 passes from approved and disallowed LAN/routed/VPN sources, including same subnet, IPv6 and direct-container-route attempts.
- Continuous probes during boot/Docker restart show no transient exposure. Rules survive restart and do not disrupt unrelated services; counter evidence stays local.
- Local DNS and public ACME authority are independently verified; no public proxy/WAN port opening is introduced. STUN remains closed.
- Unsupported backend/OS/address or missing enforceable startup boundary halts installation with an actionable compatibility finding. Proposed firewall changes have a documented local rollback path.

## S06 — Schedule renewal and reconcile failures with visible alerts

**Problem/outcome:** periodic ACME runs are insufficient without boot recovery, expiry monitoring and operator-visible failure reporting.

**Scope:** systemd renewal timer/oneshot, shared lock, bounded timeouts/cancellation, six-hour retry policy, boot reconciliation, maintenance-stop state, hourly expiry/status monitor and local alert adapter. Docker remains the daemon crash-restart owner. Integrate an existing external-to-VM monitor if available; do not create new external services implicitly.

**Completion criteria:**

- A07 locking/cancellation and A08 interruption recovery pass through the actual systemd path. `Persistent=true` catches missed runs without duplicate writers.
- A09 verifies reboot persistence, intentional-stop semantics, extended outage/expiry repair and alert thresholds with controlled clocks/certificates. Renewal is not gated on a healthy expired HTTPS endpoint.
- Failure notifications are observed by the operator through the configured local channel; VM disappearance is detected independently. Notification content is sanitized.
- Repeated no-op or failed renewal does not restart relay; monitor-only health failures alert rather than creating an unbounded restart loop. Configuration/image/maintenance changes use the same lock.

## S07 — Complete operations, recovery and server acceptance

**Problem/outcome:** deployment can be considered operable only after interoperability, restore and rollback have been demonstrated.

**Scope:** finalize installation/operation/troubleshooting runbooks from real qualification, local image export/import, encrypted consistent backup, isolated restore, software rollback, disposable endpoint canaries and sanitized evidence export. Preserve all no-publication constraints unless later explicitly changed.

**Completion criteria:**

- A01–A10 are executed and recorded with exact artifacts/versions. Source-only or synthetic-only tests are distinguished from native/WASM/runtime tests.
- A04 proves real encrypted bidirectional forwarding and UDP-free operation; A09 demonstrates bounded load and operational budgets; A10 demonstrates isolated restore and failed-upgrade rollback.
- Restore documentation identifies all required secret/state/image inputs and demonstrates certificate-expiry recovery. Old identity is not running concurrently on two VMs.
- A manually reviewed summary reports only safe labels/results; raw logs/captures and real deployment values remain local. Server milestone explicitly states Playwriter integration status and does not claim completion before P04.

## P01 — Define an explicit private Playwriter profile and descriptor

**Repository:** SapkaLabs/playwriter, separate from server work. Re-read current PR/default-branch instructions and rebase the inspected source assumptions before changes.

**Problem/outcome:** public v1 descriptors enforce a particular public map/region set. Private selection needs a separate policy without weakening existing validation or silently changing modes.

**Scope:** private v2 descriptor and local profile schema from [architecture](architecture.md#client-integration-policy-separate-repository); URL/topology/map-digest policy; compatibility/version errors; trusted profile selection UI/CLI contract; local storage and privacy boundaries. Keep endpoint PSK validation, generation revocation and existing public/local flows.

**Completion criteria:**

- Table-driven A11 descriptor tests accept only matching approved private profiles, nonzero PSK, expected region and short addresses; reject embedded destinations/redirects/public-node insertion/unknown versions.
- Existing public v1 behavior remains unchanged when explicitly selected, while private failure cannot fall through to public/local parsing. Error messages contain no descriptor or real endpoint values in public logs.
- Contract defines exact values passed extension → offscreen → worker and controller → wrapper → launcher. No reliance on inherited `TAILCAT_DERPMAP_URL`.
- P02/P03 can implement against the same synthetic profile fixtures and map digest. Required repository versioning/changeset rules are included in implementation review.

## P02 — Add private selection to extension and WASM boundary

**Problem/outcome:** worker and descriptor generation currently force the public map. Private mode must use approved validated bytes and retain endpoint keys inside the worker.

**Scope:** selected local private profile, private descriptor, offscreen/worker propagation, fresh map acquisition with bounded HTTPS/no redirects and digest/topology validation, frozen per-session map handoff to the owned WASM bridge; packaged permission/CSP diagnostics. Implement the private supplied-map bridge specified in the architecture using `tailcat.Server.Region`; preserve the public entrypoint and the pinned upstream module. The owned bridge is part of this ticket, not a silent upstream fork upgrade.

**Completion criteria:**

- A11 packaged Edge/Chrome connects through private map/relay without browser-local Playwriter relay or disabled security checks. Worker key ownership and stop/revocation tests still pass.
- A12 warm/cold cache, map loss, relay loss and profile switch show no public map or public relay attempts. The map actually consumed by Tailcat equals approved frozen bytes; a separate preflight fetch alone is insufficient.
- Permissions withheld or enterprise restrictions produce clear private failures; grant/remediation works in the actual packaged offscreen worker. No arbitrary page-origin message can select an endpoint.
- Public v1 regression suite passes; extension version/changeset requirements follow current Playwriter instructions. Artifact verification records correct transport policy without real profile data.

## P03 — Carry private profile through controller and native launcher

**Problem/outcome:** controller rejects nonpublic maps/regions and the native entrypoint hard-codes the public URL. Changing the extension alone cannot work.

**Scope:** select/validate local private profile before descriptor use; pass exact approved map identity through owned wrapper; independently enforce policy in launcher; fresh bounded validated map fetch and frozen per-session cache; preserve nonzero PSK, port 1, deadlines, IPC cleanup and explicit CLI session behavior. Keep accountless Tailcat and endpoint encryption.

**Completion criteria:**

- A11 real native connectivity succeeds through selected private relay; mismatched descriptor/profile/map/region is rejected before unapproved dial. Inherited environment cannot override it.
- A12 detects zero attempted public fallback during relay/map failures, stale cache, bad TLS, redirects and profile switching. Actual map bytes used by Client match validated profile.
- Existing stream establishment signaling, framing/backpressure, controller termination/native cleanup and public v1 compatibility tests pass; no automatic replay of unknown-outcome commands is introduced.
- Launcher/bundle manifests and verification reflect the source change; no descriptor/PSK appears in newly added diagnostics. Existing process-argument exposure is assessed and not expanded by private map support.

## P04 — Qualify private Playwriter operation and failure behavior

**Problem/outcome:** source-level routing policy is insufficient evidence that real browser/controller traffic uses the private relay.

**Scope:** run A11/A12 against the qualified server stack with packaged artifacts, disposable browser session and synthetic fixture; observe attempted routes, native and browser traffic, renewal interruption and recovery; produce a sanitized result summary.

**Completion criteria:**

- Full harmless CDP read/write succeeds with verified private relay traffic; native and browser artifacts and server versions are recorded locally. No local browser-side relay is needed.
- Private relay loss fails within client deadlines while public Internet remains available, with no public map/relay attempt or mode fallback. Positive private operation also succeeds with public DERP/maps denied.
- Map loss with warm/cold caches, certificate change, failed renewal, controller/worker loss, revocation and explicit reconnect behave as specified. Unknown-outcome commands are not replayed.
- All A11/A12 evidence is present, failed cases resolved or explicitly scoped out; any claim of a working deployment states the exact tested platform/version scope. Only reviewed synthetic summaries are eligible for later publication.

## Deferred scope, not initial tickets

External hosting/admission and abuse protection; high availability or zero-interruption TLS rotation; ARM64/other OS qualification; STUN/direct-path optimization; metrics aggregation beyond the initial local/independent checks. Each needs its own approved scope and acceptance criteria before implementation. No initial ticket authorizes it implicitly.
