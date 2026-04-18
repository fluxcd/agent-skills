# Kustomization Reference

`apiVersion: kustomize.toolkit.fluxcd.io/v1` — managed by kustomize-controller.

Kustomization builds and applies Kustomize overlays or plain Kubernetes YAML from a source
artifact. It is Flux's primary mechanism for deploying manifests to a cluster.

**Important:** This is the Flux `Kustomization` CRD, not Kustomize's `kustomization.yaml` file.
They share the name but are different resources.

## Canonical YAML

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 2m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./deploy/production
  prune: true
  wait: true
  timeout: 5m
  targetNamespace: my-app
  serviceAccountName: flux
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: flux-runtime-info
```

## Key Spec Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sourceRef.kind` | string | yes | `GitRepository`, `OCIRepository`, `Bucket`, or `ExternalArtifact` |
| `sourceRef.name` | string | yes | Source resource name |
| `sourceRef.namespace` | string | no | Cross-namespace reference (disabled by default in multi-tenant) |
| `path` | string | no | Path within the source artifact (default: `.`) |
| `interval` | duration | yes | Reconciliation interval (e.g., `10m`) |
| `retryInterval` | duration | no | Interval between retries on failure |
| `prune` | bool | yes | Delete resources removed from the source (garbage collection) |
| `wait` | bool | no | Wait for all resources to become ready (default: false) |
| `timeout` | duration | no | Timeout for the apply operation (default: `5m`) |
| `targetNamespace` | string | no | Override namespace for all resources |
| `serviceAccountName` | string | no | Service account for impersonation (multi-tenancy) |
| `force` | bool | no | Recreate resources that cannot be patched (default: false) |
| `suspend` | bool | no | Pause reconciliation |
| `deletionPolicy` | string | no | `MirrorPrune` (default), `Delete`, `WaitForTermination`, `Orphan` |
| `commonMetadata.labels` | map | no | Labels applied to all managed resources |
| `commonMetadata.annotations` | map | no | Annotations applied to all managed resources |
| `namePrefix` | string | no | Prefix added to all resource names |
| `nameSuffix` | string | no | Suffix added to all resource names |
| `images` | list | no | Kustomize image overrides (name, newName, newTag, digest) |
| `components` | list | no | Kustomize reusable components (alpha feature) |

## Dependencies

Control reconciliation order with `dependsOn`. The Kustomization waits until all
dependencies are Ready before applying:

```yaml
spec:
  dependsOn:
    - name: infra-controllers
    - name: cert-manager
      namespace: cert-manager
```

Cross-namespace dependencies require the namespace field. Dependencies are evaluated
in the Kustomization's namespace by default.

### Dependency Ready Expression

`dependsOn[].readyExpr` is an optional CEL expression to define custom readiness logic.
The expression has access to `dep` (the dependency object) and `self` (this Kustomization):

```yaml
spec:
  dependsOn:
    - name: app-backend
      readyExpr: >
        dep.metadata.labels['app/version'] == self.metadata.labels['app/version'] &&
        dep.status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True') &&
        dep.metadata.generation == dep.status.observedGeneration
```

When `readyExpr` is specified, it replaces the built-in readiness check.

## PostBuild Variable Substitution

Replace `${VAR}` placeholders in manifests after Kustomize build, before apply.

**Inline variables:**
```yaml
spec:
  postBuild:
    substitute:
      CLUSTER_NAME: production-eu
      DOMAIN: example.com
```

**Variables from ConfigMap/Secret:**
```yaml
spec:
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: flux-runtime-info
      - kind: Secret
        name: cluster-secrets
```

The ConfigMap data keys become variable names:
```yaml
# ConfigMap
data:
  CLUSTER_NAME: production-eu
  DOMAIN: example.com

# In manifests, ${CLUSTER_NAME} becomes "production-eu"
```

Inline `substitute` values override `substituteFrom` values. Multiple `substituteFrom`
entries are merged in order (later entries override earlier).

To use `${VAR}` literally without substitution, escape with `$$`: `$${VAR}` renders as `${VAR}`.

## SOPS Decryption

Decrypt SOPS-encrypted files during build:

```yaml
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age  # Secret with decryption keys
```

The Secret should contain Age private keys (`.agekey` suffix), OpenPGP keys (`.asc` suffix).

Without a `secretRef`, the decryption uses Cloud KMS with workload identity (GCP, AWS, Azure).

## Health Checks

By default, Kustomization checks standard Kubernetes readiness conditions when `wait: true`:

```yaml
spec:
  wait: true
  timeout: 5m
```

Custom health check expressions using CEL (fields: `current` required, `inProgress` and `failed` optional):

```yaml
spec:
  healthCheckExprs:
    - apiVersion: fluxcd.controlplane.io/v1
      kind: ResourceSet
      current: >
        status.conditions.filter(c, c.type == 'Ready').all(c, c.status == 'True' && c.observedGeneration == metadata.generation)
```

If a Kustomization applies a ResourceSet, always add the above healthCheckExprs.

## Remote Cluster Deployment

Two authentication methods for deploying to remote clusters:

**Secret-based** (static kubeconfig in a Secret):
```yaml
spec:
  kubeConfig:
    secretRef:
      name: remote-cluster-kubeconfig  # Secret key defaults to 'value' or 'value.yaml'
```

**ConfigMap-based** (recommended, secret-less via workload identity):
```yaml
spec:
  kubeConfig:
    configMapRef:
      name: remote-cluster-config  # ConfigMap with provider, cluster, address fields
```

The ConfigMap supports `provider` (`aws`, `azure`, `gcp`, `generic`), `cluster` (cloud resource name),
`address`, `ca.crt`, `audiences`, and `serviceAccountName` fields.

When both `kubeConfig` and `serviceAccountName` are specified, the controller impersonates
the service account on the remote cluster (must exist in a namespace matching the Kustomization's namespace).

## Patches

Apply Kustomize-style patches to resources:

```yaml
spec:
  patches:
    - target:
        kind: Deployment
        name: my-app
      patch: |
        - op: replace
          path: /spec/replicas
          value: 3
    - target:
        kind: Service
        labelSelector: "app=my-app"
      patch: |
        - op: add
          path: /metadata/annotations/example.com~1key
          value: "patched"
```

## Status and Inventory

Kustomization tracks all managed resources in `status.inventory`:

```yaml
status:
  inventory:
    entries:
      - id: default_my-app_apps_Deployment
        v: v1
```

The inventory record format is `<namespace>_<name>_<group>_<kind>` and `v` is the API version.

The inventory enables garbage collection — resources in the inventory but not in the
current build are deleted when `prune: true`.

## Controlling Apply Behavior with Annotations

Kustomization uses Kubernetes server-side apply (SSA). Per-resource annotations control behavior:

| Annotation | Default | Values | Purpose |
|-----------|---------|--------|---------|
| `kustomize.toolkit.fluxcd.io/ssa` | `Override` | `Override`, `Merge`, `IfNotPresent`, `Ignore` | Apply policy |
| `kustomize.toolkit.fluxcd.io/force` | `Disabled` | `Enabled`, `Disabled` | Recreate on immutable field changes |
| `kustomize.toolkit.fluxcd.io/prune` | `Enabled` | `Enabled`, `Disabled` | Garbage collection policy |

- `ssa: Override` — Flux owns all fields, reverts `kubectl` edits (default)
- `ssa: Merge` — preserve fields added by other tools (only for non-overlapping fields)
- `ssa: IfNotPresent` — only create if resource doesn't exist (useful for cert-manager Secrets)
- `ssa: Ignore` — skip applying even if in source
- `force: Enabled` — recreate resources with immutable field changes (e.g., Job container image changes)
- `prune: Disabled` — protect resources from garbage collection (e.g., Namespaces, PVCs)

## Triggering Reconciliation

Force immediate reconciliation:
```yaml
metadata:
  annotations:
    reconcile.fluxcd.io/requestedAt: "2024-01-01T00:00:00Z"  # any unique value
```

Or use the Flux CLI:
```bash
flux reconcile kustomization my-app --with-source
```
