#ifndef NVIM_MESSAGE_H
#define NVIM_MESSAGE_H

#include <stdbool.h>
#include <stdarg.h>
#include "nvim/eval_defs.h"  // for typval_T

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
