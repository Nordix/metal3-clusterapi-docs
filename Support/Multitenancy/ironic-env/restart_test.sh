#!/bin/bash
#
set -e
__dir__=$(realpath $(dirname $0))
source "$__dir__/config.sh"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"

sudo podman stop sushy-tools
sudo podman rm sushy-tools

sudo podman run -d --net host --name sushy-tools --pod infra-pod \
    -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"

sudo podman stop fake-ipa
sudo podman rm fake-ipa

sudo podman run --entrypoint='["sushy-fake-ipa", "--config", "/root/sushy/conf.py"]' \
    -d --net host --name fake-ipa --pod infra-pod \
    -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"

helm uninstall ironic --wait 2>/dev/null | true

read -ra PROVISIONING_IPS <<< "${IRONIC_ENDPOINTS}"
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" --set ironicReplicas={$(echo $IRONIC_ENDPOINTS | sed 's/ /\,/g')} --wait

python create_nodes.py
cp nodes.json batch.json
./07-inspect-nodes.sh "${NODE_INSPECT_BATCH_SIZE}"
