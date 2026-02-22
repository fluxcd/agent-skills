# Flux GitOps Best Practices

Assessment checklist for GitOps repository analysis. Each item is a recommendation —
not all apply to every repo. Judge based on the repo's complexity and maturity.

## Repository Structure

- [ ] **Clear top-level separation**: `apps/`, `infrastructure/`, `clusters/` (monorepo) or dedicated repos for fleet/infra/apps (multi-repo)
- [ ] **Base + overlay pattern**: Shared base configurations with per-environment overlays using Kustomize patches — avoids duplicating entire manifests across environments
- [ ] **One directory per cluster** under `clusters/` with cluster-specific Flux bootstrap or FluxInstance and reconciliation config
- [ ] **Separate controllers and configs** under `infrastructure/`: controllers install CRDs and operators, configs create custom resources that depend on those CRDs
- [ ] **ArtifactGenerator for monorepos**: When using a monorepo, split the source into independent ExternalArtifacts so infra changes don't trigger app reconciliation and vice versa
- [ ] **No Flux bootstrap manifests in app/infra dirs**: `flux-system/` (gotk-components, gotk-sync or FluxInstance) belongs under `clusters/`, not mixed with app resources

## Dependency Management

- [ ] **Explicit dependency chains**: Use `dependsOn` on Kustomizations or ResourceSets to enforce ordering — typically `infra-controllers` → `infra-configs` → `apps`
- [ ] **CRDs before custom resources**: Infrastructure controllers (that install CRDs) must be ready before configs that create CRs using those CRDs
- [ ] **`wait: true` on dependencies**: Kustomizations and ResourceSets that other resources depend on should set `wait: true` so dependents only start after all resources are healthy
- [ ] **HelmRelease dependencies**: Use `dependsOn` when one Helm release requires another (e.g., ingress-nginx depends on cert-manager for TLS)
- [ ] **No circular dependencies**: Verify `dependsOn` chains form a DAG (directed acyclic graph)

## Remediation and Reliability

- [ ] **Install/upgrade strategies on HelmReleases**: Use the modern `install.strategy.name: RetryOnFailure` and `upgrade.strategy.name: RetryOnFailure`.
  The legacy `install.remediation.retries` / `upgrade.remediation.retries` pattern still works but should be flagged for migration
- [ ] **Retry intervals**: Set `retryInterval` on Kustomizations and HelmReleases to avoid overwhelming the API server on failures
- [ ] **Timeouts**: Set `timeout` on Kustomizations and HelmReleases
- [ ] **Drift detection**: Enable `driftDetection.mode: enabled` on production HelmReleases to detect and correct out-of-band changes
- [ ] **Drift detection ignores**: Use `driftDetection.ignore` for fields that are expected to change (e.g., `/spec/replicas` for HPA-managed deployments, annotation fields set by operators)
- [ ] **CRD handling**: Set `install.crds: Create` and `upgrade.crds: CreateReplace` on HelmReleases that manage CRDs
- [ ] **Reactivity**: ConfigMaps and Secrets used in `valuesFrom` and `postBuild.substituteFrom` should be labeled with `reconcile.fluxcd.io/watch: Enabled` to trigger immediate reconciliation on changes instead of waiting for the next interval

## Versioning

- [ ] **Semver ranges on charts**: Use semver constraints (e.g., `>=1.0.0`, `6.5.*`) instead of `*` or `latest`
- [ ] **Environment-differentiated versions**: Staging uses broader ranges (e.g., `>=1.0.0-alpha`) for early adoption; production uses stable-only ranges (e.g., `>=1.0.0`)
- [ ] **Pinned source refs**: Use specific branches, tags, or semver for GitRepository/OCIRepository — avoid `latest` in production
- [ ] **OCI artifact tagging**: Use immutable tags (semver or digest) for production; `latest` or `*` only for staging/development

## Namespace Isolation

- [ ] **Per-app namespaces**: Each application and set of microservices deployed in dedicated namespace to limit blast radius
- [ ] **Tenant labels**: Use `toolkit.fluxcd.io/tenant` labels on namespaces for multi-tenancy grouping
- [ ] **`targetNamespace` on Kustomizations**: Set when the source manifests don't include namespace metadata for apps 

## Security

- [ ] **No plain-text secrets in Git**: Use SOPS encryption (`.spec.decryption` on Kustomizations) or External Secrets Operator. Search for `kind: Secret` without `sops:` to identify any unencrypted secrets. Search for `spec.values` in HelmReleases and `spec.postBuild.substitute` in Kustomizations to find potentially hardcoded sensitive values.
- [ ] **Read-only Git credentials**: Use deploy keys or read-only PATs, or read-only GitHub App for GitRepository auth
- [ ] **Network policies**: Both `flux bootstrap` and FluxInstance deploy network policies for controller pods by default. For FluxInstance, `cluster.networkPolicy` defaults to `true` — only flag if explicitly set to `false`. For bootstrap installs, policies are in `gotk-components.yaml`. Do not flag as missing unless intentionally removed
- [ ] **Source verification**: Use Cosign verification on OCI sources (`.spec.verify.provider: cosign`)
- [ ] **No `insecure: true`**: All source definitions should use TLS (the default)
- [ ] **Workload Identity for cloud registries**: OCIRepositories pointing to AWS (ECR), GCP (Artifact Registry/GCR), or Azure (ACR) should set `.spec.provider` to `aws`, `gcp`, or `azure` to use Workload Identity instead of static credentials stored in Secrets
- [ ] **Secret references present**: Sources requiring auth that don't use Workload Identity should have `.spec.secretRef` configured

## Multi-Tenancy

- [ ] **Service accounts per tenant**: Each tenant's Kustomizations and HelmReleases use a dedicated `serviceAccountName` with scoped RBAC. Note: if FluxInstance has `cluster.multitenant: true`, the operator sets a default service account for all controllers via `tenantDefaultServiceAccount` — individual resources don't need to specify `serviceAccountName` explicitly
- [ ] **No cross-namespace refs**: Enable `--no-cross-namespace-refs=true` on controllers (via FluxInstance `multitenant: true` or kustomize patches)
- [ ] **Default service account enforcement**: Set `--default-service-account=default` on controllers to prevent privilege escalation
- [ ] **Admission policies**: Use ValidatingAdmissionPolicy or Kyverno ClusterPolicies to restrict source URLs and enforce resource policies
- [ ] **Runtime info substitution**: Use ConfigMaps with `postBuild.substituteFrom` for cluster-specific variables (environment, domain, branch) rather than hardcoding values

## Flux Operator

- [ ] **Cluster size**: If a FluxInstance is present, ensure `.spec.cluster.size` is set (`small`, `medium`, or `large`). This configures vertical scaling (CPU/memory limits, concurrency) for kustomize-controller and helm-controller appropriate to the cluster's workload. Without it, controllers use default resource limits which may be insufficient for larger deployments.
- [ ] **GitHub App auth for sync**: If a FluxInstance uses `sync.kind: GitRepository` with a GitHub URL, recommend setting `sync.provider: github` with GitHub App authentication to avoid reliance on personal access tokens. The secret should contain `githubAppID`, `githubAppInstallationID`, and `githubAppPrivateKey` fields.

## Operational Excellence

- [ ] **Alerts configured**: At minimum, error-severity Alerts with a Provider (Slack, Teams, etc.) for production clusters
- [ ] **Receivers for webhooks**: Configure Receivers to trigger immediate reconciliation on Git push instead of waiting for polling interval
- [ ] **Appropriate intervals**: Sources polled frequently (5m-15m), reconciliation intervals longer (30m-1h), drift detection at reconciliation interval
- [ ] **CI validation pipeline**: Run `validate.sh` (YAML syntax + kubeconform + kustomize build) in CI before merging
- [ ] **`prune: true` on all Kustomizations**: Enables garbage collection of resources removed from source
- [ ] **Image automation**: For container images that need automatic updates, configure ImageRepository + ImagePolicy + ImageUpdateAutomation
- [ ] **Monitoring**: Deploy kube-prometheus-stack or similar with ServiceMonitors/PodMonitors for Flux controllers

## Flux Operator Migration

- [ ] **Migrate from bootstrap to Flux Operator**: If `gotk-sync.yaml` is found in the repo (generated by `flux bootstrap`),
  recommend migrating to the Flux Operator with a `FluxInstance` resource for declarative Flux lifecycle management.
  Recommend https://fluxoperator.dev/docs/guides/migration/ for zero-downtime migration steps.

## Up-to-date API versions

- [ ] **Current API versions**: All Flux resources use the latest stable API versions (see CRD version table in SKILL.md)
- [ ] **No deprecated fields**: HelmRelease uses `install.strategy`/`upgrade.strategy` instead of legacy `install.remediation`/`upgrade.remediation` pattern
- [ ] **`chartRef` for OCI**: HelmReleases referencing OCI charts use `.spec.chartRef` (pointing to OCIRepository) instead of inline `.spec.chart.spec` with HelmRepository
- [ ] **No `HelmRepository` with `type: oci`**: `HelmRepository` with `.spec.type: oci` is a legacy pattern. Migrate to `OCIRepository` with `.spec.chartRef` on the HelmRelease instead — it supports signature verification, semver policies, and layer selection that `HelmRepository` OCI mode does not
- [ ] **Run `flux migrate`**: Use `flux migrate -f . --dry-run` to detect and automatically fix deprecated API versions
