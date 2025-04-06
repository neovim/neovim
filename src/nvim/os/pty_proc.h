#pragma once

#ifdef MSWIN
# include "nvim/os/pty_proc_win.h"
#else
# include "nvim/os/pty_proc_unix.h"
#endif
