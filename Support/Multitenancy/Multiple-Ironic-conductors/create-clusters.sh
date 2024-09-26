#!/bin/bash
#

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

retry_curl() {
  endpoint=$1
  timeout=${2:-5}
  while true; do
    ret=$(curl -s $endpoint 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo $ret
      return
    else
      sleep $timeout
    fi
  done
}

create_cluster() {
  bmh_index="${1}"
  cluster="test${bmh_index}"
  namespace="metal3"
  nodename="${cluster}"
  fake_ipa_port=$((9901 + (($bmh_index % ${N_FAKE_IPA}))))
  api_server_idx=$(($bmh_index % ${N_APISERVER_PODS}))
  api_server_port=3333

  export IMAGE_URL="http://192.168.222.1:8080/images/ipa-centos9-master-1f888161-622db3d8b8580/ipa-centos9-master.tar.gz"

  # api_server_name="metal3-fkas-system"

  api_server_name=$(kubectl get pods -n default -l app=metal3-fkas-system -o jsonpath='{.items[0].metadata.name}')
  kubectl port-forward pod/${api_server_name} ${api_server_port}:3333 2>/dev/null &

  sleep 5

  echo "Creating cluster ${cluster} in namespace ${namespace}"
  # kubectl create namespace "${namespace}"
  # for f in bmc-*.yaml; do
  #   kubectl -n "${namespace}" apply -f $f
  # done

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
  # port=30000

  # kubectl -n ${namespace} apply -f /tmp/${cluster}-etcd-secrets.yaml

  # Generate metal3 cluster
  export CLUSTER_APIENDPOINT_HOST="${host}"
  export CLUSTER_APIENDPOINT_PORT="${port}"
  echo "Generating cluster ${cluster} with clusterctl"
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" \
    --control-plane-machine-count=1 \
    --worker-machine-count=1 >/tmp/${cluster}-cluster.yaml
  kubectl apply -f /tmp/${cluster}-cluster.yaml

  sleep 10

  wait_for_resource() {
    resource=$1
    jsonpath=${2:-"{.items[0].metadata.name}"}
    while true; do
      kubectl -n "${namespace}" get "${resource}" -o jsonpath="${jsonpath}" 2>/dev/null
      if [ $? -eq 0 ]; then
        return
      fi
      sleep 2
    done
  }

  # bmh_name=$(wait_for_resource "bmh")
  # metal3machine=$(wait_for_resource "m3m")
  # machine=$(wait_for_resource "machine")
  #
  # providerID="metal3://$namespace/$bmh_name/$metal3machine"
  # echo "Done generating cluster ${cluster} with clusterctl"
  # retry_curl "localhost:${api_server_port}/updateNode?resource=${namespace}/${cluster}&nodeName=${machine}&providerID=${providerID}&nodeType=CP"
}

START_NUM=${1:-3}
i=${START_NUM}

# for i in $(seq $START_NUM $N_NODES); do
namespace="test${i}"
if [[ $(kubectl get ns | grep "${namespace}") != "" ]]; then
  echo "ERROR: Namespace ${namespace} exists. Skip creating cluster"
  continue
fi
create_cluster "${i}"
# done
