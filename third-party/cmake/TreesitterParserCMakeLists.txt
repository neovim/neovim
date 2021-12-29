cmake_minimum_required(VERSION 2.8.12)
# some parsers have c++ scanner, problem?
project(parser C) # CXX

add_library(parser
  MODULE
  src/parser.c
)
set_target_properties(
  parser
  PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME ${PARSERLANG}
    PREFIX ""
)

include_directories(src)

install(TARGETS parser LIBRARY DESTINATION lib/nvim/parser)
