valgrind_check() {
	check_logs "$1" "valgrind-*"
}

asan_check() {
	check_logs "$1" "*san.*"
}

check_logs() {
	# For some strange reason, now we need to give ubuntu some time to flush it's
	# FS cache in order to see error logs, even though all commands are executing
	# synchronously
	sleep 1
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

set_environment() {
	local prefix="$1/usr"
	eval $($prefix/bin/luarocks path)
	export PATH="$prefix/bin:$PATH"
	export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
	export USE_BUNDLED_DEPS=OFF
}


install_prebuilt_deps() {
	# install prebuilt dependencies
	if [ ! -d /opt/neovim-deps ]; then
		cd /opt
		sudo git clone --depth=1 git://github.com/neovim/deps neovim-deps
		cd -
	fi
}

install_functional_test_deps() {
	sudo pip install git+https://github.com/neovim/python-client.git
	# Pass -E to let pip use PKG_CONFIG_PATH for luajit
	sudo -E pip install lupa
}

tmpdir="$(pwd)/tmp"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"
suppressions="$(pwd)/.valgrind.supp"

# Travis reports back that it has 32-cores via /proc/cpuinfo, but it's not
# what we really have available.  According to their documentation, it only has
# 1.5 virtual cores.
# See:
#   http://docs.travis-ci.com/user/speeding-up-the-build/#Paralellizing-your-build-on-one-VM
# for more information.
MAKE_CMD="make -j2"

install_prebuilt_deps

# Pins the version of the java package installed on the Travis VMs
# and avoids a lengthy upgrade process for them.
sudo apt-mark hold oracle-java7-installer oracle-java8-installer

sudo apt-get update
