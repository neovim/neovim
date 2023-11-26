# TODO(dundargoc): FindIconv is shipped by default on cmake version 3.11+. This
# file can be removed once we decide to upgrade minimum cmake version.

find_path2(ICONV_INCLUDE_DIR NAMES iconv.h)
find_library2(ICONV_LIBRARY NAMES iconv libiconv)
find_package_handle_standard_args(Iconv DEFAULT_MSG
  ICONV_INCLUDE_DIR)
mark_as_advanced(ICONV_INCLUDE_DIR ICONV_LIBRARY)

add_library(iconv INTERFACE)
target_include_directories(iconv SYSTEM BEFORE INTERFACE ${ICONV_INCLUDE_DIR})
if(ICONV_LIBRARY)
  target_link_libraries(iconv INTERFACE ${ICONV_LIBRARY})
endif()
