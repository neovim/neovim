find_path2(TREESITTER_INCLUDE_DIR tree_sitter/api.h)
find_library2(TREESITTER_LIBRARY NAMES tree-sitter)
find_package_handle_standard_args(Treesitter DEFAULT_MSG
  TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)
mark_as_advanced(TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)

add_library(treesitter INTERFACE)
target_include_directories(treesitter SYSTEM BEFORE INTERFACE ${TREESITTER_INCLUDE_DIR})
target_link_libraries(treesitter INTERFACE ${TREESITTER_LIBRARY})

# TODO(lewis6991): remove when min TS version is 0.20.9
list(APPEND CMAKE_REQUIRED_INCLUDES "${TREESITTER_INCLUDE_DIR}")
list(APPEND CMAKE_REQUIRED_LIBRARIES "${TREESITTER_LIBRARY}")
check_c_source_compiles("
#include <tree_sitter/api.h>
int
main(void)
{
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_set_max_start_depth(cursor, 32);
  return 0;
}
" TS_HAS_SET_MAX_START_DEPTH)
list(REMOVE_ITEM CMAKE_REQUIRED_INCLUDES "${TREESITTER_INCLUDE_DIR}")
list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES "${TREESITTER_LIBRARY}")

if(TS_HAS_SET_MAX_START_DEPTH)
  target_compile_definitions(treesitter INTERFACE NVIM_TS_HAS_SET_MAX_START_DEPTH)
endif()
