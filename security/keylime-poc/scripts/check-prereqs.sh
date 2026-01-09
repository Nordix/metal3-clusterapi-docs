#!/usr/bin/env bash
set -euo pipefail

KEYLIME_GIT="${1:-}"
RUST_KEYLIME_GIT="${2:-}"

need_cmd() {
    local cmd
    cmd="$1"

    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "Missing required tool: ${cmd}" >&2
        return 1
    fi

    return 0
}

need_path() {
    local path
    path="$1"

    if [[ ! -e "${path}" ]]; then
        echo "Missing required path: ${path}" >&2
        return 1
    fi

    return 0
}

main() {
    local missing
    missing=0

    echo "Checking prerequisites..."

    for cmd in docker kind kubectl openssl skopeo git; do
        if ! need_cmd "${cmd}"; then
            missing=1
        fi
    done

    if [[ -z "${KEYLIME_GIT}" ]]; then
        echo "KEYLIME_GIT not set" >&2
        missing=1
    else
        echo "KEYLIME_GIT=${KEYLIME_GIT}"
        if ! need_path "${KEYLIME_GIT}"; then
            missing=1
        fi
        if ! need_path "${KEYLIME_GIT}/docker/release/build_locally.sh"; then
            missing=1
        fi
    fi

    if [[ -z "${RUST_KEYLIME_GIT}" ]]; then
        echo "RUST_KEYLIME_GIT not set" >&2
        missing=1
    else
        echo "RUST_KEYLIME_GIT=${RUST_KEYLIME_GIT}"
        if ! need_path "${RUST_KEYLIME_GIT}"; then
            missing=1
        fi
    fi

    if [[ "${missing}" -ne 0 ]]; then
        cat >&2 <<'EOF'

Prerequisites are missing.

- Install tools: docker, kind, kubectl, openssl, skopeo, git
- Clone Keylime repos:
  - KEYLIME_GIT (Python server components)
  - RUST_KEYLIME_GIT (Rust agent)

Tip: you can override paths like:
  KEYLIME_GIT=$HOME/git/keylime/keylime RUST_KEYLIME_GIT=$HOME/git/keylime/rust-keylime make setup
EOF
        exit 1
    fi

    echo "Prerequisites OK"
}

main "$@"
