#!/bin/bash
set -e

if [[ ! -f $(sudo which minikube) ]]; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
fi

if [[ ! -f $(sudo which kubectl) ]]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

if [[ ! -f $(sudo which helm) ]]; then
  helm_api="https://api.github.com/repos/helm/helm/releases"
  helm_release_tag="$(curl -sL "${helm_api}" | jq -r ".[].tag_name" | head -n 1 )"
  echo $helm_release_tag
  helm_filename="helm-${helm_release_tag}-linux-amd64.tar.gz"
  wget -O "$helm_filename" "https://get.helm.sh/${helm_filename}"
  tar -xf "$helm_filename"
  sudo install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm
  rm -rf "${helm_filename}" linux-amd64
fi

if [[ ! -f $(sudo which kustomize) ]]; then
  kustomize_api="https://api.github.com/repos/kubernetes-sigs/kustomize/releases"
  kustomize_release_tag="$(curl -sL "${kustomize_api}" | jq -r ".[].tag_name" | grep "kustomize" | head -n 1 )"
  filename="$(echo $kustomize_release_tag | sed 's/\//_/')_linux_amd64.tar.gz"
  wget -O "${filename}" "https://github.com/kubernetes-sigs/kustomize/releases/download/${kustomize_release_tag}/${filename}"
  tar -xf "${filename}"
  sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
  rm "${filename}" kustomize
fi

if [[ ! -f $(sudo which clusterctl) ]]; then
  clusterctl_api="https://api.github.com/repos/kubernetes-sigs/cluster-api/releases"
  clusterctl_release_tag="$(curl -sL "${clusterctl_api}" | jq -r ".[].tag_name" | head -n 1 )"
  filename="clusterctl"
  wget -O "${filename}" "https://github.com/kubernetes-sigs/cluster-api/releases/download/${clusterctl_release_tag}/clusterctl-linux-amd64"
  sudo install -o root -g root -m 0755 "${filename}" /usr/local/bin/"${filename}"
  rm "${filename}"
fi

if [[ ! -f $(sudo which yq) ]]; then
  api="https://api.github.com/repos/mikefarah/yq/releases"
  release_tag="$(curl -sL "${api}" | jq -r ".[].tag_name" | head -n 1 )"
  filename="yq"
  wget -O "${filename}" "https://github.com/mikefarah/yq/releases/download/${release_tag}/yq_linux_amd64"
  sudo install -o root -g root -m 0755 "${filename}" /usr/local/bin/"${filename}"
  rm "${filename}"
fi
