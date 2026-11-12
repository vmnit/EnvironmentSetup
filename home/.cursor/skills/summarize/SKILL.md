---
name: summarize
description: >-
  Summarize a document, transcript, diff, log, run, or discussion in plain
  English. Use when the user asks for a summary, a recap, the main idea, or a
  short account of a long source.
---

# Summarize

The summary states the result first, in plain English, then the few facts a reader needs to trust it. A reader who stops after the first paragraph still has the main idea.

Use the technical terms the source uses. If the summary is the first time the reader sees a term, give the plain meaning once.

## Language

1. The first sentence is the outcome, the decision, or the point of the source.
2. One idea per sentence. Say what happened, what it means, and what is still open, in that order, when all three exist.
3. Use the source's names for people, files, commands, and machines. Use a handle when you do not have a name.
4. Keep numbers that change the meaning. Drop numbers that only show the path you took.
5. Mark a guess as a guess. Leave out a claim the source does not support.

| Twisted | Straight |
|---|---|
| The effort ultimately failed to surface any novel hardware defects, it being the case that calibration was green. | Calibration matched the reference. The round found no confirmed hardware defect. |
| There were a number of anomalies which may or may not be attributable to the read path. | Three cases disagreed with the drained twin. In each, `v_readfirstlane_b32` followed the VALU write immediately. |

Drop the tour of your own work: "first I opened", "then I looked", "it is interesting to note". The reader wants the subject, not the reading order.

## What to include

Include an item only when losing it would mislead the reader:

- The result.
- The decision, and the reason, when the source records one.
- The evidence: the command, the file, the count, the error string.
- An open question the source does not settle.
- A risk that follows from the result (a hang left a marker, a number is unchecked).

Skip acknowledgements, repeated attempts that ended in the same result, and options nobody chose. If a failed attempt changes what the result means, state the attempt and the result in one sentence.

## Shape by source

**Document or design note.** The claim, then the argument in the doc's own order. Name the section when a detail matters and the doc is long.

**Transcript or discussion.** The ask, then what was decided, then what remains undone. Attribute a contested point to the person who made it.

**Diff or code change.** What changed for a caller or a machine, then the files only when the reader will go there. Group by behavior, not by file, when one behavior touches several files.

**Run, log, or test output.** What was run, on which target, and the verdict. Then the failing or surprising lines, quoted short. Then what that verdict does and does not establish.

**Several sources.** One combined account. When two sources disagree, say both and which one you are using.

## Length

Match the source, then stop.

- A page or a short log: one paragraph.
- A design note or a meeting: a short lead plus a few bullets.
- A long transcript or a large diff: a lead paragraph plus one section per topic. Each section opens with its point.

A bullet holds one fact. A bullet that needs a semicolon is a paragraph.

## Accuracy

- Separate what the source shows from what it implies. "The twin matched the reference" is an observation. "The chip is correct" is a conclusion and needs the contract that makes it one.
- Quote a sentence when the wording is the evidence. Paraphrase everything else.
- If you only read part of the source, say which part and that the rest is unread.
- Do not promote a hypothesis to a finding because it fits.

## After drafting

Cover the source and read the summary. Check:

- The first sentence is the result.
- A person who was in the work would accept each sentence.
- No sentence only says what something is not.
- The open questions are still open on the page.
