function(BuildLuajit)
  cmake_parse_arguments(_luajit
    ""
    ""
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND;DEPENDS"
    ${ARGN})

  get_externalproject_options(luajit ${DEPS_IGNORE_SHA})
  ExternalProject_Add(luajit
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    CONFIGURE_COMMAND "${_luajit_CONFIGURE_COMMAND}"
    BUILD_IN_SOURCE 1
    BUILD_COMMAND "${_luajit_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luajit_INSTALL_COMMAND}"
    DEPENDS "${_luajit_DEPENDS}"
    ${EXTERNALPROJECT_OPTIONS})
endfunction()

check_c_compiler_flag(-fno-stack-check HAS_NO_STACK_CHECK)
if(APPLE AND HAS_NO_STACK_CHECK)
  set(NO_STACK_CHECK "CFLAGS+=-fno-stack-check")
else()
  set(NO_STACK_CHECK "")
endif()
if(CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
  set(AMD64_ABI "LDFLAGS=-lpthread -lc++abi")
else()
  set(AMD64_ABI "")
endif()
set(BUILDCMD_UNIX ${MAKE_PRG} -j CFLAGS=-fPIC
                              CFLAGS+=-DLUA_USE_APICHECK
                              CFLAGS+=-funwind-tables
                              ${NO_STACK_CHECK}
                              ${AMD64_ABI}
                              CCDEBUG+=-g
                              Q=)

# Setting MACOSX_DEPLOYMENT_TARGET is mandatory for LuaJIT; use version set by
# cmake.deps/CMakeLists.txt (either environment variable or current system version).
if(APPLE)
  set(DEPLOYMENT_TARGET "MACOSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

if(UNIX)
  BuildLuajit(INSTALL_COMMAND ${BUILDCMD_UNIX}
    CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR}
    ${DEPLOYMENT_TARGET} install)

elseif(MINGW)

  if(CMAKE_GENERATOR MATCHES "Ninja")
    set(LUAJIT_MAKE_PRG ${MAKE_PRG})
  else()
    set(LUAJIT_MAKE_PRG ${CMAKE_MAKE_PROGRAM})
  endif()
  BuildLuajit(BUILD_COMMAND ${LUAJIT_MAKE_PRG} CC=${DEPS_C_COMPILER}
                                PREFIX=${DEPS_INSTALL_DIR}
                                CFLAGS+=-DLUA_USE_APICHECK
                                CFLAGS+=-funwind-tables
                                CCDEBUG+=-g
                                BUILDMODE=static
                      # Build a DLL too
                      COMMAND ${LUAJIT_MAKE_PRG} CC=${DEPS_C_COMPILER} BUILDMODE=dynamic

          INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_BIN_DIR}
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/luajit.exe ${DEPS_BIN_DIR}
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_BIN_DIR}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_LIB_DIR}
	    # Luarocks searches for lua51.dll in lib
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_LIB_DIR}
	    COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/libluajit.a ${DEPS_LIB_DIR}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include/luajit-2.1
	    COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/luajit/src/*.h -DTO=${DEPS_INSTALL_DIR}/include/luajit-2.1 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/luajit/src/jit ${DEPS_INSTALL_DIR}/share/luajit-2.1/jit
	    )
elseif(MSVC)

  BuildLuajit(
    BUILD_COMMAND ${CMAKE_COMMAND} -E chdir ${DEPS_BUILD_DIR}/src/luajit/src ${DEPS_BUILD_DIR}/src/luajit/src/msvcbuild.bat
    INSTALL_COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_BIN_DIR}
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/luajit.exe ${DEPS_BIN_DIR}
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.dll ${DEPS_BIN_DIR}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_LIB_DIR}
      # Luarocks searches for lua51.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.lib ${DEPS_LIB_DIR}/lua51.lib
      # Luv searches for luajit.lib
      COMMAND ${CMAKE_COMMAND} -E copy ${DEPS_BUILD_DIR}/src/luajit/src/lua51.lib ${DEPS_LIB_DIR}/luajit.lib
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DEPS_INSTALL_DIR}/include/luajit-2.1
      COMMAND ${CMAKE_COMMAND} -DFROM_GLOB=${DEPS_BUILD_DIR}/src/luajit/src/*.h -DTO=${DEPS_INSTALL_DIR}/include/luajit-2.1 -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyFilesGlob.cmake
      COMMAND ${CMAKE_COMMAND} -E copy_directory ${DEPS_BUILD_DIR}/src/luajit/src/jit ${DEPS_INSTALL_DIR}/share/luajit-2.1/jit
      )
else()
  message(FATAL_ERROR "Trying to build luajit in an unsupported system ${CMAKE_SYSTEM_NAME}/${CMAKE_C_COMPILER_ID}")
endif()
