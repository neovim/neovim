
add_library(fuzzer_lib INTERFACE)

set(INIT_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/init.sh")
file(WRITE "${INIT_SCRIPT}"
  "#!/bin/bash\n"
"set -e\n"
"export CMAKE_INSTALL_PREFIX=\"${CMAKE_INSTALL_PREFIX}\"\n"
# fuzzer need to run init.sh and pass test base dir (under os /tmp/nvim_fuzzer_${pid}_${tid}) as first argument
"export FUZZER_TEST_BASE=\"\${1}\"\n"
"export TEST_XDG_CONFIG_DIR=\"\${FUZZER_TEST_BASE}/XDG_CONFIG_DIR\"\n"
"export TEST_XDG_DATA_HOME=\"\${FUZZER_TEST_BASE}/XDG_DATA_HOME\"\n"
"export TEST_TMPDIR=\"\${FUZZER_TEST_BASE}/TMPDIR\"\n"
"mkdir -p \"\${TEST_XDG_CONFIG_DIR}\" \"\${TEST_XDG_DATA_HOME}\" \"\${TEST_TMPDIR}\"\n"
"${CMAKE_CURRENT_SOURCE_DIR}/init_post.sh\n"
)

file(CHMOD "${INIT_SCRIPT}" PERMISSIONS OWNER_EXECUTE OWNER_READ OWNER_WRITE )

set_target_properties(fuzzer_lib 
  PROPERTIES
  INTERFACE_COMPILE_DEFINITIONS "MAKE_LIB;FUZZER_INIT_SCRIPT=\"${INIT_SCRIPT}\";FUZZER_SEND_SCRIPT=\"${CMAKE_CURRENT_SOURCE_DIR}/send.py\""
  INTERFACE_COMPILE_OPTIONS  ${SANITIZER_COMPILE}
  INTERFACE_LINK_LIBRARIES main_lib libuv
  INTERFACE_LINK_OPTIONS ${SANITIZER_LINK}
)


add_executable(fuzzer fuzzer.c )
target_compile_options(fuzzer  PRIVATE "-fsanitize=fuzzer")
target_link_libraries(fuzzer fuzzer_lib libuv)
target_link_options(fuzzer PRIVATE  ${SANITIZER_LINK} "-fsanitize=fuzzer")

add_executable(fuzzer_test fuzzer_test.c
  fuzzer.c
)
target_link_libraries(fuzzer_test fuzzer_lib libuv)
target_link_options(fuzzer_test PRIVATE  ${SANITIZER_LINK})

