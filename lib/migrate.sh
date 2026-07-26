#!/usr/bin/env bash
# One-time migration of legacy overlay names in $HOME to the current scheme.
#
# Usage: migrate.sh [--dry-run]
#
# The overlay convention was renamed:
#   <base>.local       -> <base>.private     (private repo, applies on every host)
#   <base>.local.host   -> <base>.$HOSTNAME  (host-specific, tracked per host)
#
# install.sh only ever *writes* paths that exist in a repo's home/ tree; it has
# no notion of a file it used to own. So a rename leaves the old file orphaned
# in $HOME, and — worse — the shared .bashrc/.bash_aliases/.vimrc no longer
# source it, silently dropping whatever config it held. This script closes that
# gap.
#
# It decides what to do by CONTENT, never by name alone, and never destroys
# unique config: a legacy file whose new-scheme counterpart exists with
# different content is backed up and LEFT IN PLACE with a warning, for a manual
# merge. Empty files, exact duplicates, and clean renames are handled silently.
#
# Idempotent and safe to run on every bootstrap: with nothing to migrate it
# prints nothing and exits 0.
#
# Backup location: $DOTFILES_BACKUP if set (so a caller can share one dir across
# passes), otherwise ~/.dotfiles-backup/<UTC timestamp>.
set -euo pipefail

DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1; shift ;;
        -h|--help)    sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "migrate: unknown option: $1" >&2; exit 2 ;;
    esac
done

BACKUP_DIR=${DOTFILES_BACKUP:-"$HOME/.dotfiles-backup/$(date -u +%Y%m%dT%H%M%SZ)"}

# Use the short hostname: install.sh names host overlays after `hostname -s`,
# so an FQDN here would look for a file that never gets installed.
HOST_S=$(hostname -s 2>/dev/null || hostname)

# Overlay families to migrate. ssh is deliberately absent from the .local.host
# tier below: ssh's Include cannot expand $HOSTNAME, so there is no per-host
# ssh overlay to migrate a .local.host file into (see MIGRATE_ORPHANS).
MIGRATE_STEMS=${MIGRATE_STEMS:-".bashrc .bash_aliases .bash_funcs .vimrc .tmux.conf"}

migrated=0 removed=0 warned=0

note()  { echo "migrate $*"; }
warn()  { echo "WARN    $*" >&2; }
# Count a file as needing manual attention (once, however many warn lines it took).
flag()  { warned=$((warned + 1)); }

# back_up REL — copy $HOME/REL into the backup dir, preserving structure.
back_up() {
    local rel="$1"
    [ "$DRY_RUN" -eq 1 ] && return 0
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -p "$HOME/$rel" "$BACKUP_DIR/$rel"
}

# handle LEGACY_REL NEW_REL
#   Migrate $HOME/LEGACY_REL to $HOME/NEW_REL, choosing by content:
#     empty                    -> back up, remove
#     identical to NEW         -> back up, remove
#     only comments differ     -> back up, remove
#     NEW absent               -> back up, rename (content rescued)
#     NEW exists, code differs -> change nothing, warn for a manual merge
handle() {
    local legacy="$1" new="$2"
    local lpath="$HOME/$legacy" npath="$HOME/$new"

    [ -e "$lpath" ] || return 0

    if [ ! -s "$lpath" ]; then
        back_up "$legacy"
        [ "$DRY_RUN" -eq 0 ] && rm -f "$lpath"
        note "remove  $legacy (empty)"
        removed=$((removed + 1))
        return 0
    fi

    if [ -e "$npath" ] && cmp -s "$lpath" "$npath"; then
        back_up "$legacy"
        [ "$DRY_RUN" -eq 0 ] && rm -f "$lpath"
        note "remove  $legacy (identical to $new)"
        removed=$((removed + 1))
        return 0
    fi

    # The rename commits rewrote the header comments in these files (they named
    # the old tier), so byte-comparison alone would flag a pure duplicate as a
    # conflict. If every non-comment, non-blank line matches, the *config* is
    # identical and the legacy file carries nothing worth merging. `#` covers
    # shell/ssh, `"` covers vimrc. Require a non-empty result: two files that are
    # nothing but comments should fall through to the conservative branch rather
    # than compare equal on two empty streams.
    if [ -e "$npath" ]; then
        local lcode ncode
        lcode=$(grep -vE '^[[:space:]]*(#|")|^[[:space:]]*$' "$lpath" || true)
        ncode=$(grep -vE '^[[:space:]]*(#|")|^[[:space:]]*$' "$npath" || true)
        if [ -n "$lcode" ] && [ "$lcode" = "$ncode" ]; then
            back_up "$legacy"
            [ "$DRY_RUN" -eq 0 ] && rm -f "$lpath"
            note "remove  $legacy (only comments differ from $new)"
            removed=$((removed + 1))
            return 0
        fi
    fi

    if [ ! -e "$npath" ]; then
        back_up "$legacy"
        if [ "$DRY_RUN" -eq 0 ]; then
            mkdir -p "$(dirname "$npath")"
            mv "$lpath" "$npath"
        fi
        note "rename  $legacy -> $new"
        migrated=$((migrated + 1))
        return 0
    fi

    # Both exist and differ — the only case where we could lose config, so we
    # change nothing and hand it to the user. Nothing is backed up here on
    # purpose: both files are still in place, and this branch repeats on every
    # run until it's resolved, which would spawn a backup dir each time.
    flag
    warn "$legacy and $new both exist and differ."
    warn "        Merge $legacy into $new by hand, then delete $legacy."
    warn "        Nothing was changed; both files are untouched in \$HOME."
}

# --- Shell/vim overlay families -------------------------------------------
for stem in $MIGRATE_STEMS; do
    handle "$stem.local"      "$stem.private"
    handle "$stem.local.host" "$stem.$HOST_S"
done

# --- ssh ------------------------------------------------------------------
# config.local was a pure rename to config.private (no content change).
handle ".ssh/config.local" ".ssh/config.private"

# config.local.host has no counterpart under the new scheme: ssh's Include
# cannot expand $HOSTNAME, so per-host ssh settings must be folded into
# config.private by hand. Back it up and say so rather than guessing.
if [ -e "$HOME/.ssh/config.local.host" ]; then
    if [ -s "$HOME/.ssh/config.local.host" ]; then
        # Left in place (and not backed up) for the same reason as the conflict
        # branch above: it recurs every run until the user merges it.
        flag
        warn ".ssh/config.local.host is no longer sourced (ssh Include cannot"
        warn "        expand \$HOSTNAME). Merge it into ~/.ssh/config.private by"
        warn "        hand, then delete it. It is untouched in \$HOME."
    else
        back_up ".ssh/config.local.host"
        [ "$DRY_RUN" -eq 0 ] && rm -f "$HOME/.ssh/config.local.host"
        note "remove  .ssh/config.local.host (empty)"
        removed=$((removed + 1))
    fi
fi

# --- Summary --------------------------------------------------------------
if [ $((migrated + removed + warned)) -eq 0 ]; then
    exit 0   # nothing legacy on this machine; stay quiet
fi

echo "----"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — nothing was changed)"
echo "legacy overlays: $migrated renamed, $removed removed, $warned needing a manual merge"
# Only advertise the backup dir if this run actually put something in it.
[ "$DRY_RUN" -eq 0 ] && [ $((migrated + removed)) -gt 0 ] && [ -d "$BACKUP_DIR" ] \
    && echo "backups in $BACKUP_DIR"
exit 0
