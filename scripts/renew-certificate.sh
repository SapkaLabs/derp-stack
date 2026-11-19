#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${DERP_HOSTNAME:?}" "${DERP_CERT_DIR:?}" "${LEGO_STATE_DIR:?}" "${LAN_BIND_IPV4:?}" "${CLOUDFLARE_TOKEN_FILE:?}"
if [[ ! -f $CLOUDFLARE_TOKEN_FILE ]]; then
    echo 'The Cloudflare token file must exist before the job runs.' >&2
    exit 1
fi
if [[ ! $DERP_HOSTNAME =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ || $DERP_CERT_DIR != /*/* ||
      -e $DERP_CERT_DIR && ! -L $DERP_CERT_DIR ]]; then
    echo 'Use a DNS hostname and an absolute managed certificate symlink path.' >&2
    exit 1
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
compose=(docker compose --env-file /dev/null -f compose.yaml -f compose.acme.yaml)
exec 9>"$LEGO_STATE_DIR/.renew.lock"
flock -n 9
echo 'Running lego certificate job.'
"${compose[@]}" run --rm --no-deps -T lego

crt="$DERP_HOSTNAME.crt"
key="$DERP_HOSTNAME.key"
issued="$LEGO_STATE_DIR/certificates"
if cmp -s "$issued/$crt" "$DERP_CERT_DIR/$crt" && cmp -s "$issued/$key" "$DERP_CERT_DIR/$key"; then
    echo 'Certificate pair unchanged. Relay left running as-is.'
    exit 0
fi

generation=$(mktemp -d -- "${DERP_CERT_DIR%/*}/generation.XXXXXXXX")
install -m 0600 -- "$issued/$crt" "$issued/$key" "$generation/"
openssl verify -purpose sslserver -verify_hostname "$DERP_HOSTNAME" \
    -untrusted "$generation/$crt" "$generation/$crt" >/dev/null
cert_pubkey=$(openssl x509 -in "$generation/$crt" -pubkey -noout)
private_pubkey=$(openssl pkey -in "$generation/$key" -passin pass: -pubout)
if [[ $cert_pubkey != "$private_pubkey" ]]; then
    echo 'Lego output contains a mismatched certificate and key.' >&2
    exit 1
fi
expected=$(openssl x509 -in "$generation/$crt" -noout -fingerprint -sha256)

previous=$(readlink -- "$DERP_CERT_DIR" || true)
select_generation() {
    ln -s -- "$1" "$generation/next"
    mv -Tf -- "$generation/next" "$DERP_CERT_DIR"
}
serve_selected_generation() {
    local cert_dir
    cert_dir=$(realpath -e -- "$DERP_CERT_DIR") || return
    DERP_CERT_DIR="$cert_dir" "${compose[@]}" up -d --no-deps --no-build --pull never --force-recreate derper
}
served_leaf() {
    timeout 2s openssl s_client -connect "$LAN_BIND_IPV4:$1" \
        -servername "$DERP_HOSTNAME" -verify_hostname "$DERP_HOSTNAME" \
        -verify_return_error </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null
}

# Give each replacement a literal, immutable certificate directory to bind.
select_generation "$generation"
if serve_selected_generation; then
    for ((attempt = 0; attempt < 15; attempt++)); do
        if relay_leaf=$(served_leaf 443) && map_leaf=$(served_leaf "${DERP_MAP_PORT:-9443}") &&
            [[ $relay_leaf == "$expected" && $map_leaf == "$expected" ]]; then
            echo "Relay and map now serve the validated certificate. $expected"
            exit 0
        fi
        sleep 1
    done
fi

echo 'TLS activation failed. Restoring the prior certificate selection.' >&2
if [[ -n $previous ]]; then
    select_generation "$previous"
    serve_selected_generation
else
    "${compose[@]}" stop derper
    rm -- "$DERP_CERT_DIR"
fi
exit 1
