cmake_minimum_required(VERSION 3.13)
project(libvterm C)

add_compile_options(-w)

include(GNUInstallDirs)

set(DECDRAWING [[
 static const struct StaticTableEncoding encoding_DECdrawing = {
   { .decode = &decode_table },
   {
     [0x60] = 0x25C6,
     [0x61] = 0x2592,
     [0x62] = 0x2409,
     [0x63] = 0x240C,
     [0x64] = 0x240D,
     [0x65] = 0x240A,
     [0x66] = 0x00B0,
     [0x67] = 0x00B1,
     [0x68] = 0x2424,
     [0x69] = 0x240B,
     [0x6a] = 0x2518,
     [0x6b] = 0x2510,
     [0x6c] = 0x250C,
     [0x6d] = 0x2514,
     [0x6e] = 0x253C,
     [0x6f] = 0x23BA,
     [0x70] = 0x23BB,
     [0x71] = 0x2500,
     [0x72] = 0x23BC,
     [0x73] = 0x23BD,
     [0x74] = 0x251C,
     [0x75] = 0x2524,
     [0x76] = 0x2534,
     [0x77] = 0x252C,
     [0x78] = 0x2502,
     [0x79] = 0x2A7D,
     [0x7a] = 0x2A7E,
     [0x7b] = 0x03C0,
     [0x7c] = 0x2260,
     [0x7d] = 0x00A3,
     [0x7e] = 0x00B7,
   }
 };
]]
)

set(UK [[
 static const struct StaticTableEncoding encoding_uk = {
   { .decode = &decode_table },
   {
     [0x23] = 0x00a3,
   }
 };
]]
)

file(WRITE src/encoding/DECdrawing.inc "${DECDRAWING}")
file(WRITE src/encoding/uk.inc "${UK}")

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
