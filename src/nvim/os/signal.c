#include <assert.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/globals.h"
#include "nvim/memline.h"
#include "nvim/eval.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/event/signal.h"
#include "nvim/os/signal.h"
#include "nvim/event/loop.h"

static SignalWatcher spipe, shup, squit, sterm;
#ifdef SIGPWR
static SignalWatcher spwr;
#endif

static bool rejecting_deadly;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/signal.c.generated.h"
#endif

void signal_init(void)
{
  signal_watcher_init(&loop, &spipe, NULL);
  signal_watcher_init(&loop, &shup, NULL);
  signal_watcher_init(&loop, &squit, NULL);
  signal_watcher_init(&loop, &sterm, NULL);
#ifdef SIGPIPE
  signal_watcher_start(&spipe, on_signal, SIGPIPE);
#endif
  signal_watcher_start(&shup, on_signal, SIGHUP);
#ifdef SIGQUIT
  signal_watcher_start(&squit, on_signal, SIGQUIT);
#endif
  signal_watcher_start(&sterm, on_signal, SIGTERM);
#ifdef SIGPWR
  signal_watcher_init(&loop, &spwr, NULL);
  signal_watcher_start(&spwr, on_signal, SIGPWR);
#endif
}

void signal_teardown(void)
{
  signal_stop();
  signal_watcher_close(&spipe, NULL);
  signal_watcher_close(&shup, NULL);
  signal_watcher_close(&squit, NULL);
  signal_watcher_close(&sterm, NULL);
#ifdef SIGPWR
  signal_watcher_close(&spwr, NULL);
#endif
}

void signal_stop(void)
{
  signal_watcher_stop(&spipe);
  signal_watcher_stop(&shup);
  signal_watcher_stop(&squit);
  signal_watcher_stop(&sterm);
#ifdef SIGPWR
  signal_watcher_stop(&spwr);
#endif
}

void signal_reject_deadly(void)
{
  rejecting_deadly = true;
}

void signal_accept_deadly(void)
{
  rejecting_deadly = false;
}

static char * signal_name(int signum)
{
  switch (signum) {
#ifdef SIGPWR
    case SIGPWR:
      return "SIGPWR";
#endif
#ifdef SIGPIPE
    case SIGPIPE:
      return "SIGPIPE";
#endif
    case SIGTERM:
      return "SIGTERM";
#ifdef SIGQUIT
    case SIGQUIT:
      return "SIGQUIT";
#endif
    case SIGHUP:
      return "SIGHUP";
    default:
      return "Unknown";
  }
}

// This function handles deadly signals.
// It tries to preserve any swap files and exit properly.
// (partly from Elvis).
// NOTE: Avoid unsafe functions, such as allocating memory, they can result in
// a deadlock.
static void deadly_signal(int signum)
{
  // Set the v:dying variable.
  set_vim_var_nr(VV_DYING, 1);

  snprintf((char *)IObuff, sizeof(IObuff), "Vim: Caught deadly signal '%s'\n",
      signal_name(signum));

  // Preserve files and exit.
  preserve_exit();
}

static void on_signal(SignalWatcher *handle, int signum, void *data)
{
  assert(signum >= 0);
  switch (signum) {
#ifdef SIGPWR
    case SIGPWR:
      // Signal of a power failure(eg batteries low), flush the swap files to
      // be safe
      ml_sync_all(false, false);
      break;
#endif
#ifdef SIGPIPE
    case SIGPIPE:
      // Ignore
      break;
#endif
    case SIGTERM:
#ifdef SIGQUIT
    case SIGQUIT:
#endif
    case SIGHUP:
      if (!rejecting_deadly) {
        deadly_signal(signum);
      }
      break;
    default:
      fprintf(stderr, "Invalid signal %d", signum);
      break;
  }
}
