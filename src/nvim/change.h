#pragma once

#include "nvim/buffer_defs.h"
#include "nvim/pos.h"

// flags for open_line()
#define OPENLINE_DELSPACES  0x01  // delete spaces after cursor
#define OPENLINE_DO_COM     0x02  // format comments
#define OPENLINE_KEEPTRAIL  0x04  // keep trailing spaces
#define OPENLINE_MARKFIX    0x08  // fix mark positions
#define OPENLINE_COM_LIST   0x10  // format comments with list/2nd line indent
#define OPENLINE_FORMAT     0x20  // formatting long comment

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "change.h.generated.h"
#endif
