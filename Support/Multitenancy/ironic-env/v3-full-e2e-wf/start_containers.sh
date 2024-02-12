#!/bin/bash
N_SUSHY=${N_SUSHY:-5}
__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
ADVERTISE_HOST="192.168.111.1"
ADVERTISE_PORT="9999"

API_URL="https://172.22.0.2:6385"
CALLBACK_URL="https://172.22.0.2:5050/v1/continue"

rm -rf "$SUSHY_CONF_DIR"
mkdir -p "$SUSHY_CONF_DIR"

mkdir -p "$SUSHY_CONF_DIR/ssh"

sudo ssh-keygen -f /root/.ssh/id_rsa_virt_power -P "" -q -y
sudo cat /root/.ssh/id_rsa_virt_power.pub | sudo tee /root/.ssh/authorized_keys

echo "Starting sushy-tools containers"
# Start sushy-tools
for i in $(seq 1 "$N_SUSHY"); do
  container_conf_dir="$SUSHY_CONF_DIR/sushy-$i"
  mkdir -p "${container_conf_dir}"
  cat <<'EOF' > "${container_conf_dir}"/htpasswd
admin:$2b$12$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
EOF
  # Set configuration options
  cat <<EOF >"${container_conf_dir}"/conf.py
import collections

Host = collections.namedtuple('Host', ['hostname', 'port'])

SUSHY_EMULATOR_LIBVIRT_URI = "${LIBVIRT_URI}"
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False
SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
SUSHY_EMULATOR_AUTH_FILE = "/root/sushy/htpasswd"
SUSHY_EMULATOR_FAKE_DRIVER = True
SUSHY_EMULATOR_LISTEN_PORT = $(( 8000 + i ))
FAKE_IPA_URL = "http://${ADVERTISE_HOST}:${ADVERTISE_PORT}"
FAKE_IPA_API_URL = "${API_URL}"
FAKE_IPA_INSPECTION_CALLBACK_URL = "${CALLBACK_URL}"
FAKE_IPA_ADVERTISE_ADDRESS = Host(hostname="${ADVERTISE_HOST}", port="${ADVERTISE_PORT}")
SUSHY_EMULATOR_FAKE_SYSTEMS = $(cat nodes.json)
EOF

sudo podman run -d --net host --name "sushy-tools-${i}" --pod infra-pod \
    -v "$container_conf_dir:/root/sushy" \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"
done

# Start fake-ipa
sudo podman run --entrypoint='["sushy-fake-ipa", "--config", "/root/sushy/conf.py"]' \
    -d --net host --name fake-ipa --pod infra-pod \
    -v "$SUSHY_CONF_DIR/sushy-1":/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"
