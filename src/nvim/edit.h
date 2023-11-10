#pragma once

#include "nvim/autocmd.h"
#include "nvim/vim.h"

// Values for in_cinkeys()
#define KEY_OPEN_FORW   0x101
#define KEY_OPEN_BACK   0x102
#define KEY_COMPLETE    0x103   // end of completion

// Values for change_indent()
#define INDENT_SET      1       // set indent
#define INDENT_INC      2       // increase indent
#define INDENT_DEC      3       // decrease indent

// flags for beginline()
#define BL_WHITE        1       // cursor on first non-white in the line
#define BL_SOL          2       // use 'sol' option
#define BL_FIX          4       // don't leave cursor on a NUL

// flags for insertchar()
#define INSCHAR_FORMAT  1       // force formatting
#define INSCHAR_DO_COM  2       // format comments
#define INSCHAR_CTRLV   4       // char typed just after CTRL-V
#define INSCHAR_NO_FEX  8       // don't use 'formatexpr'
#define INSCHAR_COM_LIST 16     // format comments with list/2nd line indent

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "edit.h.generated.h"
#endif
