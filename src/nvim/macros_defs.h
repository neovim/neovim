#pragma once

#ifndef NVIM_NLUA0
# include "auto/config.h"
#endif

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

#define WRITEBIN   "wb"        // no CR-LF translation
#define READBIN    "rb"
#define APPENDBIN  "ab"

#define REPLACE_NORMAL(s) (((s)& REPLACE_FLAG) && !((s)& VREPLACE_FLAG))

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

#if defined(__clang__) || defined(__GNUC__)
# define EXPECT(cond, value) __builtin_expect((cond), (value))
# define UNREACHABLE __builtin_unreachable()
#elif defined(_MSC_VER)
# define EXPECT(cond, value) (cond)
# define UNREACHABLE __assume(false)
#else
# define EXPECT(cond, value) (cond)
# define UNREACHABLE
#endif

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
