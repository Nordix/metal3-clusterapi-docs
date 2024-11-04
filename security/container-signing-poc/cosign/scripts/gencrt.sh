#!/usr/bin/env bash
# create certificates in the examples dir

# Create directories
OUTPUT_DIR=examples
mkdir -p "${OUTPUT_DIR}"

# Generate Root CA key - we can use whatever, only signature algos matter
# in our use-case
# openssl genrsa -out "${OUTPUT_DIR}"/ca.key 4096
openssl ecparam -name secp384r1 -genkey -noout -out "${OUTPUT_DIR}"/ca.key

# Create Root CA config
cat > "${OUTPUT_DIR}"/ca.conf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign,digitalSignature
subjectKeyIdentifier = hash
EOF

# Generate Root CA certificate
openssl req -new -x509 -days 365 -key "${OUTPUT_DIR}"/ca.key \
    -config "${OUTPUT_DIR}"/ca.conf \
    -out "${OUTPUT_DIR}"/ca.crt

# Generate leaf key
openssl genrsa -out "${OUTPUT_DIR}"/leaf.key 4096

# Create leaf config
cat > "${OUTPUT_DIR}"/leaf.conf << EOF
[req]
distinguished_name = req_distinguished_name
prompt = no
req_extensions = v3_req

[req_distinguished_name]
CN = signer@example.com

[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning,clientAuth
subjectKeyIdentifier = hash
subjectAltName = @alt_names
1.3.6.1.4.1.57264.1.8 = ASN1:UTF8String:https://signing.example.com

[alt_names]
email.0 = signer@example.com
EOF

# Create signing config (separate from CSR config)
cat > "${OUTPUT_DIR}"/signing.conf << EOF
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning,clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName = @alt_names
1.3.6.1.4.1.57264.1.8 = ASN1:UTF8String:https://signing.example.com

[alt_names]
email.0 = signer@example.com
EOF

# Generate leaf CSR
openssl req -new -key "${OUTPUT_DIR}"/leaf.key \
    -config "${OUTPUT_DIR}"/leaf.conf \
    -out "${OUTPUT_DIR}"/leaf.csr

# Sign leaf certificate using the signing config
openssl x509 -req -days 365 \
    -in "${OUTPUT_DIR}"/leaf.csr \
    -CA "${OUTPUT_DIR}"/ca.crt \
    -CAkey "${OUTPUT_DIR}"/ca.key \
    -CAcreateserial \
    -extfile "${OUTPUT_DIR}"/signing.conf \
    -out "${OUTPUT_DIR}"/leaf.crt

# Create certificate chain
cat "${OUTPUT_DIR}"/leaf.crt "${OUTPUT_DIR}"/ca.crt > "${OUTPUT_DIR}"/certificate_chain.pem
