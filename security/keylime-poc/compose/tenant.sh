#!/usr/bin/env bash
# Run docker-compose up -d first to have infra in place

set -eu

# test with args "-c add" as that triggers basically the whole keylime/tpm chain
docker exec \
    -it \
    --user root \
    compose-keylime-tenant-1 \
    keylime_tenant \
    --uuid c47b9ea2-2bc2-461b-957b-e77dbcf35e5e \
    "$@"
