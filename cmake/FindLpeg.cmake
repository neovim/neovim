find_library(LPEG_LIBRARY NAMES lpeg_a lpeg liblpeg_a)

# Ubuntu-specific workaround to find system paths
function(ubuntu)
  set(CMAKE_FIND_LIBRARY_PREFIXES "")
  find_library(LPEG_LIBRARY NAMES lpeg PATH_SUFFIXES lua/5.1)
endfunction()
ubuntu()

find_package_handle_standard_args(Lpeg DEFAULT_MSG LPEG_LIBRARY)
mark_as_advanced(LPEG_LIBRARY)

add_library(lpeg INTERFACE)
target_link_libraries(lpeg INTERFACE ${LPEG_LIBRARY})
