function(get_compile_flags _compile_flags)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
  set(compile_flags ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${build_type}})

  # Get flags set by target_compile_options().
  get_target_property(opt main_lib INTERFACE_COMPILE_OPTIONS)
  if(opt)
    list(APPEND compile_flags ${opt})
  endif()

  get_target_property(opt nvim COMPILE_OPTIONS)
  if(opt)
    list(APPEND compile_flags ${opt})
  endif()

  # Get flags set by target_compile_definitions().
  get_target_property(defs main_lib INTERFACE_COMPILE_DEFINITIONS)
  if(defs)
    foreach(def ${defs})
      list(APPEND compile_flags "-D${def}")
    endforeach()
  endif()

  get_target_property(defs nvim COMPILE_DEFINITIONS)
  if(defs)
    foreach(def ${defs})
      list(APPEND compile_flags "-D${def}")
    endforeach()
  endif()

  # Get include directories.
  get_target_property(dirs main_lib INTERFACE_INCLUDE_DIRECTORIES)
  if(dirs)
    foreach(dir ${dirs})
      list(APPEND compile_flags "-I${dir}")
    endforeach()
  endif()

  get_target_property(dirs main_lib INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
  if(dirs)
    foreach(dir ${dirs})
      list(APPEND compile_flags "-I${dir}")
    endforeach()
  endif()

  get_target_property(dirs nvim INCLUDE_DIRECTORIES)
  if(dirs)
    foreach(dir ${dirs})
      list(APPEND compile_flags "-I${dir}")
    endforeach()
  endif()

  list(REMOVE_DUPLICATES compile_flags)
  string(REPLACE ";" " " compile_flags "${compile_flags}")

  set(${_compile_flags} "${compile_flags}" PARENT_SCOPE)
endfunction()
