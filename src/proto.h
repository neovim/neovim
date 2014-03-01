/* vi:set ts=8 sts=4 sw=4:
 *
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

# if !defined MESSAGE_FILE || defined(HAVE_STDARG_H)
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

#  if defined(HAVE_STDARG_H)
int vim_vsnprintf(char *str, size_t str_m, char *fmt, va_list ap, typval_T *tvs);
#  endif
# endif

#ifndef HAVE_STRPBRK        /* not generated automatically from misc2.c */
char_u *vim_strpbrk(char_u *s, char_u *charset);
#endif
#ifndef HAVE_QSORT
/* Use our own qsort(), don't define the prototype when not used. */
void qsort(void *base, size_t elm_count, size_t elm_size,
           int (*cmp)(const void *, const void *));
#endif

/* Ugly solution for "BalloonEval" not being defined while it's used in some
 * .pro files. */
#  define BalloonEval int

#endif /* !PROTO && !NOPROTO */
