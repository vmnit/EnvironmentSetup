---
name: rebase-pr
description: >-
  Rebase a GitHub pull request onto its base branch, auto-drop commits already
  on the base via squash-merge, resolve merge conflicts when the rebase stops
  (preserve PR intent on top of the new base), post a heads-up PR comment before
  any rebase work begins and a detailed confirmation comment after the force-push
  lands, and verify diff-stat parity before pushing. Use when the user asks to
  rebase a PR, sync a PR with main, fix a "This branch is out-of-date" warning,
  or resolve a CONFLICTING / DIRTY merge state on a GitHub PR.
---

# Rebase a Pull Request

Your job is to rebase a GitHub PR onto its current base branch with zero risk of accidental scope change, and to make the force-push legible to reviewers. The skill is opinionated about four things: (1) the PR receives **two comments** — a heads-up before the rebase starts and a detailed confirmation after the push lands, (2) commits already absorbed into the base via squash-merge are dropped automatically, (3) when the rebase stops on conflicts you **resolve them and continue** (see [conflicts.md](conflicts.md)) rather than aborting by default, and (4) the new tree must produce a byte-equivalent diff against the new base before the push happens.

## Workflow

Copy this checklist into your working notes and tick as you go. Do not skip the parity check (step 7), the pre-rebase heads-up (step 2), or the post-rebase confirmation (step 10).

```
- [ ]  1. Resolve PR identity (number, repo, head branch, base branch, head SHA)
- [ ]  2. Post pre-rebase heads-up comment on the PR
- [ ]  3. Fetch base + head; check out the PR branch locally
- [ ]  4. Capture pre-rebase diff-stat vs base (parity baseline)
- [ ]  5. Detect duplicates absorbed via squash-merge (auto cut-point)
- [ ]  6. Run the rebase (with --onto when a cut-point was detected)
- [ ]  6b. If conflicts: resolve per conflicts.md, git add, rebase --continue (repeat)
- [ ]  7. Verify post-rebase diff-stat matches baseline
- [ ]  8. Force-push with --force-with-lease
- [ ]  9. Verify GitHub reports mergeable=MERGEABLE
- [ ] 10. Post post-rebase confirmation comment on the PR
```

## Step 1: Resolve PR identity

Accept either a PR URL (`https://github.com/<owner>/<repo>/pull/<n>`) or a `#<n>` reference plus a known repo. Pull every fact you need with one `gh` call:

```bash
gh pr view <pr> --repo <owner>/<repo> --json \
  number,headRefName,baseRefName,headRefOid,mergeable,mergeStateStatus,isCrossRepository,headRepositoryOwner,url
```

Record:

- `headRefName` — the PR's branch name (you will check it out)
- `baseRefName` — the rebase target (usually `main`)
- `headRefOid` — the **old HEAD SHA** that goes in both PR comments
- `isCrossRepository` — if `true`, the PR is from a fork; **stop and ask the user** whether they have push access to the fork. Do not attempt to rebase a fork PR without confirmation.
- `mergeStateStatus` — `DIRTY` or `BEHIND` confirms the rebase is needed; `CLEAN` means the user may just want the branch up to date for other reasons (verify intent).

Do **not** proceed if `state != OPEN` — closed/merged PRs should not be rebased.

## Step 2: Post pre-rebase heads-up comment

Before you touch the local checkout, alert the PR thread that a force-push is incoming. This lets any reviewer or co-author who has the branch checked out know to pause, and makes the eventual force-push obviously expected (not a ninja rewrite).

Capture the values you already have from step 1:

```bash
OLD_HEAD=<headRefOid>
BASE_REF=<baseRefName>
BASE_SHA=$(gh api repos/<owner>/<repo>/commits/<baseRefName> --jq '.sha')
```

Post via `gh pr comment` using a HEREDOC. Use this template verbatim:

```bash
gh pr comment <pr> --repo <owner>/<repo> --body "$(cat <<EOF
**Heads-up: rebasing this PR onto \`$BASE_REF\` shortly**

Force-push incoming. This is a history-only rewrite — no code changes from me, no scope expansion.

| field | value |
| --- | --- |
| current HEAD | \`$OLD_HEAD\` |
| target base | \`$BASE_REF\` @ \`$BASE_SHA\` |

Why: <one short sentence — e.g. "PR is BEHIND main", "merge state is DIRTY after #194 squash-merged into main", "branch protection requires linear history">.

A follow-up comment will land on this thread once the push is done with the new HEAD SHA, the diff-stat parity check, and the list of commits dropped (if any). If you have a local checkout of \`<headRefName>\`, hold off on rebasing it yourself until the follow-up arrives.
EOF
)"
```

The heads-up is intentionally short. Save the detailed receipt (new SHA, dropped commits, parity diff-stat) for the post-rebase confirmation in step 10 — you don't have those numbers yet.

**Do not** proceed to step 3 until `gh pr comment` exits 0 and prints the comment URL. If the comment fails to post (auth issue, repo permissions), surface the error and stop — do not rebase silently.

## Step 3: Fetch and check out

```bash
git fetch origin --prune
git fetch origin <baseRefName>
git fetch origin <headRefName>:<headRefName> 2>/dev/null \
  || git fetch origin <headRefName>
git checkout <headRefName>
```

Refuse to proceed if `git status --porcelain` shows tracked uncommitted changes. Untracked files are fine; tell the user about them but keep going.

## Step 4: Capture parity baseline

The post-rebase tree must produce the same diff as the pre-rebase tree, otherwise the rebase silently dropped or duplicated content.

```bash
git diff --stat $(git merge-base HEAD origin/<baseRefName>)..HEAD \
  > /tmp/rebase-pr-<num>-pre.diffstat
git rev-parse HEAD > /tmp/rebase-pr-<num>-old-head
```

The merge-base is the right reference because the *current* base ref may have moved beyond the PR branch's actual divergence point (that is exactly why the rebase is needed).

## Step 5: Detect squash-merge duplicates (auto cut-point)

This is the single most common reason a "trivial" rebase explodes into hundreds of conflicts: the PR was branched off a feature branch that has since been **squash-merged** into `main`. The original individual commits still live on the PR branch, but their content also lives on `main` as one squashed commit. Replaying them produces fake conflicts against their own absorbed selves.

Detect the cut-point:

```bash
# Commits ahead of base on the PR branch
git log --format='%H %s' origin/<baseRefName>..HEAD

# For each commit, check if its patch-id matches a commit already on base.
# git cherry shows '+' for unique commits and '-' for already-present ones.
git cherry origin/<baseRefName> HEAD
```

Read `git cherry` output bottom-up (oldest first):

- A contiguous run of `-` lines at the **bottom** of the list is the squash-absorbed prefix. Cut there.
- `+` lines, and any `-` lines interleaved with `+`, must be replayed.

If the absorbed prefix has length **N**, the rebase becomes:

```bash
git rebase --onto origin/<baseRefName> HEAD~<keep_count> <headRefName>
```

where `keep_count = (commits ahead of base) - N`. This replays only the **unique** commits.

If `git cherry` shows zero `-` lines, fall through to the plain rebase in step 6.

While you have the dropped commits visible, **capture their subjects now** for the step 10 receipt — after the rebase they're gone:

```bash
git log --format='- \`%h\` %s' \
  origin/<baseRefName>..HEAD~<keep_count> \
  > /tmp/rebase-pr-<num>-dropped.txt
```

### Worked examples

**Squash-absorbed prefix (auto cut-point):** PR #198 originally had 19 commits ahead of `main`. `git cherry main HEAD` showed `-` for the 16 oldest (Phase 1 commits, squash-merged via PR #194) and `+` for the 3 newest. Cut-point: `HEAD~3`. Command: `git rebase --onto origin/main HEAD~3 <branch>`. Without the cut-point, replaying the absorbed commits raises fake conflicts against squash commit `bac7067`.

**All `+` but still conflicts (manual resolution):** After Phase 1 is on `main`, `git cherry` may show `+` for every remaining PR commit while the first replay still conflicts — e.g. PR #198's registry commit vs `src/aorta/cli/probe.py` after Phase 2 (#197) refactored probe on `main`. That is base evolution, not a missed cut-point. Resolve per [conflicts.md](conflicts.md) and continue; do not abort.

## Step 6: Run the rebase

With cut-point (auto-detected duplicates):

```bash
git rebase --onto origin/<baseRefName> HEAD~<keep_count> <headRefName>
```

Without cut-point (no duplicates detected):

```bash
git rebase origin/<baseRefName>
```

### If the rebase stops on a conflict

**Default: resolve and continue.** Do not abort just because conflicts exist. Read [conflicts.md](conflicts.md) and follow it end-to-end.

Quick diagnostic:

```bash
git status
git diff --name-only --diff-filter=U
git log -1 --oneline REBASE_HEAD   # commit that failed to apply (if shown)
```

**Before editing files**, check whether step 5 missed a squash cut-point:

- If `git cherry` showed all `+` but the **first** replayed commit conflicts heavily with files that also changed on `main`, this is usually **base evolution while the PR was open** (true overlap), not a missed duplicate. Resolve manually.
- If conflicts mention the same hunks as commits that should have been dropped, abort, fix the cut-point, and restart from step 6.

**Resolution loop** (repeat until `git rebase` finishes or you hit an abort condition in conflicts.md):

1. For each conflicted path, read markers; compare with `git show origin/<headRefName>:<path>` (PR tip is ground truth).
2. Combine **base structure** + **PR semantic delta** — do not pick one entire side when both contributed real changes.
3. `git add <path>` for every resolved file (no `<<<<<<<` left).
4. `git rebase --continue`.
5. Record resolved paths for the step 10 comment.

During rebase, `<<<<<<< HEAD` is the **onto** branch (`main`), and `>>>>>>> <commit>` is the **replayed PR commit** — see conflicts.md for the ours/theirs table.

**Worked example in-repo:** ROCm/aorta PR #198, first conflict in `src/aorta/cli/probe.py` when replaying the #195 registry commit onto `main` after Phase 2 probe (#197) landed — merge `load_recipe(..., sidecar_files=mitigation_files)` into the expanded handler without reverting Phase 2 structure. Full hunk walkthrough: conflicts.md § "Worked example: ROCm/aorta PR #198".

### If you must abort

Abort only per the abort conditions in conflicts.md (frozen `source/`, unrecoverable repeated conflicts, cannot match PR tip diff, wrong cut-point). Then:

```bash
git rebase --abort
```

Post the "aborted, no push happened" follow-up (heads-up from step 2 must not dangle):

```bash
gh pr comment <pr> --repo <owner>/<repo> --body "$(cat <<EOF
**Rebase aborted — no force-push happened**

Conflicts on:

\`\`\`
<paste paths from git diff --name-only --diff-filter=U>
\`\`\`

Failed while replaying: \`<commit subject from git status>\`

\`HEAD\` is unchanged at \`$OLD_HEAD\`.

Reason: <one line — e.g. frozen source/ tree, could not match PR tip diff after resolution attempt, need different squash cut-point>
EOF
)"
```

Tell the user in chat what you tried, which files conflicted, and the specific blocker.

## Step 7: Parity check (pre-push)

After a clean rebase, the diff against the new base must match the baseline from step 4:

```bash
git diff --stat origin/<baseRefName>..HEAD \
  > /tmp/rebase-pr-<num>-post.diffstat

diff -u /tmp/rebase-pr-<num>-pre.diffstat \
        /tmp/rebase-pr-<num>-post.diffstat
```

Acceptable: byte-identical, or differs only because absorbed-via-squash files dropped out of the diff (they are now part of the base, not part of the PR's contribution). The total `+ / -` line counts and the file list for **PR-unique** files must match.

If the parity check fails for any other reason, stop and investigate. Common causes:

- A merge commit on the PR branch was flattened during rebase, dropping content.
- The PR branch contained an unrelated direct push that wasn't on `origin`.
- A `--squash` slipped into the rebase invocation.

Do not push a tree that fails parity. If you need to abort here after the parity check fails, post the same "rebase aborted" follow-up from the step 6 conflict path so the heads-up comment doesn't dangle.

## Step 8: Force-push

```bash
git push --force-with-lease origin <headRefName>
```

`--force-with-lease` (not `--force`) — refuses the push if the remote tip moved since you fetched, which catches the case where the PR author pushed a new commit while you were rebasing locally.

If the lease check fails:

1. Re-fetch.
2. Inspect the new commits on the remote.
3. Decide whether to redo the rebase including them, or hand back to the user.
4. Post an "aborted, no push happened" follow-up if you decide not to redo the rebase, mirroring the step 6 template.

Never escalate to `--force` without the user's explicit go-ahead.

## Step 9: Verify mergeability

GitHub takes a few seconds to recompute mergeability after a force-push. Poll briefly:

```bash
sleep 3
gh pr view <pr> --repo <owner>/<repo> --json mergeable,mergeStateStatus
```

Expected: `mergeable: MERGEABLE`. The `mergeStateStatus` may be `UNSTABLE` while CI restarts — that's fine and unrelated to the rebase.

If `mergeable: CONFLICTING`, the parity check missed something. Inspect with `gh pr diff` and report. The post-rebase confirmation comment in step 10 should reflect the actual mergeable state, not a wishful one.

## Step 10: Post post-rebase confirmation comment

Now that the push has landed and mergeability is checked, close the loop on the PR thread. This comment carries the receipt: new SHA, dropped commits, parity proof, current mergeable state.

```bash
NEW_HEAD=$(git rev-parse HEAD)
OLD_HEAD=$(cat /tmp/rebase-pr-<num>-old-head)
BASE_SHA=$(git rev-parse origin/<baseRefName>)
DIFFSTAT=$(cat /tmp/rebase-pr-<num>-post.diffstat)
DROPPED=$(cat /tmp/rebase-pr-<num>-dropped.txt 2>/dev/null || echo "_(none)_")
DROPPED_COUNT=$(grep -c '^- ' /tmp/rebase-pr-<num>-dropped.txt 2>/dev/null || echo 0)
KEEP_COUNT=$(git rev-list --count origin/<baseRefName>..HEAD)
MERGEABLE=<value from step 9>
CONFLICTS_RESOLVED=<newline-separated list from step 6b, or empty>
```

Post via `gh pr comment` using this template verbatim:

```bash
gh pr comment <pr> --repo <owner>/<repo> --body "$(cat <<EOF
**Rebase complete — force-push landed**

History-only rewrite. Diff against the new base is byte-equivalent to the diff against the old base (parity-checked locally before pushing).

| field | value |
| --- | --- |
| old HEAD | \`$OLD_HEAD\` |
| new HEAD | \`$NEW_HEAD\` |
| base | \`<baseRefName>\` @ \`$BASE_SHA\` |
| commits replayed | $KEEP_COUNT |
| commits dropped (already on base via squash-merge) | $DROPPED_COUNT |
| GitHub mergeable | \`$MERGEABLE\` |
| conflicts resolved manually | <count or "none"> |

<details>
<summary>Dropped commits</summary>

$DROPPED

</details>

<details>
<summary>Diff-stat vs new base (parity-checked against pre-rebase)</summary>

\`\`\`
$DIFFSTAT
\`\`\`

</details>

<details>
<summary>Conflicts resolved during rebase</summary>

\`\`\`
$CONFLICTS_RESOLVED
\`\`\`

</details>

If you had a local checkout of \`<headRefName>\`, run \`git fetch && git reset --hard origin/<headRefName>\` to pick up the rewritten history.
EOF
)"
```

If `$DROPPED_COUNT == 0`, drop the "Dropped commits" `<details>` block from the comment rather than emit an empty one.

If no files required manual conflict resolution, drop the "Conflicts resolved during rebase" `<details>` block (or set the table row to `none`).

If `$MERGEABLE != "MERGEABLE"`, replace the opening sentence with: *"Rebase pushed but GitHub reports `<state>`; investigating."* and add a TODO note. Do not pretend the rebase succeeded if it didn't fully clear the conflict.

## Reporting back to the user

After step 10, summarise in chat:

- Old HEAD → new HEAD
- New base SHA
- Commits replayed / commits auto-dropped
- Diff-stat parity result
- Final mergeable state
- Links to **both** PR comments (heads-up and confirmation)

Mirror the level of detail of the post-rebase comment so the chat history is self-contained even if someone reads it without the PR open.

## Edge cases

| Case | Handling |
|------|----------|
| PR is from a fork (`isCrossRepository: true`) | Stop, ask whether the user has push to the fork before posting the heads-up. |
| Working tree dirty (tracked changes) | Stop, ask the user to stash/commit/discard. Untracked files are fine. The heads-up comment has not posted yet at this point. |
| Base branch was renamed or deleted | `gh pr view` will show the new base; refuse if the base ref no longer exists. Do this before posting the heads-up. |
| PR has merge commits on the branch | Plain `git rebase` linearises by default; warn the user that any deliberate merge structure will be flattened. |
| Branch protection blocks force-push | Post the "aborted, no push happened" follow-up; surface the server's error verbatim and stop. |
| Multiple PRs share the head branch | Stop. Force-pushing affects every PR; require explicit confirmation per PR before the heads-up goes up. |
| Rebase produces zero commits ahead of base | Tell the user the PR is now empty (probably already merged via squash). Do not push; suggest closing the PR. Post a follow-up replacing the heads-up's promise with "PR appears already merged via squash; no push needed". |
| Pre-flight check fails before step 2 | No heads-up was posted, so no follow-up is needed. Just report to the user. |
| `mergeStateStatus: DIRTY` on GitHub | Usually means rebase needed; after push, expect `MERGEABLE`. If still `CONFLICTING` after a clean local rebase, parity or resolution missed something — inspect with `gh pr diff`. |
| Same file conflicts on every replayed commit | Consider interactive squash of PR commits first, or resolve once toward PR-tip shape so later commits apply cleanly. |
| Repo has frozen `source/` directories | Do not resolve conflicts inside them without user approval; abort and hand off. |

## What NOT to do

- Do not rebase silently — the PR thread always sees the heads-up first.
- Do not let the heads-up dangle; if the rebase aborts at any step after step 2, post the "aborted, no push happened" follow-up.
- Do not abort on the first conflict marker — resolve per [conflicts.md](conflicts.md) unless an explicit abort condition applies.
- Do not resolve conflicts by blindly taking one side (`--ours` / `--theirs`) without reading PR tip and base structure.
- Do not use `git push --force` (always `--force-with-lease`).
- Do not edit, amend, or re-order commits while rebasing. The skill is history alignment only; commit content stays byte-identical.
- Do not rebase a PR from a fork without confirming push access.
- Do not skip step 7's parity check, even on a "trivial" rebase.
- Do not delete the local branch after pushing — leave it in place for the user to inspect.
- Do not omit the post-rebase confirmation if the heads-up went up. The two comments are a contract: one always implies the other (or an explicit "aborted" follow-up).

## Summary

Resolve → **heads-up comment** → fetch → baseline diff → detect squash duplicates → rebase → **resolve conflicts if any** → parity-check → force-with-lease → verify mergeable → **confirmation comment**. The two PR comments, conflict resolution (not abort-by-default), and the parity check are the non-negotiables; everything else is mechanical.
