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
mkdir -p "${IRONIC_DATA_DIR}"
IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
docker run -d --net host --privileged --name ipa-downloader \
  --env-file bmo-config/ironic.env \
  -v "${IRONIC_DATA_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" --rm \
  /usr/local/bin/get-resource.sh

# Install cert-manager while we wait for ipa-downloader
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=500s

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t ed25519
fi

namespace="baremetal-operator-system"

docker wait ipa-downloader
minikube ssh "sudo mkdir -p /shared/html/images"
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.kernel /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.initramfs /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.headers /shared/html/images/

# Install ironic
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" \
  --namespace "${namespace}" \
  --set ironicReplicas="{${IRONIC_ENDPOINTS// /\,}}" \
  --set secrets.ironicAuthConfig="$(cat ironic/ironic-auth-config)" \
  --set secrets.ironicHtpasswd="$(cat ironic/ironic-htpasswd)" \
  --set secrets.ironicInspectorAuthConfig="$(cat ironic/ironic-inspector-auth-config)" \
  --set secrets.ironicInspectorHtpasswd="$(cat ironic/ironic-inspector-htpasswd)" \
  --wait --timeout 20m --create-namespace
