#!/bin/bash

export CLUSTER_TOPOLOGY=true
clusterctl init --core cluster-api:v1.9.11 --bootstrap kubeadm:v1.9.11 --control-plane kubeadm:v1.9.11 --infrastructure=metal3:v1.9.5 -v5
kubectl -n capi-system wait deploy capi-controller-manager --for=condition=available --timeout=600s
kubectl -n capm3-system wait deploy capm3-controller-manager --for=condition=available --timeout=600s
kubectl -n capm3-system wait deploy ipam-controller-manager --for=condition=available --timeout=600s
