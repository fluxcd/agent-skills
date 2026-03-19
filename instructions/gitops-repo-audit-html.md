# GitOps Audit HTML Report Generation Instructions

Instructions for generating an HTML report from Flux CD audit results. The audit has already been run — this document describes how to format the findings into a self-contained HTML file.

## 1. Report Structure

The HTML report is a single self-contained file with inline CSS. No external dependencies.

### Header

```html
<h1>{Project} GitOps Audit Report</h1>
<p class="subtitle">
  Generated {YYYY-MM-DD} — Flux CD repository analysis of {repo1}, {repo2}, ...
  <br>{Model name} — {N} sub-agents — {N} tool calls — {N}K tokens — {N} min
</p>
```

- **Date**: current date
- **Model**: the LLM used (e.g., Claude Opus 4.6)
- **Sub-agents**: number of parallel fluxcd agents launched (if applicable)
- **Tool calls**: sum of `tool_uses` across all agents
- **Tokens**: sum of `total_tokens` across all agents (rounded to nearest K)
- **Time**: wall clock time = max `duration_ms` across agents (they run in parallel), rounded

### Section: Repository Overview

1. **Overview cards** — one card per repo in a responsive grid:
   - Repo name — linked to the repo's `<h2 id="repo-name">` section (e.g., `<a href="#k8s-fleet">k8s-fleet</a>`)
   - Status badge: "Well-Architected" (green) / "Actionable Findings" (amber) / similar
   - Key metrics rendered as chip spans — bold count + muted kind label, flex-wrapped:
     ```html
     <div class="meta">
       <span class="stat"><span class="stat-count">5</span><span class="stat-kind">FluxInstance</span></span>
       <span class="stat"><span class="stat-count">16</span><span class="stat-kind">ResourceSet</span></span>
       <span class="stat"><span class="stat-count">6</span><span class="stat-kind">Kustomization</span></span>
     </div>
     ```
   - No description here — descriptions go under each repo's detail section

2. **Summary table** — columns: Check | repo1 | repo2 | ...
   - Rows: Classification (repository pattern name), YAML Validation, Schema Validation (with total resource count), Deprecated APIs, Secrets Management, Security, Drift Detection, Multi-Tenancy
   - Add footnotes for notable exceptions (e.g., `* Critical: hardcoded credentials found`)

### Section: GitOps Delivery Pipeline

An inline SVG diagram showing the delivery flow. **Read the FluxInstance `spec.sync.kind` for each cluster first** — the layout depends on the sync source type:

**OCI-based delivery** (`kind: OCIRepository`) — 4 columns:

| Column | Content |
|--------|---------|
| GIT | Repos stacked vertically |
| CI / CD | Single CI box (e.g., "GitHub Actions") with subtitle (e.g., "flux push + cosign") |
| REGISTRY | Single registry box (e.g., "AWS ECR") with subtitle (e.g., "Flux Artifacts") |
| CLUSTERS | Target clusters stacked vertically |

**Git-based delivery** (`kind: GitRepository`) — 2 columns:

| Column | Content |
|--------|---------|
| GIT | Repos stacked vertically |
| CLUSTERS | Target clusters stacked vertically |

Arrows flow directly from repos to clusters (Flux polls Git; no CI push step, no registry column).

Rules:
- Arrows flow left to right
- If there is a primary/orchestrator repo, highlight it with blue fill and blue border
- Other repo boxes use white fill with gray border
- Cluster boxes use green fill with green border
- One-line footer text summarizing the flow
- Order clusters: non-production first, then production
- Keep it minimal — no excessive labels, badges, or decorations
- Adapt column labels and box contents to match the actual project (CI provider, registry, cluster type)
- Only include deployment-target clusters (exclude utility clusters that run elsewhere, e.g., image automation on KinD)
- **Each cluster box must include a subtitle line** showing the `ref` and `path` from its FluxInstance `spec.sync` — read the FluxInstance YAML for each cluster before drawing the diagram. Format: `{ref} · {path}` (e.g., `latest-stable · clusters/prod-us` or `main · clusters/prod-us`). This reveals the promotion model at a glance
- Make cluster boxes tall enough to fit two lines of text (height ~38px vs 26px for single-line boxes)
- **Each repo box must include a subtitle line** showing the Git org/owner name below the repo name. Make repo boxes ~38px tall to fit both lines

### Per-Repository Sections

One `<h2 id="{repo-name}">` section per repository (the `id` matches the overview card anchor). Each contains:

1. **Description** — one line under the h2 explaining the repo's role
2. **Structure** — `<pre><code>` tree showing directory layout
3. **Security Checks** — checklist using `check-pass`, `check-warn`, `check-fail` CSS classes:
   - ✓ for passing checks (green)
   - ⚠ for warnings (amber)
   - ✗ for failures (red)
4. **Best Practices Checks** — same checklist format
5. **Findings** — ordered by severity (critical first, then warning, then info):

```html
<div class="finding critical|warning|info">
  <div class="finding-header">
    <span class="badge badge-critical|badge-warning|badge-info">CRITICAL|WARNING|INFO</span>
    <span class="finding-title">{ID}. {Title}</span>
  </div>
  <div class="finding-file">{file path and line numbers}</div>
  <div class="finding-body">
    <p>{Description and recommendation}</p>
    <pre><code>{code snippet if relevant}</code></pre>
  </div>
</div>
```

- Each finding has an ID: C1, C2 (critical), W1, W2 (warning), I1, I2 (info)
- IDs are scoped per repository (each repo starts from 1)
- Include file paths and line numbers where applicable
- Include code snippets for critical findings
- Include recommended fix code where helpful

### Section: Cross-Repository Observations

Only include this section when auditing multiple repos. Use cards (`<div class="cross-repo">`) highlighting patterns that span repos:

- Supply chain gaps (e.g., signing without verification)
- Consistency issues (e.g., one repo has controls that others lack)
- Most urgent fix across all repos

### Finding Summary Table

Final table at the bottom of the cross-repo section (or after the last repo section if single-repo audit):

| Severity | repo1 | repo2 | ... | Total |
|----------|-------|-------|-----|-------|

### Footer

```html
<footer>{Project} GitOps Audit — Generated by Flux CD Agent — {YYYY-MM-DD}</footer>
```

## 2. Design Rules

- **Minimal design** — no TOC, no emojis, no excessive decoration
- **Self-contained** — all CSS inline in `<style>`, no external resources
- **Max width**: 1100px body, 820px SVG diagram
- **Font**: system font stack (`-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`)
- **Severity colors**: critical=red (`#dc2626`), warning=amber (`#d97706`), info=blue (`#2563eb`), pass=green (`#16a34a`)
- **Code blocks**: SF Mono/Menlo/Consolas, gray background (`#f3f4f6`)
- **Tables**: full width, collapsed borders, uppercase muted headers
- **Findings**: left-colored border (4px) with tinted background matching severity
- **Overview cards**: white background, gray border, rounded corners

## 3. Naming Convention

```
{project}-report-{YYYY-MM-DD}-{HHMMSS}.html
```

## 4. CSS Template

Use this complete CSS block in every report:

```css
:root {
  --bg: #fdfdfd;
  --fg: #1a1a1a;
  --muted: #6b7280;
  --border: #e5e7eb;
  --critical: #dc2626;
  --critical-bg: #fef2f2;
  --warning: #d97706;
  --warning-bg: #fffbeb;
  --info: #2563eb;
  --info-bg: #eff6ff;
  --pass: #16a34a;
  --pass-bg: #f0fdf4;
  --card-bg: #ffffff;
  --code-bg: #f3f4f6;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--fg); line-height: 1.6; padding: 2rem; max-width: 1100px; margin: 0 auto; }
h1 { font-size: 1.75rem; font-weight: 700; margin-bottom: 0.25rem; }
.subtitle { color: var(--muted); font-size: 0.9rem; margin-bottom: 2rem; }
h2 { font-size: 1.3rem; font-weight: 600; margin: 2.5rem 0 0.75rem; padding-bottom: 0.5rem; border-bottom: 2px solid var(--border); }
h3 { font-size: 1.05rem; font-weight: 600; margin: 1.5rem 0 0.5rem; }
p, li { font-size: 0.9rem; }
ul { padding-left: 1.25rem; margin: 0.5rem 0; }
li { margin: 0.25rem 0; }
code { font-family: 'SF Mono', Menlo, Consolas, monospace; font-size: 0.82rem; background: var(--code-bg); padding: 0.15rem 0.35rem; border-radius: 3px; }
pre { background: var(--code-bg); padding: 0.75rem 1rem; border-radius: 6px; overflow-x: auto; margin: 0.5rem 0; font-size: 0.8rem; line-height: 1.5; }
pre code { background: none; padding: 0; }

.overview { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1rem; margin: 1.5rem 0; }
.overview-card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; }
.overview-card h3 { margin: 0 0 0.5rem; font-size: 1rem; }
.overview-card .status { display: inline-block; font-size: 0.75rem; font-weight: 600; padding: 0.15rem 0.5rem; border-radius: 9999px; margin-bottom: 0.5rem; }
.status-good { background: var(--pass-bg); color: var(--pass); }
.status-warn { background: var(--warning-bg); color: var(--warning); }
.meta { display: flex; flex-wrap: wrap; gap: 0.3rem; margin-top: 0.4rem; }
.stat { display: inline-flex; align-items: baseline; gap: 0.25rem; background: var(--code-bg); border: 1px solid var(--border); border-radius: 4px; padding: 0.2rem 0.5rem; font-size: 0.78rem; line-height: 1.4; white-space: nowrap; }
.stat-count { font-weight: 700; color: var(--fg); }
.stat-kind { color: var(--muted); }

.finding { border: 1px solid var(--border); border-radius: 8px; padding: 1rem 1.25rem; margin: 0.75rem 0; border-left: 4px solid var(--border); }
.finding.critical { border-left-color: var(--critical); background: var(--critical-bg); }
.finding.warning { border-left-color: var(--warning); background: var(--warning-bg); }
.finding.info { border-left-color: var(--info); background: var(--info-bg); }
.finding.pass { border-left-color: var(--pass); background: var(--pass-bg); }
.finding-header { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.35rem; }
.badge { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; padding: 0.1rem 0.45rem; border-radius: 3px; color: #fff; }
.badge-critical { background: var(--critical); }
.badge-warning { background: var(--warning); }
.badge-info { background: var(--info); }
.badge-pass { background: var(--pass); }
.finding-title { font-weight: 600; font-size: 0.9rem; }
.finding-file { font-size: 0.78rem; color: var(--muted); margin-bottom: 0.35rem; }
.finding-body { font-size: 0.85rem; }

table { width: 100%; border-collapse: collapse; margin: 0.75rem 0; font-size: 0.85rem; }
th, td { text-align: left; padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); }
th { font-weight: 600; font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.03em; }

.section-checks { margin: 0.75rem 0; }
.check { display: flex; align-items: baseline; gap: 0.4rem; font-size: 0.85rem; margin: 0.25rem 0; }
.check-pass::before { content: "\2713"; color: var(--pass); font-weight: 700; }
.check-warn::before { content: "\26A0"; color: var(--warning); }
.check-fail::before { content: "\2717"; color: var(--critical); font-weight: 700; }

.cross-repo { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; margin: 1rem 0; }

footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border); color: var(--muted); font-size: 0.78rem; text-align: center; }
```

## 5. SVG Diagram Template

Use this as the base for the pipeline diagram, adjusting repos, clusters, labels, and arrow coordinates to fit the project:

```html
<svg viewBox="0 0 790 220" xmlns="http://www.w3.org/2000/svg"
  style="width:100%;max-width:820px;margin:1rem auto;display:block;
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <defs>
    <marker id="ah" markerWidth="7" markerHeight="5" refX="7" refY="2.5" orient="auto">
      <path d="M0,0 L7,2.5 L0,5" fill="#9ca3af"/>
    </marker>
    <marker id="ah-b" markerWidth="7" markerHeight="5" refX="7" refY="2.5" orient="auto">
      <path d="M0,0 L7,2.5 L0,5" fill="#3b82f6"/>
    </marker>
  </defs>

  <!-- Col 1: Git repos (stacked vertically, ~150px wide, starting x=0) -->
  <text x="75" y="16" text-anchor="middle" font-size="9"
    font-weight="600" fill="#9ca3af" letter-spacing="0.04em">GIT</text>
  <!-- Add one rect+text block per repo, y increments of ~54px -->

  <!-- Col 2: CI box (~140px wide, centered at x=210, vertically centered) -->
  <text x="280" y="16" text-anchor="middle" font-size="9"
    font-weight="600" fill="#9ca3af" letter-spacing="0.04em">CI / CD</text>

  <!-- Col 3: Registry box (~140px wide, centered at x=410, vertically centered) -->
  <text x="480" y="16" text-anchor="middle" font-size="9"
    font-weight="600" fill="#9ca3af" letter-spacing="0.04em">REGISTRY</text>

  <!-- Col 4: Clusters (stacked vertically, ~120px wide, starting x=610) -->
  <text x="670" y="16" text-anchor="middle" font-size="9"
    font-weight="600" fill="#9ca3af" letter-spacing="0.04em">CLUSTERS</text>
  <!-- Add one rect+text block per cluster, y increments of ~42px -->

  <!-- Arrows: repos→CI, CI→registry, registry→clusters -->
  <!-- Use marker-end="url(#ah)" for gray, url(#ah-b) for blue (primary repo) -->

  <!-- Footer text -->
  <text x="350" y="205" text-anchor="middle" font-size="8.5" fill="#9ca3af">
    {One-line summary of the delivery flow}
  </text>
</svg>
```

Color reference for SVG elements:

| Element | Fill | Stroke |
|---------|------|--------|
| Primary repo | `#eff6ff` | `#3b82f6` (1.5px) |
| Other repos | `#fff` | `#d1d5db` (1.2px) |
| CI box | `#f3f4f6` | `#d1d5db` (1.2px) |
| Registry box | `#fefce8` | `#eab308` (1.2px) |
| Cluster boxes | `#f0fdf4` | `#22c55e` (1.1px) |
| Arrows (default) | — | `#9ca3af` (1.2px) |
| Arrows (primary) | — | `#3b82f6` (1.2px) |
| Column headers | — | fill `#9ca3af`, font-size 9, font-weight 600 |
