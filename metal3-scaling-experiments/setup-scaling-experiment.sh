#!/usr/bin/env bash

set -eu

# Setup kind cluster and init metal3
kind create cluster --config kind-config.yaml
kubectl apply -k https://github.com/metal3-io/baremetal-operator/config/crd
kubectl taint node kind-control-plane node-role.kubernetes.io/control-plane-
kubectl taint node kind-control-plane2 node-role.kubernetes.io/control-plane-
kubectl taint node kind-control-plane3 node-role.kubernetes.io/control-plane-
clusterctl init --infrastructure=metal3

# Deploy BMO in test-mode
kubectl create ns baremetal-operator-system
kubectl apply -k bmo-test-mode
kubectl -n baremetal-operator-system wait --timeout=5m --for=condition=Available deploy/baremetal-operator-controller-manager

# Create 1 BMH (can be applied in multiple namespaces)
./produce-available-hosts.sh 1 > /tmp/test-hosts.yaml

# Download cluster-template
CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
# https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/examples/clusterctl-templates/clusterctl-cluster.yaml
CLUSTER_TEMPLATE_URL="https://raw.githubusercontent.com/metal3-io/cluster-api-provider-metal3/main/examples/clusterctl-templates/clusterctl-cluster.yaml"
wget -O "${CLUSTER_TEMPLATE}" "${CLUSTER_TEMPLATE_URL}"

## Create new target cluster
## -------------------------

# Cluster template required variables
export CLUSTER_APIENDPOINT_HOST="test-kube-apiserver.metal3.svc.cluster.local"
export CLUSTER_APIENDPOINT_PORT="6443"
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
        local:
          serverCertSANs:
            - etcd-server.metal3.cluster.svc.local
          peerCertSANs:
            - etcd-0.etcd.metal3.cluster.svc.local"
export IMAGE_CHECKSUM="97830b21ed272a3d854615beb54cf004"
export IMAGE_CHECKSUM_TYPE="md5"
export IMAGE_FORMAT="raw"
export IMAGE_URL="http://172.22.0.1/images/rhcos-ootpa-latest.qcow2"
export KUBERNETES_VERSION="v1.25.3"
export WORKERS_KUBEADM_EXTRA_CONFIG=""

## Create first cluster and fake API
CLUSTER="test"
NAMESPACE="metal3"
kubectl create namespace "${NAMESPACE}"

# It could be that the webhook is still not ready. Retry a few times
NUM=10
for (( retry = 1; retry <= NUM; ++retry )); do
  if kubectl -n "${NAMESPACE}" apply -f /tmp/test-hosts.yaml; then
    break
  fi
  sleep 2
done

# Create cluster!
clusterctl generate cluster "${CLUSTER}" \
  --from "${CLUSTER_TEMPLATE}" \
  --target-namespace "${NAMESPACE}" | kubectl apply -f -

## Generate certificates

# Kubeadm is configured to use /tmp/pki as certificate directory
rm --recursive --force /tmp/pki
mkdir -p /tmp/pki/etcd

# Wait for certificates
while ! kubectl -n "${NAMESPACE}" get secrets "${CLUSTER}-etcd" "${CLUSTER}-ca" &> /dev/null; do
  echo "Waiting for certificates to exist."
  sleep 1
done

# Get the etcd CA certificate and key.
# This is used by kubeadm to generate etcd peer, server and client certificates
kubectl -n "${NAMESPACE}" get secrets "${CLUSTER}-etcd" -o jsonpath="{.data.tls\.crt}" | base64 -d > /tmp/pki/etcd/ca.crt
kubectl -n "${NAMESPACE}" get secrets "${CLUSTER}-etcd" -o jsonpath="{.data.tls\.key}" | base64 -d > /tmp/pki/etcd/ca.key
# Get the k8s CA certificate and key.
# This is used by kubeadm to generate the API server certificates
kubectl -n "${NAMESPACE}" get secrets "${CLUSTER}-ca" -o jsonpath="{.data.tls\.crt}" | base64 -d > /tmp/pki/ca.crt
kubectl -n "${NAMESPACE}" get secrets "${CLUSTER}-ca" -o jsonpath="{.data.tls\.key}" | base64 -d > /tmp/pki/ca.key

# Generate certificates
kubeadm init phase certs etcd-peer --config kubeadm-config.yaml
kubeadm init phase certs etcd-server --config kubeadm-config.yaml
kubeadm init phase certs apiserver-etcd-client --config kubeadm-config.yaml
kubeadm init phase certs apiserver --config kubeadm-config.yaml

# Create secrets
kubectl -n "${NAMESPACE}" create secret tls etcd-peer --cert /tmp/pki/etcd/peer.crt --key /tmp/pki/etcd/peer.key
kubectl -n "${NAMESPACE}" create secret tls etcd-server --cert /tmp/pki/etcd/server.crt --key /tmp/pki/etcd/server.key
kubectl -n "${NAMESPACE}" create secret tls apiserver-etcd-client --cert /tmp/pki/apiserver-etcd-client.crt --key /tmp/pki/apiserver-etcd-client.key
kubectl -n "${NAMESPACE}" create secret tls apiserver --cert /tmp/pki/apiserver.crt --key /tmp/pki/apiserver.key

# Deploy etcd and API server
kubectl -n "${NAMESPACE}" apply -f etcd.yaml
kubectl -n "${NAMESPACE}" apply -f kube-apiserver-deployment.yaml
kubectl -n "${NAMESPACE}" wait --for=condition=Available deploy/test-kube-apiserver

# Get kubeconfig
clusterctl -n "${NAMESPACE}" get kubeconfig test > /tmp/kubeconfig-test.yaml
# Edit kubeconfig to point to 127.0.0.1:6443 and set up port forward to the pod
sed -i s/test-kube-apiserver."${NAMESPACE}".svc.cluster.local/127.0.0.1/ /tmp/kubeconfig-test.yaml
# In background
kubectl -n "${NAMESPACE}" port-forward svc/test-kube-apiserver 6443 &

# Wait for machine
while ! kubectl -n "${NAMESPACE}" get machine -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
  echo "Waiting for Machine to exist."
  sleep 1
done
MACHINE="$(kubectl -n "${NAMESPACE}" get machine -o jsonpath="{.items[0].metadata.name}")"

# Wait for metal3machine
while ! kubectl -n "${NAMESPACE}" get m3m -l cluster.x-k8s.io/cluster-name="${CLUSTER}" -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
  echo "Waiting for Metal3Machine to exist."
  sleep 5
done
METAL3MACHINE="$(kubectl -n "${NAMESPACE}" get m3m -l cluster.x-k8s.io/cluster-name="${CLUSTER}" -o jsonpath="{.items[0].metadata.name}")"
# Wait for metal3machine to associate with BMH
kubectl -n "${NAMESPACE}" wait --timeout=5m --for=condition=AssociateBMH "m3m/${METAL3MACHINE}"

# Find UID of BMH by checking the annotation of the m3m that does not yet have a providerID
BMH_NAMESPACE_NAME="$(kubectl -n "${NAMESPACE}" get m3m -o json | jq -r '.items[] | select(.spec | has("providerID") | not) | .metadata.annotations."metal3.io/BareMetalHost"')"
BMH_NAME="${BMH_NAMESPACE_NAME#*/}"
BMH_UID="$(kubectl -n "${NAMESPACE}" get bmh "${BMH_NAME}" -o jsonpath="{.metadata.uid}")"
sed -e "s/fake-node/${MACHINE}/g" -e "s/fake-uuid/${BMH_UID}/g" fake-node.yaml | \
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
kubectl --kubeconfig=/tmp/kubeconfig-test.yaml label node "${MACHINE}" node-role.kubernetes.io/control-plane=""
# Upload kubeadm config to configmap. This will mark the KCP as initialized.
kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system create cm kubeadm-config \
  --from-file=ClusterConfiguration=kubeadm-config.yaml
