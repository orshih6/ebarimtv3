#!/bin/sh
set -e

# See the Dockerfile: put the launcher onto the (possibly freshly mounted)
# /opt/posapi before starting it.
cp -f /usr/local/lib/posapi/PosService /opt/posapi/PosService

exec "$@"
