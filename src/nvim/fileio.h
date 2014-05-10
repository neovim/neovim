#ifndef NVIM_FILEIO_H
#define NVIM_FILEIO_H

#include "nvim/buffer_defs.h"
#include "nvim/os/os.h"

/*
 * Struct to save values in before executing autocommands for a buffer that is
 * not the current buffer.
 */
typedef struct {
  buf_T       *save_curbuf;     /* saved curbuf */
  int use_aucmd_win;            /* using aucmd_win */
  win_T       *save_curwin;     /* saved curwin */
  win_T       *new_curwin;      /* new curwin */
  buf_T       *new_curbuf;      /* new curbuf */
  char_u      *globaldir;       /* saved value of globaldir */
} aco_save_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fileio.h.generated.h"
#endif
#endif  // NVIM_FILEIO_H
