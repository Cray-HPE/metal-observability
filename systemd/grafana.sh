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

# Load grafana image if it doesn't already exist
if ! podman image inspect "$GRAFANA_IMAGE" &>/dev/null; then
    # load the image
    podman load -i "$GRAFANA_IMAGE_PATH" || exit
    # get the tag
    GRAFANA_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="org.opencontainers.image.version=8.5.9")
    # tag the image
    podman tag "$GRAFANA_IMAGE_ID" "$GRAFANA_IMAGE"
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
        GRAFANA_IMAGE_ID=$(podman images --noheading --format "{{.Id}}" --filter label="org.opencontainers.image.version=8.5.9")
        # tag the image
        podman tag "$GRAFANA_IMAGE_ID" "$GRAFANA_IMAGE"
    fi
    podman create \
        --conmon-pidfile "$GRAFANA_PIDFILE" \
        --cidfile "$GRAFANA_CIDFILE" \
        --cgroups=no-conmon \
        --network host \
        --volume "/usr/sbin/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml" \
        --volume "/usr/sbin/dashboard.yml:/etc/grafana/provisioning/dashboards/dashboard.yml" \
        --volume "/usr/sbin/csm-install-progress.json:/etc/grafana/provisioning/dashboards/csm-install-progress.json" \
        --volume "/usr/sbin/device-error.json:/etc/grafana/provisioning/dashboards/device-error.json" \
        --volume "/usr/sbin/dhcp-error.json:/etc/grafana/provisioning/dashboards/dhcp-error.json" \
        --volume "/usr/sbin/known-issues-message-frequency.json:/etc/grafana/provisioning/dashboards/known-issues-message-frequency.json" \
        --volume "/usr/sbin/pxe-error.json:/etc/grafana/provisioning/dashboards/pxe-error.json" \
        --volume "/usr/sbin/pit-goss-test.json:/etc/grafana/provisioning/dashboards/pit-goss-test.json" \
        --name "$GRAFANA_CONTAINER_NAME" \
        "$GRAFANA_IMAGE" || exit
    podman inspect "$GRAFANA_CONTAINER_NAME" || exit
fi
