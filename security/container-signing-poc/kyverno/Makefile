# setup kyverno test for e2e

SCRIPTS_DIR := scripts
POLICY_DIR := policy

NOTATION_DIR := ../notation
NOTATION_EXAMPLES_DIR := $(NOTATION_DIR)/examples
NOTATION_SIGNER := $(NOTATION_EXAMPLES_DIR)/rsassa-pss-sha512.sh
NOTATION_TEST_IMAGE_UNSIGNED := busybox:1.36.0-glibc
NOTATION_TEST_IMAGE_SIGNED := busybox:1.36.1-glibc
NOTATION_TEST_DIGEST := sha256:28e01ab32c9dbcbaae96cf0d5b472f22e231d9e603811857b295e61197e40a9b

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

.PHONY: all test setup check-tools sign clean clean-tests sign-notation sign-cosign

all: check-tools
	@echo "targets: test clean"

test: check-tools setup sign tests
e2e: check-tools setup-e2e tests
notation-e2e: check-tools setup-e2e tests-notation
cosign-e2e: check-tools setup-e2e tests-cosign

.PHONY: tests tests-notation tests-cosign
.PHONY: test-pod test-deployment test-pod-notation test-pod-cosign test-deployment-notation test-deployment-cosign

setup: setup-registry create-cluster install-kyverno install-notation-plugin certificates
setup-e2e: setup-registry create-cluster install-kyverno

.PHONY: setup-registry create-cluster install-kyverno install-notation-plugin certificates
.PHONY: install-policies install-policy-notation install-policy-cosign

check-tools:
	@type -a helm &>/dev/null || echo "error: Install helm: https://helm.sh/docs/intro/install/"
	@type -a docker &>/dev/null || echo "error: Install docker: https://docs.docker.com/engine/install/"
	@type -a kind &>/dev/null || echo "error: Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
	@type -a notation &>/dev/null || echo "error: Install notation: https://notaryproject.dev/docs/user-guides/installation/cli/"

setup-registry:
	docker run -d -p $(TEST_REGISTRY):5000 --network kind --name $(TEST_REGISTRY_NAME) $(TEST_REGISTRY_IMAGE)
	for image in $(NOTATION_TEST_IMAGE_UNSIGNED) $(NOTATION_TEST_IMAGE_SIGNED) $(COSIGN_TEST_IMAGE_UNSIGNED) $(COSIGN_TEST_IMAGE_SIGNED); do \
		docker pull $${image}; \
		docker tag $${image} $(TEST_REGISTRY)/$${image}; \
		docker push $(TEST_REGISTRY)/$${image}; \
	done

create-cluster:
	./scripts/kind-cluster.sh

install-kyverno:
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update
	helm install kyverno kyverno/kyverno -n kyverno --create-namespace
	sleep 60
	# NOTE: we need to edit Kyverno config to allow insecure registries
	kubectl -n kyverno get deployment kyverno-admission-controller -o yaml | \
		sed -e 's/allowInsecureRegistry=false/allowInsecureRegistry=true/' | \
		kubectl apply -f -
	sleep 30

install-notation-plugin:
	make -C $(NOTATION_DIR) install

certificates:
	make -C $(NOTATION_DIR) certificates
	make -C $(COSIGN_DIR) certificates

install-policies: install-policy-notation install-policy-cosign

install-policy-notation:
	# replace example cert with the generated certs for notation
	cat $(POLICY_DIR)/kyverno-policy-notation.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(NOTATION_EXAMPLES_DIR)/ca.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

install-policy-cosign:
	# for cosign, we must use leaf.crt, not root ca
	cat $(POLICY_DIR)/kyverno-policy-cosign.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(COSIGN_EXAMPLES_DIR)/leaf.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

sign: sign-notation sign-cosign

sign-notation:
	make -C $(NOTATION_DIR) sign TEST_IMAGE_SIGN=$(TEST_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED)

sign-cosign:
	make -C $(COSIGN_DIR) sign TEST_IMAGE_SIGN=$(TEST_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED)

tests: install-policies test-pod test-deployment
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

tests-notation: sign-notation install-policy-notation test-pod-notation test-deployment-notation
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

tests-cosign: sign-cosign install-policy-cosign test-pod-cosign test-deployment-cosign
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

test-pod: test-pod-notation test-pod-cosign

test-pod-notation:
	kubectl run --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_UNSIGNED) pod-fail-notation || true
	kubectl run --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED) pod-success-notation || true

test-pod-cosign:
	kubectl run --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_UNSIGNED) pod-fail-cosign || true
	kubectl run --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED) pod-success-cosign || true

test-deployment: test-deployment-notation test-deployment-cosign

test-deployment-notation:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_UNSIGNED) deployment-fail-notation || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(NOTATION_TEST_IMAGE_SIGNED) deployment-success-notation || true

test-deployment-cosign:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_UNSIGNED) deployment-fail-cosign || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(COSIGN_TEST_IMAGE_SIGNED) deployment-success-cosign || true

clean-tests:
	# notation
	-kubectl delete pod pod-fail-notation || true
	-kubectl delete deployment deployment-fail-notation || true
	-kubectl delete pod pod-success-notation || true
	-kubectl delete deployment deployment-success-notation || true
	# cosign
	-kubectl delete pod pod-fail-cosign || true
	-kubectl delete deployment deployment-fail-cosign || true
	-kubectl delete pod pod-success-cosign || true
	-kubectl delete deployment deployment-success-cosign || true

clean: clean-e2e
	make -C $(NOTATION_DIR) clean
	make -C $(COSIGN_DIR) clean

clean-e2e:
	-docker rm -f $(TEST_REGISTRY_NAME)
	-kind delete cluster
