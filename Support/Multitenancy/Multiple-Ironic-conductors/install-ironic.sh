#!/bin/bash
set -eux

. ./config.sh

# In 1-conductor setup, ipa-downloader is setup as an initContainer for the ironic container, and it
# will make sure ipa is downloaded to an emptyDir before ironic starts. In multiple-conductor setup,
# we want to avoid that, as several ipa-downloader downloading the same ipa at the same time might
# make the server think it was a DDOS.
# In this script we make a hack by download ipa before installing ironic, then copy it to directory
# /shared in the minikube VM. In production, another method is required, probably by having a 
# leader-election mechanism to let an ipa-downloader run only if it's the first one in the node.
__dir__=$(realpath "$(dirname "$0")")
IRONIC_DATA_DIR="${__dir__}/Metal3/ironic"
IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
mkdir -p "${IRONIC_DATA_DIR}"

docker run -d --net host --privileged --name ipa-downloader \
  --env-file ironic.env \
  -v "${IRONIC_DATA_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

# Install cert-manager while we wait for ipa-downloader
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=500s

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t ed25519
fi

docker wait ipa-downloader

namespace="baremetal-operator-system"

minikube ssh "sudo brctl addbr ironicendpoint"
minikube ssh "sudo ip link set ironicendpoint up"
minikube ssh "sudo brctl addif ironicendpoint eth1"
# virsh -c qemu:///system attach-interface --domain minikube --model virtio --source provisioning --type network --config
# virsh -c qemu:///system attach-interface --domain minikube --model virtio --source baremetal --type network --config

export IRONIC_DATA_DIR

minikube ssh "sudo mkdir -p /shared/html/images"
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.kernel /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.initramfs /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.headers /shared/html/images/

read -ra PROVISIONING_IPS <<< "${IRONIC_ENDPOINTS}"
for PROVISIONING_IP in "${PROVISIONING_IPS[@]}"; do
  minikube ssh sudo  ip addr add ${PROVISIONING_IP}/24 dev ironicendpoint
done

# Install ironic
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" \
  --namespace "${namespace}" \
  --set ironicReplicas="{${IRONIC_ENDPOINTS// /\,}}" \
  --set secrets.ironicAuthConfig="$(cat ironic/ironic-auth-config)" \
  --set secrets.ironicHtpasswd="$(cat ironic/ironic-htpasswd)" \
  --wait --timeout 20m --create-namespace
