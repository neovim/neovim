include(CheckTypeSize)
include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFiles)
include(CheckCSourceRuns)
include(CheckCSourceCompiles)
include(TestBigEndian)

check_c_source_compiles("
#include <execinfo.h>
int main(void)
{
  void *trace[1];
  backtrace(trace, 1);
  return 0;
}
" HAVE_EXECINFO_BACKTRACE)

check_c_source_compiles("
int main(void)
{
  int a = 42;
  __builtin_add_overflow(a, a, &a);
  __builtin_sub_overflow(a, a, &a);
  return 0;
}
" HAVE_BUILTIN_ADD_OVERFLOW)

check_type_size("int" SIZEOF_INT LANGUAGE C)
check_type_size("long" SIZEOF_LONG LANGUAGE C)
check_type_size("intmax_t" SIZEOF_INTMAX_T LANGUAGE C)
check_type_size("size_t" SIZEOF_SIZE_T LANGUAGE C)
check_type_size("void *" SIZEOF_VOID_PTR LANGUAGE C)

check_symbol_exists(_NSGetEnviron crt_externs.h HAVE__NSGETENVIRON)

# Headers
check_include_files(langinfo.h HAVE_LANGINFO_H)
check_include_files(strings.h HAVE_STRINGS_H)
check_include_files(sys/utsname.h HAVE_SYS_UTSNAME_H)
check_include_files(termios.h HAVE_TERMIOS_H)
check_include_files(sys/uio.h HAVE_SYS_UIO_H)
check_include_files(sys/sdt.h HAVE_SYS_SDT_H)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  check_include_files(sys/xattr.h HAVE_XATTR)
endif()

# Functions
check_function_exists(fseeko HAVE_FSEEKO)
check_function_exists(readv HAVE_READV)
check_function_exists(readlink HAVE_READLINK)
check_function_exists(strnlen HAVE_STRNLEN)
check_function_exists(strcasecmp HAVE_STRCASECMP)
check_function_exists(strncasecmp HAVE_STRNCASECMP)
check_function_exists(strptime HAVE_STRPTIME)

check_c_source_compiles("
#include <sys/types.h>
#include <dirent.h>
#include <sys/file.h>
int main(void)
{
  DIR *dir = opendir(\"dirname\");
  dirfd(dir);
  flock(10, LOCK_SH);
  return 0;
}
" HAVE_DIRFD_AND_FLOCK)


check_c_source_compiles("
#include <pwd.h>
int main(void)
{
  getpwent();
  getpwuid(0);
  getpwnam(\"root\");
  return 0;
}
" HAVE_PWD_FUNCS)

check_c_source_compiles("
#include <intrin.h>

int main(void)
{
  unsigned long index;
  unsigned char mask = 0x8000;
  _BitScanForward64(&index, mask);
  return 0;
}
" HAVE_BITSCANFORWARD64)

if(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
  check_c_source_compiles("
#include <termios.h>
int
main(void)
{
  return forkpty(0, NULL, NULL, NULL);
}
" HAVE_FORKPTY)
else()
  set(HAVE_FORKPTY 1)
endif()

# Symbols
check_symbol_exists(FD_CLOEXEC "fcntl.h" HAVE_FD_CLOEXEC)
if(HAVE_LANGINFO_H)
  check_symbol_exists(CODESET "langinfo.h" HAVE_NL_LANGINFO_CODESET)
endif()

check_include_files("endian.h" HAVE_ENDIAN_H)

set(ENDIAN_INCLUDE_FILE "endian.h")
if(NOT HAVE_ENDIAN_H)
  check_include_files("sys/endian.h" HAVE_SYS_ENDIAN_H)
  if (HAVE_SYS_ENDIAN_H)
    set(ENDIAN_INCLUDE_FILE "sys/endian.h")
  endif()
endif()

set(SI "#include <stdint.h>\n")
set(MS "int main(int argc,char**argv)\n{\n  uint64_t i=0x0102030405060708ULL;")
set(ME "}")
check_c_source_compiles("
  #define _BSD_SOURCE 1
  #define _DEFAULT_SOURCE 1
  ${SI}
  #include <${ENDIAN_INCLUDE_FILE}>
  #ifndef be64toh
  # error No be64toh macros
  #endif
  ${MS}
    uint64_t j = be64toh(i);
    return (j == 0);  // j must not be zero
  ${ME}"
  HAVE_BE64TOH_MACROS)
if(NOT "${HAVE_BE64TOH_MACROS}")
  check_function_exists(be64toh HAVE_BE64TOH_FUNC)
endif()
if("${HAVE_BE64TOH_MACROS}" OR "${HAVE_BE64TOH_FUNC}")
  set(HAVE_BE64TOH 1)
endif()

test_big_endian(ORDER_BIG_ENDIAN)

configure_file (
  "${PROJECT_SOURCE_DIR}/cmake.config/config.h.in"
  "${PROJECT_BINARY_DIR}/cmake.config/auto/config.h"
  )

set(VERSION_STRING "${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} ")

foreach(BUILD_TYPE Debug Release RelWithDebInfo MinSizeRel)
  string(TOUPPER ${BUILD_TYPE} BUILD_TYPE_UPPER)
  set(GEN_CONFIG "$<CONFIG:${BUILD_TYPE}>")

  set(GEN_RHS "${CMAKE_C_FLAGS_${BUILD_TYPE_UPPER}} ")
  string(APPEND VERSION_STRING "$<${GEN_CONFIG}:${GEN_RHS}>")

  set(GEN_RHS "$<$<BOOL:$<TARGET_PROPERTY:nvim_bin,INTERPROCEDURAL_OPTIMIZATION_${BUILD_TYPE_UPPER}>>:${CMAKE_C_COMPILE_OPTIONS_IPO}>")
  string(APPEND VERSION_STRING "$<${GEN_CONFIG}:${GEN_RHS}>")
endforeach()

string(APPEND VERSION_STRING " ")

function(append_target_expression)
  cmake_parse_arguments(ARG
    ""
    "PREFIX;PROPERTY"
    ""
    ${ARGN})

  set(TARGET_EXPRESSION "$<TARGET_PROPERTY:nvim_bin,${ARG_PROPERTY}>")
  set(TARGET_EXPRESSION "$<REMOVE_DUPLICATES:${TARGET_EXPRESSION}>")
  set(TARGET_EXPRESSION "${ARG_PREFIX}$<JOIN:${TARGET_EXPRESSION}, ${ARG_PREFIX}>")

  set(VERSION_STRING "${VERSION_STRING} ${TARGET_EXPRESSION} " PARENT_SCOPE)
endfunction()
append_target_expression(PROPERTY COMPILE_OPTIONS)
append_target_expression(PROPERTY LINK_OPTIONS)
append_target_expression(PREFIX "-D" PROPERTY COMPILE_DEFINITIONS)
append_target_expression(PREFIX "-I" PROPERTY INCLUDE_DIRECTORIES)
string(REPLACE ";" " " VERSION_STRING "${VERSION_STRING}")
string(REPLACE "  " " " VERSION_STRING "${VERSION_STRING}")

configure_file(versiondef.h.in auto/versiondef.h.gen)

file(GENERATE
  OUTPUT "${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef-$<CONFIG>.h"
  INPUT "${PROJECT_BINARY_DIR}/cmake.config/auto/versiondef.h.gen")

configure_file (
  "${PROJECT_SOURCE_DIR}/cmake.config/pathdef.h.in"
  "${PROJECT_BINARY_DIR}/cmake.config/auto/pathdef.h"
  ESCAPE_QUOTES)
