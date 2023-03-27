#!/bin/bash
#
ironic_client="baremetal"
nodes=($(jq -c -r '.[]' nodes.json))
n_nodes=${#nodes[@]}
start_idx=${1:-0}

function create_nodes() {
  start_idx=$1
  end_idx=$2
  if [[ $end_idx -ge $n_nodes ]]; then
    end_idx=$(( n_nodes - 1 ))
  fi
  jq ".[$start_idx:$(( end_idx + 1 ))]" nodes.json > batch.json
  for idx in $(seq $start_idx $end_idx); do
    node=${nodes[$idx]}
    uuid=$(echo ${node} | jq -r '.uuid')
    node_name=$(echo ${node} | jq -r '.name')
  ${ironic_client} node create --driver redfish --driver-info \
    redfish_address=http://192.168.111.1:8000 --driver-info \
    redfish_system_id=/redfish/v1/Systems/${uuid} --driver-info \
    redfish_username=admin --driver-info redfish_password=password \
    --uuid ${uuid} \
    --name ${node_name} > /dev/null
    echo "Created node ${node_name} on ironic"
  done
}

batch_size=${2:-200}
inspect_batch_size=${3:-30}
while true; do
  end_idx=$((start_idx + batch_size - 1))
  create_nodes $start_idx $end_idx
  ./07-inspect-nodes.sh $inspect_batch_size
  start_idx=$(( end_idx + 1 ))
  if [[ $start_idx -ge $(( n_nodes - 1 )) ]]; then
    exit 0
  fi
done
