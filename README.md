# EnvironmentSetup

Generic, public dotfiles and editor/agent config. Everything under [`home/`](home/)
mirrors `$HOME`; the install scripts copy that tree into your home directory.

AMD-internal / secret content (API keys, corporate CA, ROCm helpers) is **not**
here — it lives in a separate private repo that overlays on top of this one.

## Layout

```
home/      mirrors $HOME (only generic content)
lib/       install / update / diff scripts
```

### Claude Code & Cursor config

Generic AI/editor config ships here (secret-bearing or AMD-internal config lives
in the private overlay instead):

- `home/.claude/agents/` — Claude Code subagents (rubric planner/evaluator/implementer).
- `home/.cursor/skills/` — generic Cursor skills: `review-pr`, `rebase-pr`,
  `address-pr-review-comments`, `batch-address-pr-reviews`,
  `loop-address-pr-comments`.

Cursor MCP servers (Atlassian/GitHub) carry live tokens and are provided per
machine by the private overlay; nothing secret is tracked here.

## Install

```sh
bash lib/install.sh            # copies home/ into $HOME
```

- Existing files that differ are backed up to `~/.dotfiles-backup/<timestamp>/`
  (structure preserved) before being overwritten.
- Identical files are skipped; re-running is idempotent.
- Files that exist only in `$HOME` are never touched.
- Host-specific overlays (`<base>.$HOSTNAME`) are installed **only on the matching
  host**; other hosts' overlays are skipped (see `lib/hostfilter.sh`). The same
  filter applies to `update.sh`/`diff.sh`, so they ignore other hosts' files too.

After installing, you'll also want tmux's plugin manager:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm   # then: tmux + prefix-I
```

## Machine-specific & private overlays

Shared shell/ssh files end by sourcing optional overlays, both managed by the
**private** dotfiles repo, so you never edit a shared (all-host) file for
machine-specific tweaks:

| File | sources |
| --- | --- |
| `.bashrc` | `~/.bashrc.private`, `~/.bashrc.$HOSTNAME` |
| `.bash_aliases` | `~/.bash_aliases.private`, `~/.bash_aliases.$HOSTNAME` |
| `.bash_funcs` | `~/.bash_funcs.private`, `~/.bash_funcs.$HOSTNAME` |
| `.vimrc` | `~/.vimrc.private`, `~/.vimrc.$HOSTNAME` |
| `.ssh/config` | `Include ~/.ssh/config.private` |

- `*.private` — applies on **every** host (do not hand-edit).
- `*.$HOSTNAME` — **host-specific**. The installer copies in only the file matching
  this machine's `$HOSTNAME` (e.g. `~/.bash_aliases.xsjvivekag50x`) and skips other
  hosts' files, so the private repo can track per-machine settings for many hosts
  without them conflicting. Put machine-specific tweaks here.

(`.ssh/config` has no `$HOSTNAME` variant — ssh's `Include` can't expand it, so
per-host ssh tweaks go in `~/.ssh/config.private`.)

## Sync changes back

```sh
bash lib/update.sh             # copy tracked files from $HOME back into home/
bash lib/diff.sh               # show what differs between home/ and $HOME
bash lib/status.sh [PRIVATE]   # diff this repo AND an overlay (e.g. private repo)
```

`status.sh` diffs the public `home/` plus any overlay tree you pass (a repo root
or its `home/` dir), or `$DOTFILES_PRIVATE` if set — handy for checking both
layers before an install so machine-specific edits aren't lost. Files that exist
only in `$HOME` (not tracked in any repo) are never listed, so they can't be
clobbered.

## Provisioning a full machine (with private overlay)

The private repo carries a `bootstrap.sh` that pulls this repo and itself, then
installs both layers (generic first, AMD overlay second). On a new machine you
clone the private repo and run its bootstrap; this public repo has no knowledge
of anything private.
