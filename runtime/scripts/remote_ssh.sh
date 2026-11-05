#!/bin/sh

# Bootstraps the headless Nvim server of a |remote-ssh| session: finds or installs `nvim`, which then
# runs and supervises the server (vim.net._ssh.serve()).
#
# Usage: remote_ssh.sh [--update] {sock} {dir} {url} [{version}]
#   Runs `nvim` from $PATH if it is {version} or newer, else the release {url}, which it installs
#   to {dir} (relative to $HOME) unless present, or always with --update. E.g.
#   remote_ssh.sh /tmp/nvim-remote.0123abcd/nvim.sock .local/share/nvim-remote/releases/v0.12.0-linux-x86_64 https://…/nvim-linux-x86_64.tar.gz v0.12.0

set -eu
# dash (Debian's sh) has no pipefail; tar still fails on an empty or truncated stream.
# shellcheck disable=SC3040
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

# Prints the path of `nvim` on $PATH, if it is $want or newer. It checks its own version, so an old
# or broken one fails.
# TODO: $PATH is that of a non-login shell, so it may lack e.g. `~/.local/bin`. Could take it from
# a throwaway login shell: `"$SHELL" -lc 'printf %s "$PATH"'`.
system_nvim() {
  [ -n "$want" ] || return 1
  nvim=$(command -v nvim) || return 1
  want=$want "$nvim" --clean -es \
    +'lua os.exit(vim.version.ge(vim.version(), os.getenv("want")) and 0 or 1)' \
    </dev/null >/dev/null 2>&1 || return 1
  echo "$nvim"
}

# Installs the release to $dest, unless present (and not $update).
install_release() (
  if [ -x "$dest/bin/nvim" ] && [ -z "$update" ]; then
    exit 0
  fi
  echo "Installing $dest..." >&2
  mkdir -p "${dest%/*}"
  tmp=$(mktemp -d "$dest.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  mkdir "$tmp/new"
  curl -fsSL "$url" | tar -xzf - -C "$tmp/new"
  if [ -n "$update" ]; then
    # Removed with $tmp. Gone already if a concurrent update moved it.
    mv "$dest" "$tmp/old" 2>/dev/null || :
  fi
  # The archive holds one top-level dir, e.g. `nvim-linux-x86_64/`. Atomic rename; keeps a
  # concurrent install that finished first.
  [ -e "$dest" ] || mv "$tmp"/new/* "$dest"
)

main() {
  update=
  if [ "$1" = --update ]; then
    update=1
    shift
  fi
  sock=$1
  dest="$HOME/$2"
  url=$3
  want=${4-}
  if ! nvim=$(system_nvim); then
    install_release
    nvim="$dest/bin/nvim"
  fi
  # Nvim inherits stdin from `sh -s` (i.e. from ssh), so EOF tells serve() that ssh disconnected.
  exec "$nvim" --clean -n --headless +"lua require('vim.net._ssh').serve('$sock')" +qa!
}

main "$@"
