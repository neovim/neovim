#ifndef NVIM_MBYTE_H
#define NVIM_MBYTE_H

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif
#endif  // NVIM_MBYTE_H
