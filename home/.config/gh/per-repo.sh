# Per-repo GitHub CLI account routing.
#
# `gh auth switch` is global and races across shells. This instead reads which
# logged-in account to use for *this* directory and injects that account's token
# via GH_TOKEN for a single invocation.
#
# Precedence:
#   1. `git config gh.account <user>` in the current repo
#   2. a `.gh-account` file (walk CWD → /) for non-git directories
#   3. the globally active gh account
#
# Sourced from ~/.bash_funcs (interactive shells) and from Cursor skills
# (agent shells skip ~/.bashrc). Safe to source more than once.
#
# Pin a repo:    git config gh.account <user>
# Pin a folder:  echo <user> > .gh-account

_gh_resolve_account() {
  local acct dir
  acct=$(git config --get gh.account 2>/dev/null) || acct=
  if [ -z "$acct" ]; then
    dir=${PWD:-.}
    while [ -n "$dir" ]; do
      if [ -f "$dir/.gh-account" ]; then
        acct=$(head -n1 "$dir/.gh-account" 2>/dev/null | tr -d '[:space:]')
        break
      fi
      [ "$dir" = "/" ] && break
      dir=$(dirname "$dir")
    done
  fi
  printf '%s' "$acct"
}

gh() {
  local acct token
  acct=$(_gh_resolve_account)
  if [ -n "$acct" ]; then
    token=$(command gh auth token --user "$acct" 2>/dev/null) || token=
    if [ -n "$token" ]; then
      GH_TOKEN=$token command gh "$@"
      return
    fi
  fi
  command gh "$@"
}
