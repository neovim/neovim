#ifndef NVIM_MBYTE_DEFS_H
#define NVIM_MBYTE_DEFS_H

#include <stdbool.h>

#include "nvim/iconv.h"

/// max length of an unicode char
enum { MB_MAXCHAR = 6, };

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

#endif  // NVIM_MBYTE_DEFS_H
