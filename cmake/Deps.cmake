set(DEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/usr")
set(DEPS_BIN_DIR "${DEPS_INSTALL_DIR}/bin")
set(DEPS_LIB_DIR "${DEPS_INSTALL_DIR}/lib")
set(DEPS_SHARE_DIR "${DEPS_INSTALL_DIR}/share/lua/5.1")

set(DEPS_BUILD_DIR "${CMAKE_BINARY_DIR}/build")
set(DEPS_DOWNLOAD_DIR "${DEPS_BUILD_DIR}/downloads")

set(DEPS_CMAKE_ARGS
  -D CMAKE_C_COMPILER=${CMAKE_C_COMPILER}
  -D CMAKE_C_STANDARD=99
  -D CMAKE_GENERATOR=${CMAKE_GENERATOR}
  -D CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}
  -D BUILD_SHARED_LIBS=OFF
  -D CMAKE_POSITION_INDEPENDENT_CODE=ON
  -D CMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR})
if(APPLE)
  list(APPEND DEPS_CMAKE_ARGS -D CMAKE_FIND_FRAMEWORK=${CMAKE_FIND_FRAMEWORK})
endif()

# MAKE_PRG
if(UNIX)
  find_program(MAKE_PRG NAMES gmake make)
  if(NOT MAKE_PRG)
    message(FATAL_ERROR "GNU Make is required to build the dependencies.")
  else()
    message(STATUS "Found GNU Make at ${MAKE_PRG}")
  endif()
endif()
# When using make, use the $(MAKE) variable to avoid warning about the job
# server.
if(CMAKE_GENERATOR MATCHES "Makefiles")
  set(MAKE_PRG "$(MAKE)")
endif()
if(MINGW AND CMAKE_GENERATOR MATCHES "Ninja")
  find_program(MAKE_PRG NAMES mingw32-make)
  if(NOT MAKE_PRG)
    message(FATAL_ERROR "GNU Make for mingw32 is required to build the dependencies.")
  else()
    message(STATUS "Found GNU Make for mingw32: ${MAKE_PRG}")
  endif()
endif()

# DEPS_C_COMPILER
set(DEPS_C_COMPILER "${CMAKE_C_COMPILER}")
if(CMAKE_OSX_SYSROOT)
  set(DEPS_C_COMPILER "${DEPS_C_COMPILER} -isysroot${CMAKE_OSX_SYSROOT}")
endif()

function(get_externalproject_options name DEPS_IGNORE_SHA)
  string(TOUPPER ${name} name_allcaps)
  set(url ${${name_allcaps}_URL})

  set(EXTERNALPROJECT_OPTIONS DOWNLOAD_NO_PROGRESS TRUE)

  if(EXISTS ${url})
    list(APPEND EXTERNALPROJECT_OPTIONS
      GIT_REPOSITORY ${${name_allcaps}_URL})
    if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.18)
      list(APPEND EXTERNALPROJECT_OPTIONS GIT_REMOTE_UPDATE_STRATEGY CHECKOUT)
    endif()
  else()
    list(APPEND EXTERNALPROJECT_OPTIONS URL ${${name_allcaps}_URL})
    if(NOT ${DEPS_IGNORE_SHA})
      list(APPEND EXTERNALPROJECT_OPTIONS URL_HASH SHA256=${${name_allcaps}_SHA256})
    endif()
  endif()

  set(EXTERNALPROJECT_OPTIONS ${EXTERNALPROJECT_OPTIONS} PARENT_SCOPE)
endfunction()
