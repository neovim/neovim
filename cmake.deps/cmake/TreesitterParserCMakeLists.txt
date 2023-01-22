cmake_minimum_required(VERSION 3.10)
project(parser C)

set(CMAKE_C_STANDARD 99)
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
