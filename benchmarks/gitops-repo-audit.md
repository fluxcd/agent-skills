# gitops-repo-audit

## 2026-03-19

Model: `claude-sonnet-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 9/14 (64%) | +36% |
| Multi-repo fleet | 16/16 (100%) | 14/16 (88%) | +12% |
| Image automation | 11/12 (92%) | 11/12 (92%) | 0% |
| Mixed issues | 20/20 (100%) | 12/20 (60%) | +40% |
| **Overall** | **61/62 (98%)** | **46/62 (74%)** | **+24%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 238s | 140s |
| Mean tokens | 45.3k | 24.4k |

## 2026-03-14

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 11/14 (79%) | +21% |
| Multi-repo fleet | 16/16 (100%) | 13/16 (81%) | +19% |
| Image automation | 12/12 (100%) | 10/12 (83%) | +17% |
| Mixed issues | 18/20 (90%) | 14/20 (70%) | +20% |
| **Overall** | **60/62 (97%)** | **48/62 (77%)** | **+20%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 134s | 91s |
| Mean tokens | 37.4k | 20.5k |
