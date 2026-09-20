find_path2(GHOSTTY_INCLUDE_DIR ghostty/vt.h)
find_library2(GHOSTTY_LIBRARY ghostty-vt)

find_package_handle_standard_args(Ghostty REQUIRED_VARS GHOSTTY_INCLUDE_DIR GHOSTTY_LIBRARY)

add_library(ghostty INTERFACE)
target_include_directories(ghostty SYSTEM BEFORE INTERFACE ${GHOSTTY_INCLUDE_DIR})
target_link_libraries(ghostty INTERFACE ${GHOSTTY_LIBRARY})

mark_as_advanced(GHOSTTY_INCLUDE_DIR GHOSTTY_LIBRARY)
