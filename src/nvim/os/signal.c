#include <stdbool.h>

#include <uv.h>

#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/globals.h"
#include "nvim/memline.h"
#include "nvim/eval.h"
#include "nvim/term.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/os/event_defs.h"
#include "nvim/os/event.h"
#include "nvim/os/signal.h"

static uv_signal_t sint, spipe, shup, squit, sterm, swinch;
#ifdef SIGPWR
static uv_signal_t spwr;
#endif

static bool rejecting_deadly;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/signal.c.generated.h"
#endif
void signal_init()
{
  uv_signal_init(uv_default_loop(), &sint);
  uv_signal_init(uv_default_loop(), &spipe);
  uv_signal_init(uv_default_loop(), &shup);
  uv_signal_init(uv_default_loop(), &squit);
  uv_signal_init(uv_default_loop(), &sterm);
  uv_signal_init(uv_default_loop(), &swinch);
  uv_signal_start(&sint, signal_cb, SIGINT);
  uv_signal_start(&spipe, signal_cb, SIGPIPE);
  uv_signal_start(&shup, signal_cb, SIGHUP);
  uv_signal_start(&squit, signal_cb, SIGQUIT);
  uv_signal_start(&sterm, signal_cb, SIGTERM);
  uv_signal_start(&swinch, signal_cb, SIGWINCH);
#ifdef SIGPWR
  uv_signal_init(uv_default_loop(), &spwr);
  uv_signal_start(&spwr, signal_cb, SIGPWR);
#endif
}

void signal_stop()
{
  uv_signal_stop(&sint);
  uv_signal_stop(&spipe);
  uv_signal_stop(&shup);
  uv_signal_stop(&squit);
  uv_signal_stop(&sterm);
  uv_signal_stop(&swinch);
#ifdef SIGPWR
  uv_signal_stop(&spwr);
#endif
}

void signal_reject_deadly()
{
  rejecting_deadly = true;
}

void signal_accept_deadly()
{
  rejecting_deadly = false;
}

void signal_handle(Event event)
{
  int signum = event.data.signum;

  switch (signum) {
    case SIGINT:
      got_int = true;
      break;
#ifdef SIGPWR
    case SIGPWR:
      // Signal of a power failure(eg batteries low), flush the swap files to
      // be safe
      ml_sync_all(false, false);
      break;
#endif
    case SIGPIPE:
      // Ignore
      break;
    case SIGWINCH:
      shell_resized();
      break;
    case SIGTERM:
    case SIGQUIT:
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

static char * signal_name(int signum)
{
  switch (signum) {
    case SIGINT:
      return "SIGINT";
#ifdef SIGPWR
    case SIGPWR:
      return "SIGPWR";
#endif
    case SIGPIPE:
      return "SIGPIPE";
    case SIGWINCH:
      return "SIGWINCH";
    case SIGTERM:
      return "SIGTERM";
    case SIGQUIT:
      return "SIGQUIT";
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

static void signal_cb(uv_signal_t *handle, int signum)
{
  if (rejecting_deadly) {
    if (signum == SIGINT) {
      got_int = true;
    }

    return;
  }

  Event event = {
    .type = kEventSignal,
    .data = {
      .signum = signum
    }
  };
  event_push(event, true);
}
