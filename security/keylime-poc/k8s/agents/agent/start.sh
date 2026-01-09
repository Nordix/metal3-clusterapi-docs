#!/usr/bin/env bash
set -euo pipefail

# Start script for push model agent with swtpm
# Agent connects directly to swtpm via TCP (TCTI=swtpm:)

SWTPM_STATE_DIR="${SWTPM_STATE_DIR:-/var/lib/swtpm}"

echo "Starting swtpm..."

# Create swtpm state directory
mkdir -p "${SWTPM_STATE_DIR}"
chown tss:tss "${SWTPM_STATE_DIR}" || true
chmod 750 "${SWTPM_STATE_DIR}"

# Initialize swtpm if not already initialized
if [[ ! -f "${SWTPM_STATE_DIR}/tpm2-00.permall" ]]; then
    echo "Initializing swtpm state..."
    swtpm_setup --tpm2 \
        --tpmstate "${SWTPM_STATE_DIR}" \
        --createek --decryption --create-ek-cert \
        --create-platform-cert \
        --display || true
fi

# Start swtpm with TCP sockets (same as working agent-with-swtpm)
swtpm socket --tpm2 \
    --tpmstate dir="${SWTPM_STATE_DIR}" \
    --flags startup-clear \
    --ctrl type=tcp,port=2322 \
    --server type=tcp,port=2321 \
    --daemon

echo "swtpm started"
sleep 2

# Agent UUID is configured in agent.conf via UUID_MODE:
#   uuid=generate - random UUID at config load time
#   uuid=hash_ek  - derived from TPM EK hash (stable per TPM)

REGISTRAR_IP="${KEYLIME_AGENT_REGISTRAR_IP:-127.0.0.1}"
REGISTRAR_PORT="${KEYLIME_AGENT_REGISTRAR_PORT:-30890}"
VERIFIER_URL="${KEYLIME_AGENT_VERIFIER_URL:?KEYLIME_AGENT_VERIFIER_URL must be set}"
CA_CERT="${KEYLIME_AGENT_TRUSTED_CLIENT_CA:-/var/lib/keylime/certs/cacert.crt}"
CLIENT_CERT="${KEYLIME_AGENT_SERVER_CERT:-/var/lib/keylime/certs/client-cert.crt}"
CLIENT_KEY="${KEYLIME_AGENT_SERVER_KEY:-/var/lib/keylime/certs/client-private.pem}"

echo "Starting keylime_push_model_agent..."
echo "Registrar: ${REGISTRAR_IP}:${REGISTRAR_PORT}"
echo "Verifier URL: ${VERIFIER_URL}"

# Run the push model agent
# UUID mode is configured in agent.conf (generate or hash_ek)
exec /bin/keylime_push_model_agent \
    --registrar-url "http://${REGISTRAR_IP}:${REGISTRAR_PORT}" \
    --verifier-url "${VERIFIER_URL}" \
    --ca-certificate "${CA_CERT}" \
    --certificate "${CLIENT_CERT}" \
    --key "${CLIENT_KEY}"
