#!/bin/bash

# shellcheck disable=SC1091
. ./config.sh
# Delete network connections
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
    if sudo virsh net-info $net &>/dev/null; then
        sudo virsh net-destroy $net
        sudo virsh net-undefine $net
    fi
done

# Delete directories
sudo rm -rf /opt/metal3-dev-env
sudo rm -rf "$(dirname "$0")/_clouds_yaml"

# Stop and delete minikube cluster
minikube stop
minikube delete --all --purge

# Stop and delete containers
containers=("ironic-ipa-downloader" "ironic" "keepalived" "registry" "ironic-client" "fake-ipa" "openstack-client" "httpd-infra")
for i in $(seq 1 "$N_SUSHY"); do
    containers+=("sushy-tools-$i")
done
for container in "${containers[@]}"; do
    echo "Deleting the container: $container"
    sudo podman stop "$container" &>/dev/null
    sudo podman rm "$container" &>/dev/null
done

rm -rf macaddrs uuids node.json nodes.json batch.json
