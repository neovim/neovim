#include <stdbool.h>

#include <uv.h>

#include "nvim/lib/klist.h"

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/globals.h"
#include "nvim/memline.h"
#include "nvim/eval.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/os/signal.h"
#include "nvim/os/event.h"

#define SignalEventFreer(x)
KMEMPOOL_INIT(SignalEventPool, int, SignalEventFreer)
kmempool_t(SignalEventPool) *signal_event_pool = NULL;

static uv_signal_t spipe, shup, squit, sterm;
#ifdef SIGPWR
static uv_signal_t spwr;
#endif

static bool rejecting_deadly;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/signal.c.generated.h"
#endif

void signal_init(void)
{
  signal_event_pool = kmp_init(SignalEventPool);
  uv_signal_init(uv_default_loop(), &spipe);
  uv_signal_init(uv_default_loop(), &shup);
  uv_signal_init(uv_default_loop(), &squit);
  uv_signal_init(uv_default_loop(), &sterm);
  uv_signal_start(&spipe, signal_cb, SIGPIPE);
  uv_signal_start(&shup, signal_cb, SIGHUP);
  uv_signal_start(&squit, signal_cb, SIGQUIT);
  uv_signal_start(&sterm, signal_cb, SIGTERM);
#ifdef SIGPWR
  uv_signal_init(uv_default_loop(), &spwr);
  uv_signal_start(&spwr, signal_cb, SIGPWR);
#endif
}

void signal_teardown(void)
{
  signal_stop();
  uv_close((uv_handle_t *)&spipe, NULL);
  uv_close((uv_handle_t *)&shup, NULL);
  uv_close((uv_handle_t *)&squit, NULL);
  uv_close((uv_handle_t *)&sterm, NULL);
#ifdef SIGPWR
  uv_close((uv_handle_t *)&spwr, NULL);
#endif
}

void signal_stop(void)
{
  uv_signal_stop(&spipe);
  uv_signal_stop(&shup);
  uv_signal_stop(&squit);
  uv_signal_stop(&sterm);
#ifdef SIGPWR
  uv_signal_stop(&spwr);
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
    case SIGPIPE:
      return "SIGPIPE";
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
  int *n = kmp_alloc(SignalEventPool, signal_event_pool);
  *n = signum;
  event_push((Event) {
    .handler = on_signal_event,
    .data = n
  }, false);
}

static void on_signal_event(Event event)
{
  int signum = *((int *)event.data);
  kmp_free(SignalEventPool, signal_event_pool, event.data);

  switch (signum) {
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

