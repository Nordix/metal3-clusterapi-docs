#!/usr/bin/env bash
set -euo pipefail

K8S_INFRA="$1"
CERTS_DIR="$2"
KEYLIME_VERSION="${3:-latest}"

echo "Deploying infra components (version: ${KEYLIME_VERSION})..."
kubectl apply -f "${K8S_INFRA}/namespace.yaml"

# Create combined certs secret (server + client certs for verifier)
kubectl create secret generic keylime-certs \
    --namespace keylime \
    --from-file=cacert.crt="${CERTS_DIR}/cacert.crt" \
    --from-file=server-cert.crt="${CERTS_DIR}/server-cert.crt" \
    --from-file=server-private.pem="${CERTS_DIR}/server-private.pem" \
    --from-file=client-cert.crt="${CERTS_DIR}/client-cert.crt" \
    --from-file=client-private.pem="${CERTS_DIR}/client-private.pem" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create configmap
kubectl create configmap keylime-config \
    --namespace keylime \
    --from-file="${K8S_INFRA}/configmaps/registrar.conf" \
    --from-file="${K8S_INFRA}/configmaps/verifier.conf" \
    --from-file="${K8S_INFRA}/configmaps/tenant.conf" \
    --dry-run=client -o yaml | kubectl apply -f -

sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g" "${K8S_INFRA}/registrar-deployment.yaml" | kubectl apply -f -
kubectl apply -f "${K8S_INFRA}/registrar-service.yaml"
sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g" "${K8S_INFRA}/verifier-deployment.yaml" | kubectl apply -f -
kubectl apply -f "${K8S_INFRA}/verifier-service.yaml"

# Pod spec is immutable for image changes; recreate to ensure the version is applied.
kubectl delete pod keylime-tenant -n keylime --ignore-not-found
sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g" "${K8S_INFRA}/tenant-pod.yaml" | kubectl apply -f -

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod -l app=keylime-registrar -n keylime --timeout=120s || true
kubectl wait --for=condition=Ready pod -l app=keylime-verifier -n keylime --timeout=120s || true
