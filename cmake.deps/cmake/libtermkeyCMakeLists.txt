cmake_minimum_required(VERSION 3.10)
project(libtermkey C)

add_definitions(-D _CRT_SECURE_NO_WARNINGS)
add_definitions(-DHAVE_UNIBILIUM)
if(NOT MSVC)
  add_compile_options(-std=c99)
endif()

include_directories(${PROJECT_BINARY_DIR}/t)
include_directories(SYSTEM ${UNIBILIUM_INCLUDE_DIRS})

add_library(termkey termkey.c driver-csi.c driver-ti.c)
set_target_properties(termkey PROPERTIES
  PUBLIC_HEADER ${PROJECT_SOURCE_DIR}/termkey.h)
target_link_libraries(termkey ${UNIBILIUM_LIBRARIES})

include(GNUInstallDirs)
install(TARGETS termkey
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# vim: set ft=cmake:
