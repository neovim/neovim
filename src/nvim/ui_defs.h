#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"

/// Keep in sync with ui_ext_names[] in ui.h
typedef enum {
  kUICmdline = 0,
  kUIPopupmenu,
  kUITabline,
  kUIWildmenu,
  kUIMessages,
#define kUIGlobalCount kUILinegrid
  kUILinegrid,
  kUIMultigrid,
  kUIHlState,
  kUITermColors,
  kUIFloatDebug,
  kUIExtCount,
} UIExtension;

enum {
  kLineFlagWrap = 1,
  kLineFlagInvalid = 2,
};

typedef int LineFlags;

typedef struct ui_t UI;

typedef struct {
  uint64_t channel_id;

#define UI_BUF_SIZE 4096  ///< total buffer size for pending msgpack data.
  /// guaranteed size available for each new event (so packing of simple events
  /// and the header of grid_line will never fail)
#define EVENT_BUF_SIZE 256
  char buf[UI_BUF_SIZE];  ///< buffer of packed but not yet sent msgpack data
  char *buf_wptr;  ///< write head of buffer
  const char *cur_event;  ///< name of current event (might get multiple arglists)
  Array call_buf;  ///< buffer for constructing a single arg list (max 16 elements!)

  // state for write_cb, while packing a single arglist to msgpack. This
  // might fail due to buffer overflow.
  size_t pack_totlen;
  bool buf_overflow;
  char *temp_buf;

  // We start packing the two outermost msgpack arrays before knowing the total
  // number of elements. Thus track the location where array size will need
  // to be written in the msgpack buffer, once the specific array is finished.
  char *nevents_pos;
  char *ncalls_pos;
  uint32_t nevents;  ///< number of distinct events (top-level args to "redraw"
  uint32_t ncalls;  ///< number of calls made to the current event (plus one for the name!)
  bool flushed_events;  ///< events where sent to client without "flush" event

  size_t ncells_pending;  ///< total number of cells since last buffer flush

  int hl_id;  // Current highlight for legacy put event.
  Integer cursor_row, cursor_col;  // Intended visible cursor position.

  // Position of legacy cursor, used both for drawing and visible user cursor.
  Integer client_row, client_col;
  bool wildmenu_active;
} UIData;

struct ui_t {
  bool rgb;
  bool override;  ///< Force highest-requested UI capabilities.
  bool composed;
  bool ui_ext[kUIExtCount];  ///< Externalized UI capabilities.
  int width;
  int height;
  int pum_nlines;  /// actual nr. lines shown in PUM
  bool pum_pos;  /// UI reports back pum position?
  double pum_row;
  double pum_col;
  double pum_height;
  double pum_width;

  // TUI fields.
  char *term_name;
  char *term_background;  ///< Deprecated. No longer needed since background color detection happens
                          ///< in Lua. To be removed in a future release.
  int term_colors;
  bool stdin_tty;
  bool stdout_tty;

  // TODO(bfredl): integrate into struct!
  UIData data[1];
};

typedef struct {
  const char *name;
  void (*fn)(Array args);
} UIClientHandler;
