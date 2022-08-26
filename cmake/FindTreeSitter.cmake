# - Try to find tree-sitter
# Once done, this will define
#
#  TreeSitter_FOUND        - system has tree-sitter
#  TreeSitter_INCLUDE_DIRS - the tree-sitter include directories
#  TreeSitter_LIBRARIES    - link these to use tree-sitter

include(LibFindMacros)

libfind_pkg_detect(TreeSitter tree-sitter FIND_PATH tree_sitter/api.h FIND_LIBRARY tree-sitter)
libfind_process(TreeSitter)
