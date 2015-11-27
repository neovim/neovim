#ifndef NVIM_MACROS_H
#define NVIM_MACROS_H

#ifndef MIN
# define MIN(X, Y) ((X) < (Y) ? (X) : (Y))
#endif
#ifndef MAX
# define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

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
#define lineempty(p) (*ml_get(p) == NUL)

/*
 * bufempty() - return TRUE if the current buffer is empty
 */
#define bufempty() (curbuf->b_ml.ml_line_count == 1 && *ml_get((linenr_T)1) == \
                    NUL)

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

/* Like isalpha() but reject non-ASCII characters.  Can't be used with a
 * special key (negative value). */
# define ASCII_ISLOWER(c) ((unsigned)(c) >= 'a' && (unsigned)(c) <= 'z')
# define ASCII_ISUPPER(c) ((unsigned)(c) >= 'A' && (unsigned)(c) <= 'Z')
# define ASCII_ISALPHA(c) (ASCII_ISUPPER(c) || ASCII_ISLOWER(c))
# define ASCII_ISALNUM(c) (ASCII_ISALPHA(c) || ascii_isdigit(c))

/* Returns empty string if it is NULL. */
#define EMPTY_IF_NULL(x) ((x) ? (x) : (char_u *)"")

/* macro version of chartab().
 * Only works with values 0-255!
 * Doesn't work for UTF-8 mode with chars >= 0x80. */
#define CHARSIZE(c)     (chartab[c] & CT_CELL_MASK)

/*
 * Adjust chars in a language according to 'langmap' option.
 * NOTE that there is no noticeable overhead if 'langmap' is not set.
 * When set the overhead for characters < 256 is small.
 * Don't apply 'langmap' if the character comes from the Stuff buffer or from a
 * mapping and the langnoremap option was set.
 * The do-while is just to ignore a ';' after the macro.
 */
#  define LANGMAP_ADJUST(c, condition) \
  do { \
    if (*p_langmap \
        && (condition) \
        && (!p_lnr || (p_lnr && typebuf_maplen() == 0)) \
        && !KeyStuffed \
        && (c) >= 0) \
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

#define WRITEBIN   "wb"        /* no CR-LF translation */
#define READBIN    "rb"
#define APPENDBIN  "ab"

#  define mch_fopen(n, p)       fopen((n), (p))

/* mch_open_rw(): invoke os_open() with third argument for user R/W. */
#if defined(UNIX)  /* open in rw------- mode */
# define mch_open_rw(n, f)      os_open((n), (f), (mode_t)0600)
#else
#  define mch_open_rw(n, f)     os_open((n), (f), 0)
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
# define mb_ptr_adv(p)      (p += has_mbyte ? (*mb_ptr2len)((char_u *)p) : 1)
/* Advance multi-byte pointer, do not skip over composing chars. */
# define mb_cptr_adv(p)     (p += \
  enc_utf8 ? utf_ptr2len(p) : has_mbyte ? (*mb_ptr2len)(p) : 1)
/* Backup multi-byte pointer. Only use with "p" > "s" ! */
# define mb_ptr_back(s, p)  (p -= has_mbyte ? ((*mb_head_off)((char_u *)s, (char_u *)p - 1) + 1) : 1)
/* get length of multi-byte char, not including composing chars */
# define mb_cptr2len(p)     (enc_utf8 ? utf_ptr2len(p) : (*mb_ptr2len)(p))

# define MB_COPY_CHAR(f, t) \
  if (has_mbyte) mb_copy_char((const char_u **)(&f), &t); \
  else *t++ = *f++
# define MB_CHARLEN(p)      (has_mbyte ? mb_charlen(p) : (int)STRLEN(p))
# define MB_CHAR2LEN(c)     (has_mbyte ? mb_char2len(c) : 1)
# define PTR2CHAR(p)        (has_mbyte ? mb_ptr2char(p) : (int)*(p))

# define RESET_BINDING(wp)  (wp)->w_p_scb = FALSE; (wp)->w_p_crb = FALSE

/// Calculate the length of a C array.
///
/// This should be called with a real array. Calling this with a pointer is an
/// error. A mechanism to detect many (though not all) of those errors at compile
/// time is implemented. It works by the second division producing a division by
/// zero in those cases (-Wdiv-by-zero in GCC).
#define ARRAY_SIZE(arr) ((sizeof(arr)/sizeof((arr)[0])) / ((size_t)(!(sizeof(arr) % sizeof((arr)[0])))))

#define RGB(r, g, b) ((r << 16) | (g << 8) | b)

#endif  // NVIM_MACROS_H
