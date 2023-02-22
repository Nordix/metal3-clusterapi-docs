#!/usr/bin/env bash

set -eu

# Before calling this script, you need to:
# - Setup a kubernetes cluster, e.g. kind create cluster --config manifests/kind-config-backing-cluster.yaml
# - Point to the correct kubeconfig/context. TODO: Maybe take kubeconfig as parameter?

# Certificates and kubeadm config created already

# "/tmp/kubeadm-config-${CLUSTER}.yaml"
# /tmp/pki/etcd/ca.crt /tmp/pki/etcd/ca.key
# /tmp/pki/etcd/peer.crt /tmp/pki/etcd/peer.key
# /tmp/pki/etcd/server.crt /tmp/pki/etcd/server.key

CLUSTER="test"
NAMESPACE=etcd-system
kubectl create namespace "${NAMESPACE}"

# Upload certificates
kubectl -n "${NAMESPACE}" create secret tls "${CLUSTER}-etcd" --cert /tmp/pki/etcd/ca.crt --key /tmp/pki/etcd/ca.key
kubectl -n "${NAMESPACE}" create secret tls etcd-peer --cert /tmp/pki/etcd/peer.crt --key /tmp/pki/etcd/peer.key
kubectl -n "${NAMESPACE}" create secret tls etcd-server --cert /tmp/pki/etcd/server.crt --key /tmp/pki/etcd/server.key

# Deploy ETCD
sed "s/CLUSTER/${CLUSTER}/g" manifests/v2/etcd.yaml | kubectl -n "${NAMESPACE}" apply -f -
kubectl -n etcd-system wait sts/etcd --for=jsonpath="{.status.availableReplicas}"=1

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
