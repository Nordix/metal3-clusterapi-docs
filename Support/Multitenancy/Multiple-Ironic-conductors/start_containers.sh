#!/bin/bash
N_SUSHY=${N_SUSHY:-1}
__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
ADVERTISE_HOST="192.168.111.1"

API_URL="https://172.22.0.2:6385"
CALLBACK_URL="https://172.22.0.2:5050/v1/continue"

rm -rf "$SUSHY_CONF_DIR"
mkdir -p "$SUSHY_CONF_DIR"

mkdir -p "$SUSHY_CONF_DIR/ssh"

sudo mkdir -p /root/.ssh
sudo ssh-keygen -f /root/.ssh/id_rsa_virt_power -P "" -q -y
sudo cat /root/.ssh/id_rsa_virt_power.pub | sudo tee /root/.ssh/authorized_keys

echo "Starting sushy-tools containers"
# Start sushy-tools
for i in $(seq 1 "$N_SUSHY"); do
  container_conf_dir="$SUSHY_CONF_DIR/sushy-$i"
  fake_ipa_port=$(( 9901 + (( $i % ${N_FAKE_IPA} )) ))
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
FAKE_IPA_API_URL = "${API_URL}"
FAKE_IPA_URL = "http://${ADVERTISE_HOST}:${fake_ipa_port}"
FAKE_IPA_INSPECTION_CALLBACK_URL = "${CALLBACK_URL}"
FAKE_IPA_ADVERTISE_ADDRESS = Host(hostname="${ADVERTISE_HOST}", port="${fake_ipa_port}")
SUSHY_FAKE_IPA_LISTEN_IP = "${ADVERTISE_HOST}"
SUSHY_FAKE_IPA_LISTEN_PORT = "${fake_ipa_port}"
SUSHY_EMULATOR_FAKE_IPA = True
SUSHY_EMULATOR_FAKE_SYSTEMS = $(cat nodes.json)
EOF

sudo podman run -d --net host --name "sushy-tools-${i}" --pod infra-pod \
    -v "${container_conf_dir}":/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"
done

# Start fake-ipas
for i in $(seq 1 ${N_FAKE_IPA:-1}); do
sudo podman run --entrypoint='["sushy-fake-ipa", "--config", "/root/sushy/conf.py"]' \
    -d --net host --name fake-ipa-${i} --pod infra-pod \
    -v "$SUSHY_CONF_DIR/sushy-${i}":/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"

  done

# Download ipa image
cat << EOF >"ironic.env"
HTTP_PORT=6180
PROVISIONING_INTERFACE=ironicendpoint
DHCP_RANGE=172.22.0.10,172.22.0.100
DEPLOY_KERNEL_URL=http://172.22.0.2:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://172.22.0.2:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://172.22.0.2:6385/v1/
IRONIC_INSPECTOR_ENDPOINT=https://172.22.0.2:5050/v1/
CACHEURL=http://172.22.0.1/images
IRONIC_FAST_TRACK=true
EOF

IRONIC_DATA_DIR="/opt/metal3-dev-env/ironic/"
IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
mkdir -p "${IRONIC_DATA_DIR}"

sudo podman run -d --net host --privileged --name ipa-downloader \
  --env-file ironic.env \
  -v "${IRONIC_DATA_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

export IRONIC_DATA_DIR
