#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "======================================================================"
echo "Verifying Keylime Push Model Attestation"
echo "======================================================================"

kubectl config use-context kind-keylime-infra >/dev/null 2>&1

echo ""
echo "Waiting for attestation to complete..."
sleep 10

# Get all registered agent UUIDs (supports both standard UUIDs and hash_ek hex strings)
# Filter only from the actual registrar results line (contains "uuids")
AGENT_UUIDS=$("${SCRIPT_DIR}/tenant.sh" -c reglist 2>&1 | \
    grep '"uuids"' | \
    grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{64}' | \
    sort -u)

if [[ -z "${AGENT_UUIDS}" ]]; then
    echo "FAILED: No agents registered"
    exit 1
fi

AGENT_COUNT=$(echo "${AGENT_UUIDS}" | wc -l)
echo "Checking ${AGENT_COUNT} agent(s)..."
echo ""

SUCCESS_COUNT=0
PENDING_COUNT=0

for uuid in ${AGENT_UUIDS}; do
    STATUS=$("${SCRIPT_DIR}/tenant.sh" -c status -u "${uuid}" --push-model 2>&1)
    ATT_COUNT=$(echo "${STATUS}" | grep -o '"attestation_count": [0-9]*' | grep -o '[0-9]*' || echo "0")

    if [[ -n "${ATT_COUNT}" ]] && [[ "${ATT_COUNT}" -gt 0 ]]; then
        echo "  ${uuid}: ${ATT_COUNT} attestation(s) - OK"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "  ${uuid}: pending"
        PENDING_COUNT=$((PENDING_COUNT + 1))
    fi
done

echo ""
echo "======================================================================"
if [[ "${PENDING_COUNT}" -eq 0 ]]; then
    echo "SUCCESS: All ${SUCCESS_COUNT} agent(s) attesting correctly!"
else
    echo "PARTIAL: ${SUCCESS_COUNT}/${AGENT_COUNT} agent(s) attesting"
    echo "         ${PENDING_COUNT} agent(s) still pending"
    echo "Re-run 'make verify' in a few seconds"
fi
echo "======================================================================"
