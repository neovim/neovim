cmake_minimum_required(VERSION 3.13)
project(libvterm C)

add_compile_options(-w)

include(GNUInstallDirs)

include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_BINARY_DIR})

file(GLOB VTERM_SOURCES ${CMAKE_SOURCE_DIR}/src/*.c)
add_library(vterm ${VTERM_SOURCES})
install(TARGETS vterm ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

install(FILES include/vterm.h include/vterm_keycodes.h
  DESTINATION include)

if(NOT WIN32)
  file(GLOB BIN_SOURCES ${CMAKE_SOURCE_DIR}/bin/*.c)
  foreach(EXE_C ${BIN_SOURCES})
    get_filename_component(target_name ${EXE_C} NAME_WE)
    add_executable(${target_name} ${EXE_C})
    target_link_libraries(${target_name} vterm)
    install(TARGETS ${target_name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
  endforeach()
endif()

# vim: set ft=cmake:
