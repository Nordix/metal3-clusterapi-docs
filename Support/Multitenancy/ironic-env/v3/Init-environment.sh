#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
. ./config.sh
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
./build-sushy-tools-image.sh
sudo ./01-vm-setup.sh
./02-configure-minikube.sh
sudo ./handle-images.sh
./generate_unique_nodes.sh
./start_containers.sh
./04-start-minikube.sh
./05-apply-manifests.sh
kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-controller-manager --timeout=300s
kubectl create ns metal3
clusterctl init --infrastructure=metal3
./start_fake_etcd.sh
python create_nodes.py
# rm -f /tmp/test-hosts.yaml
# ./produce-available-hosts.sh > /tmp/test-hosts.yaml
for i in $(seq 1 $N_NODES); do
  sleep 20
  ./create-clusters-v2.sh
done
