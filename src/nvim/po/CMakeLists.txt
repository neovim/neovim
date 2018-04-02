find_package(Gettext)
find_program(XGETTEXT_PRG xgettext)
find_program(ICONV_PRG iconv)

option(LANGUAGES "Localizations to build")
if(NOT LANGUAGES)
  set(LANGUAGES
    af
    ca
    cs
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

  add_custom_command(
    OUTPUT nvim.pot
    COMMAND ${CMAKE_COMMAND}
        -DXGETTEXT_PRG=${XGETTEXT_PRG}
        -DPOT_FILE=${NVIM_POT}
        -DSEARCH_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        "\"-DSOURCES=${NVIM_RELATIVE_SOURCES}\""
        -P ${PROJECT_SOURCE_DIR}/cmake/RunXgettext.cmake
    DEPENDS ${NVIM_SOURCES})

  add_custom_target(potfile DEPENDS ${NVIM_POT})

  set(LANGUAGE_MO_FILES)
  set(UPDATE_PO_TARGETS)

  macro(BuildMo name)
    set(poFile ${CMAKE_CURRENT_SOURCE_DIR}/${name}.po)
    set(moFile ${CMAKE_CURRENT_BINARY_DIR}/${name}.mo)

    add_custom_command(
      OUTPUT ${moFile}
      COMMAND ${CMAKE_COMMAND}
          -DMSGFMT_PRG=${GETTEXT_MSGFMT_EXECUTABLE}
          -DMO_FILE=${moFile}
          -DPO_FILE=${poFile}
          -P ${PROJECT_SOURCE_DIR}/cmake/RunMsgfmt.cmake
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
      COMMAND $<TARGET_FILE:nvim> -u NONE -n -e
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
    string(TOUPPER ${inputEnc} upperInputEnc)
    string(TOLOWER ${inputEnc} lowerInputEnc)

    add_custom_target(update-po-${lang}
      COMMAND ${CMAKE_COMMAND}
        -DICONV_PRG=${ICONV_PRG}
        -DINPUT_FILE=${inputFile}
        -DOUTPUT_FILE=${outputFile}
        -DINPUT_ENC=${inputEnc}
        -DOUTPUT_ENC=${outputEnc}
        -DOUTPUT_CHARSET=${outputCharSet}
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
      COMMAND ${CMAKE_COMMAND}
          -DMSGMERGE_PRG=${GETTEXT_MSGMERGE_EXECUTABLE}
          -DPO_FILE=${poFile}
          -DPOT_FILE=${NVIM_POT}
          -P ${PROJECT_SOURCE_DIR}/cmake/RunMsgmerge.cmake
      COMMENT "Updating ${LANGUAGE}.po"
      DEPENDS ${NVIM_POT})

    CheckPo(${LANGUAGE})

    list(APPEND UPDATE_PO_TARGETS update-po-${LANGUAGE})

    BuildMo(${LANGUAGE})
  endforeach()

  add_custom_target(translations ALL DEPENDS ${LANGUAGE_MO_FILES})
  add_custom_target(update-po DEPENDS ${UPDATE_PO_TARGETS})
endif()
