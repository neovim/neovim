option(USE_GCOV "Enable gcov support" OFF)

if(NOT CLANG_TSAN)
# GCOV and TSAN results in false data race reports
if(USE_GCOV)
  message(STATUS "Enabling gcov support")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} --coverage")
  add_definitions(-DUSE_GCOV)
endif()
endif()

if(WIN32)
  # tell MinGW compiler to enable wmain
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -municode")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework CoreFoundation")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -framework CoreFoundation")
endif()

set(TOUCHES_DIR ${PROJECT_BINARY_DIR}/touches)
set(GENERATOR_DIR ${CMAKE_CURRENT_LIST_DIR}/generators)
set(GENERATED_DIR ${PROJECT_BINARY_DIR}/src/nvim/auto)
set(API_DISPATCH_GENERATOR ${GENERATOR_DIR}/gen_api_dispatch.lua)
set(API_UI_EVENTS_GENERATOR ${GENERATOR_DIR}/gen_api_ui_events.lua)
set(GENERATOR_C_GRAMMAR ${GENERATOR_DIR}/c_grammar.lua)
set(API_METADATA ${PROJECT_BINARY_DIR}/api_metadata.mpack)
set(FUNCS_DATA ${PROJECT_BINARY_DIR}/funcs_data.mpack)
set(MSGPACK_LUA_C_BINDINGS ${GENERATED_DIR}/msgpack_lua_c_bindings.generated.c)
set(HEADER_GENERATOR ${GENERATOR_DIR}/gen_declarations.lua)
set(GENERATED_INCLUDES_DIR ${PROJECT_BINARY_DIR}/include)
set(GENERATED_API_DISPATCH ${GENERATED_DIR}/api/private/dispatch_wrappers.generated.h)
set(GENERATED_FUNCS_METADATA ${GENERATED_DIR}/api/private/funcs_metadata.generated.h)
set(GENERATED_UI_EVENTS ${GENERATED_DIR}/ui_events.generated.h)
set(GENERATED_UI_EVENTS_CALL ${GENERATED_DIR}/ui_events_call.generated.h)
set(GENERATED_UI_EVENTS_REMOTE ${GENERATED_DIR}/ui_events_remote.generated.h)
set(GENERATED_UI_EVENTS_BRIDGE ${GENERATED_DIR}/ui_events_bridge.generated.h)
set(GENERATED_UI_EVENTS_METADATA ${GENERATED_DIR}/api/private/ui_events_metadata.generated.h)
set(GENERATED_EX_CMDS_ENUM ${GENERATED_INCLUDES_DIR}/ex_cmds_enum.generated.h)
set(GENERATED_EX_CMDS_DEFS ${GENERATED_DIR}/ex_cmds_defs.generated.h)
set(GENERATED_FUNCS ${GENERATED_DIR}/funcs.generated.h)
set(GENERATED_EVENTS_ENUM ${GENERATED_INCLUDES_DIR}/auevents_enum.generated.h)
set(GENERATED_EVENTS_NAMES_MAP ${GENERATED_DIR}/auevents_name_map.generated.h)
set(GENERATED_OPTIONS ${GENERATED_DIR}/options.generated.h)
set(EX_CMDS_GENERATOR ${GENERATOR_DIR}/gen_ex_cmds.lua)
set(FUNCS_GENERATOR ${GENERATOR_DIR}/gen_eval.lua)
set(EVENTS_GENERATOR ${GENERATOR_DIR}/gen_events.lua)
set(OPTIONS_GENERATOR ${GENERATOR_DIR}/gen_options.lua)
set(UNICODE_TABLES_GENERATOR ${GENERATOR_DIR}/gen_unicode_tables.lua)
set(UNICODE_DIR ${PROJECT_SOURCE_DIR}/unicode)
set(GENERATED_UNICODE_TABLES ${GENERATED_DIR}/unicode_tables.generated.h)
set(VIM_MODULE_FILE ${GENERATED_DIR}/lua/vim_module.generated.h)
set(VIM_MODULE_SOURCE ${PROJECT_SOURCE_DIR}/src/nvim/lua/vim.lua)
set(CHAR_BLOB_GENERATOR ${GENERATOR_DIR}/gen_char_blob.lua)
set(LINT_SUPPRESS_FILE ${PROJECT_BINARY_DIR}/errors.json)
set(LINT_SUPPRESS_URL_BASE "https://raw.githubusercontent.com/neovim/doc/gh-pages/reports/clint")
set(LINT_SUPPRESS_URL "${LINT_SUPPRESS_URL_BASE}/errors.json")
set(LINT_PRG ${PROJECT_SOURCE_DIR}/src/clint.py)
set(DOWNLOAD_SCRIPT ${PROJECT_SOURCE_DIR}/cmake/Download.cmake)
set(LINT_SUPPRESSES_ROOT ${PROJECT_BINARY_DIR}/errors)
set(LINT_SUPPRESSES_URL "${LINT_SUPPRESS_URL_BASE}/errors.tar.gz")
set(LINT_SUPPRESSES_ARCHIVE ${LINT_SUPPRESSES_ROOT}/errors.tar.gz)
set(LINT_SUPPRESSES_TOUCH_FILE "${TOUCHES_DIR}/unpacked-clint-errors-archive")
set(LINT_SUPPRESSES_INSTALL_SCRIPT "${PROJECT_SOURCE_DIR}/cmake/InstallClintErrors.cmake")

file(GLOB UNICODE_FILES ${UNICODE_DIR}/*.txt)
file(GLOB API_HEADERS api/*.h)
list(REMOVE_ITEM API_HEADERS ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h)
file(GLOB MSGPACK_RPC_HEADERS msgpack_rpc/*.h)

include_directories(${GENERATED_DIR})
include_directories(${CACHED_GENERATED_DIR})
include_directories(${GENERATED_INCLUDES_DIR})

file(MAKE_DIRECTORY ${TOUCHES_DIR})
file(MAKE_DIRECTORY ${GENERATED_DIR})
file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR})
file(MAKE_DIRECTORY ${LINT_SUPPRESSES_ROOT})
file(MAKE_DIRECTORY ${LINT_SUPPRESSES_ROOT}/src)

file(GLOB NVIM_SOURCES *.c)
file(GLOB NVIM_HEADERS *.h)
file(GLOB XDIFF_SOURCES xdiff/*.c)
file(GLOB XDIFF_HEADERS xdiff/*.h)

foreach(subdir
        os
        api
        api/private
        msgpack_rpc
        tui
        event
        eval
        lua
        viml
        viml/parser
       )
  if(${subdir} MATCHES "tui" AND NOT FEAT_TUI)
    continue()
  endif()

  file(MAKE_DIRECTORY ${GENERATED_DIR}/${subdir})
  file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/${subdir})
  file(GLOB sources ${subdir}/*.c)
  file(GLOB headers ${subdir}/*.h)
  list(APPEND NVIM_SOURCES ${sources})
  list(APPEND NVIM_HEADERS ${headers})
endforeach()

file(GLOB UNIT_TEST_FIXTURES ${PROJECT_SOURCE_DIR}/test/unit/fixtures/*.c)

# Sort file lists to ensure generated files are created in the same order from
# build to build.
list(SORT NVIM_SOURCES)
list(SORT NVIM_HEADERS)

list(APPEND LINT_NVIM_SOURCES ${NVIM_SOURCES} ${NVIM_HEADERS})

foreach(sfile ${NVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c)$")
    list(APPEND to_remove ${sfile})
  endif()
  if(WIN32 AND ${f} MATCHES "^(pty_process_unix.c)$")
    list(APPEND to_remove ${sfile})
  endif()
  if(NOT WIN32 AND ${f} MATCHES "^(pty_process_win.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NVIM_SOURCES ${to_remove})

# Legacy files that do not yet pass -Wconversion.
set(CONV_SOURCES
  diff.c
  edit.c
  eval.c
  ex_cmds.c
  ex_docmd.c
  ex_getln.c
  fileio.c
  mbyte.c
  memline.c
  message.c
  regexp.c
  screen.c
  search.c
  spell.c
  spellfile.c
  syntax.c
  tag.c
  window.c)
foreach(sfile ${CONV_SOURCES})
  if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/${sfile}")
    message(FATAL_ERROR "${sfile} doesn't exist (it was added to CONV_SOURCES)")
  endif()
endforeach()
# xdiff: inlined external project, we don't maintain it. #9306
list(APPEND CONV_SOURCES ${XDIFF_SOURCES})

if(NOT MSVC)
  set_source_files_properties(
    ${CONV_SOURCES} PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wno-conversion")
  # gperf generates ANSI-C with incorrect linkage, ignore it.
  check_c_compiler_flag(-Wstatic-in-inline HAS_WSTATIC_IN_INLINE)
  if(HAS_WSTATIC_IN_INLINE)
    set_source_files_properties(
      eval.c PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wno-static-in-inline -Wno-conversion")
  else()
    set_source_files_properties(
      eval.c PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wno-conversion")
  endif()
endif()

if(NOT "${MIN_LOG_LEVEL}" MATCHES "^$")
  add_definitions(-DMIN_LOG_LEVEL=${MIN_LOG_LEVEL})
endif()

get_directory_property(gen_cdefs COMPILE_DEFINITIONS)
foreach(gen_cdef ${gen_cdefs} DO_NOT_DEFINE_EMPTY_ATTRIBUTES)
  if(NOT ${gen_cdef} MATCHES "INCLUDE_GENERATED_DECLARATIONS")
    list(APPEND gen_cflags "-D${gen_cdef}")
  endif()
endforeach()
if(CLANG_ASAN_UBSAN OR CLANG_MSAN OR CLANG_TSAN)
  list(APPEND gen_cflags "-DEXITFREE")
endif()

get_directory_property(gen_includes INCLUDE_DIRECTORIES)
foreach(gen_include ${gen_includes} ${LUA_PREFERRED_INCLUDE_DIRS})
  list(APPEND gen_cflags "-I${gen_include}")
endforeach()
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND CMAKE_OSX_SYSROOT)
  list(APPEND gen_cflags "-isysroot")
  list(APPEND gen_cflags "${CMAKE_OSX_SYSROOT}")
endif()
string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
separate_arguments(C_FLAGS_ARRAY UNIX_COMMAND ${CMAKE_C_FLAGS})
separate_arguments(C_FLAGS_${build_type}_ARRAY UNIX_COMMAND ${CMAKE_C_FLAGS_${build_type}})
set(gen_cflags ${gen_cflags} ${C_FLAGS_${build_type}_ARRAY} ${C_FLAGS_ARRAY})

function(get_preproc_output varname iname)
  if(MSVC)
    set(${varname} /P /Fi${iname} PARENT_SCOPE)
  else()
    set(${varname} -E -o ${iname} PARENT_SCOPE)
  endif()
endfunction()

# NVIM_GENERATED_FOR_HEADERS: generated headers to be included in headers
# NVIM_GENERATED_FOR_SOURCES: generated headers to be included in sources
# NVIM_GENERATED_SOURCES: generated source files
# These lists must be mutually exclusive.
foreach(sfile ${NVIM_SOURCES}
              "${CMAKE_CURRENT_LIST_DIR}/regexp_nfa.c"
              ${GENERATED_API_DISPATCH}
              "${GENERATED_UI_EVENTS_CALL}"
              "${GENERATED_UI_EVENTS_REMOTE}"
              "${GENERATED_UI_EVENTS_BRIDGE}"
              )
  get_filename_component(full_d ${sfile} PATH)
  file(RELATIVE_PATH d "${CMAKE_CURRENT_LIST_DIR}" "${full_d}")
  if(${d} MATCHES "^[.][.]|auto/")
    file(RELATIVE_PATH d "${GENERATED_DIR}" "${full_d}")
  endif()
  get_filename_component(f ${sfile} NAME)
  get_filename_component(r ${sfile} NAME_WE)
  if(NOT ${d} EQUAL ".")
    set(f "${d}/${f}")
    set(r "${d}/${r}")
  endif()
  set(gf_c_h "${GENERATED_DIR}/${r}.c.generated.h")
  set(gf_h_h "${GENERATED_INCLUDES_DIR}/${r}.h.generated.h")
  set(gf_i "${GENERATED_DIR}/${r}.i")

  get_preproc_output(PREPROC_OUTPUT ${gf_i})

  add_custom_command(
    OUTPUT "${gf_c_h}" "${gf_h_h}"
    COMMAND ${CMAKE_C_COMPILER} ${sfile} ${PREPROC_OUTPUT} ${gen_cflags} ${C_FLAGS_ARRAY}
    COMMAND "${LUA_PRG}" "${HEADER_GENERATOR}" "${sfile}" "${gf_c_h}" "${gf_h_h}" "${gf_i}"
    DEPENDS "${HEADER_GENERATOR}" "${sfile}"
    )
  list(APPEND NVIM_GENERATED_FOR_SOURCES "${gf_c_h}")
  list(APPEND NVIM_GENERATED_FOR_HEADERS "${gf_h_h}")
  if(${d} MATCHES "^api$" AND NOT ${f} MATCHES "^api/helpers.c$")
    list(APPEND API_HEADERS ${gf_h_h})
  endif()
endforeach()

add_custom_command(OUTPUT ${GENERATED_UNICODE_TABLES}
  COMMAND ${LUA_PRG} ${UNICODE_TABLES_GENERATOR}
                     ${UNICODE_DIR}
                     ${GENERATED_UNICODE_TABLES}
  DEPENDS
    ${UNICODE_TABLES_GENERATOR}
    ${UNICODE_FILES}
)

add_custom_command(
  OUTPUT ${GENERATED_API_DISPATCH} ${GENERATED_FUNCS_METADATA}
         ${API_METADATA} ${MSGPACK_LUA_C_BINDINGS}
  COMMAND ${LUA_PRG} ${API_DISPATCH_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}
                     ${GENERATED_API_DISPATCH}
                     ${GENERATED_FUNCS_METADATA} ${API_METADATA}
                     ${MSGPACK_LUA_C_BINDINGS}
                     ${API_HEADERS}
  DEPENDS
    ${API_HEADERS}
    ${MSGPACK_RPC_HEADERS}
    ${API_DISPATCH_GENERATOR}
    ${GENERATOR_C_GRAMMAR}
    ${CMAKE_CURRENT_LIST_DIR}/api/dispatch_deprecated.lua
)

add_custom_command(
  OUTPUT ${VIM_MODULE_FILE}
  COMMAND ${LUA_PRG} ${CHAR_BLOB_GENERATOR} ${VIM_MODULE_SOURCE}
                     ${VIM_MODULE_FILE} vim_module
  DEPENDS
    ${CHAR_BLOB_GENERATOR}
    ${VIM_MODULE_SOURCE}
)

list(APPEND NVIM_GENERATED_SOURCES
  "${MSGPACK_LUA_C_BINDINGS}"
)

add_custom_command(
  OUTPUT ${GENERATED_UI_EVENTS}
         ${GENERATED_UI_EVENTS_CALL}
         ${GENERATED_UI_EVENTS_REMOTE}
         ${GENERATED_UI_EVENTS_BRIDGE}
         ${GENERATED_UI_EVENTS_METADATA}
  COMMAND ${LUA_PRG} ${API_UI_EVENTS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}
                     ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h
                     ${GENERATED_UI_EVENTS}
                     ${GENERATED_UI_EVENTS_CALL}
                     ${GENERATED_UI_EVENTS_REMOTE}
                     ${GENERATED_UI_EVENTS_BRIDGE}
                     ${GENERATED_UI_EVENTS_METADATA}
  DEPENDS
    ${API_UI_EVENTS_GENERATOR}
    ${GENERATOR_C_GRAMMAR}
    ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h
)

list(APPEND NVIM_GENERATED_FOR_HEADERS
  "${GENERATED_EX_CMDS_ENUM}"
  "${GENERATED_EVENTS_ENUM}"
)

list(APPEND NVIM_GENERATED_FOR_SOURCES
  "${GENERATED_API_DISPATCH}"
  "${GENERATED_EX_CMDS_DEFS}"
  "${GENERATED_EVENTS_NAMES_MAP}"
  "${GENERATED_OPTIONS}"
  "${GENERATED_UNICODE_TABLES}"
  "${VIM_MODULE_FILE}"
)

list(APPEND NVIM_GENERATED_SOURCES
  "${PROJECT_BINARY_DIR}/config/auto/pathdef.c"
)

add_custom_command(OUTPUT ${GENERATED_EX_CMDS_ENUM} ${GENERATED_EX_CMDS_DEFS}
  COMMAND ${LUA_PRG} ${EX_CMDS_GENERATOR}
      ${CMAKE_CURRENT_LIST_DIR} ${GENERATED_INCLUDES_DIR} ${GENERATED_DIR}
  DEPENDS ${EX_CMDS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/ex_cmds.lua
)

if(NOT GPERF_PRG)
  message(FATAL_ERROR "gperf was not found.")
endif()
add_custom_command(OUTPUT ${GENERATED_FUNCS} ${FUNCS_DATA}
  COMMAND ${LUA_PRG} ${FUNCS_GENERATOR}
      ${CMAKE_CURRENT_LIST_DIR} ${GENERATED_DIR} ${API_METADATA} ${FUNCS_DATA}
  COMMAND ${GPERF_PRG}
      ${GENERATED_DIR}/funcs.generated.h.gperf --output-file=${GENERATED_FUNCS}
  DEPENDS ${FUNCS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/eval.lua ${API_METADATA}
)
list(APPEND NVIM_GENERATED_FOR_SOURCES
  "${GENERATED_FUNCS}")

add_custom_command(OUTPUT ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  COMMAND ${LUA_PRG} ${EVENTS_GENERATOR}
      ${CMAKE_CURRENT_LIST_DIR} ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  DEPENDS ${EVENTS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/auevents.lua
)

add_custom_command(OUTPUT ${GENERATED_OPTIONS}
  COMMAND ${LUA_PRG} ${OPTIONS_GENERATOR}
                     ${CMAKE_CURRENT_LIST_DIR} ${GENERATED_OPTIONS}
  DEPENDS ${OPTIONS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/options.lua
)

# NVIM_GENERATED_FOR_SOURCES and NVIM_GENERATED_FOR_HEADERS must be mutually exclusive.
foreach(hfile ${NVIM_GENERATED_FOR_HEADERS})
  list(FIND NVIM_GENERATED_FOR_SOURCES ${hfile} hfile_idx)
  if(NOT ${hfile_idx} EQUAL -1)
    message(FATAL_ERROR "File included in both NVIM_GENERATED_FOR_HEADERS and NVIM_GENERATED_FOR_SOURCES")
  endif()
endforeach()

# Our dependencies come first.

if (CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
  list(APPEND NVIM_LINK_LIBRARIES pthread c++abi)
endif()

if (LibIntl_FOUND)
  list(APPEND NVIM_LINK_LIBRARIES ${LibIntl_LIBRARY})
endif()

if(Iconv_LIBRARIES)
  list(APPEND NVIM_LINK_LIBRARIES ${Iconv_LIBRARIES})
endif()

if(WIN32)
  list(APPEND NVIM_LINK_LIBRARIES ${WINPTY_LIBRARIES})
endif()

# Put these last on the link line, since multiple things may depend on them.
list(APPEND NVIM_LINK_LIBRARIES
  ${LIBLUV_LIBRARIES}
  ${LIBUV_LIBRARIES}
  ${MSGPACK_LIBRARIES}
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

set(NVIM_EXEC_LINK_LIBRARIES ${NVIM_LINK_LIBRARIES} ${LUA_PREFERRED_LIBRARIES})

if(POLICY CMP0069)
  cmake_policy(SET CMP0069 NEW)
endif()

add_executable(nvim ${NVIM_GENERATED_FOR_SOURCES} ${NVIM_GENERATED_FOR_HEADERS}
  ${NVIM_GENERATED_SOURCES} ${NVIM_SOURCES} ${NVIM_HEADERS}
  ${XDIFF_SOURCES} ${XDIFF_HEADERS})
target_link_libraries(nvim ${NVIM_EXEC_LINK_LIBRARIES})
install_helper(TARGETS nvim)

set_property(TARGET nvim APPEND PROPERTY
             INCLUDE_DIRECTORIES ${LUA_PREFERRED_INCLUDE_DIRS})

if(ENABLE_LTO AND (POLICY CMP0069))
  include(CheckIPOSupported)
  check_ipo_supported(RESULT IPO_SUPPORTED)
  if(IPO_SUPPORTED AND (NOT CMAKE_BUILD_TYPE MATCHES Debug))
    set_property(TARGET nvim PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
  endif()
endif()

if(WIN32)
  # Copy DLLs and third-party tools to bin/ and install them along with nvim
  add_custom_target(nvim_runtime_deps ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${PROJECT_BINARY_DIR}/windows_runtime_deps/
      ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
  install(DIRECTORY ${PROJECT_BINARY_DIR}/windows_runtime_deps/
    DESTINATION ${CMAKE_INSTALL_BINDIR})

  add_custom_target(nvim_dll_deps DEPENDS nvim
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/windows_runtime_deps
    COMMAND ${CMAKE_COMMAND}
      "-DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}"
      -DBINARY="${PROJECT_BINARY_DIR}/bin/nvim${CMAKE_EXECUTABLE_SUFFIX}"
      -DDST=${PROJECT_BINARY_DIR}/windows_runtime_deps
      -P ${PROJECT_SOURCE_DIR}/cmake/WindowsDllCopy.cmake)
  add_dependencies(nvim_runtime_deps nvim_dll_deps)

  # A CMake script is used for copying the files to avoid the
  # "command line is too long" error that occurs when Ninja tries running
  # a command that exceeds the length limit (8191 characters) on Windows.
  # See https://developercommunity.visualstudio.com/content/problem/212207/file-open-cmake-the-command-line-is-too-long.html
  set(EXTERNAL_BLOBS_SCRIPT
    "file(MAKE_DIRECTORY \"${PROJECT_BINARY_DIR}/windows_runtime_deps/platforms\")")
  foreach(DEP_FILE IN ITEMS
                      ca-bundle.crt
                      cat.exe
                      curl.exe
                      diff.exe
                      tee.exe
                      tidy.exe
                      win32yank.exe
                      winpty-agent.exe
                      xxd.exe

                      D3Dcompiler_47.dll
                      libEGL.dll
                      libgcc_s_dw2-1.dll
                      libGLESV2.dll
                      libstdc++-6.dll
                      libwinpthread-1.dll
                      nvim-qt.exe
                      Qt5Core.dll
                      Qt5Gui.dll
                      Qt5Network.dll
                      Qt5Svg.dll
                      Qt5Widgets.dll
                      winpty.dll

                      platforms/qwindows.dll
                      )
    get_filename_component(DEP_FILE_DIR ${DEP_FILE} DIRECTORY)
    set(EXTERNAL_BLOBS_SCRIPT "${EXTERNAL_BLOBS_SCRIPT}\n"
      "file(COPY \"${DEPS_PREFIX}/bin/${DEP_FILE}\"
         DESTINATION \"${PROJECT_BINARY_DIR}/windows_runtime_deps/${DEP_FILE_DIR}\")")
  endforeach()
  file(WRITE ${PROJECT_BINARY_DIR}/external_blobs.cmake ${EXTERNAL_BLOBS_SCRIPT})
  add_custom_target(external_blobs
    COMMAND ${CMAKE_COMMAND} -P ${PROJECT_BINARY_DIR}/external_blobs.cmake)
  set_target_properties(external_blobs PROPERTIES FOLDER deps)
  add_dependencies(nvim_runtime_deps external_blobs)
else()
  add_custom_target(nvim_runtime_deps)  # Stub target to avoid CMP0046.
endif()
set_target_properties(nvim_runtime_deps PROPERTIES FOLDER deps)

add_library(
  libnvim
  STATIC
  EXCLUDE_FROM_ALL
  ${NVIM_SOURCES} ${NVIM_GENERATED_SOURCES}
  ${NVIM_HEADERS} ${NVIM_GENERATED_FOR_SOURCES} ${NVIM_GENERATED_FOR_HEADERS}
  ${XDIFF_SOURCES} ${XDIFF_HEADERS}
)
set_property(TARGET libnvim APPEND PROPERTY
             INCLUDE_DIRECTORIES ${LUA_PREFERRED_INCLUDE_DIRS})
set_target_properties(
  libnvim
  PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME nvim
)
set_property(
  TARGET libnvim
  APPEND_STRING PROPERTY COMPILE_FLAGS " -DMAKE_LIB "
)

if(NOT LUAJIT_FOUND)
  message(STATUS "luajit not found, skipping nvim-test (unit tests) target")
else()
  set(NVIM_TEST_LINK_LIBRARIES ${NVIM_LINK_LIBRARIES} ${LUAJIT_LIBRARIES})
  add_library(
    nvim-test
    MODULE
    EXCLUDE_FROM_ALL
    ${NVIM_SOURCES} ${NVIM_GENERATED_SOURCES}
    ${NVIM_HEADERS} ${NVIM_GENERATED_FOR_SOURCES} ${NVIM_GENERATED_FOR_HEADERS}
    ${XDIFF_SOURCES} ${XDIFF_HEADERS}
    ${UNIT_TEST_FIXTURES}
  )
  target_link_libraries(nvim-test ${NVIM_TEST_LINK_LIBRARIES})
  target_link_libraries(libnvim ${NVIM_TEST_LINK_LIBRARIES})
  set_property(
    TARGET nvim-test
    APPEND PROPERTY INCLUDE_DIRECTORIES ${LUAJIT_INCLUDE_DIRS}
  )
  set_target_properties(
    nvim-test
    PROPERTIES
      POSITION_INDEPENDENT_CODE ON
  )
  set_property(
    TARGET nvim-test
    APPEND_STRING PROPERTY COMPILE_FLAGS " -DUNIT_TESTING "
  )
endif()

if(CLANG_ASAN_UBSAN)
  message(STATUS "Enabling Clang address sanitizer and undefined behavior sanitizer for nvim.")
  check_c_compiler_flag(-fno-sanitize-recover=all SANITIZE_RECOVER_ALL)
  if(SANITIZE_RECOVER_ALL)
    set(SANITIZE_RECOVER -fno-sanitize-recover=all)     # Clang 3.6+
  else()
    set(SANITIZE_RECOVER -fno-sanitize-recover)         # Clang 3.5-
  endif()
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-DEXITFREE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "${SANITIZE_RECOVER} -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize=address -fsanitize=undefined -fsanitize-blacklist=${PROJECT_SOURCE_DIR}/src/.asan-blacklist")
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
  set_property(TARGET nvim APPEND_STRING PROPERTY COMPILE_FLAGS "-fPIE ")
  set_property(TARGET nvim APPEND_STRING PROPERTY LINK_FLAGS "-fsanitize=thread ")
endif()

function(get_test_target prefix sfile relative_path_var target_var)
  get_filename_component(full_d "${sfile}" PATH)
  file(RELATIVE_PATH d "${PROJECT_SOURCE_DIR}/src/nvim" "${full_d}")
  if(d MATCHES "^[.][.]")
    file(RELATIVE_PATH d "${GENERATED_DIR}" "${full_d}")
  endif()
  get_filename_component(r "${sfile}" NAME)
  if(NOT d MATCHES "^[.]?$")
    set(r "${d}/${r}")
  endif()
  string(REGEX REPLACE "[/.]" "-" suffix "${r}")
  set(${relative_path_var} ${r} PARENT_SCOPE)
  if(prefix STREQUAL "")
    set(${target_var} "${suffix}" PARENT_SCOPE)
  else()
    set(${target_var} "${prefix}-${suffix}" PARENT_SCOPE)
  endif()
endfunction()

set(NO_SINGLE_CHECK_HEADERS
  os/win_defs.h
  os/pty_process_win.h
)
foreach(hfile ${NVIM_HEADERS})
  get_test_target(test-includes "${hfile}" relative_path texe)

  if(NOT ${hfile} MATCHES "[.](c|in)[.]h$")
    set(tsource "${GENERATED_DIR}/${relative_path}.test-include.c")
    write_file("${tsource}" "#include \"${hfile}\"\nint main(int argc, char **argv) { return 0; }")
    add_executable(
      ${texe}
      EXCLUDE_FROM_ALL
      ${tsource} ${NVIM_HEADERS} ${NVIM_GENERATED_FOR_HEADERS})
    set_property(
      TARGET ${texe}
      APPEND PROPERTY INCLUDE_DIRECTORIES ${LUA_PREFERRED_INCLUDE_DIRS}
    )
    set_target_properties(${texe} PROPERTIES FOLDER test)

    list(FIND NO_SINGLE_CHECK_HEADERS "${relative_path}" hfile_exclude_idx)
    if(${hfile_exclude_idx} EQUAL -1)
      list(APPEND HEADER_CHECK_TARGETS ${texe})
    endif()
  endif()
endforeach()
add_custom_target(check-single-includes DEPENDS ${HEADER_CHECK_TARGETS})

function(add_download output url allow_failure)
  add_custom_command(
    OUTPUT "${output}"
    COMMAND
      ${CMAKE_COMMAND}
        -DURL=${url} -DFILE=${output}
        -DALLOW_FAILURE=${allow_failure}
        -P ${DOWNLOAD_SCRIPT}
    DEPENDS ${DOWNLOAD_SCRIPT}
  )
endfunction()

add_download(${LINT_SUPPRESSES_ARCHIVE} ${LINT_SUPPRESSES_URL} off)

add_custom_command(
  OUTPUT ${LINT_SUPPRESSES_TOUCH_FILE}
  WORKING_DIRECTORY ${LINT_SUPPRESSES_ROOT}/src
  COMMAND ${CMAKE_COMMAND} -E tar xfz ${LINT_SUPPRESSES_ARCHIVE}
  COMMAND
    ${CMAKE_COMMAND}
      -DTARGET=${LINT_SUPPRESSES_ROOT}
      -P ${LINT_SUPPRESSES_INSTALL_SCRIPT}
  COMMAND ${CMAKE_COMMAND} -E touch ${LINT_SUPPRESSES_TOUCH_FILE}
  DEPENDS
    ${LINT_SUPPRESSES_ARCHIVE} ${LINT_SUPPRESSES_INSTALL_SCRIPT}
)

add_download(${LINT_SUPPRESS_FILE} ${LINT_SUPPRESS_URL} off)

set(LINT_NVIM_REL_SOURCES)
foreach(sfile ${LINT_NVIM_SOURCES})
  get_test_target("" "${sfile}" r suffix)
  set(suppress_file ${LINT_SUPPRESSES_ROOT}/${suffix}.json)
  set(suppress_url "${LINT_SUPPRESS_URL_BASE}/${suffix}.json")
  set(rsfile src/nvim/${r})
  set(touch_file "${TOUCHES_DIR}/ran-clint-${suffix}")
  add_custom_command(
    OUTPUT ${touch_file}
    COMMAND ${LINT_PRG} --suppress-errors=${suppress_file} ${rsfile}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    COMMAND ${CMAKE_COMMAND} -E touch ${touch_file}
    DEPENDS ${LINT_PRG} ${sfile} ${LINT_SUPPRESSES_TOUCH_FILE}
  )
  list(APPEND LINT_TARGETS ${touch_file})
  list(APPEND LINT_NVIM_REL_SOURCES ${rsfile})
endforeach()
add_custom_target(clint DEPENDS ${LINT_TARGETS})

add_custom_target(
  clint-full
  COMMAND
    ${LINT_PRG} --suppress-errors=${LINT_SUPPRESS_FILE} ${LINT_NVIM_REL_SOURCES}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  DEPENDS ${LINT_PRG} ${LINT_NVIM_SOURCES} ${LINT_SUPPRESS_FILE}
)

add_custom_target(generated-sources DEPENDS
  ${NVIM_GENERATED_FOR_SOURCES}
  ${NVIM_GENERATED_FOR_HEADERS}
  ${NVIM_GENERATED_SOURCES}
)

add_subdirectory(po)
