#!/bin/bash
set -e

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=300s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=300s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=300s

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t ed25519
fi
# Install ironic
# read -ra PROVISIONING_IPS <<< "${IRONIC_ENDPOINTS}"
# helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" --set ironicReplicas="{$(echo "$IRONIC_ENDPOINTS" | sed 's/ /\,/g')}" --wait
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" --set ironicReplicas="{${IRONIC_ENDPOINTS/ /\,}}" --wait

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

ironic_client="ironicclient.sh"
openstack_dir="${PWD}/_clouds_yaml"
rm -rf "${openstack_dir}"
mkdir -p "${openstack_dir}"
cp /opt/metal3-dev-env/ironic/certs/ironic-ca.pem "${openstack_dir}/ironic-ca.crt"
cat << EOT >"${openstack_dir}/clouds.yaml"
clouds:
  metal3:
    auth_type: none
    baremetal_endpoint_override: https://172.22.0.2:6385
    baremetal_introspection_endpoint_override: https://172.22.0.2:5050
    verify: false
EOT

sudo podman run --net=host --tls-verify=false \
  --name openstack-client \
  --detach \
  --entrypoint='["/bin/sleep", "inf"]' \
  -v "${openstack_dir}:/etc/openstack" \
  -e OS_CLOUD="${OS_CLOUD:-metal3}" \
  "172.22.0.1:5000/localimages/ironic-client"


cat << EOT >"${ironic_client}"
#!/bin/bash

DIR="$(dirname "$(readlink -f "$0")")"

if [ -d $openstack_dir ]; then
  MOUNTDIR=$openstack_dir
else
  echo 'cannot find $openstack_dir'
  exit 1
fi

if [ \$1 == "baremetal" ] ; then
  shift 1
fi

# shellcheck disable=SC2086
sudo podman exec openstack-client /usr/bin/baremetal "\$@"
EOT

sudo chmod a+x "${ironic_client}"
sudo ln -sf "$PWD/${ironic_client}" "/usr/local/bin/baremetal"
