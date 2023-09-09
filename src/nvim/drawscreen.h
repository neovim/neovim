#ifndef NVIM_DRAWSCREEN_H
#define NVIM_DRAWSCREEN_H

#include <stdbool.h>

#include "nvim/drawline.h"
#include "nvim/macros.h"

/// flags for update_screen()
/// The higher the value, the higher the priority
enum {
  UPD_VALID        = 10,  ///< buffer not changed, or changes marked with b_mod_*
  UPD_INVERTED     = 20,  ///< redisplay inverted part that changed
  UPD_INVERTED_ALL = 25,  ///< redisplay whole inverted part
  UPD_REDRAW_TOP   = 30,  ///< display first w_upd_rows screen lines
  UPD_SOME_VALID   = 35,  ///< like UPD_NOT_VALID but may scroll
  UPD_NOT_VALID    = 40,  ///< buffer needs complete redraw
  UPD_CLEAR        = 50,  ///< screen messed up, clear it
};

/// While redrawing the screen this flag is set.  It means the screen size
/// ('lines' and 'rows') must not be changed.
EXTERN bool updating_screen INIT(= 0);

EXTERN match_T screen_search_hl INIT(= { 0 });       // used for 'hlsearch' highlight matching

#define W_ENDCOL(wp)   ((wp)->w_wincol + (wp)->w_width)
#define W_ENDROW(wp)   ((wp)->w_winrow + (wp)->w_height)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawscreen.h.generated.h"
#endif
#endif  // NVIM_DRAWSCREEN_H
