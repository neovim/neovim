#ifndef NEOVIM_PROTO_H
#define NEOVIM_PROTO_H

/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * proto.h: include the (automatically generated) function prototypes
 */

/*
 * Don't include these while generating prototypes.  Prevents problems when
 * files are missing.
 */
#if !defined(PROTO) && !defined(NOPROTO)

/*
 * Machine-dependent routines.
 */
/* avoid errors in function prototypes */
#  define Display int
#  define Widget int
#  define GdkEvent int
#  define GdkEventKey int
#  define XImage int

/* These prototypes cannot be produced automatically and conflict with
 * the old-style prototypes in message.c. */
int
smsg(char_u *, ...);

int
smsg_attr(int, char_u *, ...);

int
vim_snprintf_add(char *, size_t, char *, ...);

int
vim_snprintf(char *, size_t, char *, ...);

int vim_vsnprintf(char *str, size_t str_m, char *fmt, va_list ap, typval_T *tvs);

#endif /* !PROTO && !NOPROTO */

#endif  // NEOVIM_PROTO_H
