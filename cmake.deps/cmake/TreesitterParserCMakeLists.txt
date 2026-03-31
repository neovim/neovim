cmake_minimum_required(VERSION 3.16)
project(parser C)

add_compile_options(-w)

file(GLOB source_files src/*.c)

add_library(parser
  MODULE
  ${source_files}
)
set_target_properties(
  parser
  PROPERTIES
    OUTPUT_NAME ${PARSERLANG}
    PREFIX ""
)

include_directories(src)

install(TARGETS parser LIBRARY DESTINATION lib/nvim/parser)

# vim: set ft=cmake:
