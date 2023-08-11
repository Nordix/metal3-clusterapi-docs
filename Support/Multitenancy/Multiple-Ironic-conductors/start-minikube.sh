#!/bin/bash
set -e

# Start Minikube with insecure registry flag
minikube start --insecure-registry 172.22.0.1:5000 --memory 50000 --cpus 20

# SSH into the Minikube VM and execute the following commands
sudo su -l -c "minikube ssh sudo brctl addbr ironicendpoint" "${USER}"
sudo su -l -c "minikube ssh sudo  ip link set ironicendpoint up" "${USER}"
sudo su -l -c "minikube ssh sudo  brctl addif  ironicendpoint eth2" "${USER}"

IRONIC_DATA_DIR="/opt/metal3-dev-env/ironic/"

minikube ssh "sudo mkdir -p /shared/html/images"
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.kernel /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.initramfs /shared/html/images/
minikube cp ${IRONIC_DATA_DIR}/html/images/ironic-python-agent.headers /shared/html/images/

read -ra PROVISIONING_IPS <<< "${IRONIC_ENDPOINTS}"
for PROVISIONING_IP in "${PROVISIONING_IPS[@]}"; do
  sudo su -l -c "minikube ssh sudo  ip addr add ${PROVISIONING_IP}/24 dev ironicendpoint" "${USER}"
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
