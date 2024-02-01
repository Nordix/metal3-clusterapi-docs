#!/bin/bash

if [ -z "${1}" ]; then
    echo -e "Error: Missing cluster name\nUsage:./setup_test_environment.sh <cluster name>"
    exit 1
fi

cluster_name="${1}"

# check cluster exists | failure stop script
kinder get nodes --name "${cluster_name}"

# Remove machines
"$(dirname "${0}")"/manage_machines.sh "${cluster_name}" delete

# Remove networks
networks=$(docker network list --format '{{.Name}}' | grep -iE 'control|traffic' | sort)
for network in ${networks}; do
    echo -e "Removing network: ${network}"
    docker network rm "${network}" 2>/dev/null
done
