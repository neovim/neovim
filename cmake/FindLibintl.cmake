include(CheckCSourceCompiles)
include(CheckVariableExists)

# Append custom gettext path to CMAKE_PREFIX_PATH
# if installed via Mac Homebrew
if (APPLE)
    find_program(HOMEBREW_PRG brew)
    if (EXISTS ${HOMEBREW_PRG})
        execute_process(COMMAND ${HOMEBREW_PRG} --prefix gettext
            OUTPUT_STRIP_TRAILING_WHITESPACE
            OUTPUT_VARIABLE HOMEBREW_GETTEXT_PREFIX)
        list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_GETTEXT_PREFIX}")
    endif()
endif()

find_path(LIBINTL_INCLUDE_DIR
    NAMES libintl.h
    PATH_SUFFIXES gettext
)

find_library(LIBINTL_LIBRARY
    NAMES intl libintl
)

if (LIBINTL_INCLUDE_DIR)
  list(APPEND CMAKE_REQUIRED_INCLUDES "${LIBINTL_INCLUDE_DIR}")
endif()
# On some systems (linux+glibc) libintl is passively available.
# So only specify the library if one was found.
if (LIBINTL_LIBRARY)
  list(APPEND CMAKE_REQUIRED_LIBRARIES "${LIBINTL_LIBRARY}")
endif()
if (MSVC)
  list(APPEND CMAKE_REQUIRED_LIBRARIES ${ICONV_LIBRARY})
endif()

# On macOS, if libintl is a static library then we also need
# to link libiconv and CoreFoundation.
get_filename_component(LibIntl_EXT "${LIBINTL_LIBRARY}" EXT)
if (APPLE AND (LibIntl_EXT STREQUAL ".a"))
  set(LibIntl_STATIC TRUE)
  find_library(CoreFoundation_FRAMEWORK CoreFoundation)
  list(APPEND CMAKE_REQUIRED_LIBRARIES "${ICONV_LIBRARY}" "${CoreFoundation_FRAMEWORK}")
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
if (MSVC)
  list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES ${ICONV_LIBRARY})
endif()
if (LibIntl_STATIC)
  list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES  "${ICONV_LIBRARY}" "${CoreFoundation_FRAMEWORK}")
endif()
if (LIBINTL_INCLUDE_DIR)
  list(REMOVE_ITEM CMAKE_REQUIRED_INCLUDES "${LIBINTL_INCLUDE_DIR}")
endif()
if (LIBINTL_LIBRARY)
  list(REMOVE_ITEM CMAKE_REQUIRED_LIBRARIES "${LIBINTL_LIBRARY}")
endif()

set(REQUIRED_VARIABLES LIBINTL_LIBRARY LIBINTL_INCLUDE_DIR)
if (HAVE_WORKING_LIBINTL)
  # On some systems (linux+glibc) libintl is passively available.
  # If HAVE_WORKING_LIBINTL then we consider the requirement satisfied.
  unset(REQUIRED_VARIABLES)

  check_variable_exists(_nl_msg_cat_cntr HAVE_NL_MSG_CAT_CNTR)
endif()

find_package_handle_standard_args(Libintl DEFAULT_MSG
  ${REQUIRED_VARIABLES})
mark_as_advanced(LIBINTL_LIBRARY LIBINTL_INCLUDE_DIR)

add_library(libintl INTERFACE)
target_include_directories(libintl SYSTEM BEFORE INTERFACE ${LIBINTL_INCLUDE_DIR})
if (LIBINTL_LIBRARY)
  target_link_libraries(libintl INTERFACE ${LIBINTL_LIBRARY})
endif()
