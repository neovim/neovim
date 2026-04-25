#pragma once

#include <stdint.h>  // IWYU pragma: keep
#include <stdio.h>  // IWYU pragma: keep
#include <time.h>  // IWYU pragma: keep

#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/os/fs_defs.h"  // IWYU pragma: keep
#include "nvim/os/os_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Values for readfile() flags
enum {
  READ_NEW        = 0x01,   ///< read a file into a new buffer
  READ_FILTER     = 0x02,   ///< read filter output
  READ_STDIN      = 0x04,   ///< read from stdin
  READ_BUFFER     = 0x08,   ///< read from curbuf (converting stdin)
  READ_DUMMY      = 0x10,   ///< reading into a dummy buffer
  READ_KEEP_UNDO  = 0x20,   ///< keep undo info
  READ_FIFO       = 0x40,   ///< read from fifo or socket
  READ_NOWINENTER = 0x80,   ///< do not trigger BufWinEnter
  READ_NOFILE     = 0x100,  ///< do not read a file, do trigger BufReadCmd
};

typedef varnumber_T (*CheckItem)(void *expr, const char *name);

enum {
  FIO_LATIN1 = 0x01,       ///< convert Latin1
  FIO_UTF8 = 0x02,         ///< convert UTF-8
  FIO_UCS2 = 0x04,         ///< convert UCS-2
  FIO_UCS4 = 0x08,         ///< convert UCS-4
  FIO_UTF16 = 0x10,        ///< convert UTF-16
  FIO_ENDIAN_L = 0x80,     ///< little endian
  FIO_NOCONVERT = 0x2000,  ///< skip encoding conversion
  FIO_UCSBOM = 0x4000,     ///< check for BOM at start of file
  FIO_ALL = -1,            ///< allow all formats
};

enum {
  /// When converting, a read() or write() may leave some bytes to be converted
  /// for the next call.  The value is guessed...
  CONV_RESTLEN = 30,
};

enum { WRITEBUFSIZE = 8192, };  ///< size of normal write buffer

enum {
  /// We have to guess how much a sequence of bytes may expand when converting
  /// with iconv() to be able to allocate a buffer.
  ICONV_MULT = 8,
};

#include "fileio.h.generated.h"
