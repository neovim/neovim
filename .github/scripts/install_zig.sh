#!/bin/sh

# Install the Zig version that build.zig.zon requires, from ziglang.org.
# Used by the BSD jobs, whose VMs can't use setup-zig.

set -eu

os=$(uname -s | tr '[:upper:]' '[:lower:]')
version=$(sed -n 's/.*minimum_zig_version = "\(.*\)".*/\1/p' build.zig.zon)
zig=zig-$(uname -m | sed 's/^amd64$/x86_64/')-$os-$version
url=https://ziglang.org/download/$version/$zig.tar.xz

case $os in
  freebsd) fetch -o /tmp/zig.tar.xz "$url" ;;
  openbsd) ftp -o /tmp/zig.tar.xz "$url" ;;
  *) echo "unsupported OS: $os" >&2; exit 1 ;;
esac

xz -dc /tmp/zig.tar.xz | tar -xf - -C /usr/local
ln -s "/usr/local/$zig/zig" /usr/local/bin/zig
