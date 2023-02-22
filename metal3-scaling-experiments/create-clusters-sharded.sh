#!/usr/bin/env bash

set -eu

CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
export CLUSTER_APIENDPOINT_HOST="test-kube-apiserver.metal3.svc.cluster.local"
export CLUSTER_APIENDPOINT_PORT="6443"
# For external ETCD
export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    clusterConfiguration:
      controlPlaneEndpoint: test-kube-apiserver.metal3.svc.cluster.local:6443
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
        - 0.0.0.0
        - test-kube-apiserver.metal3.svc.cluster.local
      etcd:
        external:
          endpoints:
            - https://etcd-server.metal3.cluster.svc.local:2379
          caFile: /etc/kubernetes/pki/etcd/ca.crt
          certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
          keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key"
# For internal ETCD
# export CTLPLANE_KUBEADM_EXTRA_CONFIG="
#     clusterConfiguration:
#       controlPlaneEndpoint: test-kube-apiserver.metal3.svc.cluster.local:6443
#       apiServer:
#         certSANs:
#         - localhost
#         - 127.0.0.1
#         - 0.0.0.0
#         - test-kube-apiserver.metal3.svc.cluster.local
#       etcd:
#         local:
#           serverCertSANs:
#             - etcd-server.metal3.cluster.svc.local
#           peerCertSANs:
#             - etcd-0.etcd.metal3.cluster.svc.local"
export IMAGE_CHECKSUM="97830b21ed272a3d854615beb54cf004"
export IMAGE_CHECKSUM_TYPE="md5"
export IMAGE_FORMAT="raw"
export IMAGE_URL="http://172.22.0.1/images/rhcos-ootpa-latest.qcow2"
export KUBERNETES_VERSION="v1.25.3"
export WORKERS_KUBEADM_EXTRA_CONFIG=""

create_cluster() {
  cluster="${1:-test-1}"
  namespace="${2:-${cluster}}"

  echo "Creating cluster ${cluster} in namespace ${namespace}"

  # Upload same CA certs as used in the first cluster
  kubectl -n "${namespace}" create secret tls "${cluster}-etcd" --cert /tmp/pki/etcd/peer.crt --key /tmp/pki/etcd/peer.key
  kubectl -n "${namespace}" create secret tls "${cluster}-ca" --cert /tmp/pki/ca.crt --key /tmp/pki/ca.key
  # For external ETCD
  kubectl -n "${namespace}" create secret tls "${cluster}-apiserver-etcd-client" --cert /tmp/pki/apiserver-etcd-client.crt --key /tmp/pki/apiserver-etcd-client.key

  # Create cluster!
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" | kubectl apply -f -

  # Wait for machine
  while ! kubectl -n "${namespace}" get machine -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
    # echo "Waiting for Machine to exist."
    sleep 5
  done
  machine="$(kubectl -n "${namespace}" get machine -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}")"

  # Wait for metal3machine
  while ! kubectl -n "${namespace}" get m3m -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
    # echo "Waiting for Metal3Machine to exist."
    sleep 5
  done
  metal3machine="$(kubectl -n "${namespace}" get m3m -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}")"

  # Wait for metal3machine to associate with BMH
  kubectl -n "${namespace}" wait --timeout=5m --for=condition=AssociateBMH "m3m/${metal3machine}"

  # Set correct node name and apply
  # Find UID of BMH by checking the annotation of the m3m that does not yet have a providerID
  bmh_namespace_name="$(kubectl -n "${namespace}" get m3m -l cluster.x-k8s.io/cluster-name="${cluster}" -o json | jq -r '.items[] | select(.spec | has("providerID") | not) | .metadata.annotations."metal3.io/BareMetalHost"')"
  bmh_name="${bmh_namespace_name#*/}"
  bmh_uid="$(kubectl -n "${namespace}" get bmh "${bmh_name}" -o jsonpath="{.metadata.uid}")"
  sed -e "s/fake-node/${machine}/g" -e "s/fake-uuid/${bmh_uid}/g" fake-node.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml label node "${machine}" node-role.kubernetes.io/control-plane=""

  # Add static pods to make kubeadm control plane manager happy
  sed "s/node-name/${machine}/g" kube-apiserver-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  sed "s/node-name/${machine}/g" kube-controller-manager-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  sed "s/node-name/${machine}/g" kube-scheduler-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  # Set status on the pods (it is not added when using create/apply).
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-apiserver-${machine}" \
    --subresource=status --patch-file=kube-apiserver-pod-status.yaml
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-controller-manager-${machine}" \
    --subresource=status --patch-file=kube-controller-manager-pod-status.yaml
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-scheduler-${machine}" \
    --subresource=status --patch-file=kube-scheduler-pod-status.yaml
}

create_shard() {
  namespace="${1:-test-1}"

  echo "Creating shard for namespace ${namespace}"

  # For each shard, create a CAPKCP controller, namespace and BMHs
  # Create namespace and BMH
  kubectl create namespace "${namespace}"
  kubectl -n "${namespace}" apply -f /tmp/test-hosts.yaml
  # Create CAPKCP
  sed "s/NAMESPACE/${namespace}/g" capkcp-deploy.yaml | kubectl apply -f -
  # Wait for BMHs to be available
  kubectl -n "${namespace}" wait bmh --for=jsonpath="{.status.provisioning.state}"=available --all
}

# Number of clusters per shard
NUM="${1:-10}"
# Number of shards (namespaces and CAPKCP controller)
SHARDS="${2:-10}"
# Add more clusters in steps of step.
STEP="10"

# Set --namespace flag to watch specific namespace
# Disable --leaderelect and set spec.strategy.type to Recreate
kubectl -n capi-kubeadm-control-plane-system patch deploy capi-kubeadm-control-plane-controller-manager \
  --patch-file=/dev/stdin <<EOF
spec:
  strategy:
    type: Recreate
    rollingUpdate:
  template:
    spec:
      containers:
      - name: manager
        args:
        - --namespace=metal3
        - --metrics-bind-addr=localhost:8080
        - --feature-gates=ClusterTopology=false,KubeadmBootstrapFormatIgnition=false
EOF
kubectl -n capi-kubeadm-control-plane-system rollout status deploy capi-kubeadm-control-plane-controller-manager --watch

# Create 1 BMH (can be applied in multiple namespaces)
./produce-available-hosts.sh "${NUM}" > /tmp/test-hosts.yaml

for (( shard = 1; shard <= SHARDS; ++shard )); do
  create_shard "test-${shard}"
  for (( cluster = 1; cluster <= NUM; ++cluster )); do
    create_cluster "test-${cluster}" "test-${shard}" &
    if (( cluster % STEP == 0 )); then
      echo "Waiting for ${STEP} clusters to be created in the background."
      wait
    fi
  done
done

wait
echo "Created ${NUM} clusters x ${SHARDS} shards"
