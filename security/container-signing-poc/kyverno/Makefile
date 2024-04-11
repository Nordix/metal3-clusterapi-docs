# build and install notation-external-signer

SCRIPTS_DIR := scripts
POLICY_DIR := policy

NOTATION_DIR := ../notation
EXAMPLES_DIR := $(NOTATION_DIR)/examples
NOTATION_SIGNER := $(EXAMPLES_DIR)/rsassa-pss-sha512.sh

TEST_REGISTRY := 127.0.0.1:5001
TEST_REGISTRY_NAME := kind-registry
TEST_REGISTRY_IMAGE := registry:2
TEST_IMAGE_UNSIGNED := busybox:1.36.0-glibc
TEST_IMAGE_SIGNED := busybox:1.36.1-glibc
TEST_DIGEST := sha256:db16cd196b8a37ba5f08414e6f6e71003d76665a5eac160cb75ad3759d8b3e29

CLUSTER_REGISTRY := 172.19.0.3:5000

SHELL := /bin/bash

.PHONY: all test setup check-tools sign clean clean-tests

all: check-tools
	@echo "targets: test clean"

test: check-tools setup sign tests
e2e: check-tools setup-e2e tests

.PHONY: tests test-pod test-deployment

setup: setup-registry create-cluster install-kyverno install-notation-plugin certificates
setup-e2e: create-cluster install-kyverno

.PHONY: setup-registry create-cluster install-kyverno install-notation-plugin install-policy certificates

check-tools:
	@type -a helm &>/dev/null || echo "error: Install helm: https://helm.sh/docs/intro/install/"
	@type -a docker &>/dev/null || echo "error: Install docker: https://docs.docker.com/engine/install/"
	@type -a kind &>/dev/null || echo "error: Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
	@type -a notation &>/dev/null || echo "error: Install notation: https://notaryproject.dev/docs/user-guides/installation/cli/"

setup-registry:
	docker run -d -p $(TEST_REGISTRY):5000 --name $(TEST_REGISTRY_NAME) $(TEST_REGISTRY_IMAGE)
	for image in $(TEST_IMAGE_UNSIGNED) $(TEST_IMAGE_SIGNED); do \
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

install-policy:
	# replace example cert with the generated certs
	cat $(POLICY_DIR)/kyverno-policy.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(EXAMPLES_DIR)/ca.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

sign:
	make -C $(NOTATION_DIR) sign TEST_IMAGE_SIGN=$(TEST_REGISTRY)/$(TEST_IMAGE_SIGNED)

tests: install-policy test-pod test-deployment
	sleep 5
	kubectl get pods -A
	@echo "Success (if only pods with success are visible - ignore the ImagePull issues)"

test-pod:
	kubectl run --image $(CLUSTER_REGISTRY)/$(TEST_IMAGE_UNSIGNED) pod-fail || true
	kubectl run --image $(CLUSTER_REGISTRY)/$(TEST_IMAGE_SIGNED) pod-success

test-deployment:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(TEST_IMAGE_UNSIGNED) deployment-fail || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/$(TEST_IMAGE_SIGNED) deployment-success

clean-tests:
	-kubectl delete pod pod-fail
	-kubectl delete deployment deployment-fail
	-kubectl delete pod pod-success
	-kubectl delete deployment deployment-success

clean: clean-e2e
	make -C $(NOTATION_DIR) clean

clean-e2e:
	-docker rm -f $(TEST_REGISTRY_NAME)
	-kind delete cluster
