#ifndef NVIM_SCREEN_H
#define NVIM_SCREEN_H

#include <stdbool.h>

#include "nvim/types.h"
#include "nvim/buffer_defs.h"
#include "nvim/grid_defs.h"
#include "nvim/pos.h"

/*
 * flags for update_screen()
 * The higher the value, the higher the priority
 */
#define VALID                   10  /* buffer not changed, or changes marked
                                       with b_mod_* */
#define INVERTED                20  /* redisplay inverted part that changed */
#define INVERTED_ALL            25  /* redisplay whole inverted part */
#define REDRAW_TOP              30  /* display first w_upd_rows screen lines */
#define SOME_VALID              35  /* like NOT_VALID but may scroll */
#define NOT_VALID               40  /* buffer needs complete redraw */
#define CLEAR                   50  /* screen messed up, clear it */

/// By default, all widows are draw on a single rectangular grid, represented by
/// this ScreenGrid instance. In multigrid mode each window will have its own
/// grid, then this is only used for global screen elements that hasn't been
/// externalized.
///
/// Note: before the screen is initialized and when out of memory these can be
/// NULL.
EXTERN ScreenGrid default_grid INIT(= { 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0,
                                        0, 0, 0 });

#define DEFAULT_GRID_HANDLE 1  // handle for the default_grid

/// Status line click definition
typedef struct {
  enum {
    kStlClickDisabled = 0,  ///< Clicks to this area are ignored.
    kStlClickTabSwitch,     ///< Switch to the given tab.
    kStlClickTabClose,      ///< Close given tab.
    kStlClickFuncRun,       ///< Run user function.
  } type;      ///< Type of the click.
  int tabnr;   ///< Tab page number.
  char *func;  ///< Function to run.
} StlClickDefinition;

/// Used for tabline clicks
typedef struct {
  StlClickDefinition def;  ///< Click definition.
  const char *start;       ///< Location where region starts.
} StlClickRecord;

/// Array defining what should be done when tabline is clicked
extern StlClickDefinition *tab_page_click_defs;

/// Size of the tab_page_click_defs array
extern long tab_page_click_defs_size;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.h.generated.h"
#endif
#endif  // NVIM_SCREEN_H
