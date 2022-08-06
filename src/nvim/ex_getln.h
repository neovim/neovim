#ifndef NVIM_EX_GETLN_H
#define NVIM_EX_GETLN_H

#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/regexp_defs.h"

// Values for nextwild() and ExpandOne().  See ExpandOne() for meaning.
#define WILD_FREE               1
#define WILD_EXPAND_FREE        2
#define WILD_EXPAND_KEEP        3
#define WILD_NEXT               4
#define WILD_PREV               5
#define WILD_ALL                6
#define WILD_LONGEST            7
#define WILD_ALL_KEEP           8
#define WILD_CANCEL             9
#define WILD_APPLY              10

#define WILD_LIST_NOTFOUND      0x01
#define WILD_HOME_REPLACE       0x02
#define WILD_USE_NL             0x04
#define WILD_NO_BEEP            0x08
#define WILD_ADD_SLASH          0x10
#define WILD_KEEP_ALL           0x20
#define WILD_SILENT             0x40
#define WILD_ESCAPE             0x80
#define WILD_ICASE              0x100
#define WILD_ALLLINKS           0x200
#define WILD_IGNORE_COMPLETESLASH   0x400
#define WILD_NOERROR            0x800  // sets EW_NOERROR
#define WILD_BUFLASTUSED        0x1000
#define BUF_DIFF_FILTER         0x2000

// flags used by vim_strsave_fnameescape()
#define VSE_NONE        0
#define VSE_SHELL       1       ///< escape for a shell command
#define VSE_BUFFER      2       ///< escape for a ":buffer" command

typedef char *(*CompleteListItemGetter)(expand_T *, int);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.h.generated.h"
#endif
#endif  // NVIM_EX_GETLN_H
