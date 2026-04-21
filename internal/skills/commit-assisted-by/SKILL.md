---
name: commit-assisted-by
description: "Add an Assisted-by git trailer (agent-name/model-id) to commits made during an AI-assisted coding session. Trigger on any git commit activity visible in the session — either commits you make yourself, or commits the user makes outside your tool calls that surface in the conversation — even without an explicit request. Also trigger when the user explicitly asks to tag existing commits in a branch (e.g. 'add assisted-by to commits in this branch')."
license: Apache-2.0
allowed-tools: Bash(*/safety-check.sh) Bash(git commit:*) Bash(git log:*)
---

# Commit Assisted-by trailer

Record the assisting agent's involvement in a commit by adding an `Assisted-by: <agent-name>/<model-id>` git
trailer. The `<agent-name>` identify the specific AI assistant (CLI/harness) and `<model-id>` is the LLM version
that contributed to the commit. This disclosure provides transparency about AI involvement in code changes.

In the command examples below, substitute `<agent-name>/<model-id>` with your own values before running anything.

## Mode 1 — commits you create yourself

When you create a commit in a session, limit the commit subject to 50 characters. Use the imperative mood in the
subject line (e.g., "Add support for X" instead of "Added support for X").

If the commit message body is needed to explain what and why, wrap it at 72 characters. Avoid verbose explanations
in the body, be as concise as possible while still conveying the necessary information.

Pass `--trailer` directly on the commit command. This is the clean path and avoids amend noise:

```
git commit -s -m "Add support for X" --trailer "Assisted-by: <agent-name>/<model-id>"
```

Note that all commits must be signed off with a real human name and email to meet the DCO requirement. Never use
your agent's name or a pseudonym in the sign-off or co-author fields.

## Mode 2 — commits that appear outside your own `git commit` invocations

Sometimes a commit lands on HEAD that you did not run yourself — the user invoked git via a shell escape (e.g.
Claude Code's `! git commit ...`) or a separate terminal. Your only window is after the fact.

Run the bundled safety-check script before amending. It prints `safe`, or `skip:<reason>` if HEAD is already
pushed, already trailered, a merge, or has a rebase/cherry-pick/revert/bisect in progress.

Invoke it with the script's full path — resolve `scripts/safety-check.sh` against the directory this SKILL.md was
loaded from, not the current working directory (the two are almost never the same):

```
<skill-dir>/scripts/safety-check.sh
```

Only when the output is exactly `safe`, amend:

```
git commit --amend --no-edit --trailer "Assisted-by: <agent-name>/<model-id>"
```

Follow up with one short line so the user knows the hash moved, e.g. "Amended HEAD to add Assisted-by trailer." If
the output starts with `skip:`, tell the user why the commit was skipped.

## Mode 3 — explicit "tag the whole branch" request

Triggered by phrases like "add assisted-by to commits in this branch", "tag the commits on this branch", or
"backfill the trailer". This is the **only** mode that rewrites more than HEAD, and only because the explicit
request authorizes it. Never enter this mode on autopilot.

### Pick the base

Default to `@{u}` — it guarantees the range is only unpushed commits, which removes the force-push question
entirely. If the branch has no upstream, ask the user for an explicit base ref rather than guessing. If the user
names a base themselves ("from the last release tag"), honor it.

### Show the plan, then confirm

1. `git log --oneline <base>..HEAD` so the user can see the commits that will be rewritten.
2. If `<base>` is anything other than `@{u}`, run `git rev-list <base>..@{u} 2>/dev/null`. If non-empty, those
   commits are already on the remote — warn the user that after the rebase they will need to force-push to publish
   the rewrite, and confirm before proceeding.
3. If the range contains merge commits, stop and ask how to handle them. Default rebase linearizes merges
   (destructive), and `--rebase-merges` with `--exec` on merges is fragile — not worth the risk without the user's
   judgment.

### Run it

The exec short-circuits on commits that already carry the trailer, so the pass is idempotent:

```
git rebase <base> --exec 'git log -1 --format=%B | git interpret-trailers --parse | grep -qi "^Assisted-by:" || git commit --amend --no-edit --trailer "Assisted-by: <agent-name>/<model-id>"'
```

Afterwards, report how many commits were tagged vs skipped. If the branch was already pushed, tell the user they
will need to run `git push --force-with-lease` themselves to publish the rewrite.

If the rebase hits a conflict, do not try to resolve it. Surface the conflict to the user and let them choose
`--continue` vs `--abort`.

## Anti-patterns

- Never run `git push` yourself in any mode, even after a rebase. Publishing rewritten history is the user's call —
  surface the state and let them decide.
- Don't use `Co-authored-by:` — AI assistants are not GitHub users and the co-author convention is reserved for
  human collaborators. `Assisted-by:` is the correct semantic.
- Don't fabricate or prettify either token. Use the actual agent/CLI/harness name and model ID/version.
