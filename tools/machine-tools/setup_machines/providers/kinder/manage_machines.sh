#!/bin/bash

cluster_name="${1}"
action="${2}"
masters_count="${3}"
workers_count="${4}"
kindest_node_ver="${5}"

# To items
# Build node images such that | i.e replace configure_machines.sh by a new image
#   specific versions of kubeadm, kubelet, kubectl are used
#   More network intrafaces are added
#   Utility binaries, such as net-tools, are baked into the images

# Create a set of machines for kubernetes setup

if [ "${action}" == "create" ]; then
    kinder create cluster \
        --control-plane-nodes "${masters_count}" \
        --worker-nodes "${workers_count}" \
        --image "${kindest_node_ver}" \
        --name "${cluster_name}"

    # Verify creation of machines
    echo -e "\n---List of created machines---\n"
    kinder get nodes --name "${cluster_name}" | sort

elif [ "${action}" == "delete" ]; then
    kinder delete cluster --name "${cluster_name}" 2>/dev/null
else
    echo "Use Either create or delete or show for action"
fi
