#!/bin/sh

set -x

# Change to grandparent dir (POSIXly).
CDPATH='' cd -P -- "$(dirname -- "$0")/../.." || exit

echo "=== running submit_coverage in $PWD: $* ==="

# Debug
command -v gcov
gcov --version
find . -name '*.gcno' -o -name '*.gcna'

# Run gcov manually.
# Allows more control, and uses ';' instead of '+'
# (https://github.com/codecov/codecov-bash/pull/159#issuecomment-498960314).
find build -type f -name '*.gcno' -execdir gcov -pb {} \;

# Debug
find . -name '*.gcov'

# Download codecov-bash once.
codecov_sh="${TEMP:-/tmp}/codecov.bash"
if ! [ -f "$codecov_sh" ]; then
  curl --fail https://codecov.io/bash > "$codecov_sh"
  chmod +x "$codecov_sh"
fi

# Upload to codecov.
# -X gcov: disable gcov, done manually above.
# -Z: exit non-zero on failure
# -c: clear discovered files
# -F: flag(s)
"$codecov_sh" -X gcov -Z -c -F "$1" || echo "codecov upload failed."
