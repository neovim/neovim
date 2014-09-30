include(CheckTypeSize)
include(CheckSymbolExists)
include(CheckFunctionExists)
include(CheckIncludeFiles)

check_type_size("int" SIZEOF_INT)
check_type_size("long" SIZEOF_LONG)
check_type_size("time_t" SIZEOF_TIME_T)
check_type_size("off_t" SIZEOF_OFF_T)
check_type_size("void *" SIZEOF_VOID_PTR)

check_symbol_exists(_NSGetEnviron crt_externs.h HAVE__NSGETENVIRON)

# Headers
check_include_files(dirent.h HAVE_DIRENT_H)
check_include_files(fcntl.h HAVE_FCNTL_H)
check_include_files(iconv.h HAVE_ICONV_H)
check_include_files(langinfo.h HAVE_LANGINFO_H)
check_include_files(libgen.h HAVE_LIBGEN_H)
check_include_files(locale.h HAVE_LOCALE_H)
check_include_files(pwd.h HAVE_PWD_H)
check_include_files(strings.h HAVE_STRINGS_H)
check_include_files(stropts.h HAVE_STROPTS_H)
check_include_files(sys/ioctl.h HAVE_SYS_IOCTL_H)
check_include_files(sys/param.h HAVE_SYS_PARAM_H)
check_include_files(sys/time.h HAVE_SYS_TIME_H)
check_include_files(sys/wait.h HAVE_SYS_WAIT_H)
if(NOT HAVE_SYS_WAIT_H AND UNIX)
  # See if_cscope.c
  message(SEND_ERROR "header sys/wait.h is required for UNIX")
endif()
check_include_files(sys/utsname.h HAVE_SYS_UTSNAME_H)
check_include_files(utime.h HAVE_UTIME_H)
check_include_files(termcap.h HAVE_TERMCAP_H)
check_include_files(termios.h HAVE_TERMIOS_H)
check_include_files(termio.h HAVE_TERMIO_H)
check_include_files(unistd.h HAVE_UNISTD_H)
check_include_files(utime.h HAVE_UTIME_H)

# Functions
check_function_exists(fseeko HAVE_FSEEKO)
check_function_exists(fsync HAVE_FSYNC)
check_function_exists(getpwent HAVE_GETPWENT)
check_function_exists(getpwnam HAVE_GETPWNAM)
check_function_exists(getpwuid HAVE_GETPWUID)
check_function_exists(iconv HAVE_ICONV)
check_function_exists(lstat HAVE_LSTAT)
if(NOT HAVE_LSTAT)
  # os_unix.c uses lstat.c
  message(SEND_ERROR "lstat() function not found on your system.")
endif()
check_function_exists(putenv HAVE_PUTENV)
check_function_exists(opendir HAVE_OPENDIR)
check_function_exists(readlink HAVE_READLINK)
check_function_exists(setenv HAVE_SETENV)
if(NOT HAVE_SETENV)
  message(SEND_ERROR "setenv() function not found on your system.")
endif()
check_function_exists(setpgid HAVE_SETPGID)
check_function_exists(setsid HAVE_SETSID)
check_function_exists(sigaction HAVE_SIGACTION)
check_function_exists(sigvec HAVE_SIGVEC)
check_function_exists(strcasecmp HAVE_STRCASECMP)
check_function_exists(strncasecmp HAVE_STRNCASECMP)
check_function_exists(utime HAVE_UTIME)
check_function_exists(utimes HAVE_UTIMES)

# Symbols
check_symbol_exists(FD_CLOEXEC "fcntl.h" HAVE_FD_CLOEXEC)
if(HAVE_LANGINFO_H)
  check_symbol_exists(CODESET "langinfo.h" HAVE_NL_LANGINFO_CODESET)
endif()

# generate configuration header and update include directories
configure_file (
  "${PROJECT_SOURCE_DIR}/config/config.h.in"
  "${PROJECT_BINARY_DIR}/config/auto/config.h"
  )

# generate pathdef.c
find_program(WHOAMI_PROG whoami)
find_program(HOSTNAME_PROG hostname)

if (NOT DEFINED USERNAME AND EXISTS ${WHOAMI_PROG})
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
