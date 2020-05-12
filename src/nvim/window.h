#ifndef NVIM_WINDOW_H
#define NVIM_WINDOW_H

#include <stdbool.h>

#include "nvim/buffer_defs.h"

/* Values for file_name_in_line() */
#define FNAME_MESS      1       /* give error message */
#define FNAME_EXP       2       /* expand to path */
#define FNAME_HYP       4       /* check for hypertext link */
#define FNAME_INCL      8       /* apply 'includeexpr' */
#define FNAME_REL       16      /* ".." and "./" are relative to the (current)
                                   file instead of the current directory */
#define FNAME_UNESC     32      // remove backslashes used for escaping

/*
 * arguments for win_split()
 */
#define WSP_ROOM        1       /* require enough room */
#define WSP_VERT        2       /* split vertically */
#define WSP_TOP         4       /* window at top-left of shell */
#define WSP_BOT         8       /* window at bottom-right of shell */
#define WSP_HELP        16      /* creating the help window */
#define WSP_BELOW       32      /* put new window below/right */
#define WSP_ABOVE       64      /* put new window above/left */
#define WSP_NEWLOC      128     /* don't copy location list */

/*
 * Minimum screen size
 */
#define MIN_COLUMNS     12      /* minimal columns for screen */
#define MIN_LINES       2       /* minimal lines for screen */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "window.h.generated.h"
#endif
#endif  // NVIM_WINDOW_H
