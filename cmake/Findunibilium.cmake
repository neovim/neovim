find_path(UNIBILIUM_INCLUDE_DIR unibilium.h)
find_library(UNIBILIUM_LIBRARY unibilium)

find_package_handle_standard_args(unibilium
  REQUIRED_VARS UNIBILIUM_INCLUDE_DIR UNIBILIUM_LIBRARY)

add_library(unibilium INTERFACE)
target_include_directories(unibilium SYSTEM BEFORE INTERFACE ${UNIBILIUM_INCLUDE_DIR})
target_link_libraries(unibilium INTERFACE ${UNIBILIUM_LIBRARY})

list(APPEND CMAKE_REQUIRED_INCLUDES "${UNIBILIUM_INCLUDE_DIR}")
list(APPEND CMAKE_REQUIRED_LIBRARIES "${UNIBILIUM_LIBRARY}")
check_c_source_compiles("
#include <unibilium.h>

int
main(void)
{
  unibi_str_from_var(unibi_var_from_str(\"\"));
  return unibi_num_from_var(unibi_var_from_num(0));
}
" UNIBI_HAS_VAR_FROM)
list(REMOVE_ITEM CMAKE_REQUIRED_INCLUDES "${UNIBILIUM_INCLUDE_DIR}")
list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES "${UNIBILIUM_LIBRARY}")
if(UNIBI_HAS_VAR_FROM)
  target_compile_definitions(unibilium INTERFACE NVIM_UNIBI_HAS_VAR_FROM)
endif()

mark_as_advanced(UNIBILIUM_INCLUDE_DIR UNIBILIUM_LIBRARY)
