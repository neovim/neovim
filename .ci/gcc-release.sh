. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps

export CC=gcc
$MAKE_CMD CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON -DBUSTED_OUTPUT_TYPE=color_terminal -DCMAKE_BUILD_TYPE=Release" unittest
