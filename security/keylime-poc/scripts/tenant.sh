#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run keylime_tenant commands in the tenant pod
# Usage: ./scripts/tenant.sh [keylime_tenant arguments]
# Example: ./scripts/tenant.sh -c reglist
# Example: ./scripts/tenant.sh -c add --push-model -u <uuid>

NAMESPACE="keylime"
POD_NAME="keylime-tenant"

# Check if we're in the infra cluster context
if ! kubectl config current-context | grep -q "keylime-infra"; then
    echo "Switching to keylime-infra context..."
    kubectl config use-context kind-keylime-infra
fi

# Check if tenant pod exists
if ! kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" &>/dev/null; then
    echo "Error: Tenant pod '${POD_NAME}' not found in namespace '${NAMESPACE}'"
    echo "Run 'make run-infra' first to deploy the infra cluster"
    exit 1
fi

# Run keylime_tenant in the pod
exec kubectl exec -it "${POD_NAME}" -n "${NAMESPACE}" -- keylime_tenant "$@"
