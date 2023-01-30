#!/usr/bin/env bash

set -eu

delete_cluster() {
  cluster="${1:-test-1}"
  namespace="${2:-${cluster}}"

  machine_name="$(kubectl -n "${namespace}" get machine -o jsonpath="{.items[0].metadata.name}")"
  kubectl -n "${namespace}" delete cluster "${cluster}"
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml delete node "${machine_name}"
  kubectl delete namespace "${namespace}"
}

NUM="${1:-10}"
# Delete clusters in steps of step.
STEP="10"
for (( cluster = 1; cluster <= NUM; ++cluster )); do
  delete_cluster "test-${cluster}" &
  if (( cluster % STEP == 0 )); then
    echo "Waiting for ${cluster} clusters to be deleted in the background."
    wait
  fi
done

wait
echo "Deleted ${NUM} clusters"
