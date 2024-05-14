#!/usr/bin/env bash

set -x

CURRENT_DIR=$(realpath $(dirname "$0"))
# Image server variables
IMAGE_DIR="${CURRENT_DIR}/Metal3/images"
mkdir -p "${IMAGE_DIR}"

# Download ipa image
cat << EOF >"ironic.env"
HTTP_PORT=6180
DHCP_RANGE=192.168.222.100,192.168.222.200
DEPLOY_KERNEL_URL=http://192.168.222.100:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.222.100:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://192.168.222.100:6385/v1/
IRONIC_FAST_TRACK=true
EOF

# touch "${IMAGE_DIR}/rhcos-oota-latest.qcow2"

## Run the image server
docker run --name image-server -d \
  -p 80:8080 \
  -v "${IMAGE_DIR}:/usr/share/nginx/html" nginxinc/nginx-unprivileged
