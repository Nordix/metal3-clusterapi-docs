# Set variables
REGISTRY_NAME="registry"
REGISTRY_PORT="5000"
IMAGE_NAMES=(
    "quay.io/metal3-io/sushy-tools"
    "quay.io/metal3-io/ironic-ipa-downloader"
    "quay.io/metal3-io/ironic:latest"
    "quay.io/metal3-io/ironic-client"
    "quay.io/metal3-io/keepalived"
)
${quay.io/metal3-io/sushy-tools##*/}
# Attach provisioning and baremetal network interfaces to minikube domain
virsh attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh attach-interface --domain minikube --model virtio --source baremetal --type network --config

# Start podman registry if it's not already running
if ! podman ps | grep -q "$REGISTRY_NAME"; then
    podman run -d -p "$REGISTRY_PORT":"$REGISTRY_PORT" --name "$REGISTRY_NAME" docker.io/library/registry:2.7.1
fi

# Pull images, tag to local registry, and push to registry
for NAME in "${IMAGE_NAMES[@]}"; do
    # Pull and tag the image
    podman pull "$NAME"
    podman tag "$NAME" 127.0.0.1:"$REGISTRY_PORT"/localimages/"${NAME##*/}"
    # Push the image to the local registry
    podman push --tls-verify=false 127.0.0.1:5000/localimages/"${NAME##*/}"
done

# Define variables for repeated values
IRONIC_IMAGE="127.0.0.1:5000/localimages/ironic:latest"
SUSHY_TOOLS_IMAGE="127.0.0.1:5000/localimages/sushy-tools"
LIBVIRT_URI="qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
API_URL="http://172.22.0.2:6385"
CALLBACK_URL="http://172.22.0.2:5050/v1/continue"
ADVERTISE_HOST="192.168.111.1"
ADVERTISE_PORT="9999"

# Create directories
DIRECTORIES=(
    "/opt/metal3-dev-env/ironic/virtualbmc"
    "/opt/metal3-dev-env/ironic/virtualbmc/sushy-tools"
)
for DIR in "${DIRECTORIES[@]}"; do
    mkdir -p "$DIR"
    chmod -R 755 "$DIR"
done

# Run httpd container
podman run -d --net host --name httpd-infra \
    --pod infra-pod \
    -v /opt/metal3-dev-env/ironic:/shared \
    -e PROVISIONING_INTERFACE=provisioning \
    -e LISTEN_ALL_INTERFACES=false \
    --entrypoint /bin/runhttpd \
    "$IRONIC_IMAGE"
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
EOF

# Create an htpasswd file
cat <<EOF >/opt/metal3-dev-env/ironic/virtualbmc/sushy-tools/htpasswd
admin:$2b${12}$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
EOF

# Generate ssh keys to use for virtual power and add them to authorized_keys
sudo ssh-keygen -f /root/.ssh/id_rsa_virt_power -P "" -q -y
sudo cat /root/.ssh/id_rsa_virt_power.pub | sudo tee -a /root/.ssh/authorized_keys

# Create and start a container for sushy-tools
podman run -d --net host --name sushy-tools --pod infra-pod \
    -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy \
    -v /root/.ssh:/root/ssh \
    "${SUSHY_TOOLS_IMAGE}"
