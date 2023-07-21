#!/bin/bash
#
set -e
. ./config.sh

containers=("fake-ipa")
for i in $(seq 1 "$N_SUSHY"); do
    containers+=("sushy-tools-$i")
done
for container in "${containers[@]}"; do
    echo "Deleting the container: $container"
    sudo podman stop "$container" &>/dev/null
    sudo podman rm "$container" &>/dev/null
done

helm uninstall ironic --wait 2>/dev/null | true

./generate_unique_nodes.sh
./start_containers.sh

helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" --set ironicReplicas="{${IRONIC_ENDPOINTS/ /\,}}" --wait

python create_nodes.py
