. scripts/common.sh

(cd "$pkgroot/build" && make) || exit 1
eval "$(luarocks path)"

if [ -z "$BUSTED_OUTPUT_TYPE" ]; then
    export BUSTED_OUTPUT_TYPE="utf_terminal"
fi
make -C ./test/includes
busted --pattern=.moon -o $BUSTED_OUTPUT_TYPE ./test
