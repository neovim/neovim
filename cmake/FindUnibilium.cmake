# - Try to find unibilium
# Once done this will define
#  UNIBILIUM_FOUND - System has unibilium
#  UNIBILIUM_INCLUDE_DIRS - The unibilium include directories
#  UNIBILIUM_LIBRARIES - The libraries needed to use unibilium

find_package(PkgConfig)
if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_UNIBILIUM QUIET unibilium)
endif()

set(UNIBILIUM_DEFINITIONS ${PC_UNIBILIUM_CFLAGS_OTHER})

find_path(UNIBILIUM_INCLUDE_DIR unibilium.h
          PATHS ${PC_UNIBILIUM_INCLUDEDIR} ${PC_UNIBILIUM_INCLUDE_DIRS})

# If we're asked to use static linkage, add libunibilium.a as a preferred library name.
if(UNIBILIUM_USE_STATIC)
  list(APPEND UNIBILIUM_NAMES
    "${CMAKE_STATIC_LIBRARY_PREFIX}unibilium${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

list(APPEND UNIBILIUM_NAMES unibilium)

find_library(UNIBILIUM_LIBRARY NAMES ${UNIBILIUM_NAMES}
  HINTS ${PC_UNIBILIUM_LIBDIR} ${PC_UNIBILIUM_LIBRARY_DIRS})

set(UNIBILIUM_LIBRARIES ${UNIBILIUM_LIBRARY})
set(UNIBILIUM_INCLUDE_DIRS ${UNIBILIUM_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set UNIBILIUM_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(Unibilium DEFAULT_MSG
  UNIBILIUM_LIBRARY UNIBILIUM_INCLUDE_DIR)

mark_as_advanced(UNIBILIUM_INCLUDE_DIR UNIBILIUM_LIBRARY)
