/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * os_unixx.h -- include files that are only used in os_unix.c
 */

#if defined(HAVE_SYS_IOCTL_H)
# include <sys/ioctl.h>
#endif

#ifdef HAVE_STROPTS_H
# include <stropts.h>
#endif

#if defined(HAVE_TERMIOS_H)
# include <termios.h>
#endif

/* shared library access */
#if defined(HAVE_DLFCN_H) && defined(USE_DLOPEN)
# include <dlfcn.h>
#endif

