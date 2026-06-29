---
name: batch-address-pr-reviews
description: >-
  Triage the user's open GitHub PRs and address their review comments in
  parallel by forking one subagent per PR that runs the
  address-pr-review-comments skill. Use when the user asks to address /
  resolve / handle review comments across multiple open PRs at once, "all my
  open PRs", a range of PRs (e.g. #233..#252), or PRs greater than a number,
  optionally scoped to one reviewer (e.g. only Copilot's or only a named
  person's comments).
disable-model-invocation: true
---

# Batch Address PR Reviews

Orchestrate addressing review comments across many of the user's open PRs at
once. You pick the PRs, fork one subagent per PR that runs the
`address-pr-review-comments` skill, optionally filtered to a single reviewer,
then report a final summary table.

## Workflow

Copy this checklist into your working notes and track progress:

```
- [ ] 1. Resolve PR scope (range / greater-than / none) + reviewer filter
- [ ] 2. List the user's open PRs; if no scope given, ask which ones
- [ ] 3. Fork one subagent per selected PR (parallel) running /address-pr-review-comments
- [ ] 4. Wait for all subagents; collect their results
- [ ] 5. Post the final summary table (PR, issue, description, action taken)
```

## Step 1: Resolve scope and filter

Parse the user's request for two things:

- **PR scope** (one of):
  - **Range** — e.g. "#233 to #252", "233..252". Inclusive.
  - **Greater-than** — e.g. "PRs greater than #233", "from #233 onward". Treat
    as `number >= N` unless they say strictly greater (`> N`).
  - **None** — no PRs named. Go to Step 2 and ask.
- **Reviewer filter** (optional) — e.g. "only Copilot's comments", "only
  Sonbol's review comments". Map a person's name to their GitHub login (ask if
  ambiguous); Copilot is the bot login `copilot-pull-request-reviewer`. If no
  filter is given, address **all** unresolved reviewers.

Determine the repo. Default to the current repo (`gh repo view --json
nameWithOwner -q .nameWithOwner`). If the user names a repo or works across
multiple, confirm which one (or run per repo).

## Step 2: List open PRs (and ask if no scope)

List the user's own open PRs:

```bash
gh pr list --repo <owner>/<repo> --author @me --state open \
  --limit 100 --json number,title,url,headRefName,baseRefName \
  | jq 'sort_by(.number)'
```

Apply the scope filter from Step 1 (range / `>= N`). For each PR derive a small
description from its title (and linked issue if obvious from the title/branch).

**If the user gave no PR scope**, present every open PR as a summary table and
ask which they want before forking anything:

```
| PR | Title / description | Branch |
|----|---------------------|--------|
| #235 | stop_after collect-until-N stopping rule | feat/stop-after-232 |
| ... | ... | ... |
```

Use the `AskQuestion` tool (multi-select) listing each PR as an option plus an
"All of them" option. Do **not** fork subagents until the user picks.

If the user already gave a range / greater-than scope, skip the question and
proceed with that set (briefly echo the resolved list first).

## Step 3: Fork one subagent per PR (parallel)

Fork the subagents in a **single message with multiple `Task` tool calls** so
they run in parallel. Use `subagent_type: generalPurpose` and
`run_in_background: true`. One subagent per PR — never batch multiple PRs into
one subagent.

Orchestrate as needed: if the selected set is large (say > 6), launch in waves
to keep things manageable, but still launch each wave's PRs in parallel.

**Stacked PRs:** if two selected PRs are stacked (one's `baseRefName` is the
other's `headRefName`), note it. Running them in parallel is fine since each
subagent works on its own branch, but mention the stack in the final summary so
the user merges in order.

Each subagent gets a self-contained prompt (it does not see this conversation).
Use this template:

```
Address the review comments on GitHub PR <owner>/<repo>#<NUM> ONLY.

Read and follow the skill at
~/.cursor/skills/address-pr-review-comments/SKILL.md end-to-end for this one
PR: fetch unresolved review comments, classify each (Act / Discuss / Decline),
apply fixes plus the proactive sweep, run the self-review handoff gate before
pushing, push the fix commit, reply on each thread, resolve the threads you
fixed, and re-request Copilot review if Copilot is a reviewer.

<REVIEWER FILTER — include only if the user gave one:>
Only address review comments authored by `<login>`. Ignore comments from any
other reviewer (do not fix, reply to, or resolve them). If `<login>` has no
unresolved comments on this PR, make no changes and report that.

Scope rules:
- Touch only this PR's branch (<headRefName>). Do not modify any other PR.
- Keep the PR scope intact; no unrelated refactors.

Report back, concisely:
- PR number, title, and its linked issue number (from the PR body / "Closes
  #NN" / branch name) if any.
- One-line description of the PR.
- Action taken: how many comments Acted / Declined / Discussed, what you
  changed, whether you pushed, the pushed commit SHA, and whether Copilot was
  re-requested.
```

Fill `<login>` only when a reviewer filter was given. Keep the filter wording
identical across all subagents so they behave consistently.

## Step 4: Wait and collect

Let the backgrounded subagents finish (you are notified on completion; do not
poll reflexively). When all have returned, gather each one's reported PR
number, issue number, description, and action taken.

If a subagent reports a blocker (merge conflict, ambiguous Discuss item, auth
failure, nothing to do), capture it for the summary rather than silently
dropping the PR.

## Step 5: Final summary table

Post one table covering every PR you processed:

```
| PR | Issue | Description | Action taken |
|----|-------|-------------|--------------|
| [#235](url) | #232 | stop_after collect-until-N stopping rule | 1 comment addressed (doc-string example fix) + swept 2 sites; pushed `abc1234`; Copilot re-requested |
| [#243](url) | #242 | tag-triggered customer-wheel release workflow | 0 actionable; 2 Copilot comments declined with reasoning (mutable-tag policy); no push |
```

Columns:
- **PR** — linked PR number.
- **Issue** — the linked issue (or `—` if none).
- **Description** — one line on the PR's purpose.
- **Action taken** — what you did: counts of Act / Decline / Discuss, the push
  SHA (or "no push"), reviewer filter applied, Copilot re-request, and any
  blocker.

If a reviewer filter was used, state it once above the table (e.g. "Scoped to
Copilot's comments only").

## Notes

- The actual comment-by-comment discipline lives in
  `address-pr-review-comments`; this skill only selects PRs, fans out, and
  reports. Do not reimplement that logic here.
- Never fork a subagent for a PR the user did not select.
- `@me` resolves to the authenticated `gh` account, so this always targets the
  user's own PRs.
