#!/bin/bash

# Disable and delete bridge interfaces
iface=baremetal
if ip link show $iface &>/dev/null; then
  sudo ip link set $iface down
  sudo brctl delbr $iface
fi

# Delete baremetal network
net="baremetal"
if virsh -c qemu:///system net-info $net &>/dev/null; then
  virsh -c qemu:///system net-destroy $net
  virsh -c qemu:///system net-undefine $net
fi

# Delete directories
sudo rm -rf /opt/metal3-dev-env
sudo rm -rf "$(dirname "$0")/_clouds_yaml"

# Stop and delete minikube cluster
minikube stop
minikube delete --all --purge

# Stop and delete containers
mapfile -t existing_containers < <(docker ps --all --format json | jq -r '.Names')
declare -a containers=("ipa-downloader" "ironic" "keepalived" "registry" "ironic-client" "openstack-client" "httpd-infra" "image-server")

for container in "${existing_containers[@]}"; do
  # shellcheck disable=SC2199
  if [[ "${containers[@]}" =~ $container || "${container}" =~ "sushy-tools-"* || "${container}" =~ "fake-ipa-"* ]]; then
    echo "Deleting the container: ${container}"
    docker rm -f "$container" &>/dev/null
  fi
done

rm -rf bmc-*.yaml

rm -rf macaddrs uuids node.json nodes.json batch.json in-memory-development.yaml sushy-tools-conf

rm -rf cert
