#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_win_console.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/os_win_console.c.generated.h"
#endif

static char origTitle[256] = { 0 };
static HWND hWnd = NULL;
static HICON hOrigIconSmall = NULL;
static HICON hOrigIcon = NULL;

int os_open_conin_fd(void)
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
  const int conin_fd = os_open_conin_fd();
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

/// Sets Windows console icon, or pass NULL to restore original icon.
void os_icon_set(HICON hIconSmall, HICON hIcon)
{
  if (hWnd == NULL) {
    return;
  }
  hIconSmall = hIconSmall ? hIconSmall : hOrigIconSmall;
  hIcon = hIcon ? hIcon : hOrigIcon;

  if (hIconSmall != NULL) {
    SendMessage(hWnd, WM_SETICON, (WPARAM)ICON_SMALL, (LPARAM)hIconSmall);
  }
  if (hIcon != NULL) {
    SendMessage(hWnd, WM_SETICON, (WPARAM)ICON_BIG, (LPARAM)hIcon);
  }
}

/// Sets Nvim logo as Windows console icon.
///
/// Saves the original icon so it can be restored at exit.
void os_icon_init(void)
{
  if ((hWnd = GetConsoleWindow()) == NULL) {
    return;
  }
  // Save Windows console icon to be restored later.
  hOrigIconSmall = (HICON)SendMessage(hWnd, WM_GETICON, (WPARAM)ICON_SMALL, (LPARAM)0);
  hOrigIcon = (HICON)SendMessage(hWnd, WM_GETICON, (WPARAM)ICON_BIG, (LPARAM)0);

  const char *vimruntime = os_getenv("VIMRUNTIME");
  if (vimruntime != NULL) {
    snprintf(NameBuff, MAXPATHL, "%s" _PATHSEPSTR "neovim.ico", vimruntime);
    if (!os_path_exists(NameBuff)) {
      WLOG("neovim.ico not found: %s", NameBuff);
    } else {
      HICON hVimIcon = LoadImage(NULL, NameBuff, IMAGE_ICON, 64, 64,
                                 LR_LOADFROMFILE | LR_LOADMAP3DCOLORS);
      os_icon_set(hVimIcon, hVimIcon);
    }
  }
}

/// Saves the original Windows console title.
void os_title_save(void)
{
  GetConsoleTitle(origTitle, sizeof(origTitle));
}

/// Resets the original Windows console title.
void os_title_reset(void)
{
  SetConsoleTitle(origTitle);
}
