add_subdirectory(includes)
add_subdirectory(functional/fixtures)

find_program(LUACHECK_PRG luacheck)
find_program(STYLUA_PRG stylua)
find_program(FLAKE8_PRG flake8)
find_program(UNCRUSTIFY_PRG uncrustify)
find_program(SHELLCHECK_PRG shellcheck)

find_program(NVIM_PRG nvim)
if(NOT NVIM_PRG)
  set(NVIM_PRG $<TARGET_FILE:nvim>)
endif()

file(GLOB_RECURSE LINT_NVIM_C_FILES
  "${PROJECT_SOURCE_DIR}/src/nvim/*.[ch]"
  "${PROJECT_SOURCE_DIR}/src/nvim/*/*.[ch]"
)

list(REMOVE_DUPLICATES LINT_NVIM_C_FILES)
list(FILTER LINT_NVIM_C_FILES EXCLUDE REGEX "${PROJECT_SOURCE_DIR}/src/nvim/test.*")

add_test(
  NAME lintcommit
  COMMAND ${NVIM_PRG} -u NONE --headless -es -c [==[lua require('scripts.lintcommit').main({trace=false})]==]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

set(CLINT_PRG ${PROJECT_SOURCE_DIR}/src/clint.py)
set(CLINT_SUPPRESSIONS_DIR ${PROJECT_BINARY_DIR}/errors)

include(FetchErrorSuppressions)
FetchErrorSuppressions(
  TARGET clint-reports
  DOWNLOAD_DIR ${CLINT_SUPPRESSIONS_DIR}
)

add_test(
  NAME
    fetch-clint-suppressions
  COMMAND
    "${CMAKE_CTEST_COMMAND}"
    --build-and-test "${PROJECT_SOURCE_DIR}"
                     "${PROJECT_BINARY_DIR}"
    --build-generator "${CMAKE_GENERATOR}"
    --build-nocmake
    --build-target clint-reports
)
set_tests_properties(fetch-clint-suppressions PROPERTIES FIXTURES_SETUP ClintReports)

if(CI_BUILD)
  set(CLINT_OUTPUT_FORMAT gh_action)
else()
  set(CLINT_OUTPUT_FORMAT vs7)
endif()

# add a seprate test for each file for easier invocation
# e.g. `ctest --test-dir build -R lintuncrustify-src-nvim-window-h`
foreach(f ${LINT_NVIM_C_FILES})
  file(RELATIVE_PATH rfile ${PROJECT_SOURCE_DIR} ${f})
  file(RELATIVE_PATH testname "${PROJECT_SOURCE_DIR}/src/nvim" ${f})
  string(REGEX REPLACE "[/.]" "-" testname ${testname})
  set(unc_testname lintuncrustify-${testname})
  set(clint_testname lintc-${testname})
  add_test(
    NAME ${clint_testname}
    COMMAND ${CLINT_PRG} --suppress-errors ${CLINT_SUPPRESSIONS_DIR}/${testname}.json --output ${CLINT_OUTPUT_FORMAT} ${rfile}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
  set_tests_properties(
    ${clint_testname} PROPERTIES
    LABELS "lint-all;lintcfull"
    REQUIRED_FILES ${f}
    FIXTURES_REQUIRED ClintReports
  )
  if(UNCRUSTIFY_PRG MATCHES "-NOTFOUND")
    continue()
  endif()
  add_test(
    NAME ${unc_testname}
    COMMAND ${UNCRUSTIFY_PRG} -c ${PROJECT_SOURCE_DIR}/src/uncrustify.cfg -q --check ${rfile}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
  set_tests_properties(
    ${unc_testname} PROPERTIES
    LABELS "lint-all;lintcfull"
    REQUIRED_FILES ${f}
  )
endforeach()

# FIXME(kylo252): this is a generated file
set_tests_properties(lintc-tui-terminfo_defs-h PROPERTIES DISABLED True)

add_test(
  NAME lintlua-luacheck
  COMMAND ${LUACHECK_PRG} -q runtime/ scripts/ src/ test/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintlua-stylua
  COMMAND ${STYLUA_PRG} --color=always --check runtime/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintpy
  COMMAND ${FLAKE8_PRG} --max-line-length 100 contrib scripts src test
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintsh
  COMMAND ${SHELLCHECK_PRG} scripts/vim-patch.sh
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

set_tests_properties(
  lintcommit lintlua-stylua lintlua-luacheck lintpy lintsh PROPERTIES
  LABELS lint-all
)
