#!/usr/bin/env bash
# Diff this repo's home/ tree against $HOME, plus any overlay trees.
#
# Usage: status.sh [OVERLAY_HOME ...]
#   OVERLAY_HOME  extra "home/" dir(s) to also diff (e.g. a private repo's home/).
#                 If none are given, $DOTFILES_PRIVATE is used when set.
#
# Keeps the public repo free of any private reference: overlays are supplied at
# runtime via args or $DOTFILES_PRIVATE, never hardcoded here.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFF="$HERE/diff.sh"

overlays=("$@")
if [ ${#overlays[@]} -eq 0 ] && [ -n "${DOTFILES_PRIVATE:-}" ]; then
    overlays=("$DOTFILES_PRIVATE")
fi

echo "############ public ($HERE/../home) vs \$HOME ############"
bash "$DIFF" "$HERE/../home"

for ov in "${overlays[@]}"; do
    # Accept either a repo root (append /home) or a home/ dir directly.
    [ -d "$ov/home" ] && ov="$ov/home"
    echo
    echo "############ overlay ($ov) vs \$HOME ############"
    if [ -d "$ov" ]; then
        bash "$DIFF" "$ov"
    else
        echo "(skip: $ov not found)"
    fi
done
