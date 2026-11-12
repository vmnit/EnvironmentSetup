---
name: write-code-comments
description: >-
  Write or revise code comments and docstrings in plain English. Use when the
  user asks for comments, docstrings, or to explain code in the source, or when
  a change needs a comment for a constraint the code does not show.
---

# Write code comments

A comment says the fact the code cannot show. The code stays responsible for what it does.

Use the same plain English as other writing for this user. Technical terms are the names already in the code: the function, the flag, the instruction, the field. Use those names. Add a short plain meaning only when the comment is the first place a reader meets the term.

## Language

1. One or two sentences. A comment that needs a paragraph is usually missing a name in the code, or it belongs in a doc.
2. Say what is true and why it is true.
3. Use the words the code uses. If the function is `lease`, the comment says `lease`, not "the locking subsystem".
4. Write it so it can sit unchanged next to the line it describes.

| Twisted | Straight |
|---|---|
| This is not a reset; rather, we simply kill the group in order to attempt recovery. | Kill the process group on timeout. The GPU stays wedged until an operator recovers it. |
| HACK: workaround for weird hardware behavior. | `v_readfirstlane_b32` reads the old VGPR when it is the next instruction after the write. `s_nop 0` between them reads the new value. |
| TODO: maybe fix this later. | The 32-thread launch matches the 32-lane reference. A 64-thread launch aliases lane 32 onto the next output slot. |

Drop tag noise that carries no fact: `HACK`, `XXX`, `temporary`, "for now", "just". Keep `TODO` only when it names the missing work and the reason it is safe to ship without it.

## When to write one

Write a comment when a competent reader would make the wrong change without it:

- A constraint from outside the code: hardware behavior, a file format, a protocol, a timeout that does not undo the side effect.
- A value that looks arbitrary and is not: a mask, an alignment, a lane count, a wait count.
- An order that has to stay: this write before that fence, this check before that launch.

Leave the line uncommented when it already says what it does. A comment that repeats the next line is noise.

```cpp
// Bad: repeats the code
// Check that the architecture matches.
if (arch != expected) return error;

// Good: the reason is not in the condition
// One binary serves gfx950 and gfx1250. The caller passes the arch it selected.
if (arch != expected) return error;
```

## Where it goes

- **Function, method, or class.** One or two sentences: what it is for, and the condition the caller must meet. Put parameters and return details in the project's docstring form when the project has one. Otherwise name them in the sentence only when the type does not say it.
- **Block.** Directly above the lines, and only for those lines. Say the constraint, then stop.
- **File.** Only when the file's job is not obvious from its name and its first function. One sentence.

Match the comment style already in the file (line comment, block comment, docstring). A new style in one function makes the file harder to read.

## What to leave out

- A restatement of the control flow.
- A changelog ("added for MI350", "changed in review") unless the history is the constraint.
- A comment that will rot when the next edit renames a variable. Tie it to the stable fact, and use the identifier so a rename shows up in the diff.
- A joke, a metaphor, or a private abbreviation.

## When you change the code

Update the comment in the same edit. If the constraint is gone, delete the comment. A stale comment is worse than none, because the next reader trusts it.

## After drafting

Read the comment with the code covered. If you cannot tell what to avoid breaking, it is too vague. Then read the code with the comment covered. If you lose nothing, delete the comment.
