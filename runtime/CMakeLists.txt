set(SYN_VIM_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genvimvim.lua)
set(GENERATED_RUNTIME_DIR ${PROJECT_BINARY_DIR}/runtime)
set(GENERATED_SYN_VIM ${GENERATED_RUNTIME_DIR}/syntax/vim/generated.vim)
set(GENERATED_HELP_TAGS ${GENERATED_RUNTIME_DIR}/doc/tags)

file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR})
file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR}/syntax)
file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR}/syntax/vim)

add_custom_command(OUTPUT ${GENERATED_SYN_VIM}
  COMMAND ${LUA_PRG} ${SYN_VIM_GENERATOR}
          ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_SYN_VIM}
  DEPENDS
    ${SYN_VIM_GENERATOR}
    ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/auevents.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/options.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/eval.c
)

file(GLOB DOCFILES ${PROJECT_SOURCE_DIR}/runtime/doc/*.txt)

add_custom_command(OUTPUT ${GENERATED_HELP_TAGS}
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${PROJECT_SOURCE_DIR}/runtime/doc ${GENERATED_RUNTIME_DIR}/doc
  COMMAND "${PROJECT_BINARY_DIR}/bin/nvim"
    -u NONE
    -i NONE
    -esX
    -c "helptags ++t ."
    -c quit
  DEPENDS
    ${DOCFILES}
    nvim
  WORKING_DIRECTORY "${HELPTAGS_WORKING_DIRECTORY}"
)

add_custom_target(
  runtime ALL
  DEPENDS
    ${GENERATED_SYN_VIM}
    ${GENERATED_HELP_TAGS}
)

# CMake is painful here.  It will create the destination using the user's
# current umask, and we don't want that.  And we don't just want to install
# the target directory, as it will mess with existing permissions.  So this
# seems like the best compromise.  If we create it, then everyone can see it.
# If it's preexisting, leave it alone.

install_helper(
  DIRECTORY ${PROJECT_SOURCE_DIR}/runtime
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim)
install_helper(
  DIRECTORY ${GENERATED_RUNTIME_DIR}
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim)

file(GLOB_RECURSE RUNTIME_PROGRAMS
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  *.awk *.sh)

foreach(PROG ${RUNTIME_PROGRAMS})
  get_filename_component(BASEDIR ${PROG} PATH)
  install_helper(PROGRAMS ${PROG}
                 DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/${BASEDIR})
endforeach()
