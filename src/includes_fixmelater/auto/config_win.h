#pragma once

#define SIZEOF_INT 4
#define SIZEOF_INTMAX_T 8
#define SIZEOF_LONG 4
#define SIZEOF_SIZE_T 8

#if 8 == 8
#define ARCH_64
#elif 8 == 4
#define ARCH_32
#endif

#define PROJECT_NAME "nvim"

/* #undef HAVE__NSGETENVIRON */
/* #undef HAVE_FD_CLOEXEC */
/* #undef HAVE_FSEEKO */
/* #undef HAVE_LANGINFO_H */
/* #undef HAVE_NL_LANGINFO_CODESET */
/* #undef HAVE_NL_MSG_CAT_CNTR */
/* #undef HAVE_PWD_FUNCS */
/* #undef HAVE_READLINK */
#define HAVE_STRNLEN
/* #undef HAVE_STRCASECMP */
/* #undef HAVE_STRINGS_H */
/* #undef HAVE_STRNCASECMP */
/* #undef HAVE_STRPTIME */
/* #undef HAVE_XATTR */
/* #undef HAVE_SYS_SDT_H */
/* #undef HAVE_SYS_UTSNAME_H */
/* #undef HAVE_SYS_WAIT_H */
/* #undef HAVE_TERMIOS_H */
#define HAVE_WORKING_LIBINTL
/* #undef UNIX */
#define CASE_INSENSITIVE_FILENAME
/* #undef HAVE_SYS_UIO_H */
#ifdef HAVE_SYS_UIO_H
/* #undef HAVE_READV */
# ifndef HAVE_READV
#  undef HAVE_SYS_UIO_H
# endif
#endif
/* #undef HAVE_DIRFD_AND_FLOCK */
#define HAVE_FORKPTY

/* #undef HAVE_BE64TOH */
/* #undef ORDER_BIG_ENDIAN */
#define ENDIAN_INCLUDE_FILE <endian.h>

/* #undef HAVE_EXECINFO_BACKTRACE */
/* #undef HAVE_BUILTIN_ADD_OVERFLOW */
/* #undef HAVE_WIMPLICIT_FALLTHROUGH_FLAG */
#define HAVE_BITSCANFORWARD64
