#ifndef NVIM_MACROS_H
#define NVIM_MACROS_H

#include "auto/config.h"

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

/// LINEEMPTY() - return true if the line is empty
#define LINEEMPTY(p) (*ml_get(p) == NUL)

// toupper() and tolower() that use the current locale.
// Careful: Only call TOUPPER_LOC() and TOLOWER_LOC() with a character in the
// range 0 - 255.  toupper()/tolower() on some systems can't handle others.
// Note: It is often better to use mb_tolower() and mb_toupper(), because many
// toupper() and tolower() implementations only work for ASCII.
#define TOUPPER_LOC toupper
#define TOLOWER_LOC tolower

// toupper() and tolower() for ASCII only and ignore the current locale.
#define TOUPPER_ASC(c) (((c) < 'a' || (c) > 'z') ? (c) : (c) - ('a' - 'A'))
#define TOLOWER_ASC(c) (((c) < 'A' || (c) > 'Z') ? (c) : (c) + ('a' - 'A'))

// Like isalpha() but reject non-ASCII characters.  Can't be used with a
// special key (negative value).
#define ASCII_ISLOWER(c) ((unsigned)(c) >= 'a' && (unsigned)(c) <= 'z')
#define ASCII_ISUPPER(c) ((unsigned)(c) >= 'A' && (unsigned)(c) <= 'Z')
#define ASCII_ISALPHA(c) (ASCII_ISUPPER(c) || ASCII_ISLOWER(c))
#define ASCII_ISALNUM(c) (ASCII_ISALPHA(c) || ascii_isdigit(c))

// Returns empty string if it is NULL.
#define EMPTY_IF_NULL(x) ((x) ? (x) : "")

/// Adjust chars in a language according to 'langmap' option.
/// NOTE that there is no noticeable overhead if 'langmap' is not set.
/// When set the overhead for characters < 256 is small.
/// Don't apply 'langmap' if the character comes from the Stuff buffer or from a
/// mapping and the langnoremap option was set.
/// The do-while is just to ignore a ';' after the macro.
///
/// -V:LANGMAP_ADJUST:560
#define LANGMAP_ADJUST(c, condition) \
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

#define WRITEBIN   "wb"        // no CR-LF translation
#define READBIN    "rb"
#define APPENDBIN  "ab"

#define REPLACE_NORMAL(s) (((s)& REPLACE_FLAG) && !((s)& VREPLACE_FLAG))

// MB_PTR_ADV(): advance a pointer to the next character, taking care of
// multi-byte characters if needed. Skip over composing chars.
#define MB_PTR_ADV(p)      (p += utfc_ptr2len((char *)p))

// Advance multi-byte pointer, do not skip over composing chars.
#define MB_CPTR_ADV(p)     (p += utf_ptr2len((char *)p))

// MB_PTR_BACK(): backup a pointer to the previous character, taking care of
// multi-byte characters if needed. Only use with "p" > "s" !
#define MB_PTR_BACK(s, p) \
  (p -= utf_head_off((char *)(s), (char *)(p) - 1) + 1)

// MB_CHAR2BYTES(): convert character to bytes and advance pointer to bytes
#define MB_CHAR2BYTES(c, b) ((b) += utf_char2bytes((c), ((char *)b)))

#define RESET_BINDING(wp) \
  do { \
    (wp)->w_p_scb = false; \
    (wp)->w_p_crb = false; \
  } while (0)

/// Calculate the length of a C array
///
/// This should be called with a real array. Calling this with a pointer is an
/// error. A mechanism to detect many (though not all) of those errors at
/// compile time is implemented. It works by the second division producing
/// a division by zero in those cases (-Wdiv-by-zero in GCC).
///
/// -V:ARRAY_SIZE:1063
#define ARRAY_SIZE(arr) \
  ((sizeof(arr)/sizeof((arr)[0])) \
   / ((size_t)(!(sizeof(arr) % sizeof((arr)[0])))))

/// Get last array entry
///
/// This should be called with a real array. Calling this with a pointer is an
/// error.
#define ARRAY_LAST_ENTRY(arr) (arr)[ARRAY_SIZE(arr) - 1]

// Duplicated in os/win_defs.h to avoid include-order sensitivity.
#define RGB_(r, g, b) (((r) << 16) | ((g) << 8) | (b))

#define STR_(x) #x
#define STR(x) STR_(x)

#ifndef __has_include
# define NVIM_HAS_INCLUDE(x) 0
#else
# define NVIM_HAS_INCLUDE __has_include
#endif

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

#if NVIM_HAS_ATTRIBUTE(fallthrough) \
  && (!defined(__apple_build_version__) || __apple_build_version__ >= 7000000)
# define FALLTHROUGH {} __attribute__((fallthrough))
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
#if defined(MSWIN)
# define UV_BUF_LEN(x)  (ULONG)(x)
#else
# define UV_BUF_LEN(x)  (x)
#endif

// Type of read()/write() `count` param is platform-dependent.
#if defined(MSWIN)
# define IO_COUNT(x)  (unsigned)(x)
#else
# define IO_COUNT(x)  (x)
#endif

///
/// PRAGMA_DIAG_PUSH_IGNORE_MISSING_PROTOTYPES
///
#if defined(__clang__) && __clang__ == 1
# define PRAGMA_DIAG_PUSH_IGNORE_MISSING_PROTOTYPES \
  _Pragma("clang diagnostic push") \
  _Pragma("clang diagnostic ignored \"-Wmissing-prototypes\"")
# ifdef HAVE_WIMPLICIT_FALLTHROUGH_FLAG
#  define PRAGMA_DIAG_PUSH_IGNORE_IMPLICIT_FALLTHROUGH \
  _Pragma("clang diagnostic push") \
  _Pragma("clang diagnostic ignored \"-Wimplicit-fallthrough\"")
# else
#  define PRAGMA_DIAG_PUSH_IGNORE_IMPLICIT_FALLTHROUGH \
  _Pragma("clang diagnostic push")
# endif
# define PRAGMA_DIAG_POP \
  _Pragma("clang diagnostic pop")
#elif defined(__GNUC__)
# define PRAGMA_DIAG_PUSH_IGNORE_MISSING_PROTOTYPES \
  _Pragma("GCC diagnostic push") \
  _Pragma("GCC diagnostic ignored \"-Wmissing-prototypes\"")
# ifdef HAVE_WIMPLICIT_FALLTHROUGH_FLAG
#  define PRAGMA_DIAG_PUSH_IGNORE_IMPLICIT_FALLTHROUGH \
  _Pragma("GCC diagnostic push") \
  _Pragma("GCC diagnostic ignored \"-Wimplicit-fallthrough\"")
# else
#  define PRAGMA_DIAG_PUSH_IGNORE_IMPLICIT_FALLTHROUGH \
  _Pragma("GCC diagnostic push")
# endif
# define PRAGMA_DIAG_POP \
  _Pragma("GCC diagnostic pop")
#else
# define PRAGMA_DIAG_PUSH_IGNORE_MISSING_PROTOTYPES
# define PRAGMA_DIAG_PUSH_IGNORE_IMPLICIT_FALLTHROUGH
# define PRAGMA_DIAG_POP
#endif

#define EMPTY_POS(a) ((a).lnum == 0 && (a).col == 0 && (a).coladd == 0)

#endif  // NVIM_MACROS_H
