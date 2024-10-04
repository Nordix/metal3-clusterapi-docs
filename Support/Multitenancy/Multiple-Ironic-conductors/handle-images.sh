#!/bin/bash
#
N_NODES=${N_NODES:-1000}
IMAGE_NAMES=(
# For now, sushy-tools needs to be compiled locally with https://review.opendev.org/c/openstack/sushy-tools/+/875366
    "quay.io/metal3-io/sushy-tools"
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:latest"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived:v0.2.0"
    "quay.io/metal3-io/mariadb:latest"
    "quay.io/metal3-io/api-server:latest"
)

for image in "${IMAGE_NAMES[@]}"; do
    if [[ ! $(docker images | grep ${image}) != "" ]]; then
        docker pull ${image}
    fi
    minikube image load "${image}"
done
