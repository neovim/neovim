if(PROGRAM)

  if(${TARGET} STREQUAL "uncrustify")
    file(GLOB_RECURSE FILES ${PROJECT_ROOT}/src/nvim/*.[c,h])
    execute_process(COMMAND ${PROGRAM} -c src/uncrustify.cfg -q --check ${FILES}
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret
      OUTPUT_QUIET)
  elseif(${TARGET} STREQUAL "pylint")
    execute_process(COMMAND ${PROGRAM} contrib/ scripts/ src/ test/
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "shlint")
    execute_process(COMMAND ${PROGRAM} scripts/vim-patch.sh
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "stylua")
    execute_process(COMMAND ${PROGRAM} --color=always --check runtime/
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "lualint")
    execute_process(COMMAND ${PROGRAM} -q runtime/ scripts/ src/ test/
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  endif()

  if(ret AND NOT ret EQUAL 0)
    message(FATAL_ERROR "FAILED: ${TARGET}")
  endif()

else()
  string(TOLOWER ${PROGRAM} PROGRAM)
  string(REPLACE "-notfound" "" PROGRAM ${PROGRAM})
  message(STATUS "${TARGET}: ${PROGRAM} not found. SKIP.")
endif()
