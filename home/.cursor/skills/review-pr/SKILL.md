---
name: review-pr
description: >-
  Perform a diligent pull request review covering feature correctness, software
  design, and future scalability, then post the findings as inline + summary
  review comments on the GitHub PR. Each comment is tagged with a criticality of
  High, Medium, or Low so the author can prioritize fixes, gated on confidence to
  cut noise, with one-click `suggestion` blocks where a concrete fix exists and a
  one-line verdict (ship / fix-before-ship / hold). It also cross-checks any
  existing GitHub Copilot or CodeRabbit comments on the PR (confirm, dismiss, or
  extend each). On a re-review of a PR that was already reviewed, it also checks
  which prior comments were addressed, verifies the fixes are correct, flags any
  unaddressed critical items, hunts for gaps the last review missed, and approves
  the PR when nothing is left. Use when the user gives you a PR (number, URL, or
  branch) and asks for a code review, a design review, a scalability review, a
  re-review/follow-up review, or to add review comments on a PR.
---

# Review PR

Your job: review a GitHub pull request like a senior reviewer who cares about
three things at once — does the **feature** work, is the **design** sound, and
will it **scale** — then post the findings directly on the PR with each comment
tagged High / Medium / Low so the author knows what to fix first.

Be specific, be kind, and ground every comment in the actual diff. A vague
review wastes the author's time more than no review. Keep every comment short and
in plain language — say what's wrong and how to fix it, nothing more.

## Workflow

Copy this checklist into your working notes and track progress:

```
- [ ] 1. Preflight (gh installed + authed) + fetch metadata, diff, changed files, prior human review history, existing bot reviews
- [ ] 2. Understand intent; decide first review vs re-review; for large diffs, triage the riskiest files first
- [ ] 3. Review the FULL current diff through 3 lenses: Feature, Design, Scalability (+ baseline checks) — reading surrounding file context, not just the diff
- [ ] 4. (Re-review only) On top of the full Step 3 review, reconcile every prior human comment: fixed / fixed-wrong / unaddressed
- [ ] 5. Cross-check existing bot reviews (Copilot / CodeRabbit): confirm, dismiss, or extend each
- [ ] 6. Gate findings on confidence, self-critique to drop weak ones, then assign a criticality (High/Medium/Low) + a fix (suggestion block where possible)
- [ ] 7. Re-fetch reviews/comments/head SHA (freshness re-check), reconcile anything new since Step 1, THEN post inline comments + one summary review with a one-line verdict (approve only if still a clean re-review)
- [ ] 8. Report a short recap in chat
```

## Step 1: Preflight + fetch the PR

**Preflight — check `gh` before anything else.** Don't discover a missing CLI
mid-review:

```bash
gh --version        # is the CLI installed?
gh auth status      # is it authenticated to the right host?
```

If `gh` is missing or unauthenticated, stop and tell the user how to fix it
(install from https://cli.github.com/, then `gh auth login`). If `gh` works but
the PR is not on GitHub, ask the user to paste the diff and tell them you'll
return drafted comments instead of posting.

Resolve `<owner>`, `<repo>`, and `<pr>` from the URL/number the user gave. Use
the GitHub CLI. Read scoped JSON, not giant payloads.

```bash
# Metadata + the author's stated intent
gh pr view <pr> --json number,title,body,headRefName,baseRefName,url,additions,deletions,changedFiles,files

# The diff (this is the source of truth for the review)
gh pr diff <pr>

# Latest commit on the PR head (needed for posting inline comments)
gh pr view <pr> --json commits --jq '.commits[-1].oid'
```

### Also fetch the prior review history

A PR may already have been reviewed (by you in a previous pass, or by someone
else). Pull that history so you can tell a first review apart from a re-review:

```bash
# Submitted reviews (summary bodies + APPROVE/REQUEST_CHANGES/COMMENT state)
gh api repos/<owner>/<repo>/pulls/<pr>/reviews

# Inline review comments (the line-level findings + their threads/replies)
gh api repos/<owner>/<repo>/pulls/<pr>/comments

# When the existing comments were posted vs the latest commits, so you know
# which commits landed AFTER each comment (i.e. could contain the fix)
gh pr view <pr> --json commits --jq '.commits[] | {oid, date: .committedDate}'
```

If there are no prior reviews or inline comments, this is a **first review** —
skip Step 4 and proceed normally. If prior comments exist, this is a
**re-review** — Step 4 is required.

### Also note existing automated (bot) reviews

The PR may already carry comments from GitHub Copilot, CodeRabbit, or similar
bots. You fetched these above (they appear in the same `reviews` / `comments`
payloads, authored by accounts like `github-copilot[bot]` or `coderabbitai[bot]`).
Record which bots commented and roughly what they flagged — you'll reconcile
your own findings against them in Step 5. Do **not** read the bot comments in
detail yet; forming your own view first (Step 3) keeps your findings independent
and avoids anchoring on the bot's take.

## Step 2: Understand intent before judging

Read the PR title, body, and any linked issue. Before reviewing a line, know
what the change is *trying* to do. Review the diff against its stated goal — not
against the code you would have written. Only review the changed lines and their
immediate blast radius; do not review unrelated pre-existing code.

Using the prior review history from Step 1, decide the mode:
- **First review** — no prior reviews or inline comments exist. Do Step 3, skip
  Step 4, then continue through Steps 5–7.
- **Re-review** — prior comments exist. Do Step 3 *and* Step 4, in that order. A
  re-review is a **full review of the current diff**, not just a pass over the old
  comments. The author has pushed new commits since the last review, so the diff
  now contains both the old (possibly-fixed) code *and* brand-new code that was
  never reviewed. Run all three lenses (Step 3) across the **entire** current
  diff — reviewing any newly added code as thoroughly as on a first pass — and
  *then* reconcile the prior comments (Step 4) on top of that. Reconciling old
  comments is additive; it never replaces or narrows the full review down to only
  the previously-flagged lines.

### Large diffs: triage the riskiest files first

A huge PR reviewed front-to-back gets a shallow, fatigued review. For a large
diff (roughly >500 changed lines, or many files), first skim the file list and
rank files by risk — auth, money, data migrations, concurrency, public APIs,
and the biggest churn go first. Review those high-risk files in depth, then work
down. Keep each focused reading pass to a digestible chunk (~1,000–1,500 lines)
rather than trying to hold the whole diff in your head at once. If the PR is too
large to review responsibly in one go, say so in the summary and call out which
areas you covered in depth versus skimmed.

## Step 3: Review through three lenses

Apply all three lenses to the **full current diff** — every changed line — on both
a first review and a re-review. On a re-review the diff includes code added by the
new commits that was never reviewed before; review that new code as thoroughly as
you would on a first pass. Do **not** skip Step 3 or shrink it to only the
previously-commented lines just because prior comments exist. For the detailed
checklist under each lens, read [reference.md](reference.md) — it expands every
bullet below.

**Read the surrounding code, not just the diff.** A diff hides the context that
makes a change correct or broken — the function it sits in, the caller, the type
it returns, the invariant it relies on. For any non-trivial changed hunk, open
the full file (and key callers/callees) so you can catch logic errors, broken
contracts, and missing call-site updates that a diff-only read misses. The diff
tells you *what changed*; the file tells you *whether it's right*.

### Lens 1 — Feature (does it do the job, correctly)
- Does the code actually implement what the PR claims?
- Edge cases, empty/null inputs, boundary values, error paths.
- Regressions to existing behavior; backward compatibility.
- Tests: do they exist, do they cover the new behavior and the failure paths?

### Lens 2 — Design (is it built well)
- Right abstraction and placement; single responsibility; no logic in the wrong layer.
- Naming, readability, duplication (DRY), dead code, leaky abstractions.
- Coupling/cohesion, clear interfaces/contracts, dependency direction.
- Consistency with existing patterns and conventions in this codebase.

### Lens 3 — Scalability & future-proofing (will it hold up)
- Performance under growth: N+1 queries, unbounded loops/memory, O(n²) hot paths.
- Data growth, pagination, indexing, caching, connection/resource limits.
- Concurrency: races, locking, idempotency, retries, statefulness.
- Extensibility: will the next feature fit, or force a rewrite? Hard-coded limits,
  magic numbers, config that should be externalized, migration/versioning concerns.
- Observability & operability at scale: logging, metrics, rate limits, failure modes.

### Baseline checks (always)
Security (injection, authz, secrets, unsafe deserialization), correctness of
error handling, and project-rule compliance (read repo `AGENTS.md`,
`CLAUDE.md`, `.cursor/rules/`, lint configs, CONTRIBUTING).

## Step 4: Reconcile prior comments (re-review only)

Skip this entire step on a first review. On a re-review, go through **every**
prior inline comment and submitted-review item and classify it. For each one,
read the code as it stands now (in the latest diff) at the spot the comment
referred to, and judge whether the concern still holds.

For each prior comment, assign exactly one status:

| Status | Meaning | What you do |
|--------|---------|-------------|
| **Fixed (correct)** | The author changed the code and the change genuinely resolves the original concern as intended. | Reply briefly confirming it's resolved (e.g. "Resolved — thanks."). No new finding. |
| **Fixed (wrong/partial)** | The author touched it but the fix is incomplete, introduces a new problem, or misunderstands the original point. | Raise a **new finding** with criticality, explaining what's still wrong and the correct fix. Reference the original comment. |
| **Unaddressed** | The code is unchanged and the concern still applies. | Re-raise it. Carry over (or raise) its criticality. |

Two rules that the user specifically asked for:

1. **Unaddressed High-criticality items are non-negotiable.** If any prior
   High/critical comment was *not* fixed, surface it loudly as a **reminder /
   final check** — list each one in the summary body under a clear heading
   (e.g. "Still open from last review") so it cannot be missed, in addition to
   re-raising it inline. Do not let a previously-flagged critical issue slip
   through silently just because the author pushed other changes.

2. **Verify fixes, don't trust them.** A comment marked addressed is not done
   until you've confirmed the new code actually does what the comment asked —
   correctly and without side effects. Only then mark it Fixed (correct).

Step 3 has already reviewed the full current diff; this step is layered *on top*
of it, never a substitute for it. Before finishing, confirm Step 3 actually
covered the code the new commits added (not just the previously-flagged spots),
and flag anything the last pass missed or that the fixes themselves introduced.
Anything new becomes a normal finding.

Decide the outcome of the re-review:
- **Clean** — every prior comment is Fixed (correct) and the gap sweep found
  nothing new. → Approve the PR (see Step 7).
- **Not clean** — anything is Fixed (wrong/partial), Unaddressed, or the gap
  sweep found a new issue. → Post findings as usual; do **not** approve.

## Step 5: Cross-check existing bot reviews (Copilot / CodeRabbit)

If you noted bot comments in Step 1, reconcile them now — **after** you've formed
your own view in Step 3, never before. For each bot comment, read the code where
it points and classify it:

| Verdict | When | What you do |
|---------|------|-------------|
| **Confirm** | The bot is right and the issue matters. | Fold it into your own findings with your criticality. Don't blindly copy P0–P3 or the bot's wording — re-judge it. Attribute briefly (e.g. "Copilot flagged this too"). |
| **Dismiss** | False positive, stale (already fixed in a later commit), out of the PR's scope, or contradicts a repo convention. | Don't re-post it. If it's a *prominent* bot comment the author will wonder about, note in the summary that you reviewed it and why it doesn't hold. |
| **Extend** | The bot found a symptom but missed the root cause or a related instance. | Raise your own finding that goes further, referencing the bot's. |

Rules:
- **Don't rubber-stamp bots and don't pad your review with their noise.** Bots
  over-flag; your value is judgment. A confirmed bot finding still has to clear
  the same confidence and criticality bar as your own (Step 6).
- **De-duplicate.** If you and a bot found the same thing, post it once (yours),
  not twice.
- This step is additive to Step 3, never a substitute. The review must stand on
  its own findings even if there are zero bot comments.

## Step 6: Gate on confidence, self-critique, then assign criticality

You now have a raw list of candidate findings from Steps 3–5. Before tagging and
posting, filter it.

### Confidence gate (cut false positives)

Only post a finding you're genuinely confident is real. If you're not sure the
code actually does the bad thing — e.g. you'd need to see code outside the diff
you couldn't read, or it depends on a runtime fact you can't confirm — either go
read enough to *become* confident, or drop it. A noisy review with shaky findings
trains the author to ignore you. When a finding is plausible but unverified and
you can't confirm it, phrase it as an explicit question ("Is `x` guaranteed
non-null here?"), not an assertion, and tag it no higher than Medium.

### Self-critique pass

Before tagging, reread your own list and ask: *which of these are the weakest?*
Drop or downgrade anything that is a personal preference dressed up as a problem,
a restatement of something the code already handles, or a nit you'd be annoyed to
receive. Aim for a review where every comment earns its place.

### Assign criticality

Tag each surviving finding with exactly one level. Lead each comment body with
the tag.

| Level | Use when | Author expectation |
|-------|----------|--------------------|
| **High** | Bug, security hole, data loss/corruption, breaking change, scalability cliff that will hurt in production, missing test for new critical behavior. Merging as-is is risky. | Must fix before merge |
| **Medium** | Design smell, weak abstraction, maintainability/readability problem, missing edge-case handling, a scalability concern that is not yet urgent, thin test coverage. | Should fix; fix now or file a tracked follow-up |
| **Low** | Style/nit, naming polish, optional refactor, minor doc/comment gap, preference with no objective impact. | Nice to have; author's discretion |

Rules:
- When unsure between two levels, pick the **higher** one and say why.
- Every comment must include a concrete, actionable suggestion — ideally a code
  snippet or a one-line "do X instead". Never post "this is wrong" with no fix.
- Do not invent problems to fill a quota. A clean PR gets a short review.
- Praise is allowed and useful: call out a genuinely good pattern briefly.

### Keep comments short and plain

- Use simple, everyday words. Write like you'd talk to a teammate, not a spec.
- Get to the point: state the problem, then the fix. Skip preamble and hedging.
- Aim for 1–2 short sentences plus the fix. Cut anything that doesn't change what
  the author does.
- One issue per comment. Don't stack caveats or restate the obvious.
- Prefer a short code snippet over a paragraph explaining the snippet.

### Comment body format (use verbatim shape)

```
**[High]** <one-line problem>

<1 short sentence on why, only if it isn't obvious.>

Fix: <the change to make — a code snippet or a one-line instruction.>
```

### Prefer one-click `suggestion` blocks

When you have a concrete, line-scoped fix, write it as a GitHub `suggestion`
block so the author can apply it in one click instead of retyping. The block
replaces the exact line(s) the comment is attached to, so the replacement must be
complete and correct for that range. Shape of the comment body:

~~~
**[Medium]** Off-by-one — this skips the last element.

Fix:
```suggestion
for i in range(len(items)):
```
~~~

Notes:
- The suggestion replaces the commented line(s). For a multi-line replacement,
  attach the comment to the whole range (`start_line`..`line`) and include every
  replacement line in the block.
- Use suggestion blocks for mechanical, unambiguous fixes. For architectural
  advice, questions, or anything spanning multiple files, use prose `Fix:`
  instead — a suggestion the author would have to heavily edit is worse than a
  clear sentence.
- When suggesting an edit to a file that itself contains triple backticks (e.g.
  markdown), fence the suggestion with four backticks or with `~~~` so the inner
  fences don't break it.

## Step 7: Post the review on the PR

### Step 7.0: Freshness re-check (MANDATORY, do this immediately before posting)

Time passes between Step 1 and this point, and automated reviewers (Copilot,
CodeRabbit) re-review **asynchronously** on every push — so a fresh review or
inline comment, or even a new commit, routinely lands *during* your review. If
you post on the state you fetched in Step 1 you can approve over comments you
never saw. This is the single most common way this skill produces a wrong
verdict, so never skip this step.

Immediately before building the payload, re-fetch and diff against Step 1:

```bash
# Current head SHA — did the author push while you were reviewing?
gh pr view <pr> --json commits --jq '.commits[-1].oid'

# Latest submitted reviews and inline comments (bots included)
gh api repos/<owner>/<repo>/pulls/<pr>/reviews  --jq 'sort_by(.submitted_at) | .[-5:] | .[] | {user:.user.login, state, submitted_at}'
gh api repos/<owner>/<repo>/pulls/<pr>/comments --jq 'sort_by(.created_at)   | .[-8:] | .[] | {user:.user.login, created_at, path, line, body:(.body[0:120])}'
```

Then reconcile:
- **New human/bot comment since Step 1** → run it through Step 5 (confirm /
  dismiss / extend) and fold any confirmed finding into this review. Do not
  ignore it just because it appeared late.
- **New commit since the SHA you reviewed** → your review is now stale. Re-run
  Step 3 on the new diff (at least the changed hunks) before posting, and set
  `commit_id` to the *new* head SHA.
- **Nothing new** → proceed.

### Post the review

Post **one** PR review that bundles all inline comments plus a summary body, in a
single API call. Inline comments attach to exact lines; the summary gives the
author the big picture, a count by criticality, and a one-line verdict. On a
re-review, the summary should also state which prior comments are now resolved and
call out anything still open from the last review.

**Lead the summary with a one-line verdict** so the author gets a usable signal,
not just a list:
- **ship** — no High/Medium findings; Low nits or nothing at all.
- **fix-before-ship** — at least one High, or Mediums that really should land
  first.
- **hold** — fundamentally wrong approach or needs a rethink before line-level
  feedback is worth it.

Write the review payload to a JSON file, then submit it:

```bash
cat > /tmp/pr_review.json <<'EOF'
{
  "commit_id": "<head-commit-oid from the Step 7.0 re-check, NOT the stale Step 1 value>",
  "event": "COMMENT",
  "body": "## Review summary\n\n**Verdict: fix-before-ship**\n\n<2-4 sentence overall take>\n\n**Findings:** <H> High · <M> Medium · <L> Low\n\n<High items listed here so they are unmissable>",
  "comments": [
    { "path": "src/foo.py", "line": 42, "side": "RIGHT",
      "body": "**[High]** <one-line problem>\n\nFix: <one-line fix or snippet>" },
    { "path": "src/foo.py", "start_line": 60, "line": 65, "side": "RIGHT",
      "body": "**[Medium]** <one-line problem>\n\nFix: <one-line fix>" }
  ]
}
EOF

gh api repos/<owner>/<repo>/pulls/<pr>/reviews \
  --method POST --input /tmp/pr_review.json
```

Posting notes:
- `line` is the line number in the file's new version; use `side: "RIGHT"` for
  added/context lines and `side: "LEFT"` only to comment on removed lines.
- For a multi-line comment, set both `start_line` and `line`.
- `event` selection:
  - `"COMMENT"` (neutral) — default whenever you have findings to post.
  - `"APPROVE"` — use **only** for a *clean re-review* per Step 4 (every prior
    comment Fixed-correct and the gap sweep found nothing new), or when the user
    explicitly asks you to approve. On a clean re-review, approve with a single
    one-line body, e.g. `"No further review comments — approving."` (keep the
    `comments` array empty). Do not approve a first review on your own initiative.
    **APPROVE is the least reversible action, so it demands the strictest
    freshness bar:** only approve when the Step 7.0 re-check found nothing new
    (no new commit, no new human/bot comment) since Step 1. If anything landed —
    even a bot comment seconds ago — do not approve; downgrade to `"COMMENT"`,
    reconcile the new item first, and re-run Step 7.0 once more right before you
    finally post. When in doubt, `"COMMENT"` over `"APPROVE"`.
  - `"REQUEST_CHANGES"` — only if the user explicitly asks you to block the PR.
- Never approve when anything is unaddressed, fixed wrong/partially, or newly
  found — post those as `"COMMENT"` instead.
- If an inline comment fails because the line is outside the diff hunk, move that
  finding into the summary `body` (reference the file/line in text) instead of
  dropping it.
- Do not modify any code in this skill — reviewing is read-only. Posting comments
  is the only write action.

## Step 8: Recap in chat

After posting, give the user a short recap: the PR, the verdict, the counts by
criticality, the High items in one line each, and the review URL. Keep it tight.

On a re-review, also include: how many prior comments are now resolved, any that
were fixed incorrectly or left unaddressed (with the still-open High items called
out explicitly), any new gaps found, and — if you approved — a one-line note that
the PR was approved with no further comments.

## What NOT to do

- Do not change code or push commits; reviewing is read-only.
- Do not request-changes unless explicitly asked. Do not approve a first review on
  your own initiative — auto-approve only on a *clean re-review* (Step 4) or when
  the user asks.
- Do not mark a prior comment resolved without confirming the fix actually does
  what the comment asked, correctly and without side effects.
- Do not let a previously-flagged High/critical comment slip through silently when
  it's still unaddressed — surface it as a final-check reminder.
- Do not post (and above all do not APPROVE) on the state you fetched in Step 1 —
  always run the Step 7.0 freshness re-check immediately before posting, because
  bot reviewers comment asynchronously and a new comment or commit can land mid-review.
- Do not review code outside the PR's diff and its immediate blast radius.
- Do not post comments without a criticality tag or without a concrete suggestion.
- Do not pad the review with low-value nits to look thorough.
- Do not post a finding you can't stand behind — if you're not confident it's real,
  verify it or phrase it as a question, don't assert it.
- Do not rubber-stamp or re-post bot (Copilot/CodeRabbit) comments wholesale; judge
  each one and de-duplicate against your own findings.
- Do not overrule the codebase's existing conventions with personal preference;
  if you disagree with a convention, raise it as Low and say it's a preference.
