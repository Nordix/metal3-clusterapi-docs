#!/usr/bin/env bash

set -eu

# Get he IP address of minikube in the default network
# This is the IP address of the interface of the default network (where the BMHs are).
MINIKUBE_ETH1_IP="$(minikube ssh -- ip -f inet addr show eth1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')"
# IP of the host from minikube perspective (where we can reach libvirt)
LIBVIRT_IP="$(virsh net-dumpxml mk-minikube | sed -En "s/.*ip address='([0-9.]+)'.*/\1/p")"

# Create BMH backed by libvirt VM
create_bmh() {
  name="${1:-host-0}"
  vbmc_port="${2:-16230}"
  static_ip="${3:-}"
  # Generate MAC
  mac_address="$(printf '00:60:2F:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
  # TODO: Improve this so we can create multiple hosts with reserved IP
  # Reserve IP address for host-0
  if [ "${static_ip}" != "" ]; then
    virsh net-update default add ip-dhcp-host \
          "<host mac=\"${mac_address}\" ip=\"${static_ip}\" />" \
           --live --config
  fi

  # Create libvirt domain
  virt-install -n "${name}" --description "Virtualized BareMetalHost" --osinfo=ubuntu-lts-latest \
    --ram=4096 --vcpus=2 --disk size=20 --graphics=none --console pty --serial pty --pxe \
    --network network=default,mac="${mac_address}" --noautoconsole

  # Add BMH VM to VBMC
  kubectl -n vbmc exec deploy/vbmc -- vbmc add "${name}" --port "${vbmc_port}" \
    --libvirt-uri "qemu+ssh://${USER}@${LIBVIRT_IP}/system?keyfile=/home/docker/.ssh/id_ed25519&no_verify=1&no_tty=1"
  kubectl -n vbmc exec deploy/vbmc -- vbmc start "${name}"
  kubectl -n vbmc exec deploy/vbmc -- vbmc list

  sed -e "s/VBMC_IP/${MINIKUBE_ETH1_IP}/g" -e "s/MAC_ADDRESS/${mac_address}/g" -e "s/NAME/${name}/g" \
    -e "s/VBMC_PORT/${vbmc_port}/g" bmh.yaml | kubectl apply -f -
}

create_bmh "${1:-}" "${2:-}" "${3:-}"
