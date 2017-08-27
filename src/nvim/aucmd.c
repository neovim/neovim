// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/screen.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "aucmd.c.generated.h"
#endif

static void focusgained_event(void **argv)
{
  bool *gained = argv[0];
  do_autocmd_focusgained(*gained);
  xfree(gained);
}
void aucmd_schedule_focusgained(bool gained)
{
  bool *gainedp = xmalloc(sizeof(*gainedp));
  *gainedp = gained;
  loop_schedule(&main_loop, event_create(focusgained_event, 1, gainedp));
}

static void do_autocmd_focusgained(bool gained)
  FUNC_ATTR_NONNULL_ALL
{
  static bool recursive = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  bool has_any = has_event(EVENT_FOCUSGAINED) || has_event(EVENT_FOCUSLOST);
  bool did_any = apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                                NULL, NULL, false, curbuf);
  if (has_any && !did_any) {
    // HACK: Reschedule, hoping that the next event-loop tick will pick this up
    // during a "regular" state (as opposed to a weird implicit state, e.g.
    // early_init()..win_alloc_first() which disables autocommands).
    aucmd_schedule_focusgained(gained);
  }
  recursive = false;
}

