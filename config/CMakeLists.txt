include(CheckTypeSize)
include(CheckCSourceCompiles)

check_type_size("int" SIZEOF_INT)
check_type_size("long" SIZEOF_LONG)
check_type_size("time_t" SIZEOF_TIME_T)
check_type_size("off_t" SIZEOF_OFF_T)

if (CMAKE_HOST_APPLE)
  find_program(HAVE_HOMEBREW brew)
  if (HAVE_HOMEBREW)
    execute_process(COMMAND brew --prefix gettext
      OUTPUT_VARIABLE _TMP_HOMEBREW_GETTEXT_PREFIX
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(HOMEBREW_GETTEXT_PREFIX ${_TMP_HOMEBREW_GETTEXT_PREFIX}
      CACHE
      PATH "homebrew gettext directory (${_TMP_HOMEBREW_GETTEXT_PREFIX})")
    list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_GETTEXT_PREFIX}")
  endif()
endif()

find_path(LIBINTL_INCLUDE_DIR libintl.h)
find_library(LIBINTL_LIB intl)
get_filename_component(LIBINTL_LIB_DIR "${LIBINTL_LIB}" NAME)

if (LIBINTL_INCLUDE_DIR)
  set(CMAKE_REQUIRED_INCLUDES "${LIBINTL_INCLUDE_DIR}")
endif()

# This is required because some operating systems don't have a separate
# libintl--it is built into glibc.  So we only need to specify the library if
# one was actually found.
if (LIBINTL_LIB)
  set(CMAKE_REQUIRED_LIBRARIES "${LIBINTL_LIB}")
endif()

check_c_source_compiles("
#include <libintl.h>

int main(int argc, char** argv) {
  gettext(\"foo\");
  bindtextdomain(\"foo\", \"bar\");
  bind_textdomain_codeset(\"foo\", \"bar\");
  textdomain(\"foo\");
}" HAVE_LIBINTL)

# generate configuration header and update include directories
configure_file (
  "${PROJECT_SOURCE_DIR}/config/config.h.in"
  "${PROJECT_BINARY_DIR}/config/auto/config.h"
  )
# generate pathdef.c
find_program(WHOAMI_PROG whoami)
find_program(HOSTNAME_PROG hostname)

if (EXISTS ${WHOAMI_PROG})
  execute_process(COMMAND ${WHOAMI_PROG}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE USERNAME)
endif()
if (EXISTS ${HOSTNAME_PROG})
  execute_process(COMMAND ${HOSTNAME_PROG}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE HOSTNAME)
endif()

configure_file (
  "${PROJECT_SOURCE_DIR}/config/pathdef.c.in"
  "${PROJECT_BINARY_DIR}/config/auto/pathdef.c"
  ESCAPE_QUOTES)
