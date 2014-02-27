#!/bin/sh -e

MAKE="make -C scripts/"

export VALGRIND_CHECK=1
$MAKE cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
$MAKE
echo "Running tests with valgrind..."
if ! $MAKE test > /dev/null; then
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
$MAKE install
