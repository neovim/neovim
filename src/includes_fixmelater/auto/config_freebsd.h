#pragma once

#define SIZEOF_INT 4
#define SIZEOF_INTMAX_T 8
#define SIZEOF_LONG 8
#define SIZEOF_SIZE_T 8

#if 8 == 8
#define ARCH_64
#elif 8 == 4
#define ARCH_32
#endif

#define PROJECT_NAME "nvim"

/* #undef HAVE__NSGETENVIRON */
#define HAVE_FD_CLOEXEC
#define HAVE_FSEEKO
#define HAVE_LANGINFO_H
#define HAVE_NL_LANGINFO_CODESET
/* #undef HAVE_NL_MSG_CAT_CNTR */
#define HAVE_PWD_FUNCS
#define HAVE_READLINK
#define HAVE_STRNLEN
#define HAVE_STRCASECMP
#define HAVE_STRINGS_H
#define HAVE_STRNCASECMP
#define HAVE_STRPTIME
/* #undef HAVE_XATTR */
#define HAVE_SYS_SDT_H
#define HAVE_SYS_UTSNAME_H
/* #undef HAVE_SYS_WAIT_H */
#define HAVE_TERMIOS_H
#define HAVE_WORKING_LIBINTL
#define UNIX
/* #undef CASE_INSENSITIVE_FILENAME */
/* #undef USE_FNAME_CASE */
#define HAVE_SYS_UIO_H
#ifdef HAVE_SYS_UIO_H
#define HAVE_READV
# ifndef HAVE_READV
#  undef HAVE_SYS_UIO_H
# endif
#endif
#define HAVE_DIRFD_AND_FLOCK
#define HAVE_FORKPTY

#define HAVE_BE64TOH
/* #undef ORDER_BIG_ENDIAN */
#define ENDIAN_INCLUDE_FILE <endian.h>

/* #undef HAVE_EXECINFO_BACKTRACE */
#define HAVE_BUILTIN_ADD_OVERFLOW
#define HAVE_WIMPLICIT_FALLTHROUGH_FLAG
/* #undef HAVE_BITSCANFORWARD64 */
