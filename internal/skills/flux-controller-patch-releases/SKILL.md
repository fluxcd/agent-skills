---
name: flux-controller-patch-releases
description: >
  Run the upstream Flux controller patch release procedure for helm-controller,
  image-automation-controller, image-reflector-controller, kustomize-controller,
  notification-controller, source-controller, and source-watcher. Use when
  preparing a new controller patch release from a release series branch,
  drafting changelog entries, tagging releases, and opening the follow-up
  changelog PRs back to main.
license: Apache-2.0
---

# Flux Controller Patch Releases

Use this skill for upstream Flux controller patch releases only. Do not use it
for `flux2`, `pkg`, or other non-controller repos.

Supported controllers:
- `helm-controller`
- `image-automation-controller`
- `image-reflector-controller`
- `kustomize-controller`
- `notification-controller`
- `source-controller`
- `source-watcher`

## Important rules

- **Go deep until you block, then switch.** Drive one controller all the way
  through every step you can do locally — branch, changelog commit, version
  bump commit, push, open PR — before switching to the next. Only move on
  when you hit something you cannot progress (CI running, PR awaiting review,
  tag workflow running). The moment something unblocks (PR merged, CI green,
  workflow finished), come back to it immediately — do not finish the current
  controller's local work first if an earlier one is ready to advance.
- **Never block the conversation on long-running operations.** CI checks,
  release workflow runs, tag-triggered workflows, and similar waits must be
  watched in the background so the user can keep steering and so you can pick
  up any other controller the moment it unblocks. When a background watch
  completes, report the result and proceed.
- **Always quote PR/issue links as full URLs** (e.g.
  `https://github.com/fluxcd/helm-controller/pull/1465`), never the
  `<owner>/<repo>#<number>` shorthand — full URLs are clickable from the
  user's terminal, the shorthand is not.
- **Start background watches on every PR immediately after opening it.** Kick
  off `gh pr checks <num> -R fluxcd/<repo> --watch` in the background as
  soon as the PR is created so CI status lands in the conversation the
  moment it finishes. Do the same for tag-triggered release workflows
  (`gh run watch <id> -R fluxcd/<repo>` in the background). Do not wait
  until "everything is pushed" to start watching — start watching the first
  PR while you prepare the second.
- **Also start a background approval watch per PR.** `gh pr checks --watch`
  only covers CI; it does not fire on maintainer approval. Poll the review
  state in the background so you are notified the moment it flips to
  APPROVED + CLEAN:
  ```
  while :; do
    state=$(gh pr view <num> -R fluxcd/<repo> --json mergeStateStatus,reviewDecision --jq '.reviewDecision+" "+.mergeStateStatus')
    case "$state" in "APPROVED CLEAN") echo "$state"; break;; esac
    sleep 30
  done
  ```
  Run this in the background; when it exits, merge the PR and proceed.
- Every git commit must use `-s` (sign-off). Never include Co-Authored-By
  lines, your own name, or any AI attribution in commit messages, PR titles,
  or PR descriptions. This applies to all PRs, including PRs that update this
  skill file itself.
- Always wait for CI to go green before merging any PR.
- You cannot approve your own PRs. If a PR was opened by the git user driving
  the session, ask a maintainer to approve it (or confirm it is already
  approved) before merging.
- **Merge release PRs yourself** (controller release PRs, changelog cherry-pick
  PRs) as soon as CI is green **and** a maintainer has approved. No need to
  ask the user to click merge — act on it immediately so the next step (tag
  push, etc.) unblocks. This applies only to PRs opened with the user's
  account during this session.
- **Review feedback on release PRs is applied by amending**, not by adding
  new commits. A release PR must stay at exactly two commits
  (`Add changelog entry for vX.Y.Z` and `Release vX.Y.Z`). When the fix
  belongs in the changelog, amend the changelog commit; when it belongs in
  the release bump, amend that one. Use
  `git reset --soft HEAD~2` + re-commit, or an interactive rebase, then
  `git push --force-with-lease`.
- **After applying a review fix, reply `Fixed, thanks!` on the thread and
  resolve it.** Reply via
  `gh api repos/<owner>/<repo>/pulls/<n>/comments/<cid>/replies -f body='Fixed, thanks!'`
  and resolve via the GraphQL `resolveReviewThread` mutation. Find thread
  IDs with
  `gh api graphql -f query='{ repository(owner:"<o>",name:"<r>") { pullRequest(number:<n>) { reviewThreads(first:50) { nodes { id isResolved comments(first:1){nodes{databaseId body}} } } } } }'`.
- Do **not** watch CI on the skill-update PR continuously — it only needs to
  merge at the very end of the procedure, so check CI right before merging
  rather than keeping a watch open throughout the session.
- Tags must be annotated and signed (`git tag -s -m ...`). Never create
  release tags through the GitHub API — that produces lightweight tags which
  break `git tag -v` verification.
- Strictly follow the git commands documented in the release flow below. Do
  not invent substitutions or skip steps — each step has a reason.
- **Do not declare a controller "done" until every step in the Release Flow
  below has been executed for it**, including the final changelog
  cherry-pick PR back to `main` (step 11). Merging the release PR and
  tagging is *not* the last step. Before reporting completion, walk through
  each controller against the numbered steps and confirm each one ran.
- PRs opened by this procedure use the commit subject as the PR title and an
  empty body.

## Preconditions

- Read the upstream procedure at `website/content/en/flux/releases/procedure.md`,
  section `Controllers: patch releases`.
- Treat `git` and `gh` commands as confirmation points if the user wants that.
- Use `date` to get the release date for changelog entries.
- Fetch before reasoning about release branches or merged PRs. Do not trust stale
  local `origin/*` refs.

## Release Flow

For each controller:

1. Refresh local state.
   - `git fetch --all --tags --prune`
   - `git switch release/vX.Y.x`
   - `git pull origin release/vX.Y.x`

2. Create the release preparation branch exactly from the release series branch.
   - `git switch -c release-vX.Y.Z release/vX.Y.x`

3. Draft the new `CHANGELOG.md` entry.
   - Use the existing changelog structure in that repo.
   - Use the current date from `date`.
   - Build the entry from the commits merged into the release series branch since
     the previous tag.
   - Prefer PR titles over commit subjects for bullets.
   - Check the PRs that introduced the changes; do not infer titles from local
     commit messages.
   - In the intro paragraph, summarize the concrete bug fixes shipped in the
     patch release.

4. Commit the changelog entry.
   - `git add CHANGELOG.md`
   - `git commit -s -m "Add changelog entry for vX.Y.Z"`

5. Apply the release version bump exactly as documented.
   - Update the controller self-API version in the root `go.mod`.
   - Update `config/manager/kustomization.yaml` `newTag` to `vX.Y.Z`.
   - Commit with:
     - `git add go.mod config/manager/kustomization.yaml`
     - `git commit -s -m "Release vX.Y.Z"`

6. Push the release preparation branch.
   - `git push origin release-vX.Y.Z`

7. Open and merge the release PR into the release series branch.
   - Base: `release/vX.Y.x`
   - Head: `release-vX.Y.Z`

8. Refresh the release series branch after merge.
   - `git switch release/vX.Y.x`
   - `git pull origin release/vX.Y.x`

9. Create and push signed tags from the updated release series branch.
   Push the `api/` tag first — the release tag depends on it.
   - `git tag -s -m "api/vX.Y.Z" api/vX.Y.Z`
   - `git push origin api/vX.Y.Z`
   - `git tag -s -m "vX.Y.Z" vX.Y.Z`
   - `git push origin vX.Y.Z`

10. Confirm the non-`api/` tag triggered the release workflow.

11. Cherry-pick only the changelog commit back to `main`.
   - `git switch main`
   - `git pull origin main`
   - `git switch -c pick-changelog-vX.Y.Z main`
   - `git cherry-pick -x <Add changelog entry commit>`
   - `git push origin pick-changelog-vX.Y.Z`
   - Open PR from `pick-changelog-vX.Y.Z` to `main`

## How To Build The Changelog Entry

For a patch release, gather:
- the latest release tag on the release line
- the merged commits on `origin/release/vX.Y.x` since that tag
- the PRs corresponding to those merges

Write the new section at the top of `CHANGELOG.md`:
- `## X.Y.Z`
- `**Release date:** YYYY-MM-DD`
- short intro paragraph describing the actual bug fixes in user-facing language
- `Fixes:` when there are bug-fix items
- `Improvements:` for dependency updates, docs, feature gates, or cleanup

Rules:
- Use PR titles, not raw commit messages
- Group multiple dependency bump PRs naturally when the repo history already does that
- Verify the title against GitHub when the local merge commit is vague

## Critical Checks

- Always fetch before comparing `tag..origin/release/...`.
- Always pull the release series branch before creating `release-vX.Y.Z`.
- Always pull the release series branch again after merging the release PR and
  before tagging.
- Always inspect the actual root `go.mod`; do not assume the self-API path form.
  `source-watcher` uses `github.com/fluxcd/source-watcher/api/v2`, so it still
  needs the same self-API release bump pattern.
- Do not silently special-case a controller. If the documented step seems not to
  apply, inspect the file and confirm before proceeding.
- Tag from the release series branch merge commit, not from the release prep branch.
- Cherry-pick only the changelog commit back to `main`, not the release version bump.

## Updating this skill

- Improvements to this skill should land as a single-commit PR on a dedicated
  branch. When accumulating more changes during a release session, amend and
  force-push rather than adding new commits.
- Keep the skill-update PR open during the release session and merge it
  **last**, after all controller patch releases are done. Session learnings
  tend to surface throughout the flow; amend them in as they come up.
- Do not leak session-specific state, downstream/enterprise distribution
  details, or AI attribution into the skill file.

## Useful Local Queries

- Release branches:
  - `git branch -r --list 'origin/release/v*.x' | sort -V`
- Latest tags:
  - `git tag -l 'v*' | sort -V | tail`
- Commits since previous release on the release branch:
  - `git log --oneline <prev-tag>..origin/release/vX.Y.x`
- PR metadata for changelog bullets:
  - `gh pr view <number> -R fluxcd/<repo> --json number,title,url,baseRefName`
