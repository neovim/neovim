#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/event/defs.h"
#include "nvim/terminal.h"
#include "nvim/vterm/vterm.h"

typedef struct {
  size_t cols;
  VTermScreenCell cells[];
} ScrollbackLine;

struct terminal {
  TerminalOptions opts;  // options passed to terminal_alloc()
  VTerm *vt;
  VTermScreen *vts;
  // buffer used to:
  //  - convert VTermScreen cell arrays into utf8 strings
  //  - receive data from libvterm as a result of key presses.
  char textbuf[0x1fff];

  ScrollbackLine **sb_buffer;  ///< Scrollback storage.
  size_t sb_current;           ///< Lines stored in sb_buffer.
  size_t sb_size;              ///< Capacity of sb_buffer.
  /// "virtual index" that points to the first sb_buffer row that we need to
  /// push to the terminal buffer when refreshing the scrollback.
  int sb_pending;
  size_t sb_deleted;      ///< Lines deleted from sb_buffer.
  size_t old_sb_deleted;  ///< Value of sb_deleted on last refresh_scrollback().
  /// Lines in the terminal buffer belonging to the screen instead of the scrollback.
  int old_height;

  char *title;     // VTermStringFragment buffer
  size_t title_len;
  size_t title_size;

  // buf_T instance that acts as a "drawing surface" for libvterm
  // we can't store a direct reference to the buffer because the
  // refresh_timer_cb may be called after the buffer was freed, and there's
  // no way to know if the memory was reused.
  handle_T buf_handle;
  bool in_altscreen;
  // program suspended
  bool suspended;
  // program exited
  bool closed;
  // when true, the terminal's destruction is already enqueued.
  bool destroy;

  // some vterm properties
  bool forward_mouse;
  int invalid_start, invalid_end;   // invalid rows in libvterm screen
  struct {
    int row, col;
    int shape;
    bool visible;  ///< Terminal wants to show cursor.
                   ///< `TerminalState.cursor_visible` indicates whether it is actually shown.
    bool blink;
  } cursor;

  struct {
    bool resize;          ///< pending width/height
    bool cursor;          ///< pending cursor shape or blink change
    StringBuilder *send;  ///< When there is a pending TermRequest autocommand, block and store input.
    MultiQueue *events;   ///< Events waiting for refresh.
  } pending;

  bool streamed_paste;  ///< Streamed pasting
  bool theme_updates;  ///< Send a theme update notification when 'bg' changes
  bool synchronized_output;  ///< Mode 2026: suppress redraws until end of synchronized update
  bool sync_flush_pending;   ///< Set when mode 2026 ends; triggers immediate buffer refresh

  bool color_set[16];

  char *selection_buffer;  ///< libvterm selection buffer
  StringBuilder selection;  ///< Growable array containing full selection data

  StringBuilder termrequest_buffer;  ///< Growable array containing unfinished request sequence
  VTermTerminator termrequest_terminator;  ///< Terminator (BEL or ST) used in the termrequest

  size_t refcount;                  // reference count
};
