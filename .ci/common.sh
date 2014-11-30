valgrind_check() {
	check_logs "$1" "valgrind-*"
}

asan_check() {
	check_logs "$1" "*san.*"
}

check_logs() {
	check_core_dumps
	# Iterate through each log to remove an useless warning
	for log in $(find "$1" -type f -name "$2"); do
		sed -i "$log" \
			-e '/Warning: noted but unhandled ioctl/d' \
			-e '/could cause spurious value errors to appear/d' \
			-e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
	done
	# Now do it again, but only consider files with size > 0
	for log in $(find "$1" -type f -name "$2" -size +0); do
		cat "$log"
		err=1
	done
	if [ -n "$err" ]; then
		echo "Runtime errors detected"
		exit 1
	fi
}

check_core_dumps() {
	sleep 2

	if [ "$TRAVIS_OS_NAME" = "osx" ]; then
		cores="$(find /cores/ -type f -print)"
		dbg="lldb -Q -o bt -f build/bin/nvim -c"
	else
		# TODO(fwalch): Will trigger if a file named core.* exists outside of .deps.
		cores="$(find ./ -type f -not -path '*.deps*' -name 'core.*' -print)"
		dbg="gdb -n -batch -ex bt build/bin/nvim"
	fi

	if [ -z "$cores" ]; then
		return
	fi
	for c in $cores; do
		$dbg $c
	done
	exit 1
}

setup_deps() {
	sudo pip install neovim
	if [ "$BUILD_NVIM_DEPS" != "true" ]; then
		eval "$(curl -Ss https://raw.githubusercontent.com/neovim/bot-ci/master/scripts/travis-setup.sh) deps-${1}"
	elif [ "$TRAVIS_OS_NAME" = "linux" ]; then
		sudo apt-get install libtool
	fi
}

tmpdir="$(pwd)/tmp"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"
suppressions="$(pwd)/.valgrind.supp"
