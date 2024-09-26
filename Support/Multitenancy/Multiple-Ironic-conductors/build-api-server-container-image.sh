#!/bin/bash
#
__dir__=$(realpath $(dirname $0))
IMAGE_NAME="quay.io/metal3-io/api-server:amd64"

if [[ ${1:-""} == "-f" ]]; then
    docker rmi "${IMAGE_NAME}"
    # kubectl delete -f capim-modified.yaml || true
fi

if [[ $(docker images | grep ${IMAGE_NAME}) != "" ]]; then
    docker image save -o /tmp/api-server.tar "${IMAGE_NAME}"
    minikube image load /tmp/api-server.tar
    exit 0
fi

CAPM3_DIR="/tmp/cluster-api-provider-metal3"

if [[ ! -d "${CAPM3_DIR}" ]]; then
    git clone -b mquhuy/test --single-branch https://github.com/Nordix/cluster-api-provider-metal3.git "${CAPM3_DIR}"
fi

pushd "${CAPM3_DIR}"

make build-fake-api-server

docker image save -o /tmp/api-server.tar "${IMAGE_NAME}"
minikube image load /tmp/api-server.tar

rm -f /tmp/api-server.tar

popd
