#!/usr/bin/env bash
set -euo pipefail

# Destroy the vTPM QEMU VM and clean up all files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="${SCRIPT_DIR}/../.vm"
VM_PID="${VM_DIR}/vm.pid"
SWTPM_PID="${VM_DIR}/swtpm.pid"

if [[ -f "${VM_PID}" ]]; then
    PID="$(cat "${VM_PID}")"
    if kill -0 "${PID}" 2>/dev/null; then
        echo "Stopping VM (pid ${PID})..."
        kill "${PID}" || true
        sleep 2
        kill -9 "${PID}" 2>/dev/null || true
    fi
    rm -f "${VM_PID}"
fi

if [[ -f "${SWTPM_PID}" ]]; then
    PID="$(cat "${SWTPM_PID}")"
    if kill -0 "${PID}" 2>/dev/null; then
        echo "Stopping swtpm (pid ${PID})..."
        kill "${PID}" || true
    fi
    rm -f "${SWTPM_PID}"
fi

# Clean up VM files but keep the downloaded cloud image
if [[ -d "${VM_DIR}" ]]; then
    echo "Cleaning VM files..."
    rm -f "${VM_DIR}/vm-disk.qcow2" \
          "${VM_DIR}/cloud-init.iso" \
          "${VM_DIR}/user-data" \
          "${VM_DIR}/meta-data" \
          "${VM_DIR}/vm_key" \
          "${VM_DIR}/vm_key.pub"
    rm -rf "${VM_DIR}/swtpm"
fi

echo "VM destroyed."
