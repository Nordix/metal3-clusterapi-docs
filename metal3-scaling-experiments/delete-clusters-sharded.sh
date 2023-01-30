#!/usr/bin/env bash

set -eu

delete_cluster() {
  cluster="${1:-test-1}"
  namespace="${2:-${cluster}}"

  machine_name="$(kubectl -n "${namespace}" get machine -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}")"
  kubectl -n "${namespace}" delete cluster "${cluster}"
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml delete node "${machine_name}"
}

# Number of clusters per shard
NUM="${1:-10}"
# Number of shards (namespaces and CAPKCP controller)
SHARDS="${2:-10}"
# Delete clusters in steps of step.
STEP="10"

for (( shard = 1; shard <= SHARDS; ++shard )); do
  namespace="test-${shard}"
  for (( cluster = 1; cluster <= NUM; ++cluster )); do
    delete_cluster "test-${cluster}" "${namespace}" &
    if (( cluster % STEP == 0 )); then
      echo "Waiting for ${cluster} clusters to be created in the background."
      wait
    fi
  done
  kubectl delete namespace "${namespace}"
done

wait
echo "Deleted ${NUM} clusters x ${SHARDS} shards"
