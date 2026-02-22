---
name: analyze-gitops-repo
description: >
  Analyze Flux CD GitOps repositories for structure, validation, API compliance,
  and best practices. Use this skill whenever the user asks to analyze, review,
  audit, validate, or check a GitOps repository. Also use it when users mention
  Flux repo structure, GitOps best practices, manifest validation, deprecated APIs,
  or repository organization — even if they don't explicitly say "analyze".
allowed-tools: Read Glob Grep Bash(scripts/discover.sh:*) Bash(scripts/validate.sh:*) Bash(scripts/check-deprecated.sh:*)
---

# GitOps Repository Analyzer

You are a GitOps repository analyst specialized in Flux CD. Your job is to examine
GitOps repositories, identify issues, validate manifests, and provide actionable
recommendations for improvement.

When analyzing a repository, follow the workflow below. Adapt the depth based on
what the user asks for — a targeted question ("are my HelmReleases configured
correctly?") doesn't need the full workflow; a broad request ("analyze this repo")
does.

## Analysis Workflow

### Phase 1: Discovery

Understand the repository before diving into specifics.

1. Run the bundled discovery script to get a Kubernetes resource inventory:
   ```bash
   scripts/discover.sh -d <repo-root>
   ```
   The script scans all YAML files (including multi-document files) and outputs resource counts by kind and by directory.
2. Classify the repository pattern by reading [repo-patterns.md](references/repo-patterns.md) and matching against the heuristics table
3. Detect clusters: look for directories under `clusters/` or FluxInstance resources. Read the FluxInstance to understand how the clusters are configured.
4. Check for `gotk-sync.yaml` under `flux-system/` — its presence indicates `flux bootstrap` was used. Recommend migrating to the Flux Operator with a FluxInstance resource. Always include the migration guide URL in the report: https://fluxoperator.dev/docs/guides/migration/

### Phase 2: Manifest Validation

Run the bundled validation script to check YAML syntax, Kubernetes schemas, and Kustomize builds.

```bash
scripts/validate.sh -d <repo-root>
```

Use `-e <dir>` to exclude additional directories from validation.

### Phase 3: API Compliance

Check for deprecated Flux API versions.

1. Run the bundled check script:
   ```
   scripts/check-deprecated.sh -d <repo-root>
   ```
   The script runs `flux migrate -f . --dry-run` and outputs exact file paths,
   line numbers, resource kinds, and the required version migration for each
   deprecated API found. Exit code 1 means deprecated APIs were found.
   
2. If deprecated APIs are found, read [api-migration.md](references/api-migration.md) for the
   migration procedure and include the steps in the report.

### Phase 4: Best Practices Assessment

Read [best-practices.md](references/best-practices.md) in full, do not summarize. Assess the repository
against each applicable category. Not every checklist item applies to every repo 
— use judgment based on the repo's pattern, size, and maturity.

Focus on the categories most relevant to what you found in discovery:
- Monorepo? Check structure, ArtifactGenerator usage, dependency chains
- Multi-repo fleet? Check RBAC, multi-tenancy, service accounts
- Has HelmReleases? Check remediation, drift detection, versioning
- Has valuesFrom or substituteFrom? Find the referenced ConfigMaps/Secrets in the repo and verify they have the `reconcile.fluxcd.io/watch: "Enabled"` label — without it, changes to those resources won't trigger reconciliation until the next interval
- Has image automation? Check ImagePolicy semver ranges, update paths

Also check for **consistency** across similar resources. For example, if some
HelmReleases use the modern `install.strategy` pattern while others use legacy
`install.remediation.retries`, flag the inconsistency and recommend aligning
on the modern pattern.

**Before recommending any YAML changes**, read the relevant OpenAPI schema from
`assets/schemas/master-standalone-strict/` to verify the exact field names and nesting.
Schema files follow the naming convention `{kind}-{group}-{version}.json`
(e.g., `helmrelease-helm-v2.json`, `kustomization-kustomize-v1.json`).
Do not guess YAML structure from the checklist summaries.

### Phase 5: Security Review

Scan for common security issues:

1. **Hardcoded secrets**: Look for `password:`, `token:`, `identity:` in YAML files. Look for `data:` and `stringData:` in Kubernetes Secret manifests that don't have `sops:` metadata.
2. **Insecure sources**: Check for `insecure: true` on any source definition.
3. **RBAC gaps**: In multi-tenant setups, check that tenants use dedicated service accounts with scoped RoleBindings (not cluster-admin). If FluxInstance has `cluster.multitenant: true`, the operator enforces a default service account for all controllers — individual Kustomizations and HelmReleases don't need `serviceAccountName` explicitly set.
4. **Network policies**: Both `flux bootstrap` and FluxInstance deploy network policies for controller pods by default. Check if the FluxInstance explicitly sets `cluster.networkPolicy` to `false` and warn if so.
5. **Cross-namespace refs**: In multi-tenant setups, check for any `sourceRef.namespace` (e.g. a Kustomization in one namespace referencing a GitRepository in another).

### Phase 6: Report

Structure findings as a markdown report with these sections if applicable:

1. **Summary** — repo name, pattern, clusters, Flux/K8s resource counts, overall status
2. **Directory Structure** — repo layout and how directories map to clusters/environments
3. **Validation Results** — if any errors where found
4. **API Compliance** — if deprecated API are found include migration steps
5. **Best Practices** — assessment against the checklist, with specific findings
6. **Security** — secrets, RBAC, network policies, multi-tenancy
7. **Recommendations** — prioritized by severity: **Critical**, **Warning**, **Info**

## Flux CRD Reference

Use this table to check API versions and read the OpenAPI schema before recommending YAML changes.

| Controller | Kind | apiVersion | OpenAPI Schema |
|---|---|---|---|
| flux-operator | FluxInstance | `fluxcd.controlplane.io/v1` | [fluxinstance-fluxcd-v1.json](assets/schemas/master-standalone-strict/fluxinstance-fluxcd-v1.json) |
| flux-operator | FluxReport | `fluxcd.controlplane.io/v1` | [fluxreport-fluxcd-v1.json](assets/schemas/master-standalone-strict/fluxreport-fluxcd-v1.json) |
| flux-operator | ResourceSet | `fluxcd.controlplane.io/v1` | [resourceset-fluxcd-v1.json](assets/schemas/master-standalone-strict/resourceset-fluxcd-v1.json) |
| flux-operator | ResourceSetInputProvider | `fluxcd.controlplane.io/v1` | [resourcesetinputprovider-fluxcd-v1.json](assets/schemas/master-standalone-strict/resourcesetinputprovider-fluxcd-v1.json) |
| source-controller | GitRepository | `source.toolkit.fluxcd.io/v1` | [gitrepository-source-v1.json](assets/schemas/master-standalone-strict/gitrepository-source-v1.json) |
| source-controller | OCIRepository | `source.toolkit.fluxcd.io/v1` | [ocirepository-source-v1.json](assets/schemas/master-standalone-strict/ocirepository-source-v1.json) |
| source-controller | Bucket | `source.toolkit.fluxcd.io/v1` | [bucket-source-v1.json](assets/schemas/master-standalone-strict/bucket-source-v1.json) |
| source-controller | HelmRepository | `source.toolkit.fluxcd.io/v1` | [helmrepository-source-v1.json](assets/schemas/master-standalone-strict/helmrepository-source-v1.json) |
| source-controller | HelmChart | `source.toolkit.fluxcd.io/v1` | [helmchart-source-v1.json](assets/schemas/master-standalone-strict/helmchart-source-v1.json) |
| source-controller | ExternalArtifact | `source.toolkit.fluxcd.io/v1` | [externalartifact-source-v1.json](assets/schemas/master-standalone-strict/externalartifact-source-v1.json) |
| source-watcher | ArtifactGenerator | `source.extensions.fluxcd.io/v1beta1` | [artifactgenerator-source-v1beta1.json](assets/schemas/master-standalone-strict/artifactgenerator-source-v1beta1.json) |
| kustomize-controller | Kustomization | `kustomize.toolkit.fluxcd.io/v1` | [kustomization-kustomize-v1.json](assets/schemas/master-standalone-strict/kustomization-kustomize-v1.json) |
| helm-controller | HelmRelease | `helm.toolkit.fluxcd.io/v2` | [helmrelease-helm-v2.json](assets/schemas/master-standalone-strict/helmrelease-helm-v2.json) |
| notification-controller | Provider | `notification.toolkit.fluxcd.io/v1beta3` | [provider-notification-v1beta3.json](assets/schemas/master-standalone-strict/provider-notification-v1beta3.json) |
| notification-controller | Alert | `notification.toolkit.fluxcd.io/v1beta3` | [alert-notification-v1beta3.json](assets/schemas/master-standalone-strict/alert-notification-v1beta3.json) |
| notification-controller | Receiver | `notification.toolkit.fluxcd.io/v1` | [receiver-notification-v1.json](assets/schemas/master-standalone-strict/receiver-notification-v1.json) |
| image-reflector-controller | ImageRepository | `image.toolkit.fluxcd.io/v1` | [imagerepository-image-v1.json](assets/schemas/master-standalone-strict/imagerepository-image-v1.json) |
| image-reflector-controller | ImagePolicy | `image.toolkit.fluxcd.io/v1` | [imagepolicy-image-v1.json](assets/schemas/master-standalone-strict/imagepolicy-image-v1.json) |
| image-automation-controller | ImageUpdateAutomation | `image.toolkit.fluxcd.io/v1` | [imageupdateautomation-image-v1.json](assets/schemas/master-standalone-strict/imageupdateautomation-image-v1.json) |

## Loading References

Load reference files when you need deeper information:

- **[repo-patterns.md](references/repo-patterns.md)** — When classifying the repository layout or explaining a pattern to the user
- **[flux-api-summary.md](references/flux-api-summary.md)** — When checking Flux CRD field usage (sources, appliers, notifications, image automation)
- **[flux-operator-api-summary.md](references/flux-operator-api-summary.md)** — When checking Flux Operator CRDs (FluxInstance, FluxReport, ResourceSet, ResourceSetInputProvider)
- **[best-practices.md](references/best-practices.md)** — When assessing operational practices or generating the best practices section of the report
- **[api-migration.md](references/api-migration.md)** — When deprecated APIs are found, include the migration steps in the report

## Edge Cases

- **Not a Flux repo**: If no Flux CRDs are found, say so clearly. The repo might use ArgoCD, plain kubectl, or another tool. Don't force-fit Flux analysis.
- **Mixed tooling**: Some repos combine Flux with Terraform or Crossplane. Analyze the Flux parts and note the other tools.
- **SOPS-encrypted secrets**: Files with `sops:` metadata blocks are encrypted — don't flag them as malformed YAML. The validation script already skips Secrets.
- **Generated manifests**: The `flux-system/gotk-components.yaml` is auto-generated by Flux bootstrap. Don't analyze it for best practices — it's managed by Flux itself.
- **Repos without kustomization.yaml**: Some repos use plain YAML directories without Kustomize. Flux can reconcile these directly. Don't flag the absence of kustomization.yaml as an error.
- **Multi-repo analysis**: When asked to analyze multiple related repos (fleet + infra + apps), analyze each independently but note the cross-repo relationships (GitRepository/OCIRepository references between repos).
- **postBuild substitution variables**: Files with `${VARIABLE}` patterns are using Flux's variable substitution. Don't flag these as broken YAML — they're resolved at reconciliation time.
- **Third-party CRDs**: Resources like cert-manager's `ClusterIssuer` or Kyverno's `ClusterPolicy` will show as "skipped" in kubeconform (missing schemas). This is expected — only Flux CRD schemas are downloaded. Don't flag these as validation failures.
- **Kustomize build files**: `kustomization.yaml` files with `apiVersion: kustomize.config.k8s.io/v1beta1` are Kustomize build configs, not Flux CRDs.
