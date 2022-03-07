#ifndef NVIM_DECORATION_H
#define NVIM_DECORATION_H

#include "nvim/buffer_defs.h"
#include "nvim/extmark_defs.h"
#include "nvim/pos.h"

// actual Decoration data is in extmark_defs.h

typedef uint16_t DecorPriority;
#define DECOR_PRIORITY_BASE 0x1000

typedef enum {
  kVTEndOfLine,
  kVTOverlay,
  kVTWinCol,
  kVTRightAlign,
} VirtTextPos;

EXTERN const char *const virt_text_pos_str[] INIT(= { "eol", "overlay", "win_col", "right_align" });

typedef enum {
  kHlModeUnknown,
  kHlModeReplace,
  kHlModeCombine,
  kHlModeBlend,
} HlMode;

EXTERN const char *const hl_mode_str[] INIT(= { "", "replace", "combine", "blend" });

typedef kvec_t(VirtTextChunk) VirtText;
#define VIRTTEXT_EMPTY ((VirtText)KV_INITIAL_VALUE)


typedef kvec_t(struct virt_line { VirtText line; bool left_col; }) VirtLines;


struct Decoration {
  VirtText virt_text;
  VirtLines virt_lines;

  int hl_id;  // highlight group
  VirtTextPos virt_text_pos;
  HlMode hl_mode;

  // TODO(bfredl): at some point turn this into FLAGS
  bool virt_text_hide;
  bool hl_eol;
  bool virt_lines_above;
  // TODO(bfredl): style, etc
  DecorPriority priority;
  int col;  // fixed col value, like win_col
  int virt_text_width;  // width of virt_text
  char_u *sign_text;
  int sign_hl_id;
  int number_hl_id;
  int line_hl_id;
  int cursorline_hl_id;
};
#define DECORATION_INIT { KV_INITIAL_VALUE, KV_INITIAL_VALUE, 0, kVTEndOfLine, kHlModeUnknown, \
                          false, false, false, DECOR_PRIORITY_BASE, 0, 0, NULL, 0, 0, 0, 0 }

typedef struct {
  int start_row;
  int start_col;
  int end_row;
  int end_col;
  Decoration decor;
  int attr_id;  // cached lookup of decor.hl_id
  bool virt_text_owned;
  int win_col;
} DecorRange;

typedef struct {
  MarkTreeIter itr[1];
  kvec_t(DecorRange) active;
  buf_T *buf;
  int top_row;
  int row;
  int col_until;
  int current;
  int eol_col;
  bool has_sign_decor;
} DecorState;

typedef struct {
  NS ns_id;
  bool active;
  LuaRef redraw_start;
  LuaRef redraw_buf;
  LuaRef redraw_win;
  LuaRef redraw_line;
  LuaRef redraw_end;
  LuaRef hl_def;
  int hl_valid;
} DecorProvider;

EXTERN kvec_t(DecorProvider) decor_providers INIT(= KV_INITIAL_VALUE);
EXTERN DecorState decor_state INIT(= { 0 });
EXTERN bool provider_active INIT(= false);

#define DECORATION_PROVIDER_INIT(ns_id) (DecorProvider) \
  { ns_id, false, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, -1 }

static inline bool decor_has_sign(Decoration *decor)
{
  return decor->sign_text
    || decor->sign_hl_id
    || decor->number_hl_id
    || decor->line_hl_id
    || decor->cursorline_hl_id;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.h.generated.h"
#endif

#endif  // NVIM_DECORATION_H
