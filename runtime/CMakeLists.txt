set(SYN_VIM_GENERATOR ${PROJECT_SOURCE_DIR}/scripts/genvimvim.lua)
set(GENERATED_RUNTIME_DIR ${PROJECT_BINARY_DIR}/runtime)
set(GENERATED_SYN_VIM ${GENERATED_RUNTIME_DIR}/syntax/vim/generated.vim)
set(GENERATED_HELP_TAGS ${GENERATED_RUNTIME_DIR}/doc/tags)
set(GENERATED_PACKAGE_DIR ${GENERATED_RUNTIME_DIR}/pack/dist/opt)
set(FUNCS_DATA ${PROJECT_BINARY_DIR}/funcs_data.mpack)

file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR})
file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR}/syntax)
file(MAKE_DIRECTORY ${GENERATED_RUNTIME_DIR}/syntax/vim)

add_custom_command(OUTPUT ${GENERATED_SYN_VIM}
  COMMAND ${LUA_PRG} ${SYN_VIM_GENERATOR}
          ${PROJECT_SOURCE_DIR}/src/nvim ${GENERATED_SYN_VIM} ${FUNCS_DATA}
  DEPENDS
    ${SYN_VIM_GENERATOR}
    ${PROJECT_SOURCE_DIR}/src/nvim/ex_cmds.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/auevents.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/options.lua
    ${PROJECT_SOURCE_DIR}/src/nvim/eval.c
    ${FUNCS_DATA}
)

if(POLICY CMP0054)
  cmake_policy(SET CMP0054 OLD)
endif()

file(GLOB PACKAGES ${PROJECT_SOURCE_DIR}/runtime/pack/dist/opt/*)

set(GENERATED_PACKAGE_TAGS)
foreach(PACKAGE ${PACKAGES})
  get_filename_component(PACKNAME ${PACKAGE} NAME)
  file(GLOB "${PACKNAME}_DOC_FILES" ${PACKAGE}/doc/*.txt)
  if("${PACKNAME}_DOC_FILES")
    file(MAKE_DIRECTORY ${GENERATED_PACKAGE_DIR}/${PACKNAME})
    add_custom_target("${PACKNAME}-tags"
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${PACKAGE} ${GENERATED_PACKAGE_DIR}/${PACKNAME}
      COMMAND "${PROJECT_BINARY_DIR}/bin/nvim"
        -u NONE -i NONE -e --headless -c "helptags doc" -c quit
      DEPENDS
        nvim
      WORKING_DIRECTORY "${GENERATED_PACKAGE_DIR}/${PACKNAME}"
    )

    add_custom_command(OUTPUT "${GENERATED_PACKAGE_DIR}/${PACKNAME}/doc/tags"
      DEPENDS
        "${PACKNAME}-tags"
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

file(GLOB DOCFILES ${PROJECT_SOURCE_DIR}/runtime/doc/*.txt)

set(BUILDDOCFILES)
foreach(DF ${DOCFILES})
  get_filename_component(F ${DF} NAME)
  list(APPEND BUILDDOCFILES ${GENERATED_RUNTIME_DIR}/doc/${F})
endforeach()

add_custom_target(helptags
  COMMAND ${CMAKE_COMMAND} -E remove ${GENERATED_RUNTIME_DIR}/doc/*
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${PROJECT_SOURCE_DIR}/runtime/doc ${GENERATED_RUNTIME_DIR}/doc
  COMMAND "${PROJECT_BINARY_DIR}/bin/nvim"
    -u NONE -i NONE -e --headless -c "helptags ++t doc" -c quit
  DEPENDS
    nvim
  WORKING_DIRECTORY "${GENERATED_RUNTIME_DIR}"
)

add_custom_command(OUTPUT ${GENERATED_HELP_TAGS}
  DEPENDS
    helptags
)

add_custom_target(doc_html
  COMMAND make html
  DEPENDS
    ${GENERATED_HELP_TAGS}
  WORKING_DIRECTORY "${GENERATED_RUNTIME_DIR}/doc"
)

add_custom_target(
  runtime ALL
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

  install_helper(
    FILES ${CMAKE_CURRENT_SOURCE_DIR}/nvim.png
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/pixmaps)
endif()

file(GLOB_RECURSE RUNTIME_PROGRAMS
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  *.awk *.sh *.bat)

foreach(PROG ${RUNTIME_PROGRAMS})
  get_filename_component(BASEDIR ${PROG} PATH)
  install_helper(PROGRAMS ${PROG}
                 DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/${BASEDIR})
endforeach()

file(GLOB_RECURSE RUNTIME_FILES
  RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
  rgb.txt
  *.vim *.lua *.dict *.py *.rb *.ps *.spl *.tutor *.tutor.json)

foreach(F ${RUNTIME_FILES})
  get_filename_component(BASEDIR ${F} PATH)
  install_helper(FILES ${F}
                 DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/nvim/runtime/${BASEDIR})
endforeach()
