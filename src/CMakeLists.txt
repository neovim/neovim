file( GLOB NEOVIM_SOURCES *.c )

foreach(sfile ${NEOVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c|farsi.c|arabic.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NEOVIM_SOURCES ${to_remove})
list(APPEND NEOVIM_SOURCES "${PROJECT_BINARY_DIR}/config/auto/pathdef.c")

file( GLOB IO_SOURCES io/*.c )

add_executable (vim ${NEOVIM_SOURCES} ${IO_SOURCES}) 

target_link_libraries (vim m pthread)

include(CheckLibraryExists)
check_library_exists(termcap tgetent "" HAVE_LIBTERMCAP)

if (HAVE_LIBTERMCAP)
  target_link_libraries(vim termcap)
else()
  check_library_exists(curses tgetent "" HAVE_LIBCURSES)
  if (HAVE_LIBCURSES)
    target_link_libraries(vim curses)
  else()
    message(FATAL_ERROR "can't find something resembling -ltermcap")
  endif()
endif()

find_library(LIBUV uv)
if (${LIBUV} STREQUAL "LIBUV-NOTFOUND")
  find_library(LIBUV uv PATHS "${DEPS_LIB_PATH}")
  if (${LIBUV} STREQUAL "LIBUV-NOTFOUND" AND FetchLibuv)
    execute_process(COMMAND sh -e scripts/get-libuv.sh WORKING_DIRECTORY ..)
    find_library(LIBUV uv PATHS "${DEPS_LIB_PATH}")
    if (${LIBUV} STREQUAL "LIBUV-NOTFOUND")
      message(FATAL_ERROR "can't find libuv")
    endif()
  else()
    message(FATAL_ERROR "can't find system libuv and fetching of libuv is disabled")
  endif()
endif()
target_link_libraries(vim uv)

include_directories ("${PROJECT_SOURCE_DIR}/src/proto") 
