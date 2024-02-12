#!/bin/bash
set -eux

# Download ipa image
cat << EOF >"ironic.env"
HTTP_PORT=6180
PROVISIONING_INTERFACE=ironicendpoint
DHCP_RANGE=172.22.0.10,172.22.0.100
DEPLOY_KERNEL_URL=http://172.22.0.2:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://172.22.0.2:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://172.22.0.2:6385/v1/
IRONIC_INSPECTOR_ENDPOINT=https://172.22.0.2:5050/v1/
CACHEURL=http://172.22.0.1/images
IRONIC_FAST_TRACK=true
EOF

__dir__=$(realpath "$(dirname "$0")")
IRONIC_DATA_DIR="${__dir__}/opt/metal3-dev-env/ironic"
mkdir -p "${IRONIC_DATA_DIR}"
IPA_DOWNLOADER_IMAGE="quay.io/metal3-io/ironic-ipa-downloader"
docker run -d --net host --privileged --name ipa-downloader \
  --env-file ironic.env \
  -v "${IRONIC_DATA_DIR}:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

export IRONIC_DATA_DIR

minikube config set driver kvm2
minikube config set memory 5000
minikube config set cpus 20
minikube delete
# eval $(minikube docker-env)
sudo usermod --append --groups libvirt "$(whoami)"
while /bin/true; do
  minikube_error=0
  # minikube start --insecure-registry 127.0.0.1:5000 || minikube_error=1
  minikube start --driver=kvm2 || minikube_error=1
  if [[ $minikube_error -eq 0 ]]; then
    break
  fi
  minikube delete --all --purge
  sudo ip link delete virbr0 | true
done
# minikube image load registry.k8s.io/metrics-server/metrics-server:v0.6.4@sha256:ee4304963fb035239bb5c5e8c10f2f38ee80efc16ecbdb9feb7213c17ae2e86e
# minikube addons enable metrics-server
minikube stop
# minikube start --insecure-registry 127.0.0.1:5000
minikube start --driver=kvm2

docker wait ipa-downloader

IMAGE_NAMES=(
  quay.io/jetstack/cert-manager-controller:v1.13.0
  quay.io/jetstack/cert-manager-cainjector:v1.13.0
  quay.io/jetstack/cert-manager-webhook:v1.13.0
  quay.io/metal3-io/baremetal-operator:release-0.5 
  gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0
)

for NAME in "${IMAGE_NAMES[@]}"; do
  minikube image load ${NAME}
done

# SSH into the Minikube VM and execute the following commands
minikube ssh "sudo brctl addbr ironicendpoint"
minikube ssh "sudo ip link set ironicendpoint up"
minikube ssh "sudo brctl addif ironicendpoint eth1"

minikube ssh "sudo mkdir -p /shared/html/images"
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.kernel /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.initramfs /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.headers /shared/html/images/

read -ra PROVISIONING_IPS <<< "${IRONIC_ENDPOINTS}"
for PROVISIONING_IP in "${PROVISIONING_IPS[@]}"; do
  minikube ssh sudo  ip addr add ${PROVISIONING_IP}/24 dev ironicendpoint
done

ports=(8000 80 6385 5050 6180 53 5000 69 547 546 68 67 5353 6230)
for i in $(seq 1 "${N_SUSHY:-1}"); do
  port=$(( 8000 + i ))
  ports+=(${port})
done
for i in $(seq 1 "${N_FAKE_IPA:-1}"); do
  port=$(( 9900 + i ))
  ports+=(${port})
done

# Firewall rules
for i in "${ports[@]}"; do 
  sudo firewall-cmd --zone=public --add-port=${i}/tcp
  sudo firewall-cmd --zone=public --add-port=${i}/udp
  sudo firewall-cmd --zone=libvirt --add-port=${i}/tcp
  sudo firewall-cmd --zone=libvirt --add-port=${i}/udp
done

# Attach provisioning and baremetal network interfaces to minikube domain
virsh -c qemu:///system attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh -c qemu:///system attach-interface --domain minikube --model virtio --source baremetal --type network --config
