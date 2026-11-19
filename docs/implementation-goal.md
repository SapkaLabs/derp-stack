# Implementation goal for the LAN DERP relay

Copy the following prompt into the implementation session.

> Start an implementation goal in `SapkaLabs/derp-stack`. Deliver a Docker Compose package that relays LAN traffic between two unmodified official Tailcat clients using upstream Tailscale `derper`. Use the three active tickets in [the MVP ticket index](tickets.md) as the scope.
>
> Package the upstream relay, persist its identity and accept a mounted TLS certificate and key for its LAN hostname. Package upstream `lego` alongside it for Let's Encrypt DNS-01 issuance and scheduled renewal. Use the existing Cloudflare provider and a standard scheduler. Keep the glue small. Make a renewed certificate take effect and leave the running relay alone on a no-op or failed renewal. Use a Tailcat address that embeds the relay hostname.
>
> Show the Compose start command, a payload sent and received through this specific relay with normal TLS verification and the direct peer path excluded, and the command for invoking the scheduled certificate job now. Report what actually ran, including whether a certificate changed and which certificate the relay served. If the target LAN, DNS credentials or real issuance are unavailable or require authorization, deliver the runnable package and report exactly which live checks remain. Keep credentials and real deployment details local.
>
> Work through the agreed scope for as long as it takes. Write down additional concerns at handoff. Ask before implementing a new requirement or widening scope to address a blocker. The earlier qualification plan, a map service, client integrations, custom recovery tooling and waiting for a renewal interval are outside this goal. Finish with short setup instructions and the observed results.
