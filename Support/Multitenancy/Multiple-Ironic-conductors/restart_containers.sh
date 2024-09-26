#!/bin/bash
. ./config.sh

__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
# SUSHY_TOOLS_IMAGE="quay.io/metal3-io/sushy-tools:latest"
FAKEIPA_IMAGE="127.0.0.1:5000/localimages/fake-ipa"
# FAKEIPA_IMAGE="quay.io/metal3-io/fake-ipa:latest"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
ADVERTISE_HOST="192.168.222.1"

API_URL="https://192.168.222.100:6385"
CALLBACK_URL="https://192.168.222.100:6385/v1/continue_inspection"

namespace="metal3"
for f in bmc-*.yaml; do
  kubectl -n "${namespace}" delete -f $f
done

sleep 10

echo "Starting sushy-tools containers"
# Start sushy-tools
for i in $(seq 1 "$N_FAKE_IPAS"); do
  docker rm -f "sushy-tools-${i}"
  container_conf_dir="$SUSHY_CONF_DIR/sushy-$i"
  docker run -d --net host --name "sushy-tools-${i}" \
    -v "${container_conf_dir}":/root/sushy \
    "${SUSHY_TOOLS_IMAGE}"
  # Start fake-ipas
  port=$((9900 + i))
  ports+=(${port})
  docker rm -f "fake-ipa-${i}"
  docker run \
    -d --net host --name fake-ipa-${i} \
    -v "$SUSHY_CONF_DIR/sushy-${i}":/app \
    -v "$(realpath cert)":/root/cert \
    "${FAKEIPA_IMAGE}"
done

sleep 10

for f in bmc-*.yaml; do
  kubectl -n "${namespace}" apply -f $f
done
