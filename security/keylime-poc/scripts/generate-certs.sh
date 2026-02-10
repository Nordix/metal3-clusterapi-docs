#!/usr/bin/env bash
set -euo pipefail

# Generate TLS certificates for Keylime POC
# Creates CA, server, and client certificates in certs/ directory
# Uses keylime's expected filenames: cacert.crt, server-cert.crt, etc.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"

# Certificate validity (days)
VALIDITY=365

# Subject fields
# CA_SUBJECT="/CN=Keylime POC CA/O=Keylime POC"
SERVER_SUBJECT="/CN=keylime-server/O=Keylime POC"
CLIENT_SUBJECT="/CN=keylime-client/O=Keylime POC"

create_ca() {
    echo "Generating CA certificate..."
    openssl genrsa -out "${CERTS_DIR}/cacert.key" 4096

    cat > "${CERTS_DIR}/ca.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = Keylime POC CA
O = Keylime POC

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

    openssl req -new -x509 -days "${VALIDITY}" \
        -key "${CERTS_DIR}/cacert.key" \
        -out "${CERTS_DIR}/cacert.crt" \
        -config "${CERTS_DIR}/ca.cnf"

    rm -f "${CERTS_DIR}/ca.cnf"
}

create_server_cert() {
    echo "Generating server certificate..."

    # Create server key and CSR
    openssl genrsa -out "${CERTS_DIR}/server-private.pem" 4096
    openssl req -new \
        -key "${CERTS_DIR}/server-private.pem" \
        -out "${CERTS_DIR}/server.csr" \
        -subj "${SERVER_SUBJECT}"

    # Server cert needs SANs for all ways it can be reached
    # Detect host IP for cross-cluster communication
    if command -v hostname &>/dev/null; then
        HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    else
        HOST_IP=""
    fi

    cat > "${CERTS_DIR}/server-ext.cnf" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
nsComment = "SSL Server"
subjectKeyIdentifier = hash

[alt_names]
DNS.1 = localhost
DNS.2 = keylime-verifier
DNS.3 = keylime-registrar
DNS.4 = keylime-verifier.keylime.svc.cluster.local
DNS.5 = keylime-registrar.keylime.svc.cluster.local
DNS.6 = host.docker.internal
IP.1 = 127.0.0.1
EOF

    # Add host IP if detected
    if [[ -n "${HOST_IP}" ]]; then
        echo "IP.2 = ${HOST_IP}" >> "${CERTS_DIR}/server-ext.cnf"
        echo "Adding host IP ${HOST_IP} to server certificate SANs"
    fi

    # Add QEMU gateway IP for hwtpm VM access
    echo "IP.3 = 10.0.2.2" >> "${CERTS_DIR}/server-ext.cnf"

    # Sign server cert with CA
    openssl x509 -req -days "${VALIDITY}" \
        -in "${CERTS_DIR}/server.csr" \
        -CA "${CERTS_DIR}/cacert.crt" \
        -CAkey "${CERTS_DIR}/cacert.key" \
        -CAcreateserial \
        -out "${CERTS_DIR}/server-cert.crt" \
        -extfile "${CERTS_DIR}/server-ext.cnf"

    # Clean up CSR and ext file
    rm -f "${CERTS_DIR}/server.csr" "${CERTS_DIR}/server-ext.cnf"
}

create_client_cert() {
    echo "Generating client certificate..."

    # Create client key and CSR
    openssl genrsa -out "${CERTS_DIR}/client-private.pem" 4096
    openssl req -new \
        -key "${CERTS_DIR}/client-private.pem" \
        -out "${CERTS_DIR}/client.csr" \
        -subj "${CLIENT_SUBJECT}"

    # Client cert extension config
    cat > "${CERTS_DIR}/client-ext.cnf" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
EOF

    # Sign client cert with CA
    openssl x509 -req -days "${VALIDITY}" \
        -in "${CERTS_DIR}/client.csr" \
        -CA "${CERTS_DIR}/cacert.crt" \
        -CAkey "${CERTS_DIR}/cacert.key" \
        -CAcreateserial \
        -out "${CERTS_DIR}/client-cert.crt" \
        -extfile "${CERTS_DIR}/client-ext.cnf"

    # Clean up CSR and ext file
    rm -f "${CERTS_DIR}/client.csr" "${CERTS_DIR}/client-ext.cnf"
}

main() {
    mkdir -p "${CERTS_DIR}"

    # Check if certs already exist
    if [[ -f "${CERTS_DIR}/cacert.crt" && \
          -f "${CERTS_DIR}/server-cert.crt" && \
          -f "${CERTS_DIR}/client-cert.crt" ]]; then
        echo "Certificates already exist in ${CERTS_DIR}"
        echo "Delete certs/ directory to regenerate"
        exit 0
    fi

    echo "Generating certificates in ${CERTS_DIR}..."

    create_ca
    create_server_cert
    create_client_cert

    # Set permissions
    chmod 644 "${CERTS_DIR}"/*.crt
    chmod 600 "${CERTS_DIR}"/*.pem "${CERTS_DIR}"/*.key

    # Clean up serial file
    rm -f "${CERTS_DIR}/cacert.srl"

    echo "Certificate generation complete:"
    ls -la "${CERTS_DIR}"
}

main "$@"
