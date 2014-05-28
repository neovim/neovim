#ifndef NVIM_SYNTAX_H
#define NVIM_SYNTAX_H

#include "nvim/buffer_defs.h"

typedef int guicolor_T;

/*
 * Terminal highlighting attribute bits.
 * Attributes above HL_ALL are used for syntax highlighting.
 */
#define HL_NORMAL               0x00
#define HL_INVERSE              0x01
#define HL_BOLD                 0x02
#define HL_ITALIC               0x04
#define HL_UNDERLINE            0x08
#define HL_UNDERCURL            0x10
#define HL_STANDOUT             0x20
#define HL_ALL                  0x3f

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "syntax.h.generated.h"
#endif

#endif  // NVIM_SYNTAX_H
