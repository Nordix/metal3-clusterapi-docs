#!/usr/bin/env bash

set -eux

KEYLIME=/var/lib/keylime
TPMDIR=/tmp/tpmdir

# configure swtpm2 and start it
mkdir -p "${TPMDIR}"
chown tss:tss "${TPMDIR}"
chmod 750 "${TPMDIR}"

swtpm_setup --tpm2 \
    --tpmstate "${TPMDIR}" \
    --createek --decryption --create-ek-cert \
    --create-platform-cert \
    --display || true
swtpm socket --tpm2 \
    --tpmstate dir="${TPMDIR}" \
    --flags startup-clear \
    --ctrl type=tcp,port=2322 \
    --server type=tcp,port=2321 \
    --daemon
sleep 2

# configure dbus for abmrd
sudo rm -rf /var/run/dbus
sudo mkdir /var/run/dbus
sudo dbus-daemon --system

# run abmrd
tpm2-abrmd \
    --logger=stdout \
    --tcti=swtpm: \
    --allow-root \
    --flush-all \
    &
sleep 2

# prep image for running agent as non-root
useradd -s /sbin/nologin -g tss keylime || true

chown keylime:tss "${KEYLIME}" "${KEYLIME}"/secure
chmod 770 "${KEYLIME}" "${KEYLIME}"/secure
cp "${KEYLIME}"/cv_ca/cacert.crt "${KEYLIME}"/secure/
chown keylime:tss "${KEYLIME}"/secure/cacert.crt

# make swtpm CA accessible to tenant to validate EK cert
# and verify it to be sure we have it right to avoid issues down the road
cat /var/lib/swtpm-localca/{issuercert,swtpm-localca-rootca-cert}.pem > "${KEYLIME}"/tpm_cert_store/swtpm_localca.pem
tpm2_getekcertificate > "${KEYLIME}"/ek.bin
openssl x509 -inform DER -in "${KEYLIME}"/ek.bin -out "${KEYLIME}"/ek.pem
openssl verify -CAfile "${KEYLIME}"/tpm_cert_store/swtpm_localca.pem "${KEYLIME}"/ek.pem
sleep 2

# run agent
keylime_agent
