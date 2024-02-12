#!/usr/bin/env bash

set -eu

create_bmhs() {
  n="${1}"
  for i in $(seq 1 10); do
    port=$(( 8000 + i ))
    uuid=$(uuidgen)
    cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: worker-$i-bmc-secret
  labels:
      environment.metal3.io: baremetal
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-$i
  uid: ${uuid}
spec:
  online: true
  bmc:
    address: redfish+http://192.168.111.1:${port}/redfish/v1/Systems/${uuid}
    credentialsName: worker-$i-bmc-secret
  bootMACAddress: "$(printf '00:60:2F:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
EOF
  done
}

NUM="${1:-10}"

create_bmhs "${NUM}"
