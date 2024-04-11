# top level makefile to run e2e test
# notation -> oras copy -> kyverno

NOTATION_DIR := notation
ORAS_DIR := oras
KYVERNO_DIR := kyverno

SHELL := /bin/bash

.PHONY: all e2e clean

all:
	@echo "targets: e2e clean"

e2e:
	make -C $(NOTATION_DIR) e2e
	make -C $(ORAS_DIR) e2e
	make -C $(KYVERNO_DIR) e2e
	@echo "e2e test done!"

clean:
	make -C $(NOTATION_DIR) clean-e2e
	make -C $(ORAS_DIR) clean-e2e
	make -C $(KYVERNO_DIR) clean-e2e
