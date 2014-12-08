include(CheckLibraryExists)

option(USE_GCOV "Enable gcov support" OFF)

if(NOT CLANG_TSAN)
# GCOV and TSAN results in false data race reports
if(USE_GCOV)
  message(STATUS "Enabling gcov support")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} --coverage")
endif()
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
set(GENERATED_EVENTS_ENUM ${GENERATED_INCLUDES_DIR}/auevents_enum.generated.h)
set(GENERATED_EVENTS_NAMES_MAP ${GENERATED_DIR}/auevents_name_map.generated.h)
set(GENERATED_OPTIONS ${GENERATED_DIR}/options.generated.h)
set(EX_CMDS_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genex_cmds.lua)
set(EVENTS_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/gen_events.lua)
set(OPTIONS_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genoptions.lua)
set(EVENTS_LIST_FILE ${PROJECT_SOURCE_DIR}/src/nvim/auevents.lua)
set(EX_CMDS_DEFS_FILE ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua)
set(OPTIONS_LIST_FILE ${PROJECT_SOURCE_DIR}/src/nvim/options.lua)
set(UNICODE_TABLES_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genunicodetables.lua)
set(UNICODE_DIR ${PROJECT_SOURCE_DIR}/unicode)
set(UNICODEDATA_FILE ${UNICODE_DIR}/UnicodeData.txt)
set(CASEFOLDING_FILE ${UNICODE_DIR}/CaseFolding.txt)
set(EASTASIANWIDTH_FILE ${UNICODE_DIR}/EastAsianWidth.txt)
set(GENERATED_UNICODE_TABLES ${GENERATED_DIR}/unicode_tables.generated.h)

include_directories(${GENERATED_DIR})
include_directories(${GENERATED_INCLUDES_DIR})

file(MAKE_DIRECTORY ${GENERATED_DIR})
file(MAKE_DIRECTORY ${GENERATED_DIR}/os)
file(MAKE_DIRECTORY ${GENERATED_DIR}/api)
file(MAKE_DIRECTORY ${GENERATED_DIR}/api/private)
file(MAKE_DIRECTORY ${GENERATED_DIR}/msgpack_rpc)
file(MAKE_DIRECTORY ${GENERATED_DIR}/tui)
file(MAKE_DIRECTORY ${GENERATED_DIR}/event)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR})
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/os)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/api)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/api/private)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/msgpack_rpc)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/tui)
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/event)

file(GLOB NEOVIM_SOURCES *.c os/*.c api/*.c api/private/*.c msgpack_rpc/*.c
  tui/*.c event/*.c)
file(GLOB_RECURSE NEOVIM_HEADERS *.h)
file(GLOB UNIT_TEST_FIXTURES ${PROJECT_SOURCE_DIR}/test/unit/fixtures/*.c)

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
  fileio.c
  getchar.c
  mbyte.c
  memline.c
  message.c
  misc1.c
  ops.c
  path.c
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

if(NOT MSVC)
  set_source_files_properties(
    ${CONV_SOURCES} PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wno-conversion")
endif()

if(DEFINED MIN_LOG_LEVEL)
  add_definitions(-DMIN_LOG_LEVEL=${MIN_LOG_LEVEL})
endif()

get_directory_property(gen_cdefs COMPILE_DEFINITIONS)
foreach(gen_cdef ${gen_cdefs} DO_NOT_DEFINE_EMPTY_ATTRIBUTES)
  if(NOT "${gen_cdef}" MATCHES "INCLUDE_GENERATED_DECLARATIONS")
    list(APPEND gen_cflags "-D${gen_cdef}")
  endif()
endforeach()
if(CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN)
  list(APPEND gen_cflags "-DEXITFREE")
endif()

get_directory_property(gen_includes INCLUDE_DIRECTORIES)
foreach(gen_include ${gen_includes})
  list(APPEND gen_cflags "-I${gen_include}")
endforeach()
string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
separate_arguments(C_FLAGS_ARRAY UNIX_COMMAND ${CMAKE_C_FLAGS})
separate_arguments(C_FLAGS_${build_type}_ARRAY UNIX_COMMAND ${CMAKE_C_FLAGS_${build_type}})
set(gen_cflags ${gen_cflags} ${C_FLAGS_${build_type}_ARRAY} ${C_FLAGS_ARRAY})

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

  if(MSVC)
    set(PREPROC_OUTPUT /P /Fi${gf3})
  else()
    set(PREPROC_OUTPUT -E -o ${gf3})
  endif()

  add_custom_command(
    OUTPUT "${gf1}" "${gf2}"
    COMMAND ${CMAKE_C_COMPILER} ${sfile} ${PREPROC_OUTPUT} ${gen_cflags} ${C_FLAGS_ARRAY}
    COMMAND "${LUA_PRG}" "${HEADER_GENERATOR}" "${sfile}" "${gf1}" "${gf2}" "${gf3}"
    DEPENDS "${HEADER_GENERATOR}" "${sfile}"
    )
  list(APPEND NEOVIM_GENERATED_SOURCES "${gf1}")
  list(APPEND NEOVIM_GENERATED_SOURCES "${gf2}")
  if(${d} MATCHES "^api$" AND NOT ${f} MATCHES "^api/helpers.c$")
    list(APPEND API_HEADERS ${gf2})
  endif()
endforeach()

add_custom_command(OUTPUT ${GENERATED_UNICODE_TABLES}
  COMMAND ${LUA_PRG} ${UNICODE_TABLES_GENERATOR}
                     ${UNICODEDATA_FILE}
                     ${CASEFOLDING_FILE}
                     ${EASTASIANWIDTH_FILE}
                     ${GENERATED_UNICODE_TABLES}
  DEPENDS
    ${UNICODE_TABLES_GENERATOR}
    ${UNICODEDATA_FILE}
    ${CASEFOLDING_FILE}
    ${EASTASIANWIDTH_FILE}
)

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
  "${GENERATED_EVENTS_ENUM}"
  "${GENERATED_EVENTS_NAMES_MAP}"
  "${GENERATED_OPTIONS}"
  "${GENERATED_UNICODE_TABLES}"
)

add_custom_command(OUTPUT ${GENERATED_EX_CMDS_ENUM} ${GENERATED_EX_CMDS_DEFS}
  COMMAND ${LUA_PRG} ${EX_CMDS_GENERATOR}
      ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_INCLUDES_DIR} ${GENERATED_DIR}
  DEPENDS ${EX_CMDS_GENERATOR} ${EX_CMDS_DEFS_FILE}
)

add_custom_command(OUTPUT ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  COMMAND ${LUA_PRG} ${EVENTS_GENERATOR}
      ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  DEPENDS ${EVENTS_GENERATOR} ${EVENTS_LIST_FILE}
)

add_custom_command(OUTPUT ${GENERATED_OPTIONS}
  COMMAND ${LUA_PRG} ${OPTIONS_GENERATOR}
                     ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_OPTIONS}
  DEPENDS ${OPTIONS_GENERATOR} ${OPTIONS_LIST_FILE}
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
  ${LIBVTERM_LIBRARIES}
  ${LIBTERMKEY_LIBRARIES}
  ${UNIBILIUM_LIBRARIES}
  ${CMAKE_THREAD_LIBS_INIT}
)

if(UNIX)
  list(APPEND NVIM_LINK_LIBRARIES
    m
    util
  )
endif()

set(NVIM_EXEC_LINK_LIBRARIES ${NVIM_LINK_LIBRARIES})

# Don't use jemalloc in the unit test library.
if(JEMALLOC_FOUND)
  list(APPEND NVIM_EXEC_LINK_LIBRARIES ${JEMALLOC_LIBRARIES})
endif()

add_executable(nvim ${NEOVIM_GENERATED_SOURCES} ${NEOVIM_SOURCES}
  ${NEOVIM_HEADERS})
target_link_libraries(nvim ${NVIM_EXEC_LINK_LIBRARIES})
install_helper(TARGETS nvim)

if(CLANG_ASAN_UBSAN)
  message(STATUS "Enabling Clang address sanitizer and undefined behavior sanitizer for nvim.")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-DEXITFREE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-fno-sanitize-recover -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize=address -fsanitize=undefined -fsanitize-blacklist=${PROJECT_SOURCE_DIR}/.asan-blacklist")
  set_property(TARGET nvim APPEND_STRING PROPERTY LINK_FLAGS "-fsanitize=address -fsanitize=undefined ")
elseif(CLANG_MSAN)
  message(STATUS "Enabling Clang memory sanitizer for nvim.")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-DEXITFREE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-fsanitize=memory -fsanitize-memory-track-origins -fno-omit-frame-pointer -fno-optimize-sibling-calls ")
  set_property(TARGET nvim APPEND_STRING PROPERTY LINK_FLAGS "-fsanitize=memory -fsanitize-memory-track-origins ")
elseif(CLANG_TSAN)
  message(STATUS "Enabling Clang thread sanitizer for nvim.")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-DEXITFREE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-fsanitize=thread ")
  set_property(TARGET nvim APPEND_STRING PROPERTY LINK_FLAGS "-fsanitize=thread ")
endif()

add_library(libnvim STATIC EXCLUDE_FROM_ALL ${NEOVIM_GENERATED_SOURCES}
  ${NEOVIM_SOURCES} ${NEOVIM_HEADERS})
target_link_libraries(libnvim ${NVIM_LINK_LIBRARIES})
set_target_properties(libnvim PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  OUTPUT_NAME nvim)
set_property(TARGET libnvim APPEND_STRING PROPERTY COMPILE_FLAGS " -DMAKE_LIB ")

add_library(nvim-test MODULE EXCLUDE_FROM_ALL ${NEOVIM_GENERATED_SOURCES}
    ${NEOVIM_SOURCES} ${UNIT_TEST_FIXTURES} ${NEOVIM_HEADERS})
target_link_libraries(nvim-test ${NVIM_LINK_LIBRARIES})
set_property(TARGET nvim-test APPEND_STRING PROPERTY COMPILE_FLAGS -DUNIT_TESTING)

add_subdirectory(po)
