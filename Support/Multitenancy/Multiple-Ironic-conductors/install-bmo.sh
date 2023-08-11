#!/bin/bash
set -e

# kubectl create ns metal3

cp ironic.env bmo-config/

kubectl apply -k bmo-config

kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-controller-manager --timeout=300s
