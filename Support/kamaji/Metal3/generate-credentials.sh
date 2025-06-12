#!/usr/bin/env bash

set -eux

IRONIC_USERNAME="$(uuidgen)"
IRONIC_PASSWORD="$(uuidgen)"
echo "${IRONIC_USERNAME}" > Metal3/bmo-bootstrap/ironic-username
echo "${IRONIC_PASSWORD}" > Metal3/bmo-bootstrap/ironic-password
echo "IRONIC_HTPASSWD=$(htpasswd -n -b -B "${IRONIC_USERNAME}" "${IRONIC_PASSWORD}")" > Metal3/ironic-bootstrap/ironic-htpasswd
