#pragma once

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/normal_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

/// jump_to_mouse() returns one of first five these values, possibly with
/// some of the other five added.
enum {
  IN_UNKNOWN       = 0,
  IN_BUFFER        = 1,
  IN_STATUS_LINE   = 2,       ///< on status or command line
  IN_SEP_LINE      = 4,       ///< on vertical separator line
  IN_OTHER_WIN     = 8,       ///< in other window but can't go there
  CURSOR_MOVED     = 0x100,
  MOUSE_FOLD_CLOSE = 0x200,   ///< clicked on '-' in fold column
  MOUSE_FOLD_OPEN  = 0x400,   ///< clicked on '+' in fold column
  MOUSE_WINBAR     = 0x800,   ///< in window toolbar
  MOUSE_STATUSCOL  = 0x1000,  ///< in 'statuscolumn'
};

/// flags for jump_to_mouse()
enum {
  MOUSE_FOCUS        = 0x01,  ///< need to stay in this window
  MOUSE_MAY_VIS      = 0x02,  ///< may start Visual mode
  MOUSE_DID_MOVE     = 0x04,  ///< only act when mouse has moved
  MOUSE_SETPOS       = 0x08,  ///< only set current mouse position
  MOUSE_MAY_STOP_VIS = 0x10,  ///< may stop Visual mode
  MOUSE_RELEASED     = 0x20,  ///< button was released
};

enum {
  // Codes for mouse button events in lower three bits:
  MOUSE_LEFT    = 0x00,
  MOUSE_MIDDLE  = 0x01,
  MOUSE_RIGHT   = 0x02,
  MOUSE_RELEASE = 0x03,

  // mouse buttons that are handled like a key press
  MOUSE_X1 = 0x300,  ///< Mouse-button X1 (6th)
  MOUSE_X2 = 0x400,  ///< Mouse-button X2
};

/// Direction for nv_mousescroll() and ins_mousescroll()
enum {
  MSCR_DOWN  = 0,  ///< DOWN must be false
  MSCR_UP    = 1,
  MSCR_LEFT  = -1,
  MSCR_RIGHT = -2,
};

#include "mouse.h.generated.h"
