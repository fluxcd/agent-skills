# gitops-knowledge

## 2026-03-19

Model: `claude-sonnet-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| OCI Helm chart | 11/11 (100%) | 3/11 (27%) | +73% |
| ResourceSet preview envs | 12/12 (100%) | 6/12 (50%) | +50% |
| Notifications | 16/16 (100%) | 12/16 (75%) | +25% |
| Image automation | 9/9 (100%) | 6/9 (67%) | +33% |
| FluxInstance + ResourceSets | 14/14 (100%) | 11/14 (79%) | +21% |
| **Overall** | **62/62 (100%)** | **38/62 (61%)** | **+39%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 50s | 29s |
| Mean tokens | 39.2k | 11.3k |

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
