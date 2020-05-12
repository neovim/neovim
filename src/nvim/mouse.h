#ifndef NVIM_MOUSE_H
#define NVIM_MOUSE_H

#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/buffer_defs.h"

// jump_to_mouse() returns one of first four these values, possibly with
// some of the other three added.
#define IN_UNKNOWN             0
#define IN_BUFFER              1
#define IN_STATUS_LINE         2       // on status or command line
#define IN_SEP_LINE            4       // on vertical separator line
#define IN_OTHER_WIN           8       // in other window but can't go there
#define CURSOR_MOVED           0x100
#define MOUSE_FOLD_CLOSE       0x200   // clicked on '-' in fold column
#define MOUSE_FOLD_OPEN        0x400   // clicked on '+' in fold column
#define MOUSE_WINBAR           0x800   // in window toolbar

// flags for jump_to_mouse()
#define MOUSE_FOCUS            0x01    // need to stay in this window
#define MOUSE_MAY_VIS          0x02    // may start Visual mode
#define MOUSE_DID_MOVE         0x04    // only act when mouse has moved
#define MOUSE_SETPOS           0x08    // only set current mouse position
#define MOUSE_MAY_STOP_VIS     0x10    // may stop Visual mode
#define MOUSE_RELEASED         0x20    // button was released

// Codes for mouse button events in lower three bits:
#define MOUSE_LEFT     0x00
#define MOUSE_MIDDLE   0x01
#define MOUSE_RIGHT    0x02
#define MOUSE_RELEASE  0x03

#define MOUSE_X1       0x300  // Mouse-button X1 (6th)
#define MOUSE_X2       0x400  // Mouse-button X2

// Direction for nv_mousescroll() and ins_mousescroll()
#define MSCR_DOWN       0     // DOWN must be FALSE
#define MSCR_UP         1
#define MSCR_LEFT       -1
#define MSCR_RIGHT      -2


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mouse.h.generated.h"
#endif

#endif  // NVIM_MOUSE_H
