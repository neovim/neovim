#pragma once

#include <stdbool.h>

#include "nvim/os/os_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ascii_defs.h.inline.generated.h"
#endif

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

#define Ctrl_AT         0   // @
#define Ctrl_A          1
#define Ctrl_B          2
#define Ctrl_C          3
#define Ctrl_D          4
#define Ctrl_E          5
#define Ctrl_F          6
#define Ctrl_G          7
#define Ctrl_H          8
#define Ctrl_I          9
#define Ctrl_J          10
#define Ctrl_K          11
#define Ctrl_L          12
#define Ctrl_M          13
#define Ctrl_N          14
#define Ctrl_O          15
#define Ctrl_P          16
#define Ctrl_Q          17
#define Ctrl_R          18
#define Ctrl_S          19
#define Ctrl_T          20
#define Ctrl_U          21
#define Ctrl_V          22
#define Ctrl_W          23
#define Ctrl_X          24
#define Ctrl_Y          25
#define Ctrl_Z          26
// CTRL- [ Left Square Bracket == ESC
#define Ctrl_BSL        28  // \ BackSLash
#define Ctrl_RSB        29  // ] Right Square Bracket
#define Ctrl_HAT        30  // ^
#define Ctrl__          31

// Character that separates dir names in a path.
#ifdef BACKSLASH_IN_FILENAME
# define PATHSEP        psepc
# define PATHSEPSTR     pseps
#else
# define PATHSEP        '/'
# define PATHSEPSTR     "/"
#endif

/// Checks if `c` is a space or tab character.
///
/// @see {ascii_isdigit}
static inline bool ascii_iswhite(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return c == ' ' || c == '\t';
}

/// Checks if `c` is a space or tab character or NUL.
///
/// @see {ascii_isdigit}
static inline bool ascii_iswhite_or_nul(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return ascii_iswhite(c) || c == NUL;
}

/// Checks if `c` is a space or tab or newline character or NUL.
///
/// @see {ascii_isdigit}
static inline bool ascii_iswhite_nl_or_nul(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return ascii_iswhite(c) || c == '\n' || c == NUL;
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
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return c >= '0' && c <= '9';
}

/// Checks if `c` is a hexadecimal digit, that is, one of 0-9, a-f, A-F.
///
/// @see {ascii_isdigit}
static inline bool ascii_isxdigit(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return (c >= '0' && c <= '9')
         || (c >= 'a' && c <= 'f')
         || (c >= 'A' && c <= 'F');
}

/// Checks if `c` is an “identifier” character
///
/// That is, whether it is alphanumeric character or underscore.
static inline bool ascii_isident(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return ASCII_ISALNUM(c) || c == '_';
}

/// Checks if `c` is a binary digit, that is, 0-1.
///
/// @see {ascii_isdigit}
static inline bool ascii_isbdigit(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return (c == '0' || c == '1');
}

/// Checks if `c` is an octal digit, that is, 0-7.
///
/// @see {ascii_isdigit}
static inline bool ascii_isodigit(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return (c >= '0' && c <= '7');
}

/// Checks if `c` is a white-space character, that is,
/// one of \f, \n, \r, \t, \v.
///
/// @see {ascii_isdigit}
static inline bool ascii_isspace(int c)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  return (c >= 9 && c <= 13) || c == ' ';
}
