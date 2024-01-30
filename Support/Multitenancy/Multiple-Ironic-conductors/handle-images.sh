#!/bin/bash
#
N_NODES=${N_NODES:-1000}
IMAGE_NAMES=(
# For now, sushy-tools needs to be compiled locally with https://review.opendev.org/c/openstack/sushy-tools/+/875366
    # "quay.io/metal3-io/sushy-tools"
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:latest"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived:v0.2.0"
    "quay.io/metal3-io/mariadb:latest"
)

REGISTRY_PORT="5000"
# Pull images, tag to local registry, and push to registry
for NAME in "${IMAGE_NAMES[@]}"; do
    # Pull and tag the image
    podman pull "$NAME"
    LOCAL_IMAGE_NAME="127.0.0.1:${REGISTRY_PORT}/localimages/${NAME##*/}"
    podman tag "$NAME" "${LOCAL_IMAGE_NAME}"
    # Push the image to the local registry
    podman push --tls-verify=false "${LOCAL_IMAGE_NAME}"
    minikube image load "${LOCAL_IMAGE_NAME}"
done

__dir__=$(realpath "$(dirname "$0")")
sudo "$__dir__/ironic_tls_setup.sh"

IRONIC_IMAGE="127.0.0.1:5000/localimages/ironic:latest"
# Run httpd container
podman run -d --net host --name httpd-infra \
    --pod infra-pod \
    -v "${__dir__}/opt/metal3-dev-env/ironic":/shared \
    -e PROVISIONING_INTERFACE=provisioning \
    -e LISTEN_ALL_INTERFACES=false \
    --entrypoint /bin/runhttpd \
    "$IRONIC_IMAGE"
