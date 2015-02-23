include(CheckLibraryExists)

option(SANITIZE "Enable Clang sanitizers for nvim binary" OFF)
if(SANITIZE AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
  message(WARNING "SANITIZE is only supported for Clang ... disabling")
  set(SANITIZE OFF)
endif()

set(GENERATED_DIR ${PROJECT_BINARY_DIR}/src/nvim/auto)
set(DISPATCH_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/msgpack-gen.lua)
file(GLOB API_HEADERS api/*.h)
file(GLOB MSGPACK_RPC_HEADERS msgpack_rpc/*.h)
set(MSGPACK_DISPATCH ${GENERATED_DIR}/msgpack_dispatch.c)
set(HEADER_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/gendeclarations.lua)
set(GENERATED_INCLUDES_DIR ${PROJECT_BINARY_DIR}/include)
set(GENERATED_EX_CMDS_ENUM ${GENERATED_INCLUDES_DIR}/ex_cmds_enum.generated.h)
set(GENERATED_EX_CMDS_DEFS ${GENERATED_DIR}/ex_cmds_defs.generated.h)
set(EX_CMDS_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genex_cmds.lua)
set(EX_CMDS_DEFS_FILE ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua)

include_directories(${GENERATED_DIR})
include_directories(${GENERATED_INCLUDES_DIR})

file(MAKE_DIRECTORY ${GENERATED_DIR})
file(MAKE_DIRECTORY ${GENERATED_DIR}/os)
file(MAKE_DIRECTORY ${GENERATED_DIR}/api)
file(MAKE_DIRECTORY ${GENERATED_DIR}/api/private)
file(MAKE_DIRECTORY ${GENERATED_DIR}/msgpack_rpc)
file(MAKE_DIRECTORY ${GENERATED_DIR}/tui)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR})
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/os)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/api)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/api/private)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/msgpack_rpc)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/tui)

file(GLOB NEOVIM_SOURCES *.c os/*.c api/*.c api/private/*.c msgpack_rpc/*.c
  tui/*.c)
file(GLOB_RECURSE NEOVIM_HEADERS *.h)

foreach(sfile ${NEOVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NEOVIM_SOURCES ${to_remove})

# Handle legacy files that don't yet pass -Wconversion.
set(CONV_SOURCES
  buffer.c
  charset.c
  diff.c
  edit.c
  eval.c
  ex_cmds2.c
  ex_cmds.c
  ex_docmd.c
  ex_getln.c
  farsi.c
  fileio.c
  fold.c
  getchar.c
  if_cscope.c
  mbyte.c
  memline.c
  menu.c
  message.c
  misc1.c
  move.c
  normal.c
  ops.c
  path.c
  popupmnu.c
  quickfix.c
  regexp.c
  screen.c
  search.c
  spell.c
  syntax.c
  tag.c
  window.c)

foreach(sfile ${CONV_SOURCES})
  if(NOT EXISTS "${PROJECT_SOURCE_DIR}/src/nvim/${sfile}")
    message(FATAL_ERROR "${sfile} doesn't exist (it was added to CONV_SOURCES)")
  endif()
endforeach()

set_source_files_properties(
  ${CONV_SOURCES} PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wno-conversion")

get_directory_property(gen_cdefs COMPILE_DEFINITIONS)
foreach(gen_cdef ${gen_cdefs} DO_NOT_DEFINE_EMPTY_ATTRIBUTES)
  if(NOT "${gen_cdef}" MATCHES "INCLUDE_GENERATED_DECLARATIONS")
    list(APPEND gen_cflags "-D${gen_cdef}")
  endif()
endforeach()
if (SANITIZE)
  list(APPEND gen_cflags "-DEXITFREE")
endif()

get_directory_property(gen_includes INCLUDE_DIRECTORIES)
foreach(gen_include ${gen_includes})
  list(APPEND gen_cflags "-I${gen_include}")
endforeach()
string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
set(gen_cflags "${gen_cflags} ${CMAKE_C_FLAGS_${build_type}} ${CMAKE_C_FLAGS}")

foreach(sfile ${NEOVIM_SOURCES}
              "${PROJECT_SOURCE_DIR}/src/nvim/regexp_nfa.c")
  get_filename_component(full_d ${sfile} PATH)
  file(RELATIVE_PATH d "${PROJECT_SOURCE_DIR}/src/nvim" "${full_d}")
  get_filename_component(f ${sfile} NAME)
  get_filename_component(r ${sfile} NAME_WE)
  if(NOT ${d} EQUAL ".")
    set(f "${d}/${f}")
    set(r "${d}/${r}")
  endif()
  set(gf1 "${GENERATED_DIR}/${r}.c.generated.h")
  set(gf2 "${GENERATED_INCLUDES_DIR}/${r}.h.generated.h")
  set(gf3 "${GENERATED_DIR}/${r}.i")
  separate_arguments(C_FLAGS_ARRAY UNIX_COMMAND ${CMAKE_C_FLAGS})
  add_custom_command(
    OUTPUT "${gf1}" "${gf2}"
    COMMAND ${CMAKE_C_COMPILER} ${sfile} -o ${gf3} ${gen_cflags} -E ${C_FLAGS_ARRAY}
    COMMAND "${LUA_PRG}" "${HEADER_GENERATOR}" "${sfile}" "${gf1}" "${gf2}" "${gf3}"
    DEPENDS "${HEADER_GENERATOR}" "${sfile}"
    )
  list(APPEND NEOVIM_GENERATED_SOURCES "${gf1}")
  list(APPEND NEOVIM_GENERATED_SOURCES "${gf2}")
  if(${d} MATCHES "^api$" AND NOT ${f} MATCHES "^api/helpers.c$")
    list(APPEND API_HEADERS ${gf2})
  endif()
endforeach()

add_custom_command(OUTPUT ${MSGPACK_DISPATCH}
  COMMAND ${LUA_PRG} ${DISPATCH_GENERATOR} ${API_HEADERS} ${MSGPACK_DISPATCH}
  DEPENDS
    ${API_HEADERS}
    ${MSGPACK_RPC_HEADERS}
    ${DISPATCH_GENERATOR}
)

list(APPEND NEOVIM_GENERATED_SOURCES
  "${PROJECT_BINARY_DIR}/config/auto/pathdef.c"
  "${MSGPACK_DISPATCH}"
  "${GENERATED_EX_CMDS_ENUM}"
  "${GENERATED_EX_CMDS_DEFS}"
)

add_custom_command(OUTPUT ${GENERATED_EX_CMDS_ENUM} ${GENERATED_EX_CMDS_DEFS}
  COMMAND ${LUA_PRG} ${EX_CMDS_GENERATOR}
      ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_INCLUDES_DIR} ${GENERATED_DIR}
  DEPENDS ${EX_CMDS_GENERATOR} ${EX_CMDS_DEFS_FILE}
)

# Our dependencies come first.

if (LibIntl_FOUND)
  list(APPEND NVIM_LINK_LIBRARIES ${LibIntl_LIBRARY})
endif()

if(Iconv_LIBRARIES)
  list(APPEND NVIM_LINK_LIBRARIES ${Iconv_LIBRARIES})
endif()

# Put these last on the link line, since multiple things may depend on them.
list(APPEND NVIM_LINK_LIBRARIES
    ${LIBUV_LIBRARIES}
    ${MSGPACK_LIBRARIES}
    ${LUAJIT_LIBRARIES}
    ${LIBTICKIT_LIBRARIES}
    ${LIBTERMKEY_LIBRARIES}
    ${LIBUNIBILIUM_LIBRARIES}
    m
    util
    ${CMAKE_THREAD_LIBS_INIT}
    )

add_executable(nvim ${NEOVIM_GENERATED_SOURCES} ${NEOVIM_SOURCES}
  ${NEOVIM_HEADERS})
target_link_libraries(nvim ${NVIM_LINK_LIBRARIES})
install_helper(TARGETS nvim)

if(SANITIZE)
  message(STATUS "Enabling Clang sanitizers for nvim")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-DEXITFREE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-fno-sanitize-recover -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize=address -fsanitize=undefined ")
  set_property(TARGET nvim APPEND_STRING PROPERTY LINK_FLAGS "-fsanitize=address -fsanitize=undefined ")
endif()

add_library(libnvim STATIC EXCLUDE_FROM_ALL ${NEOVIM_GENERATED_SOURCES}
  ${NEOVIM_SOURCES} ${NEOVIM_HEADERS})
target_link_libraries(libnvim ${NVIM_LINK_LIBRARIES})
set_target_properties(libnvim PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  OUTPUT_NAME nvim)
set_property(TARGET libnvim APPEND_STRING PROPERTY COMPILE_FLAGS " -DMAKE_LIB ")

add_library(nvim-test MODULE EXCLUDE_FROM_ALL ${NEOVIM_GENERATED_SOURCES}
    ${NEOVIM_SOURCES} ${NEOVIM_HEADERS})
target_link_libraries(nvim-test ${NVIM_LINK_LIBRARIES})

add_subdirectory(po)
