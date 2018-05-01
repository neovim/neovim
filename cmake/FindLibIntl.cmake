# - Try to find libintl
# Once done, this will define
#
#  LibIntl_FOUND        - system has libintl
#  LibIntl_INCLUDE_DIRS - the libintl include directories
#  LibIntl_LIBRARIES    - link these to use libintl

include(CheckCSourceCompiles)
include(CheckVariableExists)
include(LibFindMacros)

# Append custom gettext path to CMAKE_PREFIX_PATH
# if installed via Mac Hombrew
if (CMAKE_HOST_APPLE)
    find_program(HOMEBREW_PROG brew)
    if (EXISTS ${HOMEBREW_PROG})
        execute_process(COMMAND ${HOMEBREW_PROG} --prefix gettext
            OUTPUT_STRIP_TRAILING_WHITESPACE
            OUTPUT_VARIABLE HOMEBREW_GETTEXT_PREFIX)
        list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_GETTEXT_PREFIX}")
    endif()
endif()

find_path(LibIntl_INCLUDE_DIR
    NAMES libintl.h
    PATH_SUFFIXES gettext
)

find_library(LibIntl_LIBRARY
    NAMES intl libintl
)

if (LibIntl_INCLUDE_DIR)
  set(CMAKE_REQUIRED_INCLUDES "${LibIntl_INCLUDE_DIR}")
endif()

# This is required because some operating systems don't have a separate
# libintl--it is built into glibc.  So we only need to specify the library
# if one was actually found.
if (LibIntl_LIBRARY)
  set(CMAKE_REQUIRED_LIBRARIES "${LibIntl_LIBRARY}")
endif()

check_c_source_compiles("
#include <libintl.h>

int main(int argc, char** argv) {
  gettext(\"foo\");
  ngettext(\"foo\", \"bar\", 1);
  bindtextdomain(\"foo\", \"bar\");
  bind_textdomain_codeset(\"foo\", \"bar\");
  textdomain(\"foo\");
}" HAVE_WORKING_LIBINTL)

if (HAVE_WORKING_LIBINTL)
  check_variable_exists(_nl_msg_cat_cntr HAVE_NL_MSG_CAT_CNTR)
endif()

set(LibIntl_PROCESS_INCLUDES LibIntl_INCLUDE_DIR)
set(LibIntl_PROCESS_LIBS LibIntl_LIBRARY)
libfind_process(LibIntl)
