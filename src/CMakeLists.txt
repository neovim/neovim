file( GLOB NEOVIM_SOURCES *.c )

foreach(sfile ${NEOVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c|farsi.c|arabic.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NEOVIM_SOURCES ${to_remove})
list(APPEND NEOVIM_SOURCES "${PROJECT_BINARY_DIR}/config/auto/pathdef.c")

file( GLOB OS_SOURCES os/*.c )

add_executable (nvim ${NEOVIM_SOURCES} ${OS_SOURCES})
add_library (nvim-test MODULE ${NEOVIM_SOURCES} ${OS_SOURCES})

# The libraries we link against for nvim
set(NVIM_LINK_LIBRARIES m ${LibUV_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT})

# Add any libraries needed for a specific platform
if(HAVE_CLOCK_GETTIME)
  # Work around libuv.a not linking in rt.
  list(APPEND NVIM_LINK_LIBRARIES rt)
endif(HAVE_CLOCK_GETTIME)

if (LibIntl_FOUND)
  list(APPEND NVIM_LINK_LIBRARIES ${LibIntl_LIBRARY})
endif()

target_link_libraries (nvim ${NVIM_LINK_LIBRARIES})
target_link_libraries (nvim-test ${NVIM_LINK_LIBRARIES})

include(CheckLibraryExists)
check_library_exists(termcap tgetent "" HAVE_LIBTERMCAP)

if (HAVE_LIBTERMCAP)
  target_link_libraries(nvim termcap)
  target_link_libraries(nvim-test termcap)
else()
  check_library_exists(curses tgetent "" HAVE_LIBCURSES)
  if (HAVE_LIBCURSES)
    target_link_libraries(nvim curses)
    target_link_libraries(nvim-test curses)
  else()
    find_package(Curses REQUIRED)
    target_link_libraries(nvim ${CURSES_LIBRARIES})
    target_link_libraries(nvim-test ${CURSES_LIBRARIES})
  endif()
endif()

include_directories ("${PROJECT_SOURCE_DIR}/src/proto") 

install(TARGETS nvim RUNTIME DESTINATION bin)
