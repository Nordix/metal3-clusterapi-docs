#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT="${1:-120}"
POLL_INTERVAL=5

echo ""
echo "======================================================================"
echo "Verifying Keylime Push Model Attestation"
echo "======================================================================"

kubectl config use-context kind-keylime-infra >/dev/null 2>&1

# Get all registered agent UUIDs (supports both standard UUIDs and
# hash_ek hex strings). Filter only from the actual registrar results
# line (contains "uuids").
get_agent_uuids() {
    "${SCRIPT_DIR}/tenant.sh" -c reglist 2>&1 | \
        grep '"uuids"' | \
        grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{64}' | \
        sort -u
}

echo ""
echo "Waiting for attestation (timeout: ${TIMEOUT}s)..."

ELAPSED=0
while [[ "${ELAPSED}" -lt "${TIMEOUT}" ]]; do
    AGENT_UUIDS=$(get_agent_uuids)

    if [[ -z "${AGENT_UUIDS}" ]]; then
        echo "  No agents registered yet (${ELAPSED}s elapsed)..."
        sleep "${POLL_INTERVAL}"
        ELAPSED=$((ELAPSED + POLL_INTERVAL))
        continue
    fi

    AGENT_COUNT=$(echo "${AGENT_UUIDS}" | wc -l)
    SUCCESS_COUNT=0

    for uuid in ${AGENT_UUIDS}; do
        STATUS=$("${SCRIPT_DIR}/tenant.sh" -c status -u "${uuid}" \
            --push-model 2>&1)
        ATT_COUNT=$(echo "${STATUS}" | \
            grep -o '"attestation_count": [0-9]*' | \
            grep -o '[0-9]*' || echo "0")

        if [[ -n "${ATT_COUNT}" ]] && [[ "${ATT_COUNT}" -gt 0 ]]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done

    if [[ "${SUCCESS_COUNT}" -eq "${AGENT_COUNT}" ]]; then
        echo ""
        echo "Checking ${AGENT_COUNT} agent(s)..."
        echo ""
        for uuid in ${AGENT_UUIDS}; do
            STATUS=$("${SCRIPT_DIR}/tenant.sh" -c status -u "${uuid}" \
                --push-model 2>&1)
            ATT_COUNT=$(echo "${STATUS}" | \
                grep -o '"attestation_count": [0-9]*' | \
                grep -o '[0-9]*' || echo "0")
            echo "  ${uuid}: ${ATT_COUNT} attestation(s) - OK"
        done
        echo ""
        echo "======================================================================"
        echo "SUCCESS: All ${AGENT_COUNT} agent(s) attesting correctly!"
        echo "======================================================================"
        exit 0
    fi

    echo "  ${SUCCESS_COUNT}/${AGENT_COUNT} attesting (${ELAPSED}s elapsed)..."
    sleep "${POLL_INTERVAL}"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout -- print final status
echo ""
AGENT_UUIDS=$(get_agent_uuids)
AGENT_COUNT=$(echo "${AGENT_UUIDS}" | wc -l)
echo "Checking ${AGENT_COUNT} agent(s)..."
echo ""

SUCCESS_COUNT=0
PENDING_COUNT=0

for uuid in ${AGENT_UUIDS}; do
    STATUS=$("${SCRIPT_DIR}/tenant.sh" -c status -u "${uuid}" \
        --push-model 2>&1)
    ATT_COUNT=$(echo "${STATUS}" | \
        grep -o '"attestation_count": [0-9]*' | \
        grep -o '[0-9]*' || echo "0")

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
echo "FAILED: Timed out after ${TIMEOUT}s"
echo "        ${SUCCESS_COUNT}/${AGENT_COUNT} agent(s) attesting"
echo "        ${PENDING_COUNT} agent(s) still pending"
echo "======================================================================"
exit 1
