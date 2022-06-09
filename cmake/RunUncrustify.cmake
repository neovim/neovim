# HACK: This script is invoked with "cmake -P …" as a workaround to silence uncrustify.

execute_process(
  COMMAND ${UNCRUSTIFY_PRG} -c "${PROJECT_SOURCE_DIR}/src/uncrustify.cfg" -q --check ${LINT_NVIM_SOURCES}
  OUTPUT_QUIET)
