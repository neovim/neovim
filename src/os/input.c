#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/input.h"
#include "os/event.h"
#include "vim.h"
#include "globals.h"
#include "ui.h"
#include "types.h"
#include "fileio.h"
#include "getchar.h"
#include "term.h"
#include "misc2.h"

#define READ_BUFFER_LENGTH 4096

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

typedef struct {
  uv_buf_t uvbuf;
  uint32_t rpos, wpos, fpos;
  char_u data[READ_BUFFER_LENGTH];
  bool reading;
} ReadBuffer;

static ReadBuffer rbuffer;
static uv_pipe_t read_stream;
// Use an idle handle to make reading from the fs look like a normal libuv
// event
static uv_idle_t fread_idle;
static uv_handle_type read_channel_type;
static bool eof = false;

static InbufPollResult inbuf_poll(int32_t ms);
static void stderr_switch(void);
static void alloc_cb(uv_handle_t *, size_t, uv_buf_t *);
static void read_cb(uv_stream_t *, ssize_t, const uv_buf_t *);
static void fread_idle_cb(uv_idle_t *, int);

void input_init()
{
  rbuffer.wpos = rbuffer.rpos = rbuffer.fpos = 0;
#ifdef DEBUG
  memset(&rbuffer.data, 0, READ_BUFFER_LENGTH);
#endif

  if ((read_channel_type = uv_guess_handle(read_cmd_fd)) == UV_FILE) {
    uv_idle_init(uv_default_loop(), &fread_idle);
  } else {
    uv_pipe_init(uv_default_loop(), &read_stream, 0);
    uv_pipe_open(&read_stream, read_cmd_fd);
  }
}

// Check if there's pending input
bool input_ready()
{
  return rbuffer.rpos < rbuffer.wpos || eof;
}

// Listen for input
void input_start()
{
  // Pin the buffer used by libuv
  rbuffer.uvbuf.len = READ_BUFFER_LENGTH - rbuffer.wpos;
  rbuffer.uvbuf.base = (char *)(rbuffer.data + rbuffer.wpos);

  if (read_channel_type == UV_FILE) {
    // Just invoke the `fread_idle_cb` as soon as the loop starts
    uv_idle_start(&fread_idle, fread_idle_cb);
  } else {
    // Start reading
    rbuffer.reading = false;
    uv_read_start((uv_stream_t *)&read_stream, alloc_cb, read_cb);
  }
}

// Stop listening for input
void input_stop()
{
  if (read_channel_type == UV_FILE) {
    uv_idle_stop(&fread_idle);
  } else {
    uv_read_stop((uv_stream_t *)&read_stream);
  }
}

// Copies (at most `count`) of was read from `read_cmd_fd` into `buf`
uint32_t input_read(char *buf, uint32_t count)
{
  uint32_t read_count = rbuffer.wpos - rbuffer.rpos;

  if (count < read_count) {
    read_count = count;
  }

  if (read_count > 0) {
    memcpy(buf, rbuffer.data + rbuffer.rpos, read_count);
    rbuffer.rpos += read_count;
  }

  if (rbuffer.wpos == READ_BUFFER_LENGTH) {
    // `wpos` is at the end of the buffer, so free some space by moving unread
    // data...
    memmove(
        rbuffer.data,  // ...To the beginning of the buffer(rpos 0)
        rbuffer.data + rbuffer.rpos,  // ...From the first unread position
        rbuffer.wpos - rbuffer.rpos);  // ...By the number of unread bytes
    rbuffer.wpos -= rbuffer.rpos;
    rbuffer.rpos = 0;
  }

  return read_count;
}


// Low level input function.
int os_inchar(char_u *buf, int maxlen, int32_t ms, int tb_change_cnt)
{
  InbufPollResult result;

  if (ms >= 0) {
    if ((result = inbuf_poll(ms)) == kInputNone) {
      return 0;
    }
  } else {
    if ((result = inbuf_poll(p_ut)) == kInputNone) {
      if (trigger_cursorhold() && maxlen >= 3
          && !typebuf_changed(tb_change_cnt)) {
        buf[0] = K_SPECIAL;
        buf[1] = KS_EXTRA;
        buf[2] = KE_CURSORHOLD;
        return 3;
      }

      before_blocking();
      result = inbuf_poll(-1);
    }
  }

  // If input was put directly in typeahead buffer bail out here.
  if (typebuf_changed(tb_change_cnt))
    return 0;

  if (result == kInputEof) {
    read_error_exit();
    return 0;
  }

  return read_from_input_buf(buf, (long)maxlen);
}

// Check if a character is available for reading
bool os_char_avail()
{
  return inbuf_poll(0) == kInputAvail;
}

// Check for CTRL-C typed by reading all available characters.
// In cooked mode we should get SIGINT, no need to check.
void os_breakcheck()
{
  if (curr_tmode == TMODE_RAW && event_poll(0))
    fill_input_buf(FALSE);
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int32_t ms)
{
  if (input_available())
    return kInputAvail;

  if (event_poll(ms)) {
    if (!got_int && rbuffer.rpos == rbuffer.wpos && eof) {
      return kInputEof;
    }

    return kInputAvail;
  }

  return kInputNone;
}

static void stderr_switch()
{
  int mode = cur_tmode;
  // We probably set the wrong file descriptor to raw mode. Switch back to
  // cooked mode
  settmode(TMODE_COOK);
  // Stop the idle handle
  uv_idle_stop(&fread_idle);
  // Use stderr for stdin, also works for shell commands.
  read_cmd_fd = 2;
  // Initialize and start the input stream
  uv_pipe_init(uv_default_loop(), &read_stream, 0);
  uv_pipe_open(&read_stream, read_cmd_fd);
  uv_read_start((uv_stream_t *)&read_stream, alloc_cb, read_cb);
  rbuffer.reading = false;
  // Set the mode back to what it was
  settmode(mode);
}

// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  if (rbuffer.reading) {
    buf->len = 0;
    return;
  }

  buf->base = rbuffer.uvbuf.base;
  buf->len = rbuffer.uvbuf.len;
  // Avoid `alloc_cb`, `alloc_cb` sequences on windows
  rbuffer.reading = true;
}

// Callback invoked by libuv after it copies the data into the buffer provided
// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
// 0-length buffer.
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      // Read error or EOF, either way vim must exit
      eof = true;
    }
    return;
  }

  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rbuffer.wpos += cnt;
}

// Called by the by the 'idle' handle to emulate a reading event
static void fread_idle_cb(uv_idle_t *handle, int status)
{
  uv_fs_t req;

  // Synchronous read
  uv_fs_read(
      uv_default_loop(),
      &req,
      read_cmd_fd,
      &rbuffer.uvbuf,
      1,
      rbuffer.fpos,
      NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    if (rbuffer.fpos == 0 && uv_guess_handle(2) == UV_TTY) {
      // Read error. Since stderr is a tty we switch to reading from it. This
      // is for handling for cases like "foo | xargs vim" because xargs
      // redirects stdin from /dev/null. Previously, this was done in ui.c
      stderr_switch();
    } else {
      eof = true;
    }
    return;
  }

  rbuffer.wpos += req.result;
  rbuffer.fpos += req.result;
}
