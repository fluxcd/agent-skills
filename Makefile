# Makefile for maintaining the GitOps AI Skills assets.
# Run 'make help' to see available targets.

SCHEMAS_DIRS := skills/gitops-repo-audit/assets/schemas \
	skills/gitops-cluster-debug/assets/schemas \
	skills/gitops-knowledge/assets/schemas

# The skills ship greppable field indexes (.fields.txt) instead of the raw OpenAPI
# schemas: agents grep a dotted field path instead of reading the full JSON.
# The indexes are pre-built in the flux-schema catalog and vendored here for all
# API groups matching 'fluxcd', renamed from <group>/<kind>_<version>.fields.txt
# to <kind>-<group first label>-<version>.fields.txt.
FLUX_SCHEMA_REPO := https://github.com/fluxcd/flux-schema.git

DISCOVER_SCRIPT := skills/gitops-repo-audit/scripts/discover.sh
VALIDATE_SCRIPT := skills/gitops-repo-audit/scripts/validate.sh
TEST_DIR := tests/gitops-repo-audit

# validate.sh is vendored from the flux-schema action (single source of truth)
VALIDATE_SCRIPT_URL := https://raw.githubusercontent.com/fluxcd/flux-schema/main/actions/validate/validate.sh

.PHONY: help sync-schemas clean-schemas test-discover test-validate validate-skills sync-validate

sync-schemas: clean-schemas ## Vendor the field indexes (.fields.txt) from the flux-schema catalog
	@tmp=$$(mktemp -d); \
	trap 'rm -rf $$tmp' EXIT; \
	git clone --quiet --depth 1 --filter=blob:none --sparse $(FLUX_SCHEMA_REPO) $$tmp; \
	git -C $$tmp sparse-checkout set --no-cone '/catalog/latest/*fluxcd*/*.fields.txt'; \
	for dir in $(SCHEMAS_DIRS); do \
		mkdir -p $$dir; \
		for f in $$tmp/catalog/latest/*fluxcd*/*.fields.txt; do \
			group=$$(basename $$(dirname $$f)); \
			base=$$(basename $$f .fields.txt); \
			t=$$dir/$${base%%_*}-$${group%%.*}-$${base##*_}.fields.txt; \
			cp $$f $$t; \
			echo "synced $$t"; \
		done; \
	done

clean-schemas: ## Remove the vendored field indexes
	@for dir in $(SCHEMAS_DIRS); do \
		rm -rf $$dir; \
	done

test-discover: ## Run discovery script on the test fixtures
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/monorepo-structure
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/image-automation
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/mixed-issues

test-validate: ## Run validation script on the test fixtures
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/monorepo-structure
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/multi-repo-structure
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/image-automation

validate-skills: ## Validate skill packaging against the Agent Skills spec
	gh skill publish --dry-run

sync-validate: ## Vendor validate.sh from the flux-schema action (source of truth)
	curl -fsSL $(VALIDATE_SCRIPT_URL) -o $(VALIDATE_SCRIPT)
	@awk 'NR==1{print; print ""; \
		print "# DO NOT EDIT: this file is vendored from the flux-schema action (single source of truth)."; \
		print "# Source: $(VALIDATE_SCRIPT_URL)"; \
		next} {print}' $(VALIDATE_SCRIPT) > $(VALIDATE_SCRIPT).tmp && mv $(VALIDATE_SCRIPT).tmp $(VALIDATE_SCRIPT)
	chmod +x $(VALIDATE_SCRIPT)

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
