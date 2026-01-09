#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPM_POLICY="$1"

echo "Adding all registered agents to verifier..."

# Get all registered agent UUIDs (supports both standard UUIDs and hash_ek hex strings)
# Standard UUID: 8-4-4-4-12 hex chars with dashes
# hash_ek: 64 hex chars (SHA-256 hash)
# Filter only from the actual registrar results line (contains "uuids")
AGENT_UUIDS=$("${SCRIPT_DIR}/tenant.sh" -c reglist 2>&1 | \
    grep '"uuids"' | \
    grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{64}' | \
    sort -u)

if [[ -z "${AGENT_UUIDS}" ]]; then
    echo "ERROR: No agents found in registrar"
    exit 1
fi

AGENT_COUNT=$(echo "${AGENT_UUIDS}" | wc -l)
echo "Found ${AGENT_COUNT} agent(s) in registrar"

for uuid in ${AGENT_UUIDS}; do
    echo "Adding agent: ${uuid}"
    "${SCRIPT_DIR}/tenant.sh" -c add --push-model -u "${uuid}" --tpm_policy "${TPM_POLICY}" || true
done

echo "All agents added to verifier."
