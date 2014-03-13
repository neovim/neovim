#!/bin/sh -e

# [ "$CC" != "clang" ] && exit

add-apt-repository -y ppa:ubuntu-toolchain-r/ppa
wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key | apt-key add -

cat > /etc/apt/sources.list.d/clang.list << "EOF"
deb http://llvm.org/apt/precise/ llvm-toolchain-precise main
deb-src http://llvm.org/apt/precise/ llvm-toolchain-precise main
# 3.4
deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.4 main
deb-src http://llvm.org/apt/precise/ llvm-toolchain-precise-3.4 main
# Common
deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu precise main
EOF

apt-get -qq update
apt-get -qq -y --no-install-recommends install clang-3.4 lldb-3.4
