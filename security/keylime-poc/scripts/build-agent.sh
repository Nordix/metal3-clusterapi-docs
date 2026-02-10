#!/usr/bin/env bash
set -euo pipefail

K8S_AGENTS="$1"
RUST_KEYLIME_GIT="$2"
KEYLIME_VERSION="$3"
KEYLIME_UID="${4:-490}"
KEYLIME_GID="${5:-490}"

echo "Building push model agent image..."
echo "Copying rust-keylime source to build context..."
rm -rf "${K8S_AGENTS}/agent/rust-keylime"
cp -r "${RUST_KEYLIME_GIT}" "${K8S_AGENTS}/agent/rust-keylime"

docker build -t "keylime-push-agent:${KEYLIME_VERSION}" \
    --build-arg "VERSION=${KEYLIME_VERSION}" \
    --build-arg "KEYLIME_UID=${KEYLIME_UID}" \
    --build-arg "KEYLIME_GID=${KEYLIME_GID}" \
    "${K8S_AGENTS}/agent"

rm -rf "${K8S_AGENTS}/agent/rust-keylime"
echo "Agent image built: keylime-push-agent:${KEYLIME_VERSION}"
