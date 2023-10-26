cmake_minimum_required(VERSION 3.10)
project(libtermkey C)

if(EXISTS ${PROJECT_SOURCE_DIR}/termkey.h.in)
  file(STRINGS Makefile TERMKEY_VERSION_MAJOR REGEX "VERSION_MAJOR")
  string(REGEX MATCH "[0-9]+" TERMKEY_VERSION_MAJOR ${TERMKEY_VERSION_MAJOR})

  file(STRINGS Makefile TERMKEY_VERSION_MINOR REGEX "VERSION_MINOR")
  string(REGEX MATCH "[0-9]+" TERMKEY_VERSION_MINOR ${TERMKEY_VERSION_MINOR})

  file(READ termkey.h.in TERMKEY_TEXT)
  string(REPLACE "@@VERSION_MAJOR@@" "${TERMKEY_VERSION_MAJOR}" TERMKEY_TEXT "${TERMKEY_TEXT}")
  string(REPLACE "@@VERSION_MINOR@@" "${TERMKEY_VERSION_MINOR}" TERMKEY_TEXT "${TERMKEY_TEXT}")
  file(WRITE termkey.h "${TERMKEY_TEXT}")
endif()

add_library(termkey termkey.c driver-csi.c driver-ti.c)

target_compile_definitions(termkey PRIVATE _CRT_SECURE_NO_WARNINGS HAVE_UNIBILIUM)
target_include_directories(termkey PRIVATE SYSTEM ${UNIBILIUM_INCLUDE_DIRS})

set_target_properties(termkey PROPERTIES
  PUBLIC_HEADER ${PROJECT_SOURCE_DIR}/termkey.h)
target_link_libraries(termkey PRIVATE ${UNIBILIUM_LIBRARIES})

include(GNUInstallDirs)
install(TARGETS termkey
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# vim: set ft=cmake:
