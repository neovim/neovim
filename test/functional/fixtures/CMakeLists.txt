add_executable(tty-test EXCLUDE_FROM_ALL tty-test.c)
target_link_libraries(tty-test ${LIBUV_LIBRARIES})

add_executable(shell-test EXCLUDE_FROM_ALL shell-test.c)
add_executable(printargs-test EXCLUDE_FROM_ALL printargs-test.c)
add_executable(printenv-test EXCLUDE_FROM_ALL printenv-test.c)
if(WIN32)
  set_target_properties(printenv-test PROPERTIES LINK_FLAGS -municode)
endif()

add_executable(streams-test EXCLUDE_FROM_ALL streams-test.c)
target_link_libraries(streams-test ${LIBUV_LIBRARIES})
