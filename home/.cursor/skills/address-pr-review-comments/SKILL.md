---
name: address-pr-review-comments
description: >-
  Triage and respond to pull request review comments from humans, GitHub
  Copilot, Bugbot, or other automated reviewers. Use when the user asks to
  address PR comments, respond to a code review, resolve review feedback, or
  handle Copilot/Bugbot suggestions on a GitHub PR. Classifies each comment as
  worth-fixing vs. nitpick, applies fixes plus proactive sweeps for similar
  gaps elsewhere in the diff, and replies to non-actionable comments with a
  humble, reasoned justification. After code changes, automatically chains into
  the self-review-before-pr skill when that skill is installed on disk, so push
  hooks and quality gates stay satisfied without the user attaching both skills.
---

# Address PR Review Comments

Your job is to systematically work through every unresolved review comment on a pull request, decide whether to act on it or push back, apply fixes (including proactive sweeps for the same class of issue), and reply on the PR with clear reasoning. Stay humble: a reviewer's time is a gift, even when you disagree.

## Workflow

Copy this checklist into your working notes and track progress:

```
- [ ] 1. Fetch all unresolved review comments (human + bot)
- [ ] 2. Classify each comment (Act / Discuss / Decline)
- [ ] 3. For Act items: implement fix + proactive sweep
- [ ] 4. For Decline items: draft humble reply with reasoning
- [ ] 5. For Discuss items: ask one clarifying question
- [ ] 6. Self-review gate (if installed): see "Self-review handoff before push"
- [ ] 7. Post replies and resolve threads
- [ ] 8. Re-request Copilot review if Copilot is a reviewer
- [ ] 9. Capture patterns to avoid in future PRs
```

Do not skip step 3's proactive sweep or step 9's pattern capture - they are the difference between this skill and naive comment-by-comment fixes.

**Ordering:** Run the self-review handoff **after** all Act fixes are committed locally and **before** `git push` (in Step 7). If self-review finds new issues and produces commits, finish that loop first, then push once, then post PR replies (so thread links match the final SHA). If you already pushed before self-review caught issues, push again after the follow-up commit, then reply on the PR.

## Step 1: Fetch comments

Use the GitHub CLI. Prefer scoped reads over dumping entire JSON payloads into context.

```bash
# PR metadata + thread URLs
gh pr view <pr> --json number,headRefName,baseRefName,url,reviewDecision

# Inline review comments (file/line bound)
gh api repos/{owner}/{repo}/pulls/<pr>/comments \
  --paginate \
  --jq '.[] | select(.in_reply_to_id == null) | {id, user: .user.login, path, line, body, html_url}'

# Top-level review summaries (Copilot/Bugbot post here too)
gh api repos/{owner}/{repo}/pulls/<pr>/reviews \
  --jq '.[] | {id, user: .user.login, state, body, submitted_at}'

# Resolved status (GraphQL - inline comments only)
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$pr){
        reviewThreads(first:100){
          nodes{ id isResolved isOutdated comments(first:1){nodes{body path}} }
        }
      }
    }
  }' -f owner=<owner> -f repo=<repo> -F pr=<pr>
```

Filter out `isResolved: true` and `isOutdated: true` threads before reading bodies. Read only the comment body plus the minimum file/line context needed to act.

If `gh` is unavailable or the PR is on a non-GitHub host, ask the user to paste the comments.

## Step 2: Classify each comment

For each comment, assign exactly one bucket using the rubric below. Bias toward **Act** when in doubt - reviewers usually have context you lack.

| Bucket | Apply when... | Action |
|--------|---------------|--------|
| **Act** | Bug, regression, security issue, broken contract, missing test for new behavior, violation of an established project convention, accessibility/perf issue with measurable impact, or any factually correct observation | Fix it + run proactive sweep |
| **Discuss** | Reviewer's intent is unclear, the fix has multiple valid shapes with real trade-offs, or you need domain context you don't have | Ask ONE focused clarifying question |
| **Decline** | Pure stylistic preference contradicting the project's existing convention, suggestion based on a misreading of the diff, out-of-scope refactor, micro-optimization with no evidence of impact, duplicate of an already-addressed comment, or advice that would make the code worse by an objective measure (clarity, correctness, tested behavior) | Reply with humble reasoning, do not change code |

### Decline checklist (must answer YES to all before declining)

- [ ] Have I re-read the exact lines the reviewer pointed at?
- [ ] Have I checked whether the project has a written convention favoring the reviewer's suggestion (lint rules, style guide, AGENTS.md, neighboring code)?
- [ ] Can I state a concrete reason the change would not improve correctness, clarity, performance, or safety?
- [ ] Am I confident the reviewer (or a future reader) will accept the reasoning, or at least find it respectful?

If any answer is "no", reclassify as **Act** or **Discuss**.

### Special handling for bot reviewers (Copilot, Bugbot, CodeRabbit, Sonar, etc.)

Bots produce a high false-positive rate. Validate each suggestion against the actual code before acting:

- Confirm the file/line still exists and matches what the bot quoted.
- Reproduce the claimed bug mentally or with a quick test.
- Check whether the "fix" introduces a new bug (off-by-one, swallowed exceptions, broken null handling).
- Ignore generic advice like "consider adding a comment" unless the code is genuinely unclear.

Bots are still useful - they catch real issues. Treat them like a junior reviewer: verify, then act or decline with the same humility you'd show a human.

## Step 3: Act items - fix + proactive sweep

For every Act item, do **both**:

1. **Apply the targeted fix** on the lines called out.
2. **Sweep for the same class of issue** in the rest of the PR diff first, then in closely-related files. The goal is to never receive the same comment twice on the same PR.

Examples of what "same class of issue" means:

| Comment | Sweep target |
|---------|--------------|
| "This `await` is missing inside a loop" | All loops in the diff that call async functions |
| "Magic number 86400 should be a named constant" | All numeric literals in the diff that represent durations/sizes |
| "Missing null check before `.id`" | All property accesses on values returned from the same source |
| "Use `logger.info` not `print`" | All `print` calls in the diff |
| "Test missing for error path" | All new functions in the diff that throw/return errors |
| "Inconsistent naming: `userId` vs `user_id`" | All identifiers in the diff in the same scope |

Run the sweep with Grep against the changed files (`git diff --name-only <base>...HEAD`). Mention the sweep in your reply: *"Fixed here and applied the same change to <N> other call sites in this PR."* This shows the reviewer you internalized the feedback rather than patching the one line.

If the sweep reveals an issue **outside** the PR diff, do not silently expand the PR. Either:

- Mention it in the reply and ask whether to fix in this PR or open a follow-up.
- Open a follow-up issue/PR and link it in the reply.

## Step 4: Decline items - humble reply template

Replies must be short, specific, grateful, and reasoned. Never sarcastic, never defensive, never use the word "actually" as a sentence opener.

### Reply template

```
Thanks for flagging this - I considered it and want to keep the current
approach for now. <One or two sentences of concrete reasoning grounded in
the code, a convention, or a measurement.> Happy to revisit if you feel
strongly or if I'm missing context.
```

### Worked examples

**Comment:** "Use a ternary here instead of if/else - it's more concise."

```
Thanks for the suggestion. I'm keeping the if/else because the branches
do different side effects (logging in one, metric emit in the other),
and a ternary would force both into expressions and hurt the stack trace
on errors. Happy to switch if you've seen a cleaner form.
```

**Comment (from Copilot):** "Consider using `Object.freeze` on this constant."

```
Thanks - I looked at this and we don't freeze other module-level
constants in this package (see `config.ts`, `limits.ts`). Adding it only
here would be inconsistent without a real mutation risk, since the
object is never re-exported. Leaving as-is for consistency.
```

**Comment:** "This function is too long, split it up."

```
Appreciate the read. I tried splitting it and the helpers ended up with
4+ parameters each and only one caller, which felt worse than the
inlined version. I added a section comment to make the phases easier to
scan. Open to refactoring if a natural seam appears later.
```

### Tone rules

- **Lead with thanks**, not with "but" or "however".
- **Cite something concrete**: a file, a convention, a measurement, a prior decision.
- **Leave the door open**: "happy to revisit", "open to other ideas", "let me know if I'm missing context".
- **Never** call a comment "nitpick", "bikeshedding", "wrong", or "unnecessary" to the reviewer's face. Those are internal classifications.
- **Never** quote the reviewer back at them sarcastically.
- **Never** decline silently - every Decline gets a reply.

## Step 5: Discuss items

Ask exactly one clarifying question per thread. Examples:

- "Do you want this enforced at the type level or at runtime?"
- "Should this handle the empty-list case by throwing or by returning a default?"
- "Is the concern correctness or perf? That changes which approach I'd pick."

Do not change code on a Discuss item until the reviewer responds.

## Step 6: Self-review handoff before push (chains `self-review-before-pr` when available)

This step is **not** a second skill the user must attach. **Always** probe for the
personal self-review install; if it exists, **read** `~/.cursor/skills/self-review-before-pr/SKILL.md` and **execute** its full review loop for the current repo before any push that publishes review fixes.

**Detection (run from any directory; prints `installed` or `missing`):**

```bash
if [ -f "$HOME/.cursor/skills/self-review-before-pr/scripts/self_review.py" ] \
   && [ -f "$HOME/.cursor/skills/self-review-before-pr/SKILL.md" ]; then
  echo installed
else
  echo missing
fi
```

- **If the output is `installed`:** Treat this as mandatory for this workflow:
  follow the self-review skill end-to-end (including `python3 …/self_review.py scan`,
  manual KB pass, fixes, re-scan, and `mark-reviewed --summary "…"` on the commit
  you will push). Report that same summary in chat so the loop is not silent.
  That satisfies the same gate as a dedicated "self-review before PR" run and, when
  the `before-push-self-review.sh` hook is enabled, clears it in one pass instead of
  bouncing off it.
- **If the output is `missing`:** Do **not** fail the overall task. Tell the user in one
  sentence that the self-review skill is not installed at the expected path, so
  only this skill's review discipline ran; recommend installing or attaching
  `self-review-before-pr` if they use the push hook.

Do not assume the self-review skill is in the session rules list; **filesystem
presence** is the source of truth.

## Step 7: Post replies and resolve

- Post each reply on the specific thread (use `gh api ... /pulls/comments/{id}/replies` for inline, or `gh pr comment` for top-level).
- Resolve threads where you applied the fix or where the reviewer's last word was acceptance.
- Do **not** resolve a thread where you declined - let the reviewer resolve it after they've seen your reasoning.
- Push the fix commit with a message that references the review (e.g. `address review: null-check feed entries (#1234)`).

## Step 8: Re-request Copilot review

If GitHub Copilot is one of the PR's reviewers, re-request its review **after** you have pushed the fix commit (so it re-reviews the updated diff). Copilot does not automatically re-review when you push new commits - you must explicitly ask again.

First confirm Copilot is actually a requested or prior reviewer (skip this step entirely if it isn't):

```bash
# Requested reviewers (humans + bots) + reviewers who already reviewed
gh pr view <pr> --json reviewRequests,reviews \
  --jq '{requested: [.reviewRequests[].login], reviewed: [.reviews[].user.login]} '
```

Copilot shows up as the bot login `copilot-pull-request-reviewer` (sometimes surfaced as `Copilot`). If present, re-request it via the GraphQL `requestReviews` mutation, since `gh pr edit --add-reviewer` does not reliably target the Copilot bot:

```bash
# 1. Resolve the PR node id and the Copilot bot's suggested-reviewer id
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$pr){
        id
        suggestedReviewers { reviewer { ... on Bot { id login } ... on User { id login } } }
      }
    }
  }' -f owner=<owner> -f repo=<repo> -F pr=<pr>

# 2. Re-request review using the PR node id + Copilot bot id from step 1
gh api graphql -f query='
  mutation($prId:ID!,$botId:ID!){
    requestReviews(input:{pullRequestId:$prId, botIds:[$botId], union:true}){
      pullRequest { id }
    }
  }' -f prId=<pr-node-id> -f botId=<copilot-bot-id>
```

If the Copilot bot id is not in `suggestedReviewers` (it usually appears once it has reviewed before), fall back to the UI re-request or `gh pr edit <pr> --add-reviewer copilot-pull-request-reviewer` and confirm it took. Mention in your summary that you re-requested Copilot so the user expects a fresh pass.

## Step 9: Capture patterns (avoid the same comment next time)

After the PR is settled, write a one-liner for each **valid** comment into the project's running list of review patterns. Check, in order:

1. `.cursor/rules/` in the repo - add or update a rule file if the pattern is project-specific.
2. `AGENTS.md` at the repo root - append to a "Recurring review feedback" section if one exists.
3. A personal note (e.g. `~/.cursor/notes/review-patterns.md`) for patterns that recur across repos.

Format:

```
- <project>: <one-line description of the pattern> | seen in PR #<num>
```

The next time you open a PR in this repo, scan that list before pushing. The goal is for each review comment to fire at most twice across your career on the same codebase.

## What NOT to do

- Do not change unrelated code while addressing comments. Keep the PR scope intact.
- Do not auto-apply every Copilot/Bugbot suggestion. Validate first.
- Do not mark a thread resolved just to clear the UI - resolution implies the reviewer would agree.
- Do not write a 5-paragraph reply. If you need that much space, switch to Discuss and pull it into a call/issue.
- Do not edit the reviewer's wording when quoting them.
- Do not skip step 3's sweep. It is the single highest-leverage habit in this skill.

## Summary

Fetch → classify → fix-and-sweep → **self-review if installed** → reply humbly → resolve → record the pattern. Treat every comment as a free lesson; treat every reply as something the reviewer will reread tomorrow.
