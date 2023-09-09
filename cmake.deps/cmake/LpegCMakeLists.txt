cmake_minimum_required(VERSION 3.10)
project (lpeg C)

include(GNUInstallDirs)

file(GLOB LPEG_SOURCES ${CMAKE_SOURCE_DIR}/*.c)
add_library(lpeg ${LPEG_SOURCES})

install(TARGETS lpeg ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

# vim: set ft=cmake:
