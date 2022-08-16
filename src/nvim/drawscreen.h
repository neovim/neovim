#ifndef NVIM_DRAWSCREEN_H
#define NVIM_DRAWSCREEN_H

#include "nvim/drawline.h"

/// flags for update_screen()
/// The higher the value, the higher the priority
enum {
  VALID        = 10,  ///< buffer not changed, or changes marked with b_mod_*
  INVERTED     = 20,  ///< redisplay inverted part that changed
  INVERTED_ALL = 25,  ///< redisplay whole inverted part
  REDRAW_TOP   = 30,  ///< display first w_upd_rows screen lines
  SOME_VALID   = 35,  ///< like NOT_VALID but may scroll
  NOT_VALID    = 40,  ///< buffer needs complete redraw
  CLEAR        = 50,  ///< screen messed up, clear it
};

/// While redrawing the screen this flag is set.  It means the screen size
/// ('lines' and 'rows') must not be changed.
EXTERN bool updating_screen INIT(= 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawscreen.h.generated.h"
#endif
#endif  // NVIM_DRAWSCREEN_H
