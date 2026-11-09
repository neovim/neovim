#!/bin/sh

# Bootstraps the headless Nvim server of a |remote-ssh| session: finds or installs `nvim`, which then
# runs and supervises the server (vim.net._ssh.serve()). Its stderr is reported as progress msgs.
#
# Usage: remote_ssh.sh [--update] {sock} {dir} {url} {sha256} {version}
#   Runs `nvim` from $PATH if it is {version} or newer, else the release {url} (`-`: none for this
#   platform), which it installs to {dir} (relative to $HOME) unless present, if its SHA-256 is
#   {sha256} (`-`: unknown, so it does not install). --update: (re)installs and runs the release.
#
#   Example:
#     remote_ssh.sh /tmp/nvim-remote.0123abcd/nvim.sock .local/share/nvim-remote/releases/v0.12.0-linux-x86_64 https://…/nvim-linux-x86_64.tar.gz 474430d5…7d87 v0.12.0

set -eu
# dash (Debian's sh) has no pipefail, so a pipeline must also fail safely without it, e.g.
# `file_sha256` then prints nothing (a mismatch).
# shellcheck disable=SC3040
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

# Prints the path of `nvim` on $PATH, if it is $want or newer. It checks its own version, so an old
# or broken one fails.
# TODO: $PATH is that of a non-login shell, so it may lack e.g. `~/.local/bin`. Could take it from
# a throwaway login shell: `"$SHELL" -lc 'printf %s "$PATH"'`.
system_nvim() {
  nvim=$(command -v nvim) || return 1
  want=$want "$nvim" --clean -es \
    +'lua os.exit(vim.version.ge(vim.version(), os.getenv("want")) and 0 or 1)' \
    </dev/null >/dev/null 2>&1 || return 1
  echo "$nvim"
}

# Fails unless each command $@ is on $PATH.
require() {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Not found on \$PATH: $cmd" >&2
      exit 1
    fi
  done
}

# Prints the SHA-256 of file $1.
file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1" # macOS.
  fi | cut -d ' ' -f 1
}

# Installs the release to $dest, unless present (and not $update).
install_release() (
  if [ -x "$dest/bin/nvim" ] && [ -z "$update" ]; then
    exit 0
  fi
  if [ "$url" = - ]; then
    echo "No Nvim release for $(uname -sm): install nvim $want or newer on \$PATH" >&2
    exit 1
  fi
  if [ "$sha256" = - ]; then
    echo "Cannot verify $url: SHA-256 unknown (see the local remote-ssh.log)" >&2
    exit 1
  fi
  echo "Installing $dest..." >&2
  require curl tar
  command -v sha256sum >/dev/null 2>&1 || require shasum
  mkdir -p "${dest%/*}"
  tmp=$(mktemp -d "$dest.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --retry 3 -o "$tmp/nvim.tar.gz" "$url"
  got=$(file_sha256 "$tmp/nvim.tar.gz")
  if [ "$got" != "$sha256" ]; then
    echo "SHA-256 mismatch: $url (expected $sha256, got $got)" >&2
    exit 1
  fi
  mkdir "$tmp/new"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp/new"
  # The archive holds one top-level dir, e.g. `nvim-linux-x86_64/`.
  release=$(echo "$tmp"/new/*)
  if ! err=$("$release/bin/nvim" --version 2>&1 >/dev/null); then
    echo "Cannot run $url (Linux releases need glibc): $err" >&2
    exit 1
  fi
  if [ -n "$update" ]; then
    # Removed with $tmp. Gone already if a concurrent update moved it.
    mv "$dest" "$tmp/old" 2>/dev/null || :
  fi
  # Atomic rename; keeps a concurrent install that finished first.
  [ -e "$dest" ] || mv "$release" "$dest"
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
  sha256=$4
  want=$5
  if [ -n "$update" ] || ! nvim=$(system_nvim); then
    install_release
    nvim="$dest/bin/nvim"
  fi
  echo "Starting $nvim..." >&2
  # Nvim inherits stdin from `sh -s` (i.e. from ssh), so EOF tells serve() that ssh disconnected.
  exec "$nvim" --clean -n --headless +"lua require('vim.net._ssh').serve('$sock')" +qa!
}

main "$@"
