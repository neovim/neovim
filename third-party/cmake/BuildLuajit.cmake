include(CMakeParseArguments)

# BuildLuajit(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build luajit, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLuajit)
  cmake_parse_arguments(_luajit
    ""
    "TARGET"
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND"
    ${ARGN})
  if(NOT _luajit_CONFIGURE_COMMAND AND NOT _luajit_BUILD_COMMAND
        AND NOT _luajit_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()
  if(NOT _luajit_TARGET)
    set(_luajit_TARGET "luajit")
  endif()

  ExternalProject_Add(${_luajit_TARGET}
    PREFIX ${DEPS_BUILD_DIR}
    URL ${LUAJIT_URL}
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    DOWNLOAD_COMMAND ${CMAKE_COMMAND}
      -DPREFIX=${DEPS_BUILD_DIR}
      -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/luajit
      -DURL=${LUAJIT_URL}
      -DEXPECTED_SHA256=${LUAJIT_SHA256}
      -DTARGET=${_luajit_TARGET}
      -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
    CONFIGURE_COMMAND "${_luajit_CONFIGURE_COMMAND}"
    BUILD_IN_SOURCE 1
    BUILD_COMMAND "${_luajit_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luajit_INSTALL_COMMAND}")
endfunction()

set(INSTALLCMD_UNIX ${MAKE_PRG} CFLAGS=-fPIC
                                CFLAGS+=-DLUAJIT_DISABLE_JIT
                                CFLAGS+=-DLUA_USE_APICHECK
                                CFLAGS+=-DLUA_USE_ASSERT
                                CCDEBUG+=-g
                                Q=
                                install)

if(UNIX)
  BuildLuaJit(INSTALL_COMMAND ${INSTALLCMD_UNIX}
    CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR})

elseif(MINGW AND CMAKE_CROSSCOMPILING)

  # Build luajit for the host
  BuildLuaJit(TARGET luajit_host
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${INSTALLCMD_UNIX}
      CC=${HOST_C_COMPILER} PREFIX=${HOSTDEPS_INSTALL_DIR})

  # Build luajit for the target
  BuildLuaJit(
    # Similar to Unix + cross - fPIC
    INSTALL_COMMAND
      ${MAKE_PRG} PREFIX=${DEPS_INSTALL_DIR}
        BUILDMODE=static install
        TARGET_SYS=${CMAKE_SYSTEM_NAME}
        CROSS=${CROSS_TARGET}-
        HOST_CC=${HOST_C_COMPILER} HOST_CFLAGS=${HOST_C_FLAGS}
        HOST_LDFLAGS=${HOST_EXE_LINKER_FLAGS}
        FILE_T=luajit.exe
        Q=
        INSTALL_TSYMNAME=luajit.exe)

elseif(MINGW)


	BuildLuaJit(BUILD_COMMAND ${CMAKE_MAKE_PROGRAM} CC=${DEPS_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
                                CFLAGS+=-DLUAJIT_DISABLE_JIT
                                CFLAGS+=-DLUA_USE_APICHECK
                                CFLAGS+=-DLUA_USE_ASSERT
                                CCDEBUG+=-g
                                BUILDMODE=static
                      # Build a DLL too
                      COMMAND ${CMAKE_MAKE_PROGRAM} CC=${DEPS_C_COMPILER} BUILDMODE=dynamic

          INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/luajit.exe ${DEPS_INSTALL_DIR}/bin
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_INSTALL_DIR}/bin
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
	    # Luarocks searches for lua51.dll in lib
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_INSTALL_DIR}/lib
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/libluajit.a ${DEPS_INSTALL_DIR}/lib
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include/luajit-2.0
	    COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/luajit/src/*.h -DTO=${DEPS_INSTALL_DIR}/include/luajit-2.0 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
          )
elseif(MSVC)

  BuildLuaJit(
    BUILD_COMMAND ${CMAKE_COMMAND} -E chdir ${DEPS_BUILD_DIR}/src/luajit/src ${DEPS_BUILD_DIR}/src/luajit/src/msvcbuild.bat
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/luajit.exe ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_INSTALL_DIR}/bin
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.lib ${DEPS_INSTALL_DIR}/lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include/luajit-2.0
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/luajit/src/*.h -DTO=${DEPS_INSTALL_DIR}/include/luajit-2.0 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake)

else()
  message(FATAL_ERROR "Trying to build luajit in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()

list(APPEND THIRD_PARTY_DEPS luajit)
