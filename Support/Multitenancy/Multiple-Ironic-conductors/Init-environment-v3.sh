#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
# shellcheck disable=SC1091
. ./config.sh
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
sudo ./vm-setup.sh
./install-tools.sh
./configure-minikube.sh
sudo ./handle-images.sh
./build-sushy-tools-image.sh
./generate_unique_nodes.sh
./start_containers.sh
./start-minikube.sh
./build-api-server-container-image.sh

./install-ironic.sh
./install-bmo.sh

python create_nodes_v3.py

export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure=metal3
# kubectl apply -f capim-modified.yaml
yq ".spec.replicas = ${N_APISERVER_PODS}" apiserver-deployments.yaml | kubectl apply -f -
./generate-certificates.sh
# Wait for apiserver pod to exists
sleep 120

./create-clusters.sh
