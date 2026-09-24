#!/bin/sh
set -e

# See the Dockerfile: put the launcher onto the (possibly freshly mounted)
# /opt/posapi before starting it.
cp -f /usr/local/lib/posapi/PosService /opt/posapi/PosService

# Anything other than the default command (e.g. `docker run ... sh`) runs as is.
if [ "$1" != "./PosService" ]; then
    exec "$@"
fi

# The launcher starts PosAPI but does not restart it when it dies, so the
# container would stay up with nothing serving 7080. Supervise PosAPI here and
# exit when it stays down, so the restart policy (`restart: unless-stopped`,
# `--restart`, or a Kubernetes pod) brings the whole thing back.
#
# POSAPI_DOWN_GRACE    seconds PosAPI may be gone before we exit. The launcher
#                      stops it briefly while updating it, hence the margin.
# POSAPI_START_TIMEOUT seconds to wait for PosAPI to appear at all (it is
#                      downloaded on first start).
grace="${POSAPI_DOWN_GRACE:-60}"
start_timeout="${POSAPI_START_TIMEOUT:-300}"
interval=5

"$@" &
launcher=$!

stop() {
    kill -TERM "$launcher" 2>/dev/null || true
    pkill -TERM -f '^/opt/posapi/PosAPI' 2>/dev/null || true
}
trap 'stop; wait "$launcher" 2>/dev/null; exit 0' TERM INT

seen=0
elapsed=0
down=0
while kill -0 "$launcher" 2>/dev/null; do
    sleep "$interval" &
    wait $!
    elapsed=$((elapsed + interval))

    if pgrep -f '^/opt/posapi/PosAPI' >/dev/null; then
        seen=1
        down=0
    elif [ "$seen" -eq 1 ]; then
        down=$((down + interval))
        if [ "$down" -ge "$grace" ]; then
            echo "docker-entrypoint: PosAPI has not been running for ${down}s; exiting so the container is restarted" >&2
            stop
            exit 1
        fi
    elif [ "$elapsed" -ge "$start_timeout" ]; then
        echo "docker-entrypoint: PosAPI did not start within ${start_timeout}s; exiting so the container is restarted" >&2
        stop
        exit 1
    fi
done

# The launcher itself exited: pass its status on.
wait "$launcher"
