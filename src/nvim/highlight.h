#ifndef NVIM_HIGHLIGHT_H
#define NVIM_HIGHLIGHT_H

#include <stdbool.h>

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/highlight_defs.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.h.generated.h"
#endif

static inline int win_hl_attr(win_T *wp, int hlf)
{
  // wp->w_ns_hl_attr might be null if we check highlights
  // prior to entering redraw
  return ((wp->w_ns_hl_attr && ns_hl_fast < 0) ? wp->w_ns_hl_attr : hl_attr_active)[hlf];
}

#define HLATTRS_DICT_SIZE 16

#define HL_SET_DEFAULT_COLORS(rgb_fg, rgb_bg, rgb_sp) \
  do { \
    bool dark_ = (*p_bg == 'd'); \
    rgb_fg = rgb_fg != -1 ? rgb_fg : (dark_ ? 0xFFFFFF : 0x000000); \
    rgb_bg = rgb_bg != -1 ? rgb_bg : (dark_ ? 0x000000 : 0xFFFFFF); \
    rgb_sp = rgb_sp != -1 ? rgb_sp : 0xFF0000; \
  } while (0);

#endif  // NVIM_HIGHLIGHT_H
