#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/os/input.h"
#include "nvim/os/event.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/term.h"

#define READ_BUFFER_SIZE 256

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

static RStream *read_stream;
static bool eof = false, started_reading = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.c.generated.h"
#endif
// Helper function used to push bytes from the 'event' key sequence partially
// between calls to os_inchar when maxlen < 3

void input_init(void)
{
  read_stream = rstream_new(read_cb, READ_BUFFER_SIZE, NULL, NULL);
  rstream_set_file(read_stream, read_cmd_fd);
}

// Listen for input
void input_start(void)
{
  rstream_start(read_stream);
}

// Stop listening for input
void input_stop(void)
{
  rstream_stop(read_stream);
}

// Copies (at most `count`) of was read from `read_cmd_fd` into `buf`
uint32_t input_read(char *buf, uint32_t count)
{
  return rstream_read(read_stream, buf, count);
}


// Low level input function.
int os_inchar(uint8_t *buf, int maxlen, int32_t ms, int tb_change_cnt)
{
  InbufPollResult result;

  if (event_has_deferred()) {
    // Return pending event bytes
    return push_event_key(buf, maxlen);
  }

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

  // If there are deferred events, return the keys directly
  if (event_has_deferred()) {
    return push_event_key(buf, maxlen);
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
bool os_char_avail(void)
{
  return inbuf_poll(0) == kInputAvail;
}

// Check for CTRL-C typed by reading all available characters.
// In cooked mode we should get SIGINT, no need to check.
void os_breakcheck(void)
{
  if (curr_tmode == TMODE_RAW && input_poll(0))
    fill_input_buf(false);
}

/// Test whether a file descriptor refers to a terminal.
///
/// @param fd File descriptor.
/// @return `true` if file descriptor refers to a terminal.
bool os_isatty(int fd)
{
    return uv_guess_handle(fd) == UV_TTY;
}

static bool input_poll(int32_t ms)
{
  EventSource input_sources[] = {
    rstream_event_source(read_stream),
    NULL
  };

  return input_ready() || event_poll(ms, input_sources) || input_ready();
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int32_t ms)
{
  if (input_available()) {
    return kInputAvail;
  }

  if (input_poll(ms)) {
    return eof && rstream_available(read_stream) == 0 ?
      kInputEof :
      kInputAvail;
  }

  return kInputNone;
}

static void stderr_switch(void)
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
        && os_isatty(STDERR_FILENO)) {
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

static int push_event_key(uint8_t *buf, int maxlen)
{
  static const uint8_t key[3] = { K_SPECIAL, KS_EXTRA, KE_EVENT };
  static int key_idx = 0;
  int buf_idx = 0;

  do {
    buf[buf_idx++] = key[key_idx++];
    key_idx %= 3;
  } while (key_idx > 0 && buf_idx < maxlen);

  return buf_idx;
}

// Check if there's pending input
bool input_ready(void)
{
  return rstream_available(read_stream) > 0 || eof;
}

