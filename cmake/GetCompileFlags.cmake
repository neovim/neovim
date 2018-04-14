function(get_compile_flags _compile_flags)
  # Create template akin to CMAKE_C_COMPILE_OBJECT.
  set(compile_flags "<CMAKE_C_COMPILER> <CFLAGS> <BUILD_TYPE_CFLAGS> <DEFINITIONS> <INCLUDES>")

  # Get C compiler.
  string(REPLACE
    "<CMAKE_C_COMPILER>"
    "${CMAKE_C_COMPILER}"
    compile_flags
    "${compile_flags}")

  # Get flags set by add_definition().
  get_directory_property(definitions
    DIRECTORY "src/nvim"
    DEFINITIONS)
  string(REPLACE
    "<DEFINITIONS>"
    "${definitions}"
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
  get_directory_property(include_directories_list
    DIRECTORY "src/nvim"
    INCLUDE_DIRECTORIES)
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
