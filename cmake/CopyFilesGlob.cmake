# Copy multiple files to destination, based on a glob expression
# - FROM_GLOB
# - TO

if(NOT FROM_GLOB)
  message(FATAL_ERROR "FROM_GLOB must be set")
endif()
if(NOT TO)
  message(FATAL_ERROR "TO must be set")
endif()

execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${TO})

file(GLOB files ${FROM_GLOB})
foreach(file ${files})
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${file} ${TO} RESULT_VARIABLE rv)
  if(rv)
    message(FATAL_ERROR "Error copying ${file}")
  endif()
endforeach()
