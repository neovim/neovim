#!/bin/sh -e

check_and_report() {
	reset
	(
	cd $tmpdir
	if [ -f asan.* ] || [ -f tsan.* ] || [ -f ubsan.* ]; then
		cat $tmpdir/asan.* 2> /dev/null || true
	 	cat $tmpdir/tsan.* 2> /dev/null || true
	 	cat $tmpdir/ubsan.* 2> /dev/null || true
		exit 1
	fi
	)
}

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
		check_and_report
	fi
	check_and_report
	make install
else
	export BUSTED_OUTPUT_TYPE="TAP"
	export SKIP_EXEC=1
	make cmake
	make unittest
fi

