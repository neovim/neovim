#!/bin/sh -e

# Despite the logs, CC isn't being exported at before_install time in Travis.
# So the following check cannot be used to avoid the download.
# [ "$CC" != "clang" ] && exit

echo "Downloading clang 3.4..."
mkdir /usr/local/clang-3.4
wget -q -O - http://llvm.org/releases/3.4/clang+llvm-3.4-x86_64-unknown-ubuntu12.04.tar.xz |
	unxz -c | tar xf - --strip-components=1 -C /usr/local/clang-3.4


# The section below is still around, in case we want to try the llvm.org/apt/
# repository again.

# Set to true to enable using the clang stable builds hosted at
# http://llvm.org/apt/.
#
# Note: there have been issues with this repository.  Several days in a row
# there have been problems running from broken a source repository (causing us
# to remove them from the .list file), to the toolchain being packaged
# incorrectly (most likely due to a change in version number--3.4.0 -> 3.4.1).
# Use with care.
# USE_CLANG_34=true

# if [ -n "$USE_CLANG_34" ]; then
# 	add-apt-repository -y ppa:ubuntu-toolchain-r/ppa
# 	wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key | apt-key add -

# 	cat > /etc/apt/sources.list.d/clang.list << "EOF"
# # deb http://llvm.org/apt/precise/ llvm-toolchain-precise main
# # deb-src http://llvm.org/apt/precise/ llvm-toolchain-precise main
# # 3.4
# deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.4 main
# # deb-src http://llvm.org/apt/precise/ llvm-toolchain-precise-3.4 main
# # Common
# deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu precise main
# EOF
# fi

# apt-get -qq update

# [ -n "$USE_CLANG_34" ] &&
# 	apt-get -qq -y --no-install-recommends install clang-3.4 lldb-3.4

pip install cpp-coveralls --use-mirrors
