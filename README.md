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
- `home/.config/gh/per-repo.sh` — `gh` wrapper that pins the API token per repo.

Cursor MCP servers (Atlassian/GitHub) carry live tokens and are provided per
machine by the private overlay; nothing secret is tracked here.

### GitHub CLI per-repo account

`home/.config/gh/per-repo.sh` wraps `gh` so each checkout can pin which
*already-logged-in* account to use, without `gh auth switch` (which is global
and races across shells). Selection order:

1. `git config gh.account <user>` in the current repo
2. a `.gh-account` file (walk from CWD up) for non-git directories
3. the globally active `gh` account

`.bash_funcs` sources the wrapper in interactive shells. Cursor skills that
call `gh` source the same file first, because agent shells skip `~/.bashrc`.
Which GitHub usernames to pin is machine/org-specific and lives in the private
overlay (`gh-account` helper).

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

`install.sh` also provisions tmux automatically (via `lib/plugins.sh`): it clones
tmux's plugin manager (tpm) into `~/.tmux/plugins/tpm` and installs the plugins
declared in `~/.tmux.conf` (`tmux-resurrect`, `tmux-continuum`,
`vim-tmux-navigator`) — no manual `git clone` or `prefix + I` needed. It's
idempotent (re-runs just fast-forward) and non-fatal: if `git`/`tmux` is missing
or you're offline it warns and skips, so the rest of the install still succeeds.
Run it on its own any time with:

```sh
bash lib/plugins.sh
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

The `$HOSTNAME` in an overlay name is always the **short** hostname (`hostname -s`);
the rc files strip any domain before looking the file up, so an FQDN `$HOSTNAME`
still finds `~/.bashrc.<short>`.

### Migrating from the old `.local` names

An earlier scheme used `<base>.local` (all hosts) and `<base>.local.host`
(untracked, per-machine). `install.sh` only ever *writes* paths present in a
repo's `home/` tree — it never removes a file it used to own — so after the
rename those files stayed in `$HOME` while the rc files stopped sourcing them,
silently dropping whatever config they held.

`lib/migrate.sh` fixes that, and `bootstrap.sh` runs it automatically before
installing. It decides by **content**, never by name:

```sh
bash lib/migrate.sh --dry-run   # show what would change, touch nothing
bash lib/migrate.sh             # migrate (backs everything up first)
```

| situation | action |
|---|---|
| legacy file is empty | back up, remove |
| identical to its new-scheme counterpart (or differs only in comments) | back up, remove |
| counterpart absent | back up, **rename** — content is rescued |
| counterpart exists and differs | back up both, **keep** the legacy file, warn for a manual merge |

It never deletes unique config, and is a silent no-op once a machine is migrated.
Note the old untracked `.local.host` tier is gone: per-machine config is now
tracked as `.$HOSTNAME` in the private repo.

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
