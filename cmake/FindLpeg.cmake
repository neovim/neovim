find_library(LPEG_LIBRARY NAMES lpeg_a lpeg liblpeg_a lpeg${CMAKE_SHARED_LIBRARY_SUFFIX} PATH_SUFFIXES lua/5.1)

find_package_handle_standard_args(Lpeg DEFAULT_MSG LPEG_LIBRARY)
mark_as_advanced(LPEG_LIBRARY)

# Workaround: use an imported library to prevent cmake from modifying library
# link path. See #23395.
add_library(lpeg UNKNOWN IMPORTED)
set_target_properties(lpeg PROPERTIES IMPORTED_LOCATION ${LPEG_LIBRARY})
