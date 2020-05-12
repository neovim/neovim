// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// Terminal/console utils
//

#include "nvim/os/os.h"
#include "nvim/os/tty.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/tty.c.generated.h"
#endif

#ifdef WIN32
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
  bool winpty = (os_getenv("NVIM") != NULL);

  if (winpty) {
    // Force TERM=win32con when running in winpty.
    *term = "win32con";
    uv_set_vterm_state(UV_UNSUPPORTED);
    return;
  }

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
    uv_set_vterm_state(UV_SUPPORTED);
  }
}
#endif
