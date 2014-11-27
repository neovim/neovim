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
	local c
	for c in $(find ./ -name '*core*' -print); do
	 	gdb -q -n -batch -ex bt build/bin/nvim $c
		exit 1
	done
}

setup_prebuilt_deps() {
	eval "$(curl -Ss https://raw.githubusercontent.com/neovim/bot-ci/master/scripts/travis-setup.sh) deps-${1}"
}

tmpdir="$(pwd)/tmp"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"
suppressions="$(pwd)/.valgrind.supp"
