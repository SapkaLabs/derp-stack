# LAN DERP MVP tickets

Use these three server tickets for [the implementation goal](implementation-goal.md).

| Ticket | Observable outcome |
| --- | --- |
| [Package upstream derper for the LAN](https://github.com/SapkaLabs/derp-stack/issues/2) | Compose starts the LAN relay with a supplied certificate and persistent relay identity. |
| [Issue and renew the LAN relay certificate with lego](https://github.com/SapkaLabs/derp-stack/issues/4) | The scheduled DNS-01 job can also run on demand. The relay picks up a changed certificate. |
| [Demonstrate one relayed transfer with official Tailcat](https://github.com/SapkaLabs/derp-stack/issues/7) | Two stock clients exchange a payload through the packaged relay. This check can run as soon as the relay has a usable certificate. |

Upstream documents how to embed one relay hostname in a Tailcat address. [Bring your own DERP relay](https://github.com/tailscale/tailcat/blob/v0.7.0/README.md#bring-your-own-derp-relay)

The previous [build qualification](https://github.com/SapkaLabs/derp-stack/issues/1), [map service](https://github.com/SapkaLabs/derp-stack/issues/3), [VM qualification](https://github.com/SapkaLabs/derp-stack/issues/5) and [renewal monitoring](https://github.com/SapkaLabs/derp-stack/issues/6) tickets are historical. Application-specific work is tracked separately in [Playwriter](https://github.com/SapkaLabs/playwriter/issues/15).
