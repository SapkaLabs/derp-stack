# Private DERP feasibility and integration findings

Research date: 2026-11-17. **Source-verified** means inspected code or official documentation, not a running deployment. **Recommended** describes the proposed implementation. All deployment examples are synthetic.

## Conclusion

The stack is feasible with upstream Tailscale derper, a separate HTTPS map endpoint, and lego DNS-01 automation. Protocol inspection supports derper **v1.104.7**, but interoperability remains an acceptance test. The current Playwriter public-DERP MVP cannot select this stack unchanged: its extension, descriptor validator, and native launcher explicitly select the public map. Server implementation and client integration are separate workstreams.

Use [the architecture](../architecture.md), [certificate and operation specification](../operations.md), [acceptance plan](../acceptance.md), and [ticket drafts](../tickets.md) together. Detailed upstream evidence, exact certificate behavior, version inventory, and citations are in [relay and certificate research](relay-certificates.md). The architecture is the authoritative choice where that investigation offers alternative publication strategies.

## Inspection boundary

- Existing checkout: README only before this research; no applicable `AGENTS.md` in the workspace or checked ancestors. No local implementation existed to test.
- Git remote and GitHub repository metadata identified the already-created `SapkaLabs/derp-stack`, visibility **public**. The owner's later instruction supersedes the earlier repository-creation step. No repository was created or visibility changed. [Repository](https://github.com/SapkaLabs/derp-stack).
- Playwriter PR #11 was **open**, head `2905b02f008665e4baf3692e3b28ec8abfa4ae00`, extension `0.0.180`. This is the inspected head, not a promise about later PR updates or the default branch. [PR](https://github.com/SapkaLabs/playwriter/pull/11), [manifest][pw-manifest].
- Read Playwriter `AGENTS.md` and the opening active-plan context; its unrelated stealth benchmark is outside this task. Source files inspected: `extension/manifest.json`, `extension/src/tailcat-tunnel/{index,worker,offscreen}.ts`, `playwriter/src/tailcat-tunnel/{protocol,controller,native}.ts`, its `launcher/main.go`, and `scripts/build-tailcat.mjs`. No Playwriter files were edited. [Instructions][pw-instructions].
- Inspected Tailcat `tailcat.go`, `listen.go`, `pickregion.go`, `pickregion_js.go`, `web/main_js.go`, `go.mod`, and README at `e00cdde6ff787f801361ff85ed085775c775d4c5`; inspected `tailcfg/derpmap.go` in its actual Tailscale dependency `fb79793d99f5ccedabe1ab428f0af852f49d0c62`. Additional server/ACME source inventory is in the companion research file.
- Consulted official Tailscale/Tailcat, lego, Let's Encrypt, Cloudflare, Docker, Chrome, Microsoft Edge, Ubiquiti and browser CORS documentation. Moving documentation was accessed on the research date; it does not pin an installed browser, Docker, UniFi, or VM version. Wayfinder was not available among installed skills/tools.
- No source compilation, container build/run, browser connection, packet capture, certificate issuance, DNS edit, firewall edit, VM inspection, image publication, issue creation, commit, or push occurred. All runtime acceptance items remain unexecuted.

## Client behavior at the inspected revisions

| Component | Source-verified behavior | Required integration change |
| --- | --- | --- |
| Shared protocol | `PUBLIC_DERP_MAP` is `https://tailcat.dev/derpmap.json`. [Source][pw-protocol] | Add an explicit private profile contract without changing existing public v1 behavior. |
| Extension transport | Sends `v:1`, `relayMode:'public'`, the public URL, and the short Tailcat address in its descriptor. [Source][pw-index] | Private mode must carry the selected profile and validated private map identity. |
| Browser worker | Calls `tailcatListen({derpMapURL: PUBLIC_DERP_MAP,...})`; endpoint private-key JSON stays inside the worker. [Source][pw-worker] | Pass the selected map from trusted extension settings through offscreen to the worker. Keep key ownership and generation disposal. |
| Controller | Requires public mode/exact public map, nonzero PSK, region 301–304, and no embedded regions. Deletes inherited `TAILCAT_DERPMAP_URL`. [Source][pw-controller] | Validate private profiles/region membership; do not simply remove checks or enable arbitrary descriptor-directed fetching. |
| Native wrapper/launcher | Wrapper forwards only address; launcher sets `Client.DERPMapURL` to the public URL. [Wrapper][pw-native], [launcher][pw-launcher] | Pass the selected map explicitly through the owned process boundary; validate again in launcher and preserve cleanup/deadlines. |
| Asset builder | Pins Tailcat `e00cd…`, requires Go 1.27.2, records the public map in its generated manifest. [Source][pw-build] | Retain source pin unless separately upgraded; update policy metadata/bundle verification to distinguish supported private selection. |

**Source-verified:** Tailcat already accepts a `DERPMapURL` in native client/server APIs, and the WASM listener requires one. A new Tailcat transport implementation is not indicated. The WASM listener selects a region and returns a short address referencing that region; the controller must resolve the same region in the same approved map. The `tc…` address contains a PSK capability and must be treated as a secret. [Tailcat core][tc-core], [WASM bridge][tc-wasm].

Map caching matters: the pinned fetcher keys its cache by URL, reuses a fresh entry for one hour, revalidates with `If-None-Match`, and can use a stale entry of any age after fetch failure. It sends `Tailcat-Mode: server` or `client`. Invalid JSON is rejected, but JSON decoding alone does not enforce a usable/nonempty/private-only map. The explicit URL replaces the default URL; a failed fetch is not a switch to the public URL. Embedded regions bypass lookup entirely. These facts require explicit policy validation; server cache headers alone cannot override the Tailcat in-memory policy. [Fetcher and expansion][tc-core].

## Browser, CORS, TLS, and private destinations

**Source-verified:** the extension manifest currently grants `<all_urls>`, includes `offscreen`, and permits packaged WASM. Its CSP has no `connect-src` or `default-src` restriction. Offscreen owns the dedicated worker. Chrome documents privileged cross-origin requests with host permissions; content scripts retain web-origin restrictions. The exact packaged worker must still be tested. [Manifest][pw-manifest], [offscreen][pw-offscreen], [Chrome network requests](https://developer.chrome.com/docs/extensions/develop/concepts/network-requests).

Microsoft's Local Network Access guidance says extensions with necessary host permissions can make local requests. Chrome's earlier LNA announcement replaces the former PNA experiment and describes evolving coverage; newer permission names also differ. Do not infer a permanent WebSocket exemption from old rollout notes. Record the actual Edge/Chrome version, enterprise policies, site-access grants, and offscreen-worker behavior during acceptance. No global browser security bypass is part of this design. [Edge guidance](https://learn.microsoft.com/en-us/deployedge/ms-edge-local-network-access), [Chrome LNA](https://developer.chrome.com/blog/local-network-access), [Chrome 145 changes](https://developer.chrome.com/blog/chrome-145-beta).

**Recommended:** use HTTPS for map fetch and WSS for browser DERP with the same real DNS hostname and trusted chain. The map service allows only configured extension origins (and separately named local test origins), sends `Vary: Origin`, permits GET/HEAD/OPTIONS, and allows `Tailcat-Mode` and `If-None-Match` request headers. Expose `ETag`; omit credential support. An OPTIONS preflight returns 204 for allowed origins/methods/headers. Actual GET/304/error responses carry consistent CORS headers for allowed origins. No-Origin native requests are allowed. CORS controls reading by browser origins; it is not relay admission or a firewall. [CORS rules](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS), [Tailcat headers][tc-core].

Even if extension privileges bypass CORS in a tested context, explicitly supporting these headers avoids dependence on that bypass for a controlled diagnostic page. The native `/derp` upgrade is not WebSocket framing. Upstream derper supports both and accepts browser origins; an HTTP reverse proxy configured only for WebSockets could break the native path. Therefore use direct TCP publication to derper, no Cloudflare HTTP proxy or TLS terminator. [Protocol comparison](relay-certificates.md#derp-and-browser-transport-compatibility).

## STUN and endpoint encryption

The pinned browser region picker is a stub because browsers cannot send raw UDP; it chooses from the supplied map through `Expand`. The native picker uses netcheck; the schema permits `STUNPort:-1`. For one-region browser/native DERP use, recommend **STUN disabled** and no published UDP port. Confirm startup and relaying with UDP blocked. This is a source-supported proposal, not an observed performance result. Enabling STUN later requires matching map, derper flag, firewall and tests; it is not required for DNS-01. [Browser picker][tc-picker-js], [native picker][tc-picker], [map schema][map-schema].

Endpoint WireGuard private keys and PSKs remain only at Tailcat endpoints. derper has its own DERP identity key and TLS key; those are not endpoint WireGuard private keys or PSKs. The relay forwards opaque encrypted packets and observes connection metadata, timing, sizes and node public keys. TLS termination at derper does not decrypt the inner WireGuard payload. This does not make metadata anonymous or secure a leaked session descriptor. [Tailcat architecture][tc-readme], [DERP source](https://github.com/tailscale/tailscale/blob/cbc74fe48ef1b1649f69a4d9a602319427e25102/derp/derp.go).

## Docker, DNS, and privacy findings

Docker published bridge ports traverse forwarding/NAT rules; relying on UFW INPUT rules is insufficient. With the iptables backend, `DOCKER-USER` precedes Docker acceptance and sees post-DNAT destinations; original published destination matching needs conntrack. Bind to the VM's selected LAN IPv4 address and enforce source allowlists, including same-subnet clients. An upstream router rule alone cannot filter clients that communicate directly on the same subnet. A native nftables-backend setup needs a different policy and is outside the initial recipe. [Docker firewall](https://docs.docker.com/engine/network/packet-filtering-firewalls/), [iptables](https://docs.docker.com/engine/network/firewall-iptables/), [publishing](https://docs.docker.com/engine/network/port-publishing/).

Compose secrets are per-service file mounts; standalone Compose does not make their host source files an encrypted secret store. File ownership and permissions must be provisioned on the host, not assumed from Compose UID/GID settings. Docker restart policies restart exited processes, not arbitrary unhealthy services; initial startup ordering is distinct from ongoing health. [Secrets](https://docs.docker.com/compose/how-tos/use-secrets/), [services](https://docs.docker.com/reference/compose-file/services/), [restart](https://docs.docker.com/engine/containers/start-containers-automatically/), [startup](https://docs.docker.com/compose/how-tos/startup-order/).

UniFi supports local A records; use an exact host override rather than an unnecessary whole-zone override. Browser secure DNS and VPN resolver routing can bypass local DNS and need tests. ACME validates the **public** TXT record, not that local A response. Public A/AAAA records for the relay are unnecessary in the initial design. Let's Encrypt submits certificates to CT logs, so a trusted public certificate discloses its SAN hostname outside GitHub. The repository privacy requirement is still enforceable; hostname secrecy from CT is incompatible with this selected issuance method. Use a neutral hostname without inventory clues. [UniFi](https://help.ui.com/hc/en-us/articles/15179064940439-UniFi-DNS-Records-and-Local-Hostnames), [DNS-01](https://letsencrypt.org/docs/challenge-types/), [CT](https://letsencrypt.org/docs/ct-logs/).

## Remaining decisions and tests

No owner decision blocks these documents. Routine defaults are selected in the architecture. Before implementation/deployment, record the actual host/browser versions, local domain/DNS/token paths and allowed sources **locally**. Exact builder/runtime image digests and Docker/Compose package versions are implementation lock inputs, not yet verified artifacts.

Scope-changing owner choices would be: zero-interruption certificate rotation/high availability, Internet exposure, support for additional CPU/OS families, changing the existing VM's OS if it differs from the proposed baseline, or refusing public CT hostname disclosure. These are outside the initial acceptance boundary and require a revised scope, not guessed infrastructure changes.

Outstanding runtime gates: stable derper/native/WASM compatibility; UDP-free startup; packaged extension permission behavior; actual DNS/trust; least-privilege ACME issuance and v5 renewal; crash-safe publication/reconciliation; Docker firewall and reboot behavior; build reproducibility; resource sizing; restore/rollback; and sanitized evidence. Each is mapped to [acceptance cases](../acceptance.md) and [tickets](../tickets.md).

[pw-instructions]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/AGENTS.md
[pw-manifest]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/extension/manifest.json
[pw-index]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/extension/src/tailcat-tunnel/index.ts
[pw-worker]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/extension/src/tailcat-tunnel/worker.ts
[pw-offscreen]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/extension/src/tailcat-tunnel/offscreen.ts
[pw-controller]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/playwriter/src/tailcat-tunnel/controller.ts
[pw-native]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/playwriter/src/tailcat-tunnel/native.ts
[pw-launcher]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/playwriter/src/tailcat-tunnel/launcher/main.go
[pw-protocol]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/playwriter/src/tailcat-tunnel/protocol.ts
[pw-build]: https://github.com/SapkaLabs/playwriter/blob/2905b02f008665e4baf3692e3b28ec8abfa4ae00/scripts/build-tailcat.mjs
[tc-core]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/tailcat.go
[tc-wasm]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/web/main_js.go
[tc-picker]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/pickregion.go
[tc-picker-js]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/pickregion_js.go
[tc-readme]: https://github.com/tailscale/tailcat/blob/e00cdde6ff787f801361ff85ed085775c775d4c5/README.md
[map-schema]: https://github.com/tailscale/tailscale/blob/fb79793d99f5ccedabe1ab428f0af852f49d0c62/tailcfg/derpmap.go
