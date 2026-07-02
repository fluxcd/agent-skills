# gitops-repo-audit

## v0.1.0 (2026-07-02)

Suite grows from 65 to 76 assertions with new evals: `overlay-effects`, `overlay-stress`. The `monorepo-structure` fixture gained the `source-watcher` component on its FluxInstances (required by its ArtifactGenerator pipeline).

Model: `claude-opus-4-8`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 9/14 (64%) | +36% |
| Multi-repo fleet | 15/16 (94%) | 10/16 (62%) | +32% |
| Image automation | 12/14 (86%) | 10/14 (71%) | +15% |
| Mixed issues | 21/21 (100%) | 14/21 (67%) | +33% |
| Overlay effects | 5/5 (100%) | 5/5 (100%) | 0% |
| Overlay stress | 6/6 (100%) | 6/6 (100%) | 0% |
| **Overall** | **73/76 (96%)** | **54/76 (71%)** | **+25%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 203s | 236s |
| Mean tokens | 58.4k | 42.7k |

---

Model: `claude-sonnet-5`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 11/14 (79%) | +21% |
| Multi-repo fleet | 13/16 (81%) | 11/16 (69%) | +12% |
| Image automation | 13/14 (93%) | 8/14 (57%) | +36% |
| Mixed issues | 20/21 (95%) | 13/21 (62%) | +33% |
| Overlay effects | 5/5 (100%) | 5/5 (100%) | 0% |
| Overlay stress | 6/6 (100%) | 6/6 (100%) | 0% |
| **Overall** | **71/76 (93%)** | **54/76 (71%)** | **+22%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 299s | 249s |
| Mean tokens | 69.5k | 54.8k |

## v0.0.4 (2026-06-11)

Model: `claude-fable-5`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 11/14 (79%) | +21% |
| Multi-repo fleet | 15/16 (94%) | 15/16 (94%) | 0% |
| Image automation | 14/14 (100%) | 12/14 (86%) | +14% |
| Mixed issues | 21/21 (100%) | 15/21 (71%) | +29% |
| **Overall** | **64/65 (98%)** | **53/65 (82%)** | **+16%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 212s | 209s |
| Mean tokens | 53.5k | 33.4k |

## v0.0.2 (2026-03-20)

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 12/14 (86%) | +14% |
| Multi-repo fleet | 16/16 (100%) | 14/16 (88%) | +12% |
| Image automation | 14/14 (100%) | 13/14 (93%) | +7% |
| Mixed issues | 20/21 (95%) | 14/21 (67%) | +28% |
| **Overall** | **64/65 (98%)** | **53/65 (82%)** | **+16%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 183s | 111s |
| Mean tokens | 48.9k | 22.8k |

---

Model: `claude-sonnet-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 9/14 (64%) | +36% |
| Multi-repo fleet | 15/16 (94%) | 10/16 (63%) | +31% |
| Image automation | 11/14 (79%) | 10/14 (71%) | +8% |
| Mixed issues | 21/21 (100%) | 11/21 (52%) | +48% |
| **Overall** | **61/65 (94%)** | **40/65 (62%)** | **+32%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 210s | 129s |
| Mean tokens | 42.7k | 23.2k |

---

Model: `claude-haiku-4-5`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Monorepo structure | 14/14 (100%) | 9/14 (64%) | +36% |
| Multi-repo fleet | 14/16 (88%) | 13/16 (81%) | +7% |
| Image automation | 11/14 (79%) | 8/14 (57%) | +22% |
| Mixed issues | 16/21 (76%) | 9/21 (43%) | +33% |
| **Overall** | **55/65 (85%)** | **39/65 (60%)** | **+25%** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | 108s | 90s |
| Mean tokens | 41.2k | 26.6k |

## v0.0.1 (2026-03-14)

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

---

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
