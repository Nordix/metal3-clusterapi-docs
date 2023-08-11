#!/bin/bash
set -e

# sudo install minikube
if [[ $(ls /usr/local/bin/minikube) == "" ]]; then
  curl -LO https://storage.googleapis.com/minikube/releases/v1.31.0/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
fi
# sudo install kubectl
if [[ $(ls /usr/local/bin/kubectl) == "" ]]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# sudo install Helm
if [[ $(ls /usr/local/bin/helm) == "" ]]; then
  helm_api="https://api.github.com/repos/helm/helm/releases"
  helm_release_tag="$(curl -sL "${helm_api}" | jq -r ".[].tag_name" | head -n 1 )"
  helm_filename="helm-${helm_release_tag}-linux-amd64.tar.gz"
  wget -O "$helm_filename" "https://get.helm.sh/${helm_filename}"
  tar -xf "$helm_filename"
  sudo install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm
fi

# sudo install kustomize
if [[ $(ls /usr/local/bin/kustomize) == "" ]]; then
  kustomize_api="https://api.github.com/repos/kubernetes-sigs/kustomize/releases"
  kustomize_release_tag="$(curl -sL "${kustomize_api}" | jq -r ".[].tag_name" | grep "kustomize" | head -n 1 )"
  kustomize_filename="$(echo ${kustomize_release_tag} | sed -e 's/\//_/')_linux_amd64.tar.gz"
  wget -O "${kustomize_filename}" "https://github.com/kubernetes-sigs/kustomize/releases/download/${kustomize_release_tag}/${kustomize_filename}"
  tar -xf "${kustomize_filename}"
  sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
fi

if [[ $(ls /usr/local/bin/clusterctl) == "" ]]; then
  clusterctl_api="https://api.github.com/repos/kubernetes-sigs/cluster-api/releases"
  clusterctl_release_tag="$(curl -sL "${clusterctl_api}" | jq -r ".[].tag_name" | head -n 1 )"
  clusterctl_filename="clusterctl"
  wget -O "${clusterctl_filename}" "https://github.com/kubernetes-sigs/cluster-api/releases/download/${clusterctl_release_tag}/clusterctl-linux-amd64"
  sudo install -o root -g root -m 0755 "${clusterctl_filename}" /usr/local/bin/"${clusterctl_filename}"
fi

if [[ $(ls /usr/local/bin/yq) == "" ]]; then
  api="https://api.github.com/repos/mikefarah/yq/releases"
  release_tag="$(curl -sL "${api}" | jq -r ".[].tag_name" | head -n 1 )"
  filename="yq"
  wget -O "${filename}" "https://github.com/mikefarah/yq/releases/download/${release_tag}/yq_linux_amd64"
  sudo install -o root -g root -m 0755 "${filename}" /usr/local/bin/"${filename}"
fi

# Cleanup
rm -rf "${helm_filename}" "${kustomize_filename}" "${clusterctl_filename}" linux-amd64 minikube-linux-amd64 kubectl kustomize yq
