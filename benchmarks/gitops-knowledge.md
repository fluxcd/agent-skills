# gitops-knowledge

## 2026-03-14

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| OCI Helm chart | 11/11 (100%) | 4/11 (36%) | +64% |
| ResourceSet preview envs | 12/12 (100%) | 9/12 (75%) | +25% |
| Notifications | 16/16 (100%) | 13/16 (81%) | +19% |
| Image automation | 9/9 (100%) | 6/9 (67%) | +33% |
| FluxInstance + ResourceSets | 14/14 (100%) | 10/14 (71%) | +29% |
| **Overall** | **62/62 (100%)** | **42/62 (68%)** | **+32%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 41s | 20s |
| Mean tokens | 36.9k | 11.2k |
