# Defines a target named ${target} and a command with (symbolic) output
# ${target}-cmd. If ${prg} is undefined the target prints "not found".
#
# - Use add_custom_command(…APPEND) to build the command after this.
# - Use add_custom_target(…DEPENDS) to run the command from a target.
function(def_cmd_target target prg prg_name prg_fatal)
  # Define a mostly-empty command, which can be appended-to.
  add_custom_command(OUTPUT ${target}-cmd
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMAND ${CMAKE_COMMAND} -E echo "${target}"
  )
  # Symbolic (does not generate an artifact).
  set_source_files_properties(${target}-cmd PROPERTIES SYMBOLIC "true")

  if(prg OR NOT prg_fatal)
    add_custom_target(${target}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      DEPENDS ${target}-cmd)
    if(NOT prg)
      add_custom_command(OUTPUT ${target}-cmd APPEND
        COMMAND ${CMAKE_COMMAND} -E echo "${target}: SKIP: ${prg_name} not found")
    endif()
  else()
    add_custom_target(${target} false
      COMMENT "${target}: ${prg_name} not found")
  endif()
endfunction()
