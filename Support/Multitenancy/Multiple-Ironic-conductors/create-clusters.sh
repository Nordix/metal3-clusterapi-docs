#!/bin/bash
#
set -eu

source ./config.sh
CLUSTER_TEMPLATE=manifests/cluster-template.yaml
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
  nodename="${cluster}"
  fake_ipa_port=$((9901 + (($bmh_index % ${N_FAKE_IPAS}))))
  api_server_idx=$(($bmh_index % ${N_FKAS}))
  api_server_port=3333

  api_server_name=$(kubectl get pods -n default -l app=metal3-fkas-system -o jsonpath="{.items[$api_server_idx].metadata.name}")
  kubectl port-forward pod/${api_server_name} ${api_server_port}:3333 2>/dev/null &

  sleep 5

  echo "Creating cluster ${cluster} in namespace ${namespace}"

  while true; do
    cluster_endpoint=$(curl -X POST "localhost:3333/register" \
      -H "Content-Type: application/json" -d '{
        "cluster": "'$cluster'",
        "namespace": "'$namespace'"
      }')
    echo $cluster_endpoint
    sleep 2
    if [ $? -eq 0 ]; then
      break
    else
      sleep 2
    fi
  done
  echo $cluster_endpoint
  host=$(echo ${cluster_endpoint} | jq -r ".Host")
  port=$(echo ${cluster_endpoint} | jq -r ".Port")

  # Generate metal3 cluster
  export CLUSTER_APIENDPOINT_HOST="${host}"
  export CLUSTER_APIENDPOINT_PORT="${port}"
  echo "Generating cluster ${cluster} with clusterctl"
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" \
    --control-plane-machine-count=${CP_NODE_COUNT} \
    --worker-machine-count=${WORKER_NODE_COUNT} >/tmp/${cluster}-cluster.yaml
  kubectl apply -f /tmp/${cluster}-cluster.yaml
}

START_NUM=${1:-3}
i=${START_NUM}

for i in $(seq $START_NUM $N_NODES); do
  create_cluster "${i}"
done
