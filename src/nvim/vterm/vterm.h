#pragma once

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/macros_defs.h"
#include "nvim/types_defs.h"
#include "nvim/vterm/vterm_defs.h"
#include "nvim/vterm/vterm_keycodes_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/vterm.h.generated.h"
#endif

#define VTERM_VERSION_MAJOR 0
#define VTERM_VERSION_MINOR 3

// move a rect
static inline void vterm_rect_move(VTermRect *rect, int row_delta, int col_delta)
{
  rect->start_row += row_delta; rect->end_row += row_delta;
  rect->start_col += col_delta; rect->end_col += col_delta;
}

// Bit-field describing the content of the tagged union `VTermColor`.
typedef enum {
  // If the lower bit of `type` is not set, the colour is 24-bit RGB.
  VTERM_COLOR_RGB = 0x00,

  // The colour is an index into a palette of 256 colours.
  VTERM_COLOR_INDEXED = 0x01,

  // Mask that can be used to extract the RGB/Indexed bit.
  VTERM_COLOR_TYPE_MASK = 0x01,

  // If set, indicates that this colour should be the default foreground color, i.e. there was no
  // SGR request for another colour. When rendering this colour it is possible to ignore "idx" and
  // just use a colour that is not in the palette.
  VTERM_COLOR_DEFAULT_FG = 0x02,

  // If set, indicates that this colour should be the default background color, i.e. there was no
  // SGR request for another colour. A common option when rendering this colour is to not render a
  // background at all, for example by rendering the window transparently at this spot.
  VTERM_COLOR_DEFAULT_BG = 0x04,

  // Mask that can be used to extract the default foreground/background bit.
  VTERM_COLOR_DEFAULT_MASK = 0x06,
} VTermColorType;

// Returns true if the VTERM_COLOR_RGB `type` flag is set, indicating that the given VTermColor
// instance is an indexed colour.
#define VTERM_COLOR_IS_INDEXED(col) \
  (((col)->type & VTERM_COLOR_TYPE_MASK) == VTERM_COLOR_INDEXED)

// Returns true if the VTERM_COLOR_INDEXED `type` flag is set, indicating that the given VTermColor
// instance is an rgb colour.
#define VTERM_COLOR_IS_RGB(col) \
  (((col)->type & VTERM_COLOR_TYPE_MASK) == VTERM_COLOR_RGB)

// Returns true if the VTERM_COLOR_DEFAULT_FG `type` flag is set, indicating that the given
// VTermColor instance corresponds to the default foreground color.
#define VTERM_COLOR_IS_DEFAULT_FG(col) \
  (!!((col)->type & VTERM_COLOR_DEFAULT_FG))

// Returns true if the VTERM_COLOR_DEFAULT_BG `type` flag is set, indicating that the given
// VTermColor instance corresponds to the default background color.
#define VTERM_COLOR_IS_DEFAULT_BG(col) \
  (!!((col)->type & VTERM_COLOR_DEFAULT_BG))

// Constructs a new VTermColor instance representing the given RGB values.
static inline void vterm_color_rgb(VTermColor *col, uint8_t red, uint8_t green, uint8_t blue)
{
  col->type = VTERM_COLOR_RGB;
  col->rgb.red = red;
  col->rgb.green = green;
  col->rgb.blue = blue;
}

// Construct a new VTermColor instance representing an indexed color with the given index.
static inline void vterm_color_indexed(VTermColor *col, uint8_t idx)
{
  col->type = VTERM_COLOR_INDEXED;
  col->indexed.idx = idx;
}

// ------------
// Parser layer
// ------------

/// Flag to indicate non-final subparameters in a single CSI parameter.
/// Consider
///   CSI 1;2:3:4;5a
/// 1 4 and 5 are final.
/// 2 and 3 are non-final and will have this bit set
///
/// Don't confuse this with the final byte of the CSI escape; 'a' in this case.
#define CSI_ARG_FLAG_MORE (1U << 31)
#define CSI_ARG_MASK      (~(1U << 31))

#define CSI_ARG_HAS_MORE(a) ((a)& CSI_ARG_FLAG_MORE)
#define CSI_ARG(a)          ((a)& CSI_ARG_MASK)

// Can't use -1 to indicate a missing argument; use this instead
#define CSI_ARG_MISSING ((1UL<<31) - 1)

#define CSI_ARG_IS_MISSING(a) (CSI_ARG(a) == CSI_ARG_MISSING)
#define CSI_ARG_OR(a, def)     (CSI_ARG(a) == CSI_ARG_MISSING ? (def) : CSI_ARG(a))
#define CSI_ARG_COUNT(a)      (CSI_ARG(a) == CSI_ARG_MISSING || CSI_ARG(a) == 0 ? 1 : CSI_ARG(a))

enum {
  VTERM_UNDERLINE_OFF,
  VTERM_UNDERLINE_SINGLE,
  VTERM_UNDERLINE_DOUBLE,
  VTERM_UNDERLINE_CURLY,
};

enum {
  VTERM_BASELINE_NORMAL,
  VTERM_BASELINE_RAISE,
  VTERM_BASELINE_LOWER,
};

// Back-compat alias for the brief time it was in 0.3-RC1
#define vterm_screen_set_reflow  vterm_screen_enable_reflow

void vterm_scroll_rect(VTermRect rect, int downward, int rightward,
                       int (*moverect)(VTermRect src, VTermRect dest, void *user),
                       int (*eraserect)(VTermRect rect, int selective, void *user), void *user);

struct VTermScreen {
  VTerm *vt;
  VTermState *state;

  const VTermScreenCallbacks *callbacks;
  void *cbdata;

  VTermDamageSize damage_merge;
  // start_row == -1 => no damage
  VTermRect damaged;
  VTermRect pending_scrollrect;
  int pending_scroll_downward, pending_scroll_rightward;

  int rows;
  int cols;

  unsigned global_reverse : 1;
  unsigned reflow : 1;

  // Primary and Altscreen. buffers[1] is lazily allocated as needed
  ScreenCell *buffers[2];

  // buffer will == buffers[0] or buffers[1], depending on altscreen
  ScreenCell *buffer;

  // buffer for a single screen row used in scrollback storage callbacks
  VTermScreenCell *sb_buffer;

  ScreenPen pen;
};
