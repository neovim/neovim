//
// Terminal/console utils
//

#include "nvim/os/os.h"  // IWYU pragma: keep (Windows)
#include "nvim/os/tty.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/tty.c.generated.h"  // IWYU pragma: export
#endif

#ifdef MSWIN
# if !defined(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
#  define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
# endif
/// Guesses the terminal-type.  Calls SetConsoleMode() and uv_set_vterm_state()
/// if appropriate.
///
/// @param[in,out] term Name of the guessed terminal, statically-allocated
/// @param out_fd stdout file descriptor
void os_tty_guess_term(const char **term, int out_fd)
{
  bool conemu_ansi = strequal(os_getenv("ConEmuANSI"), "ON");
  bool vtp = false;

  HANDLE handle = (HANDLE)_get_osfhandle(out_fd);
  DWORD dwMode;
  if (handle != INVALID_HANDLE_VALUE && GetConsoleMode(handle, &dwMode)) {
    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (SetConsoleMode(handle, dwMode)) {
      vtp = true;
    }
  }

  if (*term == NULL) {
    if (vtp) {
      *term = "vtpcon";
    } else if (conemu_ansi) {
      *term = "conemu";
    } else {
      *term = "win32con";
    }
  }

  if (conemu_ansi) {
    uv_tty_set_vterm_state(UV_TTY_SUPPORTED);
  }
}
#endif
