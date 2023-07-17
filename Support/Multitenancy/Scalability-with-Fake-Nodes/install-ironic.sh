#!/bin/bash
set -eux

# shellcheck disable=SC1091
. ./config.sh

__dir__=$(realpath "$(dirname "$0")")

IRONIC_USERNAME="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 12 | head -n 1)"
IRONIC_PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 12 | head -n 1)"

BMO_OVERLAY=${__dir__}/bmo-config
IRONIC_OVERLAY=${__dir__}/ironic

echo "${IRONIC_USERNAME}" >"${BMO_OVERLAY}/ironic-username"
echo "${IRONIC_PASSWORD}" >"${BMO_OVERLAY}/ironic-password"

curl -O https://raw.githubusercontent.com/metal3-io/baremetal-operator/main/ironic-deployment/components/basic-auth/ironic-auth-config-tpl

envsubst <"${__dir__}/ironic-auth-config-tpl" > \
  "${IRONIC_OVERLAY}/ironic-auth-config"

htpasswd -n -b -B "${IRONIC_USERNAME}" "${IRONIC_PASSWORD}" > \
  "${IRONIC_OVERLAY}/ironic-htpasswd"

# Create namespace
namespace="baremetal-operator-system"
kubectl create ns $namespace

# Install cert-manager and wait for it
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=500s

if [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
  ssh-keygen -t ed25519
fi

# Setup the ironic endpoints in minikube VM
minikube ssh "sudo brctl addbr ironicendpoint" 2>/dev/nul || true
minikube ssh "sudo ip link set ironicendpoint up" 2>/dev/nul || true
minikube ssh "sudo brctl addif ironicendpoint eth1" 2>/dev/nul || true

read -ra PROVISIONING_IPS <<<"${IRONIC_ENDPOINTS}"
for PROVISIONING_IP in "${PROVISIONING_IPS[@]}"; do
  minikube ssh sudo ip addr add "${PROVISIONING_IP}"/24 dev ironicendpoint
done

# Install ironic
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" \
  --namespace "${namespace}" \
  --set ironicReplicas="{${IRONIC_ENDPOINTS// /\,}}" \
  --set secrets.ironicAuthConfig="$(cat ironic/ironic-auth-config)" \
  --set secrets.ironicHtpasswd="$(cat ironic/ironic-htpasswd)" \
  --wait --timeout 20m --create-namespace

mkdir -p cert

# Get the ironic-cert, which fake IPA will need
kubectl get secret -n baremetal-operator-system ironic-cert -o json -o=jsonpath="{.data.ca\.crt}" | base64 -d >cert/ironic-ca.crt
