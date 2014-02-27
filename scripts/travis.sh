#!/bin/sh -e

export VALGRIND_CHECK=1
make -C scripts/ cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make -C scripts/
echo "Running tests with valgrind..."
if ! make test > /dev/null; then
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
