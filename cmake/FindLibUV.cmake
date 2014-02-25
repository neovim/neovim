# - Try to find libuv
# Once done, this will define
#
#  LibUV_FOUND - system has libuv
#  LibUV_INCLUDE_DIRS - the libuv include directories
#  LibUV_LIBRARIES - link these to use libuv

include(LibFindMacros)

# Include dir
find_path(LibUV_INCLUDE_DIR
    NAMES uv.h
)

# The library itself. Note that we prefer the static version.
find_library(LibUV_LIBRARY
    NAMES libuv.a uv
)

# Set the include dir variables and the libraries and let libfind_process do the rest.
# NOTE: Singular variables for this library, plural for libraries this this lib depends on.
set(LibUV_PROCESS_INCLUDES LibUV_INCLUDE_DIR)
set(LibUV_PROCESS_LIBS LibUV_LIBRARY)
libfind_process(LibUV)
