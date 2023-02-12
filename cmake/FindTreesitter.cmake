find_path(TREESITTER_INCLUDE_DIR tree_sitter/api.h)
find_library(TREESITTER_LIBRARY NAMES tree-sitter)
find_package_handle_standard_args(Treesitter DEFAULT_MSG
  TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)
mark_as_advanced(TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)

add_library(treesitter INTERFACE)
target_include_directories(treesitter SYSTEM BEFORE INTERFACE ${TREESITTER_INCLUDE_DIR})
target_link_libraries(treesitter INTERFACE ${TREESITTER_LIBRARY})

list(APPEND CMAKE_REQUIRED_INCLUDES "${TREESITTER_INCLUDE_DIR}")
list(APPEND CMAKE_REQUIRED_LIBRARIES "${TREESITTER_LIBRARY}")
check_c_source_compiles("
#include <tree_sitter/api.h>
int
main(void)
{
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_set_match_limit(cursor, 32);
  return 0;
}
" TS_HAS_SET_MATCH_LIMIT)
if(TS_HAS_SET_MATCH_LIMIT)
  target_compile_definitions(treesitter INTERFACE NVIM_TS_HAS_SET_MATCH_LIMIT)
endif()
check_c_source_compiles("
#include <stdlib.h>
#include <tree_sitter/api.h>
int
main(void)
{
  ts_set_allocator(malloc, calloc, realloc, free);
  return 0;
}
" TS_HAS_SET_ALLOCATOR)
if(TS_HAS_SET_ALLOCATOR)
  target_compile_definitions(treesitter INTERFACE NVIM_TS_HAS_SET_ALLOCATOR)
endif()
list(REMOVE_ITEM CMAKE_REQUIRED_INCLUDES "${TREESITTER_INCLUDE_DIR}")
list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES "${TREESITTER_LIBRARY}")
