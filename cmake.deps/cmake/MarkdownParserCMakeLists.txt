cmake_minimum_required(VERSION 3.16)
project(${PARSERLANG} C)

add_compile_options(-w)

add_library(markdown MODULE
tree-sitter-markdown/src/parser.c
tree-sitter-markdown/src/scanner.c)
target_include_directories(markdown
  PRIVATE
  tree-sitter-markdown/src)

add_library(markdown_inline MODULE
tree-sitter-markdown-inline/src/parser.c
tree-sitter-markdown-inline/src/scanner.c)
target_include_directories(markdown_inline
  PRIVATE
  tree-sitter-markdown-inline/src)

set_target_properties(
  markdown markdown_inline
  PROPERTIES
    PREFIX ""
)

install(TARGETS markdown markdown_inline LIBRARY DESTINATION lib/nvim/parser)

# vim: set ft=cmake:
