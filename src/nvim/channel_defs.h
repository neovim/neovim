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
