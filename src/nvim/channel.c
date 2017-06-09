// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/api/ui.h"
#include "nvim/channel.h"
#include "nvim/eval.h"
#include "nvim/event/socket.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/ascii.h"

static bool did_stdio = false;
PMap(uint64_t) *channels = NULL;

/// next free id for a job or rpc channel
/// 1 is reserved for stdio channel
/// 2 is reserved for stderr channel
static uint64_t next_chan_id = CHAN_STDERR+1;


typedef struct {
  Channel *data;
  Callback *callback;
  const char *type;
  list_T *received;
  int status;
} ChannelEvent;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.c.generated.h"
#endif
/// Teardown the module
void channel_teardown(void)
{
  if (!channels) {
    return;
  }

  Channel *channel;

  map_foreach_value(channels, channel, {
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
    *error = (const char *)e_invchan;
    return false;
  }

  bool close_main = false;
  if (part == kChannelPartRpc || part == kChannelPartAll) {
    close_main = true;
    if (chan->is_rpc) {
       rpc_close(chan);
    } else if (part == kChannelPartRpc) {
      *error = (const char *)e_invstream;
      return false;
    }
  } else if ((part == kChannelPartStdin || part == kChannelPartStdout)
             && chan->is_rpc) {
    *error = (const char *)e_invstreamrpc;
    return false;
  }

  switch (chan->streamtype) {
    case kChannelStreamSocket:
      if (!close_main) {
        *error = (const char *)e_invstream;
        return false;
      }
      stream_may_close(&chan->stream.socket);
      break;

    case kChannelStreamProc:
      proc = (Process *)&chan->stream.proc;
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
        *error = (const char *)e_invstream;
        return false;
      }
      break;

    case kChannelStreamStderr:
      if (part != kChannelPartAll && part != kChannelPartStderr) {
        *error = (const char *)e_invstream;
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
        *error = (const char *)e_invstream;
        return false;
      }
      break;
  }

  return true;
}

/// Initializes the module
void channel_init(void)
{
  channels = pmap_new(uint64_t)();
  channel_alloc(kChannelStreamStderr);
  rpc_init();
  remote_ui_init();
}

/// Allocates a channel.
///
/// Channel is allocated with refcount 1, which should be decreased
/// when the underlying stream closes.
static Channel *channel_alloc(ChannelStreamType type)
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
  chan->streamtype = type;
  pmap_put(uint64_t)(channels, chan->id, chan);
  return chan;
}

void channel_incref(Channel *channel)
{
  channel->refcount++;
}

void channel_decref(Channel *channel)
{
  if (!(--channel->refcount)) {
    multiqueue_put(main_loop.fast_events, free_channel_event, 1, channel);
  }
}

void callback_reader_free(CallbackReader *reader)
{
  callback_free(&reader->cb);
  if (reader->buffered) {
    ga_clear(&reader->buffer);
  }
}

void callback_reader_start(CallbackReader *reader)
{
  if (reader->buffered) {
    ga_init(&reader->buffer, sizeof(char *), 1);
  }
}

static void free_channel_event(void **argv)
{
  Channel *channel = argv[0];
  if (channel->is_rpc) {
    rpc_free(channel);
  }

  callback_reader_free(&channel->on_stdout);
  callback_reader_free(&channel->on_stderr);
  callback_free(&channel->on_exit);

  pmap_del(uint64_t)(channels, channel->id);
  multiqueue_free(channel->events);
  xfree(channel);
}

static void channel_destroy_early(Channel *chan)
{
  if ((chan->id != --next_chan_id)) {
    abort();
  }

  if ((--chan->refcount != 0)) {
    abort();
  }

  free_channel_event((void **)&chan);
}


static void close_cb(Stream *stream, void *data)
{
  channel_decref(data);
}

Channel *channel_job_start(char **argv, CallbackReader on_stdout,
                           CallbackReader on_stderr, Callback on_exit,
                           bool pty, bool rpc, bool detach, const char *cwd,
                           uint16_t pty_width, uint16_t pty_height,
                           char *term_name, varnumber_T *status_out)
{
  Channel *chan = channel_alloc(kChannelStreamProc);
  chan->on_stdout = on_stdout;
  chan->on_stderr = on_stderr;
  chan->on_exit = on_exit;
  chan->is_rpc = rpc;

  if (pty) {
    if (detach) {
      EMSG2(_(e_invarg2), "terminal/pty job cannot be detached");
      shell_free_argv(argv);
      xfree(term_name);
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
    if (term_name) {
      chan->stream.pty.term_name = term_name;
    }
  } else {
    chan->stream.uv = libuv_process_init(&main_loop, chan);
  }

  Process *proc = (Process *)&chan->stream.proc;
  proc->argv = argv;
  proc->cb = channel_process_exit_cb;
  proc->events = chan->events;
  proc->detach = detach;
  proc->cwd = cwd;

  char *cmd = xstrdup(proc->argv[0]);
  bool has_out, has_err;
  if (proc->type == kProcessTypePty) {
    has_out = true;
    has_err = false;
  } else {
    has_out = chan->is_rpc || callback_reader_set(chan->on_stdout);
    has_err = callback_reader_set(chan->on_stderr);
  }
  int status = process_spawn(proc, true, has_out, has_err);
  if (has_err) {
    proc->err.events = chan->events;
  }
  if (status) {
    EMSG3(_(e_jobspawn), os_strerror(status), cmd);
    xfree(cmd);
    if (proc->type == kProcessTypePty) {
      xfree(chan->stream.pty.term_name);
    }
    channel_destroy_early(chan);
    *status_out = proc->status;
    return NULL;
  }
  xfree(cmd);

  wstream_init(&proc->in, 0);
  if (has_out) {
    rstream_init(&proc->out, 0);
  }

  if (chan->is_rpc) {
    // the rpc takes over the in and out streams
    rpc_start(chan);
  } else {
    proc->in.events = chan->events;
    if (has_out) {
      callback_reader_start(&chan->on_stdout);
      proc->out.events = chan->events;
      rstream_start(&proc->out, on_job_stdout, chan);
    }
  }

  if (has_err) {
    callback_reader_start(&chan->on_stderr);
    rstream_init(&proc->err, 0);
    rstream_start(&proc->err, on_job_stderr, chan);
  }
  *status_out = (varnumber_T)chan->id;
  return chan;
}


uint64_t channel_connect(bool tcp, const char *address,
                         bool rpc, CallbackReader on_output,
                         int timeout, const char **error)
{
  if (!tcp && rpc) {
    char *path = fix_fname(address);
    if (server_owns_pipe_address(path)) {
      // avoid deadlock
      xfree(path);
      return channel_create_internal_rpc();
    }
    xfree(path);
  }

  Channel *channel = channel_alloc(kChannelStreamSocket);
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
    channel->on_stdout = on_output;
    callback_reader_start(&channel->on_stdout);
    channel->stream.socket.events = channel->events;
    rstream_start(&channel->stream.socket, on_socket_output, channel);
  }

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
}

/// Creates a loopback channel. This is used to avoid deadlock
/// when an instance connects to its own named pipe.
static uint64_t channel_create_internal_rpc(void)
{
  Channel *channel = channel_alloc(kChannelStreamInternal);
  rpc_start(channel);
  return channel->id;
}

/// Creates an API channel from stdin/stdout. This is used when embedding
/// Neovim
uint64_t channel_from_stdio(bool rpc, CallbackReader on_output,
                            const char **error)
  FUNC_ATTR_NONNULL_ALL
{
  if (!headless_mode) {
    *error = _("can only be opened in headless mode");
    return 0;
  }

  if (did_stdio) {
    *error = _("channel was already open");
    return 0;
  }
  did_stdio = true;

  Channel *channel = channel_alloc(kChannelStreamStdio);

  rstream_init_fd(&main_loop, &channel->stream.stdio.in, 0, 0);
  wstream_init_fd(&main_loop, &channel->stream.stdio.out, 1, 0);

  if (rpc) {
    rpc_start(channel);
  } else {
    channel->on_stdout = on_output;
    callback_reader_start(&channel->on_stdout);
    channel->stream.stdio.in.events = channel->events;
    channel->stream.stdio.out.events = channel->events;
    rstream_start(&channel->stream.stdio.in, on_stdio_input, channel);
  }

  return channel->id;
}

/// @param data will be consumed
size_t channel_send(uint64_t id, char *data, size_t len, const char **error)
{
  Channel *chan = find_channel(id);
  if (!chan) {
    EMSG(_(e_invchan));
    goto err;
  }

  if (chan->streamtype == kChannelStreamStderr) {
    if (chan->stream.err.closed) {
      *error = _("Can't send data to closed stream");
      goto err;
    }
    // unbuffered write
    size_t written = fwrite(data, len, 1, stderr);
    xfree(data);
    return len * written;
  }


  Stream *in = channel_instream(chan);
  if (in->closed) {
    *error = _("Can't send data to closed stream");
    goto err;
  }

  if (chan->is_rpc) {
    *error = _("Can't send raw data to rpc channel");
    goto err;
  }

  WBuffer *buf = wstream_new_buffer(data, len, 1, xfree);
  return wstream_write(in, buf) ? len : 0;

err:
  xfree(data);
  return 0;
}

// vimscript job callbacks must be executed on Nvim main loop
static inline void process_channel_event(Channel *chan, Callback *callback,
                                         const char *type, char *buf,
                                         size_t count, int status)
{
  ChannelEvent event_data;
  event_data.received = NULL;
  if (buf) {
    event_data.received = tv_list_alloc();
    char *ptr = buf;
    size_t remaining = count;
    size_t off = 0;

    while (off < remaining) {
      // append the line
      if (ptr[off] == NL) {
        tv_list_append_string(event_data.received, ptr, (ssize_t)off);
        size_t skip = off + 1;
        ptr += skip;
        remaining -= skip;
        off = 0;
        continue;
      }
      if (ptr[off] == NUL) {
        // Translate NUL to NL
        ptr[off] = NL;
      }
      off++;
    }
    tv_list_append_string(event_data.received, ptr, (ssize_t)off);
  } else {
    event_data.status = status;
  }
  event_data.data = chan;
  event_data.callback = callback;
  event_data.type = type;
  on_channel_event(&event_data);
}

void on_job_stdout(Stream *stream, RBuffer *buf, size_t count,
                   void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_stdout, "stdout");
}

void on_job_stderr(Stream *stream, RBuffer *buf, size_t count,
                   void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_stderr, "stderr");
}

static void on_socket_output(Stream *stream, RBuffer *buf, size_t count,
                             void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_stdout, "data");
}

static void on_stdio_input(Stream *stream, RBuffer *buf, size_t count,
                           void *data, bool eof)
{
  Channel *chan = data;
  on_channel_output(stream, chan, buf, count, eof, &chan->on_stdout, "stdin");
}

static void on_channel_output(Stream *stream, Channel *chan, RBuffer *buf,
                              size_t count, bool eof, CallbackReader *reader,
                              const char *type)
{
  // stub variable, to keep reading consistent with the order of events, only
  // consider the count parameter.
  size_t r;
  char *ptr = rbuffer_read_ptr(buf, &r);

  if (eof) {
    if (reader->buffered) {
      process_channel_event(chan, &reader->cb, type, reader->buffer.ga_data,
                        (size_t)reader->buffer.ga_len, 0);
      ga_clear(&reader->buffer);
    } else if (callback_reader_set(*reader)) {
      process_channel_event(chan, &reader->cb, type, ptr, 0, 0);
    }
    return;
  }

  // The order here matters, the terminal must receive the data first because
  // process_channel_event will modify the read buffer(convert NULs into NLs)
  if (chan->term) {
    terminal_receive(chan->term, ptr, count);
  }

  rbuffer_consumed(buf, count);
  if (reader->buffered) {
    ga_concat_len(&reader->buffer, ptr, count);
  } else if (callback_reader_set(*reader)) {
    process_channel_event(chan, &reader->cb, type, ptr, count, 0);
  }
}

static void channel_process_exit_cb(Process *proc, int status, void *data)
{
  Channel *chan = data;
  if (chan->term) {
    char msg[sizeof("\r\n[Process exited ]") + NUMBUFLEN];
    snprintf(msg, sizeof msg, "\r\n[Process exited %d]", proc->status);
    terminal_close(chan->term, msg);
  }

  if (chan->status_ptr) {
    *chan->status_ptr = status;
  }

  process_channel_event(chan, &chan->on_exit, "exit", NULL, 0, status);

  channel_decref(chan);
}

static void on_channel_event(ChannelEvent *ev)
{
  if (!ev->callback) {
    return;
  }

  typval_T argv[4];

  argv[0].v_type = VAR_NUMBER;
  argv[0].v_lock = VAR_UNLOCKED;
  argv[0].vval.v_number = (varnumber_T)ev->data->id;

  if (ev->received) {
    argv[1].v_type = VAR_LIST;
    argv[1].v_lock = VAR_UNLOCKED;
    argv[1].vval.v_list = ev->received;
    argv[1].vval.v_list->lv_refcount++;
  } else {
    argv[1].v_type = VAR_NUMBER;
    argv[1].v_lock = VAR_UNLOCKED;
    argv[1].vval.v_number = ev->status;
  }

  argv[2].v_type = VAR_STRING;
  argv[2].v_lock = VAR_UNLOCKED;
  argv[2].vval.v_string = (uint8_t *)ev->type;

  typval_T rettv = TV_INITIAL_VALUE;
  callback_call(ev->callback, 3, argv, &rettv);
  tv_clear(&rettv);
}


/// Open terminal for channel
///
/// Channel `chan` is assumed to be an open pty channel,
/// and curbuf is assumed to be a new, unmodified buffer.
void channel_terminal_open(Channel *chan)
{
  TerminalOptions topts;
  topts.data = chan;
  topts.width = chan->stream.pty.width;
  topts.height = chan->stream.pty.height;
  topts.write_cb = term_write;
  topts.resize_cb = term_resize;
  topts.close_cb = term_close;
  curbuf->b_p_channel = (long)chan->id;  // 'channel' option
  Terminal *term = terminal_open(topts);
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

  terminal_destroy(chan->term);
  chan->term = NULL;
  channel_decref(chan);
}

static void term_close(void *data)
{
  Channel *chan = data;
  process_stop(&chan->stream.proc);
  multiqueue_put(chan->events, term_delayed_free, 1, data);
}

