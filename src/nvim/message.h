#ifndef NVIM_MESSAGE_H
#define NVIM_MESSAGE_H

#include <stdbool.h>
#include <stdarg.h>
#include <stddef.h>

#include "nvim/types.h"

/*
 * Types of dialogs passed to do_dialog().
 */
#define VIM_GENERIC     0
#define VIM_ERROR       1
#define VIM_WARNING     2
#define VIM_INFO        3
#define VIM_QUESTION    4
#define VIM_LAST_TYPE   4       /* sentinel value */

/*
 * Return values for functions like vim_dialogyesno()
 */
#define VIM_YES         2
#define VIM_NO          3
#define VIM_CANCEL      4
#define VIM_ALL         5
#define VIM_DISCARDALL  6

/// Show plain message
#define MSG(s)                      msg((char_u *)(s))

/// Show message highlighted according to the attr
#define MSG_ATTR(s, attr)           msg_attr((const char *)(s), (attr))

/// Display error message
///
/// Sets error flag in process, can be transformed into an exception.
#define EMSG(s)                     emsg((char_u *)(s))

/// Like #EMSG, but for messages with one "%s" inside
#define EMSG2(s, p)                 emsgf((const char *) (s), (p))

/// Like #EMSG, but for messages with two "%s" inside
#define EMSG3(s, p, q)              emsgf((const char *) (s), (p), (q))

/// Like #EMSG, but for messages with one "%" PRId64 inside
#define EMSGN(s, n)                 emsgf((const char *) (s), (int64_t)(n))

/// Like #EMSG, but for messages with one "%" PRIu64 inside
#define EMSGU(s, n)                 emsgf((const char *) (s), (uint64_t)(n))

/// Like #EMSG, but for internal messages
#define IEMSG(s)                    iemsg((const char *)(s))

/// Like #EMSG2, but for internal messages
#define IEMSG2(s, p)                iemsgf((const char *)(s), (p))

/// Like #EMSGN, but for internal messages
#define IEMSGN(s, n)                iemsgf((const char *)(s), (int64_t)(n))

/// Display message at the recorded position
#define MSG_PUTS(s)                 msg_puts((const char *)(s))

/// Display message at the recorded position, highlighted
#define MSG_PUTS_ATTR(s, a)         msg_puts_attr((const char *)(s), (a))

/// Like #MSG_PUTS, but highlight like title
#define MSG_PUTS_TITLE(s)           msg_puts_title((const char *)(s))

/// Like #MSG_PUTS, but if middle part of too long messages it will be replaced
#define MSG_PUTS_LONG(s)            msg_puts_long_attr((char_u *)(s), 0)

/// Like #MSG_PUTS_ATTR, but if middle part of long messages will be replaced
#define MSG_PUTS_LONG_ATTR(s, a)    msg_puts_long_attr((char_u *)(s), (a))

/// Message history for `:messages`
typedef struct msg_hist {
  struct msg_hist *next;  ///< Next message.
  char_u *msg;            ///< Message text.
  int attr;               ///< Message highlighting.
  bool multiline;         ///< Multiline message.
} MessageHistoryEntry;

/// First message
extern MessageHistoryEntry *first_msg_hist;
/// Last message
extern MessageHistoryEntry *last_msg_hist;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.h.generated.h"
#endif
#endif  // NVIM_MESSAGE_H
