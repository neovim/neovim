#ifndef NVIM_OS_PTY_CONPTY_WIN_H
#define NVIM_OS_PTY_CONPTY_WIN_H

#ifndef HPCON
# define HPCON VOID *
#endif

extern HRESULT (WINAPI *pCreatePseudoConsole)  // NOLINT(whitespace/parens)
  (COORD, HANDLE, HANDLE, DWORD, HPCON *);
extern HRESULT (WINAPI *pResizePseudoConsole)(HPCON, COORD);
extern void (WINAPI *pClosePseudoConsole)(HPCON);

typedef struct conpty {
  HPCON pty;
  STARTUPINFOEXW si_ex;
} conpty_t;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_conpty_win.h.generated.h"
#endif

#endif  // NVIM_OS_PTY_CONPTY_WIN_H
