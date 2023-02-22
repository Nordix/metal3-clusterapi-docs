#!/usr/bin/env bash

set -eu

delete_cluster() {
  kubeconfig_external="${1}"
  cluster="${2:-test-1}"
  namespace="${3:-${cluster}}"

  kubectl -n "${namespace}" delete cluster "${cluster}" || true

  # Delete etcd user
  kubectl --kubeconfig="${kubeconfig_external}" -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    user delete "${cluster}"
  # Delete role
  kubectl --kubeconfig="${kubeconfig_external}" -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    role delete "${cluster}"
  # Delete data
  kubectl --kubeconfig="${kubeconfig_external}" -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    del "/${cluster}" --prefix

  kubectl delete namespace "${namespace}" || true
  kubectl --kubeconfig="${kubeconfig_external}" delete namespace "${namespace}"
}

NUM="${1:-10}"
# Delete clusters in steps of step.
STEP="10"
# Kubeconfig for external backing cluster
EXT_KUBECONFIG="${2}"
START="${3:-1}"

for (( cluster = START; cluster <= START+NUM-1; ++cluster )); do
  delete_cluster "${EXT_KUBECONFIG}" "test-${cluster}" &
  if (( cluster % STEP == 0 )); then
    echo "Waiting for ${STEP} clusters to be deleted in the background."
    wait
  fi
done

wait
echo "Deleted ${NUM} clusters"
