#pragma once

#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/types_defs.h"

#define DECOR_ID_INVALID UINT32_MAX

typedef struct {
  char *text;
  int hl_id;  ///< -1 if not specified
} VirtTextChunk;

typedef kvec_t(VirtTextChunk) VirtText;
#define VIRTTEXT_EMPTY ((VirtText)KV_INITIAL_VALUE)

/// Keep in sync with virt_text_pos_str[] in decoration.h
typedef enum {
  kVPosEndOfLine,
  kVPosEndOfLineRightAlign,
  kVPosInline,
  kVPosOverlay,
  kVPosRightAlign,
  kVPosWinCol,
} VirtTextPos;

/// Flags for virtual lines
enum {
  kVLLeftcol = 1,  ///< Start at left window edge, ignoring number column, etc.
  kVLScroll = 2,   ///< Can scroll horizontally with 'nowrap'
  // kVLWrap = 4,
};

typedef kvec_t(struct virt_line { VirtText line; int flags; }) VirtLines;

typedef uint16_t DecorPriority;
#define DECOR_PRIORITY_BASE 0x1000

/// Keep in sync with hl_mode_str[] in decoration.h
typedef enum {
  kHlModeUnknown,
  kHlModeReplace,
  kHlModeCombine,
  kHlModeBlend,
} HlMode;

enum {
  kSHIsSign = 1,
  kSHHlEol = 2,
  kSHUIWatched = 4,
  kSHUIWatchedOverlay = 8,
  kSHSpellOn = 16,
  kSHSpellOff = 32,
  kSHConceal = 64,
  kSHConcealLines = 128,
};

typedef struct {
  uint16_t flags;
  DecorPriority priority;
  int hl_id;
  schar_T conceal_char;
} DecorHighlightInline;

#define DECOR_HIGHLIGHT_INLINE_INIT { 0, DECOR_PRIORITY_BASE, 0, 0 }

typedef struct {
  uint16_t flags;
  DecorPriority priority;
  int hl_id;  // if sign: highlight of sign text
  schar_T text[SIGN_WIDTH];  // conceal text only uses text[0]
  // NOTE: if more functionality is added to a Highlight these should be overloaded
  // or restructured
  char *sign_name;
  int sign_add_id;
  int number_hl_id;
  int line_hl_id;
  int cursorline_hl_id;
  uint32_t next;
  const char *url;
} DecorSignHighlight;

#define DECOR_SIGN_HIGHLIGHT_INIT { 0, DECOR_PRIORITY_BASE, 0, { 0, 0 }, NULL, 0, 0, 0, 0, \
                                    DECOR_ID_INVALID, NULL }

enum {
  kVTIsLines = 1,
  kVTHide = 2,
  kVTLinesAbove = 4,
  kVTRepeatLinebreak = 8,
};

typedef struct DecorVirtText DecorVirtText;
struct DecorVirtText {
  uint8_t flags;
  uint8_t hl_mode;
  DecorPriority priority;
  int width;  // width of virt_text
  int col;
  VirtTextPos pos;
  // TODO(bfredl): reduce this to one datatype, later
  union {
    VirtText virt_text;
    VirtLines virt_lines;
  } data;
  DecorVirtText *next;
};
#define DECOR_VIRT_TEXT_INIT { 0, kHlModeUnknown, DECOR_PRIORITY_BASE, 0, 0, kVPosEndOfLine, \
                               { .virt_text = KV_INITIAL_VALUE }, NULL, }
#define DECOR_VIRT_LINES_INIT { kVTIsLines, kHlModeUnknown, DECOR_PRIORITY_BASE, 0, 0, \
                                kVPosEndOfLine, { .virt_lines = KV_INITIAL_VALUE }, NULL, }

typedef struct {
  uint32_t sh_idx;
  DecorVirtText *vt;
} DecorExt;

// Stored inline in marktree, with MT_FLAG_DECOR_EXT in MTKey.flags
typedef union {
  DecorHighlightInline hl;
  DecorExt ext;
} DecorInlineData;

// Not stored in the marktree, but used when passing around args
//
// Convention: an empty "no decoration" value should always be encoded
// with ext=false and an unset DecorHighlightInline (no flags, no hl_id)
typedef struct {
  bool ext;
  DecorInlineData data;
} DecorInline;

// initializes in a valid state for the DecorHighlightInline branch
#define DECOR_INLINE_INIT { .ext = false, .data.hl = DECOR_HIGHLIGHT_INLINE_INIT }

typedef struct {
  NS ns_id;

  enum {
    kDecorProviderActive = 1,
    kDecorProviderWinDisabled = 2,
    kDecorProviderRedrawDisabled = 3,
    kDecorProviderDisabled = 4,
  } state;

  LuaRef redraw_start;
  LuaRef redraw_buf;
  LuaRef redraw_win;
  LuaRef redraw_line;
  LuaRef redraw_end;
  LuaRef hl_def;
  LuaRef spell_nav;
  LuaRef conceal_line;
  int hl_valid;
  bool hl_cached;

  uint8_t error_count;
} DecorProvider;
