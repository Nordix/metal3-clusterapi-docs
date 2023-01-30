#!/usr/bin/env bash

set -eu

create_bmhs() {
  n="${1}"
  for (( i = 1; i <= n; ++i )); do
    cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: worker-$i-bmc-secret
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-$i
spec:
  online: true
  bmc:
    address: libvirt://192.168.122.$i:6233/
    credentialsName: worker-$i-bmc-secret
  bootMACAddress: "$(printf '00:60:2F:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"
EOF
  done
}

NUM="${1:-10}"

create_bmhs "${NUM}"
