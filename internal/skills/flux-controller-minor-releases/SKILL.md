---
name: flux-controller-minor-releases
description: >
  Run the upstream Flux controller minor release procedure for helm-controller,
  image-automation-controller, image-reflector-controller, kustomize-controller,
  notification-controller, source-controller, and source-watcher. Use when
  cutting a new controller minor release (vX.Y.0): creating the release series
  branch, drafting the minor changelog, tagging, merging the release branch back
  to main, and adding the backport label.
license: Apache-2.0
---

# Flux Controller Minor Releases

Use this skill for upstream Flux controller **minor** releases (`vX.Y.0`) only —
the release that opens a new `release/vX.Y.x` series. Do not use it for `flux2`,
`pkg`, or other non-controller repos.

Supported controllers:
- `helm-controller`
- `image-automation-controller`
- `image-reflector-controller`
- `kustomize-controller`
- `notification-controller`
- `source-controller`
- `source-watcher`

## Important rules

- **Strictly follow the documented git commands, one step at a time.** Each step
  below has a reason. Do not invent substitutions, batch unrelated commands into
  one shell invocation, or insert extra verification commands between documented
  steps unless asked. Adapt only the version numbers.
- **Never block the conversation on long-running operations.** CI checks, the
  tag-triggered release workflow, and approval waits must be watched in the
  background (`run_in_background`) so the user can keep steering and you get
  notified on completion. A foreground watch blocks the session.
- **Always quote PR/issue links as full URLs** (e.g.
  `https://github.com/fluxcd/source-controller/pull/2082`), never the
  `<owner>/<repo>#<number>` shorthand — full URLs are clickable from the user's
  terminal.
- **Start background watches on every PR immediately after opening it.** Kick off
  `gh pr checks <num> -R fluxcd/<repo> --watch` in the background as soon as the
  PR is created, and the same for tag-triggered release workflows
  (`gh run watch <id> -R fluxcd/<repo>`).
- **Also start a background approval watch per PR.** `gh pr checks --watch` only
  covers CI, not maintainer approval. Poll the review state in the background:
  ```
  while :; do
    state=$(gh pr view <num> -R fluxcd/<repo> --json mergeStateStatus,reviewDecision --jq '.reviewDecision+" "+.mergeStateStatus')
    case "$state" in "APPROVED CLEAN") echo "$state"; break;; esac
    sleep 30
  done
  ```
- Every git commit must use `-s` (sign-off). Never include Co-Authored-By lines,
  your own name, or any AI attribution in commit messages, PR titles, or PR
  descriptions. This applies to the skill-update PR too.
- Always wait for CI to go green before merging any PR.
- You cannot approve your own PRs. If a PR was opened by the git user driving the
  session, ask a maintainer to approve it (or confirm it is already approved)
  before merging.
- **Merge release PRs yourself** as soon as CI is green **and** a maintainer has
  approved — act immediately so the next step (tag push, merge to main, label PR)
  unblocks. Applies only to PRs opened with the user's account this session.
- **Review feedback on the release PR is applied by amending**, not by adding new
  commits. The release PR must stay at exactly two commits
  (`Add changelog entry for vX.Y.0` and `Release vX.Y.0`). Use
  `git reset --soft HEAD~2` + re-commit, or an interactive rebase, then
  `git push --force-with-lease`.
- **After applying a review fix, reply `Fixed, thanks!` on the thread and resolve
  it.** Reply via
  `gh api repos/<owner>/<repo>/pulls/<n>/comments/<cid>/replies -f body='Fixed, thanks!'`
  and resolve via the GraphQL `resolveReviewThread` mutation.
- Tags must be annotated and signed (`git tag -s -m ...`). Never create release
  tags through the GitHub API — that produces lightweight tags which break
  `git tag -v` verification.
- **PR titles and bodies.** Release-prep and label PRs use the commit subject as
  the title. The release→main PR uses the GitHub-default humanized branch name
  `Release/vX.Y.x`. Every PR body is a single line pointing at the flux2 minor
  release tracking issue: `Part of: https://github.com/fluxcd/flux2/issues/NNNN`.
- **Do not declare the release done until every step below has run**, including
  the final backport label PR (step 11). Tagging and merging to main are not the
  last step. Walk the numbered steps and confirm each one ran before reporting
  completion.

## Preconditions

- Read the upstream procedure at `website/content/en/flux/releases/procedure.md`,
  section `Controllers: minor releases`
  (https://fluxcd.io/flux/releases/procedure/#controllers-minor-releases).
- Identify the flux2 minor-release tracking issue so PR bodies can reference it
  (`Part of: https://github.com/fluxcd/flux2/issues/NNNN`).
- Use `date` to get the release date for the changelog entry.
- `git fetch --all --tags --prune` before reasoning about branches, tags, or
  merged PRs. Do not trust stale local `origin/*` refs.
- Treat `git` and `gh` commands as confirmation points if the user wants that.

## Release Flow

For the controller being released (target version `vX.Y.0`):

1. Create the release series branch from `main` and push it.
   - `git switch -c release/vX.Y.x main`
   - `git push origin release/vX.Y.x`

2. Create the release preparation branch from the series branch.
   - `git switch -c release-vX.Y.0 release/vX.Y.x`

3. Draft the new `CHANGELOG.md` entry (see "How To Build The Changelog Entry").
   Then commit it.
   - `git add CHANGELOG.md`
   - `git commit -s -m "Add changelog entry for vX.Y.0"`

4. Apply the release version bump exactly as documented.
   - Update the controller self-API version in the root `go.mod` to `vX.Y.0`.
     Inspect the actual `go.mod`; do not assume the self-API path form
     (`source-watcher` uses `github.com/fluxcd/source-watcher/api/v2`).
   - Update `config/manager/kustomization.yaml` `newTag` to `vX.Y.0`.
   - `git add go.mod config/manager/kustomization.yaml`
   - `git commit -s -m "Release vX.Y.0"`

5. Push the release preparation branch.
   - `git push origin release-vX.Y.0`

6. Open and merge the release PR into the release series branch.
   - Base: `release/vX.Y.x`  Head: `release-vX.Y.0`
   - Title `Release vX.Y.0`, body `Part of: <tracking issue URL>`.
   - Merge when CI is green and a maintainer has approved.

7. Refresh the release series branch after the merge.
   - `git switch release/vX.Y.x`
   - `git pull origin release/vX.Y.x`
   - Confirm both version refs are `vX.Y.0` on the merged commit before tagging.

8. Create and push signed tags from the updated release series branch. Push the
   `api/` tag first — the release tag depends on it.
   - `git tag -s -m "api/vX.Y.0" api/vX.Y.0`
   - `git push origin api/vX.Y.0`
   - `git tag -s -m "vX.Y.0" vX.Y.0`
   - `git push origin vX.Y.0`

9. Verify the release workflow triggered by the `vX.Y.0` tag. Watch it in the
   background until it concludes successfully (images published + signed, SBOM,
   SLSA provenance, GitHub release created).

10. Merge the release series branch into `main` via PR. This merges the whole
    branch (changelog + version bump), not a cherry-pick.
    - Base: `main`  Head: `release/vX.Y.x`
    - Leave the title at the GitHub default — the humanized branch name
      `Release/vX.Y.x`. Body `Part of: <tracking issue URL>`.
    - Merge when CI is green and approved.

11. **Last:** open the backport label PR against `main`. Do this only **after**
    step 10 has merged.
    - `git switch main`
    - `git pull origin main`
    - `git switch -c label-X.Y main`
    - Append to `.github/labels.yaml`, after the previous `backport:` entry:
      ```yaml
      - name: backport:release/vX.Y.x
        description: To be backported to release/vX.Y.x
        color: '#ffd700'
      ```
    - `git add .github/labels.yaml`
    - `git commit -s -m "Add backport:release/vX.Y.x label"`
    - `git push origin label-X.Y`
    - Open PR (base `main`, title `Add backport:release/vX.Y.x label`, body
      `Part of: <tracking issue URL>`) and merge when green.
    - **Why last:** the label branch is cut from `main`. If you open it before
      step 10 merges, that merge moves `main` forward and the label PR must then
      be rebased onto the new `main` and force-pushed
      (`git rebase main` + `git push --force-with-lease`). Opening it last avoids
      the rebase entirely.

## How To Build The Changelog Entry

A minor changelog entry summarizes what is **new in vX.Y.0 relative to the whole
vX.(Y-1) line** — not every commit since the previous minor. The hard part is
selecting exactly the right PRs.

### Selecting the PRs (do this rigorously — do not infer from commit messages)

1. Establish the candidate set: PRs merged to `main` since the previous minor
   (`v(X).(Y-1).0`).
   - From merge commits:
     `git log --merges --grep="Merge pull request" v(X).(Y-1).0..release/vX.Y.x`
     and extract the `#NNNN`.
   - Cross-check against `gh` so squash/rebase merges are not missed:
     `gh pr list --base main --state merged --limit 200 --json number,mergedAt,title`
     filtered to merges after the previous minor's release timestamp.
2. **Verify every candidate PR via `gh pr view <n> -R fluxcd/<repo> --json number,baseRefName,state,mergedAt,title`.**
   Keep only PRs that are `MERGED` and have `baseRefName == main`. Use the PR
   title from GitHub, never the local merge-commit subject (these drift; e.g. a
   commit may say one thing while the PR title says another).
3. **Exclude PRs already shipped in a patch release of the previous minor**
   (anything `> v(X).(Y-1).0` and `< vX.Y.0`). Read the `## (X).(Y-1).Z` patch
   sections already in `CHANGELOG.md` and drop any candidate whose change shipped
   there. Note the patch changelogs cite the **cherry-pick** PR numbers
   (against `release/v(X).(Y-1).x`), which differ from the original `main` PR
   numbers — match by change, not by number.
4. **Exclude release mechanics PRs**: changelog cherry-pick/"Add changelog entry"
   PRs, the previous release's `Release/v(X).(Y-1).x` merge-back, and label PRs.
5. Collapse routine dependency bumps (fluxcd/pkg, CI actions, k8s/Go bumps whose
   content already shipped in a patch) into a single `Various dependency updates`
   bullet listing each PR link. Keep genuinely user-facing items as their own
   bullets. See "Dependency update PRs" below before settling for a generic line.

### Writing the entry

Write the new section at the top of `CHANGELOG.md`, matching the existing minor
entries in that repo:
- `## X.Y.0`
- `**Release date:** YYYY-MM-DD` (from `date`)
- A one–two sentence intro naming the headline theme.
- Optional `⚠️` upgrade warnings (API removals, required `flux migrate`, etc.).
  When warning about a deprecated/beta API removal, link the upgrade instruction
  to the canonical flux2 upgrade-procedure discussion
  (https://github.com/fluxcd/flux2/discussions/5572), not to a one-off
  `flux migrate` PR — the discussion is the maintained guide covering both the
  Flux CLI and Flux Operator migration paths. Older changelog entries may still
  point at a migrate PR; do not copy that, use the discussion link.
- Per-API subsections (`### GitRepository`, `### OCIRepository`,
  `### HelmChart`, `### Bucket`, …) describing notable features in prose.
- An optional `### General updates` subsection for k8s/Go/dependency posture.
- `Fixes:` and `Improvements:` bullet lists, each bullet a short title plus one
  or more `[#NNNN](https://github.com/fluxcd/<repo>/pull/NNNN)` links.

Surface borderline items (repo-internal docs, a dep bump whose content already
shipped in a patch) to the user rather than guessing whether to headline them.

### Dependency update PRs

Do not reduce a dependency bump to a generic line without checking its substance.
- Read the PR description, follow referenced upstream PRs (e.g.
  `Includes: fluxcd/pkg#NNNN`), and look at the `go.mod` diff.
- Call out security fixes with their CVE/GHSA and an advisory link plus a short
  impact parenthetical. Use matching wording across controllers that pull the
  same bump.
- Only mention a dependency change relevant to what that controller actually
  does — a bumped module often ships capabilities the controller never exercises.

## Critical Checks

- Always `git fetch --all --tags --prune` before comparing
  `v(X).(Y-1).0..release/vX.Y.x` or reasoning about merged PRs.
- The release series branch (step 1) is cut from `main`; the prep branch (step 2)
  is cut from `release/vX.Y.x`.
- Pull the release series branch again after merging the release PR and before
  tagging. Tag from the series-branch merge commit, not from the prep branch.
- Push `api/vX.Y.0` before `vX.Y.0`.
- The release→main PR merges the whole branch; do **not** cherry-pick for a minor.
- Open the backport label PR last (after step 10 merges) to avoid a rebase.
- Inspect the actual root `go.mod` for the self-API path; do not assume its form.
- Do not silently special-case a controller. If a documented step seems not to
  apply, inspect the file and confirm before proceeding.

## Bumping the API in dependent controllers

After a controller minor ships, its API module often needs bumping in the
controllers that depend on it (e.g. `image-reflector-controller/api` in
image-automation-controller, or `source-controller/api` in helm-controller,
kustomize-controller, image-automation-controller, and source-watcher). This is a
separate follow-up PR per dependent repo, not part of the 11 release steps above.

- Branch from the dependent repo's `main` (which may already carry an earlier
  bump from the same release round), then
  `go get github.com/fluxcd/<controller>/api@vX.Y.0` followed by `go mod tidy`.
- The bump is usually **`go.mod` + `go.sum` only**. Mirror an existing sibling PR
  from the same round for the exact title/body/commit shape.
- **But check whether the dependent repo pins the dependency's published release
  manifests** in `config/default/kustomization.yaml` (remote
  `…/releases/download/vX.Y.Z/<controller>.crds.yaml` and `.deployment.yaml`
  URLs). If it does, bump those URLs to the new version too. Some repos pin them
  (source-controller is pinned by source-watcher, helm-controller, and
  kustomize-controller) and some do not (image-automation-controller does not pin
  image-reflector-controller). Do not assume — `grep` the repo.
- If the released minor removed APIs, confirm the dependent still builds: it must
  not import a removed package version. Run `go build ./...` and `go vet ./...`.

## Updating this skill

- Improvements should land as a single-commit PR on a dedicated branch. When
  accumulating more changes during a release session, amend and force-push rather
  than adding new commits.
- Keep the skill-update PR open during the session and merge it **last**, after
  the release is fully done. Do not keep a CI watch open on it throughout — check
  CI right before merging.
- Do not leak session-specific state, downstream/enterprise distribution details,
  or AI attribution into the skill file.

## Useful Local Queries

- Existing release branches: `git branch -r --list 'origin/release/v*.x' | sort -V`
- Latest tags: `git tag -l 'v*' | sort -V | tail`
- Candidate PR merges since the previous minor:
  `git log --merges --grep="Merge pull request" v(X).(Y-1).0..release/vX.Y.x`
- Full merged-PR cross-check:
  `gh pr list --base main --state merged --limit 200 --json number,mergedAt,title`
- Verify a single PR for the changelog:
  `gh pr view <n> -R fluxcd/<repo> --json number,title,url,baseRefName,state,mergedAt`
