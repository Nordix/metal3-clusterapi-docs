#!/usr/bin/env bash
set -euo pipefail

# VM setup script - runs INSIDE the QEMU VM.
# Initializes kubeadm single-node cluster and deploys keylime agent
# with hardware TPM (/dev/tpmrm0).
#
# Usage: vm-setup.sh <host_ip> <keylime_version> <keylime_uid> <keylime_gid>
#
# Expects these files to be scp'd into ~/keylime/ before running:
#   certs/cacert.crt, certs/client-cert.crt, certs/client-private.pem
#   k8s/agents/agent-daemonset-hw.yaml
#   k8s/agents/device-plugin.yaml
#   k8s/agents/namespace.yaml
#   k8s/agents/agent/keylime-agent.conf

HOST_IP="${1:?Usage: vm-setup.sh <host_ip> <keylime_version> <keylime_uid> <keylime_gid>}"
KEYLIME_VERSION="${2:-latest}"
KEYLIME_UID="${3:-490}"
KEYLIME_GID="${4:-490}"
UUID_MODE="${5:-hash_ek}"

WORK_DIR="${HOME}/keylime"
CERTS_DIR="${WORK_DIR}/certs"
K8S_DIR="${WORK_DIR}/k8s/agents"

echo "=== Verifying vTPM ==="
ls -la /dev/tpm0 /dev/tpmrm0
sudo tpm2_getcap properties-fixed 2>&1 | head -5 || true

echo "=== Initializing kubeadm cluster ==="
if kubectl get nodes &>/dev/null; then
    echo "Cluster already initialized"
else
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16

    mkdir -p "${HOME}/.kube"
    sudo cp /etc/kubernetes/admin.conf "${HOME}/.kube/config"
    sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"

    # Untaint control-plane to schedule workloads
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

    # Install Calico CNI
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

    echo "Waiting for node to be ready..."
    kubectl wait --for=condition=Ready node --all --timeout=120s
fi

echo "=== Deploying device plugin ==="
kubectl apply -f "${K8S_DIR}/device-plugin.yaml"
echo "Waiting for device plugin..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=generic-device-plugin \
    -n kube-system --timeout=120s || true

# Wait for TPM resource to appear
echo "Waiting for TPM resource..."
for i in $(seq 1 30); do
    if kubectl describe node | grep -q "squat.ai/tpm"; then
        echo "TPM resource available"
        break
    fi
    if [[ "${i}" -eq 30 ]]; then
        echo "ERROR: TPM resource not available after 30s"
        kubectl describe node | grep -A5 "Capacity:"
        exit 1
    fi
    sleep 2
done

echo "=== Deploying keylime agent ==="
kubectl apply -f "${K8S_DIR}/namespace.yaml"

# Create client certs secret
kubectl create secret generic keylime-client-certs \
    --namespace keylime \
    --from-file=cacert.crt="${CERTS_DIR}/cacert.crt" \
    --from-file=client-cert.crt="${CERTS_DIR}/client-cert.crt" \
    --from-file=client-private.pem="${CERTS_DIR}/client-private.pem" \
    --dry-run=client -o yaml | kubectl apply -f -

# Generate agent config with UUID mode
TMPCONF=$(mktemp)
sed "s/^uuid = .*/uuid = \"${UUID_MODE}\"/" "${K8S_DIR}/agent/keylime-agent.conf" > "${TMPCONF}"

kubectl create configmap keylime-agent-config \
    --namespace keylime \
    --from-file=agent.conf="${TMPCONF}" \
    --from-literal=registrar_host="${HOST_IP}" \
    --from-literal=verifier_url="https://${HOST_IP}:30881" \
    --dry-run=client -o yaml | kubectl apply -f -
rm -f "${TMPCONF}"

# Deploy agent DaemonSet
sed "s/__KEYLIME_VERSION__/${KEYLIME_VERSION}/g; s/__KEYLIME_UID__/${KEYLIME_UID}/g; s/__KEYLIME_GID__/${KEYLIME_GID}/g" \
    "${K8S_DIR}/agent-daemonset-hw.yaml" | kubectl apply -f -

echo "Waiting for agent pod..."
for _ in {1..30}; do
    if kubectl get pod -l app=keylime-agent -n keylime 2>/dev/null | grep -q keylime-agent; then
        break
    fi
    sleep 2
done
kubectl wait --for=condition=Ready pod -l app=keylime-agent -n keylime --timeout=120s || true

echo "=== Agent deployed ==="
kubectl get pods -n keylime -o wide
kubectl logs -n keylime -l app=keylime-agent --tail=10 || true
