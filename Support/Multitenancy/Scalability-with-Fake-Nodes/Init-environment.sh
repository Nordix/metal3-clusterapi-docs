#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
# shellcheck disable=SC1091
. ./config.sh
__dir__=$(realpath "$(dirname "$0")")
./start_image_server.sh
./minikube-setup.sh
./run-ipa-downloader.sh
./handle-images.sh
./install-fkas.sh
./install-ironic.sh
./install-bmo.sh
./generate_unique_nodes.sh
./create-bmhs.sh
./start_containers.sh
./apply-bmhs.sh

./clusterctl-init.sh

./create-clusters.sh
