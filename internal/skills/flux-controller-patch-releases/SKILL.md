---
name: flux-controller-patch-releases
description: >
  Run the upstream Flux controller patch release procedure for helm-controller,
  image-automation-controller, image-reflector-controller, kustomize-controller,
  notification-controller, source-controller, and source-watcher. Use when
  preparing a new controller patch release from a release series branch,
  drafting changelog entries, tagging releases, and opening the follow-up
  changelog PRs back to main.
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

9. Create signed tags from the updated release series branch.
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

## Useful Local Queries

- Release branches:
  - `git branch -r --list 'origin/release/v*.x' | sort -V`
- Latest tags:
  - `git tag -l 'v*' | sort -V | tail`
- Commits since previous release on the release branch:
  - `git log --oneline <prev-tag>..origin/release/vX.Y.x`
- PR metadata for changelog bullets:
  - `gh pr view <number> -R fluxcd/<repo> --json number,title,url,baseRefName`
