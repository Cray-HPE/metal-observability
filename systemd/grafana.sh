#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

GRAFANA_IMAGE="@@grafana-image@@"
GRAFANA_IMAGE_PATH="@@grafana-path@@"

command -v podman >/dev/null 2>&1 || { echo >&2 "${0##*/}: command not found: podman"; exit 1; }

if [ $# -lt 2 ]; then
    echo >&2 "usage: grafana PIDFILE CIDFILE [CONTAINER [VOLUME]]"
    exit 1
fi

GRAFANA_PIDFILE="$1"
GRAFANA_CIDFILE="$2"
GRAFANA_CONTAINER_NAME="${3-grafana}"  
GRAFANA_VOLUME_NAME="${4:-${GRAFANA_CONTAINER_NAME}-data}"

GRAFANA_VOLUME_MOUNT="/grafana-data:rw,exec"

# Create Grafana volume if not already present
if ! podman volume inspect "$GRAFANA_VOLUME_NAME" &>/dev/null; then
    # Load grafana image if it doesn't already exist
    if ! podman image inspect "$GRAFANA_IMAGE" &>/dev/null; then
        # load the image
        podman load -i "$GRAFANA_IMAGE_PATH" || exit
        # get the tag
        GRAFANA_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="name=GRAFANA Repository Manager") 
        # tag the image
        podman tag "$GRAFANA_IMAGE_ID" "$GRAFANA_IMAGE"
    fi
    podman run --rm --network host \
        -v "${GRAFANA_VOLUME_NAME}:${GRAFANA_VOLUME_MOUNT}" \
        "$GRAFANA_IMAGE" /bin/sh -c "
mkdir -p /grafana-data/etc
cat > /grafana-data/etc/grafana.properties << EOF
grafana.onboarding.enabled=false
grafana.scripts.allowCreation=true
grafana.security.randompassword=false
EOF
chown -Rv 200:200 /grafana-data
chmod -Rv u+rwX,go+rX,go-w /grafana-data
" || exit
    podman volume inspect "$GRAFANA_VOLUME_NAME" || exit
fi

# always ensure pid file is fresh
rm -f "$GRAFANA_PIDFILE"

# Create Grafana container
if ! podman inspect --type container "$GRAFANA_CONTAINER_NAME" &>/dev/null; then
    rm -f "$GRAFANA_CIDFILE" || exit
    # Load grafana image if it doesn't already exist
    if ! podman image inspect "$GRAFANA_IMAGE" &>/dev/null; then
        # load the image
        podman load -i "$GRAFANA_IMAGE_PATH"
        # get the tag
        GRAFANA_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="name=GRAFANA Repository Manager")
        # tag the image
        podman tag "$GRAFANA_IMAGE_ID" "$GRAFANA_IMAGE"
    fi
    podman create \
        --conmon-pidfile "$GRAFANA_PIDFILE" \
        --cidfile "$GRAFANA_CIDFILE" \
        --cgroups=no-conmon \
        --network host \
        --volume "${GRAFANA_VOLUME_NAME}:${GRAFANA_VOLUME_MOUNT}" \
        --name "$GRAFANA_CONTAINER_NAME" \
        "$GRAFANA_IMAGE" || exit
    podman inspect "$GRAFANA_CONTAINER_NAME" || exit
fi
