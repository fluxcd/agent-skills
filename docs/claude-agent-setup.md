# Claude Code Flux CD Sub-Agent Setup

## Prerequisites 

Create a workspace for running the Flux CD agent or use one of your GitOps repositories.

```shell
mkdir -p my-fluxcd-workspace
cd my-fluxcd-workspace
```

Run Claude Code in the workspace and install the Flux CD plugin from the marketplace:

```shell
/plugin marketplace add fluxcd/agent-skills
/plugin install gitops-skills@fluxcd
```

You can restart Claude Code to load the new agent or run the reload command.

To verify the agent is available, run `/agents` and look for `fluxcd` in the list.
Note that the agent inherits the permissions of the Claude Code instance,
so ensure it can run Git and Bash commands, and has access to the necessary tools:

- `flux` for dry running and manifest generation
- `flux-operator` for building and validating Flux Operator manifests
- `awk` for text processing and data extraction
- `yq` for YAML parsing and validation
- `kustomize` for building kustomize overlays
- `kubeconform` for validating Kubernetes manifests against OpenAPI schemas
- `flux-operator-mcp` for debugging Flux on live Kubernetes clusters (required by `gitops-cluster-debug`)

> On macOS and Linux you can install the CLIs using this [Brewfile](https://raw.githubusercontent.com/fluxcd/agent-skills/refs/heads/main/Brewfile).

## Running GitOps Audits

Copy the instructions for Claude to generate audit reports in HTML format
to your workspace under ` instructions/gitops-repo-audit-html.md`:

```shell
mkdir -p instructions
curl -L https://raw.githubusercontent.com/fluxcd/agent-skills/refs/heads/main/instructions/gitops-repo-audit-html.md -o instructions/gitops-repo-audit-html.md
```

Create a directory for saving audit reports:

```shell
mkdir -p reports
```

Multi-repo audit prompt example:

```text
Task: GitOps Audit

Repos:
  - https://github.com/controlplaneio-fluxcd/d2-fleet
  - https://github.com/controlplaneio-fluxcd/d2-infra
  - https://github.com/controlplaneio-fluxcd/d2-apps

For each repo:
  - clone it (just the HEAD) in tmp
  - spawn a fluxcd agent to audit it @.claude/agents/fluxcd.md
  - save the agent's output in a markdown file in @reports in the format `{project}-audit-{YYYY-MM-DD}-{HHMMSS}.md`

When all done:
  - use the @instructions/gitops-repo-audit-html.md to generate a HTML report of the audit results
  - save the aggregated report in the @reports directory
  - delete the cloned repo from tmp
  - open the report in the browser
```

Mono-repo audit prompt example:

```text
Task: GitOps Audit

Repo: https://github.com/controlplaneio-fluxcd/flux-operator-local-dev

Analyze:
  - clone it (just the HEAD) in tmp
  - spawn a fluxcd agent to audit it @.claude/agents/fluxcd.md
  - save the agent's output in a markdown file in @reports in the format `{project}-audit-{YYYY-MM-DD}-{HHMMSS}.md`

When all done:
  - use the @instructions/gitops-repo-audit-html.md to generate an HTML report of the audit results
  - include a dependency graph in the GitOps Delivery Pipeline section of the report
  - save the report in the @reports directory
  - delete the cloned repo from tmp
  - open the report in the browser
```

You can customize the prompts and report generation instructions
as needed for your specific use case and repositories.
