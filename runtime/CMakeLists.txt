set(GENERATED_RUNTIME_DIR ${PROJECT_BINARY_DIR}/runtime)

set(GENERATED_HELP_TAGS ${GENERATED_RUNTIME_DIR}/doc/tags)
set(GENERATED_PACKAGE_DIR ${GENERATED_RUNTIME_DIR}/pack/dist/opt)
set(GENERATED_SYN_VIM ${GENERATED_RUNTIME_DIR}/syntax/vim/generated.vim)
set(SYN_VIM_GENERATOR ${PROJECT_SOURCE_DIR}/src/gen/gen_vimvim.lua)

file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR}/syntax/vim)

get_directory_property(LUA_GEN DIRECTORY ${PROJECT_SOURCE_DIR}/src/nvim DEFINITION LUA_GEN)
get_directory_property(LUA_GEN_DEPS DIRECTORY ${PROJECT_SOURCE_DIR}/src/nvim DEFINITION LUA_GEN_DEPS)

add_custom_command(OUTPUT ${GENERATED_SYN_VIM}
  COMMAND ${LUA_GEN} ${SYN_VIM_GENERATOR} ${GENERATED_SYN_VIM} ${FUNCS_DATA}
    ${PROJECT_SOURCE_DIR}/src/nvim/options.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/auevents.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/vvars.lua
  DEPENDS
    ${LUA_GEN_DEPS}
    ${SYN_VIM_GENERATOR}
    ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/auevents.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/options.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/vvars.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/eval.c
    ${FUNCS_DATA}
)

file(GLOB PACKAGES CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/runtime/pack/dist/opt/*)

set(GENERATED_PACKAGE_TAGS)
foreach(PACKAGE ${PACKAGES})
  get_filename_component(PACKNAME ${PACKAGE} NAME)
  file(GLOB "${PACKNAME}_DOC_FILES" CONFIGURE_DEPENDS ${PACKAGE}/doc/*.txt)
  if(${PACKNAME}_DOC_FILES)
    file(MAKE_DIRECTORY ${GENERATED_PACKAGE_DIR}/${PACKNAME})
    add_custom_command(OUTPUT "${GENERATED_PACKAGE_DIR}/${PACKNAME}/doc/tags"
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${PACKAGE} ${GENERATED_PACKAGE_DIR}/${PACKNAME}
      COMMAND $<TARGET_FILE:nvim_bin>
        -u NONE -i NONE -e --headless -c "helptags doc" -c quit
      DEPENDS
        nvim_bin
        nvim_runtime_deps
      WORKING_DIRECTORY "${GENERATED_PACKAGE_DIR}/${PACKNAME}"
    )

    set("${PACKNAME}_DOC_NAMES")
    foreach(DF "${${PACKNAME}_DOC_FILES}")
      get_filename_component(F ${DF} NAME)
      list(APPEND "${PACKNAME}_DOC_NAMES" ${GENERATED_PACKAGE_DIR}/${PACKNAME}/doc/${F})
    endforeach()

    install_helper(
      FILES ${GENERATED_PACKAGE_DIR}/${PACKNAME}/doc/tags "${${PACKNAME}_DOC_NAMES}"
      DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/pack/dist/opt/${PACKNAME}/doc)

    list(APPEND GENERATED_PACKAGE_TAGS "${GENERATED_PACKAGE_DIR}/${PACKNAME}/doc/tags")
  endif()
endforeach()

set(BUILDDOCFILES)
foreach(DF ${DOCFILES})
  get_filename_component(F ${DF} NAME)
  list(APPEND BUILDDOCFILES ${GENERATED_RUNTIME_DIR}/doc/${F})
endforeach()

add_custom_command(OUTPUT ${GENERATED_HELP_TAGS}
  COMMAND ${CMAKE_COMMAND} -E remove_directory doc
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${PROJECT_SOURCE_DIR}/runtime/doc doc
  COMMAND $<TARGET_FILE:nvim_bin>
    -u NONE -i NONE -e --headless -c "helptags ++t doc" -c quit
  DEPENDS
    nvim_bin
    nvim_runtime_deps
  WORKING_DIRECTORY "${GENERATED_RUNTIME_DIR}"
)

add_custom_target(
  nvim_runtime
  DEPENDS
    ${GENERATED_SYN_VIM}
    ${GENERATED_HELP_TAGS}
    ${GENERATED_PACKAGE_TAGS}
)

# CMake is painful here.  It will create the destination using the user's
# current umask, and we don't want that.  And we don't just want to install
# the target directory, as it will mess with existing permissions.  So this
# seems like the best compromise.  If we create it, then everyone can see it.
# If it's preexisting, leave it alone.

install_helper(
  FILES ${GENERATED_HELP_TAGS} ${BUILDDOCFILES}
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/doc)

install_helper(
  FILES ${GENERATED_SYN_VIM}
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/syntax/vim)

if(NOT APPLE)
  install_helper(
    FILES ${CMAKE_CURRENT_SOURCE_DIR}/nvim.desktop
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)
endif()

install_helper(
  FILES ${CMAKE_CURRENT_SOURCE_DIR}/nvim.png
  DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/128x128/apps)

file(GLOB RUNTIME_ROOT_FILES CONFIGURE_DEPENDS *.vim *.lua *.ico)
install_helper(FILES ${RUNTIME_ROOT_FILES}
               DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/)

file(GLOB RUNTIME_DIRS CONFIGURE_DEPENDS */)
foreach(D ${RUNTIME_DIRS})
  if(IS_DIRECTORY ${D})
    install_helper(DIRECTORY ${D}
                   DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/)
  endif()
endforeach()

# only foo.sh script in runtime/
install_helper(PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/scripts/less.sh DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/scripts/)
