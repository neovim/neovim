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
alias make="make -j2"

if [ "$CC" = "clang" ]; then
	# force using the version installed by 'travis-setup.sh'
	export CC=/usr/bin/clang

	install_dir="$(pwd)/dist"
	# temporary directory for writing sanitizer logs
	tmpdir="$(pwd)/tmp"
	rm -rf "$tmpdir"
	mkdir -p "$tmpdir"

	# need the symbolizer path for stack traces with source information
	symbolizer=/usr/bin/llvm-symbolizer-3.4

	export SKIP_UNITTEST=1
	export SANITIZE=1
	export ASAN_SYMBOLIZER_PATH=$symbolizer
	export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
	export TSAN_OPTIONS="external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"
	export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works

	make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$install_dir"
	make
	if ! make test; then
		reset
		check_and_report
	fi
	check_and_report
	make install
else
	export SKIP_EXEC=1
	make CMAKE_EXTRA_FLAGS="-DBUSTED_OUTPUT_TYPE=TAP"
	make cmake
	make unittest
fi
