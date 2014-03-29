#!/bin/sh -e

[ "$CC" != "clang" ] && exit

# Set to true to enable using the clang nightly builds (of the stable branch).
CLANG_NIGHTLIES=

if [ -n "$CLANG_NIGHTLIES" ]; then
	add-apt-repository -y ppa:ubuntu-toolchain-r/ppa
	wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key | apt-key add -

	cat > /etc/apt/sources.list.d/clang.list << "EOF"
deb http://llvm.org/apt/precise/ llvm-toolchain-precise main
# 3.4
deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.4 main
# Common
deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu precise main
EOF
fi

apt-get -qq update

[ -n "$USE_CLANG_NIGHTLIES" ] &&
	apt-get -qq -y --no-install-recommends install clang-3.4 lldb-3.4
