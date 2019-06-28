function(get_compile_flags _compile_flags)
  # Create template akin to CMAKE_C_COMPILE_OBJECT.
  set(compile_flags "<CMAKE_C_COMPILER> <CFLAGS> <BUILD_TYPE_CFLAGS> <COMPILE_OPTIONS> <COMPILE_DEFINITIONS> <INCLUDES>")

  # Get C compiler.
  string(REPLACE
    "<CMAKE_C_COMPILER>"
    "${CMAKE_C_COMPILER}"
    compile_flags
    "${compile_flags}")

  # Get flags set by add_definitions().
  get_directory_property(compile_definitions
    DIRECTORY "src/nvim"
    COMPILE_DEFINITIONS)
  # NOTE: list(JOIN) requires CMake 3.12.
  string(REPLACE ";" " -D" compile_definitions "${compile_definitions}")
  string(CONCAT compile_definitions "-D" "${compile_definitions}")
  string(REPLACE
    "<COMPILE_DEFINITIONS>"
    "${compile_definitions}"
    compile_flags
    "${compile_flags}")

  # Get flags set by add_compile_options().
  get_directory_property(compile_options
    DIRECTORY "src/nvim"
    COMPILE_OPTIONS)
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
