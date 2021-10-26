// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/os/input.h"
#include "nvim/os/os_win_console.h"
#include "nvim/vim.h"

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
