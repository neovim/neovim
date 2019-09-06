function(get_compile_flags _compile_flags)
  # Create template akin to CMAKE_C_COMPILE_OBJECT.
  set(compile_flags "<CMAKE_C_COMPILER> <CFLAGS> <BUILD_TYPE_CFLAGS> <COMPILE_OPTIONS><COMPILE_DEFINITIONS> <INCLUDES>")

  # Get C compiler.
  string(REPLACE
    "<CMAKE_C_COMPILER>"
    "${CMAKE_C_COMPILER}"
    compile_flags
    "${compile_flags}")

  # Get flags set by add_definitions().
  get_property(compile_definitions DIRECTORY PROPERTY COMPILE_DEFINITIONS)
  get_target_property(compile_definitions_target nvim COMPILE_DEFINITIONS)
  if(compile_definitions_target)
    list(APPEND compile_definitions ${compile_definitions_target})
    list(REMOVE_DUPLICATES compile_definitions)
  endif()
  # NOTE: list(JOIN) requires CMake 3.12, string(CONCAT) requires CMake 3.
  string(REPLACE ";" " -D" compile_definitions "${compile_definitions}")
  if(compile_definitions)
    set(compile_definitions " -D${compile_definitions}")
  endif()
  string(REPLACE
    "<COMPILE_DEFINITIONS>"
    "${compile_definitions}"
    compile_flags
    "${compile_flags}")

  # Get flags set by add_compile_options().
  get_property(compile_options DIRECTORY PROPERTY COMPILE_OPTIONS)
  get_target_property(compile_options_target nvim COMPILE_OPTIONS)
  if(compile_options_target)
    list(APPEND compile_options ${compile_options_target})
    list(REMOVE_DUPLICATES compile_options)
  endif()
  # NOTE: list(JOIN) requires CMake 3.12.
  string(REPLACE ";" " " compile_options "${compile_options}")
  string(REPLACE
    "<COMPILE_OPTIONS>"
    "${compile_options}"
    compile_flags
    "${compile_flags}")

  # Get general C flags.
  string(REPLACE
    "<CFLAGS>"
    "${CMAKE_C_FLAGS}"
    compile_flags
    "${compile_flags}")

  # Get C flags specific to build type.
  string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
  string(REPLACE
    "<BUILD_TYPE_CFLAGS>"
    "${CMAKE_C_FLAGS_${build_type}}"
    compile_flags
    "${compile_flags}")

  # Get include directories.
  get_property(include_directories_list DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
  list(REMOVE_DUPLICATES include_directories_list)
  foreach(include_directory ${include_directories_list})
    set(include_directories "${include_directories} -I${include_directory}")
  endforeach()
  string(REPLACE
    "<INCLUDES>"
    "${include_directories}"
    compile_flags
    "${compile_flags}")

  # Clean duplicate whitespace.
  string(REPLACE
    "  "
    " "
    compile_flags
    "${compile_flags}")

  set(${_compile_flags} "${compile_flags}" PARENT_SCOPE)
endfunction()
