#ifndef NVIM_CHARSET_H
#define NVIM_CHARSET_H

/*
 * Flags for chartab[].
 */
#define CT_CELL_MASK    0x07    /* mask: nr of display cells (1, 2 or 4) */
#define CT_PRINT_CHAR   0x10    /* flag: set for printable chars */
#define CT_ID_CHAR      0x20    /* flag: set for ID chars */
#define CT_FNAME_CHAR   0x40    /* flag: set for file name chars */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "charset.h.generated.h"
#endif
#endif  // NVIM_CHARSET_H
