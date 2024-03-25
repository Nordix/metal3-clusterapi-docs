# build and install notation-external-signer

EXAMPLES_DIR := examples
SCRIPTS_DIR := scripts
POLICY_DIR := policy
PLUGIN_DIR := $(HOME)/.config/notation/plugins/external-signer
NOTATION_SIGNER := ../notation/examples/rsassa-pss-sha512.sh

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
test: check-tools setup sign tests

.PHONY: tests test-pod test-deployment

tests: install-policy test-pod test-deployment
setup: setup-registry create-cluster install-kyverno install-notation-plugin certificates

.PHONY: setup-registry create-cluster install-kyverno install-notation-plugin install-policy certificates

check-tools:
	@command -v helm &>/dev/null || echo "error: Install helm: https://helm.sh/docs/intro/install/"
	@command -v docker &>/dev/null || echo "error: Install docker: https://docs.docker.com/engine/install/"
	@command -v kind &>/dev/null || echo "error: Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/"
	@command -v notation &>/dev/null || echo "error: Install notation: https://notaryproject.dev/docs/user-guides/installation/cli/"

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
	cd ../notation && make install

certificates:
	openssl genrsa -out $(EXAMPLES_DIR)/ca.key 4096
	openssl req -new -x509 -days 365 -key $(EXAMPLES_DIR)/ca.key \
		-subj "/O=Notation/CN=Notation Root CA" \
		-out $(EXAMPLES_DIR)/ca.crt -addext "keyUsage=critical,keyCertSign"

	openssl genrsa -out $(EXAMPLES_DIR)/leaf.key 4096
	openssl req -newkey rsa:4096 -nodes -keyout $(EXAMPLES_DIR)/leaf.key \
		-subj "/CN=Notation.leaf" -out $(EXAMPLES_DIR)/leaf.csr

	openssl x509 -req \
		-extfile <(printf "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature") \
		-days 365 -in $(EXAMPLES_DIR)/leaf.csr -CA $(EXAMPLES_DIR)/ca.crt -CAkey $(EXAMPLES_DIR)/ca.key \
		-CAcreateserial -out $(EXAMPLES_DIR)/leaf.crt

	cat $(EXAMPLES_DIR)/leaf.crt $(EXAMPLES_DIR)/ca.crt > $(EXAMPLES_DIR)/certificate_chain.pem

install-policy: certificates
	# replace example cert with the generated certs
	cat $(POLICY_DIR)/kyverno-policy.yaml | \
		sed -re '/-----BEGIN/,/END CERTIFICATE-----/d' | \
		{ cat -; cat $(EXAMPLES_DIR)/ca.crt | sed -e 's/^/              /g'; } | \
	kubectl apply -f -
	sleep 30

sign:
	EXTERNAL_CERT_CHAIN=$(EXAMPLES_DIR)/certificate_chain.pem \
	EXTERNAL_PRIVATE_KEY=$(EXAMPLES_DIR)/leaf.key \
	EXTERNAL_SIGNER=$(NOTATION_SIGNER) \
	notation sign --debug --insecure-registry --id "anything" --plugin "external-signer" \
		$(TEST_REGISTRY)/$(TEST_IMAGE_SIGNED)

test-pod:
	kubectl run --image $(CLUSTER_REGISTRY)/busybox:1.36.0-glibc pod-fail || true
	kubectl run --image $(CLUSTER_REGISTRY)/busybox:1.36.1-glibc pod-success

test-deployment:
	kubectl create deployment --image $(CLUSTER_REGISTRY)/busybox:1.36.0-glibc deployment-fail  || true
	kubectl create deployment --image $(CLUSTER_REGISTRY)/busybox:1.36.1-glibc deployment-success

clean-tests:
	kubectl delete pod pod-fail || true
	kubectl delete deployment deployment-fail || true
	kubectl delete pod pod-success || true
	kubectl delete deployment deployment-success || true

clean:
	rm -rf "$(PLUGIN_DIR)"
	rm -f $(EXAMPLES_DIR)/*.{cer,crt,csr,key,pem}
	docker rm -f $(TEST_REGISTRY_NAME)
	kind delete cluster
