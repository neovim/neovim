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

# Travis reports back that it has 32-cores via /proc/cpuinfo, but it's not
# what we really have available.  According to their documentation, it only has
# 1.5 virtual cores.
# See:
#   http://docs.travis-ci.com/user/speeding-up-the-build/#Paralellizing-your-build-on-one-VM
# for more information.
MAKE_CMD="make -j2"

if [ "$CC" = "clang" ]; then
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
	$MAKE_CMD install
else
	export SKIP_EXEC=1
	$MAKE_CMD CMAKE_EXTRA_FLAGS="-DBUSTED_OUTPUT_TYPE=TAP -DUSE_GCOV=ON"
	$MAKE_CMD cmake CMAKE_EXTRA_FLAGS="-DUSE_GCOV=ON"
	$MAKE_CMD unittest
fi
