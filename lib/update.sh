#!/usr/bin/env bash
# Pull tracked dotfiles from $HOME back into the repo's home/ tree.
#
# Usage: update.sh [DEST]
#   DEST  the repo "home/" dir to update. Defaults to home/ next to this script.
#
# For every file already present under DEST, copy the live $HOME/<relpath> over
# it (only when it exists and differs). This never adds new files; it just
# refreshes what the repo already tracks.
set -euo pipefail

LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$LIBDIR/hostfilter.sh"

DEST=${1:-"$(cd "$LIBDIR/.." && pwd)/home"}
DEST=$(cd "$DEST" && pwd)

updated=0 same=0 missing=0
while IFS= read -r -d '' file; do
    rel=${file#"$DEST"/}
    src=$HOME/$rel
    # Don't try to pull back overlays that belong to other hosts.
    dotfiles_is_foreign_host_overlay "$rel" && continue
    if [ ! -e "$src" ]; then
        echo "missing $rel (not in \$HOME)"
        missing=$((missing + 1))
        continue
    fi
    if cmp -s "$src" "$file"; then
        same=$((same + 1))
        continue
    fi
    cp "$src" "$file"
    echo "update  $rel"
    updated=$((updated + 1))
done < <(find "$DEST" -type f -print0)

echo "----"
echo "$updated updated, $same unchanged, $missing missing in \$HOME"
