#ifndef NVIM_MESSAGE_H
#define NVIM_MESSAGE_H

#include <stdbool.h>
#include <stdarg.h>
#include "nvim/eval_defs.h"  // for typval_T

// Columns needed by 'showcmd' display.
// Also used for the notifications summary (enough to show "+NN :messages").
#define SHOWCMD_COLS 13

#define DIALOG_MSG_SIZE 1000    /* buffer size for dialog_msg() */

/* special attribute addition: Put message in history */
#define MSG_HIST                0x1000
#define MAX_MSG_HIST_LEN        400

#define MSG(s)                      msg((char_u *)(s))
#define MSG_ATTR(s, attr)           msg_attr((char_u *)(s), (attr))
#define EMSG(s)                     emsg((char_u *)(s))
#define EMSG2(s, p)                 emsg2((char_u *)(s), (char_u *)(p))
#define EMSG3(s, p, q)              emsg3((char_u *)(s), (char_u *)(p), \
    (char_u *)(q))
#define EMSGN(s, n)                 emsgn((char_u *)(s), (int64_t)(n))
#define EMSGU(s, n)                 emsgu((char_u *)(s), (uint64_t)(n))
#define OUT_STR(s)                  out_str((char_u *)(s))
#define OUT_STR_NF(s)               out_str_nf((char_u *)(s))
#define MSG_PUTS(s)                 msg_puts((char_u *)(s))
#define MSG_PUTS_ATTR(s, a)         msg_puts_attr((char_u *)(s), (a))
#define MSG_PUTS_TITLE(s)           msg_puts_title((char_u *)(s))
#define MSG_PUTS_LONG(s)            msg_puts_long_attr((char_u *)(s), 0)
#define MSG_PUTS_LONG_ATTR(s, a)    msg_puts_long_attr((char_u *)(s), (a))

#define PERROR(msg) \
  (void) emsg3((char_u *) "%s: %s", (char_u *)msg, (char_u *)strerror(errno))

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.h.generated.h"
#endif
#endif  // NVIM_MESSAGE_H
