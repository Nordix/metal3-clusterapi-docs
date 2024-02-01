#!/usr/bin/env bash

set -eux

REPO_ROOT=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
cd "${REPO_ROOT}" || exit 1

# Set up minikube
minikube start --driver=kvm2

virsh -c qemu:///system net-define "${REPO_ROOT}/Metal3/net.xml"
virsh -c qemu:///system net-start baremetal-e2e
# Attach baremetal-e2e interface to minikube with specific mac.
# This will give minikube a known reserved IP address that we can use for Ironic
virsh -c qemu:///system attach-interface --domain minikube --mac="52:54:00:6c:3c:01" \
  --model virtio --source baremetal-e2e --type network --config

# Restart minikube to apply the changes
minikube stop
minikube start

# Image server variables
IMAGE_DIR="${REPO_ROOT}/Metal3/images"

## Run the image server
mkdir -p "${IMAGE_DIR}"
docker run --name image-server-e2e -d \
  -p 80:8080 \
  -v "${IMAGE_DIR}:/usr/share/nginx/html" nginxinc/nginx-unprivileged

kubectl create namespace baremetal-operator-system

export IRONIC_USERNAME="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
export IRONIC_PASSWORD="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
export IRONIC_INSPECTOR_USERNAME="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
export IRONIC_INSPECTOR_PASSWORD="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"

BMO_OVERLAY=${REPO_ROOT}/Metal3/bmo
IRONIC_OVERLAY=${REPO_ROOT}/Metal3/ironic

echo "${IRONIC_USERNAME}" > "${BMO_OVERLAY}/ironic-username"
echo "${IRONIC_PASSWORD}" > "${BMO_OVERLAY}/ironic-password"
echo "${IRONIC_INSPECTOR_USERNAME}" > "${BMO_OVERLAY}/ironic-inspector-username"
echo "${IRONIC_INSPECTOR_PASSWORD}" > "${BMO_OVERLAY}/ironic-inspector-password"

curl -O https://raw.githubusercontent.com/metal3-io/baremetal-operator/main/ironic-deployment/components/basic-auth/ironic-auth-config-tpl
curl -O https://raw.githubusercontent.com/metal3-io/baremetal-operator/main/ironic-deployment/components/basic-auth/ironic-inspector-auth-config-tpl

envsubst < "${REPO_ROOT}/ironic-auth-config-tpl" > \
  "${IRONIC_OVERLAY}/ironic-auth-config"
envsubst < "${REPO_ROOT}/ironic-inspector-auth-config-tpl" > \
  "${IRONIC_OVERLAY}/ironic-inspector-auth-config"

echo "IRONIC_HTPASSWD=$(htpasswd -n -b -B "${IRONIC_USERNAME}" "${IRONIC_PASSWORD}")" > \
  "${IRONIC_OVERLAY}/ironic-htpasswd"
echo "INSPECTOR_HTPASSWD=$(htpasswd -n -b -B "${IRONIC_INSPECTOR_USERNAME}" \
  "${IRONIC_INSPECTOR_PASSWORD}")" > "${IRONIC_OVERLAY}/ironic-inspector-htpasswd"

clusterctl init --infrastructure=metal3
kubectl apply -k "${REPO_ROOT}/Metal3/ironic"
kubectl apply -k "${REPO_ROOT}/Metal3/bmo"
