# GitOps Agent Skills

[![license](https://img.shields.io/github/license/fluxcd/skills.svg)](https://github.com/fluxcd/skills/blob/main/LICENSE)

A collection of reusable skills that give AI Agents expertise in Flux CD,
Kubernetes, and GitOps best practices for auditing repository structure, security,
operational readiness, and debugging live cluster installations.

> [!IMPORTANT]
> This project is under active development. Skill definitions, reference files,
> and evaluation criteria may change in a backwards incompatible manner.

## Install

Install skills for AI Agents with support for `.agents/skills` e.g. Codex, Copilot, Gemini, etc:

```shell
npx skills add https://github.com/fluxcd/agent-skills
```

For Claude Code, add the marketplace and install the skills with:

```shell
/plugin marketplace add fluxcd/agent-skills
/plugin install gitops-skills@fluxcd
```

## Prerequisites

The skills in this repository rely on the following tools being available in the environment:

- `flux` for dry running and manifest generation
- `yq` for YAML parsing and validation
- `kustomize` for building kustomize overlays
- `kubeconform` for validating Kubernetes manifests against OpenAPI schemas
- `flux-operator-mcp` for debugging Flux on live Kubernetes clusters (required by `gitops-cluster-debug`)

A [Brewfile](https://raw.githubusercontent.com/fluxcd/agent-skills/refs/heads/main/Brewfile) is provided for easy installation of the prerequisites on macOS.

## Available Skills

### gitops-repo-audit

Audits Flux GitOps repositories for structure, security, and operational best practices.
Validates manifests against OpenAPI schemas, detects deprecated API versions,
reviews secrets management, source authentication, RBAC and multi-tenancy configuration,
and generates a structured report with prioritized recommendations.

To invoke the skill, use the following prompt:

```text
Audit the current repo and provide a GitOps report.
```

In Claude Code, you can also invoke the skill directly with `/gitops-repo-audit`.

To run only the manifest validation phase, use:

```text
Validate my repo without auditing it.
```

This prompt can be used when changes have been made to the repository,
and you want to re-run the validation checks without performing a full audit.

You can also use the skill to audit only the files with changes:

```text
Run a GitOps audit only on the files with changes.
```

### gitops-cluster-debug

Debugs and troubleshoots Flux CD on live Kubernetes clusters using the
[Flux MCP](https://fluxoperator.dev/mcp-server/) server. Inspects Flux installation health, diagnoses
HelmRelease and Kustomization failures, analyzes pod logs and traces dependency chains.

To invoke the skill, use the following prompts:

```text
Check the Flux installation on my current cluster.
```

```text
Debug the failing HelmRelease podinfo in the apps namespace on my current cluster.
```

```text
Troubleshoot the Kustomization flux-system/infra-controllers in the staging cluster.
```

The `flux-operator-mcp` server can be configured in Claude Code with:

```bash
claude mcp add --scope user --transport stdio flux-operator-mcp \
  --env KUBECONFIG=$HOME/.kube/config \
  -- flux-operator-mcp serve --read-only
```

Note that the `--read-only` flag is will prevent the Agent from making any changes to the cluster.
The MCP server masks Kubernetes Secrets, the Agent receives only the data key names without values.

## Skill Structure

Each skill follows the [Agent Skills Open Standard](https://agentskills.io/):

- `SKILL.md` - Instructions for the agent
- `scripts/` - Helper scripts for automation
- `references/` - Supporting documentation
