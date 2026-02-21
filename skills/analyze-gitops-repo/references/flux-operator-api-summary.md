# Flux Operator API Summary

Condensed reference for the Flux Operator CRDs. For full documentation, see [fluxoperator.dev](https://fluxoperator.dev).

## FluxInstance (`fluxcd.controlplane.io/v1`)

Manages the Flux controllers installation and configuration. Only one per cluster, named `flux` in `flux-system`.

**Key fields:**
- `.spec.distribution.version` — Flux version semver range (e.g., `"2.x"`)
- `.spec.distribution.registry` — Container registry for Flux images
- `.spec.distribution.artifact` — OCI artifact URL for enterprise distribution
- `.spec.components[]` — List of controllers to install (source-controller, kustomize-controller, helm-controller, notification-controller, image-reflector-controller, image-automation-controller)
- `.spec.cluster.type` — `kubernetes` or `openshift`
- `.spec.cluster.size` — Vertical scaling profile: `small` (5 concurrency, 512Mi), `medium` (10 concurrency, 1Gi), `large` (20 concurrency, 3Gi). Sets CPU/memory limits and concurrency for kustomize-controller and helm-controller. Use `small` for edge/tens of apps, `medium` for hundreds, `large` for up to a thousand. For thousands of apps, use sharding instead.
- `.spec.cluster.multitenant` — Enable multi-tenancy lockdown: sets default service account via `tenantDefaultServiceAccount` (defaults to `"default"`), enables `--no-cross-namespace-refs=true` and `--default-service-account` on all controllers. When enabled, individual Kustomizations/HelmReleases don't need `serviceAccountName`
- `.spec.cluster.networkPolicy` — Deploy network policies for controller pods (default: `true`)
- `.spec.sync` — Configure Git/OCI sync for cluster reconciliation (kind, url, ref, path, pullSecret, provider)
- `.spec.sync.provider` — OIDC-based auth provider. For `GitRepository`: `github` (GitHub App auth) or `azure`. For `OCIRepository`/`Bucket`: `aws`, `azure`, `gcp`. When the sync URL points to GitHub (`github.com`), recommend `provider: github` with GitHub App authentication to avoid reliance on personal access tokens.
- `.spec.kustomize.patches[]` — Strategic merge patches for controller deployments

**Pattern:** One FluxInstance per cluster. Use `.spec.sync` to point at the cluster's config directory. For GitHub repos, use `provider: github` with a GitHub App secret for secure, auto-renewing auth.
**Gotcha:** Only one FluxInstance allowed per cluster. Name must be `flux`. Network policies are enabled by default — omitting `networkPolicy` means policies ARE deployed.

## FluxReport (`fluxcd.controlplane.io/v1`)

Read-only, auto-generated status report reflecting the Flux installation state.

**Key status fields:**
- `.spec.distribution` — Installed version and registry info
- `.spec.components[]` — Status of each controller (image, status)
- `.spec.sync` — Sync source and revision info
- `.spec.reconcilers` — Count of running reconcilers by type (Kustomization, HelmRelease, etc.)

**Pattern:** Query with `kubectl get fluxreport flux -n flux-system` for installation health.

## ResourceSet (`fluxcd.controlplane.io/v1`)

Generates groups of Kubernetes resources from a matrix of input values with templated resources.

**Key fields:**
- `.spec.inputs[]` — Array of input objects (each becomes a template iteration)
- `.spec.resources[]` — Templated Kubernetes resources using `<< inputs.field >>` syntax
- `.spec.commonMetadata` — Labels/annotations applied to all generated resources
- `.spec.serviceAccountName` — Service account for impersonation
- `.spec.dependsOn[]` — Other ResourceSets that must be ready first

**Pattern:** Multi-tenant app deployment — one input per tenant generates namespace, RBAC, source, and Kustomization.
**Gotcha:** Template syntax uses `<< >>` delimiters (not `{{ }}`). Supports filters: `quote`, `int`, `base64`, `toJson`.

## ResourceSetInputProvider (`fluxcd.controlplane.io/v1`)

Fetches input values from external services for ResourceSet consumption.

**Key fields:**
- `.spec.type` — `GitHubPullRequest`, `GitHubBranch`, `GitLabMergeRequest`, `GitLabBranch`, `AzureDevOpsPullRequest`, `OCIImageList`
- `.spec.url` — Repository or registry URL
- `.spec.filter.labels[]` — Label filter for PRs/MRs
- `.spec.filter.limit` — Maximum number of inputs to fetch
- `.spec.secretRef` — Authentication secret reference

**Pattern:** PR preview environments — provider fetches open PRs, ResourceSet creates ephemeral environments per PR.
