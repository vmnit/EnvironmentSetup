# Worked example

One real run of the workflow, from a held draft to a filed issue. Included
because every step below changed the outcome — this is what the checklist is
protecting against, in concrete form.

**Starting point:** a draft on disk, `ISSUE-<topic>-false-positives.md`, held for
three days with the recorded disposition *"File later as a standalone issue after
<emulator> or <hardware> is available to reproduce the dispatch path."* It made
two claims: (a) a tool emitted phantom diagnostics at runtime, and (b) its
diagnostic output hid the total number of findings behind a cap of 32.

## 1. Re-test the blocker → it was imaginary

The tracking doc said the emulator was "no longer installed on this host
(searched; no binary, `MIRAGE_BIN` unset)". Both facts were true and the
conclusion was wrong: in this workflow the emulator is **built in-tree**, never
system-installed. The build tree created for the very commit under test carried
its own copy, plus the discovery symlink it needs. It started a session
immediately.

**Lesson:** the search tested for the tool the way one tests for a
system-installed binary, on a workflow where every copy has been built in-tree.
Test the mechanism, not the sentence.

## 2. Re-measure → claim (a) was already fixed

A PR had merged since the draft was written, fixing the underlying analysis. The
draft's central claim was closed. Filing it as live would have asserted to the
fix's author, days after he shipped it, that his fix did not exist.

The re-measurement also produced something better than a retraction: it
**confirmed** an inference an earlier comment had been forced to make. That
comment had argued from a static proxy that the fix must reach the runtime hook
too, and said so honestly. Driving the original reproducer through the hook on a
real dispatch turned the inference into a measurement, with both controls
behaving.

## 3. Verify each claim → claim (b) was wrong in detail, right in substance

The draft said the header printed `diagnostics=32`, read 32 as the cap, and
proposed printing the total alongside it "since the information is already on
hand as `report.diagnostics_truncated`".

Three things were wrong:

- The header printed **36**, not 32, on an object with **511** real findings.
  Neither the cap nor the total — so a reader who knows the cap is 32 cannot even
  recognise the number as capped. *Worse* than the draft claimed.
- `diagnostics_truncated` is a `bool`. The total is never computed, so it is not
  "already on hand" and the proposed fix could not work as written.
- The counter froze because of one term in a gate evaluated **once per
  instruction** rather than once per finding — so the remaining findings of the
  instruction that crossed the cap were still counted. 32 + 4 = 36.

## 4. Harden → this is where the issue became hard to decline

**In-repo precedent.** The same report struct was rendered by three consumers.
The CLI printed `diagnostics=>=36` plus `omitted at least 4`; a sibling hook
printed `at least 36`. Only the third dropped the qualifier. The issue stopped
being "please change your design" and became "one of your three renderers
disagrees with the other two, and the helper it needs already exists in your
tree". It also flipped a component the original draft had named as a second
victim into a counter-example.

**Cheapest reproducer.** The CLI's own `--max-diagnostics` default was also 32,
so the entire counting half reproduced in **two commands with no GPU** — one
printing `>=36`, the same run with a raised cap printing `511`. This became the
single most valuable property of the issue.

**Predict, then observe.** Rather than assert the per-instruction mechanism, the
harness derived it: find the instruction holding the 32nd finding, count how many
findings it carries, predict the header, compare. It printed:

```
static total                 511
store cap (max_diagnostics)  32
instruction straddling cap   .text+0x1f6a8  (6 diagnostics)
predicted header N           36
observed header N            36
-> MATCH
```

**Cost the fix.** On review the user proposed the better fix: let the counter keep
counting while storage stops at the cap. Checking the premise showed it was half
right — the instruction walk *does* complete when truncated (identical
instruction and event counts capped and uncapped), but the detection call sits
inside the gate, so past the cap there is nothing left to count. So the fix costs
something real, measured at **+16%** on the worst object, with an input that never
truncates as the control (identical timings, proving the delta was attributable).

The decisive find was one line *above* the bug: an adjacent counter was
deliberately **not** gated the same way, which is why other statistics stayed
exact past the cap. The repo already drew the distinction being asked for and had
simply not extended it to diagnostics.

## 5. Scope and scrub → two statements went stale

Promoting the counter fix to the primary ask silently invalidated two sentences
written when it was a footnote: the issue still described itself as *"scoped to
reporting"* and as *"a reporting defect, not an analysis defect"*. Neither was
true once the primary fix reached the shared analysis. Both were caught by
re-reading the whole document after the promotion and corrected before posting.

Caveats were stated in the issue rather than omitted: the one-line fix shape came
from reading the code, not a built and tested patch; the cost figure was measured
through an existing CLI cap rather than by applying the change; and the change
would alter visible output for all three consumers.

## 6–8. Duplicate check, file, verify

Identifier searches (`diagnostics_observed`, `max_diagnostics`,
`diagnostics truncated`) returned **zero** hits. The prose search returned four
neighbours, none reporting this output. Filed; body fetched back and diffed
against the payload — identical apart from a trailing newline the tracker
appends.

## 9. Record → and fix what was now known to be wrong

Beyond recording the filed number, the sweep corrected claims the new
measurements had invalidated elsewhere:

- A generated summary asserting a captured `diagnostics=32` was "the documented
  per-object cap hit exactly". It wasn't — it was a lower bound that happened to
  coincide with the cap on those objects.
- A schema note that did not distinguish *printed* from *observed* counts, which
  is exactly the conflation the issue is about.
- A sibling script whose header said the dispatch half was unrunnable, now
  pointing at the script that runs it.
- An append-only changelog entry, corrected by appending a bracketed pointer to
  the newer entry rather than rewriting the original.

## What the checklist caught, in order of value

1. A blocker that did not exist, which had held the item for three days.
2. A central claim that had been fixed upstream since the draft was written.
3. A proposed fix that could not work, because the data it assumed was a boolean.
4. A number reported as 32 that was actually 36, making the defect worse.
5. Two sentences that contradicted the body after the ask was re-prioritised.
6. Four stale claims in surrounding documents and scripts.
