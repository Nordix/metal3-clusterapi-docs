# setup kyverno test for e2e

SCRIPTS_DIR := scripts
POLICY_DIR := policy

TEST_REGISTRY := 127.0.0.1:5001
TEST_REGISTRY_NAME := kind-registry
TEST_REGISTRY_IMAGE := registry:2

CLUSTER_REGISTRY := 172.18.0.2:5000

SHELL := /bin/bash

.PHONY: all setup check-tools setup-registry create-cluster install-kyverno clean

all: check-tools
	@echo "targets: setup clean"
	@echo "after 'make setup', run 'make -f cosign.mk' or 'make -f notation.mk'"

setup: check-tools setup-registry create-cluster install-kyverno
	@echo "kyverno setup done!"

check-tools:
	@type -a helm &>/dev/null || echo "error: Install helm: https://helm.sh/docs/intro/install/"
	@type -a docker &>/dev/null || echo "error: Install docker: https://docs.docker.com/engine/install/"
	@type -a kind &>/dev/null || echo "error: Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
	@type -a notation &>/dev/null || echo "error: Install notation: https://notaryproject.dev/docs/user-guides/installation/cli/"

setup-registry:
	docker run -d -p $(TEST_REGISTRY):5000 --network kind --name $(TEST_REGISTRY_NAME) $(TEST_REGISTRY_IMAGE)

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

clean:
	-docker rm -f $(TEST_REGISTRY_NAME)
	-kind delete cluster --name kyverno
