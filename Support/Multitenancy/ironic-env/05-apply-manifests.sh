set -e
# Apply ironic
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

  mkdir -p "${openstack_dir}"

  cat << EOT >"${openstack_dir}/clouds.yaml"
clouds:
  metal3:
    auth_type: none
    baremetal_endpoint_override: http://172.22.0.2:${ironic_port}
    baremetal_introspection_endpoint_override: http://172.22.0.2:5050
EOT
sudo chmod a+x "${ironic_client}"
sudo ln -sf "$PWD/${ironic_client}" "/usr/local/bin/baremetal"
