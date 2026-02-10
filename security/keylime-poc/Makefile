# Keylime Push Model Agent POC Makefile

# Configuration (override via environment)
KEYLIME_VERSION  ?= latest
KEYLIME_GIT      ?= $(HOME)/git/keylime/keylime
RUST_KEYLIME_GIT ?= $(HOME)/git/keylime/rust-keylime
DOCKERFILE_TYPE  ?= fedora
AGENT_CLUSTERS   ?= 2
# UUID mode: "generate" (random) or "hash_ek" (derived from TPM EK)
UUID_MODE        ?= hash_ek
KEYLIME_UID      ?= 490
KEYLIME_GID      ?= 490
# TPM mode: "swtpm" (emulated, default) or "hw" (hardware /dev/tpmrm0)
TPM_MODE         ?= swtpm

# Directories
SCRIPTS_DIR := scripts
CERTS_DIR   := certs
K8S_INFRA   := k8s/infra
K8S_AGENTS  := k8s/agents

# TPM policy: swtpm uses PCR 0 (all zeros), hwtpm uses PCR 8 (unused, all zeros in vTPM)
SWTPM_POLICY := {"0":"0000000000000000000000000000000000000000000000000000000000000000"}
HWTPM_POLICY := {"8":"0000000000000000000000000000000000000000000000000000000000000000"}
TPM_POLICY := $(SWTPM_POLICY)

# Detect host IP for cross-cluster communication
HOST_IP := $(shell hostname -I 2>/dev/null | awk '{print $$1}' || echo "host.docker.internal")

.PHONY: all setup run swtpm hwtpm server test verify clean clean-server \
        clean-agents clean-vm check-prereqs build-server-images \
        build-agent-image help

all: help

help:
	@echo "Keylime Push Model Agent POC"
	@echo ""
	@echo "Usage:"
	@echo "  make setup       - Build keylime images from source (one-time)"
	@echo "  make swtpm       - Full POC with software TPM (default)"
	@echo "  make hwtpm       - Full POC with hardware TPM (/dev/tpmrm0)"
	@echo "  make run         - Alias for 'make swtpm'"
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
	@echo "  KEYLIME_UID=$(KEYLIME_UID)"
	@echo "  KEYLIME_GID=$(KEYLIME_GID)"
	@echo "  TPM_MODE=$(TPM_MODE)"
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
	@$(SCRIPTS_DIR)/build-agent.sh $(K8S_AGENTS) $(RUST_KEYLIME_GIT) $(KEYLIME_VERSION) $(KEYLIME_UID) $(KEYLIME_GID)

# =============================================================================
# Run targets (full POC: server + test)
# =============================================================================

swtpm: server
	@$(MAKE) test TPM_MODE=swtpm
	@echo ""
	@echo "swtpm POC complete."

hwtpm: TPM_POLICY = $(HWTPM_POLICY)
hwtpm: server create-vtpm-vm deploy-hwtpm-agents add-agents-to-verifier verify
	@echo ""
	@echo "hwtpm POC complete."

run: swtpm

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
	@$(SCRIPTS_DIR)/deploy-agent-clusters.sh $(AGENT_CLUSTERS) $(K8S_AGENTS) $(CERTS_DIR) $(HOST_IP) $(KEYLIME_VERSION) $(UUID_MODE) $(KEYLIME_UID) $(KEYLIME_GID) $(TPM_MODE)

# =============================================================================
# Test (deploy agent cluster and verify attestation - idempotent)
# =============================================================================

test: clean-agents create-agents-cluster deploy-agents add-agents-to-verifier verify
	@echo ""
	@echo "Test complete."

add-agents-to-verifier:
	@$(SCRIPTS_DIR)/add-agents-to-verifier.sh '$(TPM_POLICY)'

# =============================================================================
# hwtpm VM targets
# =============================================================================

create-vtpm-vm:
	@$(SCRIPTS_DIR)/create-vtpm-vm.sh

deploy-hwtpm-agents: build-agent-image
	@$(SCRIPTS_DIR)/deploy-hwtpm-agents.sh 10.0.2.2 $(KEYLIME_VERSION) $(KEYLIME_UID) $(KEYLIME_GID) $(UUID_MODE)

# =============================================================================
# Verify (read-only attestation check)
# =============================================================================

verify:
	@$(SCRIPTS_DIR)/verify-attestation.sh

# =============================================================================
# Clean
# =============================================================================

clean: clean-agents clean-vm clean-server
	@echo "Cleanup complete."

clean-server:
	@echo "Deleting keylime-infra cluster..."
	kind delete cluster --name keylime-infra || true
	rm -rf $(CERTS_DIR)

clean-agents:
	@$(SCRIPTS_DIR)/clean-agent-clusters.sh

clean-vm:
	@$(SCRIPTS_DIR)/destroy-vtpm-vm.sh
