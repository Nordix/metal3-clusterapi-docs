#!/bin/bash
set -e

cat <<EOF >"bmo-config/ironic.env"
HTTP_PORT=6180
PROVISIONING_INTERFACE=ironicendpoint
DHCP_RANGE=192.168.222.100,192.168.222.200
DEPLOY_KERNEL_URL=http://192.168.222.100:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.222.100:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://192.168.222.100:6385/v1/
IRONIC_INSPECTOR_ENDPOINT=https://192.168.222.100:5050/v1/
CACHEURL=http://192.168.222.100/images
IRONIC_FAST_TRACK=true
EOF

kubectl apply -k bmo-config

kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-controller-manager --timeout=300s
