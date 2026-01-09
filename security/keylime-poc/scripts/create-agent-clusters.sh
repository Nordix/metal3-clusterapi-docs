#!/usr/bin/env bash
set -euo pipefail

CLUSTER_COUNT="$1"
K8S_AGENTS="$2"

echo "Creating ${CLUSTER_COUNT} agent cluster(s)..."

for i in $(seq 1 "${CLUSTER_COUNT}"); do
    CLUSTER_NAME="keylime-agents-${i}"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo "Cluster ${CLUSTER_NAME} already exists"
    else
        echo "Creating cluster ${CLUSTER_NAME}..."
        # Generate temporary config with correct cluster name
        sed "s/keylime-agents/keylime-agents-${i}/g" "${K8S_AGENTS}/kind-config.yaml" | \
            kind create cluster --config -
    fi
done

echo "All agent clusters created."
