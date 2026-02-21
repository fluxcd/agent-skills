# GitOps AI Skills

[![license](https://img.shields.io/github/license/fluxcd/skills.svg)](https://github.com/fluxcd/skills/blob/main/LICENSE)

A collection of reusable skills for transforming AI Agents into GitOps Engineers
with expertise in Flux, Kubernetes, and best practices for repository structure.

## Skills Overview

### analyze-gitops-repo

Analyze Flux CD GitOps repositories for structure, validation, API compliance,
and best practices. Scans directory layout, validates manifests with kubeconform,
detects deprecated API versions, checks against operational best practices,
and generates a structured report with prioritized recommendations.

```shell
npx skills add https://github.com/fluxcd/skills --skill analyze-gitops-repo
```
