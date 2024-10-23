#!/bin/bash
set -ex
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
# shellcheck disable=SC1091
. ./config.sh
./vm-setup.sh
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
./build-sushy-tools-image.sh
./generate_unique_nodes.sh
./start_containers.sh
./handle-images.sh
./configure-minikube.sh
./install-ironic.sh
python create_and_inspect_nodes.py
