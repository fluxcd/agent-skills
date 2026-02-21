# GitOps AI Skills

[![license](https://img.shields.io/github/license/fluxcd/skills.svg)](https://github.com/fluxcd/skills/blob/main/LICENSE)

A collection of reusable skills for transforming AI Agents into GitOps Engineers
with expertise in Flux, Kubernetes, and best practices for repository structure.

## Install

Install skills for Agents with support for `.agents/skills` e.g. Codex, Gemini, etc:

```shell
npx skills add https://github.com/fluxcd/skills
```

Add all skills to [Claude Code](https://code.claude.com/docs/en/discover-plugins#add-from-github):

```shell
/plugin marketplace add fluxcd/skills
```

## Skills Overview

### analyze-gitops-repo

Analyze Flux CD GitOps repositories for structure, validation, API compliance,
and best practices. Scans directory layout, validates manifests with kubeconform,
detects deprecated API versions, checks against operational best practices,
and generates a structured report with prioritized recommendations.
