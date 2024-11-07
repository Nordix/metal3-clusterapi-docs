# top level makefile to run e2e test
# 1st flow: notation -> oras copy -> kyverno
# 2nd flow: cosign -> kyverno
# kyverno tests both cosign and notation

NOTATION_DIR := notation
ORAS_DIR := oras
KYVERNO_DIR := kyverno
COSIGN_DIR := cosign

SHELL := /bin/bash

.PHONY: all notation cosign clean

all:
	@echo "targets: notation cosign clean"

notation:
	make -C $(KYVERNO_DIR) setup
	make -C $(KYVERNO_DIR) -f notation.mk

cosign:
	make -C $(KYVERNO_DIR) setup
	make -C $(KYVERNO_DIR) -f cosign.mk

clean:
	make -C $(NOTATION_DIR) clean
	make -C $(ORAS_DIR) clean
	make -C $(COSIGN_DIR) clean
	make -C $(KYVERNO_DIR) clean
