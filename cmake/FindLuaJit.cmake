# - Try to find luajit
# Once done this will define
#  LUAJIT_FOUND - System has luajit
#  LUAJIT_INCLUDE_DIRS - The luajit include directories
#  LUAJIT_LIBRARIES - The libraries needed to use luajit

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_LUAJIT QUIET luajit)
endif()

set(LUAJIT_DEFINITIONS ${PC_LUAJIT_CFLAGS_OTHER})

find_path(LUAJIT_INCLUDE_DIR luajit.h
          PATHS ${PC_LUAJIT_INCLUDEDIR} ${PC_LUAJIT_INCLUDE_DIRS}
          PATH_SUFFIXES luajit-2.0)

# If we're asked to use static linkage, add libluajit-5.1.a as a preferred
# library name.
if(LUAJIT_USE_STATIC)
  list(APPEND LUAJIT_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}luajit-5.1${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

if(MSVC)
  list(APPEND LUAJIT_NAMES lua51)
elseif(MINGW)
  list(APPEND LUAJIT_NAMES libluajit libluajit-5.1)
else()
  list(APPEND LUAJIT_NAMES luajit-5.1)
endif()

find_library(LUAJIT_LIBRARY NAMES ${LUAJIT_NAMES}
             PATHS ${PC_LUAJIT_LIBDIR} ${PC_LUAJIT_LIBRARY_DIRS})

set(LUAJIT_LIBRARIES ${LUAJIT_LIBRARY})
set(LUAJIT_INCLUDE_DIRS ${LUAJIT_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set LUAJIT_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(LuaJit DEFAULT_MSG
                                  LUAJIT_LIBRARY LUAJIT_INCLUDE_DIR)

mark_as_advanced(LUAJIT_INCLUDE_DIR LUAJIT_LIBRARY)
