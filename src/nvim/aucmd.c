// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/os.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/ui.h"
#include "nvim/aucmd.h"
#include "nvim/eval.h"
#include "nvim/channel.h"
#include "nvim/msgpack_rpc/channel.h"

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

  Channel *chan = find_channel(chanid);
  const char *client_name = (chan && chanid > 0)
    ? rpc_client_name(chan)
    : (chanid > 0 ? "?" : "nvim-tui");

  dict_T *dict = get_vim_var_dict(VV_EVENT);
  assert(chanid < VARNUMBER_MAX);
  tv_dict_add_str(dict, S_LEN("name"),
                  client_name ? client_name : "?");
  tv_dict_add_nr(dict, S_LEN("chan"), (varnumber_T)chanid);
  tv_dict_set_keys_readonly(dict);
  apply_autocmds(attached ? EVENT_UIENTER : EVENT_UILEAVE,
                 (char_u *)client_name, NULL, false, curbuf);
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

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                 NULL, NULL, false, curbuf);
  recursive = false;
}
