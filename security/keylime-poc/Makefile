# Keylime Push Model Agent POC Makefile

# Configuration (override via environment)
KEYLIME_VERSION  ?= latest
KEYLIME_GIT      ?= $(HOME)/git/keylime/keylime
RUST_KEYLIME_GIT ?= $(HOME)/git/keylime/rust-keylime
DOCKERFILE_TYPE  ?= fedora
AGENT_CLUSTERS   ?= 2
# UUID mode: "generate" (random) or "hash_ek" (derived from TPM EK)
# Note: hash_ek requires fix from tuomo/fix-hash-ek-on-push-model branch
UUID_MODE        ?= generate

# Directories
SCRIPTS_DIR := scripts
CERTS_DIR   := certs
K8S_INFRA   := k8s/infra
K8S_AGENTS  := k8s/agents

# TPM policy requiring PCR 0 with zeros (swtpm default)
TPM_POLICY := {"0":"0000000000000000000000000000000000000000000000000000000000000000"}

# Detect host IP for cross-cluster communication
HOST_IP := $(shell hostname -I 2>/dev/null | awk '{print $$1}' || echo "host.docker.internal")

.PHONY: all setup run server test verify clean clean-server clean-agents \
        check-prereqs build-server-images build-agent-image help

all: help

help:
	@echo "Keylime Push Model Agent POC"
	@echo ""
	@echo "Usage:"
	@echo "  make setup       - Build keylime images from source (one-time)"
	@echo "  make run         - Full POC: server + test (idempotent)"
	@echo "  make server      - Deploy keylime backend (registrar, verifier)"
	@echo "  make test        - Deploy agent clusters and run attestation test"
	@echo "  make verify      - Read-only check of attestation status"
	@echo "  make clean       - Delete all clusters"
	@echo ""
	@echo "Configuration:"
	@echo "  KEYLIME_VERSION=$(KEYLIME_VERSION)"
	@echo "  KEYLIME_GIT=$(KEYLIME_GIT)"
	@echo "  RUST_KEYLIME_GIT=$(RUST_KEYLIME_GIT)"
	@echo "  AGENT_CLUSTERS=$(AGENT_CLUSTERS)"
	@echo "  UUID_MODE=$(UUID_MODE)"
	@echo "  HOST_IP=$(HOST_IP)"

# =============================================================================
# Setup (one-time, builds images from source)
# =============================================================================

setup: check-prereqs build-server-images build-agent-image
	@echo "Setup complete. Run 'make run' to start the POC."

check-prereqs:
	@bash $(SCRIPTS_DIR)/check-prereqs.sh $(KEYLIME_GIT) $(RUST_KEYLIME_GIT)

build-server-images:
	@echo "Building keylime server images from $(KEYLIME_GIT)..."
	cd $(KEYLIME_GIT)/docker/release && ./build_locally.sh $(KEYLIME_VERSION)

build-agent-image:
	@$(SCRIPTS_DIR)/build-agent.sh $(K8S_AGENTS) $(RUST_KEYLIME_GIT) $(KEYLIME_VERSION)

# =============================================================================
# Run (full POC: server + test)
# =============================================================================

run: server test
	@echo ""
	@echo "POC complete."

# =============================================================================
# Server (keylime backend infrastructure)
# =============================================================================

server: generate-certs create-infra-cluster deploy-infra
	@echo "Infrastructure cluster ready."
	@echo "Registrar: http://localhost:30890"
	@echo "Verifier:  https://localhost:30881"

generate-certs:
	@echo "Generating TLS certificates..."
	$(SCRIPTS_DIR)/generate-certs.sh

create-infra-cluster:
	@echo "Creating keylime-infra cluster..."
	@if kind get clusters 2>/dev/null | grep -q "^keylime-infra$$"; then \
		echo "Cluster keylime-infra already exists"; \
	else \
		kind create cluster --config $(K8S_INFRA)/kind-config.yaml; \
	fi
	@kubectl config use-context kind-keylime-infra

deploy-infra: load-infra-images
	@$(SCRIPTS_DIR)/deploy-infra.sh $(K8S_INFRA) $(CERTS_DIR) $(KEYLIME_VERSION)

load-infra-images:
	@echo "Loading images into keylime-infra cluster..."
	kind load docker-image --name keylime-infra keylime_registrar:$(KEYLIME_VERSION) || true
	kind load docker-image --name keylime-infra keylime_verifier:$(KEYLIME_VERSION) || true
	kind load docker-image --name keylime-infra keylime_tenant:$(KEYLIME_VERSION) || true

create-agents-cluster:
	@$(SCRIPTS_DIR)/create-agent-clusters.sh $(AGENT_CLUSTERS) $(K8S_AGENTS)

deploy-agents: build-agent-image
	@$(SCRIPTS_DIR)/deploy-agent-clusters.sh $(AGENT_CLUSTERS) $(K8S_AGENTS) $(CERTS_DIR) $(HOST_IP) $(KEYLIME_VERSION) $(UUID_MODE)

# =============================================================================
# Test (deploy agent cluster and verify attestation - idempotent)
# =============================================================================

test: clean-agents create-agents-cluster deploy-agents add-agents-to-verifier verify
	@echo ""
	@echo "Test complete."

add-agents-to-verifier:
	@$(SCRIPTS_DIR)/add-agents-to-verifier.sh '$(TPM_POLICY)'

# =============================================================================
# Verify (read-only attestation check)
# =============================================================================

verify:
	@$(SCRIPTS_DIR)/verify-attestation.sh

# =============================================================================
# Clean
# =============================================================================

clean: clean-agents clean-server
	@echo "Cleanup complete."

clean-server:
	@echo "Deleting keylime-infra cluster..."
	kind delete cluster --name keylime-infra || true
	rm -rf $(CERTS_DIR)

clean-agents:
	@$(SCRIPTS_DIR)/clean-agent-clusters.sh
