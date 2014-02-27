. scripts/common.sh

(cd "$pkgroot/build" && make) || exit 1
eval "$(luarocks path)"

busted --pattern=.moon ./test
