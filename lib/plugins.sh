#!/usr/bin/env bash
# Provision tmux's plugin manager (tpm) and the plugins declared in ~/.tmux.conf.
#
# ~/.tmux.conf ends with `run '~/.tmux/plugins/tpm/tpm'` and lists plugins via
# `set -g @plugin '...'`. Those plugins live under ~/.tmux/plugins/, which are
# external git repos — the file-copy installer (install.sh) can only mirror
# tracked files, so it can neither clone tpm nor pull the plugins. Without this
# step a fresh machine gets a .tmux.conf whose final `run` line points at a
# missing tpm and every `@plugin` silently does nothing.
#
# This clones tpm if absent (or fast-forwards it if present), then installs any
# declared plugins that are missing — no interactive `prefix + I` needed.
#
# Idempotent and safe to run on every install. It never fails the caller: if
# git or tmux is missing, or the network is down, it warns and exits 0 so a
# bootstrap that is otherwise fine is not aborted by a plugin hiccup.
set -uo pipefail

TMUX_CONF="${TMUX_CONF:-$HOME/.tmux.conf}"
PLUGIN_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
TPM_DIR="$PLUGIN_DIR/tpm"
TPM_URL="${TPM_URL:-https://github.com/tmux-plugins/tpm}"

warn() { echo "plugins: $*" >&2; }

# tpm is a git repo and only useful alongside tmux, so both are prerequisites.
if ! command -v git >/dev/null 2>&1; then
    warn "git not found — skipping tmux plugin setup."
    exit 0
fi
if ! command -v tmux >/dev/null 2>&1; then
    warn "tmux not found — skipping tmux plugin setup."
    exit 0
fi
if [ ! -f "$TMUX_CONF" ]; then
    # Nothing declares plugins yet (install.sh runs before this on a fresh box
    # only if ordered so); without a conf there is nothing to provision.
    warn "no $TMUX_CONF — skipping tmux plugin setup."
    exit 0
fi

# --- 1) tpm itself --------------------------------------------------------
if [ -d "$TPM_DIR/.git" ]; then
    echo "plugins: updating tpm in $TPM_DIR"
    git -C "$TPM_DIR" pull --ff-only --quiet \
        || warn "could not fast-forward tpm (continuing with the existing copy)."
else
    echo "plugins: cloning tpm -> $TPM_DIR"
    if ! git clone --depth 1 --quiet "$TPM_URL" "$TPM_DIR"; then
        warn "clone failed (offline?). tmux plugins not installed — re-run this later."
        exit 0
    fi
fi

# --- 2) the plugins tpm manages ------------------------------------------
# tpm reads the @plugin options from a running tmux server, so drive it under a
# throwaway detached session when we're not already inside tmux. bin/install_plugins
# clones anything missing and is a no-op once everything is present.
installer="$TPM_DIR/bin/install_plugins"
if [ ! -x "$installer" ]; then
    warn "tpm has no bin/install_plugins — clone may be incomplete."
    exit 0
fi

# TMUX_PLUGIN_MANAGER_PATH lets tpm honor a non-default plugin dir; export it so
# the installer and tpm agree on where plugins live. Trailing slash is what tpm
# itself uses internally.
export TMUX_PLUGIN_MANAGER_PATH="$PLUGIN_DIR/"

echo "plugins: installing/updating tmux plugins from $TMUX_CONF"
if [ -n "${TMUX:-}" ]; then
    # Already inside tmux: the current server has (or can) load the conf.
    "$installer" >/dev/null 2>&1 || warn "plugin install reported an error (continuing)."
else
    # Headless: start a detached server that has sourced the conf so tpm can see
    # the @plugin options, run the installer, then tear the session down.
    session="tpm-provision-$$"
    tmux new-session -d -s "$session" -x 200 -y 50 2>/dev/null || {
        warn "could not start a tmux session to install plugins — run 'tmux' then prefix + I."
        exit 0
    }
    tmux source-file "$TMUX_CONF" 2>/dev/null || true
    "$installer" >/dev/null 2>&1 || warn "plugin install reported an error (continuing)."
    tmux kill-session -t "$session" 2>/dev/null || true
fi

# Report what actually landed so the run is verifiable at a glance.
installed=$(find "$PLUGIN_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | sed 's#.*/#  - #')
echo "plugins: tmux plugins present under $PLUGIN_DIR:"
[ -n "$installed" ] && echo "$installed" || echo "  (none)"
exit 0
