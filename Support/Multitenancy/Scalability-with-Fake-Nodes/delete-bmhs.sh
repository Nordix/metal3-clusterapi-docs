#!/bin/bash

# Script to delete BMHs from test501 to test1000
# This script will:
# 1. Delete the BMH resources from Kubernetes if they exist
# 2. Keep the YAML files intact

namespace=${1:-"metal3"}

echo "Deleting BMHs from test501 to test1000..."
echo "Using namespace: ${namespace}"

# Function to delete a single BMH
delete_bmh() {
    local bmh_name=$1
    local yaml_file="bmc-${bmh_name}.yaml"
    
    # Check if the YAML file exists
    if [ -f "${yaml_file}" ]; then
        echo "Processing ${bmh_name}..."
        
        # Try to delete from Kubernetes if it exists
        if kubectl get bmh "${bmh_name}" -n "${namespace}" &>/dev/null; then
            echo "  Deleting ${bmh_name} from Kubernetes..."
            
            # First try normal deletion
            kubectl delete bmh "${bmh_name}" -n "${namespace}" --timeout=30s &>/dev/null
            
            # Check if it's still there (stuck due to finalizers)
            if kubectl get bmh "${bmh_name}" -n "${namespace}" &>/dev/null; then
                echo "  BMH ${bmh_name} stuck, removing finalizers..."
                kubectl patch bmh "${bmh_name}" -n "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge
                # Force delete if still exists
                kubectl delete bmh "${bmh_name}" -n "${namespace}" --force --grace-period=0 &>/dev/null || true
            fi
            
            # Also delete the associated secret if it exists
            secret_name="${bmh_name}-bmc-secret"
            if kubectl get secret "${secret_name}" -n "${namespace}" &>/dev/null; then
                echo "  Removing finalizers from secret ${secret_name}..."
                kubectl patch secret "${secret_name}" -n "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge &>/dev/null || true
                echo "  Deleting secret ${secret_name} from Kubernetes..."
                kubectl delete secret "${secret_name}" -n "${namespace}" --timeout=10s &>/dev/null || true
            fi
        else
            echo "  ${bmh_name} not found in Kubernetes (may not be applied)"
        fi
        
        # Keep the YAML file intact
        echo "  YAML file ${yaml_file} preserved"
    else
        echo "YAML file ${yaml_file} not found, skipping..."
    fi
}

# Option for bulk deletion (faster for many BMHs)
bulk_delete=${2:-"false"}

if [ "$bulk_delete" = "bulk" ]; then
    echo "Using bulk deletion method..."
    
    # Get all BMHs matching the pattern (test501 to test1000)
    bmh_list=$(kubectl get bmh -n "${namespace}" -o name | grep -E 'test(50[1-9]|5[1-9][0-9]|[6-9][0-9][0-9]|1000)$' | cut -d'/' -f2)
    
    if [ -n "$bmh_list" ]; then
        echo "Found BMHs to delete: $(echo "$bmh_list" | wc -l) items"
        
        # Step 1: Remove finalizers from secrets first
        echo "Removing finalizers from secrets..."
        for bmh in $bmh_list; do
            secret_name="${bmh}-bmc-secret"
            if kubectl get secret "$secret_name" -n "${namespace}" &>/dev/null; then
                kubectl patch secret "$secret_name" -n "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge &
            fi
        done
        wait
        
        # Step 2: Remove finalizers from BMHs
        echo "Removing finalizers from BMHs..."
        for bmh in $bmh_list; do
            echo "$bmh"
            kubectl patch bmh "$bmh" -n "${namespace}" -p '{"metadata":{"finalizers":[]}}' --type=merge &
        done
        wait
        
        # Step 3: Delete secrets
        echo "Deleting secrets..."
        for bmh in $bmh_list; do
            secret_name="${bmh}-bmc-secret"
            kubectl delete secret "$secret_name" -n "${namespace}" --ignore-not-found=true &
        done
        wait
        
        # Step 4: Delete BMHs
        echo "Deleting BMHs..."
        for bmh in $bmh_list; do
            echo "Deleting BMH: $bmh"
            kubectl delete bmh "$bmh" -n "${namespace}" --force --grace-period=0 --timeout=30s &
            # Limit concurrent deletions to avoid overwhelming the API server
            if (( $(jobs -r | wc -l) >= 10 )); then
                wait -n  # Wait for any one job to complete
            fi
        done
        wait
    else
        echo "No BMHs found matching the pattern"
    fi
else
    # Individual deletion method
    echo "Using individual deletion method..."
    for i in $(seq 501 1000); do
        delete_bmh "test${i}"
    done
fi

echo "Deletion complete!"
echo "Summary:"
echo "- Attempted to delete BMHs test501 through test1000 from namespace '${namespace}'"
echo "- Preserved all YAML files for future use"
echo ""
echo "Usage:"
echo "  ./delete-bmhs.sh [namespace] [method]"
echo "  - namespace: Kubernetes namespace (default: metal3)"
echo "  - method: 'bulk' for faster bulk deletion, or leave empty for individual deletion"
echo ""
echo "Examples:"
echo "  ./delete-bmhs.sh                    # Delete from 'metal3' namespace individually"
echo "  ./delete-bmhs.sh metal3 bulk        # Delete from 'metal3' namespace using bulk method"
echo "  ./delete-bmhs.sh my-namespace       # Delete from 'my-namespace' individually"
echo ""
echo "You can verify the deletion with:"
echo "  kubectl get bmh -n ${namespace} | grep -E 'test(50[1-9]|5[1-9][0-9]|[6-9][0-9][0-9]|1000)'"
