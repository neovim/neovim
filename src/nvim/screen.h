#ifndef NVIM_SCREEN_H
#define NVIM_SCREEN_H

#include <stdbool.h>

#include "nvim/buffer_defs.h"
#include "nvim/grid.h"
#include "nvim/pos.h"
#include "nvim/types.h"

// flags for update_screen()
// The higher the value, the higher the priority
#define VALID                   10  // buffer not changed, or changes marked
                                    // with b_mod_*
#define INVERTED                20  // redisplay inverted part that changed
#define INVERTED_ALL            25  // redisplay whole inverted part
#define REDRAW_TOP              30  // display first w_upd_rows screen lines
#define SOME_VALID              35  // like NOT_VALID but may scroll
#define NOT_VALID               40  // buffer needs complete redraw
#define CLEAR                   50  // screen messed up, clear it

/// corner value flags for hsep_connected and vsep_connected
typedef enum {
  WC_TOP_LEFT = 0,
  WC_TOP_RIGHT,
  WC_BOTTOM_LEFT,
  WC_BOTTOM_RIGHT,
} WindowCorner;

// Maximum columns for terminal highlight attributes
#define TERM_ATTRS_MAX 1024

/// Array defining what should be done when tabline is clicked
EXTERN StlClickDefinition *tab_page_click_defs INIT(= NULL);

/// Size of the tab_page_click_defs array
EXTERN long tab_page_click_defs_size INIT(= 0);

#define W_ENDCOL(wp)   ((wp)->w_wincol + (wp)->w_width)
#define W_ENDROW(wp)   ((wp)->w_winrow + (wp)->w_height)

// While redrawing the screen this flag is set.  It means the screen size
// ('lines' and 'rows') must not be changed.
EXTERN bool updating_screen INIT(= 0);

// While resizing the screen this flag is set.
EXTERN bool resizing_screen INIT(= 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.h.generated.h"
#endif
#endif  // NVIM_SCREEN_H
