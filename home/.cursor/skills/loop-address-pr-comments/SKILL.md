---
name: loop-address-pr-comments
description: >-
  Poll a given pull request on a recurring 5-10 minute cadence and run the
  address-pr-review-comments workflow on each tick, so new human/bot review
  comments get triaged, fixed, and replied to automatically until the PR is
  merged/closed or the user stops the loop. Use when the user asks to watch,
  poll, babysit, or continuously address review comments on a specific PR at an
  interval (e.g. "every 5-10 min keep addressing comments on PR 279"). Composes
  the `loop` skill (recurring wake) with the `address-pr-review-comments` skill
  (per-tick work).
disable-model-invocation: true
---

# Loop: Address PR Review Comments

Keep one pull request's review comments continuously handled. This skill wires
the **`loop`** skill's recurring wake mechanism to the
**`address-pr-review-comments`** skill's per-run workflow: every 5-10 minutes,
re-check the PR for new unresolved comments and process them.

This is a thin orchestrator. It does **not** re-implement either skill — it
reads and follows them:

- Recurring wake / sentinel / stop mechanics: `~/.cursor/skills-cursor/loop/SKILL.md`
- Per-tick comment triage/fix/reply: `~/.cursor/skills/address-pr-review-comments/SKILL.md`

Read both before arming the loop.

## Parse the invocation

Accept `/loop-address-pr-comments [interval] <pr>`.

- `<pr>` (required): a PR number, URL, or branch. If missing, print
  `Usage: /loop-address-pr-comments [interval] <pr>` and stop.
- `[interval]` (optional): `5m`..`10m`. Default **`7m`**. Clamp anything below
  `5m` to `5m` and above `10m` to `10m` (the user asked for a 5-10 min cadence);
  say so if you clamp.

Resolve `<pr>` to `owner/repo` + number once up front (`gh pr view <pr> --json
number,url,state,headRefName`) so every tick targets the same PR.

## Arm the loop

Use the `loop` skill's **Fixed Schedule** pattern with a PR-specific sentinel so
unrelated output never wakes this loop. Embed the PR in the payload:

```bash
while true; do
  sleep <interval-seconds>
  echo 'AGENT_LOOP_TICK_prcomments_<pr> {"prompt":"address-pr-review-comments for PR <pr>"}'
done
```

Start it as one background shell with:

- `notify_on_output` pattern `^AGENT_LOOP_TICK_prcomments_<pr>`,
- a short `reason` like `PR <pr> comment tick`,
- `debounce_ms` >= the interval.

Then follow the `loop` skill's arming checklist: check for an already-running
loop for this PR first (don't duplicate), smoke-check clean startup, and track
the PID so you can stop it on request.

## Run order

1. **Immediately after arming**, run one full `address-pr-review-comments` pass
   (the loop skill requires the prompt to run once at arm time; the first
   sentinel only arrives after the initial sleep, so startup does not
   double-run).
2. **On each tick**, read the latest matching payload and run another
   `address-pr-review-comments` pass on the same PR.

## Each tick: address-pr-review-comments

Follow that skill end-to-end each tick. Key reminders so ticks stay cheap and
safe:

- Fetch only **unresolved, non-outdated** threads (human + bot); if there are
  none new since the last tick, do nothing and report a one-line "no new
  comments" status — do not churn the PR.
- Classify Act / Discuss / Decline; fix Act items **plus the proactive sweep**;
  reply humbly to Decline items; ask at most one question on Discuss items.
- Honor the **self-review handoff before push** step: if
  `~/.cursor/skills/self-review-before-pr/` is installed, run its loop and
  `mark-reviewed` before pushing (this repo's push hook enforces it).
- Push once, then post replies so thread links match the final SHA; re-request
  Copilot if it's a reviewer.

## Stop conditions

Stop the loop (kill the tracked PID, then await the shell task so its completion
notification is consumed) when any of these hold — and say why:

- The user asks to stop.
- `gh pr view <pr> --json state,mergedAt` shows the PR **merged or closed**.
- **Copilot signals "no comments".** This is the primary "nothing left to do"
  stop signal. After each tick pushes fixes and re-requests Copilot, wait for
  its fresh review to land, then read the latest Copilot review:

  ```bash
  gh api repos/{owner}/{repo}/pulls/<pr>/reviews \
    --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer" or .user.login=="Copilot")] | last | {state, body}'
  # inline comments from that same review (must be zero)
  gh api repos/{owner}/{repo}/pulls/<pr>/comments \
    --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer" or .user.login=="Copilot") | select(.in_reply_to_id==null)] | length'
  ```

  If that latest Copilot review has **no inline comments** and its body states it
  found nothing (e.g. contains "no comments", "No suggestions", or an equivalent
  clean-pass phrase), stop the loop — Copilot has confirmed there is nothing left
  to address.

Never arm a second loop for a PR that already has one running.

## Per-tick status

Keep tick output short: PR, interval, what changed this tick (comments handled /
declined / none), push SHA if any, and when the next tick fires. On stop, state
that the loop stopped and why.
