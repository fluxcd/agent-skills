# Makefile for maintaining the GitOps AI Skills assets.
# Run 'make help' to see available targets.

SCHEMAS_DIRS := skills/gitops-repo-audit/assets/schemas/master-standalone-strict \
	skills/gitops-cluster-debug/assets/schemas/master-standalone-strict

DISCOVER_SCRIPT := skills/gitops-repo-audit/scripts/discover.sh
VALIDATE_SCRIPT := skills/gitops-repo-audit/scripts/validate.sh
TEST_DIR := tests/gitops-repo-audit

.PHONY: help download-schemas clean-schemas test-discover test-validate

download-schemas: clean-schemas ## Download Flux OpenAPI schemas for kubeconform validation
	@for dir in $(SCHEMAS_DIRS); do \
		mkdir -p $$dir; \
		curl -sL https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C $$dir; \
		curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C $$dir; \
		rm -f $$dir/all.json $$dir/_definitions.json; \
	done

clean-schemas: ## Remove downloaded schemas
	@for dir in $(SCHEMAS_DIRS); do \
		rm -rf $$dir; \
	done

test-discover: ## Run discovery script on the test fixtures
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/monorepo-structure

test-validate: ## Run validation script on the test fixtures
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/monorepo-structure

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
