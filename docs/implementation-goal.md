Start a durable implementation goal for the private DERP stack and its Playwriter integration. This message authorizes the coding phase below. Use the actual goal tools exposed by this T3 Code/Codex session; an ordinary checklist or scheduled task is not a substitute.

## Goal lifecycle

First call `get_goal`. If there is no unfinished goal, call `create_goal` with this objective:

> Implement the code, reproducible local builds, configuration templates, tests and operating documentation for SapkaLabs/derp-stack issues #1–#7 and SapkaLabs/playwriter issues #12–#15, following the reviewed specifications. Complete the required coding-phase checks in an authorized local development/test environment, resolve review findings, and deliver reviewable local commits plus an exact handoff of outstanding deployment acceptance. No real deployment, public image publication, real DNS/firewall changes or public ACME issuance is authorized by this goal.

Do not set a token budget unless I explicitly provide one. Continue an already active identical goal without duplicating it. Do not replace an unrelated unfinished goal; explain the conflict. If goal tools are unavailable, report that limitation rather than claiming a persistent goal exists.

Use `get_goal` and a concise plan to retain progress across turns. Persist a public-safe implementation status document with ticket-to-commit mapping, executed tests, unresolved findings and deferred deployment checks; sensitive evidence stays elsewhere. Continue independent authorized work when one check is unavailable. Follow `update_goal`'s actual blocked/paused-status rules; do not manufacture a pause, spin repeatedly on missing access, or claim completion because a turn ends. Call `update_goal` with `status: "complete"` only after meeting the coding-phase definition of done below.

## Read the specifications and current source

Read applicable repository `AGENTS.md` instructions, then these files in the derp-stack checkout:

1. `README.md` and `docs/tickets.md`.
2. `docs/architecture.md` and `docs/operations.md` — authoritative implementation choices.
3. `docs/acceptance.md` — required evidence, not previously passed tests.
4. `docs/research/feasibility.md` and `docs/research/relay-certificates.md` — cited facts and runtime uncertainties.

The research includes an investigated symlink-publication alternative; the final design selects literal immutable-generation bind mounts. Implement the final design. Preserve the documentation even if still uncommitted. Inventory dirty files and capture a documentation-only local baseline commit containing only these task-owned documents before implementation; preserve unrelated changes. Capture a separate pre-change review base SHA for each repository.

Read each issue and its current discussion before its implementation:

| ID | Issue | Depends on |
| --- | --- | --- |
| S01 | https://github.com/SapkaLabs/derp-stack/issues/1 | Specification baseline |
| S02 | https://github.com/SapkaLabs/derp-stack/issues/2 | S01 |
| S03 | https://github.com/SapkaLabs/derp-stack/issues/3 | S01, S02 |
| S04 | https://github.com/SapkaLabs/derp-stack/issues/4 | S01–S03 |
| S05 | https://github.com/SapkaLabs/derp-stack/issues/5 | S02, S03 |
| S06 | https://github.com/SapkaLabs/derp-stack/issues/6 | S04, S05 |
| S07 | https://github.com/SapkaLabs/derp-stack/issues/7 | S01–S06 |
| P01 | https://github.com/SapkaLabs/playwriter/issues/12 | S03 map contract |
| P02 | https://github.com/SapkaLabs/playwriter/issues/13 | P01 |
| P03 | https://github.com/SapkaLabs/playwriter/issues/14 | P01 |
| P04 | https://github.com/SapkaLabs/playwriter/issues/15 | P02, P03, S07 qualification |

Code dependencies can proceed once the needed contract/implementation is available and tested, even if the prerequisite issue remains open for later live acceptance. Do not demand production qualification before implementing the next module, and do not erase those qualification requirements.

Discover the Playwriter checkout through available project/Git metadata; do not assume its filesystem location. Read its current instructions. Re-inspect https://github.com/SapkaLabs/playwriter/pull/11 and source: the research baseline was head `2905b02f008665e4baf3692e3b28ec8abfa4ae00`, extension 0.0.180, Tailcat `e00cdde6ff787f801361ff85ed085775c775d4c5`. If PR #11 is unmerged, base a separate integration branch on its current head; if merged, use a current base containing it. Do not overwrite the PR branch or assume default main contains the MVP. Respect current manifest-version and changeset rules.

## Installed skills

Resolve each name from the session's installed-skill catalog and read its actual `SKILL.md` before first use, including applicable references. Do not invent skill contents. If one is unavailable, look for a relocated installed copy and report the exact missing capability; continue unaffected work. User-specific local skill paths must not enter GitHub.

| Skill | Application |
| --- | --- |
| `codebase-design` | Before designing configuration, map, certificate lifecycle/recovery and private-profile interfaces. Keep interfaces small and behavior testable through them. |
| `tdd` | Behavioral changes test-first at the approved seams below, one failing test and minimal implementation at a time. Read `tests.md` and `mocking.md`; test doubles belong at external boundaries. |
| `cybersecurity` | Container, TLS/certificate, secret-handling and supply-chain review. Read its catalog and select `container-audit`, `crypto-audit`, `secrets-audit`, and `dependency-audit` workflows for the relevant changes. Source/local-artifact review only; no implicit live pentest, cloud scan or upload. |
| `code-review` | Each meaningful completed batch and final diff against the captured pre-change commit and linked issue/spec. Run its separate Standards and Spec reviews, fix actionable findings, verify fixes. The fixed point and spec are supplied here; do not ask me to repeat them. |
| `research` | Uncertain upstream APIs, flags, versions, advisories or platform behavior. Use official primary sources and pinned revisions; follow its background-investigation workflow within this scope. |
| `diagnosing-bugs` | Build/test/runtime failures: establish a narrow reproducible signal, test hypotheses, fix causes and rerun relevant checks. |
| `cross-platform-environment` | Discover existing host/browser/toolchain capabilities without assumed machine paths or broad environment dumps. Discovery does not authorize remote access or host changes. |
| `cross-platform-validation` | Actual browser/asset validation: read `web.md`, `generated-assets.md` and `evidence.md` as applicable, pin baseline/candidate and exercise the same environment. Follow current T3 browser-tool rules. |
| `writing-for-agents` | Agent instructions, implementation handoffs and agent-consumed runbooks with explicit scope and completion criteria. |
| `domain-modeling` | Only when changing domain terminology, adding glossary entries or recording a consequential ADR. Preserve certificate-generation/profile/session distinctions. |
| `create-work-item` | Updates to the existing eleven issues: preserve criteria, avoid duplicates and read back mutations. |
| `pr` | If a PR is subsequently authorized, read this before composing its body; report actual validation and limitations. |

Use existing Playwriter UI conventions for the small profile/settings addition. Do not activate unrelated website builders, .NET/mobile specialists, provisioning wizards or broad redesign workflows. No dedicated Docker/Go implementation skill was available when this prompt was prepared; use the pinned official sources, repository standards, behavioral tests and scoped container review.

Skill-required research/review delegation is authorized. Otherwise work directly; do not launch an unrequested fleet or new top-level threads. Follow current native/T3 orchestration rules, delegate completion instructions and scope constraints. Use a new review task for a re-review when required; fix small findings yourself.

## Approved test seams

I approve these public interfaces as the test seams for this goal. Record concrete interface names before testing. Routine naming and adapter choices within these seams need no further approval; ask only for a materially different seam or scope.

| Seam | What it catches / does not establish |
| --- | --- |
| Configuration/profile loader and validator | Unsafe paths, unresolved placeholders, invalid URLs/topology/digests; does not prove host routing or browser permissions. |
| HTTPS map request/response | Schema, methods, CORS, ETag, bounds and trust; does not prove DERP forwarding. |
| Host certificate lifecycle command/status | Obtain/no-op/failure, immutable generations, locks, cancellation, recovery and rollback through observable outcomes; fake ACME/Docker adapters do not qualify the real CA/VM. |
| Compose startup/probe and two-endpoint data path | Flags, mounts, users, resources, TLS, native/WebSocket interoperability and encrypted forwarding; local tests do not qualify the owner's LAN/VPN firewall or reboot. |
| Descriptor/controller/launcher and extension transport | Explicit selection, actual consumed map, no fallback, cleanup/revocation and compatibility; mocks do not replace packaged-browser proof. |
| Disposable packaged-browser/CLI flow | Harmless CDP operation, real private route, failure/recovery and no public attempts; local fixtures do not establish production availability or Internet admission. |

Use synthetic independent expected results, disposable test keys and scoped fake clocks/ACME/DNS/Docker adapters as necessary. Test trust may be scoped explicitly to an isolated client/profile; never weaken production verification or alter the user's system/browser trust store. Do not test private helpers or duplicate implementation logic in assertions.

## Coding authority and deployment boundary

You may edit code/configuration/tests/docs in the two named repositories, obtain public dependencies, build local images/artifacts, run unit/integration and disposable local browser/CLI tests, and create task-specific local branches/commits. Use an already available suitable local Linux container runtime; remote daemons and host provisioning are not implicitly authorized. Keep test listeners loopback-bound and disposable. Preserve existing user services, browser profiles and keys.

Do not install system-wide SDKs, alter host firewall/DNS/trust, SSH to a VM, provision infrastructure, deploy services, use real Cloudflare credentials, issue staging/production public certificates, change UniFi/Proxmox settings, expose the service to LAN/WAN, publish images/packages, push/merge branches or open PRs without separate authorization. Isolated self-generated test certificates are allowed; public ACME issuance is not.

Sanitized progress updates on these eleven issues are allowed. Do not use automatic issue-closing keywords or close an issue while required acceptance evidence is missing. Keep real domains, IPs, VLANs, host/VM/account IDs, emails, inventories, credentials, descriptors, certificates, keys and raw logs/captures out of GitHub, including comments, CI and artifacts. Sanitization is a human-review step as well as automated scanning.

## Execution

1. Inventory workspace/tooling, preserve the documentation baseline, capture review base SHAs, read initial skills, and map issue criteria to coding checks versus deployment gates.
2. Implement S01–S07 in dependency order. Resolve actual build digests/tool versions. Do not silently replace selected derper/lego/Tailcat pins; if evidence requires a change, record why and update compatibility tests/specs together.
3. Implement P01–P03 once their contracts are ready. Enforce private profiles, frozen validated map bytes, nonzero PSKs, the owned private WASM bridge against pinned Tailcat, and the controlled native launcher. Preserve explicit public v1 selection; private failures cannot trigger public/local fallback.
4. Run local S07/P04 qualification using disposable synthetic fixtures and packaged browser/native artifacts. Observe attempted destinations: merely blocking public traffic does not prove no fallback attempt. Keep listener health distinct from successful relaying. No browser-side Playwriter relay is required.
5. Perform relevant security reviews and both code-review axes. Fix defects, rerun affected checks and document observed behavior. Source inspection and mocks never substitute for required runtime evidence.
6. Prepare a deployment handoff after independent coding is complete: remaining acceptance cases, required local inputs/host capabilities, concrete proposed changes/commands and rollback. Request secrets only through `request_secret` when a separately authorized action actually needs one; never solicit secrets in chat.

Preserve: local image builds without registry publication; direct DERP; LAN/VPN-only deployment design; no container Docker socket; Cloudflare token only in automation; immutable complete certificate/key generations; controlled manual-TLS recreation; no unnecessary relay restart for failed/no-op renewal; endpoint keys/PSKs never on relay; no silent public fallback; no replay of unknown-outcome commands; private configuration/evidence outside GitHub.

## Coding-phase definition of done

All implementation code, templates, harnesses and runbooks needed by the eleven tickets exist. Required coding-phase checks, including Linux builds and disposable local runtime/browser checks, pass; correctness/security review findings are resolved. A missing required local runtime/tool is a blocker for its check, not a pass or an automatic exclusion. Continue unaffected work, then apply the actual goal blocked-status rules if an impasse remains.

Report each ticket separately as code implemented, local checks passed, live deployment checks pending, or blocked with evidence. Provide review base/head SHAs, local commit mapping, exact test results and relevant local artifact paths. Preserve the complete list of unrun A01–A12 checks and reasons. Do not claim the deployment works or close deployment-dependent issues from coding completion alone.

Real-domain ACME, target LAN/VPN policy, target-VM reboot/restore and production end-to-end acceptance remain outside this bounded goal until separately authorized. Finish with a concrete deployment-readiness handoff. No production values are needed to begin implementation.
