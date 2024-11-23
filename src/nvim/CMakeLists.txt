add_library(main_lib INTERFACE)

# Internally we need to make a distinction between "nvim without runtime files"
# (nvim_bin) and "nvim with runtime files" (nvim).
add_executable(nvim_bin EXCLUDE_FROM_ALL)

set_target_properties(nvim_bin
  PROPERTIES
  EXPORT_COMPILE_COMMANDS ON
  ENABLE_EXPORTS TRUE
  OUTPUT_NAME nvim)

#-------------------------------------------------------------------------------
# Dependencies
#-------------------------------------------------------------------------------

add_library(nlua0 MODULE)
if(WIN32)
  target_compile_definitions(nlua0 PUBLIC LUA_BUILD_AS_DLL LUA_LIB)
  set_target_properties(nlua0 PROPERTIES ENABLE_EXPORTS TRUE)
elseif(APPLE)
  target_link_options(nlua0 PRIVATE -undefined dynamic_lookup)
endif()

# TODO(dundargoc): unittest stops working if I create an pseudo-imported
# library "luv" as with the other dependencies. Figure out why and fix.
find_package(Luv 1.43.0 REQUIRED)
target_include_directories(main_lib SYSTEM BEFORE INTERFACE ${LUV_INCLUDE_DIR})
target_link_libraries(main_lib INTERFACE ${LUV_LIBRARY})

find_package(Iconv REQUIRED)
find_package(Libuv 1.28.0 REQUIRED)
find_package(Lpeg REQUIRED)
find_package(Treesitter 0.24.0 REQUIRED)
find_package(Unibilium 2.0 REQUIRED)
find_package(UTF8proc REQUIRED)

target_link_libraries(main_lib INTERFACE
  iconv
  lpeg
  treesitter
  unibilium
  utf8proc)
target_link_libraries(nlua0 PUBLIC lpeg)

if(ENABLE_LIBINTL)
  find_package(Libintl REQUIRED) # Libintl (not Intl) selects our FindLibintl.cmake script. #8464
  target_link_libraries(main_lib INTERFACE libintl)
endif()

if(ENABLE_WASMTIME)
  find_package(Wasmtime 25.0.2 EXACT REQUIRED)
  target_link_libraries(main_lib INTERFACE wasmtime)
  target_compile_definitions(nvim_bin PRIVATE HAVE_WASMTIME)
endif()

# The unit test lib requires LuaJIT; it will be skipped if LuaJIT is missing.
option(PREFER_LUA "Prefer Lua over LuaJIT in the nvim executable." OFF)
if(PREFER_LUA)
  find_package(Lua 5.1 EXACT REQUIRED)
  target_include_directories(main_lib SYSTEM BEFORE INTERFACE ${LUA_INCLUDE_DIR})
  target_include_directories(nlua0 SYSTEM BEFORE PUBLIC ${LUA_INCLUDE_DIR})
  target_link_libraries(main_lib INTERFACE ${LUA_LIBRARIES})
  # Passive (not REQUIRED): if LUAJIT_FOUND is not set, fixtures for unittests is skipped.
  find_package(Luajit)
else()
  find_package(Luajit REQUIRED)
  target_include_directories(main_lib SYSTEM BEFORE INTERFACE ${LUAJIT_INCLUDE_DIR})
  target_link_libraries(main_lib INTERFACE ${LUAJIT_LIBRARY})
  target_include_directories(nlua0 SYSTEM BEFORE PUBLIC ${LUAJIT_INCLUDE_DIR})
  if(WIN32)
    target_link_libraries(nlua0 PUBLIC ${LUAJIT_LIBRARY})
  endif()
endif()

#-------------------------------------------------------------------------------
# Compiler and linker options
#-------------------------------------------------------------------------------

if(NOT MSVC)
  target_compile_options(main_lib INTERFACE -Wall -Wextra -pedantic -Wno-unused-parameter
    -Wstrict-prototypes -std=gnu99 -Wshadow -Wconversion -Wvla
    -Wdouble-promotion
    -Wmissing-noreturn
    -Wmissing-format-attribute
    -Wmissing-prototypes
    -fsigned-char)

  # For O_CLOEXEC, O_DIRECTORY, and O_NOFOLLOW flags on older systems
  # (pre POSIX.1-2008: glibc 2.11 and earlier). #4042
  # For ptsname(). #6743
  target_compile_definitions(main_lib INTERFACE _GNU_SOURCE)
endif()

# -fstack-protector breaks Mingw-w64 builds
if(NOT MINGW)
  check_c_compiler_flag(-fstack-protector-strong HAS_FSTACK_PROTECTOR_STRONG_FLAG)
  if(HAS_FSTACK_PROTECTOR_STRONG_FLAG)
    target_compile_options(main_lib INTERFACE -fstack-protector-strong)
    target_link_libraries(main_lib INTERFACE -fstack-protector-strong)
  else()
    check_c_compiler_flag(-fstack-protector HAS_FSTACK_PROTECTOR_FLAG)
    if(HAS_FSTACK_PROTECTOR_FLAG)
      target_compile_options(main_lib INTERFACE -fstack-protector --param ssp-buffer-size=4)
      target_link_libraries(main_lib INTERFACE -fstack-protector --param ssp-buffer-size=4)
    endif()
  endif()
endif()

# Compiler specific options
if(MSVC)
  target_compile_options(main_lib INTERFACE -W3)

  # Disable warnings that give too many false positives.
  target_compile_options(main_lib INTERFACE -wd4311 -wd4146 -wd4003 -wd4715)
  target_compile_definitions(main_lib INTERFACE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_DEPRECATE)

  target_sources(main_lib INTERFACE ${CMAKE_CURRENT_LIST_DIR}/os/nvim.manifest)
elseif(MINGW)
  # Use POSIX compatible stdio in Mingw
  target_compile_definitions(main_lib INTERFACE __USE_MINGW_ANSI_STDIO)

  # wrapper for nvim.manifest
  target_sources(main_lib INTERFACE ${CMAKE_CURRENT_LIST_DIR}/os/nvim.rc)
elseif(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  target_compile_options(main_lib INTERFACE
    -Wno-conversion
    -fno-common
    $<$<CONFIG:Release>:-Wno-unused-result>
    $<$<CONFIG:RelWithDebInfo>:-Wno-unused-result>
    $<$<CONFIG:MinSizeRel>:-Wno-unused-result>)
elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
  # On FreeBSD 64 math.h uses unguarded C11 extension, which taints clang
  # 3.4.1 used there.
  if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
    target_compile_options(main_lib INTERFACE -Wno-c11-extensions)
  endif()

  # workaround for clang-11 on macOS, supported on later versions
  if(NOT APPLE)
    target_link_libraries(nvim_bin PRIVATE -Wl,--no-undefined)
  endif()
endif()

# Platform specific options
if(UNIX)
  target_link_libraries(main_lib INTERFACE m)
  if (NOT CMAKE_SYSTEM_NAME STREQUAL "SunOS")
    target_link_libraries(main_lib INTERFACE util)
  endif()
endif()

if(CMAKE_SYSTEM_NAME MATCHES "Windows")
  target_compile_definitions(main_lib INTERFACE _WIN32_WINNT=0x0602 MSWIN WIN32_LEAN_AND_MEAN)
  target_link_libraries(main_lib INTERFACE netapi32)
elseif(CMAKE_SYSTEM_NAME MATCHES "Darwin")
  target_link_libraries(nvim_bin PRIVATE "-framework CoreServices")

  # Actually export symbols - symbols may not be visible even though
  # ENABLE_EXPORTS is set to true. See
  # https://github.com/neovim/neovim/issues/25295
  target_link_options(nvim_bin PRIVATE "-Wl,-export_dynamic")
elseif(CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
  target_link_libraries(main_lib INTERFACE pthread c++abi)
elseif(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
  target_link_libraries(nvim_bin PRIVATE -lsocket)
endif()

check_c_compiler_flag(-Wimplicit-fallthrough HAVE_WIMPLICIT_FALLTHROUGH_FLAG)
if(HAVE_WIMPLICIT_FALLTHROUGH_FLAG)
  target_compile_options(main_lib INTERFACE -Wimplicit-fallthrough)
endif()

check_c_compiler_flag(-fdiagnostics-color=auto HAS_DIAG_COLOR_FLAG)
if(HAS_DIAG_COLOR_FLAG)
  if(CMAKE_GENERATOR MATCHES "Ninja")
    target_compile_options(main_lib INTERFACE -fdiagnostics-color=always)
  else()
    target_compile_options(main_lib INTERFACE -fdiagnostics-color=auto)
  endif()
endif()

target_compile_definitions(main_lib INTERFACE INCLUDE_GENERATED_DECLARATIONS)

# Remove --sort-common from linker flags, as this seems to cause bugs (see #2641, #3374).
# TODO: Figure out the root cause.
if(CMAKE_EXE_LINKER_FLAGS MATCHES "--sort-common" OR
   CMAKE_SHARED_LINKER_FLAGS MATCHES "--sort-common" OR
   CMAKE_MODULE_LINKER_FLAGS MATCHES "--sort-common")
  message(STATUS "Removing --sort-common from linker flags")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
  string(REGEX REPLACE ",--sort-common(=[^,]+)?" "" CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}")

  # If no linker flags remain for a -Wl argument, remove it.
  # '-Wl$' will match LDFLAGS="-Wl,--sort-common",
  # '-Wl ' will match LDFLAGS="-Wl,--sort-common -Wl,..."
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
  string(REGEX REPLACE "-Wl($| )" "" CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS}")
endif()

#-------------------------------------------------------------------------------
# Cmake options
#-------------------------------------------------------------------------------

if(ENABLE_ASAN_UBSAN)
  message(STATUS "Enabling address sanitizer and undefined behavior sanitizer for nvim.")
  if(NOT MSVC)
    if(CI_BUILD)
      # Try to recover from all sanitize issues so we get reports about all failures
      target_compile_options(nvim_bin PRIVATE -fsanitize-recover=all)
    else()
      target_compile_options(nvim_bin PRIVATE -fno-sanitize-recover=all)
    endif()
    target_compile_options(nvim_bin PRIVATE
      -fno-omit-frame-pointer
      -fno-optimize-sibling-calls
      -fsanitize=undefined)
  endif()

  target_compile_options(nvim_bin PRIVATE -fsanitize=address)
  target_link_libraries(nvim_bin PRIVATE -fsanitize=address -fsanitize=undefined)
  target_compile_definitions(nvim_bin PRIVATE ENABLE_ASAN_UBSAN)
endif()

if(ENABLE_MSAN)
  message(STATUS "Enabling memory sanitizer for nvim.")
  target_compile_options(nvim_bin PRIVATE
    -fsanitize=memory
    -fsanitize-memory-track-origins
    -fno-omit-frame-pointer
    -fno-optimize-sibling-calls)
  target_link_libraries(nvim_bin PRIVATE -fsanitize=memory -fsanitize-memory-track-origins)
endif()

if(ENABLE_TSAN)
  message(STATUS "Enabling thread sanitizer for nvim.")
  target_compile_options(nvim_bin PRIVATE -fsanitize=thread -fPIE)
  target_link_libraries(nvim_bin PRIVATE -fsanitize=thread)
endif()

option(CI_BUILD "CI, extra flags will be set" OFF)
if(CI_BUILD)
  message(STATUS "CI build enabled")
  if(MSVC)
    target_compile_options(main_lib INTERFACE -WX)
  else()
    target_compile_options(main_lib INTERFACE -Werror)
  endif()
endif()

option(ENABLE_IWYU "Run include-what-you-use with the compiler." OFF)
if(ENABLE_IWYU)
  find_program(IWYU_PRG NAMES include-what-you-use iwyu REQUIRED)
  set(iwyu_flags "${IWYU_PRG};")
  string(APPEND iwyu_flags "-Xiwyu;--no_default_mappings;")
  string(APPEND iwyu_flags "-Xiwyu;--no_fwd_decls;")
  string(APPEND iwyu_flags "-Xiwyu;--mapping_file=${PROJECT_SOURCE_DIR}/cmake.config/iwyu/mapping.imp")

  set_target_properties(nvim_bin PROPERTIES C_INCLUDE_WHAT_YOU_USE "${iwyu_flags}")
  target_compile_definitions(main_lib INTERFACE EXITFREE)
endif()

option(ENABLE_COMPILER_SUGGESTIONS "Enable -Wsuggest compiler warnings" OFF)
if(ENABLE_COMPILER_SUGGESTIONS)
  target_compile_options(main_lib INTERFACE
    -Wsuggest-attribute=cold
    -Wsuggest-attribute=const
    -Wsuggest-attribute=malloc
    -Wsuggest-attribute=pure)
endif()

option(ENABLE_GCOV "Enable gcov support" OFF)
if(ENABLE_GCOV)
  if(ENABLE_TSAN)
    # GCOV and TSAN results in false data race reports
    message(FATAL_ERROR "ENABLE_GCOV cannot be used with ENABLE_TSAN")
  endif()
  message(STATUS "Enabling gcov support")
  target_compile_options(main_lib INTERFACE --coverage)
  target_link_libraries(main_lib INTERFACE --coverage)
  target_compile_definitions(main_lib INTERFACE USE_GCOV)
endif()

#-------------------------------------------------------------------------------
# Variables
#-------------------------------------------------------------------------------

set(FUNCS_METADATA ${PROJECT_BINARY_DIR}/funcs_metadata.mpack)
set(UI_METADATA ${PROJECT_BINARY_DIR}/ui_metadata.mpack)
set(BINARY_LIB_DIR ${PROJECT_BINARY_DIR}/lib/nvim)
set(GENERATED_DIR ${PROJECT_BINARY_DIR}/src/nvim/auto)
set(GENERATED_INCLUDES_DIR ${PROJECT_BINARY_DIR}/include)
set(GENERATOR_DIR ${CMAKE_CURRENT_LIST_DIR}/generators)
set(GEN_EVAL_TOUCH ${TOUCHES_DIR}/gen_doc_eval)
set(LUAJIT_RUNTIME_DIR ${DEPS_PREFIX}/share/luajit-2.1/jit)
set(NVIM_RUNTIME_DIR ${PROJECT_SOURCE_DIR}/runtime)

# GENERATOR_DIR
set(API_DISPATCH_GENERATOR ${GENERATOR_DIR}/gen_api_dispatch.lua)
set(API_UI_EVENTS_GENERATOR ${GENERATOR_DIR}/gen_api_ui_events.lua)
set(CHAR_BLOB_GENERATOR ${GENERATOR_DIR}/gen_char_blob.lua)
set(EVENTS_GENERATOR ${GENERATOR_DIR}/gen_events.lua)
set(EX_CMDS_GENERATOR ${GENERATOR_DIR}/gen_ex_cmds.lua)
set(FUNCS_GENERATOR ${GENERATOR_DIR}/gen_eval.lua)
set(GENERATOR_C_GRAMMAR ${GENERATOR_DIR}/c_grammar.lua)
set(GENERATOR_HASHY ${GENERATOR_DIR}/hashy.lua)
set(GENERATOR_PRELOAD ${GENERATOR_DIR}/preload.lua)
set(HEADER_GENERATOR ${GENERATOR_DIR}/gen_declarations.lua)
set(OPTIONS_GENERATOR ${GENERATOR_DIR}/gen_options.lua)

# GENERATED_DIR and GENERATED_INCLUDES_DIR
set(GENERATED_API_DISPATCH ${GENERATED_DIR}/api/private/dispatch_wrappers.generated.h)
set(GENERATED_EVENTS_ENUM ${GENERATED_INCLUDES_DIR}/auevents_enum.generated.h)
set(GENERATED_EVENTS_NAMES_MAP ${GENERATED_DIR}/auevents_name_map.generated.h)
set(GENERATED_EX_CMDS_DEFS ${GENERATED_DIR}/ex_cmds_defs.generated.h)
set(GENERATED_EX_CMDS_ENUM ${GENERATED_INCLUDES_DIR}/ex_cmds_enum.generated.h)
set(GENERATED_FUNCS ${GENERATED_DIR}/funcs.generated.h)
set(GENERATED_API_METADATA ${GENERATED_DIR}/api/private/api_metadata.generated.h)
set(GENERATED_KEYSETS_DEFS ${GENERATED_DIR}/keysets_defs.generated.h)
set(GENERATED_OPTIONS ${GENERATED_DIR}/options.generated.h)
set(GENERATED_OPTIONS_ENUM ${GENERATED_DIR}/options_enum.generated.h)
set(GENERATED_OPTIONS_MAP ${GENERATED_DIR}/options_map.generated.h)
set(GENERATED_OPTION_VARS ${GENERATED_DIR}/option_vars.generated.h)
set(GENERATED_UI_EVENTS_CALL ${GENERATED_DIR}/ui_events_call.generated.h)
set(GENERATED_UI_EVENTS_CLIENT ${GENERATED_DIR}/ui_events_client.generated.h)
set(GENERATED_UI_EVENTS_REMOTE ${GENERATED_DIR}/ui_events_remote.generated.h)
set(LUA_API_C_BINDINGS ${GENERATED_DIR}/lua_api_c_bindings.generated.h)
set(VIM_MODULE_FILE ${GENERATED_DIR}/lua/vim_module.generated.h)

# NVIM_RUNTIME_DIR
set(LUA_DEFAULTS_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/_defaults.lua)
set(LUA_EDITOR_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/_editor.lua)
set(LUA_FILETYPE_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/filetype.lua)
set(LUA_FS_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/fs.lua)
set(LUA_F_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/F.lua)
set(LUA_INIT_PACKAGES_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/_init_packages.lua)
set(LUA_INSPECT_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/inspect.lua)
set(LUA_KEYMAP_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/keymap.lua)
set(LUA_LOADER_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/loader.lua)
set(LUA_OPTIONS_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/_options.lua)
set(LUA_SHARED_MODULE_SOURCE ${NVIM_RUNTIME_DIR}/lua/vim/shared.lua)

file(GLOB API_HEADERS CONFIGURE_DEPENDS api/*.h)
list(REMOVE_ITEM API_HEADERS ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h)
file(GLOB MSGPACK_RPC_HEADERS CONFIGURE_DEPENDS msgpack_rpc/*.h)

target_include_directories(main_lib INTERFACE
  ${GENERATED_DIR}
  ${GENERATED_INCLUDES_DIR}
  "${PROJECT_BINARY_DIR}/cmake.config"
  "${PROJECT_SOURCE_DIR}/src")

target_include_directories(nlua0 PUBLIC
  "${PROJECT_SOURCE_DIR}/src"
  "${PROJECT_BINARY_DIR}/cmake.config"
  ${GENERATED_INCLUDES_DIR})

file(MAKE_DIRECTORY ${TOUCHES_DIR} ${GENERATED_DIR} ${GENERATED_INCLUDES_DIR})

file(GLOB NVIM_SOURCES CONFIGURE_DEPENDS *.c)
file(GLOB NVIM_HEADERS CONFIGURE_DEPENDS *.h)
file(GLOB EXTERNAL_SOURCES CONFIGURE_DEPENDS ../xdiff/*.c ../mpack/*.c ../cjson/*.c ../klib/*.c ../vterm/*.c)
file(GLOB EXTERNAL_HEADERS CONFIGURE_DEPENDS ../xdiff/*.h ../mpack/*.h ../cjson/*.h ../klib/*.h ../vterm/*.h)

file(GLOB NLUA0_SOURCES CONFIGURE_DEPENDS ../mpack/*.c)

if(PREFER_LUA)
  # luajit not used, use a vendored copy of the bit module
  list(APPEND EXTERNAL_SOURCES ${PROJECT_SOURCE_DIR}/src/bit.c)
  list(APPEND NLUA0_SOURCES ${PROJECT_SOURCE_DIR}/src/bit.c)
  target_compile_definitions(main_lib INTERFACE NVIM_VENDOR_BIT)
endif()

# Inlined external projects, we don't maintain it. #9306
if(MSVC)
  set_source_files_properties(
    ${EXTERNAL_SOURCES} PROPERTIES COMPILE_OPTIONS "-wd4090;-wd4244;-wd4267")
else()
  set_source_files_properties(
    ${EXTERNAL_SOURCES} PROPERTIES COMPILE_OPTIONS "-Wno-conversion;-Wno-missing-noreturn;-Wno-missing-format-attribute;-Wno-double-promotion;-Wno-strict-prototypes;-Wno-misleading-indentation;-Wno-sign-compare;-Wno-implicit-fallthrough;-Wno-missing-prototypes;-Wno-missing-field-initializers")
endif()

list(APPEND NLUA0_SOURCES ${PROJECT_SOURCE_DIR}/src/nlua0.c)

foreach(subdir
        os
        api
        api/private
        msgpack_rpc
        tui
        tui/termkey
        event
        eval
        lua
        lib
        viml
        viml/parser
       )

  file(MAKE_DIRECTORY ${GENERATED_DIR}/${subdir})
  file(MAKE_DIRECTORY ${GENERATED_INCLUDES_DIR}/${subdir})
  file(GLOB sources CONFIGURE_DEPENDS ${subdir}/*.c)
  file(GLOB headers CONFIGURE_DEPENDS ${subdir}/*.h)
  list(APPEND NVIM_SOURCES ${sources})
  list(APPEND NVIM_HEADERS ${headers})
endforeach()

# Sort file lists to ensure generated files are created in the same order from
# build to build.
list(SORT NVIM_SOURCES)
list(SORT NVIM_HEADERS)

foreach(sfile ${NVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(WIN32 AND ${f} MATCHES "^(pty_proc_unix.c)$")
    list(REMOVE_ITEM NVIM_SOURCES ${sfile})
  endif()
  if(NOT WIN32 AND ${f} MATCHES "^(pty_proc_win.c)$")
    list(REMOVE_ITEM NVIM_SOURCES ${sfile})
  endif()
  if(NOT WIN32 AND ${f} MATCHES "^(pty_conpty_win.c)$")
    list(REMOVE_ITEM NVIM_SOURCES ${sfile})
  endif()
  if(NOT WIN32 AND ${f} MATCHES "^(os_win_console.c)$")
    list(REMOVE_ITEM NVIM_SOURCES ${sfile})
  endif()
endforeach()

foreach(hfile ${NVIM_HEADERS})
  get_filename_component(f ${hfile} NAME)
  if(WIN32 AND ${f} MATCHES "^(unix_defs.h)$")
    list(REMOVE_ITEM NVIM_HEADERS ${hfile})
  endif()
  if(WIN32 AND ${f} MATCHES "^(pty_proc_unix.h)$")
    list(REMOVE_ITEM NVIM_HEADERS ${hfile})
  endif()
  if(NOT WIN32 AND ${f} MATCHES "^(win_defs.h)$")
    list(REMOVE_ITEM NVIM_HEADERS ${hfile})
  endif()
endforeach()

list(APPEND LINT_NVIM_SOURCES ${NVIM_SOURCES} ${NVIM_HEADERS})

# Log level (NVIM_LOG_DEBUG in log.h)
if(CI_BUILD)
  # Don't debug log on CI, it gets too verbose in the main build log.
  # TODO(bfredl): debug log level also exposes some errors with EXITFREE in ASAN build.
else()
  # Minimize logging for release-type builds.
  target_compile_definitions(nvim_bin PRIVATE $<$<CONFIG:Debug>:NVIM_LOG_DEBUG>)
endif()

if(ENABLE_ASAN_UBSAN OR ENABLE_MSAN OR ENABLE_TSAN)
  target_compile_definitions(main_lib INTERFACE EXITFREE)
endif()

#-------------------------------------------------------------------------------
# Header generation
#-------------------------------------------------------------------------------

get_target_property(prop main_lib INTERFACE_COMPILE_DEFINITIONS)
if(NOT "${prop}" STREQUAL "prop-NOTFOUND")
  foreach(gen_cdef ${prop})
    if(NOT ${gen_cdef} MATCHES "INCLUDE_GENERATED_DECLARATIONS")
      list(APPEND gen_cflags "-D${gen_cdef}")
    endif()
  endforeach()
endif()

get_directory_property(targets BUILDSYSTEM_TARGETS)
foreach(target ${targets})
  get_target_property(prop ${target} INTERFACE_INCLUDE_DIRECTORIES)
  if(NOT "${prop}" STREQUAL "prop-NOTFOUND")
    message(STATUS "${target} props '${prop}'")
    foreach(gen_include ${prop})
      list(APPEND gen_cflags "-I${gen_include}")
    endforeach()
  endif()
endforeach()

list(REMOVE_DUPLICATES gen_cflags)

if(APPLE AND CMAKE_OSX_SYSROOT)
  list(APPEND gen_cflags "-isysroot" "${CMAKE_OSX_SYSROOT}")
endif()
if(MSVC)
  list(APPEND gen_cflags -wd4003)
endif()

set(NVIM_VERSION_GIT_H ${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef_git.h)
add_custom_target(update_version_stamp
  COMMAND ${CMAKE_COMMAND}
    -D NVIM_VERSION_MAJOR=${NVIM_VERSION_MAJOR}
    -D NVIM_VERSION_MINOR=${NVIM_VERSION_MINOR}
    -D NVIM_VERSION_PATCH=${NVIM_VERSION_PATCH}
    -D NVIM_VERSION_PRERELEASE=${NVIM_VERSION_PRERELEASE}
    -D OUTPUT=${NVIM_VERSION_GIT_H}
    -D NVIM_SOURCE_DIR=${CMAKE_SOURCE_DIR}
    -P ${PROJECT_SOURCE_DIR}/cmake/GenerateVersion.cmake
  BYPRODUCTS ${NVIM_VERSION_GIT_H})

set(NVIM_VERSION_DEF_H ${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef.h)
add_custom_command(
  OUTPUT "${NVIM_VERSION_DEF_H}"
  COMMAND "${CMAKE_COMMAND}"
    -E copy
    "${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef-$<CONFIG>.h"
    "${NVIM_VERSION_DEF_H}"
  DEPENDS "${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef-$<CONFIG>.h")

set(LUA_GEN ${LUA_GEN_PRG} ${GENERATOR_PRELOAD} ${PROJECT_SOURCE_DIR} $<TARGET_FILE:nlua0> ${PROJECT_BINARY_DIR})
set(LUA_GEN_DEPS ${GENERATOR_PRELOAD} $<TARGET_FILE:nlua0>)

# NVIM_GENERATED_FOR_HEADERS: generated headers to be included in headers
# NVIM_GENERATED_FOR_SOURCES: generated headers to be included in sources
# These lists must be mutually exclusive.
foreach(sfile ${NVIM_SOURCES}
              ${NVIM_HEADERS}
              ${GENERATED_API_DISPATCH}
              "${GENERATED_UI_EVENTS_CALL}"
              "${GENERATED_UI_EVENTS_REMOTE}"
              "${GENERATED_UI_EVENTS_CLIENT}"
              )
  get_filename_component(full_d ${sfile} DIRECTORY)
  file(RELATIVE_PATH d "${CMAKE_CURRENT_LIST_DIR}" "${full_d}")
  if(${d} MATCHES "^[.][.]|auto/")
    file(RELATIVE_PATH d "${GENERATED_DIR}" "${full_d}")
  endif()
  get_filename_component(f ${sfile} NAME)
  get_filename_component(r ${sfile} NAME_WE)
  get_filename_component(ext ${sfile} EXT)
  if(NOT ${d} EQUAL ".")
    set(f "${d}/${f}")
    set(r "${d}/${r}")
  endif()
  if ("${ext}" STREQUAL ".c.h")
    continue() # .c.h files are sussy baka, skip
  elseif(${sfile} IN_LIST NVIM_HEADERS)
    set(gf_basename "${r}.h.inline.generated.h")
    set(gf_c_h "${GENERATED_INCLUDES_DIR}/${r}.h.inline.generated.h")
    set(gf_h_h "SKIP")
    set(gf_h_h_out "")
  else()
    set(gf_basename "${r}.c.generated.h")
    set(gf_c_h "${GENERATED_DIR}/${r}.c.generated.h")
    set(gf_h_h "${GENERATED_INCLUDES_DIR}/${r}.h.generated.h")
    set(gf_h_h_out "${gf_h_h}")
  endif()
  set(gf_i "${GENERATED_DIR}/${f}.i")

  if(MSVC)
    set(PREPROC_OUTPUT /P /Fi${gf_i} /nologo)
  else()
    set(PREPROC_OUTPUT -w -E -o ${gf_i})
  endif()

  set(depends "${HEADER_GENERATOR}" "${sfile}" "${LUA_GEN_DEPS}")
  if("${f}" STREQUAL "version.c")
    # Ensure auto/versiondef_git.h exists after "make clean".
    list(APPEND depends update_version_stamp "${NVIM_VERSION_GIT_H}" "${NVIM_VERSION_DEF_H}")
  endif()
  add_custom_command(
    OUTPUT "${gf_c_h}" ${gf_h_h_out}
    COMMAND ${CMAKE_C_COMPILER} ${sfile} ${PREPROC_OUTPUT} ${gen_cflags}
    COMMAND ${LUA_GEN} "${HEADER_GENERATOR}" "${sfile}" "${gf_c_h}" "${gf_h_h}" "${gf_i}" "${gf_basename}"
    DEPENDS ${depends})
  list(APPEND NVIM_GENERATED_FOR_SOURCES "${gf_c_h}")
  if (NOT ${sfile} IN_LIST NVIM_HEADERS)
    list(APPEND NVIM_GENERATED_FOR_HEADERS "${gf_h_h}")
    if(${d} MATCHES "^api$" AND NOT ${f} MATCHES "^api/helpers.c$")
      list(APPEND API_HEADERS ${gf_h_h})
    endif()
  endif()
endforeach()

set(NVIM_VERSION_LUA ${PROJECT_BINARY_DIR}/nvim_version.lua)
configure_file(${GENERATOR_DIR}/nvim_version.lua.in ${NVIM_VERSION_LUA})

add_custom_command(
  OUTPUT ${GENERATED_API_DISPATCH} ${GENERATED_API_METADATA}
  ${FUNCS_METADATA} ${LUA_API_C_BINDINGS} ${GENERATED_KEYSETS_DEFS}
         COMMAND ${LUA_GEN} ${API_DISPATCH_GENERATOR}
                         ${GENERATED_API_DISPATCH}
                         ${GENERATED_API_METADATA} ${FUNCS_METADATA}
                         ${LUA_API_C_BINDINGS}
                         ${GENERATED_KEYSETS_DEFS}
                         ${UI_METADATA}
                         ${NVIM_VERSION_GIT_H}
                         ${API_HEADERS}
  DEPENDS
    ${LUA_GEN_DEPS}
    ${API_HEADERS}
    ${MSGPACK_RPC_HEADERS}
    ${API_DISPATCH_GENERATOR}
    ${GENERATOR_C_GRAMMAR}
    ${UI_METADATA}
    ${NVIM_VERSION_LUA}
    ${NVIM_VERSION_GIT_H}
    ${CMAKE_CURRENT_LIST_DIR}/api/dispatch_deprecated.lua
)

add_custom_command(
  OUTPUT ${VIM_MODULE_FILE}
  COMMAND ${CMAKE_COMMAND} -E env
      "LUAC_PRG=${LUAC_PRG}"
      ${LUA_PRG} ${CHAR_BLOB_GENERATOR} -c ${VIM_MODULE_FILE}
      # NB: vim._init_packages and vim.inspect must be be first and second ones
      # respectively, otherwise --luamod-dev won't work properly.
      ${LUA_INIT_PACKAGES_MODULE_SOURCE} "vim._init_packages"
      ${LUA_INSPECT_MODULE_SOURCE} "vim.inspect"
      ${LUA_EDITOR_MODULE_SOURCE} "vim._editor"
      ${LUA_FILETYPE_MODULE_SOURCE} "vim.filetype"
      ${LUA_FS_MODULE_SOURCE} "vim.fs"
      ${LUA_F_MODULE_SOURCE} "vim.F"
      ${LUA_KEYMAP_MODULE_SOURCE} "vim.keymap"
      ${LUA_LOADER_MODULE_SOURCE} "vim.loader"
      ${LUA_DEFAULTS_MODULE_SOURCE} "vim._defaults"
      ${LUA_OPTIONS_MODULE_SOURCE} "vim._options"
      ${LUA_SHARED_MODULE_SOURCE} "vim.shared"
  DEPENDS
    ${CHAR_BLOB_GENERATOR}
    ${LUA_INIT_PACKAGES_MODULE_SOURCE}
    ${LUA_INSPECT_MODULE_SOURCE}
    ${LUA_EDITOR_MODULE_SOURCE}
    ${LUA_FILETYPE_MODULE_SOURCE}
    ${LUA_FS_MODULE_SOURCE}
    ${LUA_F_MODULE_SOURCE}
    ${LUA_KEYMAP_MODULE_SOURCE}
    ${LUA_LOADER_MODULE_SOURCE}
    ${LUA_DEFAULTS_MODULE_SOURCE}
    ${LUA_OPTIONS_MODULE_SOURCE}
    ${LUA_SHARED_MODULE_SOURCE}
  VERBATIM
)

add_custom_command(
  OUTPUT ${GENERATED_UI_EVENTS_CALL}
         ${GENERATED_UI_EVENTS_REMOTE}
         ${UI_METADATA}
         ${GENERATED_UI_EVENTS_CLIENT}
  COMMAND ${LUA_GEN} ${API_UI_EVENTS_GENERATOR}
                     ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h
                     ${GENERATED_UI_EVENTS_CALL}
                     ${GENERATED_UI_EVENTS_REMOTE}
                     ${UI_METADATA}
                     ${GENERATED_UI_EVENTS_CLIENT}
  DEPENDS
    ${LUA_GEN_DEPS}
    ${API_UI_EVENTS_GENERATOR}
    ${GENERATOR_C_GRAMMAR}
    ${CMAKE_CURRENT_LIST_DIR}/api/ui_events.in.h
)

list(APPEND NVIM_GENERATED_FOR_HEADERS
  "${GENERATED_EX_CMDS_ENUM}"
  "${GENERATED_EVENTS_ENUM}"
  "${GENERATED_KEYSETS_DEFS}"
  "${GENERATED_OPTIONS_ENUM}"
  "${GENERATED_OPTION_VARS}"
)

list(APPEND NVIM_GENERATED_FOR_SOURCES
  "${GENERATED_API_DISPATCH}"
  "${GENERATED_EX_CMDS_DEFS}"
  "${GENERATED_EVENTS_NAMES_MAP}"
  "${GENERATED_OPTIONS}"
  "${GENERATED_OPTIONS_MAP}"
  "${VIM_MODULE_FILE}"
  "${PROJECT_BINARY_DIR}/cmake.config/auto/pathdef.h"
)

add_custom_command(OUTPUT ${GENERATED_EX_CMDS_ENUM} ${GENERATED_EX_CMDS_DEFS}
  COMMAND ${LUA_GEN} ${EX_CMDS_GENERATOR} ${GENERATED_INCLUDES_DIR} ${GENERATED_DIR}
  DEPENDS ${LUA_GEN_DEPS} ${EX_CMDS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/ex_cmds.lua
)

add_custom_command(OUTPUT ${GENERATED_FUNCS} ${FUNCS_DATA}
  COMMAND ${LUA_GEN} ${FUNCS_GENERATOR} ${GENERATED_DIR} ${FUNCS_METADATA} ${FUNCS_DATA}
  DEPENDS ${LUA_GEN_DEPS} ${FUNCS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/eval.lua ${FUNCS_METADATA}
)
list(APPEND NVIM_GENERATED_FOR_SOURCES
  "${GENERATED_FUNCS}")

add_custom_command(OUTPUT ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  COMMAND ${LUA_GEN} ${EVENTS_GENERATOR} ${GENERATED_EVENTS_ENUM} ${GENERATED_EVENTS_NAMES_MAP}
  DEPENDS ${LUA_GEN_DEPS} ${EVENTS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/auevents.lua
)

add_custom_command(OUTPUT ${GENERATED_OPTIONS} ${GENERATED_OPTIONS_ENUM} ${GENERATED_OPTIONS_MAP} ${GENERATED_OPTION_VARS}
  COMMAND ${LUA_GEN} ${OPTIONS_GENERATOR} ${GENERATED_OPTIONS} ${GENERATED_OPTIONS_ENUM} ${GENERATED_OPTIONS_MAP} ${GENERATED_OPTION_VARS}
  DEPENDS ${LUA_GEN_DEPS} ${OPTIONS_GENERATOR} ${CMAKE_CURRENT_LIST_DIR}/options.lua
)

# NVIM_GENERATED_FOR_SOURCES and NVIM_GENERATED_FOR_HEADERS must be mutually exclusive.
foreach(hfile ${NVIM_GENERATED_FOR_HEADERS})
  list(FIND NVIM_GENERATED_FOR_SOURCES ${hfile} hfile_idx)
  if(NOT ${hfile_idx} EQUAL -1)
    message(FATAL_ERROR "File included in both NVIM_GENERATED_FOR_HEADERS and NVIM_GENERATED_FOR_SOURCES")
  endif()
endforeach()

if(PREFER_LUA)
  message(STATUS "luajit not used, skipping unit tests")
else()
  file(GLOB UNIT_TEST_FIXTURES CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/test/unit/fixtures/*.c)
  target_sources(nvim_bin PRIVATE ${UNIT_TEST_FIXTURES})
  target_compile_definitions(nvim_bin PRIVATE UNIT_TESTING)
endif()

target_sources(main_lib INTERFACE
  ${NVIM_GENERATED_FOR_SOURCES}
  ${NVIM_GENERATED_FOR_HEADERS}
  ${NVIM_SOURCES}
  ${NVIM_HEADERS}
  ${EXTERNAL_SOURCES}
  ${EXTERNAL_HEADERS})

if(WIN32)
  # add windows resource file pointing to the neovim icon
  # this makes the icon appear for the neovim exe and associated filetypes
  target_sources(nvim_bin PRIVATE ${NVIM_RUNTIME_DIR}/windows_icon.rc)
endif()

target_sources(nlua0 PUBLIC ${NLUA0_SOURCES})

target_link_libraries(nvim_bin PRIVATE main_lib PUBLIC libuv)
install_helper(TARGETS nvim_bin)
if(MSVC)
  install(FILES $<TARGET_PDB_FILE:nvim_bin> DESTINATION ${CMAKE_INSTALL_BINDIR} OPTIONAL)
endif()

if(ENABLE_LTO)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT IPO_SUPPORTED)
  if(IPO_SUPPORTED)
    set_target_properties(nvim_bin PROPERTIES
      INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE
      INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO TRUE
      INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL TRUE)
  endif()
endif()

add_custom_target(nvim_runtime_deps)
if(WIN32)
  # Copy DLLs and third-party tools to bin/ and install them along with nvim
  add_custom_command(TARGET nvim_runtime_deps
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E ${COPY_DIRECTORY} ${PROJECT_BINARY_DIR}/windows_runtime_deps/
      ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
  install(DIRECTORY ${PROJECT_BINARY_DIR}/windows_runtime_deps/
    DESTINATION ${CMAKE_INSTALL_BINDIR})

  add_custom_target(nvim_dll_deps DEPENDS nvim_bin
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/windows_runtime_deps
    COMMAND ${CMAKE_COMMAND}
      -D CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}
      -D BINARY="${PROJECT_BINARY_DIR}/bin/nvim${CMAKE_EXECUTABLE_SUFFIX}"
      -D DST=${PROJECT_BINARY_DIR}/windows_runtime_deps
      -D CI_BUILD=${CI_BUILD}
      -P ${PROJECT_SOURCE_DIR}/cmake/WindowsDllCopy.cmake)
  add_dependencies(nvim_runtime_deps nvim_dll_deps)

  # A CMake script is used for copying the files to avoid the
  # "command line is too long" error that occurs when Ninja tries running
  # a command that exceeds the length limit (8191 characters) on Windows.
  # See https://developercommunity.visualstudio.com/content/problem/212207/file-open-cmake-the-command-line-is-too-long.html
  set(EXTERNAL_BLOBS_SCRIPT
    "file(MAKE_DIRECTORY \"${PROJECT_BINARY_DIR}/windows_runtime_deps/platforms\")")
  foreach(DEP_FILE IN ITEMS
      cat.exe
      tee.exe
      win32yank.exe
      xxd.exe)
  get_filename_component(DEP_FILE_DIR ${DEP_FILE} DIRECTORY)
  set(EXTERNAL_BLOBS_SCRIPT "${EXTERNAL_BLOBS_SCRIPT}\n"
    "file(COPY \"${DEPS_PREFIX}/bin/${DEP_FILE}\"
    DESTINATION \"${PROJECT_BINARY_DIR}/windows_runtime_deps/${DEP_FILE_DIR}\")")
  endforeach()
  file(WRITE ${PROJECT_BINARY_DIR}/external_blobs.cmake ${EXTERNAL_BLOBS_SCRIPT})
  add_custom_target(external_blobs
    COMMAND ${CMAKE_COMMAND} -P ${PROJECT_BINARY_DIR}/external_blobs.cmake)
  add_dependencies(nvim_runtime_deps external_blobs)
endif()

file(MAKE_DIRECTORY ${BINARY_LIB_DIR})

# install treesitter parser if bundled
if(EXISTS ${DEPS_PREFIX}/lib/nvim/parser)
  add_custom_command(
    TARGET nvim_runtime_deps
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E ${COPY_DIRECTORY} ${DEPS_PREFIX}/lib/nvim/parser ${BINARY_LIB_DIR}/parser)
endif()

install(DIRECTORY ${BINARY_LIB_DIR}
  DESTINATION ${CMAKE_INSTALL_LIBDIR}
  USE_SOURCE_PERMISSIONS)

if(NOT PREFER_LUA)
  # install luajit runtime files if bundled
  if(EXISTS ${LUAJIT_RUNTIME_DIR})
    install(DIRECTORY ${LUAJIT_RUNTIME_DIR}
      DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/lua
      USE_SOURCE_PERMISSIONS)
  endif()
endif()

add_library(libnvim STATIC EXCLUDE_FROM_ALL)
if(MSVC)
  set(LIBNVIM_NAME libnvim)
else()
  set(LIBNVIM_NAME nvim)
endif()
set_target_properties(
  libnvim
  PROPERTIES
    OUTPUT_NAME ${LIBNVIM_NAME}
)
target_compile_definitions(libnvim PRIVATE MAKE_LIB)
target_link_libraries(libnvim PRIVATE main_lib PUBLIC libuv)

#-------------------------------------------------------------------------------
# Lint
#-------------------------------------------------------------------------------

find_program(CLANG_TIDY_PRG clang-tidy)
set(EXCLUDE_CLANG_TIDY typval_encode.c.h ui_events.in.h)
if(WIN32)
  list(APPEND EXCLUDE_CLANG_TIDY
    os/pty_proc_unix.h
    os/unix_defs.h)
else()
  list(APPEND EXCLUDE_CLANG_TIDY
    os/win_defs.h
    os/pty_proc_win.h
    os/pty_conpty_win.h
    os/os_win_console.h)
endif()
add_glob_target(
  TARGET lintc-clang-tidy
  COMMAND ${CLANG_TIDY_PRG}
  FILES ${LINT_NVIM_SOURCES}
  FLAGS --quiet
  EXCLUDE ${EXCLUDE_CLANG_TIDY})

# The checks we ignore are meant to be removed eventually, but we can only
# enable each warning after we fix all instances of that specific warning as to
# not break CI.
if(APPLE)
  string(APPEND CLANG_ANALYZER_IGNORE "-clang-analyzer-core.NonNullParamChecker,")
endif()
add_glob_target(
  TARGET clang-analyzer
  COMMAND ${CLANG_TIDY_PRG}
  FILES ${LINT_NVIM_SOURCES}
  FLAGS --quiet
  --checks='
  -*,
  clang-analyzer-*,
  -clang-analyzer-core.NullDereference,
  -clang-analyzer-core.UndefinedBinaryOperatorResult,
  -clang-analyzer-core.uninitialized.Assign,
  -clang-analyzer-optin.core.EnumCastOutOfRange,
  -clang-analyzer-optin.performance.Padding,
  -clang-analyzer-security.insecureAPI.strcpy,
  -clang-analyzer-unix.StdCLibraryFunctions,
  -clang-analyzer-unix.Stream,
  ${CLANG_ANALYZER_IGNORE}
  '
  EXCLUDE ${EXCLUDE_CLANG_TIDY})

add_custom_target(copy_compile_commands
  COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/compile_commands.json ${PROJECT_SOURCE_DIR}/compile_commands.json)
add_dependencies(copy_compile_commands nvim_bin)
add_dependencies(lintc-clang-tidy copy_compile_commands)
add_dependencies(clang-analyzer copy_compile_commands)

if(CI_BUILD)
  set(LINT_OUTPUT_FORMAT gh_action)
else()
  set(LINT_OUTPUT_FORMAT vs7)
endif()
add_glob_target(
  TARGET lintc-clint
  COMMAND ${PROJECT_SOURCE_DIR}/src/clint.py
  FLAGS --output=${LINT_OUTPUT_FORMAT}
  FILES ${LINT_NVIM_SOURCES}
  EXCLUDE
    tui/terminfo_defs.h)

set(UNCRUSTIFY_PRG ${DEPS_BIN_DIR}/uncrustify)
set(UNCRUSTIFY_CONFIG ${PROJECT_SOURCE_DIR}/src/uncrustify.cfg)

add_custom_target(uncrustify_update_config
  ${UNCRUSTIFY_PRG} -c ${UNCRUSTIFY_CONFIG} --update-config-with-doc -o ${UNCRUSTIFY_CONFIG})

add_glob_target(
  TARGET lintc-uncrustify
  COMMAND ${UNCRUSTIFY_PRG}
  FLAGS -c ${UNCRUSTIFY_CONFIG} -q --check
  FILES ${NVIM_SOURCES} ${NVIM_HEADERS})

add_glob_target(
  TARGET formatc
  COMMAND ${UNCRUSTIFY_PRG}
  FLAGS -c ${UNCRUSTIFY_CONFIG} --replace --no-backup
  FILES ${NVIM_SOURCES} ${NVIM_HEADERS})

add_dependencies(lintc-uncrustify uncrustify_update_config)
add_dependencies(formatc uncrustify_update_config)
add_dependencies(uncrustify_update_config uncrustify)

add_custom_target(lintc)
add_dependencies(lintc lintc-clint lintc-uncrustify lintc-clang-tidy)

#-------------------------------------------------------------------------------
# Docs
#-------------------------------------------------------------------------------

add_subdirectory(po)

add_custom_target(generated-sources DEPENDS
  ${NVIM_GENERATED_FOR_HEADERS}
  ${NVIM_GENERATED_FOR_SOURCES}
)

file(GLOB API_SOURCES CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/src/nvim/api/*.c)

file(GLOB LUA_SOURCES CONFIGURE_DEPENDS
  ${NVIM_RUNTIME_DIR}/lua/vim/*.lua
  ${NVIM_RUNTIME_DIR}/lua/vim/_meta/*.lua
  ${NVIM_RUNTIME_DIR}/lua/vim/filetype/*.lua
  ${NVIM_RUNTIME_DIR}/lua/vim/lsp/*.lua
  ${NVIM_RUNTIME_DIR}/lua/vim/treesitter/*.lua
)

add_target(doc-vim
  COMMAND $<TARGET_FILE:nvim_bin> -u NONE -l scripts/gen_vimdoc.lua
  DEPENDS
    nvim
    ${API_SOURCES}
    ${LUA_SOURCES}
    ${PROJECT_SOURCE_DIR}/scripts/gen_vimdoc.lua
    ${NVIM_RUNTIME_DIR}/doc/api.txt
    ${NVIM_RUNTIME_DIR}/doc/diagnostic.txt
    ${NVIM_RUNTIME_DIR}/doc/lsp.txt
    ${NVIM_RUNTIME_DIR}/doc/lua.txt
    ${NVIM_RUNTIME_DIR}/doc/treesitter.txt
  )

add_target(doc-eval
  COMMAND $<TARGET_FILE:nvim_bin> -u NONE -l ${PROJECT_SOURCE_DIR}/scripts/gen_eval_files.lua
  DEPENDS
    nvim
    ${FUNCS_METADATA}
    ${PROJECT_SOURCE_DIR}/scripts/gen_eval_files.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/eval.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/options.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/vvars.lua
    ${NVIM_RUNTIME_DIR}/doc/builtin.txt
  )

add_custom_target(doc)
add_dependencies(doc doc-vim doc-eval)

add_target(lintdoc
  COMMAND $<TARGET_FILE:nvim_bin> -u NONE -l scripts/lintdoc.lua
  DEPENDS ${DOCFILES}
  CUSTOM_COMMAND_ARGS USES_TERMINAL)
add_dependencies(lintdoc nvim)
