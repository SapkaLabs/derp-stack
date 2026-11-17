# derp-stack

Specification for a locally built Docker Compose deployment of a private Tailscale DERP relay with automated DNS-01 TLS certificates.

**Planning stage only.** No deployment code, images or infrastructure have been produced or validated. The recommended design uses direct derper, a separate HTTPS map service, one-shot lego, and host-side certificate scheduling. Playwriter custom-map support is a separate integration dependency.

Read in order:

1. [Cited feasibility and current Playwriter findings](docs/research/feasibility.md)
2. [Detailed relay and certificate source evidence](docs/research/relay-certificates.md)
3. [Architecture, configuration, secrets and privacy contract](docs/architecture.md)
4. [Certificate lifecycle and operations](docs/operations.md)
5. [Acceptance specification — all runtime cases unexecuted](docs/acceptance.md)
6. [Ordered implementation tickets — 11 GitHub issues](docs/tickets.md)
7. [T3 Code implementation goal prompt](docs/implementation-goal.md)

Research baseline: 2026-11-17. All deployment examples are synthetic. Real deployment configuration, credentials, session descriptors, certificates, keys, inventories and unredacted diagnostics must remain outside this public repository and its issues, PRs, CI output and artifacts.
