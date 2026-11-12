---
name: file-investigation-issue
description: >-
  Turn an investigation finding or an on-disk issue draft into a filed,
  evidence-hardened tracker issue. Re-tests recorded blockers, re-measures
  against the current code, verifies every claim in the draft against source,
  then hunts for in-repo precedent, the cheapest possible reproducer, a
  predict-then-observe check on the mechanism, and the measured cost of the
  proposed fix. Scrubs the body for public posting, checks for duplicates, files
  it, verifies the post round-trips, and records the outcome in a tracking
  document. Use when the user asks to file an issue from a draft or a finding, to
  unblock or re-check a held or blocked draft, to re-measure a draft before
  filing, or to file a bug discovered during an investigation.
---

# Filing an investigation finding as an issue

The failure mode this prevents: **the evidence ages faster than the draft does.**
A draft written last week can be stale in its numbers, its mechanism, its
proposed fix, and its stated blocker — all while reading as confident and
finished. Verify before filing, not after a maintainer does it for you.

Corollary worth internalising: expect to find claims that are wrong in *detail*
while right in *substance*. Those are the valuable ones. The corrected version is
usually sharper and the fix usually smaller.

## Workflow

Copy this checklist and track progress:

```
- [ ] 1. Re-test the blocker
- [ ] 2. Re-measure against current code
- [ ] 3. Verify each claim against source
- [ ] 4. Harden the evidence
- [ ] 5. Scope and scrub
- [ ] 6. Duplicate check
- [ ] 7. Confirm, then file
- [ ] 8. Verify the post round-trips
- [ ] 9. Record the outcome
```

### 1. Re-test the blocker — never trust a recorded one

If the item is held, blocked, or deferred, re-run the blocker check yourself
before accepting it. A recorded blocker describes a past environment.

Test the **mechanism** of the blocker, not the sentence. The sentence is often
right about the symptom and wrong about the cause.

The most common false blocker is "tool X is not available", concluded from
`which X` or an unset env var, when X is built in-tree, vendored, containerised,
or present in a sibling build directory. Before accepting it, search the build
trees, sibling checkouts, and container images.

If the blocker turns out to be real, say so explicitly and stop — a partially
measured issue is worse than an unfiled one.

### 2. Re-measure against the current code

Establish whether the target has changed since the draft was written. Check for
merged fixes, moved tips, renamed symbols.

Asserting a live defect that was fixed last week — to the person who fixed it —
discredits every other item you file. Conversely, a fix landing between two
measurements is a natural experiment: it can *strengthen* a neighbouring finding
by showing what it did and did not touch.

Pin and cite the exact commit you measured at. Never mix commits silently.

### 3. Verify each claim against source — the draft is a hypothesis

Treat every number, file:line, and mechanism in the draft as unverified.

- Does the source actually say what the draft says it says?
- Does the measurement reproduce now?
- Do the draft's numbers describe the same quantity as each other? Counts of
  *stored*, *printed*, *observed* and *actual* items are routinely conflated.

Pay special attention to **proposed fixes that assume data exists**. A draft
saying "the total is already available as `some_field`" is worth checking — if
that field is a boolean, or is itself derived from the truncated data, the real
fix is a different shape entirely.

### 4. Harden the evidence

Four moves, in rough order of payoff.

**In-repo precedent.** Do other callers or consumers of the same code get this
right? Grep for sibling implementations, other renderers of the same struct,
other callers of the same helper. If one of them does it correctly, the issue
stops being a design proposal and becomes an inconsistency with a precedent that
already exists in the same repository — dramatically harder to decline, and it
tells the maintainer exactly what the patch looks like.

**Cheapest reproducer.** Drive the reproduction cost down as far as it will go:
no special hardware beats hardware, no container beats a container, two commands
beat a script. Maintainers act on what they can verify in a minute. Look for an
existing flag, default, or CLI surface that exposes the same behaviour without
the full stack — the cheap path often already exists.

**Predict, then observe.** Turn a mechanism claim from asserted into
machine-checked: compute what your explanation predicts, compare against the
observation, and have the harness print `MATCH` / `MISMATCH` itself. "The number
is odd" becomes "the number is this mechanism, and here is the arithmetic."

**Cost the fix you propose.** If the fix removes an early-out or adds work,
measure it. Include a control that isolates the change from noise — ideally an
input that does not exercise the changed path at all, so identical timings prove
the delta is attributable. Report the measurement as an upper or lower bound
where it is one, and say which.

### 5. Scope and scrub

- **One defect per issue.** Closed or fixed neighbouring findings go in a
  clearly-labelled "what this issue is not" section, or get cut.
- **State what is not claimed.** Name the adjacent classes you are not making
  claims about, and cite their issues.
- **Put caveats in the issue, not in your head.** Untested patches, proxy
  measurements, mechanisms inferred from docs rather than source, single-sample
  timings — all stated plainly. Reviewers trust a report that volunteers its own
  limits.
- **Scrub for public posting.** No local absolute paths, no hostnames, no user
  names, no internal tree or branch names that leak org structure, no customer
  identifiers, no environment dumps. Grep the exact payload, not the draft.
- **After promoting or demoting an ask, re-read the whole document — including
  the title.** Summary paragraphs and "distinctness"/"scope" sections go stale
  first and will directly contradict the body. The **title and any component
  tag** are part of the document: re-prioritising an ask can move the defect
  into a different component, and a stale tag misroutes the issue to the wrong
  owner. Derive the tag from where the *primary* fix lands, not from where the
  symptom was observed or which investigation found it.
- **Markdown gotcha.** A table whose first row is content (`| Branch | x |`)
  followed by `|---|---|` renders that content row as the header. Use an empty
  header row (`| | |`) for label/value tables.

### 6. Duplicate check

Search the tracker for the **mechanism's identifiers** — symbol names, flag
names, error strings, constants — not just the prose topic. Topic searches
return neighbours; identifier searches return duplicates.

Record what you searched and what came back, so the next person need not redo it.

### 7. Confirm, then file

**Stop here and get explicit go-ahead** unless the user has already approved this
specific draft. A public post is hard to undo.

Before building the payload, verify the posting path actually works: authentication,
repository access, issue permissions. Some organisations reject particular token
types, so confirm rather than discover it at post time.

**Verify you can *update*, not just create.** These are separate permissions and
can differ for the same account and the same repository. If you can file but not
edit, a later correction — a wrong title, a stale tag — becomes unfixable, and
re-filing does not rescue you because closing the original is also an update.

If an update returns an authorization error, do not accept it before checking
for a **shadowed credential**: an environment token such as `GH_TOKEN` overrides
the CLI's stored login, and the two can have different capabilities even for the
same account and the same token type. Try each stored credential explicitly
(`env -u GH_TOKEN gh auth switch --user <account>`) before concluding the
operation is blocked by policy. A create that succeeds followed by an update
that 403s is the signature of this, not of a hard block.

Match the project's conventions by looking at its recent issues: title style
(prefix tags, backticks or not), whether labels are used, whether a template
exists.

The draft's H1 becomes the issue title — **strip it from the body** so it does
not appear twice.

### 8. Verify the post round-trips

Fetch the posted body back and diff it against the payload you sent. Confirm the
key figures survived. A trailing-newline difference is normal; anything else is
a truncation or escaping problem worth fixing immediately.

### 9. Record the outcome

Maintain a tracking document, and **create one if none exists**. Record per item:

```markdown
| Order | ID | Type | Status | Filed as |
| ---: | --- | --- | --- | --- |
| 1 | <ID> | new issue | `filed` | [#NNN](url) |
```

Status vocabulary: `ready` · `blocked` · `needs-decision` · `hold-not-filing` ·
`filed`

Per item, capture: the draft path, the reproducer path, the commit measured at,
what the re-verification **confirmed** versus **contradicted**, the
duplicate-search result, and the filed number. Add a dated changelog entry.

Then **correct the stale claims you found along the way**, wherever they live —
generated summaries, reports, sibling scripts, READMEs. For append-only logs,
append a bracketed correction pointing at the newer entry rather than rewriting
history.

Also fix any script whose output would now mislead: a harness that prints zeros
for a measurement it could not take is a false negative waiting to happen. It
should state the missing column in its own output, or refuse to print a number.

## Additional resources

- For a full worked example of this workflow, including the specific mistakes it
  caught, see [examples.md](examples.md).
