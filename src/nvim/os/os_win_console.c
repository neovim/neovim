// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/vim.h"
#include "nvim/os/input.h"
#include "nvim/os/os_win_console.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/os_win_console.c.generated.h"
#endif


int os_get_conin_fd(void)
{
  const HANDLE conin_handle = CreateFile("CONIN$",
                                         GENERIC_READ | GENERIC_WRITE,
                                         FILE_SHARE_READ | FILE_SHARE_WRITE,
                                         (LPSECURITY_ATTRIBUTES)NULL,
                                         OPEN_EXISTING, 0, (HANDLE)NULL);
  assert(conin_handle != INVALID_HANDLE_VALUE);
  int conin_fd = _open_osfhandle((intptr_t)conin_handle, _O_RDONLY);
  assert(conin_fd != -1);
  return conin_fd;
}

void os_replace_stdin_to_conin(void)
{
  close(STDIN_FILENO);
  const int conin_fd = os_get_conin_fd();
  assert(conin_fd == STDIN_FILENO);
}

void os_replace_stdout_and_stderr_to_conout(void)
{
  const HANDLE conout_handle =
    CreateFile("CONOUT$",
               GENERIC_READ | GENERIC_WRITE,
               FILE_SHARE_READ | FILE_SHARE_WRITE,
               (LPSECURITY_ATTRIBUTES)NULL,
               OPEN_EXISTING, 0, (HANDLE)NULL);
  assert(conout_handle != INVALID_HANDLE_VALUE);
  close(STDOUT_FILENO);
  const int conout_fd = _open_osfhandle((intptr_t)conout_handle, 0);
  assert(conout_fd == STDOUT_FILENO);
  close(STDERR_FILENO);
  const int conerr_fd = _open_osfhandle((intptr_t)conout_handle, 0);
  assert(conerr_fd == STDERR_FILENO);
}

void os_set_vtp(bool enable)
{
  static TriState is_legacy = kNone;
  if (is_legacy == kNone) {
    uv_tty_vtermstate_t state;
    uv_tty_get_vterm_state(&state);
    is_legacy = (state == UV_TTY_UNSUPPORTED) ? kTrue : kFalse;
  }
  if (!is_legacy && !os_has_vti()) {
    uv_tty_set_vterm_state(enable ? UV_TTY_SUPPORTED : UV_TTY_UNSUPPORTED);
  }
}

static bool os_has_vti(void)
{
  static TriState has_vti = kNone;
  if (has_vti == kNone) {
    HANDLE handle = (HANDLE)_get_osfhandle(input_global_fd());
    DWORD dwMode;
    if (handle != INVALID_HANDLE_VALUE && GetConsoleMode(handle, &dwMode)) {
      has_vti = !!(dwMode & ENABLE_VIRTUAL_TERMINAL_INPUT) ? kTrue : kFalse;
    }
  }
  return has_vti == kTrue;
}
