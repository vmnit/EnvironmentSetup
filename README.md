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

## Install

```sh
bash lib/install.sh            # copies home/ into $HOME
```

- Existing files that differ are backed up to `~/.dotfiles-backup/<timestamp>/`
  (structure preserved) before being overwritten.
- Identical files are skipped; re-running is idempotent.
- Files that exist only in `$HOME` are never touched.

After installing, you'll also want tmux's plugin manager:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm   # then: tmux + prefix-I
```

## Machine-specific & private overlays

Shared shell/ssh files end by sourcing optional overlays, so you never have to
edit a tracked file for per-machine tweaks:

| File | sources |
| --- | --- |
| `.bashrc` | `~/.bashrc.local`, `~/.bashrc.local.host` |
| `.bash_aliases` | `~/.bash_aliases.local`, `~/.bash_aliases.local.host` |
| `.bash_funcs` | `~/.bash_funcs.local`, `~/.bash_funcs.local.host` |
| `.ssh/config` | `Include ~/.ssh/config.local`, `~/.ssh/config.local.host` |

- `*.local` — managed by the **private** dotfiles repo (do not hand-edit).
- `*.local.host` — **per-machine**, never committed to any repo and never written
  by any installer, so they survive every install. Put host-specific tweaks here.

## Sync changes back

```sh
bash lib/update.sh             # copy tracked files from $HOME back into home/
bash lib/diff.sh               # show what differs between home/ and $HOME
```

## Provisioning a full machine (with private overlay)

The private repo carries a `bootstrap.sh` that pulls this repo and itself, then
installs both layers (generic first, AMD overlay second). On a new machine you
clone the private repo and run its bootstrap; this public repo has no knowledge
of anything private.
