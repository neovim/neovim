. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps

setup_clang

$MAKE_CMD CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON -DCMAKE_BUILD_TYPE=Release -DBUSTED_OUTPUT_TYPE=color_terminal" unittest
