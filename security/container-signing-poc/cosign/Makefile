# cosign signing test

TEST_REGISTRY := 127.0.0.1:5003
TEST_REGISTRY_NAME := cosign-registry
TEST_REGISTRY_IMAGE := registry:2
TEST_IMAGE := alpine
TEST_IMAGE_TAG := 3.20.3
TEST_DIGEST := sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d
TEST_IMAGE_LOCAL := $(TEST_REGISTRY)/$(TEST_IMAGE):$(TEST_IMAGE_TAG)
TEST_DIGEST_LOCAL := sha256:33735bd63cf84d7e388d9f6d297d348c523c044410f553bd878c6d7829612735
TEST_IMAGE_SIGN := $(TEST_REGISTRY)/$(TEST_IMAGE)@$(TEST_DIGEST_LOCAL)
EXAMPLES_DIR := examples
SHELL := /bin/bash

# set gencrt script (bring your own certificates) to yes to avoid generating new
# ones each time. Must be executable (bash, python, binary) with +x bit.
# must produce leaf.{crt,key},sub-ca.crt,root.crt and certificate_chain.pem
# (sub-ca.crt + root.crt combined)
CERT_SCRIPT := ./gencrt.sh

.PHONY: all clean registry test certificates sign verify e2e clean-e2e check-tools save load pack unpack dump-sig

all: check-tools
	@echo "targets: test verify clean e2e clean-e2e"

check-tools:
	@type -a docker &>/dev/null || echo "error: Install docker: https://docs.docker.com/engine/install/"
	@type -a cosign &>/dev/null || echo "error: Install cosign: https://docs.sigstore.dev/cosign/system_config/installation/"
	@type -a openssl &>/dev/null || echo "error: openssl missing"

clean:
	rm -rf $(EXAMPLES_DIR)/$(TEST_IMAGE)-image
	rm -f $(EXAMPLES_DIR)/*
	docker rm -f $(TEST_REGISTRY_NAME) 2>/dev/null

clean-e2e: clean

registry:
	docker run -d -p $(TEST_REGISTRY):5000 --name $(TEST_REGISTRY_NAME) $(TEST_REGISTRY_IMAGE)
	docker pull $(TEST_IMAGE):$(TEST_IMAGE_TAG)@$(TEST_DIGEST)
	docker tag $(TEST_IMAGE)@$(TEST_DIGEST) $(TEST_IMAGE_LOCAL)
	docker push $(TEST_IMAGE_LOCAL)

certificates:
	$(CERT_SCRIPT)

test: check-tools registry certificates sign verify
e2e: test save load

sign:
	cosign generate "$(TEST_IMAGE_SIGN)" > $(EXAMPLES_DIR)/payload.json
	openssl dgst -sha256 -sign $(EXAMPLES_DIR)/leaf.key \
		-out $(EXAMPLES_DIR)/payload.sig $(EXAMPLES_DIR)/payload.json
	base64 $(EXAMPLES_DIR)/payload.sig > $(EXAMPLES_DIR)/payloadbase64.sig

	cosign attach signature \
		--payload $(EXAMPLES_DIR)/payload.json \
		--signature $(EXAMPLES_DIR)/payloadbase64.sig \
		--certificate $(EXAMPLES_DIR)/leaf.crt \
		--certificate-chain $(EXAMPLES_DIR)/certificate_chain.pem \
		$(TEST_IMAGE_SIGN)

verify:
	cosign tree $(TEST_IMAGE_SIGN)
	cosign verify \
		--ca-roots=$(EXAMPLES_DIR)/ca.crt \
		--certificate-identity-regexp '.*' \
		--certificate-oidc-issuer-regexp '.*' \
		--private-infrastructure \
		--insecure-ignore-sct \
		$(TEST_IMAGE_SIGN)

save:
	rm -rf $(EXAMPLES_DIR)/$(TEST_IMAGE)-image
	cosign save \
		--dir $(EXAMPLES_DIR)/$(TEST_IMAGE)-image \
		--allow-insecure-registry=true \
		$(TEST_IMAGE_SIGN)

pack: save
	tar cf $(EXAMPLES_DIR)/$(TEST_IMAGE).tar $(EXAMPLES_DIR)/$(TEST_IMAGE)-image
	rm -rf $(EXAMPLES_DIR)/$(TEST_IMAGE)-image

unpack:
	rm -rf $(EXAMPLES_DIR)/$(TEST_IMAGE)-image
	tar xf $(EXAMPLES_DIR)/$(TEST_IMAGE).tar $(EXAMPLES_DIR)/$(TEST_IMAGE)-image

load: unpack
	cosign load \
		--allow-insecure-registry=true \
		--dir $(EXAMPLES_DIR)/$(TEST_IMAGE)-image \
		$(TEST_IMAGE_LOCAL)-loaded
	cosign tree $(TEST_IMAGE_LOCAL)-loaded
	rm -rf $(EXAMPLES_DIR)/$(TEST_IMAGE)-image

dump-sig: save
	DIGEST=$$(jq -r '.manifests[] | select(.annotations.kind == "dev.cosignproject.cosign/sigs") | .digest' $(EXAMPLES_DIR)/$(TEST_IMAGE)-image/index.json) && \
	jq . $(EXAMPLES_DIR)/$(TEST_IMAGE)-image/blobs/"$${DIGEST/:/\/}"
