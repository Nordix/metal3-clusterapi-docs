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
  namespace="${cluster}"
  nodename="${cluster}"
  fake_ipa_port=$(( 9901 + (( $bmh_index % ${N_FAKE_IPA} )) ))
  api_server_idx=$(( $bmh_index % ${N_APISERVER_PODS} ))
  api_server_port=$(( 3333 + ${api_server_idx} ))

  export IMAGE_URL="http://192.168.222.1:${fake_ipa_port}/images/rhcos-ootpa-latest.qcow2"
  # export IMAGE_URL="http://192.168.111.1:8080/rhcos-ootpa-latest.qcow2"

  api_server_name=$(kubectl get pods -l app=capim -o jsonpath="{.items[${api_server_idx}].metadata.name}")

  kubectl port-forward pod/${api_server_name} ${api_server_port}:3333 2>/dev/null&

  echo "Creating cluster ${cluster} in namespace ${namespace}"
  kubectl create namespace "${namespace}"
  kubectl -n "${namespace}" apply -f bmc-${nodename}.yaml

  caKeyEncoded=$(cat /tmp/ca.key | base64 -w 0)
  caCertEncoded=$(cat /tmp/ca.crt | base64 -w 0)
  etcdKeyEncoded=$(cat /tmp/etcd.key | base64 -w 0)
  etcdCertEncoded=$(cat /tmp/etcd.crt | base64 -w 0)

  while true; do
    cluster_endpoints=$(retry_curl "localhost:${api_server_port}/register?resource=${namespace}/${cluster}&caKey=${caKeyEncoded}&caCert=${caCertEncoded}&etcdKey=${etcdKeyEncoded}&etcdCert=${etcdCertEncoded}")
    if jq -e . >/dev/null 2>&1 <<<"$cluster_endpoints"; then
      break
    else
      sleep 2
    fi
  done
  echo $cluster_endpoints
  host=$(echo ${cluster_endpoints} | jq -r ".Host")
  port=$(echo ${cluster_endpoints} | jq -r ".Port")

  cat <<EOF > "/tmp/${cluster}-ca-secrets.yaml"
apiVersion: v1
kind: Secret
metadata:
  labels:
    cluster.x-k8s.io/cluster-name: ${cluster}
  name: ${cluster}-ca
  namespace: ${namespace}
type: kubernetes.io/tls
data:
  tls.crt: ${caCertEncoded}
  tls.key: ${caKeyEncoded}
EOF

  kubectl -n ${namespace} apply -f /tmp/${cluster}-ca-secrets.yaml

  cat <<EOF > "/tmp/${cluster}-etcd-secrets.yaml"
apiVersion: v1
kind: Secret
metadata:
  labels:
    cluster.x-k8s.io/cluster-name: ${cluster}
  name: ${cluster}-etcd
  namespace: ${namespace}
type: kubernetes.io/tls
data:
  tls.crt: ${etcdCertEncoded}
  tls.key: ${etcdKeyEncoded}
EOF

  kubectl -n ${namespace} apply -f /tmp/${cluster}-etcd-secrets.yaml

  # Generate metal3 cluster
  export CLUSTER_APIENDPOINT_HOST="${host}"
  export CLUSTER_APIENDPOINT_PORT="${port}"
  echo "Generating cluster ${cluster} with clusterctl"
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" > /tmp/${cluster}-cluster.yaml
  kubectl apply -f /tmp/${cluster}-cluster.yaml

  sleep 10

  wait_for_resource() {
    resource=$1
    jsonpath=${2:-"{.items[0].metadata.name}"}
    while true; do
      kubectl -n "${namespace}" get "${resource}" -o jsonpath="${jsonpath}" 2> /dev/null
      if [ $? -eq 0 ]; then
        return
      fi
      sleep 2
    done
  }

  bmh_name=$(wait_for_resource "bmh")
  metal3machine=$(wait_for_resource "m3m")
  machine=$(wait_for_resource "machine")

  providerID="metal3://$namespace/$bmh_name/$metal3machine"
  echo "Done generating cluster ${cluster} with clusterctl"
  retry_curl "localhost:${api_server_port}/updateNode?resource=${namespace}/${cluster}&nodeName=${machine}&providerID=${providerID}"
}

START_NUM=${1:-1}

for i in $(seq $START_NUM $N_NODES); do
  namespace="test${i}"
  if [[ $(kubectl get ns | grep "${namespace}") != "" ]]; then
    echo "ERROR: Namespace ${namespace} exists. Skip creating cluster"
    continue
  fi
  create_cluster "${i}"
done

# Wait for all BMHs to be available. Clusters should be more or less ready by then.
desired_states=("available" "provisioning" "provisioned")
for i in $(seq $START_NUM $N_NODES); do
  namespace="test${i}"
  bmh_name="$(kubectl -n ${namespace} get bmh -o jsonpath='{.items[0].metadata.name}')"
  echo "Waiting for BMH ${bmh_name} to become available."
  while true; do
    bmh_state="$(kubectl -n ${namespace} get bmh -o jsonpath='{.items[0].status.provisioning.state}')"
    if [[ "${desired_states[@]}" =~ "${bmh_state}" ]]; then
      break
    fi
    sleep 3
  done
done

# Run describe for all clusters
for i in $(seq $START_NUM $N_NODES); do
  clusterctl -n "test${i}" describe cluster "test${i}"
done
