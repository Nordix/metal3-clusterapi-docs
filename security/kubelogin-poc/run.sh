#!/usr/bin/env bash

set -eux

rm -rf ~/.kube/cache/oidc-login
kind delete cluster --name kubelogin-poc || true
rm -f ssl/* && ./gencert.sh
kind create cluster --config=kind.conf --name kubelogin-poc
sleep 20
kubectl apply -f k8s/dex.yaml
kubectl create secret tls dex.example.com.tls --cert=ssl/cert.pem --key=ssl/key.pem --namespace=dex
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
EOF
