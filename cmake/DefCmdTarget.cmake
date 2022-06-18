# Defines a target named ${target}. If ${prg} is undefined the target prints
# "not found".
#
# - Use add_custom_command(TARGET <target_name> ...) to append a command to the
# target.
function(def_cmd_target target prg prg_name prg_fatal)
  add_custom_target(${target})

  if(NOT prg)
    if(prg_fatal)
      add_custom_command(TARGET ${target}
        COMMAND ${CMAKE_COMMAND} -E echo "${target}: ${prg_name} not found"
        COMMAND false)
    else()
      add_custom_command(TARGET ${target}
        COMMAND ${CMAKE_COMMAND} -E echo "${target}: SKIP: ${prg_name} not found")
    endif()
  endif()
endfunction()
