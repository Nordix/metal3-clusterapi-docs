set -e
trap "trap - SIGTERM && kill -- -'$$'" SIGINT SIGTERM EXIT
__dir__=$(realpath $(dirname $0))
source "$__dir__/config.sh"
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
./build-sushy-tools-image.sh
sudo ./01-vm-setup.sh
./02-configure-minikube.sh
sudo ./03-images-and-run-local-services.sh "$N_NODES"
./04-start-minikube.sh "${IRONIC_ENDPOINTS}"
./05-apply-manifests.sh "${IRONIC_ENDPOINTS}"
# ./06-create-nodes.sh 0 "$NODE_CREATE_BATCH_SIZE" "$NODE_INSPECT_BATCH_SIZE"
python create_nodes.py
cp nodes.json batch.json
./07-inspect-nodes.sh "${NODE_INSPECT_BATCH_SIZE}"
