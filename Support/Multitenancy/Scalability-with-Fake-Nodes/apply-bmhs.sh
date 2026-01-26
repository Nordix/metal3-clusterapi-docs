#!/bin/bash
# shellcheck disable=SC1091
. ./config.sh

# Wait for specific batch of BMHs to be available
wait_for_batch_available() {
  local namespace=$1
  shift
  local batch_files=("$@")
  
  # Extract BMH names from batch files
  local batch_bmh_names=()
  for file in "${batch_files[@]}"; do
    # Look for the BMH name specifically (after "kind: BareMetalHost")
    bmh_name=$(awk '/kind: BareMetalHost/,/^---$/ { if (/^  name:/) print $2 }' "$file" | head -1)
    if [ -n "$bmh_name" ]; then
      batch_bmh_names+=("$bmh_name")
    fi
  done
  
  echo "Monitoring ${#batch_bmh_names[@]} BMHs in this batch: ${batch_bmh_names[*]}"
  
  while true; do
    local all_available=true
    local pending_count=0
    
    for bmh_name in "${batch_bmh_names[@]}"; do
      state=$(kubectl get bmh "$bmh_name" -n "$namespace" -o jsonpath='{.status.provisioning.state}' 2>/dev/null || echo "not-found")
      
      if [ "$state" != "available" ]; then
        all_available=false
        pending_count=$((pending_count + 1))
        echo "BMH $bmh_name is not available (current state: $state)"
      fi
    done
    
    if [ "$all_available" == "true" ]; then
      echo "All BMHs in this batch are now available!"
      break
    else
      echo "Waiting for $pending_count BMHs to become available..."
      sleep 30
    fi
  done
}

namespace=${1:-"metal3"}

kubectl create ns "${namespace}"

# Deploy BMHs in batches of 500
batch_size=500
batch_count=0
current_batch=()

# Get all BMH files and sort them numerically
mapfile -t bmh_files < <(ls bmc-*.yaml bmc-test*.yaml 2>/dev/null | sort -V)

# Check if any files were found
if [ ${#bmh_files[@]} -eq 0 ]; then
  echo "No BMH files found matching pattern bmc-*.yaml or bmc-test*.yaml"
  exit 1
fi

echo "Found ${#bmh_files[@]} BMH files to deploy"

for f in "${bmh_files[@]}"; do
  current_batch+=("$f")
  
  # When batch is full or it's the last file, deploy the batch
  if [ ${#current_batch[@]} -eq $batch_size ] || [ "$f" = "${bmh_files[-1]}" ]; then
    batch_count=$((batch_count + 1))
    echo "Deploying batch ${batch_count} with ${#current_batch[@]} BMHs..."
    
    # Apply all files in current batch
    for batch_file in "${current_batch[@]}"; do
      kubectl -n "${namespace}" apply -f "$batch_file"
    done
    
    echo "Waiting for batch ${batch_count} BMHs to become available..."
    wait_for_batch_available "${namespace}" "${current_batch[@]}"
    
    echo "Batch ${batch_count} is ready. Proceeding to next batch..."
    current_batch=()
  fi
done

# Wait for all BMHs to be in available state (legacy function for final check)
check_bmh_status() {
  local namespace=$1
  # Get the list of BMH objects and their provisioning states
  local states
  states=$(kubectl get bmh -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}:{.status.provisioning.state}{"\n"}{end}')

  # Loop through each BMH and check its state
  local all_available=true
  while IFS= read -r line; do
    local name
    local state
    name=$(echo "$line" | cut -d':' -f1)
    state=$(echo "$line" | cut -d':' -f2)

    if [ "$state" != "available" ]; then
      all_available=false
      echo "BMH $name is not available (current state: $state)"
    fi
  done <<<"$states"

  echo $all_available
}

echo "All batches deployed successfully!"
echo "Performing final verification of all BMH objects..."

final_check=$(check_bmh_status "${namespace}")
if [ "$final_check" == "true" ]; then
  echo "✅ All BMH objects are in 'available' state."
else
  echo "⚠️  Some BMHs may still be transitioning. Run the script again or check manually."
fi
