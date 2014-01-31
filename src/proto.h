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

# if defined(UNIX) || defined(__EMX__) || defined(VMS)
#  include "os_unix.pro"
# endif

#  include "blowfish.pro"
# include "buffer.pro"
# include "charset.pro"
#  include "if_cscope.pro"
# include "diff.pro"
# include "digraph.pro"
# include "edit.pro"
# include "eval.pro"
# include "ex_cmds.pro"
# include "ex_cmds2.pro"
# include "ex_docmd.pro"
# include "ex_eval.pro"
# include "ex_getln.pro"
# include "fileio.pro"
# include "fold.pro"
# include "getchar.pro"
#  include "hangulin.pro"
# include "hardcopy.pro"
# include "hashtab.pro"
# include "main.pro"
# include "mark.pro"
# include "memfile.pro"
# include "memline.pro"
#  include "menu.pro"

# if !defined MESSAGE_FILE || defined(HAVE_STDARG_H)
/* These prototypes cannot be produced automatically and conflict with
 * the old-style prototypes in message.c. */
int
smsg __ARGS((char_u *, ...));

int
smsg_attr __ARGS((int, char_u *, ...));

int
vim_snprintf_add __ARGS((char *, size_t, char *, ...));

int
vim_snprintf __ARGS((char *, size_t, char *, ...));

#  if defined(HAVE_STDARG_H)
int vim_vsnprintf(char *str, size_t str_m, char *fmt, va_list ap, typval_T *tvs);
#  endif
# endif

# include "message.pro"
# include "misc1.pro"
# include "misc2.pro"
#ifndef HAVE_STRPBRK        /* not generated automatically from misc2.c */
char_u *vim_strpbrk __ARGS((char_u *s, char_u *charset));
#endif
#ifndef HAVE_QSORT
/* Use our own qsort(), don't define the prototype when not used. */
void qsort __ARGS((void *base, size_t elm_count, size_t elm_size, int (*cmp)(
                       const void *, const void *)));
#endif
# include "move.pro"
# if defined(FEAT_MBYTE) || defined(FEAT_XIM) || defined(FEAT_KEYMAP) \
  || defined(FEAT_POSTSCRIPT)
#  include "mbyte.pro"
# endif
# include "normal.pro"
# include "ops.pro"
# include "option.pro"
# include "popupmnu.pro"
#  include "quickfix.pro"
# include "regexp.pro"
# include "screen.pro"
#  include "sha256.pro"
# include "search.pro"
# include "spell.pro"
# include "syntax.pro"
# include "tag.pro"
# include "term.pro"
# include "ui.pro"
# include "undo.pro"
# include "version.pro"
# include "window.pro"







/* Ugly solution for "BalloonEval" not being defined while it's used in some
 * .pro files. */
#  define BalloonEval int



# ifdef FEAT_OLE
# endif

/*
 * The perl include files pollute the namespace, therefore proto.h must be
 * included before the perl include files.  But then CV is not defined, which
 * not included here for the perl files.  Use a dummy define for CV for the
 * other files.
 */

#ifdef MACOS_CONVERT
#endif

#endif /* !PROTO && !NOPROTO */
