#!/bin/bash
#
sudo dnf -y install qemu-kvm libvirt virt-install net-tools podman firewalld

DEVTOOLS_PATH=${DEVTOOLS_PATH:-$HOME/metal3-dev-tools}
rm -rf $DEVTOOLS_PATH

git clone https://github.com/Nordix/metal3-dev-tools ${DEVTOOLS_PATH}

${DEVTOOLS_PATH}/ci/scripts/image_scripts/provision_node_image_centos.sh

# install minikube
curl -LO https://storage.googleapis.com/minikube/releases/v1.31.1/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
helm_api="https://api.github.com/repos/helm/helm/releases"
curl -sL "${helm_api}" > helm_releases.txt
helm_release_tag="$(cat helm_releases.txt | jq -r ".[].tag_name" | head -n 1 )"
rm -f helm_releases.txt
filename="helm-${helm_release_tag}-linux-amd64.tar.gz"
wget -O "$filename.tar.gz" "https://get.helm.sh/${filename}"
tar -xf "$filename.tar.gz"
sudo install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm
rm -rf "$filename.tar.gz" linux-amd64 minikube-linux-amd64 kubectl

# Install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.5.0/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
