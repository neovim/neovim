add_executable(tee tee.c)

# tee has to be in the same directory as the nvim executable
set_target_properties(tee PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

install(TARGETS tee
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)
