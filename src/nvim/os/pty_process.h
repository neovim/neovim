#ifndef NVIM_OS_PTY_PROCESS_H
#define NVIM_OS_PTY_PROCESS_H

#include "nvim/vim.h"

#ifdef FEAT_PTY_PROCESS
# ifdef INCLUDE_GENERATED_DECLARATIONS
#  include "os/pty_process.h.generated.h"
# endif
#else
// Dummy replacement using pipe_process
# include "pipe_process.h"
# define pty_process_init(job) pipe_process_init(job)
# define pty_process_spawn(job) pipe_process_spawn(job)
# define pty_process_destroy(job) pipe_process_destroy(job)
# define pty_process_close(job) pipe_process_close(job)
// FIXME: this is not right
# define pty_process_close_master(job) pipe_process_close(job)
# define pty_process_resize(job, width, height)
#endif
#endif  // NVIM_OS_PTY_PROCESS_H
