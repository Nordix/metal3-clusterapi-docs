# setup kyverno test for e2e

SCRIPTS_DIR := scripts
POLICY_DIR := policy

COSIGN_DIR := ../cosign
COSIGN_EXAMPLES_DIR := $(COSIGN_DIR)/examples
COSIGN_TEST_IMAGE_UNSIGNED := alpine:3.20.2
COSIGN_TEST_IMAGE_SIGNED := alpine:3.20.3
COSIGN_TEST_DIGEST := sha256:33735bd63cf84d7e388d9f6d297d348c523c044410f553bd878c6d7829612735

TEST_REGISTRY := 127.0.0.1:5001
TEST_REGISTRY_NAME := kind-registry
TEST_REGISTRY_IMAGE := registry:2

CLUSTER_REGISTRY := 172.18.0.2:5000

SHELL := /bin/bash

.PHONY: all registry certificates policy sign test test-pod test-deployment delete

all: registry certificates sign policy test

registry:
	for image in $(COSIGN_TEST_IMAGE_UNSIGNED) $(COSIGN_TEST_IMAGE_SIGNED); do \
		docker pull $${image}; \
		docker tag $${image} $(TEST_REGISTRY)/$${image}; \
		docker push $(TEST_REGISTRY)/$${image}; \
	done

certificates:
	make -C $(COSIGN_DIR) certificates

policy:
	cat $(POLICY_DIR)/kyverno-policy-cosign.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(COSIGN_EXAMPLES_DIR)/ca.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

sign:
	make -C $(COSIGN_DIR) sign TEST_IMAGE_SIGN=$(TEST_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED)

test: test-pod test-deployment
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

test-pod:
	kubectl run --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_UNSIGNED) pod-fail-cosign || true
	kubectl run --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED) pod-success-cosign || true

test-deployment:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_UNSIGNED) deployment-fail-cosign || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED) deployment-success-cosign || true

delete:
	kubectl -n default delete deployment --all
	kubectl -n default delete pod --all
