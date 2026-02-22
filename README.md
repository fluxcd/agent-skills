# GitOps AI Skills

[![license](https://img.shields.io/github/license/fluxcd/skills.svg)](https://github.com/fluxcd/skills/blob/main/LICENSE)

A collection of reusable skills for transforming AI Agents into GitOps Engineers
with expertise in Flux, Kubernetes, and best practices for repository structure.

## Install

Install skills for Agents with support for `.agents/skills` e.g. Codex, Copilot, Gemini, etc:

```shell
npx skills add https://github.com/fluxcd/skills
```

For Claude Code, add the marketplace and install the skills with:

```shell
/plugin marketplace add fluxcd/skills
/plugin install gitops-skills@fluxcd
```

## Skills

### analyze-gitops-repo

This skill is for analyzing Flux GitOps repositories for structure, validation, API compliance,
and best practices. Scans directory layout, validates manifests,
detects deprecated API versions, checks against operational best practices,
and generates a structured report with prioritized recommendations.

The following tools are used by the skill and must be available in the environment for it to work properly:

- `flux` for deprecated API detection
- `curl` for fetching Flux OpenAPI schemas from GitHub
- `yq` for YAML parsing and validation
- `kustomize` for building kustomize overlays
- `kubeconform` for validating Kubernetes manifests against OpenAPI schemas

To invoke the skill, use the following prompt:

```text
Analyze the current repo and provide a GitOps report.
```

In Claude Code, you can also invoke the skill directly with `/analyze-gitops-repo`.

To run only the manifest validation phase, use:

```text
Validate my repo without analyzing it.
```

This prompt can be used when changes have been made to the repository, 
and you want to re-run the validation checks without performing a full analysis.

You can also use the skill to analyze only the files with changes:

```text
Run a GitOps analysis only on the files with changes.
```
