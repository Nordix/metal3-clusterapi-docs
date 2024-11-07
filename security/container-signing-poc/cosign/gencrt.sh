#!/usr/bin/env bash
# create certificates in the examples dir

set -eu

# Create directories
OUTPUT_DIR=examples
mkdir -p "${OUTPUT_DIR}"

# Setup CA files
touch "${OUTPUT_DIR}"/index
echo 1000 > "${OUTPUT_DIR}"/serial
echo 1000 > "${OUTPUT_DIR}"/subca-serial

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
CN = root@example.com

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign,digitalSignature
subjectKeyIdentifier = hash

[ca]
default_ca = CA_default

[CA_default]
database = examples/index
serial = examples/serial
private_key = examples/ca.key
certificate = examples/ca.crt
new_certs_dir = examples
default_days = 3650
default_md = sha256
policy = policy_match

[policy_match]
commonName = supplied
EOF

# Generate Root CA certificate
openssl req -new -x509 -days 365 -key "${OUTPUT_DIR}"/ca.key \
    -config "${OUTPUT_DIR}"/ca.conf \
    -out "${OUTPUT_DIR}"/ca.crt

# Sub CA config
cat > "${OUTPUT_DIR}"/sub-ca.conf << EOL
[req]
distinguished_name = req_dn
x509_extensions = v3_ca
prompt = no

[req_dn]
CN = sub@example.com

[v3_ca]
basicConstraints = critical,CA:true,pathlen:0
keyUsage = critical,keyCertSign,cRLSign

[ca]
default_ca = CA_default

[CA_default]
database = examples/index
serial = examples/subca-serial
private_key = examples/sub-ca.key
certificate = examples/sub-ca.crt
new_certs_dir = examples
default_days = 1875
default_md = sha256
policy = policy_match

[policy_match]
commonName = supplied
EOL

# Generate Sub CA
openssl genrsa -out "${OUTPUT_DIR}"/sub-ca.key 4096
openssl req -new -config "${OUTPUT_DIR}"/sub-ca.conf \
    -key "${OUTPUT_DIR}"/sub-ca.key \
    -out "${OUTPUT_DIR}"/sub-ca.csr
openssl ca -batch -config "${OUTPUT_DIR}"/ca.conf \
    -in "${OUTPUT_DIR}"/sub-ca.csr \
    -out "${OUTPUT_DIR}"/sub-ca.crt \
    -extensions v3_ca

# Create leaf config
cat > "${OUTPUT_DIR}"/leaf.conf << EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = signing@example.com
EOF

# Create signing config (separate from CSR config)
cat > "${OUTPUT_DIR}"/signing.conf << EOF
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning,clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName = @alt_names

[alt_names]
URI.0 = https://signing.example.com
EOF

# Generate leaf key - whatever is fine
# openssl genrsa -out "${OUTPUT_DIR}"/leaf.key 4096
openssl ecparam -name secp384r1 -genkey -noout -out "${OUTPUT_DIR}"/leaf.key

# Generate leaf CSR
openssl req -new -key "${OUTPUT_DIR}"/leaf.key \
    -config "${OUTPUT_DIR}"/leaf.conf \
    -out "${OUTPUT_DIR}"/leaf.csr

# Sign leaf certificate using the signing config
openssl x509 -req -days 365 \
    -in "${OUTPUT_DIR}"/leaf.csr \
    -CA "${OUTPUT_DIR}"/sub-ca.crt \
    -CAkey "${OUTPUT_DIR}"/sub-ca.key \
    -CAcreateserial \
    -extfile "${OUTPUT_DIR}"/signing.conf \
    -out "${OUTPUT_DIR}"/leaf.crt

# Create certificate chain
cat "${OUTPUT_DIR}"/sub-ca.crt "${OUTPUT_DIR}"/ca.crt > "${OUTPUT_DIR}"/certificate_chain.pem
