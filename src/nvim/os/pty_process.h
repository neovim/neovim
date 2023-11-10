#pragma once

#ifdef MSWIN
# include "nvim/os/pty_process_win.h"
#else
# include "nvim/os/pty_process_unix.h"
#endif
