
# Image server variables
IMAGE_DIR="${REPO_ROOT}/Metal3/images"

touch "${IMAGE_DIR}/rhcos-oota-latest.qcow2"

## Run the image server
mkdir -p "${IMAGE_DIR}"
docker run --name image-server -d \
  -p 80:8080 \
  -v "${IMAGE_DIR}:/usr/share/nginx/html" nginxinc/nginx-unprivileged

