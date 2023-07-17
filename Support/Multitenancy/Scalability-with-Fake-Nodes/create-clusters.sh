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

cp "${IMAGE_DIR}"/ipa-centos9-master-*/ipa-centos9-master.tar.gz "${IMAGE_DIR}"
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

START_NUM=${1:-1}

for i in $(seq "$START_NUM" "$N_CLUSTERS"); do
  create_cluster "${i}"
done
