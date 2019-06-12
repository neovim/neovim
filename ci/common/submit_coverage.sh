#!/bin/sh

# Debug
set -x
echo "=== submit_coverage: $* ==="
env
pwd

# TODO
cd /c/projects/neovim || exit

find . -name '*.gcno' -o -name '*.gcna'

codecov_sh="${TEMP:-/tmp}/codecov.bash"
if ! [ -f "$codecov_sh" ]; then
  curl --fail https://codecov.io/bash > "$codecov_sh"
  chmod +x "$codecov_sh"
fi

# Run gcov manually.
# Allows more control, and uses ';' instead of '+'
# (https://github.com/codecov/codecov-bash/pull/159#issuecomment-498960314).
find build -type f -name '*.gcno' -execdir gcov -pb {} \;

# Debug
find . -name '*.gcov'

# -X gcov: disable gcov, done manually above.
# -Z: exit non-zero on failure
# -c: clear discovered files
# -F: flag(s)
"$codecov_sh" -X gcov -Z -c -F "$1" || echo "codecov upload failed."
