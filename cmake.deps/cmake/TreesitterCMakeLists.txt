cmake_minimum_required(VERSION 3.10)
project(tree-sitter C)
set(CMAKE_C_STANDARD 99)
add_library(tree-sitter lib/src/lib.c)
target_include_directories(tree-sitter
  PRIVATE lib/src lib/include)

install(FILES
  lib/include/tree_sitter/api.h
  lib/include/tree_sitter/parser.h
  DESTINATION include/tree_sitter)

include(GNUInstallDirs)
install(TARGETS tree-sitter DESTINATION ${CMAKE_INSTALL_LIBDIR})

# vim: set ft=cmake:
