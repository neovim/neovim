find_path(LIBLUV_INCLUDE_DIR luv/luv.h)

# Explicitly look for luv.so. #10407
list(APPEND LIBLUV_NAMES luv_a luv libluv_a luv${CMAKE_SHARED_LIBRARY_SUFFIX})

find_library(LIBLUV_LIBRARY NAMES ${LIBLUV_NAMES})

set(LIBLUV_LIBRARIES ${LIBLUV_LIBRARY})
set(LIBLUV_INCLUDE_DIRS ${LIBLUV_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBLUV_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibLUV DEFAULT_MSG
  LIBLUV_LIBRARY LIBLUV_INCLUDE_DIR)

mark_as_advanced(LIBLUV_INCLUDE_DIR LIBLUV_LIBRARY)
