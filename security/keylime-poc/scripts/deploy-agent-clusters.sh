#!/usr/bin/env bash
set -euo pipefail

CLUSTER_COUNT="$1"
K8S_AGENTS="$2"
CERTS_DIR="$3"
HOST_IP="$4"
KEYLIME_VERSION="${5:-latest}"
UUID_MODE="${6:-generate}"

echo "Deploying agents to ${CLUSTER_COUNT} cluster(s)..."
echo "UUID mode: ${UUID_MODE}"

for i in $(seq 1 "${CLUSTER_COUNT}"); do
    CLUSTER_NAME="keylime-agents-${i}"
    echo ""
    echo "=== Deploying to ${CLUSTER_NAME} ==="

    # Switch context
    kubectl config use-context "kind-${CLUSTER_NAME}"

    # Load image
    echo "Loading agent image..."
    kind load docker-image --name "${CLUSTER_NAME}" "keylime-push-agent:${KEYLIME_VERSION}"

    # Deploy using existing script logic
    echo "Deploying agent components (version: ${KEYLIME_VERSION})..."
    kubectl apply -f "${K8S_AGENTS}/namespace.yaml"

    # Create client certs secret
    kubectl create secret generic keylime-client-certs \
        --namespace keylime \
        --from-file=cacert.crt="${CERTS_DIR}/cacert.crt" \
        --from-file=client-cert.crt="${CERTS_DIR}/client-cert.crt" \
        --from-file=client-private.pem="${CERTS_DIR}/client-private.pem" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Generate agent.conf with UUID mode and create configmap
    echo "Generating agent config (uuid=${UUID_MODE})..."
    TMPCONF=$(mktemp)
    sed "s/^uuid = .*/uuid = \"${UUID_MODE}\"/" "${K8S_AGENTS}/agent/keylime-agent.conf" > "${TMPCONF}"

    # Create configmap with both agent.conf and host addresses
    kubectl create configmap keylime-agent-config \
        --namespace keylime \
        --from-file=agent.conf="${TMPCONF}" \
        --from-literal=registrar_host="${HOST_IP}" \
        --from-literal=verifier_url="https://${HOST_IP}:30881" \
        --dry-run=client -o yaml | kubectl apply -f -
    rm -f "${TMPCONF}"

    sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g" "${K8S_AGENTS}/agent-daemonset.yaml" | kubectl apply -f -

    echo "Waiting for agent pods in ${CLUSTER_NAME}..."
    for _ in {1..30}; do
        if kubectl get pod -l app=keylime-agent -n keylime 2>/dev/null | grep -q keylime-agent; then
            break
        fi
        sleep 2
    done
    kubectl wait --for=condition=Ready pod -l app=keylime-agent -n keylime --timeout=120s || true
done

# Wait for all agents to register
echo ""
echo "Waiting for agent registration..."
sleep 15

echo "All agent clusters deployed."
