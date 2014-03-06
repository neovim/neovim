. scripts/common.sh

(cd "$pkgroot/build" && make) || exit 1
eval "$(luarocks path)"

if [ $# == 0 ]; then # Assume full test
  busted --pattern=.moon ./test
else
  # Assume a list of unittest files
  for filename; do
    filename=./test/unit/$filename.moon
    if [ ! -f $filename ]; then
      echo "Not found: $filename"
    else
      busted $filename
    fi
  done
fi
