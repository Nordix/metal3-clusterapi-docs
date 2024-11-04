# top level makefile to run e2e test
# 1st flow: notation -> oras copy -> kyverno
# 2nd flow: cosign -> kyverno
# kyverno tests both cosign and notation

NOTATION_DIR := notation
ORAS_DIR := oras
KYVERNO_DIR := kyverno
COSIGN_DIR := cosign

SHELL := /bin/bash

.PHONY: all e2e clean notation-e2e cosign-e2e

all:
	@echo "targets: e2e clean"

e2e:
	make -C $(NOTATION_DIR) e2e
	make -C $(ORAS_DIR) e2e
	make -C $(COSIGN_DIR) e2e
	make -C $(KYVERNO_DIR) e2e
	@echo "e2e test done!"

notation-e2e:
	make -C $(NOTATION_DIR) e2e
	make -C $(ORAS_DIR) e2e
	make -C $(KYVERNO_DIR) notation-e2e
	@echo "notation e2e test done!"

cosign-e2e:
	make -C $(COSIGN_DIR) e2e
	make -C $(KYVERNO_DIR) cosign-e2e
	@echo "cosign e2e test done!"

clean:
	make -C $(NOTATION_DIR) clean-e2e
	make -C $(ORAS_DIR) clean-e2e
	make -C $(COSIGN_DIR) clean-e2e
	make -C $(KYVERNO_DIR) clean-e2e
