#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <utf8proc.h>

#include "nvim/iconv_defs.h"

enum {
  /// Maximum number of bytes in a multi-byte character.  It can be one 32-bit
  /// character of up to 6 bytes, or one 16-bit character of up to three bytes
  /// plus six following composing characters of three bytes each.
  MB_MAXBYTES = 21,
  /// Maximum length of a Unicode character, excluding composing characters.
  MB_MAXCHAR = 6,
};

/// properties used in enc_canon_table[] (first three mutually exclusive)
enum {
  ENC_8BIT     = 0x01,
  ENC_DBCS     = 0x02,
  ENC_UNICODE  = 0x04,

  ENC_ENDIAN_B = 0x10,       ///< Unicode: Big endian
  ENC_ENDIAN_L = 0x20,       ///< Unicode: Little endian

  ENC_2BYTE    = 0x40,       ///< Unicode: UCS-2
  ENC_4BYTE    = 0x80,       ///< Unicode: UCS-4
  ENC_2WORD    = 0x100,      ///< Unicode: UTF-16

  ENC_LATIN1   = 0x200,      ///< Latin1
  ENC_LATIN9   = 0x400,      ///< Latin9
  ENC_MACROMAN = 0x800,      ///< Mac Roman (not Macro Man! :-)
};

/// Flags for vimconv_T
typedef enum {
  CONV_NONE      = 0,
  CONV_TO_UTF8   = 1,
  CONV_9_TO_UTF8 = 2,
  CONV_TO_LATIN1 = 3,
  CONV_TO_LATIN9 = 4,
  CONV_ICONV     = 5,
} ConvFlags;

#define MBYTE_NONE_CONV { \
  .vc_type = CONV_NONE, \
  .vc_factor = 1, \
  .vc_fail = false, \
}

/// Structure used for string conversions
typedef struct {
  int vc_type;    ///< Zero or more ConvFlags.
  int vc_factor;  ///< Maximal expansion factor.
  iconv_t vc_fd;  ///< Value for CONV_ICONV.
  bool vc_fail;   ///< What to do with invalid characters: if true, fail,
                  ///< otherwise use '?'.
} vimconv_T;

typedef struct {
  int32_t value;  ///< Code point.
  int len;        ///< Length in bytes.
} CharInfo;

typedef struct {
  char *ptr;     ///< Pointer to the first byte of the character.
  CharInfo chr;  ///< Information about the character.
} StrCharInfo;

typedef struct {
  int8_t begin_off;  ///< Offset to the first byte of the codepoint.
  int8_t end_off;    ///< Offset to one past the end byte of the codepoint.
} CharBoundsOff;

typedef utf8proc_int32_t GraphemeState;

enum { UNICODE_INVALID = 0xFFFD, };
