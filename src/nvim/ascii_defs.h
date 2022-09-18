#ifndef NVIM_ASCII_DEFS_H
#define NVIM_ASCII_DEFS_H

#include <stdbool.h>

#include "nvim/func_attr.h"
#include "nvim/macros.h"
#include "nvim/os/os_defs.h"

// Definitions of various common control characters.

#define CHAR_ORD(x)      ((uint8_t)(x) < 'a' \
                          ? (uint8_t)(x) - 'A' \
                          : (uint8_t)(x) - 'a')
#define CHAR_ORD_LOW(x)   ((uint8_t)(x) - 'a')
#define CHAR_ORD_UP(x)    ((uint8_t)(x) - 'A')
#define ROT13(c, a)     (((((c) - (a)) + 13) % 26) + (a))

#define NUL             '\000'
#define BELL            '\007'
#define BS              '\010'
#define TAB             '\011'
#define NL              '\012'
#define NL_STR          "\012"
#define FF              '\014'
#define CAR             '\015'  // CR is used by Mac OS X
#define ESC             '\033'
#define ESC_STR         "\033"
#define DEL             0x7f
#define DEL_STR         "\177"
#define CSI             0x9b    // Control Sequence Introducer
#define CSI_STR         "\233"
#define DCS             0x90    // Device Control String
#define STERM           0x9c    // String Terminator

#define POUND           0xA3

#define CTRL_CHR(x)     (TOUPPER_ASC(x) ^ 0x40)  // '?' -> DEL, '@' -> ^@, etc.
#define META(x)         ((x) | 0x80)

#define CTRL_F_STR      "\006"
#define CTRL_H_STR      "\010"
#define CTRL_V_STR      "\026"

enum {
  Ctrl_AT = 0,  // @
  Ctrl_A = 1,
  Ctrl_B = 2,
  Ctrl_C = 3,
  Ctrl_D = 4,
  Ctrl_E = 5,
  Ctrl_F = 6,
  Ctrl_G = 7,
  Ctrl_H = 8,
  Ctrl_I = 9,
  Ctrl_J = 10,
  Ctrl_K = 11,
  Ctrl_L = 12,
  Ctrl_M = 13,
  Ctrl_N = 14,
  Ctrl_O = 15,
  Ctrl_P = 16,
  Ctrl_Q = 17,
  Ctrl_R = 18,
  Ctrl_S = 19,
  Ctrl_T = 20,
  Ctrl_U = 21,
  Ctrl_V = 22,
  Ctrl_W = 23,
  Ctrl_X = 24,
  Ctrl_Y = 25,
  Ctrl_Z = 26,
  // CTRL- [ Left Square Bracket == ESC
  Ctrl_BSL = 28,  // \ BackSLash
  Ctrl_RSB = 29,  // ] Right Square Bracket
  Ctrl_HAT = 30,  // ^
  Ctrl__ = 31,
};

// Character that separates dir names in a path.
#ifdef BACKSLASH_IN_FILENAME
# define PATHSEP        psepc
# define PATHSEPSTR     pseps
#else
# define PATHSEP        '/'
# define PATHSEPSTR     "/"
#endif

static inline bool ascii_iswhite(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_iswhite_or_nul(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_isdigit(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_isxdigit(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_isident(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_isbdigit(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

static inline bool ascii_isspace(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

/// Checks if `c` is a space or tab character.
///
/// @see {ascii_isdigit}
static inline bool ascii_iswhite(int c)
{
  return c == ' ' || c == '\t';
}

/// Checks if `c` is a space or tab character or NUL.
///
/// @see {ascii_isdigit}
static inline bool ascii_iswhite_or_nul(int c)
{
  return ascii_iswhite(c) || c == NUL;
}

/// Check whether character is a decimal digit.
///
/// Library isdigit() function is officially locale-dependent and, for
/// example, returns true for superscript 1 (¹) in locales where encoding
/// contains it in lower 8 bits. Also avoids crashes in case c is below
/// 0 or above 255: library functions are officially defined as accepting
/// only EOF and unsigned char values (otherwise it is undefined behaviour)
/// what may be used for some optimizations (e.g. simple `return
/// isdigit_table[c];`).
static inline bool ascii_isdigit(int c)
{
  return c >= '0' && c <= '9';
}

/// Checks if `c` is a hexadecimal digit, that is, one of 0-9, a-f, A-F.
///
/// @see {ascii_isdigit}
static inline bool ascii_isxdigit(int c)
{
  return (c >= '0' && c <= '9')
         || (c >= 'a' && c <= 'f')
         || (c >= 'A' && c <= 'F');
}

/// Checks if `c` is an “identifier” character
///
/// That is, whether it is alphanumeric character or underscore.
static inline bool ascii_isident(int c)
{
  return ASCII_ISALNUM(c) || c == '_';
}

/// Checks if `c` is a binary digit, that is, 0-1.
///
/// @see {ascii_isdigit}
static inline bool ascii_isbdigit(int c)
{
  return (c == '0' || c == '1');
}

/// Checks if `c` is an octal digit, that is, 0-7.
///
/// @see {ascii_isdigit}
static inline bool ascii_isodigit(int c)
{
  return (c >= '0' && c <= '7');
}

/// Checks if `c` is a white-space character, that is,
/// one of \f, \n, \r, \t, \v.
///
/// @see {ascii_isdigit}
static inline bool ascii_isspace(int c)
{
  return (c >= 9 && c <= 13) || c == ' ';
}

#endif  // NVIM_ASCII_DEFS_H
