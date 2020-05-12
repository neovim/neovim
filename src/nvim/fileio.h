#ifndef NVIM_FILEIO_H
#define NVIM_FILEIO_H

#include "nvim/buffer_defs.h"
#include "nvim/os/os.h"

// Values for readfile() flags
#define READ_NEW        0x01    // read a file into a new buffer
#define READ_FILTER     0x02    // read filter output
#define READ_STDIN      0x04    // read from stdin
#define READ_BUFFER     0x08    // read from curbuf (converting stdin)
#define READ_DUMMY      0x10    // reading into a dummy buffer
#define READ_KEEP_UNDO  0x20    // keep undo info
#define READ_FIFO       0x40    // read from fifo or socket

#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))

/*
 * Struct to save values in before executing autocommands for a buffer that is
 * not the current buffer.
 */
typedef struct {
  buf_T       *save_curbuf;     ///< saved curbuf
  int use_aucmd_win;            ///< using aucmd_win
  win_T       *save_curwin;     ///< saved curwin
  win_T       *save_prevwin;    ///< saved prevwin
  win_T       *new_curwin;      ///< new curwin
  bufref_T     new_curbuf;      ///< new curbuf
  char_u      *globaldir;       ///< saved value of globaldir
} aco_save_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
// Events for autocommands
# include "auevents_enum.generated.h"
# include "fileio.h.generated.h"
#endif
#endif  // NVIM_FILEIO_H
