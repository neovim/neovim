file(GLOB_RECURSE PRE_HEADERS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} pre/*.h)

foreach(hfile ${PRE_HEADERS})
  string(REGEX REPLACE ^pre/ post/ post_hfile ${hfile})
  get_filename_component(hdir ${CMAKE_CURRENT_BINARY_DIR}/${post_hfile} PATH)
  file(MAKE_DIRECTORY ${hdir})
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${post_hfile}
    COMMAND ${CMAKE_C_COMPILER} -std=c99 -E -P
      ${CMAKE_CURRENT_SOURCE_DIR}/${hfile}
      -I${LIBUV_INCLUDE_DIRS}
      -o ${CMAKE_CURRENT_BINARY_DIR}/${post_hfile})
  list(APPEND POST_HEADERS ${post_hfile})
endforeach()

add_custom_target(unittest-headers DEPENDS ${POST_HEADERS})
