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

## Create certificates for backing clusters

rm --recursive --force /tmp/pki
mkdir -p /tmp/pki/etcd

CLUSTER="test"
NAMESPACE=etcd-system
kubectl create namespace "${NAMESPACE}"

sed -e "s/NAMESPACE/${NAMESPACE}/g" -e "s/\/CLUSTER//g" manifests/v2/kubeadm-config.yaml > "/tmp/kubeadm-config-${CLUSTER}.yaml"

# Generate CA certificates
kubeadm init phase certs etcd-ca --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
kubeadm init phase certs ca --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
# Generate etcd peer and server certificates
kubeadm init phase certs etcd-peer --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
kubeadm init phase certs etcd-server --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
