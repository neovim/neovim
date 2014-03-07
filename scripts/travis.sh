#!/bin/sh -e

export VALGRIND_CHECK=1
export BUSTED_OUTPUT_TYPE="TAP"
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make
make unittest
echo "Running tests with valgrind..."
if ! make test; then
	if ls src/testdir/valgrind.* > /dev/null 2>&1; then
		echo "Memory leak detected" >&2 
		cat src/testdir/valgrind.*
	else
		echo "Failed tests:" >&2 
		for t in src/testdir/*.failed; do
			echo ${t%%.*}
		done	
	fi
	exit 1
fi
make install
