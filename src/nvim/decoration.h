#ifndef NVIM_DECORATION_H
#define NVIM_DECORATION_H

#include "nvim/pos.h"
#include "nvim/buffer_defs.h"
#include "nvim/extmark_defs.h"

// actual Decoration data is in extmark_defs.h

typedef struct {
  char *text;
  int hl_id;
} VirtTextChunk;

typedef kvec_t(VirtTextChunk) VirtText;
#define VIRTTEXT_EMPTY ((VirtText)KV_INITIAL_VALUE)

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
  int hl_id;  // highlight group
  VirtText virt_text;
  VirtTextPos virt_text_pos;
  bool virt_text_hide;
  HlMode hl_mode;
  bool hl_eol;
  // TODO(bfredl): style, signs, etc
  DecorPriority priority;
  bool shared;  // shared decoration, don't free
  int col;  // fixed col value, like win_col
};
#define DECORATION_INIT { 0, KV_INITIAL_VALUE, kVTEndOfLine, false, \
                          kHlModeUnknown, false, DECOR_PRIORITY_BASE, false, 0 }

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
  bool hl_cached;
} DecorProvider;

EXTERN kvec_t(DecorProvider) decor_providers INIT(= KV_INITIAL_VALUE);
EXTERN DecorState decor_state INIT(= { 0 });
EXTERN bool provider_active INIT(= false);

#define DECORATION_PROVIDER_INIT(ns_id) (DecorProvider) \
                                 { ns_id, false, LUA_NOREF, LUA_NOREF, \
                                   LUA_NOREF, LUA_NOREF, LUA_NOREF, \
                                   LUA_NOREF, -1, false }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration.h.generated.h"
#endif

#endif  // NVIM_DECORATION_H
