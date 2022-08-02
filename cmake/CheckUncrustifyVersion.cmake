if(UNCRUSTIFY_PRG)
  execute_process(COMMAND uncrustify --version
    OUTPUT_VARIABLE user_version
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REGEX REPLACE "[A-Za-z_#-]" "" user_version ${user_version})

  file(STRINGS ${CONFIG_FILE} required_version LIMIT_COUNT 1)
  string(REGEX REPLACE "[A-Za-z_# -]" "" required_version ${required_version})

  if(NOT user_version STREQUAL required_version)
    message(FATAL_ERROR "Wrong uncrustify version! Required version is ${required_version} but found ${user_version}")
  endif()
endif()
