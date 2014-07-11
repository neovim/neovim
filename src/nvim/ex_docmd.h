#ifndef NVIM_EX_DOCMD_H
#define NVIM_EX_DOCMD_H

/* flags for do_cmdline() */
#define DOCMD_VERBOSE   0x01    /* included command in error message */
#define DOCMD_NOWAIT    0x02    /* don't call wait_return() and friends */
#define DOCMD_REPEAT    0x04    /* repeat exec. until getline() returns NULL */
#define DOCMD_KEYTYPED  0x08    /* don't reset KeyTyped */
#define DOCMD_EXCRESET  0x10    /* reset exception environment (for debugging)*/
#define DOCMD_KEEPLINE  0x20    /* keep typed line for repeating with "." */

/* defines for eval_vars() */
#define VALID_PATH              1
#define VALID_HEAD              2

/* Values for exmode_active (0 is no exmode) */
#define EXMODE_NORMAL           1
#define EXMODE_VIM              2

typedef char_u *(*LineGetter)(int, void *, int);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_docmd.h.generated.h"
#endif
#endif  // NVIM_EX_DOCMD_H
