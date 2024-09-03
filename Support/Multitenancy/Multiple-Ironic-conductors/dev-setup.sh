#!/usr/bin/env bash

set -eux

REPO_ROOT=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
cd "${REPO_ROOT}" || exit 1

# Set up minikube
minikube config set memory 20000
minikube config set cpus 14
minikube start --driver=kvm2

virsh -c qemu:///system net-define "${REPO_ROOT}/nets/baremetal.xml"
virsh -c qemu:///system net-start baremetal
# Attach baremetal-e2e interface to minikube with specific mac.
# This will give minikube a known reserved IP address that we can use for Ironic
virsh -c qemu:///system attach-interface --domain minikube --mac="52:54:00:6c:3c:01" \
  --model virtio --source baremetal --type network --config

# Restart minikube to apply the changes
minikube stop
minikube start

kubectl create namespace baremetal-operator-system

export IRONIC_USERNAME="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
export IRONIC_PASSWORD="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"

BMO_OVERLAY=${REPO_ROOT}/bmo-config
IRONIC_OVERLAY=${REPO_ROOT}/ironic

echo "${IRONIC_USERNAME}" > "${BMO_OVERLAY}/ironic-username"
echo "${IRONIC_PASSWORD}" > "${BMO_OVERLAY}/ironic-password"

curl -O https://raw.githubusercontent.com/metal3-io/baremetal-operator/main/ironic-deployment/components/basic-auth/ironic-auth-config-tpl

envsubst < "${REPO_ROOT}/ironic-auth-config-tpl" > \
  "${IRONIC_OVERLAY}/ironic-auth-config"

echo "$(htpasswd -n -b -B "${IRONIC_USERNAME}" "${IRONIC_PASSWORD}")" > \
  "${IRONIC_OVERLAY}/ironic-htpasswd"

if [[ $(which firewall-cmd) == "" ]]; then
  exit 0
fi

ports=(8000 80 6385 5050 6180 53 5000 69 547 546 68 67 5353 6230)
for i in $(seq 1 "${N_SUSHY:-1}"); do
  port=$(( 8000 + i ))
  ports+=(${port})
done

for i in $(seq 1 "${N_FAKE_IPA:-1}"); do
  port=$(( 9900 + i ))
  ports+=(${port})
done

# Firewall rules
for i in "${ports[@]}"; do 
  sudo firewall-cmd --zone=public --add-port=${i}/tcp
  sudo firewall-cmd --zone=public --add-port=${i}/udp
  sudo firewall-cmd --zone=libvirt --add-port=${i}/tcp
  sudo firewall-cmd --zone=libvirt --add-port=${i}/udp
done
