# Set variables
N_NODES=${1:-1000}
REGISTRY_NAME="registry"
REGISTRY_PORT="5000"
IMAGE_NAMES=(
    "quay.io/metal3-io/ironic-python-agent"
# For now, sushy-tools needs to be compiled locally with https://review.opendev.org/c/openstack/sushy-tools/+/875366
    # "quay.io/metal3-io/sushy-tools"
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:latest"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived:v0.2.0"
    "quay.io/metal3-io/mariadb:latest"
)


# Attach provisioning and baremetal network interfaces to minikube domain
virsh attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh attach-interface --domain minikube --model virtio --source baremetal --type network --config

# Start podman registry if it's not already running
if ! podman ps | grep -q "$REGISTRY_NAME"; then
    podman run -d -p "$REGISTRY_PORT":"$REGISTRY_PORT" --name "$REGISTRY_NAME" docker.io/library/registry:2.7.1
fi

podman pod create -n infra-pod || true
podman pod create -n ironic-pod || true
# Pull images, tag to local registry, and push to registry
for NAME in "${IMAGE_NAMES[@]}"; do
    # Pull and tag the image
    podman pull "$NAME"
    podman tag "$NAME" 127.0.0.1:"$REGISTRY_PORT"/localimages/"${NAME##*/}"
    # Push the image to the local registry
    podman push --tls-verify=false 127.0.0.1:5000/localimages/"${NAME##*/}"
done

podman push --tls-verify=false 127.0.0.1:5000/localimages/sushy-tools

# Define variables for repeated values
IRONIC_IMAGE="127.0.0.1:5000/localimages/ironic:latest"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
API_URL="http://172.22.0.2:6385"
CALLBACK_URL="http://172.22.0.2:5050/v1/continue"
ADVERTISE_HOST="192.168.111.1"
ADVERTISE_PORT="9999"

# if [[ "${IRONIC_TLS_SETUP}" == "true" ]]; then
API_URL="https://172.22.0.2:6385"
CALLBACK_URL="https://172.22.0.2:5050/v1/continue"
__dir__=$(realpath $(dirname $0))
"$__dir__/ironic_tls_setup.sh"
# fi
    

# Create directories
DIRECTORIES=(
    "/opt/metal3-dev-env/ironic/virtualbmc"
    "/opt/metal3-dev-env/ironic/virtualbmc/sushy-tools"
)
for DIR in "${DIRECTORIES[@]}"; do
    mkdir -p "$DIR"
    chmod -R 755 "$DIR"
done

rm -f nodes.json
echo '[]' > nodes.json

# Run httpd container
podman run -d --net host --name httpd-infra \
    --pod infra-pod \
    -v /opt/metal3-dev-env/ironic:/shared \
    -e PROVISIONING_INTERFACE=provisioning \
    -e LISTEN_ALL_INTERFACES=false \
    --entrypoint /bin/runhttpd \
    "$IRONIC_IMAGE"

rm -rf macaddrs uuids

function macgen {
    hexdump -n 6 -ve '1/1 "%.2x "' /dev/random | awk -v a="2,6,a,e" -v r="$RANDOM" 'BEGIN{srand(r);}NR==1{split(a,b,",");r=int(rand()*4+1);printf "%s%s:%s:%s:%s:%s:%s\n",substr($1,0,1),b[r],$2,$3,$4,$5,$6}'
}

function generate_unique {
    func=$1
    store_file=$2
    newgen=$($func)
    if [[ ! -f "$store_file" || $(grep "$newgen" "$store_file") == "" ]]; then
	echo "$newgen" >> "$store_file"
	echo "$newgen"
	return
    fi
    $func
}

for i in $(seq 1 "$N_NODES"); do
  uuid=$(generate_unique uuidgen uuids)
  macaddr=$(generate_unique macgen macgen)
  name="fake${i}" 
  jq --arg node_name "${name}" \
    --arg uuid "${uuid}" \
    --arg macaddr "${macaddr}" \
    '{
      "uuid": $uuid,
      "name": $node_name,
      "power_state": "Off",
      "nics": [
	{"mac": $macaddr, "ip": "172.0.0.100"}
      ]
    }' nodes_template.json > node.json

  jq -s '.[0] + [.[1] ]' nodes.json node.json > tmp.json
  rm -f nodes.json
  mv tmp.json nodes.json
done

# Set configuration options
cat <<EOF >/opt/metal3-dev-env/ironic/virtualbmc/sushy-tools/conf.py
import collections

Host = collections.namedtuple('Host', ['hostname', 'port'])

SUSHY_EMULATOR_LIBVIRT_URI = "${LIBVIRT_URI}"
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False
SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
SUSHY_EMULATOR_AUTH_FILE = "/root/sushy/htpasswd"
SUSHY_EMULATOR_FAKE_DRIVER = True
FAKE_IPA_API_URL = "${API_URL}"
FAKE_IPA_INSPECTION_CALLBACK_URL = "${CALLBACK_URL}"
FAKE_IPA_ADVERTISE_ADDRESS = Host(hostname="${ADVERTISE_HOST}", port="${ADVERTISE_PORT}")
SUSHY_EMULATOR_FAKE_SYSTEMS = $(cat nodes.json)
EOF

# Create an htpasswd file
cat <<'EOF' > /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools/htpasswd
admin:$2b$12$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
EOF

# Generate ssh keys to use for virtual power and add them to authorized_keys
sudo ssh-keygen -f /root/.ssh/id_rsa_virt_power -P "" -q -y
sudo cat /root/.ssh/id_rsa_virt_power.pub | sudo tee -a /root/.ssh/authorized_keys

podman run -d --net host --name sushy-tools --pod infra-pod \
    -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"

podman run --entrypoint='["sushy-fake-ipa", "--config", "/root/sushy/conf.py"]' \
    -d --net host --name fake-ipa --pod infra-pod \
    -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"
