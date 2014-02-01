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
		if which wget > /dev/null 2>&1; then
			tmp_dir=$(mktemp -d "/tmp/download_sha1check_XXXXXXX")
			fifo="$tmp_dir/fifo"
			mkfifo "$fifo"
			# download, untar and calculate sha1 sum in one pass
			(wget "$url" -O - | tee "$fifo" | \
				(cd "$tgt";  tar --strip-components=1 -xvzf -)) &
			sum=$(sha1sum < "$fifo" | cut -d ' ' -f1)
			rm -rf "$tmp_dir"
			if [ "$sum" != "$sha1" ]; then
				echo "SHA1 sum doesn't match, expected '$sha1' got '$sum'"
				exit 1
			fi
		else
			echo "Missing wget utility"
			exit 1
		fi
	fi
}

github_download() {
	local repo=$1
	local ver=$2
	download "https://github.com/${repo}/archive/${ver}.tar.gz" "$3" "$4"
}
