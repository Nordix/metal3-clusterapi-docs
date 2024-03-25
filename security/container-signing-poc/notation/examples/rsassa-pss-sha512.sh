#!/usr/bin/env bash

# This is example of custom script doing rsassa-pss-sha512 signing.
# This would be pretty much the same as importing the key into Notation
# and let Notation do the signing for you.
#
# INPUT is coming to stdin, and is the payload in correct format.
#   OpenSSL reads stdin by default.
# OUTPUT needs to be raw signature.
#   OpenSSL writes to stdout by default.
# EXTERNAL_PRIVATE_KEY needs to point to file where the signing key is.

set -eu

openssl dgst -sha512 -sign "${EXTERNAL_PRIVATE_KEY}" \
    -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:32
