#!/bin/bash

ironic_client="baremetal"
node_names=($(jq -c -r '.[].name' batch.json))
n_nodes=${#node_names[@]}
batch_size=${1:-30}

function inspect_batch() {
  start_idx=$1
  end_idx=$2
  if [[ "$end_idx" -ge "$n_nodes" ]]; then
    end_idx=$(( n_nodes - 1 ))
  fi
  current_batch_size=$(( end_idx - start_idx + 1 ))
  inspected_nodes=()
  echo "${ironic_client}: Inspecting nodes batch ${node_names[$start_idx]} - ${node_names[$end_idx]}"
  while true; do
    for idx in $(seq "$start_idx" "$end_idx"); do
      node_name=${node_names[$idx]}
      if [[ " ${inspected_nodes[*]} " =~ " $node_name " ]]; then
        continue
      fi
      node_info=$("${ironic_client}" node show "$node_name" -f json)
      provisioning_state=$(echo "${node_info}" | jq -r '.provision_state')
      if [[ "$provisioning_state" == "enroll" ]]; then
        "${ironic_client}" node manage "${node_name}"
        continue
      fi 
      if [[ "$provisioning_state" == "verifying" || "$provisioning_state" == "inspect wait" || "$provisioning_state" == "inspecting" ]]; then
        continue
      fi
      inspection_info=$(echo "${node_info}" | jq -r '.inspection_finished_at')
      if [[ "$provisioning_state" == "manageable" ]]; then
        if [[ "$inspection_info" == "null" ]]; then
          "${ironic_client}" node inspect "${node_name}"
        else
          inspected_nodes+=("${node_name}")
          echo "${ironic_client}: ${node_name} was inspected at ${inspection_info}"
          if [[ ${#inspected_nodes[@]} == "$current_batch_size" ]]; then
            echo "${ironic_client}: Done batch"
            return
          fi
        fi
      fi
      if [[ "$provisioning_state" == "inspect failed" ]]; then
        echo "${ironic_client}: ${node_name} was failed in inspection"
        # ${ironic_client} node inspect $node_name
        inspected_nodes+=("${node_name}")
        if [[ $(echo "$inspected_nodes" | wc -w) == "$current_batch_size" ]]; then
          echo "${ironic_client}: Done batch"
          return
        fi
      fi
    done
  done
}

start_idx=0
while true; do
  end_idx=$((start_idx + batch_size - 1))
  inspect_batch "$start_idx" "$end_idx"
  start_idx=$(( end_idx + 1 ))
  if [[ "$start_idx" -ge "$n_nodes" ]]; then
    exit 0
  fi
done
