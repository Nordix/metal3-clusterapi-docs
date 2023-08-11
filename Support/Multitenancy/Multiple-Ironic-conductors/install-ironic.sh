#!/bin/bash
set -e

. ./config.sh

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=500s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=500s

if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
  ssh-keygen -t ed25519
fi

# Install ironic
helm install ironic ironic --set sshKey="$(cat ~/.ssh/id_rsa.pub)" --set ironicReplicas="{${IRONIC_ENDPOINTS// /\,}}" --wait --timeout 20m

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
