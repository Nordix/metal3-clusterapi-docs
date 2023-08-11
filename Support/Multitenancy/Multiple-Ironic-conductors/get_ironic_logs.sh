#!/bin/bash
#
log_dir="ironic_logs"
rm -rf ${log_dir}
mkdir -p ${log_dir}
ns="baremetal-operator-system"
pod_names=($(kubectl -n "${ns}" get pods -o json | jq -r ".items[].metadata.name"))
for name in ${pod_names[@]}; do
    containers=($(kubectl -n "${ns}" get pod ${name} -o json | jq -r ".spec.containers[].name"))
    for c in ${containers[@]}; do
        kubectl -n "${ns}" logs ${name} -c ${c} > "${log_dir}/${name}-${c}-log.txt"
    done
done
