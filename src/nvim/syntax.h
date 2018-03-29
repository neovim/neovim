#ifndef NVIM_SYNTAX_H
#define NVIM_SYNTAX_H

#include <stdbool.h>

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"

#define HL_CONTAINED   0x01    /* not used on toplevel */
#define HL_TRANSP      0x02    /* has no highlighting	*/
#define HL_ONELINE     0x04    /* match within one line only */
#define HL_HAS_EOL     0x08    /* end pattern that matches with $ */
#define HL_SYNC_HERE   0x10    /* sync point after this item (syncing only) */
#define HL_SYNC_THERE  0x20    /* sync point at current line (syncing only) */
#define HL_MATCH       0x40    /* use match ID instead of item ID */
#define HL_SKIPNL      0x80    /* nextgroup can skip newlines */
#define HL_SKIPWHITE   0x100   /* nextgroup can skip white space */
#define HL_SKIPEMPTY   0x200   /* nextgroup can skip empty lines */
#define HL_KEEPEND     0x400   /* end match always kept */
#define HL_EXCLUDENL   0x800   /* exclude NL from match */
#define HL_DISPLAY     0x1000  /* only used for displaying, not syncing */
#define HL_FOLD        0x2000  /* define fold */
#define HL_EXTEND      0x4000  /* ignore a keepend */
#define HL_MATCHCONT   0x8000  /* match continued from previous line */
#define HL_TRANS_CONT  0x10000 /* transparent item without contains arg */
#define HL_CONCEAL     0x20000 /* can be concealed */
#define HL_CONCEALENDS 0x40000 /* can be concealed */

typedef struct {
  char *name;
  RgbValue color;
} color_name_table_T;
extern color_name_table_T color_name_table[];

/// Array of highlight definitions, used for unit testing
extern const char *const highlight_init_cmdline[];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "syntax.h.generated.h"
#endif

#endif  // NVIM_SYNTAX_H
