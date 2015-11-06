# Copy this to 'local.mk' in the repository root.
# Individual entries must be uncommented to take effect.

# By default, the installation prefix is '/usr/local'.
# CMAKE_EXTRA_FLAGS += -DCMAKE_INSTALL_PREFIX=/usr/local/nvim-latest

# These CFLAGS can be used in addition to those specified in CMakeLists.txt:
# CMAKE_EXTRA_FLAGS="-DCMAKE_C_FLAGS=-ftrapv -Wlogical-op"

# By default, the jemalloc family of memory allocation functions are used.
# Uncomment the following to instead use libc memory allocation functions.
# CMAKE_EXTRA_FLAGS += -DENABLE_JEMALLOC=OFF

# Sets the build type; defaults to Debug. Valid values:
#
# - Debug:          Disables optimizations (-O0), enables debug information and logging.
#
# - Dev:            Enables all optimizations that do not interfere with
#                   debugging (-Og if available, -O2 and -g if not).
#                   Enables debug information and logging.
#
# - RelWithDebInfo: Enables optimizations (-O2) and debug information.
#                   Disables logging.
#
# - MinSizeRel:     Enables all -O2 optimization that do not typically
#                   increase code size, and performs further optimizations
#                   designed to reduce code size (-Os).
#                   Disables debug information and logging.
#
# - Release:        Same as RelWithDebInfo, but disables debug information.
#
# CMAKE_BUILD_TYPE := Debug

# By default, nvim uses bundled versions of its required third-party
# dependencies.
# Uncomment these entries to instead use system-wide installations of
# them.
#
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_BUSTED=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_DEPS=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_JEMALLOC=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_LIBTERMKEY=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_LIBUV=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_LIBVTERM=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_LUAJIT=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_LUAROCKS=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_MSGPACK=OFF
# DEPS_CMAKE_FLAGS += -DUSE_BUNDLED_UNIBILIUM=OFF

# By default, bundled libraries are statically linked to nvim.
# This has no effect for non-bundled deps, which are always dynamically linked.
# Uncomment these entries to instead use dynamic linking.
#
# CMAKE_EXTRA_FLAGS += -DLIBTERMKEY_USE_STATIC=OFF
# CMAKE_EXTRA_FLAGS += -DLIBUNIBILIUM_USE_STATIC=OFF
# CMAKE_EXTRA_FLAGS += -DLIBUV_USE_STATIC=OFF
# CMAKE_EXTRA_FLAGS += -DLIBVTERM_USE_STATIC=OFF
# CMAKE_EXTRA_FLAGS += -DLUAJIT_USE_STATIC=OFF
# CMAKE_EXTRA_FLAGS += -DMSGPACK_USE_STATIC=OFF
