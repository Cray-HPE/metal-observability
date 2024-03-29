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
set -euf -o pipefail
mkdir -p /opt/cray/tests/install/logs/grok_exporter

GROK_IMAGE="@@grok-exporter-image@@"
GROK_IMAGE_PATH="@@grok-exporter-path@@"

command -v podman >/dev/null 2>&1 || { echo >&2 "${0##*/}: command not found: podman"; exit 1; }

if [ $# -lt 2 ]; then
    echo >&2 "usage: grok-exporter PIDFILE CIDFILE [CONTAINER [VOLUME]]"
    exit 1
fi

GROK_PIDFILE="$1"
GROK_CIDFILE="$2"
GROK_CONTAINER_NAME="${3-grok-exporter}"  

GROK_VOLUME_MOUNT="/grok_exporter/config.yml:rw,exec"

# Load grok-exporter image if it doesn't already exist
if ! podman image inspect "$GROK_IMAGE" &>/dev/null; then
    # load the image
    podman load -i "$GROK_IMAGE_PATH" || exit
    # get the tag
    GROK_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="Name=grok_exporter")
    # tag the image
    podman tag "$GROK_IMAGE_ID" "$GROK_IMAGE"
fi

# always ensure pid file is fresh
rm -f "$GROK_PIDFILE"

# Create Grok-exporter container
if ! podman inspect --type container "$GROK_CONTAINER_NAME" &>/dev/null; then
    rm -f "$GROK_CIDFILE" || exit
    # Load grok-exporter image if it doesn't already exist
    if ! podman image inspect "$GROK_IMAGE" &>/dev/null; then
        # load the image
        podman load -i "$GROK_IMAGE_PATH"
        # get the tag
        GROK_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="Name=grok_exporter")
        # tag the image
        podman tag "$GROK_IMAGE_ID" "$GROK_IMAGE"
    fi
    podman create \
        --conmon-pidfile "$GROK_PIDFILE" \
        --cidfile "$GROK_CIDFILE" \
        --cgroups=no-conmon \
        --network host \
        --volume "/usr/sbin/config.yml:${GROK_VOLUME_MOUNT}" \
        --volume "/var/log/conman:/grok_exporter/logs/conman" \
        --volume "/opt/cray/tests/install/logs/grok_exporter:/grok_exporter/logs/goss_tests" \
        --name "$GROK_CONTAINER_NAME" \
        "$GROK_IMAGE" || exit
    podman inspect "$GROK_CONTAINER_NAME" || exit
fi
