# Numstore: the storage library that holds buffer text (see ARCHITECTURE.md).
#
# The patch renames numstore's stream_init() to ns_stream_init(): the old
# name collides with stream_init() in src/nvim/event/stream.c when both are
# linked into nvim. Drop the patch when the rename is upstream.
#
# Always a Release build: only that defines NLOG, which stops numstore from
# printing its log on the terminal.
get_externalproject_options(numstore ${DEPS_IGNORE_SHA})
ExternalProject_Add(numstore
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/numstore
  PATCH_COMMAND patch -p1 -N -i ${CMAKE_CURRENT_SOURCE_DIR}/cmake/NumstoreNsStreamInit.patch
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} -D CMAKE_BUILD_TYPE=Release -D NUMSTORE_DOCS=OFF
  ${EXTERNALPROJECT_OPTIONS})
