if(PATCH_CMD STREQUAL git)
  execute_process(COMMAND ${PATCH_EXE} -C ${START_DIR} init)
  execute_process(COMMAND ${PATCH_EXE} -C ${START_DIR} apply --ignore-whitespace ${PATCH_FILE})
else()
  execute_process(COMMAND ${PATCH_EXE} -d ${START_DIR} -i ${PATCH_FILE})
endif()
