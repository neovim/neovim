# BuildLuajit(TARGET targetname CONFIGURE_COMMAND ... BUILD_COMMAND ... INSTALL_COMMAND ...)
# Reusable function to build luajit, wraps ExternalProject_Add.
# Failing to pass a command argument will result in no command being run
function(BuildLuajit)
  cmake_parse_arguments(_luajit
    ""
    "TARGET"
    "CONFIGURE_COMMAND;BUILD_COMMAND;INSTALL_COMMAND;DEPENDS"
    ${ARGN})
  if(NOT _luajit_CONFIGURE_COMMAND AND NOT _luajit_BUILD_COMMAND
        AND NOT _luajit_INSTALL_COMMAND)
    message(FATAL_ERROR "Must pass at least one of CONFIGURE_COMMAND, BUILD_COMMAND, INSTALL_COMMAND")
  endif()
  if(NOT _luajit_TARGET)
    set(_luajit_TARGET "luajit")
  endif()

  ExternalProject_Add(${_luajit_TARGET}
    URL ${LUAJIT_URL}
    URL_HASH SHA256=${LUAJIT_SHA256}
    DOWNLOAD_NO_PROGRESS TRUE
    DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/luajit
    CONFIGURE_COMMAND "${_luajit_CONFIGURE_COMMAND}"
    BUILD_IN_SOURCE 1
    BUILD_COMMAND "${_luajit_BUILD_COMMAND}"
    INSTALL_COMMAND "${_luajit_INSTALL_COMMAND}"
    DEPENDS "${_luajit_DEPENDS}")
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

if((UNIX AND NOT APPLE) OR (APPLE AND NOT CMAKE_OSX_ARCHITECTURES))
  BuildLuaJit(INSTALL_COMMAND ${BUILDCMD_UNIX}
    CC=${DEPS_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR}
    ${DEPLOYMENT_TARGET} install)

elseif(CMAKE_OSX_ARCHITECTURES AND APPLE)

  set(LUAJIT_C_COMPILER "${CMAKE_C_COMPILER}")
  if(CMAKE_OSX_SYSROOT)
    set(LUAJIT_C_COMPILER "${LUAJIT_C_COMPILER} -isysroot${CMAKE_OSX_SYSROOT}")
  endif()

  # Passing multiple `-arch` flags to the LuaJIT build will cause it to fail.
  # To get a working universal build, we build each requested architecture slice
  # individually then `lipo` them all up.
  set(LUAJIT_SRC_DIR "${DEPS_BUILD_DIR}/src/luajit")
  foreach(ARCH IN LISTS CMAKE_OSX_ARCHITECTURES)
    set(STATIC_CC "${LUAJIT_C_COMPILER} -arch ${ARCH}")
    set(DYNAMIC_CC "${LUAJIT_C_COMPILER} -arch ${ARCH} -fPIC")
    set(TARGET_LD "${LUAJIT_C_COMPILER} -arch ${ARCH}")
    list(APPEND LUAJIT_THIN_EXECUTABLES "${LUAJIT_SRC_DIR}-${ARCH}/src/luajit")
    list(APPEND LUAJIT_THIN_STATIC_LIBS "${LUAJIT_SRC_DIR}-${ARCH}/src/libluajit.a")
    list(APPEND LUAJIT_THIN_DYLIBS "${LUAJIT_SRC_DIR}-${ARCH}/src/libluajit.so")
    list(APPEND LUAJIT_THIN_TARGETS "luajit-${ARCH}")

    # See https://luajit.org/install.html#cross.
    BuildLuaJit(TARGET "luajit-${ARCH}"
        BUILD_COMMAND ${BUILDCMD_UNIX}
        CC=${LUAJIT_C_COMPILER} STATIC_CC=${STATIC_CC}
        DYNAMIC_CC=${DYNAMIC_CC} TARGET_LD=${TARGET_LD}
        PREFIX=${DEPS_INSTALL_DIR}
        ${DEPLOYMENT_TARGET})
  endforeach()
  BuildLuaJit(
    CONFIGURE_COMMAND ${BUILDCMD_UNIX} CC=${LUAJIT_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR} ${DEPLOYMENT_TARGET}
    COMMAND ${CMAKE_COMMAND} -E rm -f ${LUAJIT_SRC_DIR}/src/luajit ${LUAJIT_SRC_DIR}/src/libluajit.so ${LUAJIT_SRC_DIR}/src/libluajit.a
    BUILD_COMMAND lipo ${LUAJIT_THIN_EXECUTABLES} -create -output ${LUAJIT_SRC_DIR}/src/luajit
    COMMAND lipo ${LUAJIT_THIN_STATIC_LIBS} -create -output ${LUAJIT_SRC_DIR}/src/libluajit.a
    COMMAND lipo ${LUAJIT_THIN_DYLIBS} -create -output ${LUAJIT_SRC_DIR}/src/libluajit.so
    INSTALL_COMMAND ${BUILDCMD_UNIX} CC=${LUAJIT_C_COMPILER} PREFIX=${DEPS_INSTALL_DIR} ${DEPLOYMENT_TARGET} install
    DEPENDS ${LUAJIT_THIN_TARGETS}
    )

elseif(MINGW)

  if(CMAKE_GENERATOR MATCHES "Ninja")
    set(LUAJIT_MAKE_PRG ${MAKE_PRG})
  else()
    set(LUAJIT_MAKE_PRG ${CMAKE_MAKE_PROGRAM})
  endif()
  BuildLuaJit(BUILD_COMMAND ${LUAJIT_MAKE_PRG} CC=${DEPS_C_COMPILER}
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

  BuildLuaJit(
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
