/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * macros.h: macro definitions for often used code
 */

/*
 * Position comparisons
 */
# define lt(a, b) (((a).lnum != (b).lnum) \
                   ? (a).lnum < (b).lnum \
                   : (a).col != (b).col \
                   ? (a).col < (b).col \
                   : (a).coladd < (b).coladd)
# define ltp(a, b) (((a)->lnum != (b)->lnum) \
                    ? (a)->lnum < (b)->lnum \
                    : (a)->col != (b)->col \
                    ? (a)->col < (b)->col \
                    : (a)->coladd < (b)->coladd)
# define equalpos(a, b) (((a).lnum == (b).lnum) && ((a).col == (b).col) && \
                         ((a).coladd == (b).coladd))
# define clearpos(a) {(a)->lnum = 0; (a)->col = 0; (a)->coladd = 0; }

#define ltoreq(a, b) (lt(a, b) || equalpos(a, b))

/*
 * lineempty() - return TRUE if the line is empty
 */
#define lineempty(p) (*ml_get(p) == '\0')

/*
 * bufempty() - return TRUE if the current buffer is empty
 */
#define bufempty() (curbuf->b_ml.ml_line_count == 1 && *ml_get((linenr_T)1) == \
                    '\0')

/*
 * toupper() and tolower() that use the current locale.
 * Careful: Only call TOUPPER_LOC() and TOLOWER_LOC() with a character in the
 * range 0 - 255.  toupper()/tolower() on some systems can't handle others.
 * Note: It is often better to use vim_tolower() and vim_toupper(), because many
 * toupper() and tolower() implementations only work for ASCII.
 */
#define TOUPPER_LOC toupper
#define TOLOWER_LOC tolower

/* toupper() and tolower() for ASCII only and ignore the current locale. */
# define TOUPPER_ASC(c) (((c) < 'a' || (c) > 'z') ? (c) : (c) - ('a' - 'A'))
# define TOLOWER_ASC(c) (((c) < 'A' || (c) > 'Z') ? (c) : (c) + ('a' - 'A'))

/* Use our own isdigit() replacement, because on MS-Windows isdigit() returns
 * non-zero for superscript 1.  Also avoids that isdigit() crashes for numbers
 * below 0 and above 255.  */
#define VIM_ISDIGIT(c) ((unsigned)(c) - '0' < 10)

/* Like isalpha() but reject non-ASCII characters.  Can't be used with a
 * special key (negative value). */
# define ASCII_ISLOWER(c) ((unsigned)(c) - 'a' < 26)
# define ASCII_ISUPPER(c) ((unsigned)(c) - 'A' < 26)
# define ASCII_ISALPHA(c) (ASCII_ISUPPER(c) || ASCII_ISLOWER(c))
# define ASCII_ISALNUM(c) (ASCII_ISALPHA(c) || VIM_ISDIGIT(c))

/* macro version of chartab().
 * Only works with values 0-255!
 * Doesn't work for UTF-8 mode with chars >= 0x80. */
#define CHARSIZE(c)     (chartab[c] & CT_CELL_MASK)

/*
 * Adjust chars in a language according to 'langmap' option.
 * NOTE that there is no noticeable overhead if 'langmap' is not set.
 * When set the overhead for characters < 256 is small.
 * Don't apply 'langmap' if the character comes from the Stuff buffer.
 * The do-while is just to ignore a ';' after the macro.
 */
#  define LANGMAP_ADJUST(c, condition) \
  do { \
    if (*p_langmap && (condition) && !KeyStuffed && (c) >= 0) \
    { \
      if ((c) < 256) \
        c = langmap_mapchar[c]; \
      else \
        c = langmap_adjust_mb(c); \
    } \
  } while (0)

/*
 * vim_isbreak() is used very often if 'linebreak' is set, use a macro to make
 * it work fast.
 */
#define vim_isbreak(c) (breakat_flags[(char_u)(c)])

#  define mch_fopen(n, p)       fopen((n), (p))
# define mch_fstat(n, p)        fstat((n), (p))
#  ifdef STAT_IGNORES_SLASH
/* On Solaris stat() accepts "file/" as if it was "file".  Return -1 if
 * the name ends in "/" and it's not a directory. */
#   define mch_stat(n, p)       (illegal_slash(n) ? -1 : stat((n), (p)))
#  else
#   define mch_stat(n, p)       stat((n), (p))
#  endif

#ifdef HAVE_LSTAT
# define mch_lstat(n, p)        lstat((n), (p))
#else
# define mch_lstat(n, p)        mch_stat((n), (p))
#endif

#   define mch_open(n, m, p)    open((n), (m), (p))

/* mch_open_rw(): invoke mch_open() with third argument for user R/W. */
#if defined(UNIX)  /* open in rw------- mode */
# define mch_open_rw(n, f)      mch_open((n), (f), (mode_t)0600)
#else
#  define mch_open_rw(n, f)     mch_open((n), (f), 0)
#endif

#ifdef STARTUPTIME
# define TIME_MSG(s) { if (time_fd != NULL) time_msg(s, NULL); }
#else
# define TIME_MSG(s)
#endif

# define REPLACE_NORMAL(s) (((s) & REPLACE_FLAG) && !((s) & VREPLACE_FLAG))

# define UTF_COMPOSINGLIKE(p1, p2)  utf_composinglike((p1), (p2))

/* Whether to draw the vertical bar on the right side of the cell. */
# define CURSOR_BAR_RIGHT (curwin->w_p_rl && (!(State & CMDLINE) || cmdmsg_rl))

/*
 * mb_ptr_adv(): advance a pointer to the next character, taking care of
 * multi-byte characters if needed.
 * mb_ptr_back(): backup a pointer to the previous character, taking care of
 * multi-byte characters if needed.
 * MB_COPY_CHAR(f, t): copy one char from "f" to "t" and advance the pointers.
 * PTR2CHAR(): get character from pointer.
 */
/* Get the length of the character p points to */
# define MB_PTR2LEN(p)          (has_mbyte ? (*mb_ptr2len)(p) : 1)
/* Advance multi-byte pointer, skip over composing chars. */
# define mb_ptr_adv(p)      p += has_mbyte ? (*mb_ptr2len)(p) : 1
/* Advance multi-byte pointer, do not skip over composing chars. */
# define mb_cptr_adv(p)     p += \
  enc_utf8 ? utf_ptr2len(p) : has_mbyte ? (*mb_ptr2len)(p) : 1
/* Backup multi-byte pointer. */
# define mb_ptr_back(s, p)  p -= has_mbyte ? ((*mb_head_off)(s, p - 1) + 1) : 1
/* get length of multi-byte char, not including composing chars */
# define mb_cptr2len(p)     (enc_utf8 ? utf_ptr2len(p) : (*mb_ptr2len)(p))

# define MB_COPY_CHAR(f, \
                      t) if (has_mbyte) mb_copy_char(&f, &t); else *t++ = *f++
# define MB_CHARLEN(p)      (has_mbyte ? mb_charlen(p) : (int)STRLEN(p))
# define MB_CHAR2LEN(c)     (has_mbyte ? mb_char2len(c) : 1)
# define PTR2CHAR(p)        (has_mbyte ? mb_ptr2char(p) : (int)*(p))

# define RESET_BINDING(wp)  (wp)->w_p_scb = FALSE; (wp)->w_p_crb = FALSE
