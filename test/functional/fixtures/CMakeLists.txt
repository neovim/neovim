add_executable(tty-test tty-test.c)
target_link_libraries(tty-test ${LIBUV_LIBRARIES})

add_executable(shell-test shell-test.c)
add_executable(printargs-test printargs-test.c)
add_executable(printenv-test printenv-test.c)
if(WIN32)
  set_target_properties(printenv-test PROPERTIES LINK_FLAGS -municode)
endif()
