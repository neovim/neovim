if(PROGRAM)

  if(${TARGET} STREQUAL "lint_uncrustify")
    file(GLOB_RECURSE FILES ${PROJECT_ROOT}/src/nvim/*.[c,h])
    execute_process(COMMAND ${PROGRAM} -c src/uncrustify.cfg -q --check ${FILES}
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret
      OUTPUT_QUIET)
  elseif(${TARGET} STREQUAL "lint_py")
    execute_process(COMMAND ${PROGRAM} contrib/ scripts/ src/ test/
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "lint_sh")
    execute_process(COMMAND ${PROGRAM} scripts/vim-patch.sh
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "lint_stylua")
    execute_process(COMMAND ${PROGRAM} --color=always --check runtime/
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret)
  elseif(${TARGET} STREQUAL "lint_lua")
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
