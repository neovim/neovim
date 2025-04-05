#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/api/fold.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/validate.h"
#include "nvim/fold.h"
#include "nvim/pos_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/fold.c.generated.h"  // IWYU pragma: keep
#endif

/// Gets the start and end lines for the closed fold on the given line
///
/// @param window   |window-ID|, or 0 for current window
/// @param lnum   The line number to check (0-indexed)
/// @param[out] err Error details, if any
/// @return  Dict containing fold information, with these keys:
///          - first: The start line of the current closed fold, or `nil` if none
///          - last: The end line of the current closed fold, or `nil` if none
Dict(fold_info) nvim__fold_info(Window window, Integer lnum, Arena *arena, Error *err)
  FUNC_API_SINCE(14)
{
  Dict(fold_info) rv = KEYDICT_INIT;
  win_T *win = find_window_by_handle(window, err);

  if (win) {
    if (lnum >= 0 && lnum <= win->w_buffer->b_ml.ml_line_count - 1) {
      linenr_T first;
      linenr_T last;
      if (hasFoldingWin(win, (linenr_T)(lnum + 1), &first, &last, false, NULL)) {
        PUT_KEY(rv, fold_info, first, first);
        PUT_KEY(rv, fold_info, last, last);
      }
    } else {
      api_set_error(err, kErrorTypeValidation, "Line number outside range");
    }
  }

  return rv;
}
