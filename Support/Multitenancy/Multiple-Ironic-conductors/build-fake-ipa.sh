#!/bin/bash
#
# Start docker registry if it's not already running
#
exit 0
docker rmi "${IMAGE_NAME}"
IMAGE_NAME="127.0.0.1:5000/localimages/fake-ipa"
if [[ ${1:-""} == "-f" ]]; then
    # rm -rf "${FAKEIPA_DIR}"
    docker rmi "${IMAGE_NAME}"
fi

if [[ $(docker images | grep ${IMAGE_NAME}) != "" ]]; then
    exit 0
fi
FAKEIPA_DIR="/tmp/fake-ipa"
# rm -rf "$FAKEIPA_DIR"
if [[ ! -d "${FAKEIPA_DIR}" ]]; then
    git clone https://github.com/metal3-io/utility-images.git "$FAKEIPA_DIR"
    pushd "$FAKEIPA_DIR"
    gh pr checkout 14
    popd
fi
pushd "$FAKEIPA_DIR"

cd fake-ipa || exit
#
docker build -t "${IMAGE_NAME}" .
popd
