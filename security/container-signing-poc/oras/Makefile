# use oras to move busybox image with signatures to another registry

NOTATION_DIR := ../notation

# registry1 is same as in ../notation, containing container with signature
NOTATION_REGISTRY := 127.0.0.1:5002
# registry2 is clean registry where we import continer and signature
TEST_REGISTRY := 127.0.0.1:5001
# name needs to match kyverno registry for e2e
TEST_REGISTRY_NAME := kind-registry
TEST_REGISTRY_IMAGE := registry:2

TEST_TAG := 1.36.1-glibc
TEST_IMAGE := busybox:$(TEST_TAG)
TEST_DIGEST := sha256:28e01ab32c9dbcbaae96cf0d5b472f22e231d9e603811857b295e61197e40a9b
TEST_IMAGE1_LOCAL := $(NOTATION_REGISTRY)/$(TEST_IMAGE)
TEST_IMAGE1_SIGN := $(NOTATION_REGISTRY)/busybox@$(TEST_DIGEST)
TEST_IMAGE2_LOCAL := $(TEST_REGISTRY)/$(TEST_IMAGE)
TEST_IMAGE2_SIGN := $(TEST_REGISTRY)/busybox@$(TEST_DIGEST)
TEST_IMAGE_TARBALL := busybox.tar

SHELL := /bin/bash

.PHONY: all test e2e verify-image sign-image registry export-image import-image clean check-tools

all: check-tools
	@echo "targets: test clean"

check-tools:
	@type -a oras &>/dev/null || echo "error: Install oras: https://oras.land/docs/installation"
	@type -a notation &>/dev/null || echo "error: Install notation: https://notaryproject.dev/docs/user-guides/installation/cli/"

registry:
	docker run -d -p $(TEST_REGISTRY):5000 --network bridge --name $(TEST_REGISTRY_NAME) $(TEST_REGISTRY_IMAGE)

sign-image:
	# we run full notation test to get signatures
	make -C $(NOTATION_DIR) test

export-image:
	oras cp --recursive --from-plain-http $(TEST_IMAGE1_SIGN) --to-oci-layout $(TEST_IMAGE)
	tar cf busybox.tar busybox
	sudo rm -rf busybox

import-image:
	tar xf busybox.tar
	oras cp --recursive --from-oci-layout $(TEST_IMAGE) --to-plain-http $(TEST_IMAGE2_LOCAL)

verify-image:
	notation verify --insecure-registry $(TEST_IMAGE2_SIGN)

test: check-tools sign-image export-image registry import-image verify-image
	@echo Success!

e2e: check-tools export-image registry import-image verify-image

clean: clean-e2e
	make -C $(NOTATION_DIR) clean

clean-e2e: clean
	sudo rm -rf busybox.tar busybox
	-docker rm -f $(TEST_REGISTRY_NAME)
