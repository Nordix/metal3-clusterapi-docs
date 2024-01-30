#!/bin/bash

# shellcheck disable=SC1091
. ./config.sh
# Delete network connections
sudo systemctl enable --now libvirtd
sudo nmcli con delete baremetal provisioning

# Disable and delete bridge interfaces
for iface in baremetal provisioning; do
    if ip link show $iface &>/dev/null; then
        sudo ip link set $iface down
        sudo brctl delbr $iface
    fi
done

# Delete libvirt networks
for net in provisioning baremetal; do
    if virsh -c qemu:///system net-info $net &>/dev/null; then
        virsh -c qemu:///system net-destroy $net
        virsh -c qemu:///system net-undefine $net
    fi
done

# Delete directories
sudo rm -rf /opt/metal3-dev-env
sudo rm -rf "$(dirname "$0")/_clouds_yaml"

# Stop and delete minikube cluster
minikube stop
minikube delete --all --purge

# Stop and delete containers
declare -a running_containers=($(podman ps --all --format json | jq -r '.[].Names[0]'))
echo ${running_containers[0]}
declare -a containers=("ipa-downloader" "ironic" "keepalived" "registry" "ironic-client" "openstack-client" "httpd-infra")

for container in "${running_containers[@]}"; do
    if [[ "${containers[@]}" =~  "${container}" || "${container}" =~ "sushy-tools-"* || "${container}" =~ "fake-ipa-"* ]]; then
        echo "Deleting the container: ${container}"
        podman stop "$container" &>/dev/null
        podman rm "$container" &>/dev/null
    fi
done

rm -rf bmc-*.yaml

rm -rf macaddrs uuids node.json nodes.json batch.json in-memory-development.yaml sushy-tools-conf ironic.env

podman pod rm infra-pod ironic-pod
sudo rm -rf opt/metal3-dev-env/ironic/html
