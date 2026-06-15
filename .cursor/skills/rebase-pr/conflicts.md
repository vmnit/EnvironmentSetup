# Rebase conflict resolution (reference)

Use this file when step 6 of `SKILL.md` stops on conflicts. The parent skill owns the overall rebase contract (heads-up comment, parity check, force-with-lease); this file owns **how to resolve markers and continue**.

## Ours vs theirs during rebase (easy to get wrong)

During `git rebase`, conflict marker semantics are **inverted** compared to a normal merge:

| Marker | Meaning during rebase |
|--------|------------------------|
| `<<<<<<< HEAD` | The branch you are rebasing **onto** (e.g. current `main`) |
| `>>>>>>> <commit>` | The commit being **replayed** from the PR branch |

Do not blindly `git checkout --ours` / `--theirs` without checking which side is which. Prefer reading both sides and editing a combined hunk.

Inspect stages without opening the working tree:

```bash
git show :1:<path>   # common ancestor (if available)
git show :2:<path>   # HEAD (onto / base side)
git show :3:<path>   # incoming commit side
```

## Resolution principles

1. **Preserve PR intent** — every semantic change the replayed commit introduced must survive (new parameters, new registry entries, new tests, etc.).
2. **Preserve base structure** — if `main` refactored a file while the PR was open, graft the PR's delta onto the **new** layout; do not revert to the pre-refactor file shape.
3. **Combine, don't pick one side**, when both sides added orthogonal lines (e.g. base added Phase 2 flags; PR added `--mitigations-file` plumbing).
4. **Read the PR branch tip** — `git show origin/<headRefName>:<path>` is the ground truth for what the PR should look like *after* a successful rebase. Your resolved file should match that diff against `origin/<baseRefName>`, not merely "look reasonable."
5. **Frozen trees** — if the repo marks `source/` as upstream-frozen (see project `CLAUDE.md` / `AGENTS.md`), do not resolve conflicts inside those paths without explicit user approval; abort and hand off.
6. **No drive-by fixes** — conflict resolution is history alignment only; do not refactor, reformat, or fix unrelated lint while resolving.

## Per-file workflow

For each path in `git diff --name-only --diff-filter=U`:

```bash
git status -sb
git diff --name-only --diff-filter=U
```

1. Open the file; locate `<<<<<<<` / `=======` / `>>>>>>>`.
2. Read **HEAD** hunk (base) and **incoming** hunk (replayed commit).
3. Read **PR tip** for the same path: `git show origin/<headRefName>:<path>`.
4. Edit to a single coherent result that matches PR tip's *semantic* diff vs new base.
5. `git add <path>` — only after all conflict markers are gone.
6. `git rebase --continue`.

If `git rebase --continue` stops again, repeat. Track resolved files for the post-rebase comment.

## When to abort instead of resolving

Abort (`git rebase --abort`) and post the "aborted, no push happened" PR comment only when:

- Conflicts repeat in the same file across **three or more** replayed commits with no stable combined shape (suggest squash or author intervention).
- Conflict touches frozen `source/` trees without user approval.
- You cannot make the post-rebase tree match the PR tip diff without inventing behavior not present on either side.
- `git cherry` was wrong: conflicts look like replaying already-merged work — re-run step 5 with a different cut-point before manual resolution.

Otherwise **resolve and continue**; do not abort just because conflicts exist.

## Worked example: ROCm/aorta PR #198 (`src/aorta/cli/probe.py`)

**Situation:** PR #198 rebased onto `main`. Phase 2 probe work (#197) landed on `main` and expanded `probe.py`; the PR's first replayed commit (#195 registry) still used the older handler shape and added `sidecar_files=mitigation_files` to `load_recipe`.

**Markers:**

```python
<<<<<<< HEAD
        r = load_recipe(recipe)
        if r.probe_extras is None:
=======
        r = load_recipe(recipe, sidecar_files=mitigation_files or None)
        probe_extras = r.probe_extras
        if probe_extras is None:
>>>>>>> 4c7ee64 (registry: register NaN-debug flag sweep set for aorta probe (#195))
```

**Correct resolution** (base structure + PR intent):

```python
        r = load_recipe(recipe, sidecar_files=mitigation_files or None)
        if r.probe_extras is None:
```

Later commits on the PR branch also add `LookupError` to `except` tuples — when those commits replay, merge those hunks into the **current** Phase 2 handler body rather than restoring the pre-#197 file.

**Verify** after the full rebase:

```bash
git diff origin/main..HEAD --stat    # post-rebase
# Compare to pre-rebase PR diff captured in step 4
diff -u /tmp/rebase-pr-198-pre.diffstat /tmp/rebase-pr-198-post.diffstat
```

## Common conflict shapes

| Shape | What happened | Resolution |
|-------|----------------|------------|
| Additive imports | Both sides added different imports | Union of imports; sort per project style |
| Same function, different bodies | True edit overlap | Merge logic; prefer PR tip for PR-owned behavior |
| File renamed on base | PR edited old path | Apply PR edit to new path; `git add` new path, `git rm` old if needed |
| Recipe/registry both touched | Parallel edits to lists | Keep all PR registry entries; keep base's unrelated edits |
| Delete vs modify | Base deleted, PR modified | Usually keep PR content unless base deletion was intentional removal |

## After all conflicts are resolved

Resume the parent skill at **step 7 (parity check)**. Conflict resolution does not skip parity. If parity fails because squash-absorbed files disappeared from the stat, that is acceptable per step 7; if PR-unique files differ, investigate before pushing.

In the **step 10 confirmation comment**, add a row or bullet listing files where conflicts were resolved manually, e.g. `Conflicts resolved: src/aorta/cli/probe.py`.
