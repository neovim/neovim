// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "aucmd.c.generated.h"
#endif

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

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                 NULL, NULL, false, curbuf);
  recursive = false;
}

