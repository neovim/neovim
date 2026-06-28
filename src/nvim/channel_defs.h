#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/event/defs.h"

#define CHAN_STDIO 1
#define CHAN_STDERR 2

typedef enum {
  kChannelStreamProc,
  kChannelStreamSocket,
  kChannelStreamStdio,
  kChannelStreamStderr,
  kChannelStreamInternal,
} ChannelStreamType;

typedef enum {
  kChannelPartStdin,
  kChannelPartStdout,
  kChannelPartStderr,
  kChannelPartRpc,
  kChannelPartAll,
} ChannelPart;

typedef enum {
  kChannelStdinPipe,
  kChannelStdinNull,
  /// pty job only: child's stdin (fd 0) is a separate pipe instead of the tty. The pty remains the
  /// controlling terminal (fd 1/2 + /dev/tty), so a program can read piped data on stdin while still
  /// prompting/interacting on the tty (e.g. `:w !sudo tee`). chansend()/chanclose() feed fd 0; typed
  /// keys go to the tty. #40407
  kChannelStdinFd,
} ChannelStdinMode;

typedef struct {
  RStream in;
  Stream out;
} StdioPair;

typedef struct {
  bool closed;
} StderrState;

typedef struct {
  LuaRef cb;
  bool closed;
} InternalState;

typedef struct {
  Callback cb;
  dict_T *self;
  garray_T buffer;
  bool eof;
  bool buffered;
  bool fwd_err;
  const char *type;
} CallbackReader;

#define CALLBACK_READER_INIT ((CallbackReader){ .cb = CALLBACK_NONE, \
                                                .self = NULL, \
                                                .buffer = GA_EMPTY_INIT_VALUE, \
                                                .buffered = false, \
                                                .fwd_err = false, \
                                                .type = NULL })
