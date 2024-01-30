#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
# shellcheck disable=SC1091
. ./config.sh
./vm-setup.sh
./install-tools.sh
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
./build-sushy-tools-image.sh
./generate_unique_nodes.sh
./start_containers.sh
./configure-minikube.sh
./handle-images.sh
./install-ironic.sh
./install-bmo.sh

python create_nodes.py
