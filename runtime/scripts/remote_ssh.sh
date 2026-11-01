#!/bin/sh

# Runs the headless Nvim server of a |remote-ssh| session, until it exits or ssh disconnects.
# Prints NVIM_READY once the server listens (or NVIM_CRASHED).
#
# Usage: remote_ssh.sh {sock} {dir} {url} [{version}]
#   Runs `nvim` from $PATH if it is {version} or newer, else the release {url}, which it installs
#   to {dir} (relative to $HOME) unless present. E.g.
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

# Installs the release to $dest, unless present.
install_release() (
  if [ -x "$dest/bin/nvim" ]; then
    exit 0
  fi
  echo "Installing $dest..." >&2
  mkdir -p "${dest%/*}"
  tmp=$(mktemp -d "$dest.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$url" | tar -xzf - -C "$tmp"
  # The archive holds one top-level dir, e.g. `nvim-linux-x86_64/`. Atomic rename; keeps a
  # concurrent install that finished first.
  [ -e "$dest" ] || mv "$tmp"/* "$dest"
)

# Starts `nvim` ($1) as the server at $sock, in a private dir. Both are removed on exit.
# Prints NVIM_READY once it listens, or NVIM_CRASHED.
start_server() {
  dir=${sock%/*}
  # Fresh private dir: `mkdir` fails if it exists, so nobody can plant a socket.
  mkdir -m 700 "$dir"
  nvim_pid=
  trap 'kill "$nvim_pid" 2>/dev/null || true; rm -rf "$dir"' EXIT
  trap 'exit 1' HUP INT TERM PIPE
  __NVIM_STARTREASON=remote-ssh NVIM_APPNAME=nvim-remote "$1" --headless --listen "$sock" </dev/null &
  nvim_pid=$!
  while [ ! -S "$sock" ]; do
    if ! kill -0 "$nvim_pid" 2>/dev/null; then
      echo "NVIM_CRASHED"
      exit 1
    fi
    sleep 0.1
  done
  echo "NVIM_READY"
}

# Waits until the server exits or ssh disconnects. No pty, so no SIGHUP on disconnect: a failed
# heartbeat write triggers the EXIT trap.
heartbeat() {
  while kill -0 "$nvim_pid" 2>/dev/null; do
    # `wait` (unlike a foreground `sleep`) lets a signal run its trap at once. The `sleep` must not
    # hold stdout, else the closing ssh channel waits for it.
    sleep 1 >/dev/null 2>&1 &
    wait $!
    printf '\n' 2>/dev/null || exit 1
  done
}

main() {
  sock=$1
  dest="$HOME/$2"
  url=$3
  want=${4-}
  if ! nvim=$(system_nvim); then
    install_release
    nvim="$dest/bin/nvim"
  fi
  start_server "$nvim"
  heartbeat
}

main "$@"
