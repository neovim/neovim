#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/input.h"
#include "os/event.h"
#include "os/rstream_defs.h"
#include "os/rstream.h"
#include "vim.h"
#include "globals.h"
#include "ui.h"
#include "types.h"
#include "fileio.h"
#include "getchar.h"
#include "term.h"
#include "misc2.h"

#define READ_BUFFER_SIZE 256

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

static RStream *read_stream;
static bool eof = false, started_reading = false;

static InbufPollResult inbuf_poll(int32_t ms);
static void stderr_switch(void);
static void read_cb(RStream *rstream, void *data, bool eof);

void input_init()
{
  read_stream = rstream_new(read_cb, READ_BUFFER_SIZE, NULL);
  rstream_set_file(read_stream, read_cmd_fd);
}

// Check if there's pending input
bool input_ready()
{
  return rstream_available(read_stream) > 0 || eof;
}

// Listen for input
void input_start()
{
  rstream_start(read_stream);
}

// Stop listening for input
void input_stop()
{
  rstream_stop(read_stream);
}

// Copies (at most `count`) of was read from `read_cmd_fd` into `buf`
uint32_t input_read(char *buf, uint32_t count)
{
  return rstream_read(read_stream, buf, count);
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

  // If there are pending events, return the keys directly
  if (maxlen >= 3 && event_is_pending()) {
    buf[0] = K_SPECIAL;
    buf[1] = KS_EXTRA;
    buf[2] = KE_EVENT;
    return 3;
  }

  // If input was put directly in typeahead buffer bail out here.
  if (typebuf_changed(tb_change_cnt)) {
    return 0;
  }

  if (result == kInputEof) {
    read_error_exit();
    return 0;
  }

  return read_from_input_buf(buf, (int64_t)maxlen);
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
    fill_input_buf(false);
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int32_t ms)
{
  if (input_available()) {
    return kInputAvail;
  }

  if (event_poll(ms)) {
    return eof && rstream_available(read_stream) == 0 ?
      kInputEof :
      kInputAvail;
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
  rstream_stop(read_stream);
  // Use stderr for stdin, also works for shell commands.
  read_cmd_fd = 2;
  // Initialize and start the input stream
  rstream_set_file(read_stream, read_cmd_fd);
  rstream_start(read_stream);
  // Set the mode back to what it was
  settmode(mode);
}

static void read_cb(RStream *rstream, void *data, bool at_eof)
{
  if (at_eof) {
    if (!started_reading
        && rstream_is_regular_file(rstream)
        && uv_guess_handle(2) == UV_TTY) {
      // Read error. Since stderr is a tty we switch to reading from it. This
      // is for handling for cases like "foo | xargs vim" because xargs
      // redirects stdin from /dev/null. Previously, this was done in ui.c
      stderr_switch();
    } else {
      eof = true;
    }
  }

  started_reading = true;
}
