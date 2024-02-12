#!/bin/bash
. ./config.sh
N_SUSHY=${N_SUSHY:-1}
__dir__=$(realpath "$(dirname "$0")")
SUSHY_CONF_DIR="${__dir__}/sushy-tools-conf"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
ADVERTISE_HOST="192.168.222.1"

API_URL="https://192.168.222.100:6385"
CALLBACK_URL="https://192.168.222.100:5050/v1/continue"

rm -rf "$SUSHY_CONF_DIR"
mkdir -p "$SUSHY_CONF_DIR"

mkdir -p "$SUSHY_CONF_DIR/ssh"

# sudo mkdir -p /root/.ssh
# sudo ssh-keygen -f /root/.ssh/id_rsa_virt_power -P "" -q -y
# sudo cat /root/.ssh/id_rsa_virt_power.pub | sudo tee /root/.ssh/authorized_keys

ports=(8000 80 6385 5050 6180 53 5000 69 547 546 68 67 5353 6230)
echo "Starting sushy-tools containers"
# Start sushy-tools
for i in $(seq 1 "$N_SUSHY"); do
  container_conf_dir="$SUSHY_CONF_DIR/sushy-$i"
  fake_ipa_port=$(( 9901 + (( $i % ${N_FAKE_IPA:-1} )) ))
  port=$(( 8000 + i ))
  ports+=(${port})
  mkdir -p "${container_conf_dir}"
  cat <<'EOF' > "${container_conf_dir}"/htpasswd
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
SUSHY_EMULATOR_LISTEN_PORT = $(( 8000 + i ))
FAKE_IPA_API_URL = "${API_URL}"
FAKE_IPA_URL = "http://${ADVERTISE_HOST}:${fake_ipa_port}"
FAKE_IPA_INSPECTION_CALLBACK_URL = "${CALLBACK_URL}"
FAKE_IPA_ADVERTISE_ADDRESS_IP = "${ADVERTISE_HOST}"
FAKE_IPA_ADVERTISE_ADDRESS_PORT = "${fake_ipa_port}"
SUSHY_FAKE_IPA_LISTEN_IP = "${ADVERTISE_HOST}"
SUSHY_FAKE_IPA_LISTEN_PORT = "${fake_ipa_port}"
SUSHY_EMULATOR_FAKE_IPA = True
SUSHY_EMULATOR_FAKE_SYSTEMS = $(cat nodes.json)
EOF

docker run -d --net host --name "sushy-tools-${i}" \
    -v "${container_conf_dir}":/root/sushy \
    "${SUSHY_TOOLS_IMAGE}"
done

# Start fake-ipas
for i in $(seq 1 ${N_FAKE_IPA:-1}); do
  port=$(( 9900 + i ))
  ports+=(${port})
docker run --entrypoint=sushy-fake-ipa \
    -d --net host --name fake-ipa-${i} \
    -v "$SUSHY_CONF_DIR/sushy-${i}":/root/sushy \
    "${SUSHY_TOOLS_IMAGE}" \
    --config /root/sushy/conf.py
done

# Firewall rules
# Please enable these lines if you use a firewall. The ports need to be opened
# for i in "${ports[@]}"; do 
#   sudo firewall-cmd --zone=public --add-port=${i}/tcp
#   sudo firewall-cmd --zone=public --add-port=${i}/udp
#   sudo firewall-cmd --zone=libvirt --add-port=${i}/tcp
#   sudo firewall-cmd --zone=libvirt --add-port=${i}/udp
# done
