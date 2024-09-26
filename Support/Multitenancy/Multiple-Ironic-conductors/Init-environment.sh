#!/bin/bash
set -e
trap 'trap - SIGTERM && kill -- -'$$'' SIGINT SIGTERM EXIT
__dir__=$(realpath "$(dirname "$0")")
. ./config.sh
./start_image_server.sh
./minikube-setup.sh
./run-ipa-downloader.sh
./handle-images.sh
./install-fkas.sh
./install-ironic.sh
./install-bmo.sh
./generate_unique_nodes.sh
python create-bmhs.py
./start_containers.sh
./apply-bmhs.sh

./clusterctl-init.sh

./create-clusters.sh
