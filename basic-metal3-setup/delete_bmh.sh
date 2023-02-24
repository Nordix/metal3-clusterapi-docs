#!/usr/bin/env bash

set -u

delete_bmh() {
  name="${1:-host-0}"
  # We do not care about deprovisioning here since we will anyway delete the VM.
  # So to speed things up, we detach it before deleting.
  kubectl annotate bmh "${name}" baremetalhost.metal3.io/detached=""
  kubectl delete bmh "${name}"
  kubectl -n vbmc exec deploy/vbmc -- vbmc delete "${name}"
  # Check MAC. If it matches with what is in net-dumpxml, remove that line from the network.
  bmh_mac="$(virsh dumpxml --domain "${name}" | sed -En "s/.*mac address='([0-9A-Fa-f:]+)'.*/\1/p" | tr '[:lower:]' '[:upper:]')"
  net_reserved_mac="$(virsh net-dumpxml default | sed -En "s/.*host mac='([0-9A-Fa-f:]+)'.*/\1/p" | tr '[:lower:]' '[:upper:]')"
  if [ "${bmh_mac}" = "${net_reserved_mac}" ]; then
    static_ip="$(virsh net-dumpxml default | sed -En "s/.*ip='([0-9.]+)'.*/\1/p")"
    virsh net-update default delete ip-dhcp-host \
          "<host mac=\"${bmh_mac}\" ip=\"${static_ip}\" />" \
           --live --config
  fi
  virsh destroy --domain "${name}"
  virsh undefine --domain "${name}" --remove-all-storage
}

delete_bmh "${1}"
