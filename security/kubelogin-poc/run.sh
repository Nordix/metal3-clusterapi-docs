#!/usr/bin/env bash

set -eux

KIND_NAME="poc"
KUBELOGIN_CACHE="${HOME}/.kube/cache/oidc-login"

command -v kubectl &>/dev/null || { echo "error: kubectl not in PATH"; exit 1; }
command -v kind &>/dev/null || { echo "error: kind not in PATH"; exit 1; }

rm -rf "${KUBELOGIN_CACHE}"
kind delete cluster --name "${KIND_NAME}" || true
rm -f ssl/* && ./gencert.sh
kind create cluster --config=kind.conf --name "${KIND_NAME}"
sleep 20
kubectl apply -f k8s/dex.yaml
kubectl create secret tls dex.example.com.tls \
    --cert=ssl/cert.pem --key=ssl/key.pem --namespace=dex
kubectl apply -f k8s/openldap.yaml

# create role for user "customuser"
# user is whatever the group-claim=groups field defines groups field is
kubectl create clusterrolebinding oidc-cluster-admin \
    --clusterrole=cluster-admin \
    --user='Bar1'

# create role for user "foo"
kubectl create clusterrolebinding oidc-view-group \
    --clusterrole=view \
    --user='Bar2'

sleep 20
kubectl get pods -A

cat <<EOF
Done!

Now do: kubectl --user oidc get pods -A

and use either:
- customuser/custompassword   for cluster-admin
- foo/bar                     for view

as legit users. First is cluster-admin, second has only view rights.

Remove ~/.kube/cache/oidc-login/ if you want to relogin without recreating
the environment.

When done, delete kind cluster with: kind delete cluster --name ${KIND_NAME}

EOF
