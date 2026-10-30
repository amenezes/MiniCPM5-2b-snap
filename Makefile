SHELL := /bin/bash

# Always run `hf` via pipx to avoid relying on local `hf` installations.
hf := pipx run --spec "huggingface_hub[cli]" hf

SNAP_NAME ?= minicpm5-2b
ENGINE ?= cpu

# Upstream GGUF (Q4_K_M from OpenBMB). Override to use an internal mirror.
GGUF_REPO ?= openbmb/MiniCPM5-2B-GGUF
GGUF_FILE ?= MiniCPM5-2B-Q4_K_M.gguf
GGUF_SHA256 ?= ec2d5801640099e97d8d7e8003ad4d81f336e757811f03a26173dddf386602fd
MODEL_DIR := components/model-q4-k-m-gguf

# Additional quantization variants (from bartowski).
GGUF_EXTRA_REPO ?= bartowski/MiniCPM5-2B-GGUF
Q5KM_FILE ?= MiniCPM5-2B-Q5_K_M.gguf
Q5KM_SHA256 ?= c32c4e0203ac181f5771291725a76dfd94bdc6c54ee79fcb17ebaea3c19c500b
Q5KM_DIR := components/model-q5-k-m-gguf
Q6K_FILE ?= MiniCPM5-2B-Q6_K.gguf
Q6K_SHA256 ?= c9f424852aa737b3f5f2f83096a6214d86a8ea2516f3a0fbaa04a3b4feba477d
Q6K_DIR := components/model-q6-k-gguf

# DSpark draft model (optional `minicpm5-2b-dspark` variant). Not a standalone
# model: it is loaded as --model-draft and only works with MiniCPM5-2B.
DSPARK_REPO ?= openbmb/MiniCPM5-2B-DSpark-GGUF
DSPARK_FILE ?= MiniCPM5-2.6B-DSpark.gguf
DSPARK_SHA256 ?= 57df08640f0534a1aac075d1c8bdacdb2b7e5815da6f4e5cfd39ecac3a3f0c26
DSPARK_DIR := components/model-dspark-gguf

.PHONY: all help init init-all init-dspark build install upload use-dspark use-default smoke-test install-deps init-submodules download-models download-extra-models download-dspark verify-model verify-extra-models verify-dspark

all: help

#
# Main targets
#

help: ## Show this help message
	@echo "Usage: make <target>"
	@echo
	@echo "Targets:"
	@# List all targets with descriptions (lines starting with '##'):
	@grep -E '^[a-zA-Z0-9_-]+:.*## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-18s %s\n", $$1, $$2}'

init: init-submodules install-deps download-models verify-model ## Initialize the build environment (default Q4_K_M model only)

init-all: init-submodules install-deps download-models download-extra-models download-dspark verify-model verify-extra-models verify-dspark ## Initialize with all quantization variants and the DSpark draft

init-dspark: init-submodules install-deps download-models download-dspark verify-model verify-dspark ## Initialize the build environment for the DSpark variant

build: ## Build the snap
	./dev/build.sh

install: ## Install the snap
	./dev/install.sh

upload: ## Upload the snap
	./dev/upload.sh

use-dspark: ## Switch the installed snap to the DSpark variant (downloads the draft component)
	sudo $(SNAP_NAME) use-model minicpm5-2b-dspark --assume-yes

use-default: ## Switch the installed snap back to the default Q4_K_M variant
	sudo $(SNAP_NAME) use-model minicpm5-2b --assume-yes

smoke-test: ## Run smoke tests (override with SNAP_NAME=... ENGINE=...)
	sudo ./dev/smoke-test.sh $(SNAP_NAME) $(ENGINE)

#
# Supporting targets
#

install-deps:
	@echo "Installing dependencies..."
	@# Ensure pipx is available for running the hf CLI.
	@command -v pipx >/dev/null 2>&1 || { \
		sudo apt-get update; \
		sudo apt-get install -y pipx; \
	}

init-submodules:
	@echo "Initializing submodules..."
	@if git submodule status | grep -q '^-'; then \
		git submodule update --init; \
	fi

download-models:
	@echo "Downloading MiniCPM5-2B-Q4_K_M model weights..."
	$(hf) download $(GGUF_REPO) $(GGUF_FILE) \
		--local-dir $(MODEL_DIR)

download-extra-models: ## Download Q5_K_M and Q6_K model variants
	@echo "Downloading MiniCPM5-2B-Q5_K_M model weights..."
	$(hf) download $(GGUF_EXTRA_REPO) $(Q5KM_FILE) \
		--local-dir $(Q5KM_DIR)
	@echo "Downloading MiniCPM5-2B-Q6_K model weights..."
	$(hf) download $(GGUF_EXTRA_REPO) $(Q6K_FILE) \
		--local-dir $(Q6K_DIR)

download-dspark: ## Download the DSpark draft model (optional minicpm5-2b-dspark variant)
	@echo "Downloading MiniCPM5-2.6B-DSpark draft weights..."
	$(hf) download $(DSPARK_REPO) $(DSPARK_FILE) \
		--local-dir $(DSPARK_DIR)

verify-model: ## Verify the Q4_K_M GGUF checksum against the pinned sha256
	@echo "Verifying $(MODEL_DIR)/$(GGUF_FILE)..."
	@if [ ! -f "$(MODEL_DIR)/$(GGUF_FILE)" ]; then \
		echo "ERROR: $(MODEL_DIR)/$(GGUF_FILE) not found. Run 'make download-models' first." >&2; \
		exit 1; \
	fi
	@echo "$(GGUF_SHA256)  $(MODEL_DIR)/$(GGUF_FILE)" | sha256sum --check --status \
		&& echo "OK: checksum matches" \
		|| { echo "ERROR: checksum mismatch (expected $(GGUF_SHA256))" >&2; exit 1; }

verify-extra-models: ## Verify Q5_K_M and Q6_K GGUF checksums
	@echo "Verifying $(Q5KM_DIR)/$(Q5KM_FILE)..."
	@if [ ! -f "$(Q5KM_DIR)/$(Q5KM_FILE)" ]; then \
		echo "ERROR: $(Q5KM_DIR)/$(Q5KM_FILE) not found. Run 'make download-extra-models' first." >&2; \
		exit 1; \
	fi
	@echo "$(Q5KM_SHA256)  $(Q5KM_DIR)/$(Q5KM_FILE)" | sha256sum --check --status \
		&& echo "OK: Q5_K_M checksum matches" \
		|| { echo "ERROR: Q5_K_M checksum mismatch (expected $(Q5KM_SHA256))" >&2; exit 1; }
	@echo "Verifying $(Q6K_DIR)/$(Q6K_FILE)..."
	@if [ ! -f "$(Q6K_DIR)/$(Q6K_FILE)" ]; then \
		echo "ERROR: $(Q6K_DIR)/$(Q6K_FILE) not found. Run 'make download-extra-models' first." >&2; \
		exit 1; \
	fi
	@echo "$(Q6K_SHA256)  $(Q6K_DIR)/$(Q6K_FILE)" | sha256sum --check --status \
		&& echo "OK: Q6_K checksum matches" \
		|| { echo "ERROR: Q6_K checksum mismatch (expected $(Q6K_SHA256))" >&2; exit 1; }

verify-dspark: ## Verify the DSpark draft GGUF checksum against the pinned sha256
	@echo "Verifying $(DSPARK_DIR)/$(DSPARK_FILE)..."
	@if [ ! -f "$(DSPARK_DIR)/$(DSPARK_FILE)" ]; then \
		echo "ERROR: $(DSPARK_DIR)/$(DSPARK_FILE) not found. Run 'make download-dspark' first." >&2; \
		exit 1; \
	fi
	@echo "$(DSPARK_SHA256)  $(DSPARK_DIR)/$(DSPARK_FILE)" | sha256sum --check --status \
		&& echo "OK: DSpark checksum matches" \
		|| { echo "ERROR: DSpark checksum mismatch (expected $(DSPARK_SHA256))" >&2; exit 1; }
