// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/ui.h"
#include "nvim/aucmd.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/buffer.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "aucmd.c.generated.h"
#endif

void do_autocmd_uienter(uint64_t chanid, bool attached)
{
  static bool recursive = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;

  dict_T *dict = get_vim_var_dict(VV_EVENT);
  assert(chanid < VARNUMBER_MAX);
  tv_dict_add_nr(dict, S_LEN("chan"), (varnumber_T)chanid);
  tv_dict_set_keys_readonly(dict);
  apply_autocmds(attached ? EVENT_UIENTER : EVENT_UILEAVE,
                 NULL, NULL, false, curbuf);
  tv_dict_clear(dict);

  recursive = false;
}

static void focusgained_event(void **argv)
{
  bool *gainedp = argv[0];
  do_autocmd_focusgained(*gainedp);
  xfree(gainedp);
}
void aucmd_schedule_focusgained(bool gained)
{
  bool *gainedp = xmalloc(sizeof(*gainedp));
  *gainedp = gained;
  loop_schedule_deferred(&main_loop,
                         event_create(focusgained_event, 1, gainedp));
}

static void do_autocmd_focusgained(bool gained)
{
  static bool recursive = false;
  static Timestamp last_time = (time_t)0;
  bool need_redraw = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  need_redraw |= apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                                NULL, NULL, false, curbuf);

  // When activated: Check if any file was modified outside of Vim.
  // Only do this when not done within the last two seconds as:
  // 1. Some filesystems have modification time granularity in seconds. Fat32
  //    has a granularity of 2 seconds.
  // 2. We could get multiple notifications in a row.
  if (gained && last_time + (Timestamp)2000 < os_now()) {
    need_redraw = check_timestamps(true);
    last_time = os_now();
  }

  if (need_redraw) {
    // Something was executed, make sure the cursor is put back where it
    // belongs.
    need_wait_return = false;

    if (State & CMDLINE) {
      redrawcmdline();
    } else if ((State & NORMAL) || (State & INSERT)) {
      if (must_redraw != 0) {
        update_screen(0);
      }

      setcursor();
    }

    ui_flush();
  }

  if (need_maketitle) {
    maketitle();
  }

  recursive = false;
}
