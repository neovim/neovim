function(LINT)
  cmake_parse_arguments(LINT "QUIET" "PROGRAM" "FLAGS;FILES" ${ARGN})

  if(LINT_QUIET)
    set(OUTPUT_QUIET OUTPUT_QUIET)
  elseif()
    set(OUTPUT_QUIET "")
  endif()

  find_program(PROGRAM_EXISTS ${LINT_PROGRAM})
  if(PROGRAM_EXISTS)
    execute_process(COMMAND ${LINT_PROGRAM} ${LINT_FLAGS} ${LINT_FILES}
      WORKING_DIRECTORY ${PROJECT_ROOT}
      RESULT_VARIABLE ret
      ${OUTPUT_QUIET})
    if(ret AND NOT ret EQUAL 0)
      message(FATAL_ERROR "FAILED: ${TARGET}")
    endif()
  else()
    message(STATUS "${TARGET}: ${LINT_PROGRAM} not found. SKIP.")
  endif()
endfunction()

if(${TARGET} STREQUAL "lintuncrustify")
  file(GLOB_RECURSE FILES ${PROJECT_ROOT}/src/nvim/*.[c,h])
  lint(PROGRAM uncrustify FLAGS -c src/uncrustify.cfg -q --check FILES ${FILES} QUIET)
elseif(${TARGET} STREQUAL "lintpy")
  lint(PROGRAM flake8 FILES contrib/ scripts/ src/ test/)
elseif(${TARGET} STREQUAL "lintsh")
  lint(PROGRAM shellcheck FILES scripts/vim-patch.sh)
elseif(${TARGET} STREQUAL "lintlua")
  lint(PROGRAM luacheck FLAGS -q FILES runtime/ scripts/ src/ test/)
  lint(PROGRAM stylua FLAGS --color=always --check FILES runtime/)
endif()
