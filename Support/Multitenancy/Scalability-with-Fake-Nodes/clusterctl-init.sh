#!/bin/bash

export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure=metal3
kubectl -n capi-system wait deploy capi-controller-manager --for=condition=available --timeout=600s
kubectl -n capm3-system wait deploy capm3-controller-manager --for=condition=available --timeout=600s
kubectl -n capm3-system wait deploy ipam-controller-manager --for=condition=available --timeout=600s
