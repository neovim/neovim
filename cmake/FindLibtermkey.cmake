find_path2(LIBTERMKEY_INCLUDE_DIR termkey.h)
find_library2(LIBTERMKEY_LIBRARY NAMES termkey)
find_package_handle_standard_args(Libtermkey DEFAULT_MSG
  LIBTERMKEY_LIBRARY LIBTERMKEY_INCLUDE_DIR)
mark_as_advanced(LIBTERMKEY_INCLUDE_DIR LIBTERMKEY_LIBRARY)

add_library(libtermkey INTERFACE)
target_include_directories(libtermkey SYSTEM BEFORE INTERFACE ${LIBTERMKEY_INCLUDE_DIR})
target_link_libraries(libtermkey INTERFACE ${LIBTERMKEY_LIBRARY})
