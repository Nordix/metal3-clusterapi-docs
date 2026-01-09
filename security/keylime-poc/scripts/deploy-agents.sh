#!/usr/bin/env bash
set -euo pipefail

K8S_AGENTS="$1"
CERTS_DIR="$2"
HOST_IP="$3"
KEYLIME_VERSION="${4:-latest}"

echo "Deploying agent components (version: ${KEYLIME_VERSION})..."
kubectl apply -f "${K8S_AGENTS}/namespace.yaml"

# Create client certs secret
kubectl create secret generic keylime-client-certs \
    --namespace keylime \
    --from-file=cacert.crt="${CERTS_DIR}/cacert.crt" \
    --from-file=client-cert.crt="${CERTS_DIR}/client-cert.crt" \
    --from-file=client-private.pem="${CERTS_DIR}/client-private.pem" \
    --dry-run=client -o yaml | kubectl apply -f -

# Update configmap with host IP
echo "Using host IP: ${HOST_IP}"
sed "s/PLACEHOLDER/${HOST_IP}/g" "${K8S_AGENTS}/agent-configmap.yaml" | kubectl apply -f -

sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g" "${K8S_AGENTS}/agent-daemonset.yaml" | kubectl apply -f -

echo "Waiting for agent pods..."
# Wait for pod to be scheduled first
for _ in {1..30}; do
    if kubectl get pod -l app=keylime-agent -n keylime 2>/dev/null | grep -q keylime-agent; then
        break
    fi
    sleep 2
done
kubectl wait --for=condition=Ready pod -l app=keylime-agent -n keylime --timeout=120s || true

# Give agent time to initialize swtpm and register
echo "Waiting for agent registration..."
sleep 15
