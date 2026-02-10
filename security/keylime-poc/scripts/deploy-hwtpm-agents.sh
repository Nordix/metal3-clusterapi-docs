#!/usr/bin/env bash
set -euo pipefail

# Deploy keylime agent into the vTPM VM.
# Copies files into VM via scp, runs vm-setup.sh, waits for registration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
VM_DIR="${PROJECT_DIR}/.vm"
SSH_KEY="${VM_DIR}/vm_key"
SSH_PORT="${SSH_PORT:-2222}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q)

HOST_IP="${1:?Usage: deploy-hwtpm-agents.sh <host_ip> <keylime_version> <keylime_uid> <keylime_gid>}"
KEYLIME_VERSION="${2:-latest}"
KEYLIME_UID="${3:-490}"
KEYLIME_GID="${4:-490}"
UUID_MODE="${5:-hash_ek}"

CERTS_DIR="${PROJECT_DIR}/certs"
K8S_AGENTS="${PROJECT_DIR}/k8s/agents"

if [[ ! -f "${SSH_KEY}" ]]; then
    echo "ERROR: VM SSH key not found. Run create-vtpm-vm.sh first."
    exit 1
fi

vm_ssh() {
    ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" -p "${SSH_PORT}" keylime@localhost "$@"
}

vm_scp() {
    scp "${SSH_OPTS[@]}" -i "${SSH_KEY}" -P "${SSH_PORT}" "$@"
}

echo "=== Loading agent image into VM ==="
# Check if image exists locally
if ! docker image inspect "keylime-push-agent:${KEYLIME_VERSION}" &>/dev/null; then
    echo "ERROR: keylime-push-agent:${KEYLIME_VERSION} not found. Run 'make setup' first."
    exit 1
fi

# Transfer image to VM and load into containerd
echo "Exporting agent image..."
docker save "keylime-push-agent:${KEYLIME_VERSION}" | \
    vm_ssh "sudo ctr -n k8s.io images import -"

echo "=== Copying files to VM ==="
vm_ssh "mkdir -p ~/keylime/certs ~/keylime/k8s/agents/agent"

vm_scp "${CERTS_DIR}/cacert.crt" \
       "${CERTS_DIR}/client-cert.crt" \
       "${CERTS_DIR}/client-private.pem" \
       keylime@localhost:~/keylime/certs/

vm_scp "${K8S_AGENTS}/agent-daemonset-hw.yaml" \
       "${K8S_AGENTS}/device-plugin.yaml" \
       "${K8S_AGENTS}/agent-configmap.yaml" \
       "${K8S_AGENTS}/namespace.yaml" \
       keylime@localhost:~/keylime/k8s/agents/

vm_scp "${K8S_AGENTS}/agent/keylime-agent.conf" \
       keylime@localhost:~/keylime/k8s/agents/agent/

vm_scp "${SCRIPT_DIR}/vm-setup.sh" \
       keylime@localhost:~/keylime/

echo "=== Running vm-setup.sh inside VM ==="
vm_ssh "chmod +x ~/keylime/vm-setup.sh && ~/keylime/vm-setup.sh '${HOST_IP}' '${KEYLIME_VERSION}' '${KEYLIME_UID}' '${KEYLIME_GID}' '${UUID_MODE}'"

echo ""
echo "Waiting for agent registration..."
sleep 15

echo "hwtpm agent deployment complete."
