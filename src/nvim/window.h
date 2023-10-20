#ifndef NVIM_WINDOW_H
#define NVIM_WINDOW_H

#include <stdbool.h>
#include <stddef.h>

#include "nvim/buffer_defs.h"
#include "nvim/macros.h"
#include "nvim/option_defs.h"

// Values for file_name_in_line()
#define FNAME_MESS      1       // give error message
#define FNAME_EXP       2       // expand to path
#define FNAME_HYP       4       // check for hypertext link
#define FNAME_INCL      8       // apply 'includeexpr'
#define FNAME_REL       16      // ".." and "./" are relative to the (current)
                                // file instead of the current directory
#define FNAME_UNESC     32      // remove backslashes used for escaping

// arguments for win_split()
#define WSP_ROOM        0x01    // require enough room
#define WSP_VERT        0x02    // split/equalize vertically
#define WSP_HOR         0x04    // equalize horizontally
#define WSP_TOP         0x08    // window at top-left of shell
#define WSP_BOT         0x10    // window at bottom-right of shell
#define WSP_HELP        0x20    // creating the help window
#define WSP_BELOW       0x40    // put new window below/right
#define WSP_ABOVE       0x80    // put new window above/left
#define WSP_NEWLOC      0x100   // don't copy location list

// Minimum screen size
#define MIN_COLUMNS     12      // minimal columns for screen
#define MIN_LINES       2       // minimal lines for screen

// Set to true if 'cmdheight' was explicitly set to 0.
EXTERN bool p_ch_was_zero INIT( = false);
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "window.h.generated.h"
#endif
#endif  // NVIM_WINDOW_H
