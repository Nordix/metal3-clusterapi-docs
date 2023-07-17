#!/usr/bin/env bash

set -eux
# shellcheck disable=SC1091
. ./config.sh

REPO_ROOT=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
cd "${REPO_ROOT}" || exit 1

# Set up minikube
minikube config set memory "${MINIKUBE_MEMORY}"
minikube config set cpus "${MINIKUBE_CPUS}"
minikube start --driver=kvm2 --wait-timeout 120s

virsh -c qemu:///system net-define "${REPO_ROOT}/manifests/net.xml"
virsh -c qemu:///system net-start baremetal
minikube config set insecure-registry "0.0.0.0/0"
# Attach baremetal-e2e interface to minikube with specific mac.
# This will give minikube a known reserved IP address that we can use for Ironic
virsh -c qemu:///system attach-interface --domain minikube --mac="52:54:00:6c:3c:01" \
  --model virtio --source baremetal --type network --config

# Restart minikube to apply the changes
minikube stop
minikube start --wait-timeout 120s
