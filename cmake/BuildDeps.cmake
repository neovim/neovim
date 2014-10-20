#
# Helper to build Neovim dependency bundle
# 
# This is quick function to build an external cmake project. Unlike
# ExternalProject the project will be built immediatly upon call,
# usefull for building dependencies before doing configuration checks

# PROJECT_SRC is the location of CMakeLists.txt and PROJECT_BUILDDIR
# is the path where CMake will build
# 
# If there is an error this function will cause a FATAL_ERROR
#
function(build_deps PROJECT_SRC PROJECT_BUILDDIR)
  file(MAKE_DIRECTORY ${PROJECT_BUILDDIR})
  execute_process(
	    COMMAND ${CMAKE_COMMAND} ${PROJECT_SRC}
              -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
              -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
              -DCMAKE_TOOLCHAIN_FILE=${DCMAKE_TOOLCHAIN_FILE}
	    WORKING_DIRECTORY ${PROJECT_BUILDDIR}
            RESULT_VARIABLE RV
            )
  if (RV)
          message(FATAL_ERROR "Error configuring depdendencies: ${RV}")
  endif()
  execute_process(COMMAND ${CMAKE_COMMAND} --build ${PROJECT_BUILDDIR}
            RESULT_VARIABLE RV
            )
  if (RV)
          message(FATAL_ERROR "Error building depdendencies: ${RV}")
  endif()
endfunction()
