set(NEOVIM_SOURCES
    blowfish.c
    buffer.c
    charset.c
    diff.c
    digraph.c
    edit.c
    eval.c
    ex_cmds2.c
    ex_cmds.c
    ex_docmd.c
    ex_eval.c
    ex_getln.c
    fileio.c
    fold.c
    getchar.c
    hangulin.c
    hardcopy.c
    hashtab.c
    if_cscope.c
    main.c
    mark.c
    mbyte.c
    memfile.c
    memline.c
    menu.c
    message.c
    misc1.c
    misc2.c
    move.c
    normal.c
    ops.c
    option.c
    os_unix.c
    popupmnu.c
    quickfix.c
    regexp.c
    screen.c
    search.c
    sha256.c
    spell.c
    syntax.c
    tag.c
    term.c
    ui.c
    undo.c
    version.c
    window.c
   )
list(APPEND NEOVIM_SOURCES "${PROJECT_BINARY_DIR}/config/auto/pathdef.c")

set(OS_SOURCES
    os/fs.c
    os/mem.c
   )

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
