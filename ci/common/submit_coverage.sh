#!/bin/sh

# Debug
set -x
echo "=== submit_coverage: $* ==="
pwd
find . -name '*.gcno' -o -name '*.gcna'

codecov_sh="${TEMP:-/tmp}/codecov.bash"
if ! [ -f "$codecov_sh" ]; then
  curl --fail https://codecov.io/bash > "$codecov_sh"
  chmod +x "$codecov_sh"
fi

# -Z: exit non-zero on failure
# -c: clear discovered files
# -F: flag(s)
"$codecov_sh" -Z -c -F "$1" || echo "codecov upload failed."
