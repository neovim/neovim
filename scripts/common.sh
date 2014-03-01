platform='unknown'
unameval=`uname`
if [ "$unameval" = 'Linux' ]; then
	platform='linux'
elif [ "$unameval" = 'FreeBSD' ]; then
	platform='freebsd'
elif [ "$unameval" = 'Darwin' ]; then
	platform='darwin'
fi

sha1sumcmd='sha1sum'
if [ "$platform" = 'freebsd' ]; then
	sha1sumcmd='shasum'
elif [ "$platform" = 'darwin' ]; then
	sha1sumcmd='shasum'
fi

pkgroot="$(pwd)"
deps="$pkgroot/.deps"
prefix="$deps/usr"
export PATH="$prefix/bin:$PATH"

download() {
	local url=$1
	local tgt=$2
	local sha1=$3

	if [ ! -d "$tgt" ]; then
		mkdir -p "$tgt"
		local download_command=""
		if which wget > /dev/null 2>&1; then
			# -O - to send output to stdout
			download_command="wget --no-verbose $url -O -"
		elif which curl >/dev/null 2>&1; then
			# -L to follow the redirects that github will send us
			# -sS to supress the progress bar, but show errors
			# curl sends output to stdout by default
			download_command="curl -L -sS $url"
		else
			echo "Missing wget utility and curl utility"
			exit 1
		fi
		local tmp_dir=$(mktemp -d "/tmp/download_sha1check_XXXXXXX")
		local fifo="$tmp_dir/fifo"
		mkfifo "$fifo"
		echo "Downloading $url..."
		# download, untar and calculate sha1 sum in one pass
		($download_command | tee "$fifo" | \
			(cd "$tgt";  tar --strip-components=1 -xzf -)) &
		local sum=$("$sha1sumcmd" < "$fifo" | cut -d ' ' -f1)
		rm -rf "$tmp_dir"
		if [ "$sum" != "$sha1" ]; then
			echo "SHA1 sum doesn't match, expected '$sha1' got '$sum'"
			exit 1
		else
			echo "Download complete."
		fi
	fi
}

github_download() {
	local repo=$1
	local ver=$2
	download "https://github.com/${repo}/archive/${ver}.tar.gz" "$3" "$4"
}
