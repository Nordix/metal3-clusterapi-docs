#!/bin/bash
#
N_NODES=${N_NODES:-1000}
IMAGE_NAMES=(
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:v26.0.1"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived:v0.2.0"
    "quay.io/metal3-io/mariadb:latest"
    "gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0"
    # "quay.io/metal3-io/api-server:latest"
)

for image in "${IMAGE_NAMES[@]}"; do
    if [[ ! $(docker images | grep ${image}) != "" ]]; then
        docker pull ${image}
    fi
    minikube image load "${image}"
done

CONTAINER_IMAGES=(
    "quay.io/metal3-io/sushy-tools:latest"
    "quay.io/metal3-io/fake-ipa:latest"
)
for image in "${CONTAINER_IMAGES[@]}"; do
    if [[ ! $(docker images | grep ${image}) != "" ]]; then
        docker pull ${image}
    fi
done
