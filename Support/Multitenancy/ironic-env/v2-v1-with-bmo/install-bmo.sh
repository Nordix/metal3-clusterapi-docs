#!/bin/bash
set -e

kubectl create ns metal3

BMOPATH=${BMOPATH:-$HOME/baremetal-operator}

rm -rf ${BMOPATH}

git clone https://github.com/Nordix/baremetal-operator.git ${BMOPATH}

cat << EOF >"${BMOPATH}/config/default/ironic.env"
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

kustomize build ${BMOPATH}/config/tls | kubectl apply -f -

kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-controller-manager --timeout=300s
