set -e
# Apply ironic
kubectl apply -f manifests/ironic.yaml -n baremetal-operator-system
kubectl -n baremetal-operator-system wait --for=condition=available deployment/baremetal-operator-ironic --timeout=300s
cat <<'EOF' >ironicclient.sh
#!/bin/bash

DIR="$(dirname "$(readlink -f "$0")")"

if [ -d "${PWD}/_clouds_yaml" ]; then
  MOUNTDIR="${PWD}/_clouds_yaml"
else
  echo "cannot find _clouds_yaml"
  exit 1
fi

if [ "$1" == "baremetal" ] ; then
  shift 1
fi

# shellcheck disable=SC2086
sudo podman run --net=host --tls-verify=false \
  -v "${MOUNTDIR}:/etc/openstack" --rm \
  -e OS_CLOUD="${OS_CLOUD:-metal3}" "172.22.0.1:5000/localimages/ironic-client" "$@"
EOF

mkdir _clouds_yaml

cat <<'EOF' >_clouds_yaml/clouds.yaml
clouds:
  metal3:
    auth_type: none
    baremetal_endpoint_override: http://172.22.0.2:6385
    baremetal_introspection_endpoint_override: http://172.22.0.2:5050
EOF
sudo chmod a+x ironicclient.sh
sudo ln -sf "$PWD/ironicclient.sh" "/usr/local/bin/baremetal"

# Create ironic node

mkdir /opt/metal3-dev-env/ironic/html/images || true
touch /opt/metal3-dev-env/ironic/html/images/image.qcow2

baremetal node create --driver redfish --driver-info \
  redfish_address=http://192.168.111.1:8000 --driver-info \
  redfish_system_id=/redfish/v1/Systems/27946b59-9e44-4fa7-8e91-f3527a1ef094 --driver-info \
  redfish_username=admin --driver-info redfish_password=password \
  --name default-node-1

baremetal node set default-node-1    --driver-info deploy_kernel="http://172.22.0.2:6180/images/ironic-python-agent.kernel"     --driver-info deploy_ramdisk="http://172.22.0.2:6180/images/ironic-python-agent.initramfs"
baremetal node set default-node-1       --instance-info image_source=http://172.22.0.1/images/image.qcow2     --instance-info image_checksum=http://172.22.0.1/images/image.qcow2

baremetal node create --driver redfish --driver-info \
redfish_address=http://192.168.111.1:8000 --driver-info \
redfish_system_id=/redfish/v1/Systems/27946b59-9e44-4fa7-8e91-f3527a1ef095 --driver-info \
redfish_username=admin --driver-info redfish_password=password \
--name default-node-2

baremetal node set default-node-2    --driver-info deploy_kernel="http://172.22.0.2:6180/images/ironic-python-agent.kernel"     --driver-info deploy_ramdisk="http://172.22.0.2:6180/images/ironic-python-agent.initramfs"
baremetal node set default-node-2       --instance-info image_source=http://172.22.0.1/images/image.qcow2     --instance-info image_checksum=http://172.22.0.1/images/image.qcow2