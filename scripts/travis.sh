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

case $CC in
	clang-*)
		install_dir="$(pwd)/dist"
		# temporary directory for writing sanitizer logs
		tmpdir="$(pwd)/tmp"
		rm -rf "$tmpdir"
		mkdir -p "$tmpdir"

		# need the symbolizer path for stack traces with source information
		export symbolizer=/usr/bin/llvm-symbolizer-3.4
		export SKIP_UNITTEST=1

		if [ "$CC" = "clang-tsan" ]; then
			export SANITIZE=thread
			export TSAN_OPTIONS="suppressions=$(pwd)/.tsan-suppress:external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"
		else
			export SANITIZE=address
			export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
			export ASAN_SYMBOLIZER_PATH=$symbolizer
			export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works
		fi

		# force using the version installed by 'travis-setup.sh'
		export CC=/usr/bin/clang

		make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$install_dir"
		make
		if ! make test; then
			reset
			check_and_report
			exit 1
		fi
		check_and_report
		make install
		;;
	*)
		export BUSTED_OUTPUT_TYPE="TAP"
		export SKIP_EXEC=1
		make cmake
		make unittest
		;;
esac
