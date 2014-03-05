/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * os_unixx.h -- include files that are only used in os_unix.c
 */

/*
 * Stuff for signals
 */
#if defined(HAVE_SIGSET) && !defined(signal)
# define signal sigset
#endif

/* sun's sys/ioctl.h redefines symbols from termio world */
#if defined(HAVE_SYS_IOCTL_H) && !defined(sun)
# include <sys/ioctl.h>
#endif

# if defined(HAVE_SYS_WAIT_H) || defined(HAVE_UNION_WAIT)
#  include <sys/wait.h>
# endif

# ifndef WEXITSTATUS
#  ifdef HAVE_UNION_WAIT
#   define WEXITSTATUS(stat_val) ((stat_val).w_T.w_Retcode)
#  else
#   define WEXITSTATUS(stat_val) (((stat_val) >> 8) & 0377)
#  endif
# endif

# ifndef WIFEXITED
#  ifdef HAVE_UNION_WAIT
#   define WIFEXITED(stat_val) ((stat_val).w_T.w_Termsig == 0)
#  else
#   define WIFEXITED(stat_val) (((stat_val) & 255) == 0)
#  endif
# endif

#ifdef HAVE_STROPTS_H
#ifdef sinix
#define buf_T __system_buf_t__
#endif
# include <stropts.h>
#ifdef sinix
#undef buf_T
#endif
#endif

#ifdef HAVE_STRING_H
# include <string.h>
#endif

#ifdef HAVE_SYS_STREAM_H
# include <sys/stream.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
# include <sys/utsname.h>
#endif

#ifdef HAVE_SYS_SYSTEMINFO_H
/*
 * foolish Sinix <sys/systeminfo.h> uses SYS_NMLN but doesn't include
 * <limits.h>, where it is defined. Perhaps other systems have the same
 * problem? Include it here. -- Slootman
 */
# if defined(HAVE_LIMITS_H) && !defined(_LIMITS_H)
#  include <limits.h>           /* for SYS_NMLN (Sinix 5.41 / Unix SysV.4) */
# endif

/* Define SYS_NMLN ourselves if it still isn't defined (for CrayT3E). */
# ifndef SYS_NMLN
#  define SYS_NMLN 32
# endif

# include <sys/systeminfo.h>    /* for sysinfo */
#endif

/*
 * We use termios.h if both termios.h and termio.h are available.
 * Termios is supposed to be a superset of termio.h.  Don't include them both,
 * it may give problems on some systems (e.g. hpux).
 * I don't understand why we don't want termios.h for apollo.
 */
#if defined(HAVE_TERMIOS_H) && !defined(apollo)
#  include <termios.h>
#else
# ifdef HAVE_TERMIO_H
#  include <termio.h>
# else
#  ifdef HAVE_SGTTY_H
#   include <sgtty.h>
#  endif
# endif
#endif

#ifdef HAVE_SYS_PTEM_H
# include <sys/ptem.h>  /* must be after termios.h for Sinix */
# ifndef _IO_PTEM_H     /* For UnixWare that should check for _IO_PT_PTEM_H */
#  define _IO_PTEM_H
# endif
#endif

/* shared library access */
#if defined(HAVE_DLFCN_H) && defined(USE_DLOPEN)
# ifdef __MVS__
/* needed to define RTLD_LAZY (Anthony Giorgio) */
#  define __SUSV3
# endif
# include <dlfcn.h>
#else
#endif
