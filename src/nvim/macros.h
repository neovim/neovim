#ifndef NVIM_MACROS_H
#define NVIM_MACROS_H

// EXTERN is only defined in main.c. That's where global variables are
// actually defined and initialized.
#ifndef EXTERN
# define EXTERN extern
# define INIT(...)
#else
# ifndef INIT
#  define INIT(...) __VA_ARGS__
# endif
#endif

#ifndef MIN
# define MIN(X, Y) ((X) < (Y) ? (X) : (Y))
#endif
#ifndef MAX
# define MAX(X, Y) ((X) > (Y) ? (X) : (Y))
#endif

/// String with length
///
/// For use in functions which accept (char *s, size_t len) pair in arguments.
///
/// @param[in]  s  Static string.
///
/// @return `s, sizeof(s) - 1`
#define S_LEN(s) (s), (sizeof(s) - 1)

/// LINEEMPTY() - return TRUE if the line is empty
#define LINEEMPTY(p) (*ml_get(p) == NUL)

/// BUFEMPTY() - return TRUE if the current buffer is empty
#define BUFEMPTY() (curbuf->b_ml.ml_line_count == 1 && *ml_get((linenr_T)1) == \
                    NUL)

/*
 * toupper() and tolower() that use the current locale.
 * Careful: Only call TOUPPER_LOC() and TOLOWER_LOC() with a character in the
 * range 0 - 255.  toupper()/tolower() on some systems can't handle others.
 * Note: It is often better to use mb_tolower() and mb_toupper(), because many
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
        && (p_lrm || (vgetc_busy ? typebuf_maplen() == 0 : KeyTyped)) \
        && !KeyStuffed \
        && (c) >= 0) \
    { \
      if ((c) < 256) \
        c = langmap_mapchar[c]; \
      else \
        c = langmap_adjust_mb(c); \
    } \
  } while (0)

#define WRITEBIN   "wb"        /* no CR-LF translation */
#define READBIN    "rb"
#define APPENDBIN  "ab"

#  define mch_fopen(n, p)       fopen((n), (p))

/* mch_open_rw(): invoke os_open() with third argument for user R/W. */
#if defined(UNIX)  /* open in rw------- mode */
# define mch_open_rw(n, f)      os_open((n), (f), (mode_t)0600)
#elif defined(WIN32)
# define mch_open_rw(n, f)      os_open((n), (f), S_IREAD | S_IWRITE)
#else
# define mch_open_rw(n, f)      os_open((n), (f), 0)
#endif

# define REPLACE_NORMAL(s) (((s) & REPLACE_FLAG) && !((s) & VREPLACE_FLAG))

# define UTF_COMPOSINGLIKE(p1, p2)  utf_composinglike((p1), (p2))

/* Whether to draw the vertical bar on the right side of the cell. */
# define CURSOR_BAR_RIGHT (curwin->w_p_rl && (!(State & CMDLINE) || cmdmsg_rl))

// MB_PTR_ADV(): advance a pointer to the next character, taking care of
// multi-byte characters if needed.
// MB_PTR_BACK(): backup a pointer to the previous character, taking care of
// multi-byte characters if needed.
// MB_COPY_CHAR(f, t): copy one char from "f" to "t" and advance the pointers.
// PTR2CHAR(): get character from pointer.

// Get the length of the character p points to
# define MB_PTR2LEN(p)          mb_ptr2len(p)
// Advance multi-byte pointer, skip over composing chars.
# define MB_PTR_ADV(p)      (p += mb_ptr2len((char_u *)p))
// Advance multi-byte pointer, do not skip over composing chars.
# define MB_CPTR_ADV(p)     (p += utf_ptr2len(p))
// Backup multi-byte pointer. Only use with "p" > "s" !
# define MB_PTR_BACK(s, p)  (p -= mb_head_off((char_u *)s, (char_u *)p - 1) + 1)
// get length of multi-byte char, not including composing chars
# define MB_CPTR2LEN(p)     utf_ptr2len(p)

# define MB_COPY_CHAR(f, t) mb_copy_char((const char_u **)(&f), &t);

# define MB_CHARLEN(p)      mb_charlen(p)
# define MB_CHAR2LEN(c)     mb_char2len(c)
# define PTR2CHAR(p)        utf_ptr2char(p)

# define RESET_BINDING(wp)  (wp)->w_p_scb = FALSE; (wp)->w_p_crb = FALSE

/// Calculate the length of a C array
///
/// This should be called with a real array. Calling this with a pointer is an
/// error. A mechanism to detect many (though not all) of those errors at
/// compile time is implemented. It works by the second division producing
/// a division by zero in those cases (-Wdiv-by-zero in GCC).
#define ARRAY_SIZE(arr) \
    ((sizeof(arr)/sizeof((arr)[0])) \
     / ((size_t)(!(sizeof(arr) % sizeof((arr)[0])))))

/// Get last array entry
///
/// This should be called with a real array. Calling this with a pointer is an
/// error.
#define ARRAY_LAST_ENTRY(arr) (arr)[ARRAY_SIZE(arr) - 1]

// Duplicated in os/win_defs.h to avoid include-order sensitivity.
#define RGB_(r, g, b) ((r << 16) | (g << 8) | b)

#define STR_(x) #x
#define STR(x) STR_(x)

#ifndef __has_attribute
# define NVIM_HAS_ATTRIBUTE(x) 0
#elif defined(__clang__) && __clang__ == 1 \
    && (__clang_major__ < 3 || (__clang_major__ == 3 && __clang_minor__ <= 5))
// Starting in Clang 3.6, __has_attribute was fixed to only report true for
// GNU-style attributes.  Prior to that, it reported true if _any_ backend
// supported the attribute.
# define NVIM_HAS_ATTRIBUTE(x) 0
#else
# define NVIM_HAS_ATTRIBUTE __has_attribute
#endif

#if NVIM_HAS_ATTRIBUTE(fallthrough)
# define FALLTHROUGH __attribute__((fallthrough))
#else
# define FALLTHROUGH
#endif

// -V:STRUCT_CAST:641

/// Change type of structure pointers: cast `struct a *` to `struct b *`
///
/// Used to silence PVS errors.
///
/// @param  Type  Structure to cast to.
/// @param  obj  Object to cast.
///
/// @return ((Type *)obj).
#define STRUCT_CAST(Type, obj) ((Type *)(obj))

// Type of uv_buf_t.len is platform-dependent.
// Related: https://github.com/libuv/libuv/pull/1236
#if defined(WIN32)
# define UV_BUF_LEN(x)  (ULONG)(x)
#else
# define UV_BUF_LEN(x)  (x)
#endif

// Type of read()/write() `count` param is platform-dependent.
#if defined(WIN32)
# define IO_COUNT(x)  (unsigned)(x)
#else
# define IO_COUNT(x)  (x)
#endif

#endif  // NVIM_MACROS_H
