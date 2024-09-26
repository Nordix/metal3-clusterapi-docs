#!/bin/bash
#
exit 0
REGISTRY_NAME="registry"
REGISTRY_PORT="5000"
# Start docker registry if it's not already running
IMAGE_NAME="127.0.0.1:5000/localimages/sushy-tools"
SUSHYTOOLS_DIR="/tmp/sushy-tools"
if [[ ${1:-""} == "-f" ]]; then
  rm -rf "${SUSHYTOOLS_DIR}"
  docker rmi "${IMAGE_NAME}"
fi

if [[ $(docker images | grep ${IMAGE_NAME}) != "" ]]; then
  exit 0
fi
if [[ ! -d "${SUSHYTOOLS_DIR}" ]]; then
  git clone https://opendev.org/openstack/sushy-tools.git "$SUSHYTOOLS_DIR"
  cd "$SUSHYTOOLS_DIR" || exit
fi
cd "$SUSHYTOOLS_DIR" || exit

pip3 install build
python3 -m build

cd dist || exit
WHEEL_FILENAME=$(ls *.whl)
echo "$WHEEL_FILENAME"

cd ..

cat <<EOF >"${SUSHYTOOLS_DIR}/Dockerfile"
# Use the official ubuntu image as the base image
FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update -y && \
    apt-get install -y python3 python3-pip python3-venv && \
    apt-get clean all

WORKDIR /opt

# RUN python3 setup.py install

# Copy the application code to the container
COPY "dist/${WHEEL_FILENAME}" .

RUN pip3 install ${WHEEL_FILENAME}

ENV FLASK_DEBUG=1

RUN mkdir -p /root/sushy

# Set the default command to run when starting the container
CMD ["sushy-emulator", "-i", "::", "--config", "/root/sushy/conf.py"]
EOF

docker build -t "${IMAGE_NAME}" .
