#!/bin/sh
set -eu

if [ -z "${DERP_HOSTNAME:-}" ]; then
    exec /derper "$@"
fi
case "$DERP_HOSTNAME" in
    [!a-zA-Z0-9]*|*[!a-zA-Z0-9]|*[!a-zA-Z0-9.-]*)
        echo 'DERP_HOSTNAME must be a DNS hostname.' >&2
        exit 1
        ;;
esac

umask 022
mkdir -p /run/derp-map
for file in nginx.conf derpmap.json; do
    envsubst '${DERP_HOSTNAME}' \
        <"/usr/local/share/derp-map/$file.template" >"/run/derp-map/$file"
done

trap 'exit 0' TERM INT
/derper "$@" &
derper_pid=$!
nginx -c /run/derp-map/nginx.conf -g 'daemon off;' &
map_pid=$!
trap 'kill -TERM "$derper_pid" "$map_pid" 2>/dev/null || true; wait "$derper_pid" "$map_pid" || true' EXIT

# Restart the bundle if either listener exits unexpectedly.
wait -n
exit 1
