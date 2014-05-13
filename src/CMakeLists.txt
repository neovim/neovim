include(CheckLibraryExists)

set(GENERATED_DIR ${PROJECT_BINARY_DIR}/src/auto)
set(DISPATCH_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/msgpack-gen.lua)
file(GLOB API_HEADERS api/*.h)
set(MSGPACK_RPC_HEADER ${PROJECT_SOURCE_DIR}/src/os/msgpack_rpc.h)
set(MSGPACK_DISPATCH ${GENERATED_DIR}/msgpack_dispatch.c)

# Remove helpers.h from API_HEADERS since it doesn't contain public API
# functions
foreach(sfile ${API_HEADERS})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(helpers.h)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()
list(REMOVE_ITEM API_HEADERS ${to_remove})
set(to_remove)

file(MAKE_DIRECTORY ${GENERATED_DIR})

add_custom_command(OUTPUT ${MSGPACK_DISPATCH}
  COMMAND ${LUA_PRG} ${DISPATCH_GENERATOR} ${API_HEADERS} ${MSGPACK_DISPATCH}
  DEPENDS
    ${API_HEADERS}
    ${MSGPACK_RPC_HEADER}
    ${DISPATCH_GENERATOR}
    )

file( GLOB NEOVIM_SOURCES *.c )

foreach(sfile ${NEOVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NEOVIM_SOURCES ${to_remove})
list(APPEND NEOVIM_SOURCES "${PROJECT_BINARY_DIR}/config/auto/pathdef.c")
list(APPEND NEOVIM_SOURCES "${MSGPACK_DISPATCH}")

file( GLOB OS_SOURCES os/*.c )
file( GLOB API_SOURCES api/*.c )

set(CONV_SRCS
  api.c
  arabic.c
  garray.c
  memory.c
  os/env.c
  os/event.c
  os/job.c
  os/mem.c
  os/rstream.c
  os/signal.c
  os/users.c
  os/wstream.c
  )

set_source_files_properties(
  ${CONV_SRCS} PROPERTIES COMPILE_FLAGS "${COMPILE_FLAGS} -Wconversion")

if(CMAKE_C_COMPILER_ID MATCHES "Clang")
  if(DEFINED ENV{SANITIZE})
    message(STATUS "Enabling the sanitizers")
    add_definitions(-DEXITFREE) # is this necessary for LeakSanitizer?
    add_definitions(-fno-sanitize-recover -fno-omit-frame-pointer
      -fno-optimize-sibling-calls -fsanitize=address -fsanitize=undefined)
    set(CMAKE_EXE_LINKER_FLAGS
      "-fsanitize=address -fsanitize=undefined ${CMAKE_EXE_LINKER_FLAGS}")
    set(CMAKE_SHARED_LINKER_FLAGS
      "-fsanitize=address -fsanitize=undefined ${CMAKE_SHARED_LINKER_FLAGS}")
  endif()
endif()

# Our dependencies come first.

if (LibIntl_FOUND)
  list(APPEND NVIM_LINK_LIBRARIES ${LibIntl_LIBRARY})
endif()

check_library_exists(curses tgetent "" HAVE_LIBCURSES)
if (HAVE_LIBCURSES)
  list(APPEND NVIM_LINK_LIBRARIES curses)
else()
  check_library_exists(tinfo tgetent "" HAVE_LIBTINFO)
  if (HAVE_LIBTINFO)
    list(APPEND NVIM_LINK_LIBRARIES tinfo)
  else()
    find_package(Curses REQUIRED)
    list(APPEND NVIM_LINK_LIBRARIES ${CURSES_LIBRARIES})
  endif()
endif()

# Put these last on the link line, since multiple things may depend on them.
list(APPEND NVIM_LINK_LIBRARIES
    ${LIBUV_LIBRARIES}
    ${MSGPACK_LIBRARIES}
    ${LUAJIT_LIBRARIES}
    m
    ${CMAKE_THREAD_LIBS_INIT})

if(NOT DEFINED ENV{SKIP_EXEC})
  add_executable(nvim ${NEOVIM_SOURCES} ${OS_SOURCES} ${API_SOURCES})
  target_link_libraries(nvim ${NVIM_LINK_LIBRARIES})
  install(TARGETS nvim RUNTIME DESTINATION bin)
endif()

if(NOT DEFINED ENV{SKIP_UNITTEST})
  add_library(nvim-test MODULE EXCLUDE_FROM_ALL ${NEOVIM_SOURCES} ${OS_SOURCES})
  target_link_libraries(nvim-test ${NVIM_LINK_LIBRARIES})
endif()
