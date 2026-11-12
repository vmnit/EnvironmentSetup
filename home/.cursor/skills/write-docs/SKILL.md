---
name: write-docs
description: >-
  Write or revise technical documents in plain English: design notes, runbooks,
  READMEs, and explanations of how something works. Use when the user asks to
  write, rewrite, or edit documentation, a doc, a runbook, a README section, or
  an explanation meant to be read later.
---

# Write docs

Write so a reader can learn the main idea from the first sentences, then do the task or check the fact without rereading a sentence to unpack it.

Use the real technical names: instruction names, file paths, flags, register names, error strings. On first use, add the plain meaning when the reader may not know the term. After that, use the term.

## Language

1. Put the main idea in the first sentence of the document and of each section.
2. Use ordinary words. One idea per sentence. Say what is true, then the consequence.
3. Prefer a short sentence to a clause stacked on a clause.
4. Cut a sentence that repeats the one before it.
5. Keep commands, paths, names, and numbers exact. Copy them from the source that works.
6. Define a term once, in the sentence where it first matters. Skip the definition when the surrounding doc already gave it.

Straighten a sentence before leaving it:

| Twisted | Straight |
|---|---|
| It is worth noting that the wait does not, in and of itself, recover a wedged device. | The wait stops the process. It does not recover a wedged GPU. |
| Utilization of the conformance path is mandatory in order to avoid the generation of hang-class kernels. | Use conformance mode. It refuses hang-class kernels. |
| The launcher, which is responsible for dispatch, checks the architecture. | The launcher checks the architecture before dispatch. |

Drop filler that adds no fact: "it is worth noting", "in order to", "the fact that", "basically", "simply", "delve", "leverage", "robust". Drop a contrast that only says what you are not doing. Say the thing you are doing.

## Before writing

Name three things, to yourself, in one line each:

- **Reader.** Who reads this, and what they already know.
- **Job.** What they can do, or what they understand, after reading.
- **Kind.** Procedure, explanation, or reference. Use one kind as the spine. A procedure can contain a short explanation. An explanation can contain one command.

Read the existing doc and the surrounding docs first. Match their headings and words when they are already clear. Replace a twisted paragraph. Leave a clear paragraph alone.

## What each kind contains

**Procedure** (runbook, how-to):

1. What this run produces, in one or two sentences.
2. What must already be true (machine, toolchain, file, permission), only the items the reader cannot guess.
3. The steps in the order to run them. One action per step. The command, then the result that means it worked.
4. Where the output goes.
5. The failure the reader is likely to hit: the symptom, the cause, the next action. Stop after the likely ones.

**Explanation** (how something works, a design note):

1. What the thing is for.
2. The path a request, a case, or a datum takes, in order.
3. The choice that would surprise a reader, and the reason, in the same paragraph.
4. The limit: the case this design does not cover, stated as the case and the result.

**Reference** (README section, config, API note):

1. One sentence on what the item is.
2. The fields, flags, or files, each with what it changes.
3. One valid example.
4. The value the reader must not invent, called out next to that field.

## Shape

- Title says the subject in the reader's words.
- Open with the result or the purpose. Background follows only when a step is unclear without it.
- Headings are short and say the contents ("Calibrate on one GPU"), not a label ("Overview", "Miscellaneous").
- Use a list when the items are parallel or sequential. Use prose when the point has a reason attached.
- A command block contains the command the reader runs, with the working directory if it matters. Leave out narrative inside the block.

## Accuracy

- A command in the doc is a command that has been run, or one taken from the interface you just read. If you have not checked it, say so next to it.
- Describe current behavior. When the code and an old sentence disagree, the code wins, and the doc changes.
- State a limit as a fact the reader needs. "Calibration decides which opcodes the reference may claim." Skip a limit that only advertises caution.

## After drafting

Read the doc once as the reader. Check:

- The first paragraph states the job.
- Each step has an action and a visible result.
- Each technical term is either ordinary in this repo or explained once.
- No sentence needs to be parsed twice.
- A claim about behavior matches the code or the run you checked.
