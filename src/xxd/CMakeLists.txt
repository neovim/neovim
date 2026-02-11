add_executable(xxd xxd.c)

# xxd has to be in the same directory as the nvim executable
set_target_properties(xxd PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(WIN32)
  install(TARGETS xxd
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
  )
endif()
