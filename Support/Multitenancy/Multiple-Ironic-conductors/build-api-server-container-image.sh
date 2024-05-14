#!/bin/bash
#
__dir__=$(realpath $(dirname $0))
IMAGE_NAME="quay.io/metal3-io/api-server:latest"

if [[ ${1:-""} == "-f" ]]; then
    docker rmi "${IMAGE_NAME}"
    # kubectl delete -f capim-modified.yaml || true
fi

if [[ $(docker images | grep ${IMAGE_NAME}) != "" ]]; then
    # docker push "${IMAGE_NAME}"
    minikube image load "${IMAGE_NAME}"
    exit 0
fi
CAPM3_DIR="/tmp/cluster-api-provider-metal3"
if [[ ! -d "${CAPM3_DIR}" ]]; then
    git clone https://github.com/metal3-io/cluster-api-provider-metal3.git "${CAPM3_DIR}"
    cd "${CAPM3_DIR}" || exit
    gh pr checkout 1610
fi

cd "${CAPM3_DIR}" || exit

FAKEAPI_DIR="${CAPM3_DIR}/hack/fake-apiserver"

# cp "${__dir__}/main.go" "${INMEMORY_DIR}/main.go"

cd "${FAKEAPI_DIR}" || exit

# docker build --build-arg=builder_image=docker.io/library/golang:1.20.8 --build-arg=goproxy=https://proxy.golang.org,direct --build-arg=ARCH=amd64 --build-arg=ldflags="-X 'sigs.k8s.io/cluster-api/version.buildDate=2023-10-10T11:47:30Z'  -X 'sigs.k8s.io/cluster-api/version.gitCommit=8ba3f47b053da8bbf63cf407c930a2ee10bfd754' -X 'sigs.k8s.io/cluster-api/version.gitTreeState=dirty' -X 'sigs.k8s.io/cluster-api/version.gitMajor=1' -X 'sigs.k8s.io/cluster-api/version.gitMinor=0' -X 'sigs.k8s.io/cluster-api/version.gitVersion=v1.0.0-4041-8ba3f47b053da8-dirty' -X 'sigs.k8s.io/cluster-api/version.gitReleaseCommit=e09ed61cc9ba8bd37b0760291c833b4da744a985'" ../../.. -t "${IMAGE_NAME}" --file Dockerfile

docker build . -t "${IMAGE_NAME}"

docker image save -o /tmp/api-server.tar "${IMAGE_NAME}"
minikube image load /tmp/api-server.tar

rm -f /tmp/api-server.tar

# docker push "${IMAGE_NAME}"
# minikube image load "${IMAGE_NAME}"
