#
# Helper to build Neovim dependency bundle
# 
# This is quick function to build an external cmake project. Unlike
# ExternalProject the project will be built immediatly upon call,
# usefull for building dependencies before doing configuration checks

# Change this list to add more variables that should be passed to CMake
set(BUILDDEPS_PASSTHROUGH
  CMAKE_BUILD_TYPE
  CMAKE_GENERATOR
  CMAKE_TOOLCHAIN_FILE
  )

# PROJECT_SRC is the location of CMakeLists.txt and PROJECT_BUILDDIR
# is the path where CMake will build
# 
# If there is an error this function will cause a FATAL_ERROR
#
function(build_deps PROJECT_SRC PROJECT_BUILDDIR)

  # cmake arguments
  set(CMAKE_ARGUMENTS)
  foreach(VARNAME ${BUILDDEPS_PASSTHROUGH})
    if(DEFINED ${VARNAME})
      list(APPEND CMAKE_ARGUMENTS "-D${VARNAME}=${${VARNAME}}")
    endif()
  endforeach()

  file(MAKE_DIRECTORY ${PROJECT_BUILDDIR})
  message(STATUS "Building dependency: ${PROJECT_SRC}")

  execute_process(
    COMMAND ${CMAKE_COMMAND} ${PROJECT_SRC} ${CMAKE_ARGUMENTS}
    WORKING_DIRECTORY ${PROJECT_BUILDDIR}
    RESULT_VARIABLE RV
    )
  if (RV)
    message(FATAL_ERROR "Error configuring depdendency: ${RV}")
  endif()
  execute_process(COMMAND ${CMAKE_COMMAND} --build ${PROJECT_BUILDDIR}
    RESULT_VARIABLE RV
    )
  if (RV)
    message(FATAL_ERROR "Error building depdendency: ${RV}")
  endif()
endfunction()
