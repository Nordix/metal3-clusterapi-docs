#!/usr/bin/env bash

set -eu

TYPE="${1:?type missing: either 'password' or 'device-code'}"

KIND_NAME="kubelogin-poc"
KUBELOGIN_CACHE="${HOME}/.kube/cache/oidc-login"

echo "checking tools ..."
command -v kubectl &>/dev/null || { echo "error: kubectl not in PATH"; exit 1; }
command -v kind &>/dev/null || { echo "error: kind not in PATH"; exit 1; }

echo "removing old clusters with name '${KIND_NAME}' ..."
rm -rf "${KUBELOGIN_CACHE}"
kind delete cluster --name "${KIND_NAME}" || true

echo "generating certificates ..."
rm -f ssl/* && ./gencert.sh

echo "creating kind cluster with name '${KIND_NAME}' ..."
kind create cluster --config=kind.conf --name "${KIND_NAME}"
sleep 20

echo "applying dex-${TYPE}.yaml ..."
kubectl apply -f "k8s/dex-${TYPE}.yaml"
kubectl create secret tls dex.example.com.tls \
    --cert=ssl/cert.pem --key=ssl/key.pem --namespace=dex

echo "applying openldap.yaml ..."
kubectl apply -f k8s/openldap.yaml

echo "creating cluster roles ..."
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

echo "configuring kubekonfig for user oidc ..."
if [[ "${TYPE}" == "password" ]]; then
    kubectl config set-credentials oidc \
        --exec-api-version=client.authentication.k8s.io/v1beta1 \
        --exec-command=kubectl \
        --exec-arg=oidc-login \
        --exec-arg=get-token \
        --exec-arg=--oidc-issuer-url=https://dex.example.com:32000 \
        --exec-arg=--oidc-client-id=kubelogin-test \
        --exec-arg=--oidc-extra-scope=email \
        --exec-arg=--oidc-extra-scope=profile \
        --exec-arg=--oidc-extra-scope=groups \
        --exec-arg=--insecure-skip-tls-verify \
        --exec-arg=--oidc-client-secret=kubelogin-test-secret \
        --exec-arg=--grant-type=password \
        --exec-arg=-v1
else
    kubectl config set-credentials oidc \
        --exec-api-version=client.authentication.k8s.io/v1beta1 \
        --exec-command=kubectl \
        --exec-arg=oidc-login \
        --exec-arg=get-token \
        --exec-arg=--oidc-issuer-url=https://dex.example.com:32000 \
        --exec-arg=--oidc-client-id=kubelogin-test \
        --exec-arg=--oidc-extra-scope=email \
        --exec-arg=--oidc-extra-scope=profile \
        --exec-arg=--oidc-extra-scope=groups \
        --exec-arg=--insecure-skip-tls-verify \
        --exec-arg=--oidc-pkce-method=S256 \
        --exec-arg=--grant-type=device-code \
        --exec-arg=-v1
fi
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
