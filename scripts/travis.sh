#!/bin/sh -e

check_and_report() {
	(
	cd $tmpdir
	set -- [*]san.[*] *san.*
	case $1$2 in
		'[*]san.[*]*san.*')
			;;
		*)
			shift
			cat "$@"
			echo "Runtime errors detected"
			exit 1
			;;
	esac
	)
}

set_environment() {
	local prefix="$1"
	eval $($prefix/bin/luarocks path)
	export PATH="$prefix/bin:$PATH"
	export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
	export DEPS_CMAKE_FLAGS="-DUSE_BUNDLED_LIBUV=OFF -DUSE_BUNDLED_LUAJIT=OFF -DUSE_BUNDLED_MSGPACK=OFF -DUSE_BUNDLED_LUAROCKS=OFF"
}

# install prebuilt dependencies
if [ ! -d /opt/neovim-deps ]; then
	cd /opt
	sudo git clone --depth=1 git://github.com/tarruda/neovim-deps
	cd -
fi

# Travis reports back that it has 32-cores via /proc/cpuinfo, but it's not
# what we really have available.  According to their documentation, it only has
# 1.5 virtual cores.
# See:
#   http://docs.travis-ci.com/user/speeding-up-the-build/#Paralellizing-your-build-on-one-VM
# for more information.
MAKE_CMD="make -j2"

if [ "$TRAVIS_BUILD_TYPE" = "clang/asan" ]; then
	if [ ! -d /usr/local/clang-3.4 ]; then
		echo "Downloading clang 3.4..."
		sudo sh <<- "EOF"
		mkdir /usr/local/clang-3.4
		wget -q -O - http://llvm.org/releases/3.4/clang+llvm-3.4-x86_64-unknown-ubuntu12.04.tar.xz |
		unxz -c | tar xf - --strip-components=1 -C /usr/local/clang-3.4
		EOF
	fi
	sudo pip install cpp-coveralls --use-mirrors

	export CC=clang
	set_environment /opt/neovim-deps
	if test -f /usr/local/clang-3.4/bin/clang; then
		USE_CLANG_34=true
		export CC=/usr/local/clang-3.4/bin/clang
		symbolizer=/usr/local/clang-3.4/bin/llvm-symbolizer
	fi

	# Try to detect clang-3.4 installed via apt and through llvm.org/apt/.
	if dpkg -s clang-3.4 > /dev/null 2>&1; then
		USE_CLANG_34=true
		export CC=/usr/bin/clang
		symbolizer=/usr/bin/llvm-symbolizer-3.4
	fi

	install_dir="$(pwd)/dist"
	# temporary directory for writing sanitizer logs
	tmpdir="$(pwd)/tmp"
	rm -rf "$tmpdir"
	mkdir -p "$tmpdir"

	# need the symbolizer path for stack traces with source information
	if [ -n "$USE_CLANG_34" ]; then
		export ASAN_OPTIONS="detect_leaks=1:"
	else
		symbolizer=/usr/local/clang-3.3/bin/llvm-symbolizer
	fi

	export SANITIZE=1
	export ASAN_SYMBOLIZER_PATH=$symbolizer
	export ASAN_OPTIONS="${ASAN_OPTIONS}log_path=$tmpdir/asan"
	export TSAN_OPTIONS="external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"

	export SKIP_UNITTEST=1
	export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works

	$MAKE_CMD cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$install_dir -DUSE_GCOV=ON"
	$MAKE_CMD
	if ! $MAKE_CMD test; then
		reset
		check_and_report
		exit 1
	fi
	check_and_report
	coveralls --encoding iso-8859-1
	$MAKE_CMD install
elif [ "$TRAVIS_BUILD_TYPE" = "gcc/unittest" ]; then
	sudo pip install cpp-coveralls --use-mirrors
	export CC=gcc
	set_environment /opt/neovim-deps
	export SKIP_EXEC=1
	$MAKE_CMD CMAKE_EXTRA_FLAGS="-DBUSTED_OUTPUT_TYPE=TAP -DUSE_GCOV=ON" unittest
	coveralls --encoding iso-8859-1
elif [ "$TRAVIS_BUILD_TYPE" = "gcc/ia32" ]; then
	set_environment /opt/neovim-deps/32
	sudo apt-get update

	# Need this to keep apt-get from removing gcc when installing libncurses
	# below.
	sudo apt-get install libc6-dev libc6-dev:i386

	# Do this separately so that things get configured correctly, otherwise
	# libncurses fails to install.
	sudo apt-get install gcc-multilib g++-multilib

	# Install the dev version to get the pkg-config and symlinks installed
	# correctly.
	sudo apt-get install libncurses5-dev:i386

	$MAKE_CMD CMAKE_EXTRA_FLAGS="-DBUSTED_OUTPUT_TYPE=TAP -DCMAKE_TOOLCHAIN_FILE=cmake/i386-linux-gnu.toolchain.cmake" unittest
	$MAKE_CMD test
elif [ "$TRAVIS_BUILD_TYPE" = "clint" ]; then
	./scripts/clint.sh
fi
