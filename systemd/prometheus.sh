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

PROMETHEUS_IMAGE="@@prometheus-image@@"
PROMETHEUS_IMAGE_PATH="@@prometheus-path@@"

command -v podman >/dev/null 2>&1 || { echo >&2 "${0##*/}: command not found: podman"; exit 1; }

if [ $# -lt 2 ]; then
    echo >&2 "usage: prometheus PIDFILE CIDFILE [CONTAINER [VOLUME]]"
    exit 1
fi

PROMETHEUS_PIDFILE="$1"
PROMETHEUS_CIDFILE="$2"
PROMETHEUS_CONTAINER_NAME="${3-prometheus}"  

PROMETHEUS_VOLUME_MOUNT="/etc/prometheus/prometheus.yml:rw,exec"

# Load busybox image if it doesn't already exist
if ! podman image inspect "$PROMETHEUS_IMAGE" &>/dev/null; then
    # load the image
    podman load -i "$PROMETHEUS_IMAGE_PATH" || exit
    # get the tag
    PROMETHEUS_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="org.opencontainers.image.version=v2.36.1")
    # tag the image
    podman tag "$PROMETHEUS_IMAGE_ID" "$PROMETHEUS_IMAGE"
fi

# always ensure pid file is fresh
rm -f "$PROMETHEUS_PIDFILE"

# Create Prometheus container
if ! podman inspect --type container "$PROMETHEUS_CONTAINER_NAME" &>/dev/null; then
    rm -f "$PROMETHEUS_CIDFILE" || exit
    # Load prometheus image if it doesn't already exist
    if ! podman image inspect "$PROMETHEUS_IMAGE" &>/dev/null; then
        # load the image
        podman load -i "$PROMETHEUS_IMAGE_PATH"
        # get the tag
        PROMETHEUS_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="org.opencontainers.image.version=v2.36.1")
        # tag the image
        podman tag "$PROMETHEUS_IMAGE_ID" "$PROMETHEUS_IMAGE"
    fi
    podman create \
        --conmon-pidfile "$PROMETHEUS_PIDFILE" \
        --cidfile "$PROMETHEUS_CIDFILE" \
        --cgroups=no-conmon \
        --network host \
        --volume "/usr/sbin/prometheus.yml:${PROMETHEUS_VOLUME_MOUNT}" \
        --name "$PROMETHEUS_CONTAINER_NAME" \
        "$PROMETHEUS_IMAGE" || exit
    podman inspect "$PROMETHEUS_CONTAINER_NAME" || exit
fi
