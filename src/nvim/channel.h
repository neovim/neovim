#ifndef NVIM_CHANNEL_H
#define NVIM_CHANNEL_H

#include "nvim/main.h"
#include "nvim/event/socket.h"
#include "nvim/event/process.h"
#include "nvim/os/pty_process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/eval/typval.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lua/executor.h"
#include "nvim/api/vim.h"

#define CHAN_STDIO 1
#define CHAN_STDERR 2

typedef enum {
  kChannelStreamProc,
  kChannelStreamSocket,
  kChannelStreamStdio,
  kChannelStreamStderr,
  kChannelStreamInternal
} ChannelStreamType;

typedef enum {
  kChannelPartStdin,
  kChannelPartStdout,
  kChannelPartStderr,
  kChannelPartRpc,
  kChannelPartAll
} ChannelPart;


typedef struct {
  Stream in;
  Stream out;
} StdioPair;

typedef struct {
  bool closed;
} StderrState;

typedef struct {
  Callback cb;
  dict_T *self;
  garray_T buffer;
  bool eof;
  bool buffered;
  const char *type;
} CallbackReader;

#define CALLBACK_READER_INIT ((CallbackReader){ .cb = CALLBACK_NONE, \
                                                .self = NULL, \
                                                .buffer = GA_EMPTY_INIT_VALUE, \
                                                .buffered = false, \
                                                .type = NULL })
static inline bool callback_reader_set(CallbackReader reader)
{
  return reader.cb.type != kCallbackNone || reader.self;
}

typedef struct {
  Callback callback;

  // parallel call
  Callback item_callback;    ///< per-item callback
  int count;                 ///< number of workers
  list_T *work_queue;        ///< argument lists to consume
  int next;                  ///< next list to consume from "work_queue"
  Array results;             ///< accumulated results
  char_u *callee;            ///< called function
} AsyncCall;

struct Channel {
  uint64_t id;
  size_t refcount;
  MultiQueue *events;

  ChannelStreamType streamtype;
  union {
    Process proc;
    LibuvProcess uv;
    PtyProcess pty;
    Stream socket;
    StdioPair stdio;
    StderrState err;
  } stream;

  bool is_rpc;
  RpcState rpc;
  Terminal *term;
  AsyncCall *async_call;

  CallbackReader on_data;
  CallbackReader on_stderr;
  Callback on_exit;
  int exit_status;

  bool callback_busy;
  bool callback_scheduled;
};

EXTERN PMap(uint64_t) *channels;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.h.generated.h"
#endif

/// @returns Channel with the id or NULL if not found
static inline Channel *find_channel(uint64_t id)
{
  return pmap_get(uint64_t)(channels, id);
}

static inline Stream *channel_instream(Channel *chan)
  FUNC_ATTR_NONNULL_ALL
{
  switch (chan->streamtype) {
    case kChannelStreamProc:
      return &chan->stream.proc.in;

    case kChannelStreamSocket:
      return &chan->stream.socket;

    case kChannelStreamStdio:
      return &chan->stream.stdio.out;

    case kChannelStreamInternal:
    case kChannelStreamStderr:
      abort();
  }
  abort();
}

static inline Stream *channel_outstream(Channel *chan)
  FUNC_ATTR_NONNULL_ALL
{
  switch (chan->streamtype) {
    case kChannelStreamProc:
      return &chan->stream.proc.out;

    case kChannelStreamSocket:
      return &chan->stream.socket;

    case kChannelStreamStdio:
      return &chan->stream.stdio.in;

    case kChannelStreamInternal:
    case kChannelStreamStderr:
      abort();
  }
  abort();
}

static inline Channel *asynccall_channel_acquire(void)
{
  Error err = ERROR_INIT;
  Object jobid = EXEC_LUA_STATIC("return vim._create_nvim_job()",
                                 (Array)ARRAY_DICT_INIT, &err);

  if (ERROR_SET(&err)) {
    api_free_object(jobid);
    api_clear_error(&err);
    return NULL;
  }

  return find_channel((uint64_t)jobid.data.integer);
}

static inline void asynccall_channel_release(Channel *channel)
{
  process_stop((Process *)&channel->stream.proc);
}

bool callback_call(Callback *const, const int,
                   typval_T *const, typval_T *const);

static inline void asynccall_callback_call(
    Callback *cb, Object *result, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T argv[2] = { TV_INITIAL_VALUE, TV_INITIAL_VALUE };
  if (object_to_vim(*result, &argv[0], err)) {
    typval_T rettv = TV_INITIAL_VALUE;
    callback_call(cb, 1, argv, &rettv);
    tv_clear(&rettv);
    tv_clear(&argv[0]);
  }
}

static inline void asynccall_put_result(
    uint64_t job, Object result, Error *err)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ((long)job));
  ADD(args, result);
  EXEC_LUA_STATIC("vim._put_result(...)", args, err);
  xfree(args.items);
}

static inline void asynccall_append_result(
    uint64_t job, Object result, Error *err)
{
  Array args = ARRAY_DICT_INIT;
  ADD(args, INTEGER_OBJ((long)job));
  ADD(args, result);
  EXEC_LUA_STATIC("vim._append_result(...)", args, err);
  xfree(args.items);
}


#endif  // NVIM_CHANNEL_H
