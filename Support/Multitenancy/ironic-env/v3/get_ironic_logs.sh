#!/bin/bash
#
NS="baremetal-operator-system"
dir="logs"
mkdir -p "$dir"
rm -rf "${dir:?}/*"


get_container_log() {
  container_name=$1
  podRegex=$2
  podNames=($(kubectl -n "$NS" get pod -o json | jq -r '.items | .[].metadata.name' | grep "${podRegex}" ))

  for podName in "${podNames[@]}"; do
    echo "Getting logs $podName/$container_name"
    fileName=${dir}/${podName}-${container_name}-log.txt
    rm -f "${fileName}"
    kubectl -n "$NS" logs "$podName" -c "${container_name}" > "${fileName}"
  done
}
get_container_log "ironic" "ironic-[[:digit:]]"
get_container_log "ironic-inspector" "ironic-common"
