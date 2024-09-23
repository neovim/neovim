find_package(Gettext REQUIRED)
find_program(XGETTEXT_PRG xgettext)
find_program(ICONV_PRG iconv)
mark_as_advanced(
  GETTEXT_MSGFMT_EXECUTABLE
  GETTEXT_MSGMERGE_EXECUTABLE
  ICONV_PRG
  XGETTEXT_PRG)

option(ENABLE_LANGUAGES "Localizations to build" ON)
if(ENABLE_LANGUAGES)
  set(LANGUAGES
    af
    ca
    cs
    da
    de
    en_GB
    eo
    es
    fi
    fr
    ga
    it
    ja
    ko.UTF-8
    nl
    no
    pl.UTF-8
    pt_BR
    ru
    sk
    sv
    tr
    uk
    vi
    zh_CN.UTF-8
    zh_TW.UTF-8)
endif()

if(HAVE_WORKING_LIBINTL AND GETTEXT_FOUND AND XGETTEXT_PRG AND ICONV_PRG)
  set(ENV{OLD_PO_FILE_INPUT} yes)
  set(ENV{OLD_PO_FILE_OUTPUT} yes)

  set(NVIM_RELATIVE_SOURCES)
  foreach(SRC ${NVIM_SOURCES} ${NVIM_HEADERS})
    file(RELATIVE_PATH RELATIVE_SRC ${CMAKE_CURRENT_SOURCE_DIR} ${SRC})
    list(APPEND NVIM_RELATIVE_SOURCES ${RELATIVE_SRC})
  endforeach()

  set(NVIM_POT ${CMAKE_CURRENT_BINARY_DIR}/nvim.pot)

  list(SORT NVIM_RELATIVE_SOURCES)
  add_custom_command(
    OUTPUT ${NVIM_POT}
    COMMAND $<TARGET_FILE:nvim_bin> -u NONE -i NONE -n --headless --cmd "set cpo+=+"
      -c "silent source ${CMAKE_CURRENT_SOURCE_DIR}/tojavascript.vim"
      ${NVIM_POT} ${PROJECT_SOURCE_DIR}/runtime/optwin.vim
    COMMAND ${XGETTEXT_PRG} -o ${NVIM_POT} --default-domain=nvim
      --add-comments --keyword=_ --keyword=N_ --keyword=NGETTEXT:1,2
      -D ${CMAKE_CURRENT_SOURCE_DIR} -D ${CMAKE_CURRENT_BINARY_DIR}
      ${NVIM_RELATIVE_SOURCES} optwin.js
    COMMAND $<TARGET_FILE:nvim_bin> -u NONE -i NONE -n --headless --cmd "set cpo+=+"
      -c "silent source ${CMAKE_CURRENT_SOURCE_DIR}/fixfilenames.vim"
      ${NVIM_POT} ${PROJECT_SOURCE_DIR}/runtime/optwin.vim
    VERBATIM
    DEPENDS ${NVIM_SOURCES} nvim_bin nvim_runtime_deps)

  set(LANGUAGE_MO_FILES)
  set(UPDATE_PO_TARGETS)

  macro(BuildMo name)
    set(poFile ${CMAKE_CURRENT_SOURCE_DIR}/${name}.po)
    set(moFile ${CMAKE_CURRENT_BINARY_DIR}/${name}.mo)

    add_custom_command(
      OUTPUT ${moFile}
      COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} -o ${moFile} ${poFile}
      DEPENDS ${poFile} ${NVIM_POT})

    install_helper(
      FILES ${moFile}
      DESTINATION ${CMAKE_INSTALL_LOCALEDIR}/${name}/LC_MESSAGES
      RENAME ${PROJECT_NAME}.mo)

    list(APPEND LANGUAGE_MO_FILES ${moFile})
  endmacro()

  macro(CheckPo name)
    set(poFile ${CMAKE_CURRENT_SOURCE_DIR}/${name}.po)

    add_custom_target(check-po-${name}
      COMMAND $<TARGET_FILE:nvim_bin> -u NONE -n -e
          -S ${CMAKE_CURRENT_SOURCE_DIR}/check.vim
          -c "if error == 0 | q | endif" -c cq ${poFile} ||
          ${CMAKE_COMMAND} -E echo "${name}.po failed the check."
      COMMENT "Checking ${name}.po"
      VERBATIM
      DEPENDS ${poFile})
  endmacro()

  macro(BuildPoIconvGenericWithCharset
      lang inputName outputName inputEnc outputEnc outputCharSet)
    set(inputFile ${CMAKE_CURRENT_SOURCE_DIR}/${inputName}.po)
    set(outputFile ${CMAKE_CURRENT_SOURCE_DIR}/${outputName}.po)

    add_custom_target(update-po-${lang}
      COMMAND ${CMAKE_COMMAND}
        -D ICONV_PRG=${ICONV_PRG}
        -D INPUT_FILE=${inputFile}
        -D OUTPUT_FILE=${outputFile}
        -D INPUT_ENC=${inputEnc}
        -D OUTPUT_ENC=${outputEnc}
        -D OUTPUT_CHARSET=${outputCharSet}
        -P ${PROJECT_SOURCE_DIR}/cmake/ConvertPo.cmake
      COMMENT "Updating ${outputName}.po"
      DEPENDS ${inputFile})

    CheckPo(${outputName})

    list(APPEND UPDATE_PO_TARGETS update-po-${lang})
  endmacro()

  macro(BuildPoIconvGeneric lang inputName outputName inputEnc outputEnc)
    # Most of the time, the output charset is the same as the iconv output
    # encoding.
    BuildPoIconvGenericWithCharset(
      ${lang} ${inputName} ${outputName} ${inputEnc} ${outputEnc} ${outputEnc})
  endmacro()

  macro(BuildPoIconv name inputEnc outputEnc)
    set(lang ${name}.${outputEnc})
    set(inputName ${name})

    if(outputEnc STREQUAL utf-8)
      set(outputName ${name}.UTF-8)
    else()
      set(outputName ${lang})
    endif()

    BuildPoIconvGeneric(
      ${lang} ${inputName} ${outputName} ${inputEnc} ${outputEnc})
  endmacro()

  # Create some translations from others.
  if(";${LANGUAGES};" MATCHES ";ja;")
    BuildPoIconv(ja utf-8 euc-jp)
    BuildMo(ja.euc-jp)
  endif()

  if(";${LANGUAGES};" MATCHES ";cs;")
    BuildPoIconv(cs ISO-8859-2 cp1250)
    BuildMo(cs.cp1250)
  endif()

  if(";${LANGUAGES};" MATCHES ";sk;")
    BuildPoIconv(sk ISO-8859-2 cp1250)
    BuildMo(sk.cp1250)
  endif()

  add_custom_target(update-po-nb
    COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/no.po ${CMAKE_CURRENT_SOURCE_DIR}/nb.po
    DEPENDS no.po)
  list(APPEND UPDATE_PO_TARGETS update-po-nb)
  if(";${LANGUAGES};" MATCHES ";no;")
    CheckPo(nb)
    BuildMo(nb)
  endif()

  foreach(LANGUAGE ${LANGUAGES})
    set(poFile "${CMAKE_CURRENT_SOURCE_DIR}/${LANGUAGE}.po")

    add_custom_target(update-po-${LANGUAGE}
      COMMAND ${GETTEXT_MSGMERGE_EXECUTABLE} -q --update --backup=none --sort-by-file
      ${poFile} ${NVIM_POT}
      COMMENT "Updating ${LANGUAGE}.po"
      DEPENDS ${NVIM_POT})

    CheckPo(${LANGUAGE})

    list(APPEND UPDATE_PO_TARGETS update-po-${LANGUAGE})

    BuildMo(${LANGUAGE})
  endforeach()

  add_custom_target(nvim_translations DEPENDS ${LANGUAGE_MO_FILES})
  add_custom_target(update-po DEPENDS ${UPDATE_PO_TARGETS})
  add_dependencies(nvim nvim_translations)
endif()
