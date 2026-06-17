#!/usr/bin/env bash
# Install a dotfiles tree into $HOME.
#
# Usage: install.sh [SRC]
#   SRC  a "home/" directory whose contents mirror $HOME.
#        Defaults to the home/ dir next to this script's repo root.
#
# For every regular file under SRC, the matching $HOME/<relpath> is written.
# Existing files that differ are first copied (with structure) into a backup
# dir before being overwritten. Identical files are skipped. Files that exist
# only in $HOME (e.g. *.local.host) are never touched, because this script only
# writes paths that exist inside SRC.
#
# Backup location: $DOTFILES_BACKUP if set (lets a caller share one dir across
# multiple passes), otherwise ~/.dotfiles-backup/<UTC timestamp>.
set -euo pipefail

SRC=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/home"}
SRC=$(cd "$SRC" && pwd)

if [ ! -d "$SRC" ]; then
    echo "install: source dir not found: $SRC" >&2
    exit 1
fi

BACKUP_DIR=${DOTFILES_BACKUP:-"$HOME/.dotfiles-backup/$(date -u +%Y%m%dT%H%M%SZ)"}

copied=0 skipped=0 backed_up=0
while IFS= read -r -d '' file; do
    rel=${file#"$SRC"/}
    target=$HOME/$rel

    if [ -e "$target" ] && cmp -s "$file" "$target"; then
        skipped=$((skipped + 1))
        continue
    fi

    if [ -e "$target" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -p "$target" "$BACKUP_DIR/$rel"
        backed_up=$((backed_up + 1))
        echo "backup  $rel -> $BACKUP_DIR/$rel"
    fi

    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"

    # Harden perms git can't track: ssh refuses group/world-writable configs,
    # and the API key file should not be readable by others.
    case "$rel" in
        .ssh/*)                      chmod 600 "$target"; chmod 700 "$HOME/.ssh" ;;
        .config/claude-code/env.sh)  chmod 600 "$target" ;;
    esac

    copied=$((copied + 1))
    echo "install $rel"
done < <(find "$SRC" -type f -print0)

echo "----"
echo "from $SRC: $copied written, $skipped identical, $backed_up backed up"
[ "$backed_up" -gt 0 ] && echo "backups in $BACKUP_DIR"
exit 0
