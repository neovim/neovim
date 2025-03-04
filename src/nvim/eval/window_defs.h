#include "nvim/buffer_defs.h"

/// Structure used by switch_win() to pass values to restore_win()
typedef struct {
  win_T *sw_curwin;
  tabpage_T *sw_curtab;
  bool sw_same_win;  ///< VIsual_active was not reset
  bool sw_visual_active;
} switchwin_T;

/// Structure used by win_execute_before() to pass values to win_execute_after()
typedef struct {
  win_T *wp;
  pos_T curpos;
  char cwd[MAXPATHL];
  int cwd_status;
  bool apply_acd;
  switchwin_T switchwin;
} win_execute_T;
