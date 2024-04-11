#!/usr/bin/env bash

# This is example of custom script reading signature from a file.
#
# INPUT is coming to stdin, and is the payload in correct format.
# OUTPUT needs to be raw signature.
#
# Any errors/logging go to stderr, and will be ignored by the calling plugin,
# so the payload.txt will be written into a file in case "payload.sig" does
# not exist. This way the payload is available for any manual handling/signing.
#
# NOTE: the signer must wait in the same request for the payload.sig to appear
# If signer is rerun, the metadata will change, and the signature will not be
# valid. Increase sleep timeout, make it intelligent, or whatever suits you.

set -eu

# we actually can ignore the input unless we want to decode the payload
# and read different signature per input
INPUT=$(cat -)
PAYLOAD="payload.txt"
OUTPUT="payload.sig"

# if signature is not found, write payload to file, wait 60s for payload.sig
# to appear, and then read it
if ! cat "${OUTPUT}"; then
    echo -n "${INPUT}" > "${PAYLOAD}"
    sleep 60
    cat "${OUTPUT}"
fi
