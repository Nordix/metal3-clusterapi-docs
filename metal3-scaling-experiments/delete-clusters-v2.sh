#!/usr/bin/env bash

set -eu

delete_cluster() {
  cluster="${1:-test-1}"
  namespace="${2:-${cluster}}"

  kubectl -n "${namespace}" delete cluster "${cluster}" || true

  # Delete etcd user
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    user delete "${cluster}"
  # Delete role
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    role delete "${cluster}"
  # Delete data
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    del "/${cluster}" --prefix

  kubectl delete namespace "${namespace}"
}

NUM="${1:-10}"
# Delete clusters in steps of step.
STEP="10"
for (( cluster = 1; cluster <= NUM; ++cluster )); do
  delete_cluster "test-${cluster}" &
  if (( cluster % STEP == 0 )); then
    echo "Waiting for ${STEP} clusters to be deleted in the background."
    wait
  fi
done

wait
echo "Deleted ${NUM} clusters"
