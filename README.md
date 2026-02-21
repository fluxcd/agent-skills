# GitOps AI Skills

[![license](https://img.shields.io/github/license/fluxcd/skills.svg)](https://github.com/fluxcd/skills/blob/main/LICENSE)

A collection of reusable skills for transforming AI Agents into GitOps Engineers
with expertise in Flux, Kubernetes, and best practices for repository structure.

## Install

Install skills for Agents with support for `.agents/skills` e.g. Codex, Gemini, etc:

```shell
npx skills add https://github.com/fluxcd/skills
```

For Claude Code, first add the marketplace:

```shell
/plugin marketplace add fluxcd/skills
```

Then install the `gitops-skills` plugin:

```shell
/plugin install gitops-skills@fluxcd
```

## Skills

### analyze-gitops-repo

This skill is for analyzing Flux GitOps repositories for structure, validation, API compliance,
and best practices. Scans directory layout, validates manifests with kubeconform,
detects deprecated API versions, checks against operational best practices,
and generates a structured report with prioritized recommendations.

To invoke the skill, use the following prompt:

```
Analyze the current repo and provide a GitOps report.
```

In Claude Code, you can also invoke the skill directly with `/analyze-gitops-repo`.
