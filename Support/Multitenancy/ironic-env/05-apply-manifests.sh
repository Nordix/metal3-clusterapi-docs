set -e
WORKING_DIR="/opt/metal3-dev-env/ironic"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-webhook --timeout=300s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager-cainjector --timeout=300s
kubectl -n cert-manager wait --for=condition=available deployment/cert-manager --timeout=300s
# kubectl apply -f "$WORKING_DIR/ironic-cacert.yaml"
# Apply ironic
kubectl create ns baremetal-operator-system
kubectl apply -f manifests/ironic.yaml -n baremetal-operator-system
kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-ironic --timeout=300s

openstack_dir="${PWD}/_clouds_yaml"
ironic_client="ironicclient.sh"
ironic_port=6385

cat << EOT >"${ironic_client}"
#!/bin/bash

DIR="$(dirname "$(readlink -f "$0")")"

if [ -d $openstack_dir ]; then
  MOUNTDIR=$openstack_dir
else
  echo 'cannot find '$openstack_dir
  exit 1
fi

if [ \$1 == "baremetal" ] ; then
  shift 1
fi

# shellcheck disable=SC2086
sudo podman run --net=host --tls-verify=false \
  -v "${openstack_dir}:/etc/openstack" --rm \
  -e OS_CLOUD="${OS_CLOUD:-metal3}" "172.22.0.1:5000/localimages/ironic-client" "\$@"
EOT

rm -rf "${openstack_dir}"
mkdir -p "${openstack_dir}"

cp /opt/metal3-dev-env/ironic/certs/ironic-ca.pem "${openstack_dir}/ironic-ca.crt"

cat << EOT >"${openstack_dir}/clouds.yaml"
clouds:
  metal3:
    auth_type: none
    # cacert: /etc/openstack/ironic-ca.crt
    baremetal_endpoint_override: https://172.22.0.2:${ironic_port}
    baremetal_introspection_endpoint_override: https://172.22.0.2:5050
    verify: false
EOT
sudo chmod a+x "${ironic_client}"
sudo ln -sf "$PWD/${ironic_client}" "/usr/local/bin/baremetal"
