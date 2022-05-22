#ifndef NVIM_MESSAGE_H
#define NVIM_MESSAGE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/grid_defs.h"
#include "nvim/lib/kvec.h"
#include "nvim/macros.h"
#include "nvim/types.h"

/*
 * Types of dialogs passed to do_dialog().
 */
#define VIM_GENERIC     0
#define VIM_ERROR       1
#define VIM_WARNING     2
#define VIM_INFO        3
#define VIM_QUESTION    4
#define VIM_LAST_TYPE   4       // sentinel value

/*
 * Return values for functions like vim_dialogyesno()
 */
#define VIM_YES         2
#define VIM_NO          3
#define VIM_CANCEL      4
#define VIM_ALL         5
#define VIM_DISCARDALL  6

typedef struct {
  String text;
  int attr;
} HlMessageChunk;

typedef kvec_t(HlMessageChunk) HlMessage;

/// Message history for `:messages`
typedef struct msg_hist {
  struct msg_hist *next;  ///< Next message.
  char_u *msg;            ///< Message text.
  const char *kind;     ///< Message kind (for msg_ext)
  int attr;               ///< Message highlighting.
  bool multiline;         ///< Multiline message.
} MessageHistoryEntry;

/// First message
extern MessageHistoryEntry *first_msg_hist;
/// Last message
extern MessageHistoryEntry *last_msg_hist;

EXTERN bool msg_ext_need_clear INIT(= false);

// allocated grid for messages. Used when display+=msgsep is set, or
// ext_multigrid is active. See also the description at msg_scroll_flush()
EXTERN ScreenGrid msg_grid INIT(= SCREEN_GRID_INIT);
EXTERN int msg_grid_pos INIT(= 0);

// "adjusted" message grid. This grid accepts positions relative to
// default_grid. Internally it will be translated to a position on msg_grid
// relative to the start of the message area, or directly mapped to default_grid
// for legacy (display-=msgsep) message scroll behavior.
// // TODO(bfredl): refactor "internal" message logic, msg_row etc
// to use the correct positions already.
EXTERN ScreenGrid msg_grid_adj INIT(= SCREEN_GRID_INIT);

// value of msg_scrolled at latest msg_scroll_flush.
EXTERN int msg_scrolled_at_flush INIT(= 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.h.generated.h"
#endif
#endif  // NVIM_MESSAGE_H
