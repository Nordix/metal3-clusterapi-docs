#!/bin/bash
#
set -e
. ./config.sh
./build-sushy-tools-image.sh

containers=("fake-ipa")
for i in $(seq 1 "$N_SUSHY"); do
    containers+=("sushy-tools-$i")
done

for container in "${containers[@]}"; do
    echo "Deleting the container: $container"
    sudo podman stop "$container" &>/dev/null || true
    sudo podman rm "$container" &>/dev/null || true
done

# Start fake-ipa
__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
sudo podman run --entrypoint='["sushy-fake-ipa", "--config", "/root/sushy/conf.py"]' \
    -d --net host --name fake-ipa --pod infra-pod \
    -v "$SUSHY_CONF_DIR/sushy-1":/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"

for i in $(seq 1 "$N_SUSHY"); do
    container_conf_dir="$SUSHY_CONF_DIR/sushy-$i"
    sudo podman run -d --net host --name "sushy-tools-${i}" --pod infra-pod \
	-v "$container_conf_dir:/root/sushy" \
	-v /root/.ssh:/root/ssh \
	"${SUSHY_TOOLS_IMAGE}"
done

OFFSET=$(kubectl get bmh -A --no-headers | wc -l)
./create-clusters-v2.sh 1 ${OFFSET}
