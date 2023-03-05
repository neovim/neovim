find_path(LIBLUV_INCLUDE_DIR luv/luv.h)
find_library(LIBLUV_LIBRARY NAMES luv_a luv libluv_a luv.so)
find_package_handle_standard_args(Libluv DEFAULT_MSG
  LIBLUV_LIBRARY LIBLUV_INCLUDE_DIR)
mark_as_advanced(LIBLUV_INCLUDE_DIR LIBLUV_LIBRARY)
