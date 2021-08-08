#ifndef NVIM_DECORATION_H
#define NVIM_DECORATION_H

#include "nvim/pos.h"
#include "nvim/buffer_defs.h"
#include "nvim/extmark_defs.h"

// actual Decoration data is in extmark_defs.h

typedef uint16_t DecorPriority;
#define DECOR_PRIORITY_BASE 0x1000

typedef enum {
  kVTEndOfLine,
  kVTOverlay,
  kVTWinCol,
  kVTRightAlign,
} VirtTextPos;

typedef enum {
  kHlModeUnknown,
  kHlModeReplace,
  kHlModeCombine,
  kHlModeBlend,
} HlMode;

struct Decoration
{
  VirtText virt_text;
  int hl_id;  // highlight group
  VirtTextPos virt_text_pos;
  HlMode hl_mode;
  bool virt_text_hide;
  bool hl_eol;
  bool shared;  // shared decoration, don't free
  // TODO(bfredl): style, signs, etc
  DecorPriority priority;
  int col;  // fixed col value, like win_col
  int virt_text_width;  // width of virt_text
};
#define DECORATION_INIT { KV_INITIAL_VALUE, 0, kVTEndOfLine, kHlModeUnknown, \
                          false, false, false, DECOR_PRIORITY_BASE, 0, 0 }

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
  VirtText *virt_text;
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.h.generated.h"
#endif

#endif  // NVIM_DECORATION_H
