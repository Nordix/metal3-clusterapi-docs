#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
# shellcheck disable=SC1091
. ./config.sh
# This is temporarily required since https://review.opendev.org/c/openstack/sushy-tools/+/875366 has not been merged.
./build-sushy-tools-image.sh
sudo ./vm-setup.sh
./configure-minikube.sh
sudo ./handle-images.sh
./generate_unique_nodes.sh
./start_containers.sh
./start-minikube.sh
./install-ironic.sh
./install-bmo.sh
python create_nodes.py
