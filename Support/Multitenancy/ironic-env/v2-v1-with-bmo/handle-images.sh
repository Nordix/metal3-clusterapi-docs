#!/bin/bash
#
N_NODES=${N_NODES:-1000}
REGISTRY_NAME="registry"
REGISTRY_PORT="5000"
IMAGE_NAMES=(
# For now, sushy-tools needs to be compiled locally with https://review.opendev.org/c/openstack/sushy-tools/+/875366
    # "quay.io/metal3-io/sushy-tools"
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:latest"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived:v0.2.0"
    "quay.io/metal3-io/mariadb:latest"
)


# Attach provisioning and baremetal network interfaces to minikube domain
virsh attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh attach-interface --domain minikube --model virtio --source baremetal --type network --config

# Start podman registry if it's not already running
if ! podman ps | grep -q "$REGISTRY_NAME"; then
    podman run -d -p "$REGISTRY_PORT":"$REGISTRY_PORT" --name "$REGISTRY_NAME" docker.io/library/registry:2.7.1
fi

podman pod create -n infra-pod || true
podman pod create -n ironic-pod || true
# Pull images, tag to local registry, and push to registry
for NAME in "${IMAGE_NAMES[@]}"; do
    # Pull and tag the image
    podman pull "$NAME"
    podman tag "$NAME" 127.0.0.1:"$REGISTRY_PORT"/localimages/"${NAME##*/}"
    # Push the image to the local registry
    podman push --tls-verify=false 127.0.0.1:5000/localimages/"${NAME##*/}"
done

# This image was built earlier, but can only be pushed now, after the network was setup
podman push --tls-verify=false 127.0.0.1:5000/localimages/sushy-tools

__dir__=$(realpath "$(dirname "$0")")
"$__dir__/ironic_tls_setup.sh"

# Define variables for repeated values
IRONIC_IMAGE="127.0.0.1:5000/localimages/ironic:latest"
    
# Run httpd container
podman run -d --net host --name httpd-infra \
    --pod infra-pod \
    -v /opt/metal3-dev-env/ironic:/shared \
    -e PROVISIONING_INTERFACE=provisioning \
    -e LISTEN_ALL_INTERFACES=false \
    --entrypoint /bin/runhttpd \
    "$IRONIC_IMAGE"
