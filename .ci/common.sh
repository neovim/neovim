valgrind_check() {
	(
	cd $1
	set -- valgrind-[*] valgrind-*
	case $1$2 in
		'valgrind-[*]valgrind-*')
			;;
		*)
			shift
			local err=''
			for valgrind_log in "$@"; do
				# Remove useless warning
				sed -i "$valgrind_log" \
					-e '/Warning: noted but unhandled ioctl/d' \
					-e '/could cause spurious value errors to appear/d' \
					-e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
				if [ "$(stat -c %s $valgrind_log)" != "0" ]; then
					# if after removing the warning, the log still has errors, show its
					# contents and set the flag so we exit with non-zero status
					cat "$valgrind_log"
					err=1
				fi
			done
			if [ -n "$err" ]; then
				echo "Runtime errors detected"
				exit 1
			fi
			;;
	esac
	)
}

asan_check() {
	(
	cd $1
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

set_environment() {
	local prefix="$1"
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

install_vroom() {
	(
	sudo pip install neovim
	git clone git://github.com/google/vroom
	cd vroom
	python setup.py build
	sudo python setup.py install
	)
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
