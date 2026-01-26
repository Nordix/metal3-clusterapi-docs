#!/bin/bash
#
set -eu

# shellcheck disable=SC1091
source ./config.sh
export CLUSTER_APIENDPOINT_PORT="6443"
export IMAGE_CHECKSUM="97830b21ed272a3d854615beb54cf004"
export IMAGE_CHECKSUM_TYPE="md5"
export IMAGE_FORMAT="raw"
export KUBERNETES_VERSION="v1.26.0"
export WORKERS_KUBEADM_EXTRA_CONFIG=""
export WORKER_MACHINE_COUNT="0"
export NODE_DRAIN_TIMEOUT="60s"
export CTLPLANE_KUBEADM_EXTRA_CONFIG=""
CP_NODE_COUNT=${CP_NODE_COUNT:-1}
WORKER_NODE_COUNT=${WORKER_NODE_COUNT:-0}
__dir__=$(realpath "$(dirname "$0")")
IRONIC_DATA_DIR="${__dir__}/Metal3/ironic"
IMAGE_DIR="${IRONIC_DATA_DIR}/html/images"

cp "${IMAGE_DIR}"/ipa-centos9-master.*/ipa-centos9-master.tar.gz "${IMAGE_DIR}"
# We use the ipa image since the image doesn't matter
export IMAGE_URL="http://192.168.222.1:8080/images/ipa-centos9-master.tar.gz"

create_cluster() {
  bmh_index="${1}"
  cluster="test${bmh_index}"
  namespace="metal3"
  api_server_idx=$((bmh_index % N_FKAS))
  api_server_port=3333

  api_server_name=$(kubectl get pods -n default -l app=metal3-fkas-system -o jsonpath="{.items[$api_server_idx].metadata.name}")
  kubectl port-forward pod/"${api_server_name}" "${api_server_port}":3333 2>/dev/null &

  sleep 5

  echo "Creating cluster ${cluster} in namespace ${namespace}"

  # shellcheck disable=SC2086
  cluster_endpoint=$(curl -s -X POST "localhost:3333/register" \
    -H "Content-Type: application/json" -d '{
        "cluster": "'$cluster'",
        "namespace": "'$namespace'"
      }')
  host=$(echo "${cluster_endpoint}" | jq -r ".Host")
  port=$(echo "${cluster_endpoint}" | jq -r ".Port")

  # Generate metal3 cluster
  export CLUSTER_APIENDPOINT_HOST="${host}"
  export CLUSTER_APIENDPOINT_PORT="${port}"
  echo "Generating cluster ${cluster} with clusterctl"
  clusterctl generate cluster "${cluster}" \
    --target-namespace "${namespace}" \
    --control-plane-machine-count="${CP_NODE_COUNT}" \
    --worker-machine-count="${WORKER_NODE_COUNT}" >/tmp/"${cluster}"-cluster.yaml
  kubectl apply -f /tmp/"${cluster}"-cluster.yaml
}

# Function to wait for all BMHs to be provisioned
wait_for_bmh_provisioning() {
  local namespace="$1"
  local batch_end="$2"
  
  echo "Waiting for all BMHs to be provisioned after batch ending at cluster ${batch_end}..."
  
  while true; do
    # Count how many test BMHs are provisioned
    local provisioned_count
    provisioned_count=$(kubectl get bmh -n "${namespace}" -o jsonpath='{range .items[*]}{.metadata.name}:{.status.provisioning.state}{"\n"}{end}' 2>/dev/null | \
      grep ":provisioned\|:externally-provisioned" | \
      grep -E "test[0-9]+" | \
      wc -l)
    
    echo "Currently ${provisioned_count} BMHs are provisioned, need ${batch_end}"
    
    if [ "$provisioned_count" -ge "$batch_end" ]; then
      echo "Required ${batch_end} BMHs are provisioned. Proceeding to next batch."
      break
    fi
    
    local needed
    needed=$((batch_end - provisioned_count))
    echo "Waiting for ${needed} more BMHs to be provisioned..."
    
    # Wait 2 minutes before checking again
    sleep 120
  done
}

START_NUM=${1:-301}

for i in $(seq "$START_NUM" "$N_CLUSTERS"); do
  create_cluster "${i}"
  
  # Check and wait for BMH provisioning every 50 clusters
  if [ $((i % 50)) -eq 0 ]; then
    echo "Completed ${i} clusters. Checking BMH provisioning status..."
    wait_for_bmh_provisioning "metal3" "${i}"
    echo "All BMHs provisioned. Sleeping for 5 minutes before next batch..."
    sleep 300  # 5 minutes additional stabilization
    echo "Resuming cluster creation..."
  fi
done
