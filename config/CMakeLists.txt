include(CheckTypeSize)
include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFiles)
include(CheckCSourceRuns)
include(CheckCSourceCompiles)

check_type_size("int" SIZEOF_INT)
check_type_size("long" SIZEOF_LONG)
check_type_size("intmax_t" SIZEOF_INTMAX_T)
check_type_size("size_t" SIZEOF_SIZE_T)
check_type_size("long long" SIZEOF_LONG_LONG)
check_type_size("void *" SIZEOF_VOID_PTR)

if (CMAKE_HOST_SYSTEM_VERSION MATCHES ".*-Microsoft")
  # Windows Subsystem for Linux
  set(HAVE_WSL 1)
endif()

check_symbol_exists(_NSGetEnviron crt_externs.h HAVE__NSGETENVIRON)

# Headers
check_include_files(iconv.h HAVE_ICONV_H)
check_include_files(langinfo.h HAVE_LANGINFO_H)
check_include_files(locale.h HAVE_LOCALE_H)
check_include_files(pwd.h HAVE_PWD_H)
check_include_files(strings.h HAVE_STRINGS_H)
check_include_files(sys/wait.h HAVE_SYS_WAIT_H)
if(NOT HAVE_SYS_WAIT_H AND UNIX)
  # See if_cscope.c
  message(SEND_ERROR "header sys/wait.h is required for Unix")
endif()
check_include_files(sys/utsname.h HAVE_SYS_UTSNAME_H)
check_include_files(termios.h HAVE_TERMIOS_H)
check_include_files(utime.h HAVE_UTIME_H)
check_include_files(sys/uio.h HAVE_SYS_UIO_H)

# Functions
check_function_exists(fseeko HAVE_FSEEKO)
check_function_exists(getpwent HAVE_GETPWENT)
check_function_exists(getpwnam HAVE_GETPWNAM)
check_function_exists(getpwuid HAVE_GETPWUID)
check_function_exists(uv_translate_sys_error HAVE_UV_TRANSLATE_SYS_ERROR)
check_function_exists(readv HAVE_READV)

if(Iconv_FOUND)
  set(HAVE_ICONV 1)
endif()

if(JEMALLOC_FOUND)
  set(HAVE_JEMALLOC 1)
endif()

check_function_exists(_putenv_s HAVE_PUTENV_S)
if(WIN32 AND NOT HAVE_PUTENV_S)
  message(SEND_ERROR "_putenv_s() function not found on your system.")
endif()
check_function_exists(opendir HAVE_OPENDIR)
check_function_exists(readlink HAVE_READLINK)
check_function_exists(setenv HAVE_SETENV)
if(UNIX AND NOT HAVE_SETENV)
  message(SEND_ERROR "setenv() function not found on your system.")
endif()
check_function_exists(unsetenv HAVE_UNSETENV)
check_function_exists(setpgid HAVE_SETPGID)
check_function_exists(setsid HAVE_SETSID)
check_function_exists(sigaction HAVE_SIGACTION)
check_function_exists(strcasecmp HAVE_STRCASECMP)
check_function_exists(strncasecmp HAVE_STRNCASECMP)
check_function_exists(utime HAVE_UTIME)
check_function_exists(utimes HAVE_UTIMES)

# Symbols
check_symbol_exists(FD_CLOEXEC "fcntl.h" HAVE_FD_CLOEXEC)
if(HAVE_LANGINFO_H)
  check_symbol_exists(CODESET "langinfo.h" HAVE_NL_LANGINFO_CODESET)
endif()

check_include_files("endian.h" HAVE_ENDIAN_H)
check_include_files("sys/endian.h" HAVE_SYS_ENDIAN_H)

set(ENDIAN_INCLUDE_FILE "endian.h")
if(HAVE_SYS_ENDIAN_H AND NOT HAVE_ENDIAN_H)
  set(ENDIAN_INCLUDE_FILE "sys/endian.h")
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
if (NOT "${HAVE_BE64TOH}")
  if (NOT "${CMAKE_CROSSCOMPILING}")
    # It is safe to make ORDER_BIG_ENDIAN not defined if
    # - HAVE_BE64TOH is true. In this case be64toh will be used unconditionally in
    #   any case and ORDER_BIG_ENDIAN will not be examined.
    # - CMAKE_CROSSCOMPILING *and* HAVE_BE64TOH are both false. In this case
    #   be64toh function which uses cycle and arithmetic operations is used which
    #   will work regardless of endianess. Function is sub-optimal though.
    check_c_source_runs("
      ${SI}
      ${MS}
        char *s = (char *) &i;
        return (
          s[0] == 0x01
          && s[1] == 0x02
          && s[2] == 0x03
          && s[3] == 0x04
          && s[4] == 0x05
          && s[5] == 0x06
          && s[6] == 0x07
          && s[7] == 0x08) ? 0 : 1;
      ${ME}"
      ORDER_BIG_ENDIAN)
  endif()
endif()

# generate configuration header and update include directories
configure_file (
  "${PROJECT_SOURCE_DIR}/config/config.h.in"
  "${PROJECT_BINARY_DIR}/config/auto/config.h"
  )

# generate version definitions
configure_file (
  "${PROJECT_SOURCE_DIR}/config/versiondef.h.in"
  "${PROJECT_BINARY_DIR}/config/auto/versiondef.h"
  )

# generate pathdef.c
find_program(WHOAMI_PROG whoami)
find_program(HOSTNAME_PROG hostname)

if (DEFINED ENV{USERNAME})
  set(USERNAME $ENV{USERNAME})
elseif (NOT DEFINED USERNAME AND EXISTS ${WHOAMI_PROG})
  execute_process(COMMAND ${WHOAMI_PROG}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE USERNAME)
endif()
if (DEFINED ENV{HOSTNAME})
  set(HOSTNAME $ENV{HOSTNAME})
elseif (EXISTS ${HOSTNAME_PROG})
  execute_process(COMMAND ${HOSTNAME_PROG}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    OUTPUT_VARIABLE HOSTNAME)
endif()

configure_file (
  "${PROJECT_SOURCE_DIR}/config/pathdef.c.in"
  "${PROJECT_BINARY_DIR}/config/auto/pathdef.c"
  ESCAPE_QUOTES)
