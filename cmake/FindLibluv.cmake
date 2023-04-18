find_path(LIBLUV_INCLUDE_DIR luv/luv.h)
find_library(LIBLUV_LIBRARY NAMES luv_a luv libluv_a)

# Ubuntu-specific workaround to find system paths
function(ubuntu)
  set(CMAKE_FIND_LIBRARY_PREFIXES "")
  find_path(LIBLUV_INCLUDE_DIR luv/luv.h PATH_SUFFIXES lua5.1)
  find_library(LIBLUV_LIBRARY NAMES luv PATH_SUFFIXES lua/5.1)
endfunction()
ubuntu()

find_package_handle_standard_args(Libluv DEFAULT_MSG
  LIBLUV_LIBRARY LIBLUV_INCLUDE_DIR)
mark_as_advanced(LIBLUV_INCLUDE_DIR LIBLUV_LIBRARY)
