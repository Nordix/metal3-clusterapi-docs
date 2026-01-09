#!/usr/bin/env bash
set -euo pipefail

echo "Deleting all keylime-agents clusters..."

# Find and delete all keylime-agents-* clusters
CLUSTERS=$(kind get clusters 2>/dev/null | grep "^keylime-agents" || true)

if [[ -z "${CLUSTERS}" ]]; then
    echo "No agent clusters found"
    exit 0
fi

for cluster in ${CLUSTERS}; do
    echo "Deleting cluster: ${cluster}"
    kind delete cluster --name "${cluster}" || true
done

echo "All agent clusters deleted."
