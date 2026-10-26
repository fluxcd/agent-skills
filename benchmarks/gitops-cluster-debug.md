# gitops-cluster-debug

## v0.4.0 (2026-10-26)

Updates the skill for the flux-operator-mcp v0.62.0 tool set: `trace_kubernetes_resource` to follow a workload or Flux object up to the Flux objects and source that deliver it, `get_kubernetes_events` and `get_kubernetes_logs` at the workload level (with `type`, `since`, `grep`, `limit` and `previous` for crashloops), `get_kubernetes_metrics`, `diff_kubernetes_manifest` to preview a local change against the cluster (new Workflow 9, including reading the live objects to report old → new values), `search_flux_docs`/`read_flux_doc`, `fields` to keep `get_kubernetes_resources` results small, and the write tools (`reconcile_flux_resource`, `patch_kubernetes_resource`, `suspend`/`resume`, `apply`/`delete`) with what to do when the server runs `--read-only`. Workload failures get their own workflow (Workflow 8) that replaces the pod-lookup steps of the old log analysis workflow, and Alert/Provider point at the notification `v1` field indexes.

The evals are new and run against a live cluster: a kind cluster with Kubernetes 1.37, Flux v2.10.0 and Flux Operator v0.62.0, with the broken scenarios from `tests/gitops-cluster-debug/scenarios.yaml` applied — a Kustomization blocked by a GitRepository auth failure, a HelmRelease with a non-existent image tag, a ResourceSet-generated Deployment crashlooping on a missing `DB_PASSWORD`, and a local change to a Kustomization path (`tests/gitops-cluster-debug/podinfo-change`) that lowers a memory limit, raises the HPA maximum and drops the Service. The suite has 5 evals and 32 assertions. Executors ran as `claude -p` with only the `flux-operator-mcp` server started with `--read-only` (12 tools) plus local file and shell tools, with no kubeconfig of their own, so all cluster access went through the MCP server. One run per eval per configuration. Graded by `claude-opus-5-5` from the final report and the executor's tool-call log.

The first with-skill run of `diff-change` reported the new values from the diff but not the old ones, because the diff's JSON patch carries only the new values; Workflow 9 now tells the agent to read the patched fields from the live objects. That run is archived under `_archive/`, and the table shows the rerun.

Model: `claude-sonnet-5-5`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Health check | 6/6 (100%) | 5/6 (83%) | +17% |
| Kustomization Git auth | 6/6 (100%) | 6/6 (100%) | 0% |
| HelmRelease image pull | 7/7 (100%) | 5/7 (71%) | +29% |
| Workload crashloop | 7/7 (100%) | 6/7 (86%) | +14% |
| Change preview (diff) | 6/6 (100%) | 4/6 (67%) | +33% |
| **Overall** | **32/32 (100%)** | **26/32 (81%)** | **+19%** |

The baseline is strong because the MCP server ships its own usage instructions: without the skill the agent still traced the crashlooping Deployment to its ResourceSet, read the previous container's logs at the Deployment level and called `diff_kubernetes_manifest` with the right owner. It was shallower: the health check took the stale FluxReport counters at face value and reported no failing HelmReleases, the HelmRelease run never looked at the chart source or the pods and told the user to fix the tag in Git although the HelmRelease is not managed by a Flux object, and the diff run reported only the new values.

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 28s | 16s |
| Mean tokens | 158.9k | 91.1k |

Token counts include cached prompt reads, which dominate in `claude -p` runs with MCP tools.

**Previous skill vs updated skill** (`claude-opus-5-5`, same scenarios, run before the Workflow 9 old → new step was added)

| Eval | Updated Skill | Previous Skill |
|------|---------------|----------------|
| Health check | 6/6 | 6/6 |
| Kustomization Git auth | 6/6 | 6/6 |
| HelmRelease image pull | 7/7 | 7/7 |
| Workload crashloop | 7/7 | 6/7 |
| Change preview (diff) | 6/6 | 6/6 |
| **Overall** | **32/32 (100%)** | **31/32 (97%)** |

With Opus, the previous skill also reached for the new tools because the MCP server instructions describe them; the only scored difference is that it pulled warning events for the whole namespace instead of the crashing workload. Mean duration and tokens were the same for both (43s vs 40s, 240k vs 241k).
