#!/bin/bash
#
container_name=${1:-ironic}
NS="baremetal-operator-system"
podName=$(kubectl -n "$NS" get pod -o json | jq -r '.items | .[].metadata.name' | grep "ironic" )

rm -f "${container_name}.log"
kubectl -n "$NS" logs "$podName" -c "${container_name}" > "${container_name}.log"
