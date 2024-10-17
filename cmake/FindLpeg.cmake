find_library2(LPEG_LIBRARY NAMES lpeg_a lpeg liblpeg_a lpeg.so lpeg${CMAKE_SHARED_LIBRARY_SUFFIX} PATH_SUFFIXES lua/5.1)
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND LPEG_LIBRARY MATCHES ".so$")
  execute_process(
    COMMAND otool -hv "${LPEG_LIBRARY}"
    OUTPUT_VARIABLE LPEG_HEADER
    )
  if(LPEG_HEADER MATCHES ".* BUNDLE .*")
    message(FATAL_ERROR "lpeg library found at ${LPEG_LIBRARY} but built as a bundle rather than a dylib, please rebuild with `-dynamiclib` rather than `-bundle`")
  endif()
endif()

find_package_handle_standard_args(Lpeg DEFAULT_MSG LPEG_LIBRARY)
mark_as_advanced(LPEG_LIBRARY)

# Workaround: use an imported library to prevent cmake from modifying library
# link path. See #23395.
add_library(lpeg UNKNOWN IMPORTED)
set_target_properties(lpeg PROPERTIES IMPORTED_LOCATION ${LPEG_LIBRARY})
