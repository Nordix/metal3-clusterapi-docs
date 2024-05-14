#!/bin/bash
set -eux

./build-api-server-container-image.sh -f

. ./config.sh

yq ".spec.replicas = ${N_APISERVER_PODS}" apiserver-deployments.yaml | kubectl delete -f -
kubectl wait deploy metal3-fake-api-server --for=delete --timeout=600s

yq ".spec.replicas = ${N_APISERVER_PODS}" apiserver-deployments.yaml | kubectl apply -f -

kubectl wait deploy metal3-fake-api-server --for=condition=available --timeout=600s

./create-clusters.sh
