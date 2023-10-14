cmake_minimum_required(VERSION 3.13)
# Can be removed once minimum version is at least 3.15
if(POLICY CMP0092)
  cmake_policy(SET CMP0092 NEW)
endif()
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
