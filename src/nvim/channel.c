// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "lauxlib.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/channel.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/socket.h"
#include "nvim/event/wstream.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/rbuffer.h"

#ifdef MSWIN
# include "nvim/os/fs.h"
# include "nvim/os/os_win_console.h"
# include "nvim/os/pty_conpty_win.h"
#endif

static bool did_stdio = false;

/// next free id for a job or rpc channel
/// 1 is reserved for stdio channel
/// 2 is reserved for stderr channel
static uint64_t next_chan_id = CHAN_STDERR + 1;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.c.generated.h"
#endif

/// Teardown the module
void channel_teardown(void)
{
  Channel *channel;

  pmap_foreach_value(&channels, channel, {
    channel_close(channel->id, kChannelPartAll, NULL);
  });
}

/// Closes a channel
///
/// @param id The channel id
/// @return true if successful, false otherwise
bool channel_close(uint64_t id, ChannelPart part, const char **error)
{
  Channel *chan;
  Process *proc;

  const char *dummy;
  if (!error) {
    error = &dummy;
  }

  if (!(chan = find_channel(id))) {
    if (id < next_chan_id) {
      // allow double close, even though we can't say what parts was valid.
      return true;
    }
    *error = e_invchan;
    return false;
  }

  bool close_main = false;
  if (part == kChannelPartRpc || part == kChannelPartAll) {
    close_main = true;
    if (chan->is_rpc) {
      rpc_close(chan);
    } else if (part == kChannelPartRpc) {
      *error = e_invstream;
      return false;
    }
  } else if ((part == kChannelPartStdin || part == kChannelPartStdout)
             && chan->is_rpc) {
    *error = e_invstreamrpc;
    return false;
  }

  switch (chan->streamtype) {
  case kChannelStreamSocket:
    if (!close_main) {
      *error = e_invstream;
      return false;
    }
    stream_may_close(&chan->stream.socket);
    break;

  case kChannelStreamProc:
    proc = &chan->stream.proc;
    if (part == kChannelPartStdin || close_main) {
      stream_may_close(&proc->in);
    }
    if (part == kChannelPartStdout || close_main) {
      stream_may_close(&proc->out);
    }
    if (part == kChannelPartStderr || part == kChannelPartAll) {
      stream_may_close(&proc->err);
    }
    if (proc->type == kProcessTypePty && part == kChannelPartAll) {
      pty_process_close_master(&chan->stream.pty);
    }

    break;

  case kChannelStreamStdio:
    if (part == kChannelPartStdin || close_main) {
      stream_may_close(&chan->stream.stdio.in);
    }
    if (part == kChannelPartStdout || close_main) {
      stream_may_close(&chan->stream.stdio.out);
    }
    if (part == kChannelPartStderr) {
      *error = e_invstream;
      return false;
    }
    break;

  case kChannelStreamStderr:
    if (part != kChannelPartAll && part != kChannelPartStderr) {
      *error = e_invstream;
      return false;
    }
    if (!chan->stream.err.closed) {
      chan->stream.err.closed = true;
      // Don't close on exit, in case late error messages
      if (!exiting) {
        fclose(stderr);
      }
      channel_decref(chan);
    }
    break;

  case kChannelStreamInternal:
    if (!close_main) {
      *error = e_invstream;
      return false;
    }
    if (chan->term) {
      api_free_luaref(chan->stream.internal.cb);
      chan->stream.internal.cb = LUA_NOREF;
      chan->stream.internal.closed = true;
      terminal_close(&chan->term, 0);
    } else {
      channel_decref(chan);
    }
    break;

  default:
    abort();
  }

  return true;
}

/// Initializes the module
void channel_init(void)
{
  channel_alloc(kChannelStreamStderr);
  rpc_init();
}

/// Allocates a channel.
///
/// Channel is allocated with refcount 1, which should be decreased
/// when the underlying stream closes.
Channel *channel_alloc(ChannelStreamType type)
  FUNC_ATTR_NONNULL_RET
{
  Channel *chan = xcalloc(1, sizeof(*chan));
  if (type == kChannelStreamStdio) {
    chan->id = CHAN_STDIO;
  } else if (type == kChannelStreamStderr) {
    chan->id = CHAN_STDERR;
  } else {
    chan->id = next_chan_id++;
  }
  chan->events = multiqueue_new_child(main_loop.events);
  chan->refcount = 1;
  chan->exit_status = -1;
  chan->streamtype = type;
  assert(chan->id <= VARNUMBER_MAX);
  pmap_put(uint64_t)(&channels, chan->id, chan);
  return chan;
}

void channel_create_event(Channel *chan, const char *ext_source)
{
#ifdef NVIM_LOG_DEBUG
  const char *source;

  if (ext_source) {
    // TODO(bfredl): in a future improved traceback solution,
    // external events should be included.
    source = ext_source;
  } else {
    eval_fmt_source_name_line(IObuff, sizeof(IObuff));
    source = IObuff;
  }

  assert(chan->id <= VARNUMBER_MAX);
  Dictionary info = channel_info(chan->id);
  typval_T tv = TV_INITIAL_VALUE;
  // TODO(bfredl): do the conversion in one step. Also would be nice
  // to pretty print top level dict in defined order
  (void)object_to_vim(DICTIONARY_OBJ(info), &tv, NULL);
  char *str = encode_tv2json(&tv, NULL);
  ILOG("new channel %" PRIu64 " (%s) : %s", chan->id, source, str);
  xfree(str);
  api_free_dictionary(info);

#else
  (void)ext_source;
#endif

  channel_info_changed(chan, true);
}

void channel_incref(Channel *chan)
{
  chan->refcount++;
}

void channel_decref(Channel *chan)
{
  if (!(--chan->refcount)) {
    // delay free, so that libuv is done with the handles
    multiqueue_put(main_loop.events, free_channel_event, 1, chan);
  }
}

void callback_reader_free(CallbackReader *reader)
{
  callback_free(&reader->cb);
  ga_clear(&reader->buffer);
}

void callback_reader_start(CallbackReader *reader, const char *type)
{
  ga_init(&reader->buffer, sizeof(char *), 32);
  reader->type = type;
}

static void free_channel_event(void **argv)
{
  Channel *chan = argv[0];
  if (chan->is_rpc) {
    rpc_free(chan);
  }

  if (chan->streamtype == kChannelStreamProc) {
    process_free(&chan->stream.proc);
  }

  callback_reader_free(&chan->on_data);
  callback_reader_free(&chan->on_stderr);
  callback_free(&chan->on_exit);

  pmap_del(uint64_t)(&channels, chan->id, NULL);
  multiqueue_free(chan->events);
  xfree(chan);
}

static void channel_destroy_early(Channel *chan)
{
  if ((chan->id != --next_chan_id)) {
    abort();
  }
  pmap_del(uint64_t)(&channels, chan->id, NULL);
  chan->id = 0;

  if ((--chan->refcount != 0)) {
    abort();
  }

  // uv will keep a reference to handles until next loop tick, so delay free
  multiqueue_put(main_loop.events, free_channel_event, 1, chan);
}

static void close_cb(Stream *stream, void *data)
{
  channel_decref(data);
}

/// Starts a job and returns the associated channel
///
/// @param[in]  argv  Arguments vector specifying the command to run,
///                   NULL-terminated
/// @param[in]  on_stdout  Callback to read the job's stdout
/// @param[in]  on_stderr  Callback to read the job's stderr
/// @param[in]  on_exit  Callback to receive the job's exit status
/// @param[in]  pty  True if the job should run attached to a pty
/// @param[in]  rpc  True to communicate with the job using msgpack-rpc,
///                  `on_stdout` is ignored
/// @param[in]  detach  True if the job should not be killed when nvim exits,
///                     ignored if `pty` is true
/// @param[in]  stdin_mode  Stdin mode. Either kChannelStdinPipe to open a
///                         channel for stdin or kChannelStdinNull to leave
///                         stdin disconnected.
/// @param[in]  cwd  Initial working directory for the job.  Nvim's working
///                  directory if `cwd` is NULL
/// @param[in]  pty_width  Width of the pty, ignored if `pty` is false
/// @param[in]  pty_height  Height of the pty, ignored if `pty` is false
/// @param[in]  env  Nvim's configured environment is used if this is NULL,
///                  otherwise defines all environment variables
/// @param[out]  status_out  0 for invalid arguments, > 0 for the channel id,
///                          < 0 if the job can't start
///
/// @returns [allocated] channel
Channel *channel_job_start(char **argv, CallbackReader on_stdout, CallbackReader on_stderr,
                           Callback on_exit, bool pty, bool rpc, bool overlapped, bool detach,
                           ChannelStdinMode stdin_mode, const char *cwd, uint16_t pty_width,
                           uint16_t pty_height, dict_T *env, varnumber_T *status_out)
{
  Channel *chan = channel_alloc(kChannelStreamProc);
  chan->on_data = on_stdout;
  chan->on_stderr = on_stderr;
  chan->on_exit = on_exit;

  if (pty) {
    if (detach) {
      semsg(_(e_invarg2), "terminal/pty job cannot be detached");
      shell_free_argv(argv);
      if (env) {
        tv_dict_free(env);
      }
      channel_destroy_early(chan);
      *status_out = 0;
      return NULL;
    }
    chan->stream.pty = pty_process_init(&main_loop, chan);
    if (pty_width > 0) {
      chan->stream.pty.width = pty_width;
    }
    if (pty_height > 0) {
      chan->stream.pty.height = pty_height;
    }
  } else {
    chan->stream.uv = libuv_process_init(&main_loop, chan);
  }

  Process *proc = &chan->stream.proc;
  proc->argv = argv;
  proc->cb = channel_process_exit_cb;
  proc->events = chan->events;
  proc->detach = detach;
  proc->cwd = cwd;
  proc->env = env;
  proc->overlapped = overlapped;

  char *cmd = xstrdup(proc->argv[0]);
  bool has_out, has_err;
  if (proc->type == kProcessTypePty) {
    has_out = true;
    has_err = false;
  } else {
    has_out = rpc || callback_reader_set(chan->on_data);
    has_err = callback_reader_set(chan->on_stderr);
    proc->fwd_err = chan->on_stderr.fwd_err;
  }

  bool has_in = stdin_mode == kChannelStdinPipe;

  int status = process_spawn(proc, has_in, has_out, has_err);
  if (status) {
    semsg(_(e_jobspawn), os_strerror(status), cmd);
    xfree(cmd);
    if (proc->env) {
      tv_dict_free(proc->env);
    }
    channel_destroy_early(chan);
    *status_out = proc->status;
    return NULL;
  }
  xfree(cmd);
  if (proc->env) {
    tv_dict_free(proc->env);
  }

  if (has_in) {
    wstream_init(&proc->in, 0);
  }
  if (has_out) {
    rstream_init(&proc->out, 0);
  }

  if (rpc) {
    // the rpc takes over the in and out streams
    rpc_start(chan);
  } else {
    if (has_out) {
      callback_reader_start(&chan->on_data, "stdout");
      rstream_start(&proc->out, on_channel_data, chan);
    }
  }

  if (has_err) {
    callback_reader_start(&chan->on_stderr, "stderr");
    rstream_init(&proc->err, 0);
    rstream_start(&proc->err, on_job_stderr, chan);
  }

  *status_out = (varnumber_T)chan->id;
  return chan;
}

uint64_t channel_connect(bool tcp, const char *address, bool rpc, CallbackReader on_output,
                         int timeout, const char **error)
{
  Channel *channel;

  if (!tcp && rpc) {
    char *path = fix_fname(address);
    bool loopback = server_owns_pipe_address(path);
    xfree(path);
    if (loopback) {
      // Create a loopback channel. This avoids deadlock if nvim connects to
      // its own named pipe.
      channel = channel_alloc(kChannelStreamInternal);
      channel->stream.internal.cb = LUA_NOREF;
      rpc_start(channel);
      goto end;
    }
  }

  channel = channel_alloc(kChannelStreamSocket);
  if (!socket_connect(&main_loop, &channel->stream.socket,
                      tcp, address, timeout, error)) {
    channel_destroy_early(channel);
    return 0;
  }

  channel->stream.socket.internal_close_cb = close_cb;
  channel->stream.socket.internal_data = channel;
  wstream_init(&channel->stream.socket, 0);
  rstream_init(&channel->stream.socket, 0);

  if (rpc) {
    rpc_start(channel);
  } else {
    channel->on_data = on_output;
    callback_reader_start(&channel->on_data, "data");
    rstream_start(&channel->stream.socket, on_channel_data, channel);
  }

end:
  channel_create_event(channel, address);
  return channel->id;
}

/// Creates an RPC channel from a tcp/pipe socket connection
///
/// @param watcher The SocketWatcher ready to accept the connection
void channel_from_connection(SocketWatcher *watcher)
{
  Channel *channel = channel_alloc(kChannelStreamSocket);
  socket_watcher_accept(watcher, &channel->stream.socket);
  channel->stream.socket.internal_close_cb = close_cb;
  channel->stream.socket.internal_data = channel;
  wstream_init(&channel->stream.socket, 0);
  rstream_init(&channel->stream.socket, 0);
  rpc_start(channel);
  channel_create_event(channel, watcher->addr);
}

/// Creates an API channel from stdin/stdout. This is used when embedding
/// Neovim
uint64_t channel_from_stdio(bool rpc, CallbackReader on_output, const char **error)
  FUNC_ATTR_NONNULL_ALL
{
  if (!headless_mode && !embedded_mode) {
    *error = _("can only be opened in headless mode");
    return 0;
  }

  if (did_stdio) {
    *error = _("channel was already open");
    return 0;
  }
  did_stdio = true;

  Channel *channel = channel_alloc(kChannelStreamStdio);

  int stdin_dup_fd = STDIN_FILENO;
  int stdout_dup_fd = STDOUT_FILENO;
#ifdef MSWIN
  // Strangely, ConPTY doesn't work if stdin and stdout are pipes. So replace
  // stdin and stdout with CONIN$ and CONOUT$, respectively.
  if (embedded_mode && os_has_conpty_working()) {
    stdin_dup_fd = os_dup(STDIN_FILENO);
    os_replace_stdin_to_conin();
    stdout_dup_fd = os_dup(STDOUT_FILENO);
    os_replace_stdout_and_stderr_to_conout();
  }
#else
  if (embedded_mode) {
    stdin_dup_fd = dup(STDIN_FILENO);
    stdout_dup_fd = dup(STDOUT_FILENO);
    dup2(STDERR_FILENO, STDOUT_FILENO);
    dup2(STDERR_FILENO, STDIN_FILENO);
  }
#endif
  rstream_init_fd(&main_loop, &channel->stream.stdio.in, stdin_dup_fd, 0);
  wstream_init_fd(&main_loop, &channel->stream.stdio.out, stdout_dup_fd, 0);

  if (rpc) {
    rpc_start(channel);
  } else {
    channel->on_data = on_output;
    callback_reader_start(&channel->on_data, "stdin");
    rstream_start(&channel->stream.stdio.in, on_channel_data, channel);
  }

  return channel->id;
}

/// @param data will be consumed
size_t channel_send(uint64_t id, char *data, size_t len, bool data_owned, const char **error)
  FUNC_ATTR_NONNULL_ALL
{
  Channel *chan = find_channel(id);
  size_t written = 0;
  if (!chan) {
    *error = _(e_invchan);
    goto retfree;
  }

  if (chan->streamtype == kChannelStreamStderr) {
    if (chan->stream.err.closed) {
      *error = _("Can't send data to closed stream");
      goto retfree;
    }
    // unbuffered write
    written = len * fwrite(data, len, 1, stderr);
    goto retfree;
  }

  if (chan->streamtype == kChannelStreamInternal) {
    if (chan->is_rpc) {
      *error = _("Can't send raw data to rpc channel");
      goto retfree;
    }
    if (!chan->term || chan->stream.internal.closed) {
      *error = _("Can't send data to closed stream");
      goto retfree;
    }
    terminal_receive(chan->term, data, len);
    written = len;
    goto retfree;
  }

  Stream *in = channel_instream(chan);
  if (in->closed) {
    *error = _("Can't send data to closed stream");
    goto retfree;
  }

  if (chan->is_rpc) {
    *error = _("Can't send raw data to rpc channel");
    goto retfree;
  }

  // write can be delayed indefinitely, so always use an allocated buffer
  WBuffer *buf = wstream_new_buffer(data_owned ? data : xmemdup(data, len),
                                    len, 1, xfree);
  return wstream_write(in, buf) ? len : 0;

retfree:
  if (data_owned) {
    xfree(data);
  }
  return written;
}

/// Convert binary byte array to a readfile()-style list
///
/// @param[in]  buf  Array to convert.
/// @param[in]  len  Array length.
///
/// @return [allocated] Converted list.
static inline list_T *buffer_to_tv_list(const char *const buf, const size_t len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  list_T *const l = tv_list_alloc(kListLenMayKnow);
  // Empty buffer should be represented by [''], encode_list_write() thinks
  // empty list is fine for the case.
  tv_list_append_string(l, "", 0);
  if (len > 0) {
    encode_list_write(l, buf, len);
  }
  return l;
}

void on_channel_data(Stream *stream, RBuffer *buf, size_t count, void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_data);
}

void on_job_stderr(Stream *stream, RBuffer *buf, size_t count, void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_stderr);
}

static void on_channel_output(Stream *stream, Channel *chan, RBuffer *buf, size_t count, bool eof,
                              CallbackReader *reader)
{
  // stub variable, to keep reading consistent with the order of events, only
  // consider the count parameter.
  size_t r;
  char *ptr = rbuffer_read_ptr(buf, &r);

  if (eof) {
    reader->eof = true;
  } else {
    if (chan->term) {
      terminal_receive(chan->term, ptr, count);
    }

    rbuffer_consumed(buf, count);

    if (callback_reader_set(*reader)) {
      ga_concat_len(&reader->buffer, ptr, count);
    }
  }

  if (callback_reader_set(*reader)) {
    schedule_channel_event(chan);
  }
}

/// schedule the necessary callbacks to be invoked as a deferred event
static void schedule_channel_event(Channel *chan)
{
  if (!chan->callback_scheduled) {
    if (!chan->callback_busy) {
      multiqueue_put(chan->events, on_channel_event, 1, chan);
      channel_incref(chan);
    }
    chan->callback_scheduled = true;
  }
}

static void on_channel_event(void **args)
{
  Channel *chan = (Channel *)args[0];

  chan->callback_busy = true;
  chan->callback_scheduled = false;

  int exit_status = chan->exit_status;
  channel_reader_callbacks(chan, &chan->on_data);
  channel_reader_callbacks(chan, &chan->on_stderr);
  if (exit_status > -1) {
    channel_callback_call(chan, NULL);
    chan->exit_status = -1;
  }

  chan->callback_busy = false;
  if (chan->callback_scheduled) {
    // further callback was deferred to avoid recursion.
    multiqueue_put(chan->events, on_channel_event, 1, chan);
    channel_incref(chan);
  }

  channel_decref(chan);
}

void channel_reader_callbacks(Channel *chan, CallbackReader *reader)
{
  if (reader->buffered) {
    if (reader->eof) {
      if (reader->self) {
        if (tv_dict_find(reader->self, reader->type, -1) == NULL) {
          list_T *data = buffer_to_tv_list(reader->buffer.ga_data,
                                           (size_t)reader->buffer.ga_len);
          tv_dict_add_list(reader->self, reader->type, strlen(reader->type),
                           data);
        } else {
          semsg(_(e_streamkey), reader->type, chan->id);
        }
      } else {
        channel_callback_call(chan, reader);
      }
      reader->eof = false;
    }
  } else {
    bool is_eof = reader->eof;
    if (reader->buffer.ga_len > 0) {
      channel_callback_call(chan, reader);
    }
    // if the stream reached eof, invoke extra callback with no data
    if (is_eof) {
      channel_callback_call(chan, reader);
      reader->eof = false;
    }
  }
}

static void channel_process_exit_cb(Process *proc, int status, void *data)
{
  Channel *chan = data;
  if (chan->term) {
    terminal_close(&chan->term, status);
  }

  // If process did not exit, we only closed the handle of a detached process.
  bool exited = (status >= 0);
  if (exited && chan->on_exit.type != kCallbackNone) {
    schedule_channel_event(chan);
    chan->exit_status = status;
  }

  channel_decref(chan);
}

static void channel_callback_call(Channel *chan, CallbackReader *reader)
{
  Callback *cb;
  typval_T argv[4];

  argv[0].v_type = VAR_NUMBER;
  argv[0].v_lock = VAR_UNLOCKED;
  argv[0].vval.v_number = (varnumber_T)chan->id;

  if (reader) {
    argv[1].v_type = VAR_LIST;
    argv[1].v_lock = VAR_UNLOCKED;
    argv[1].vval.v_list = buffer_to_tv_list(reader->buffer.ga_data,
                                            (size_t)reader->buffer.ga_len);
    tv_list_ref(argv[1].vval.v_list);
    ga_clear(&reader->buffer);
    cb = &reader->cb;
    argv[2].vval.v_string = (char *)reader->type;
  } else {
    argv[1].v_type = VAR_NUMBER;
    argv[1].v_lock = VAR_UNLOCKED;
    argv[1].vval.v_number = chan->exit_status;
    cb = &chan->on_exit;
    argv[2].vval.v_string = "exit";
  }

  argv[2].v_type = VAR_STRING;
  argv[2].v_lock = VAR_UNLOCKED;

  typval_T rettv = TV_INITIAL_VALUE;
  callback_call(cb, 3, argv, &rettv);
  tv_clear(&rettv);
}

/// Open terminal for channel
///
/// Channel `chan` is assumed to be an open pty channel,
/// and `buf` is assumed to be a new, unmodified buffer.
void channel_terminal_open(buf_T *buf, Channel *chan)
{
  TerminalOptions topts;
  topts.data = chan;
  topts.width = chan->stream.pty.width;
  topts.height = chan->stream.pty.height;
  topts.write_cb = term_write;
  topts.resize_cb = term_resize;
  topts.close_cb = term_close;
  buf->b_p_channel = (long)chan->id;  // 'channel' option
  Terminal *term = terminal_open(buf, topts);
  chan->term = term;
  channel_incref(chan);
}

static void term_write(char *buf, size_t size, void *data)
{
  Channel *chan = data;
  if (chan->stream.proc.in.closed) {
    // If the backing stream was closed abruptly, there may be write events
    // ahead of the terminal close event. Just ignore the writes.
    ILOG("write failed: stream is closed");
    return;
  }
  WBuffer *wbuf = wstream_new_buffer(xmemdup(buf, size), size, 1, xfree);
  wstream_write(&chan->stream.proc.in, wbuf);
}

static void term_resize(uint16_t width, uint16_t height, void *data)
{
  Channel *chan = data;
  pty_process_resize(&chan->stream.pty, width, height);
}

static inline void term_delayed_free(void **argv)
{
  Channel *chan = argv[0];
  if (chan->stream.proc.in.pending_reqs || chan->stream.proc.out.pending_reqs) {
    multiqueue_put(chan->events, term_delayed_free, 1, chan);
    return;
  }

  if (chan->term) {
    terminal_destroy(&chan->term);
  }
  channel_decref(chan);
}

static void term_close(void *data)
{
  Channel *chan = data;
  process_stop(&chan->stream.proc);
  multiqueue_put(chan->events, term_delayed_free, 1, data);
}

void channel_info_changed(Channel *chan, bool new_chan)
{
  event_T event = new_chan ? EVENT_CHANOPEN : EVENT_CHANINFO;
  if (has_event(event)) {
    channel_incref(chan);
    multiqueue_put(main_loop.events, set_info_event, 2, chan, event);
  }
}

static void set_info_event(void **argv)
{
  Channel *chan = argv[0];
  event_T event = (event_T)(ptrdiff_t)argv[1];

  save_v_event_T save_v_event;
  dict_T *dict = get_v_event(&save_v_event);
  Dictionary info = channel_info(chan->id);
  typval_T retval;
  (void)object_to_vim(DICTIONARY_OBJ(info), &retval, NULL);
  tv_dict_add_dict(dict, S_LEN("info"), retval.vval.v_dict);
  tv_dict_set_keys_readonly(dict);

  apply_autocmds(event, NULL, NULL, false, curbuf);

  restore_v_event(dict, &save_v_event);
  api_free_dictionary(info);
  channel_decref(chan);
}

bool channel_job_running(uint64_t id)
{
  Channel *chan = find_channel(id);
  return (chan
          && chan->streamtype == kChannelStreamProc
          && !process_is_stopped(&chan->stream.proc));
}

Dictionary channel_info(uint64_t id)
{
  Channel *chan = find_channel(id);
  if (!chan) {
    return (Dictionary)ARRAY_DICT_INIT;
  }

  Dictionary info = ARRAY_DICT_INIT;
  PUT(info, "id", INTEGER_OBJ((Integer)chan->id));

  const char *stream_desc, *mode_desc;
  switch (chan->streamtype) {
  case kChannelStreamProc: {
    stream_desc = "job";
    if (chan->stream.proc.type == kProcessTypePty) {
      const char *name = pty_process_tty_name(&chan->stream.pty);
      PUT(info, "pty", CSTR_TO_OBJ(name));
    }

    char **p = chan->stream.proc.argv;
    Array argv = ARRAY_DICT_INIT;
    if (p != NULL) {
      while (*p != NULL) {
        ADD(argv, CSTR_TO_OBJ(*p));
        p++;
      }
    }
    PUT(info, "argv", ARRAY_OBJ(argv));
    break;
  }

  case kChannelStreamStdio:
    stream_desc = "stdio";
    break;

  case kChannelStreamStderr:
    stream_desc = "stderr";
    break;

  case kChannelStreamInternal:
    PUT(info, "internal", BOOLEAN_OBJ(true));
    FALLTHROUGH;

  case kChannelStreamSocket:
    stream_desc = "socket";
    break;

  default:
    abort();
  }
  PUT(info, "stream", CSTR_TO_OBJ(stream_desc));

  if (chan->is_rpc) {
    mode_desc = "rpc";
    PUT(info, "client", DICTIONARY_OBJ(rpc_client_info(chan)));
  } else if (chan->term) {
    mode_desc = "terminal";
    PUT(info, "buffer", BUFFER_OBJ(terminal_buf(chan->term)));
  } else {
    mode_desc = "bytes";
  }
  PUT(info, "mode", CSTR_TO_OBJ(mode_desc));

  return info;
}

Array channel_all_info(void)
{
  Channel *channel;
  Array ret = ARRAY_DICT_INIT;
  pmap_foreach_value(&channels, channel, {
    ADD(ret, DICTIONARY_OBJ(channel_info(channel->id)));
  });
  return ret;
}
