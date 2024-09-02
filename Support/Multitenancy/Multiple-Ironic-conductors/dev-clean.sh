#!/usr/bin/env bash

CURRENT_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "${CURRENT_DIR}" || exit 1

NUM_BMH=${NUM_BMH:-"5"}

minikube delete
docker rm -f vbmc
docker rm -f image-server-e2e
docker rm -f sushy-tools

for ((i=0; i<NUM_BMH; i++))
do
  virsh -c qemu:///system destroy --domain "bmo-e2e-${i}"
  virsh -c qemu:///system undefine --domain "bmo-e2e-${i}" --remove-all-storage
done

virsh -c qemu:///system net-destroy baremetal-e2e
virsh -c qemu:///system net-undefine baremetal-e2e

rm -rfv "${REPO_ROOT}/Metal3/
