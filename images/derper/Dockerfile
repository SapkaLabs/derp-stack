FROM golang:1.27.4-alpine@sha256:70bd7ddea8b6cbe5d6943cde279d6b67feb10cc924fb9100d1d8757c1575b280 AS build
ARG TAILSCALE_VERSION=1.104.7
RUN CGO_ENABLED=0 go install \
    -ldflags "-X tailscale.com/version.longStamp=${TAILSCALE_VERSION}" \
    tailscale.com/cmd/derper@v${TAILSCALE_VERSION}

FROM nginx:1.30.7-alpine@sha256:3bc3836dc0be3b811f238210360bf8e7ca8a2d0effdae46160bf1f3578710051
COPY --from=build /go/bin/derper /derper
COPY run-derper.sh /usr/local/bin/run-derper
RUN chmod 0755 /usr/local/bin/run-derper
COPY derpmap.json.template nginx.conf.template /usr/local/share/derp-map/
ENTRYPOINT ["/usr/local/bin/run-derper"]
CMD []
