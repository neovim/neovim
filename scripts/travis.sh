#!/bin/sh

export VALGRIND_CHECK=1
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist" || exit 1
make || exit 1
echo "Running tests with valgrind..."
if ! make test > /dev/null 2>&1; then
	failed=$(ls src/testdir/valgrind.*)
	if [ -n "$failed" ]; then
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
