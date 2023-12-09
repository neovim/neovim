find_path2(UNIBILIUM_INCLUDE_DIR unibilium.h)
find_library2(UNIBILIUM_LIBRARY unibilium)

find_package_handle_standard_args(Unibilium
  REQUIRED_VARS UNIBILIUM_INCLUDE_DIR UNIBILIUM_LIBRARY)

add_library(unibilium_lib INTERFACE)
target_include_directories(unibilium_lib SYSTEM BEFORE INTERFACE ${UNIBILIUM_INCLUDE_DIR})
target_link_libraries(unibilium_lib INTERFACE ${UNIBILIUM_LIBRARY})

mark_as_advanced(UNIBILIUM_INCLUDE_DIR UNIBILIUM_LIBRARY)
