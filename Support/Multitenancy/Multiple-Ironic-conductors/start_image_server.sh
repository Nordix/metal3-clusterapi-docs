#!/usr/bin/env bash

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
# Image server variables
IMAGE_DIR="${REPO_ROOT}/Metal3/images"
mkdir -p "${IMAGE_DIR}"

# Download ipa image
cat << EOF >"ironic.env"
HTTP_PORT=6180
DHCP_RANGE=192.168.222.100,192.168.222.200
DEPLOY_KERNEL_URL=http://192.168.222.100:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.222.100:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://192.168.222.100:6385/v1/
CACHEURL=http://192.168.222.100/images
IRONIC_FAST_TRACK=true
EOF

IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
docker run -d --net host --privileged --name ipa-downloader \
  --env-file ironic.env \
  -v "${IMAGE_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

# touch "${IMAGE_DIR}/rhcos-oota-latest.qcow2"

## Run the image server
mkdir -p "${IMAGE_DIR}"
docker run --name image-server -d \
  -p 80:8080 \
  -v "${IMAGE_DIR}:/usr/share/nginx/html" nginxinc/nginx-unprivileged
