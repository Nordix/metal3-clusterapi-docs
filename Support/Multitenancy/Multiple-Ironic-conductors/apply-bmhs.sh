#!/bin/bash
. ./config.sh

namespace=${1:-"metal3"}

kubectl create ns "${namespace}"

for f in bmc-*.yaml; do
  kubectl -n "${namespace}" apply -f $f
done

# Wait for the BMHs to be in available state
check_bmh_status() {
  local namespace=$1
  # Get the list of BMH objects and their provisioning states
  local states=$(kubectl get bmh -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}:{.status.provisioning.state}{"\n"}{end}')

  # Loop through each BMH and check its state
  local all_available=true
  while IFS= read -r line; do
    local name=$(echo "$line" | cut -d':' -f1)
    local state=$(echo "$line" | cut -d':' -f2)

    if [ "$state" != "available" ]; then
      all_available=false
      echo "BMH $name is not available (current state: $state)"
    fi
  done <<<"$states"

  echo $all_available
}

echo "Waiting for all BMH objects to become 'available'..."
while true; do
  all_available=$(check_bmh_status "${namespace}")

  if [ "$all_available" == "true" ]; then
    echo "All BMH objects are in 'available' state."
    break
  fi

  sleep 60
done
