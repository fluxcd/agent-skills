# Makefile for maintaining the GitOps AI Skills assets.
# Run 'make help' to see available targets.

SCHEMAS_DIR := skills/analyze-gitops-repo/assets/schemas/master-standalone-strict

DISCOVER_SCRIPT := skills/analyze-gitops-repo/scripts/discover.sh
VALIDATE_SCRIPT := skills/analyze-gitops-repo/scripts/validate.sh
TEST_DIR := tests/analyze-gitops-repo

.PHONY: help download-schemas clean-schemas test-discover test-validate

download-schemas: clean-schemas ## Download Flux OpenAPI schemas for kubeconform validation
	mkdir -p $(SCHEMAS_DIR)
	curl -sL https://github.com/controlplaneio-fluxcd/flux-operator/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C $(SCHEMAS_DIR)
	curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C $(SCHEMAS_DIR)
	rm -f $(SCHEMAS_DIR)/all.json $(SCHEMAS_DIR)/_definitions.json

clean-schemas: ## Remove downloaded schemas
	rm -rf $(SCHEMAS_DIR)

test-discover: ## Run discovery script on the test fixtures
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/monorepo-structure

test-validate: ## Run validation script on the test fixtures
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/monorepo-structure

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
