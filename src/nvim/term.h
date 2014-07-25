#ifndef NVIM_TERM_H
#define NVIM_TERM_H

/* Size of the buffer used for tgetent().  Unfortunately this is largely
 * undocumented, some systems use 1024.  Using a buffer that is too small
 * causes a buffer overrun and a crash.  Use the maximum known value to stay
 * on the safe side. */
#define TBUFSZ 2048             /* buffer size for termcap entry */

/* Codes for mouse button events in lower three bits: */
#define MOUSE_LEFT     0x00
#define MOUSE_MIDDLE   0x01
#define MOUSE_RIGHT    0x02
#define MOUSE_RELEASE  0x03

/* bit masks for modifiers: */
#define MOUSE_SHIFT    0x04
#define MOUSE_ALT      0x08
#define MOUSE_CTRL     0x10

/* mouse buttons that are handled like a key press (GUI only) */
/* Note that the scroll wheel keys are inverted: MOUSE_5 scrolls lines up but
 * the result of this is that the window moves down, similarly MOUSE_6 scrolls
 * columns left but the window moves right. */
#define MOUSE_4        0x100   /* scroll wheel down */
#define MOUSE_5        0x200   /* scroll wheel up */

#define MOUSE_X1       0x300 /* Mouse-button X1 (6th) */
#define MOUSE_X2       0x400 /* Mouse-button X2 */

#define MOUSE_6        0x500   /* scroll wheel left */
#define MOUSE_7        0x600   /* scroll wheel right */

/* 0x20 is reserved by xterm */
#define MOUSE_DRAG_XTERM   0x40

#define MOUSE_DRAG     (0x40 | MOUSE_RELEASE)

/* Lowest button code for using the mouse wheel (xterm only) */
#define MOUSEWHEEL_LOW         0x60

#define MOUSE_CLICK_MASK       0x03

#define NUM_MOUSE_CLICKS(code) \
  (((unsigned)((code) & 0xC0) >> 6) + 1)

#define SET_NUM_MOUSE_CLICKS(code, num) \
  (code) = ((code) & 0x3f) | ((((num) - 1) & 3) << 6)

/* Added to mouse column for GUI when 'mousefocus' wants to give focus to a
 * window by simulating a click on its status line.  We could use up to 128 *
 * 128 = 16384 columns, now it's reduced to 10000. */
#define MOUSE_COLOFF 10000

#if defined(UNIX)
# define CHECK_DOUBLE_CLICK 1  /* Checking for double clicks ourselves. */
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "term.h.generated.h"
#endif
#endif  // NVIM_TERM_H
