# - Try to find tree-sitter
# Once done, this will define
#
#  TREESITTER_FOUND        - system has tree-sitter
#  TREESITTER_INCLUDE_DIRS - the tree-sitter include directories
#  TREESITTER_LIBRARIES    - link these to use tree-sitter

include(LibFindMacros)

libfind_pkg_detect(TREESITTER tree-sitter FIND_PATH tree_sitter/api.h FIND_LIBRARY tree-sitter)
libfind_process(TREESITTER)
