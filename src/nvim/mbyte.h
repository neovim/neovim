#ifndef NVIM_MBYTE_H
#define NVIM_MBYTE_H

#include <stdbool.h>

/*
 * Return byte length of character that starts with byte "b".
 * Returns 1 for a single-byte character.
 * MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
 * Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
 */
#define MB_BYTE2LEN(b)         utf8len_tab[b]
#define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : utf8len_tab[b])

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
#define mb_ptr2len_len utfc_ptr2len_len
#define mb_char2len utf_char2len
#define mb_char2bytes utf_char2bytes
#define mb_ptr2cells utf_ptr2cells
#define mb_ptr2cells_len utf_ptr2cells_len
#define mb_char2cells utf_char2cells
#define mb_off2cells utf_off2cells
#define mb_ptr2char utf_ptr2char
#define mb_head_off utf_head_off

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif
#endif  // NVIM_MBYTE_H
