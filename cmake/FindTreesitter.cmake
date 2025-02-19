find_path2(TREESITTER_INCLUDE_DIR tree_sitter/api.h)
find_library2(TREESITTER_LIBRARY NAMES tree-sitter)
find_package_handle_standard_args(Treesitter DEFAULT_MSG
  TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)
mark_as_advanced(TREESITTER_LIBRARY TREESITTER_INCLUDE_DIR)

add_library(treesitter INTERFACE)
target_include_directories(treesitter SYSTEM BEFORE INTERFACE ${TREESITTER_INCLUDE_DIR})
target_link_libraries(treesitter INTERFACE ${TREESITTER_LIBRARY})
