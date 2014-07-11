#ifndef NVIM_SCREEN_H
#define NVIM_SCREEN_H

#include <stdbool.h>

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


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.h.generated.h"
#endif
#endif  // NVIM_SCREEN_H
