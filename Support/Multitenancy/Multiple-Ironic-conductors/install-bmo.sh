#!/bin/bash
set -e

kubectl apply -k bmo-config

kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-controller-manager --timeout=300s
