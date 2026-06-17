#!/usr/bin/env bash
# Show diffs between the repo's home/ tree and the live $HOME.
#
# Usage: diff.sh [SRC]
#   SRC  the repo "home/" dir. Defaults to home/ next to this script.
set -euo pipefail

SRC=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/home"}
SRC=$(cd "$SRC" && pwd)

diffs=0 same=0 missing=0
while IFS= read -r -d '' file; do
    rel=${file#"$SRC"/}
    target=$HOME/$rel
    if [ ! -e "$target" ]; then
        echo "=== MISSING in \$HOME: $rel ==="
        missing=$((missing + 1))
    elif cmp -s "$file" "$target"; then
        same=$((same + 1))
    else
        echo "=== DIFF $rel (repo vs \$HOME) ==="
        diff "$file" "$target" || true
        diffs=$((diffs + 1))
    fi
done < <(find "$SRC" -type f -print0)

echo "----"
echo "$diffs differ, $same identical, $missing missing in \$HOME"
