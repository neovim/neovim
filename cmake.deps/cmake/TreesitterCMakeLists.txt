cmake_minimum_required(VERSION 3.13)
# Can be removed once minimum version is at least 3.15
if(POLICY CMP0092)
  cmake_policy(SET CMP0092 NEW)
endif()
project(treesitter C)

add_compile_options(-w)

add_library(tree-sitter lib/src/lib.c)
target_include_directories(tree-sitter
  PRIVATE lib/src lib/include)

install(FILES
  lib/include/tree_sitter/api.h
  DESTINATION include/tree_sitter)

include(GNUInstallDirs)
install(TARGETS tree-sitter DESTINATION ${CMAKE_INSTALL_LIBDIR})

# vim: set ft=cmake:
