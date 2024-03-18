get_sha(lpeg ${DEPS_IGNORE_SHA})
ExternalProject_Add(lpeg
  URL ${LPEG_URL}
  ${EXTERNALPROJECT_URL_HASH}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/lpeg
  PATCH_COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/LpegCMakeLists.txt
    ${DEPS_BUILD_DIR}/src/lpeg/CMakeLists.txt
  CMAKE_ARGS ${DEPS_CMAKE_ARGS} -DCMAKE_C_FLAGS=${DEPS_INCLUDE_FLAGS}
  CMAKE_CACHE_ARGS ${DEPS_CMAKE_CACHE_ARGS}
  ${EXTERNALPROJECT_OPTIONS})

if(USE_BUNDLED_LUAJIT)
  add_dependencies(lpeg luajit)
elseif(USE_BUNDLED_LUA)
  add_dependencies(lpeg lua)
endif()
