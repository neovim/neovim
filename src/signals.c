#include <stdbool.h>
#include <uv.h>

#include "vim.h"
#include "eval.h"
#include "main.h"
#include "misc1.h"
#include "term.h"
#include "os/io.h"


static void handle_deadly(int signum);


char * signal_name(int signum) {
  switch (signum) {
    case SIGINT:
      return "SIGINT";
    case SIGWINCH:
      return "SIGWINCH";
    case SIGTERM:
      return "SIGTERM";
    case SIGABRT:
      return "SIGABRT";
    case SIGQUIT:
      return "SIGQUIT";
    case SIGHUP:
      return "SIGHUP";
    default:
      return "Unknown";
  }
}

void handle_signal() {
  int sig = io_consume_signal();

  switch (sig) {
    case SIGINT:
      got_int = TRUE;
      break;
    case SIGWINCH:
      shell_resized();
      break;
    case SIGTERM:
    case SIGABRT:
    case SIGQUIT:
    case SIGHUP:
      handle_deadly(sig);
      break;
    default:
      fprintf(stderr, "Invalid signal %d", sig);
      break;
  }
}

/*
 * This function handles deadly signals.
 * It tries to preserve any swap files and exit properly.
 * (partly from Elvis).
 * NOTE: Avoid unsafe functions, such as allocating memory, they can result in
 * a deadlock.
 */
static void handle_deadly(int sig) {
  static int entered = 0;           /* count the number of times we got here.
                                       Note: when memory has been corrupted
                                       this may get an arbitrary value! */
  ++entered;

  /* Set the v:dying variable. */
  set_vim_var_nr(VV_DYING, (long)entered);

  /*
   * If something goes wrong after entering here, we may get here again.
   * When this happens, give a message and try to exit nicely (resetting the
   * terminal mode, etc.)
   * When this happens twice, just exit, don't even try to give a message,
   * stack may be corrupt or something weird.
   * When this still happens again (or memory was corrupted in such a way
   * that "entered" was clobbered) use _exit(), don't try freeing resources.
   */
  if (entered >= 3) {
    /* TODO reset_signals(); */
    /* TODO may_core_dump(); */
    if (entered >= 4)
      _exit(8);
    exit(7);
  }
  if (entered == 2) {
    /* No translation, it may call malloc(). */
    OUT_STR("Vim: Double signal, exiting\n");
    out_flush();
    getout(1);
  }

  sprintf((char *)IObuff, "Vim: Caught deadly signal '%s'\n",
      signal_name(sig));

  /* Preserve files and exit.  This sets the really_exiting flag to prevent
   * calling free(). */
  preserve_exit();
}
