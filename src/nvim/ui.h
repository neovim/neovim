#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stdbool.h>

/*
 * jump_to_mouse() returns one of first four these values, possibly with
 * some of the other three added.
 */
#define IN_UNKNOWN             0
#define IN_BUFFER              1
#define IN_STATUS_LINE         2       /* on status or command line */
#define IN_SEP_LINE            4       /* on vertical separator line */
#define IN_OTHER_WIN           8       /* in other window but can't go there */
#define CURSOR_MOVED           0x100
#define MOUSE_FOLD_CLOSE       0x200   /* clicked on '-' in fold column */
#define MOUSE_FOLD_OPEN        0x400   /* clicked on '+' in fold column */

/* flags for jump_to_mouse() */
#define MOUSE_FOCUS            0x01    /* need to stay in this window */
#define MOUSE_MAY_VIS          0x02    /* may start Visual mode */
#define MOUSE_DID_MOVE         0x04    /* only act when mouse has moved */
#define MOUSE_SETPOS           0x08    /* only set current mouse position */
#define MOUSE_MAY_STOP_VIS     0x10    /* may stop Visual mode */
#define MOUSE_RELEASED         0x20    /* button was released */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
#endif
#endif  // NVIM_UI_H
