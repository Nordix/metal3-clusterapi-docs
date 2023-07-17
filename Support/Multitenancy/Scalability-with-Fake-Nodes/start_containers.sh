#!/bin/bash

# shellcheck disable=SC1091
. ./config.sh
__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
FAKEIPA_IMAGE="quay.io/metal3-io/fake-ipa:latest"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
ADVERTISE_HOST="192.168.222.1"

API_URL="https://192.168.222.100:6385"
CALLBACK_URL="https://192.168.222.100:6385/v1/continue_inspection"

rm -rf "${SUSHY_CONF_DIR}"
mkdir -p "${SUSHY_CONF_DIR}"

mkdir -p "${SUSHY_CONF_DIR}/ssh"

ports=(8000 80 6385 5050 6180 53 5000 69 547 546 68 67 5353 6230)
echo "Starting sushy-tools containers"
# Start sushy-tools
for i in $(seq 1 "${N_FAKE_IPAS}"); do
  container_conf_dir="${SUSHY_CONF_DIR}/sushy-${i}"
  fake_ipa_port=$((9900 + i))
  sushy_port=$((8000 + i))
  ports+=("${port}")
  ports+=("${fake_ipa_port}")
  mkdir -p "${container_conf_dir}"
  cat <<'EOF' >"${container_conf_dir}"/htpasswd
admin:$2b$12$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
EOF

  # Set configuration options
  cat <<EOF >"${container_conf_dir}"/conf.py
import collections

SUSHY_EMULATOR_LIBVIRT_URI = "${LIBVIRT_URI}"
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False
SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
SUSHY_EMULATOR_AUTH_FILE = "/root/sushy/htpasswd"
SUSHY_EMULATOR_FAKE_DRIVER = True
SUSHY_EMULATOR_LISTEN_PORT = "${sushy_port}"
EXTERNAL_NOTIFICATION_URL = "http://${ADVERTISE_HOST}:${fake_ipa_port}"
FAKE_IPA_API_URL = "${API_URL}"
FAKE_IPA_URL = "http://${ADVERTISE_HOST}:${fake_ipa_port}"
FAKE_IPA_INSPECTION_CALLBACK_URL = "${CALLBACK_URL}"
FAKE_IPA_ADVERTISE_ADDRESS_IP = "${ADVERTISE_HOST}"
FAKE_IPA_ADVERTISE_ADDRESS_PORT = "${fake_ipa_port}"
FAKE_IPA_CAFILE = "/root/cert/ironic-ca.crt"
SUSHY_FAKE_IPA_LISTEN_IP = "${ADVERTISE_HOST}"
SUSHY_FAKE_IPA_LISTEN_PORT = "${fake_ipa_port}"
SUSHY_EMULATOR_FAKE_IPA = True
SUSHY_EMULATOR_FAKE_SYSTEMS = $(cat nodes.json)
EOF

  docker run -d --net host --name "sushy-tools-${i}" \
    -v "${container_conf_dir}":/root/sushy \
    "${SUSHY_TOOLS_IMAGE}"

  # Start fake-ipas
  docker run \
    -d --net host --name "fake-ipa-${i}" \
    -v "${SUSHY_CONF_DIR}/sushy-${i}":/app \
    -v "$(realpath cert)":/root/cert \
    "${FAKEIPA_IMAGE}"
done

# Firewall rules
# NOTE: Uncomment these lines if you use firewall
# for i in "${ports[@]}"; do
#   sudo firewall-cmd --zone=libvirt --add-port=${i}/tcp
#   sudo firewall-cmd --zone=libvirt --add-port=${i}/udp
# done
