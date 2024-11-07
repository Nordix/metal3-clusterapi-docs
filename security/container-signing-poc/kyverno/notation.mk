# setup kyverno test for e2e

SCRIPTS_DIR := scripts
POLICY_DIR := policy

NOTATION_DIR := ../notation
NOTATION_EXAMPLES_DIR := $(NOTATION_DIR)/examples
NOTATION_SIGNER := $(NOTATION_EXAMPLES_DIR)/rsassa-pss-sha512.sh
NOTATION_TEST_IMAGE_UNSIGNED := busybox:1.36.0-glibc
NOTATION_TEST_IMAGE_SIGNED := busybox:1.36.1-glibc
NOTATION_TEST_DIGEST := sha256:28e01ab32c9dbcbaae96cf0d5b472f22e231d9e603811857b295e61197e40a9b

TEST_REGISTRY := 127.0.0.1:5001
TEST_REGISTRY_NAME := kind-registry
TEST_REGISTRY_IMAGE := registry:2

CLUSTER_REGISTRY := 172.18.0.2:5000

SHELL := /bin/bash

.PHONY: all install-plugin registry certificates policy sign test test-pod test-deployment delete

all: install-plugin registry certificates sign policy test

install-plugin:
	make -C $(NOTATION_DIR) install

registry:
	for image in $(NOTATION_TEST_IMAGE_UNSIGNED) $(NOTATION_TEST_IMAGE_SIGNED); do \
		docker pull $${image}; \
		docker tag $${image} $(TEST_REGISTRY)/$${image}; \
		docker push $(TEST_REGISTRY)/$${image}; \
	done

certificates:
	make -C $(NOTATION_DIR) certificates

policy:
	# replace example cert with the generated certs for notation
	cat $(POLICY_DIR)/kyverno-policy-notation.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(NOTATION_EXAMPLES_DIR)/ca.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

sign:
	make -C $(NOTATION_DIR) sign TEST_IMAGE_SIGN=$(TEST_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED)

test: test-pod test-deployment
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

test-pod:
	kubectl run --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_UNSIGNED) pod-fail-notation || true
	kubectl run --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED) pod-success-notation || true

test-deployment:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_UNSIGNED) deployment-fail-notation || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED) deployment-success-notation || true

delete:
	kubectl -n default delete deployment --all
	kubectl -n default delete pod --all
