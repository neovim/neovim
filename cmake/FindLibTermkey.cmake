find_path(LIBTERMKEY_INCLUDE_DIR termkey.h)

list(APPEND LIBTERMKEY_NAMES termkey)

find_library(LIBTERMKEY_LIBRARY NAMES ${LIBTERMKEY_NAMES})

set(LIBTERMKEY_LIBRARIES ${LIBTERMKEY_LIBRARY})
set(LIBTERMKEY_INCLUDE_DIRS ${LIBTERMKEY_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LIBTERMKEY_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LibTermkey DEFAULT_MSG
  LIBTERMKEY_LIBRARY LIBTERMKEY_INCLUDE_DIR)

mark_as_advanced(LIBTERMKEY_INCLUDE_DIR LIBTERMKEY_LIBRARY)
