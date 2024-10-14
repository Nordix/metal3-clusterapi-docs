ironic_client="ironicclient.sh"
openstack_dir="${PWD}/_clouds_yaml"
rm -rf "${openstack_dir}"
mkdir -p "${openstack_dir}"
__dir__=$(realpath "$(dirname "$0")")
cp ${__dir__}/opt/metal3-dev-env/ironic/certs/ironic-ca.pem "${openstack_dir}/ironic-ca.crt"
cat << EOT >"${openstack_dir}/clouds.yaml"
clouds:
  metal3:
    auth_type: none
    baremetal_endpoint_override: https://172.22.0.2:6385
    baremetal_introspection_endpoint_override: https://172.22.0.2:5050
    verify: false
EOT

docker run --net=host \
  --name openstack-client \
  --detach \
  --entrypoint=/bin/sleep \
  -v "${openstack_dir}:/etc/openstack" \
  -e OS_CLOUD="${OS_CLOUD:-metal3}" \
  "172.22.0.1:5000/localimages/ironic-client" \
  "inf"


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
docker exec openstack-client /usr/bin/baremetal "\$@"
EOT

sudo chmod a+x "${ironic_client}"
sudo ln -sf "$PWD/${ironic_client}" "/usr/local/bin/baremetal"
