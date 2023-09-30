#ifndef NVIM_EVAL_WINDOW_H
#define NVIM_EVAL_WINDOW_H

#include <stdbool.h>
#include <string.h>

#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/cursor.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/globals.h"
#include "nvim/mark.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/os.h"
#include "nvim/pos.h"
#include "nvim/vim.h"
#include "nvim/window.h"

/// Structure used by switch_win() to pass values to restore_win()
typedef struct {
  win_T *sw_curwin;
  tabpage_T *sw_curtab;
  bool sw_same_win;  ///< VIsual_active was not reset
  bool sw_visual_active;
} switchwin_T;

/// Execute a block of code in the context of window `wp` in tabpage `tp`.
/// Ensures the status line is redrawn and cursor position is valid if it is moved.
#define WIN_EXECUTE(wp, tp, block) \
  do { \
    win_T *const wp_ = (wp); \
    const pos_T curpos_ = wp_->w_cursor; \
    char cwd_[MAXPATHL]; \
    char autocwd_[MAXPATHL]; \
    bool apply_acd_ = false; \
    int cwd_status_ = FAIL; \
    /* Getting and setting directory can be slow on some systems, only do */ \
    /* this when the current or target window/tab have a local directory or */ \
    /* 'acd' is set. */ \
    if (curwin != wp \
        && (curwin->w_localdir != NULL || wp->w_localdir != NULL \
            || (curtab != tp && (curtab->tp_localdir != NULL || tp->tp_localdir != NULL)) \
            || p_acd)) { \
      cwd_status_ = os_dirname(cwd_, MAXPATHL); \
    } \
    /* If 'acd' is set, check we are using that directory.  If yes, then */ \
    /* apply 'acd' afterwards, otherwise restore the current directory. */ \
    if (cwd_status_ == OK && p_acd) { \
      do_autochdir(); \
      apply_acd_ = os_dirname(autocwd_, MAXPATHL) == OK && strcmp(cwd_, autocwd_) == 0; \
    } \
    switchwin_T switchwin_; \
    if (switch_win_noblock(&switchwin_, wp_, (tp), true) == OK) { \
      check_cursor(); \
      block; \
    } \
    restore_win_noblock(&switchwin_, true); \
    if (apply_acd_) { \
      do_autochdir(); \
    } else if (cwd_status_ == OK) { \
      os_chdir(cwd_); \
    } \
    /* Update the status line if the cursor moved. */ \
    if (win_valid(wp_) && !equalpos(curpos_, wp_->w_cursor)) { \
      wp_->w_redr_status = true; \
    } \
    /* In case the command moved the cursor or changed the Visual area, */ \
    /* check it is valid. */ \
    check_cursor(); \
    if (VIsual_active) { \
      check_pos(curbuf, &VIsual); \
    } \
  } while (false)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/window.h.generated.h"
#endif
#endif  // NVIM_EVAL_WINDOW_H
