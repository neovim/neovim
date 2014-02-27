#!/bin/sh -e

export VALGRIND_CHECK=1
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make
echo "Running tests with valgrind..."
if ! make test > /dev/null 2>&1; then
	failed=$(ls src/testdir/valgrind.* || true)
	if [ -n "$failed" ]; then
		echo "Memory leak detected" >&2 
		cat src/testdir/valgrind.*
	else
		echo "Failed tests:" >&2 
		for t in src/testdir/*.failed; do
			echo ${t%%.*}
		done	
	fi
	exit 2
fi
make install
