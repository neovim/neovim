# - Try to find utf8proc
# Once done this will define
#  UTF8PROC_FOUND - System has utf8proc
#  UTF8PROC_INCLUDE_DIRS - The utf8proc include directories
#  UTF8PROC_LIBRARIES - The libraries needed to use utf8proc

if(NOT USE_BUNDLED_UTF8PROC)
  find_package(PkgConfig)
  if (PKG_CONFIG_FOUND)
      pkg_check_modules(PC_UTF8PROC QUIET utf8proc)
  endif()
else()
  set(PC_UTF8PROC_INCLUDEDIR)
  set(PC_UTF8PROC_INCLUDE_DIRS)
  set(PC_UTF8PROC_LIBDIR)
  set(PC_UTF8PROC_LIBRARY_DIRS)
  set(LIMIT_SEARCH NO_DEFAULT_PATH)
endif()

set(UTF8PROC_DEFINITIONS ${PC_UTF8PROC_CFLAGS_OTHER})

find_path(UTF8PROC_INCLUDE_DIR utf8proc.h
          PATHS ${PC_UTF8PROC_INCLUDEDIR} ${PC_UTF8PROC_INCLUDE_DIRS}
          ${LIMIT_SEARCH})

# If we're asked to use static linkage, add libutf8proc.a as a preferred library name.
if(UTF8PROC_USE_STATIC)
  list(APPEND UTF8PROC_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}utf8proc${CMAKE_STATIC_LIBRARY_SUFFIX}")
if(MSVC)
  list(APPEND UTF8PROC_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}utf8proc_static${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()
endif()

list(APPEND UTF8PROC_NAMES utf8proc)
if(MSVC)
  list(APPEND UTF8PROC_NAMES utf8proc_static)
endif()

find_library(UTF8PROC_LIBRARY NAMES ${UTF8PROC_NAMES}
  HINTS ${PC_UTF8PROC_LIBDIR} ${PC_UTF8PROC_LIBRARY_DIRS}
  ${LIMIT_SEARCH})

set(UTF8PROC_LIBRARIES ${UTF8PROC_LIBRARY})
set(UTF8PROC_INCLUDE_DIRS ${UTF8PROC_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set UTF8PROC_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(Utf8proc DEFAULT_MSG
  UTF8PROC_LIBRARY UTF8PROC_INCLUDE_DIR)

mark_as_advanced(UTF8PROC_INCLUDE_DIR UTF8PROC_LIBRARY)
