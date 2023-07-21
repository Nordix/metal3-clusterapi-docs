#!/bin/bash

CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
# https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/examples/clusterctl-templates/clusterctl-cluster.yaml
CLUSTER_TEMPLATE_URL="https://raw.githubusercontent.com/metal3-io/cluster-api-provider-metal3/main/examples/clusterctl-templates/clusterctl-cluster.yaml"
wget -O "${CLUSTER_TEMPLATE}" "${CLUSTER_TEMPLATE_URL}"

rm --recursive --force /tmp/pki
mkdir -p /tmp/pki/etcd

CLUSTER="test"
NAMESPACE=etcd-system
kubectl create namespace "${NAMESPACE}"

sed -e "s/NAMESPACE/${NAMESPACE}/g" -e "s/\/CLUSTER//g" manifests/kubeadm-config.yaml > "/tmp/kubeadm-config-${CLUSTER}.yaml"

# Generate CA certificates
kubeadm init phase certs etcd-ca --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
kubeadm init phase certs ca --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
# Generate etcd peer and server certificates
kubeadm init phase certs etcd-peer --config "/tmp/kubeadm-config-${CLUSTER}.yaml"
kubeadm init phase certs etcd-server --config "/tmp/kubeadm-config-${CLUSTER}.yaml"

sleep 10

# Upload certificates
kubectl -n "${NAMESPACE}" create secret tls "${CLUSTER}-etcd" --cert /tmp/pki/etcd/ca.crt --key /tmp/pki/etcd/ca.key
kubectl -n "${NAMESPACE}" create secret tls etcd-peer --cert /tmp/pki/etcd/peer.crt --key /tmp/pki/etcd/peer.key
kubectl -n "${NAMESPACE}" create secret tls etcd-server --cert /tmp/pki/etcd/server.crt --key /tmp/pki/etcd/server.key

# Deploy ETCD
sed "s/CLUSTER/${CLUSTER}/g" manifests/etcd.yaml | kubectl -n "${NAMESPACE}" apply -f -

kubectl -n etcd-system wait sts/etcd --for=jsonpath="{.status.availableReplicas}"=1 --timeout=300s

# Create root role
kubectl -n etcd-system exec etcd-0 -- etcdctl \
  --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
  role add root
# Create root user
kubectl -n etcd-system exec etcd-0 -- etcdctl \
  --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
  user add root --new-user-password="rootpw"
kubectl -n etcd-system exec etcd-0 -- etcdctl \
  --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
  user grant-role root root
# Enable authentication
kubectl -n etcd-system exec etcd-0 -- etcdctl \
  --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
  auth enable
