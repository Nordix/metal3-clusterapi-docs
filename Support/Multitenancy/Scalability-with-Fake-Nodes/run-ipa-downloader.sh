#!/usr/bin/env bash

set -x

# In normal setup, ipa-downloader is setup as an initContainer for the ironic container, and it
# will make sure ipa is downloaded to an emptyDir before ironic starts. In multiple-conductor setup,
# we want to avoid that, as several ipa-downloader downloading the same ipa at the same time might
# make the server think it was a DDOS.
# In this script we make a hack by download ipa before installing ironic, then copy it to directory
# /shared in the minikube VM. In production, another method is required, probably by having a
# leader-election mechanism to let an ipa-downloader run only if it's the first one in the node.

__dir__=$(realpath "$(dirname "$0")")
IRONIC_DATA_DIR="${__dir__}/Metal3/ironic"
IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
IMAGE_DIR="${IRONIC_DATA_DIR}/html/images"
mkdir -p "${IMAGE_DIR}"
export IRONIC_DATA_DIR

# Check if ipa image was already downloaded
if [[ ! -f "${IMAGE_DIR}/downloaded" ]]; then
  docker rm -f ipa-downloader 2>/dev/null
  # Download ipa image
  cat <<EOF >"ironic.env"
HTTP_PORT=6180
DHCP_RANGE=192.168.222.100,192.168.222.200
DEPLOY_KERNEL_URL=http://192.168.222.100:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.222.100:6180/images/ironic-python-agent.initramfs
IRONIC_FAST_TRACK=true
EOF

  docker run -d --net host --privileged --name ipa-downloader \
    --env-file ironic.env \
    -v "${IRONIC_DATA_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

  docker wait ipa-downloader

  # Create this file, so that image won't be downloaded next time. This is to save time, as ipa-downloader
  # sometimes takes forever, due to network issue
  touch "${IMAGE_DIR}/downloaded"

  docker rm -f ipa-downloader 2>/dev/null
fi

# IPA version could change, so we copy the image to a static address
ipa_dir=$(find "${IMAGE_DIR}" -maxdepth 1 -type d -name 'ipa-*' -print -quit 2>/dev/null)

if [[ -d "${ipa_dir}" ]]; then
  cp "${ipa_dir}/ipa-centos9-master.tar.gz" "${IMAGE_DIR}"
fi

# Copy ipa image files to the ssh VM
minikube ssh "sudo mkdir -p /shared/html/images"
minikube cp "${IRONIC_DATA_DIR}"/html/images/ironic-python-agent.kernel /shared/html/images/
minikube cp "${IRONIC_DATA_DIR}"/html/images/ironic-python-agent.initramfs /shared/html/images/
minikube cp "${IRONIC_DATA_DIR}"/html/images/ironic-python-agent.headers /shared/html/images/
