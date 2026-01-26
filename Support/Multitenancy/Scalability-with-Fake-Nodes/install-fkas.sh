#!/bin/bash

# shellcheck disable=SC1091
. ./config.sh

curl -s https://raw.githubusercontent.com/metal3-io/cluster-api-provider-metal3/refs/heads/release-1.9/hack/fake-apiserver/k8s/metal3-fkas-system.yaml | sed "s/replicas: [0-9]\+/replicas: $N_FKAS/" | kubectl apply -f -
