#!/bin/bash
#
IMAGE_NAME="127.0.0.1:5000/localimages/sushy-tools"
if [[ ${1:-""} == "-f" ]]; then
    podman rmi "${IMAGE_NAME}"
fi

if [[ $(podman images | grep ${IMAGE_NAME}) != "" ]]; then
    podman push --tls-verify=false "${IMAGE_NAME}"
    exit 0
fi
SUSHYTOOLS_DIR="/tmp/sushy-tools"
rm -rf "$SUSHYTOOLS_DIR"
git clone https://opendev.org/openstack/sushy-tools.git "$SUSHYTOOLS_DIR"
cd "$SUSHYTOOLS_DIR" || exit
git fetch https://review.opendev.org/openstack/sushy-tools refs/changes/66/875366/39 && git cherry-pick FETCH_HEAD

pip3 install build
python3 -m build

cd dist || exit
WHEEL_FILENAME=$(ls ./*.whl)
echo "$WHEEL_FILENAME"

cd ..

cat <<EOF > "${SUSHYTOOLS_DIR}/Dockerfile"
# Use the official Centos image as the base image
FROM ubuntu:22.04

# Install necessary packages
RUN apt update -y && \
    apt install -y python3 python3-pip python3-venv && \
    apt clean all

WORKDIR /opt

# RUN python3 setup.py install

# Copy the application code to the container
COPY dist/${WHEEL_FILENAME} .

RUN pip3 install ${WHEEL_FILENAME}

ENV FLASK_DEBUG=1

RUN mkdir -p /root/sushy

# Set the default command to run when starting the container
CMD ["sushy-emulator", "-i", "::", "--config", "/root/sushy/conf.py"]
EOF
podman push --tls-verify=false

podman build -t "${IMAGE_NAME}" .
podman push --tls-verify=false "${IMAGE_NAME}"
