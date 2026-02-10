#!/usr/bin/env bash
set -euo pipefail

# Create a QEMU VM with vTPM for hardware TPM testing.
# Downloads Ubuntu cloud image, configures cloud-init, boots with swtpm backend.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="${SCRIPT_DIR}/../.vm"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
CLOUD_IMG="${VM_DIR}/ubuntu-cloud.img"
VM_DISK="${VM_DIR}/vm-disk.qcow2"
VM_PID="${VM_DIR}/vm.pid"
SWTPM_DIR="${VM_DIR}/swtpm"
SWTPM_PID="${VM_DIR}/swtpm.pid"
SSH_PORT="${SSH_PORT:-2222}"
VM_RAM="${VM_RAM:-4096}"
VM_CPUS="${VM_CPUS:-4}"
SSH_KEY="${VM_DIR}/vm_key"
DISK_SIZE="${DISK_SIZE:-40G}"

mkdir -p "${VM_DIR}" "${SWTPM_DIR}"

# Check prerequisites
for cmd in qemu-system-x86_64 qemu-img swtpm cloud-localds ssh-keygen; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "ERROR: ${cmd} not found. Install it first."
        echo "  apt install qemu-system-x86 qemu-utils swtpm cloud-image-utils openssh-client"
        exit 1
    fi
done

if [[ -f "${VM_PID}" ]] && kill -0 "$(cat "${VM_PID}")" 2>/dev/null; then
    echo "VM already running (pid $(cat "${VM_PID}"))"
    exit 0
fi

# Generate SSH key for VM access
if [[ ! -f "${SSH_KEY}" ]]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -q
fi

# Download cloud image
if [[ ! -f "${CLOUD_IMG}" ]]; then
    echo "Downloading Ubuntu 24.04 cloud image..."
    curl -L -o "${CLOUD_IMG}" "${CLOUD_IMG_URL}"
fi

# Create VM disk from cloud image
echo "Creating VM disk (${DISK_SIZE})..."
cp "${CLOUD_IMG}" "${VM_DISK}"
qemu-img resize "${VM_DISK}" "${DISK_SIZE}"

# Create cloud-init config
SSH_PUB="$(cat "${SSH_KEY}.pub")"
cat > "${VM_DIR}/user-data" <<EOF
#cloud-config
hostname: keylime-hwtpm
users:
  - name: keylime
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${SSH_PUB}

package_update: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gpg
  - tpm2-tools

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter
  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1

runcmd:
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
  - swapoff -a
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - mkdir -p /etc/apt/keyrings
  - rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y containerd kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - sed -i 's/device_ownership_from_security_context = false/device_ownership_from_security_context = true/' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd kubelet
  - touch /var/lib/cloud/instance/boot-finished-custom

final_message: "Cloud-init complete after \$DATASOURCE_LIST seconds"
EOF

cat > "${VM_DIR}/meta-data" <<EOF
instance-id: keylime-hwtpm-001
local-hostname: keylime-hwtpm
EOF

# Create cloud-init ISO
cloud-localds "${VM_DIR}/cloud-init.iso" "${VM_DIR}/user-data" "${VM_DIR}/meta-data"

# Start swtpm (vTPM backend for QEMU)
echo "Starting swtpm..."
if [[ -f "${SWTPM_PID}" ]] && kill -0 "$(cat "${SWTPM_PID}")" 2>/dev/null; then
    echo "swtpm already running"
else
    swtpm socket --tpm2 \
        --tpmstate dir="${SWTPM_DIR}" \
        --ctrl type=unixio,path="${SWTPM_DIR}/swtpm-sock" \
        --flags startup-clear \
        --daemon \
        --pid file="${SWTPM_PID}"
    sleep 1
fi

# Start QEMU VM
echo "Starting QEMU VM (${VM_CPUS} CPUs, ${VM_RAM}MB RAM, SSH port ${SSH_PORT})..."
qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -smp "${VM_CPUS}" \
    -m "${VM_RAM}" \
    -drive file="${VM_DISK}",format=qcow2,if=virtio \
    -drive file="${VM_DIR}/cloud-init.iso",format=raw,if=virtio \
    -chardev socket,id=chrtpm,path="${SWTPM_DIR}/swtpm-sock" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-crb,tpmdev=tpm0 \
    -netdev user,id=net0,hostfwd=tcp::"${SSH_PORT}"-:22 \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -serial null \
    -daemonize \
    -pidfile "${VM_PID}"

echo "VM started (pid $(cat "${VM_PID}"))"
echo "Waiting for SSH..."

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q)

for i in $(seq 1 60); do
    if ssh "${SSH_OPTS[@]}" -o ConnectTimeout=2 -i "${SSH_KEY}" -p "${SSH_PORT}" \
        keylime@localhost true 2>/dev/null; then
        echo "SSH ready after ${i} seconds"
        break
    fi
    if [[ "${i}" -eq 60 ]]; then
        echo "ERROR: SSH not ready after 60s"
        exit 1
    fi
    sleep 1
done

# Wait for cloud-init to finish
echo "Waiting for cloud-init to complete..."
for i in $(seq 1 300); do
    if ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" -p "${SSH_PORT}" \
        keylime@localhost "test -f /var/lib/cloud/instance/boot-finished-custom" 2>/dev/null; then
        echo "Cloud-init complete after ${i} seconds"
        break
    fi
    if [[ "${i}" -eq 300 ]]; then
        echo "ERROR: cloud-init not finished after 300s"
        exit 1
    fi
    sleep 1
done

# Verify vTPM
echo "Verifying vTPM..."
ssh "${SSH_OPTS[@]}" -i "${SSH_KEY}" -p "${SSH_PORT}" \
    keylime@localhost "ls -la /dev/tpm0 /dev/tpmrm0 && { sudo tpm2_getcap properties-fixed | head -5 || true; }"

echo ""
echo "VM ready. SSH: ssh -i ${SSH_KEY} -p ${SSH_PORT} keylime@localhost"
