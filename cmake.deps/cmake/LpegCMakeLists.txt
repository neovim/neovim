cmake_minimum_required(VERSION 3.16)
project (lpeg C)

include(GNUInstallDirs)

file(GLOB LPEG_SOURCES ${CMAKE_SOURCE_DIR}/*.c)
add_library(lpeg ${LPEG_SOURCES})

target_compile_options(lpeg PRIVATE -w)

install(TARGETS lpeg ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

# vim: set ft=cmake:
