#!/usr/bin/env bash
# Shared helper: decide whether a dotfile relpath is a host-specific overlay that
# does NOT belong on the current host, so install/diff/update can skip it.
#
# Overlay convention (see README "Machine-specific & private overlays"):
#   <base>.private     -> private-repo overlay; applies on every host (never skipped)
#   <base>.$HOSTNAME   -> host-specific; only for that one host
#
# Only files whose basename is "<stem>.<tag>" for one of the recognized overlay
# stems below are treated as host overlays. <tag> must be a single token (no
# dots); "private" is reserved (never treated as a hostname). A file is "foreign"
# (skip) when its <tag> is a hostname other than this machine's short or full
# hostname.
#
# Extend DOTFILES_HOST_STEMS (space-separated) to add more overlay families.

DOTFILES_HOST_STEMS=${DOTFILES_HOST_STEMS:-".bashrc .bash_aliases .bash_funcs .vimrc .tmux.conf"}

# dotfiles_is_foreign_host_overlay REL
#   returns 0 (true)  -> REL is another host's overlay; caller should SKIP it
#   returns 1 (false) -> REL is generic, this host's, or not an overlay; KEEP it
dotfiles_is_foreign_host_overlay() {
    local rel="$1"
    local fname stem tag host_s host_f
    fname=$(basename "$rel")
    host_s=$(hostname -s 2>/dev/null || hostname)
    host_f=$(hostname 2>/dev/null || echo "$host_s")

    for stem in $DOTFILES_HOST_STEMS; do
        case "$fname" in
            "$stem".*)
                tag=${fname#"$stem".}
                case "$tag" in
                    private|*.*) return 1 ;;   # reserved or compound suffix -> keep
                esac
                # A single-token tag == a hostname. Keep only if it's ours.
                if [ "$tag" = "$host_s" ] || [ "$tag" = "$host_f" ]; then
                    return 1
                fi
                return 0
                ;;
        esac
    done
    return 1
}
