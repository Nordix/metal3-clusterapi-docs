#!/usr/bin/env bash

set -eux

# Stop if image-server already exists
docker rm -f image-server 2>/dev/null

__dir__=$(realpath "$(dirname "$0")")
IRONIC_DATA_DIR="${__dir__}/Metal3/ironic"
IMAGE_DIR="${IRONIC_DATA_DIR}/html/images"
mkdir -p "${IMAGE_DIR}"

## Run the image server
docker run --name image-server -d \
  -p 8080:8080 \
  -v "${IMAGE_DIR}:/usr/share/nginx/html/images" nginxinc/nginx-unprivileged
