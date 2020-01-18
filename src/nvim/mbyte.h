#ifndef NVIM_MBYTE_H
#define NVIM_MBYTE_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/iconv.h"
#include "nvim/func_attr.h"
#include "nvim/os/os_defs.h"  // For indirect
#include "nvim/types.h"  // for char_u

/*
 * Return byte length of character that starts with byte "b".
 * Returns 1 for a single-byte character.
 * MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
 * Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
 */
#define MB_BYTE2LEN(b)         utf8len_tab[b]
#define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : utf8len_tab[b])

// max length of an unicode char
#define MB_MAXCHAR     6

/* properties used in enc_canon_table[] (first three mutually exclusive) */
#define ENC_8BIT       0x01
#define ENC_DBCS       0x02
#define ENC_UNICODE    0x04

#define ENC_ENDIAN_B   0x10        /* Unicode: Big endian */
#define ENC_ENDIAN_L   0x20        /* Unicode: Little endian */

#define ENC_2BYTE      0x40        /* Unicode: UCS-2 */
#define ENC_4BYTE      0x80        /* Unicode: UCS-4 */
#define ENC_2WORD      0x100       /* Unicode: UTF-16 */

#define ENC_LATIN1     0x200       /* Latin1 */
#define ENC_LATIN9     0x400       /* Latin9 */
#define ENC_MACROMAN   0x800       /* Mac Roman (not Macro Man! :-) */

// TODO(bfredl): eventually we should keep only one of the namings
#define mb_ptr2len utfc_ptr2len
#define mb_char2len utf_char2len
#define mb_char2cells utf_char2cells

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
  int vc_type;  ///< Zero or more ConvFlags.
  int vc_factor;  ///< Maximal expansion factor.
# ifdef HAVE_ICONV
  iconv_t vc_fd;  ///< Value for CONV_ICONV.
# endif
  bool vc_fail;  ///< What to do with invalid characters: if true, fail,
                 ///< otherwise use '?'.
} vimconv_T;

extern const uint8_t utf8len_tab_zero[256];

extern const uint8_t utf8len_tab[256];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif

static inline int mb_strcmp_ic(bool ic, const char *s1, const char *s2)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Compare strings
///
/// @param[in]  ic  True if case is to be ignored.
///
/// @return 0 if s1 == s2, <0 if s1 < s2, >0 if s1 > s2.
static inline int mb_strcmp_ic(bool ic, const char *s1, const char *s2)
{
  return (ic ? mb_stricmp(s1, s2) : strcmp(s1, s2));
}
#endif  // NVIM_MBYTE_H
