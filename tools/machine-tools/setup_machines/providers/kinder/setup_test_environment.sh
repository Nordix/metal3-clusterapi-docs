#!/bin/bash

# This scripts needs to be replaced by an docker container image
cluster_name="${1}"
masters_count="${2:-3}"
workers_count="${3:-3}"
kindest_node_ver="${4:-kindest/node:v1.18.0}"

if [ -z "${1}" ]; then
    echo -e "Error: Missing cluster name\nUsage:./setup_test_environment.sh <cluster name> [<number of controlplanes> <number of workers> <kindest_node_ver>]"
    exit 1
fi

# Add more networks following the naming pattern
networks=("control_network_api" "control_network_etcd" "traffic_network_1" "traffic_network_2")
subnets=("192.168.10.0/24" "192.168.20.0/24" "192.168.100.0/24" "192.168.200.0/24")

if [ "${#networks[@]}" != "${#subnets[@]}" ]; then
    echo -e "Error: Number of subnets does not match number of networks\n"
    exit 1
fi

# Remove existing and create new machines
"$(dirname "${0}")"/manage_machines.sh "$cluster_name" delete

"$(dirname "${0}")"/manage_machines.sh "$cluster_name" create "${masters_count}" "${workers_count}" "${kindest_node_ver}"

# Install utility binaries on machines, Eg. net-tools
machines=$(kinder get nodes --name "${cluster_name}")
for machine in ${machines}; do
    docker exec "${machine}" bash -c 'apt-get update -y; apt-get install -y tree vim net-tools mlocate iputils-ping'
done

# Remove existing and create more control plane networks
for i in $(seq 0 $(("${#networks[@]}" - 1))); do
    docker network rm "${networks[$i]}" 2>/dev/null
    docker network create --driver=bridge --subnet="${subnets[$i]}" "${networks[$i]}"
done

# Add more networks to control plane machines
"$(dirname "${0}")"/manage_interfaces.sh "${cluster_name}" delete

"$(dirname "${0}")"/manage_interfaces.sh "${cluster_name}" add

# show IP address assignment
"$(dirname "${0}")"/manage_interfaces.sh "${cluster_name}" show
