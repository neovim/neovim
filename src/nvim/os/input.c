#include <assert.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/os/input.h"
#include "nvim/os/event.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/memory.h"
#include "nvim/keymap.h"
#include "nvim/mbyte.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/term.h"

#define READ_BUFFER_SIZE 0xfff
#define INPUT_BUFFER_SIZE (READ_BUFFER_SIZE * 4)

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

static RStream *read_stream;
static RBuffer *read_buffer, *input_buffer;
static bool eof = false, started_reading = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.c.generated.h"
#endif
// Helper function used to push bytes from the 'event' key sequence partially
// between calls to os_inchar when maxlen < 3

void input_init(void)
{
  input_buffer = rbuffer_new(INPUT_BUFFER_SIZE + MAX_KEY_CODE_LEN);

  if (embedded_mode) {
    return;
  }

  read_buffer = rbuffer_new(READ_BUFFER_SIZE);
  read_stream = rstream_new(read_cb, read_buffer, NULL);
  rstream_set_file(read_stream, read_cmd_fd);
}

void input_teardown(void)
{
  if (embedded_mode) {
    return;
  }

  rstream_free(read_stream);
}

// Listen for input
void input_start(void)
{
  if (embedded_mode) {
    return;
  }

  rstream_start(read_stream);
}

// Stop listening for input
void input_stop(void)
{
  if (embedded_mode) {
    return;
  }

  rstream_stop(read_stream);
}

// Low level input function.
int os_inchar(uint8_t *buf, int maxlen, int ms, int tb_change_cnt)
{
  InbufPollResult result;

  if (ms >= 0) {
    if ((result = inbuf_poll(ms)) == kInputNone) {
      return 0;
    }
  } else {
    if ((result = inbuf_poll((int)p_ut)) == kInputNone) {
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
  if (typebuf_changed(tb_change_cnt)) {
    return 0;
  }

  if (result == kInputEof) {
    read_error_exit();
    return 0;
  }

  // Safe to convert rbuffer_read to int, it will never overflow since
  // we use relatively small buffers.
  return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
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
  if (curr_tmode == TMODE_RAW)
    input_poll(0);
}

/// Test whether a file descriptor refers to a terminal.
///
/// @param fd File descriptor.
/// @return `true` if file descriptor refers to a terminal.
bool os_isatty(int fd)
{
    return uv_guess_handle(fd) == UV_TTY;
}

/// Return the contents of the input buffer and make it empty. The returned
/// pointer must be passed to `input_buffer_restore()` later.
String input_buffer_save(void)
{
  size_t inbuf_size = rbuffer_pending(input_buffer);
  String rv = {
    .data = xmemdup(rbuffer_read_ptr(input_buffer), inbuf_size),
    .size = inbuf_size
  };
  rbuffer_consumed(input_buffer, inbuf_size);
  return rv;
}

/// Restore the contents of the input buffer and free `str`
void input_buffer_restore(String str)
{
  rbuffer_consumed(input_buffer, rbuffer_pending(input_buffer));
  rbuffer_write(input_buffer, str.data, str.size);
  free(str.data);
}

size_t input_enqueue(String keys)
{
  size_t rv = rbuffer_write(input_buffer, keys.data, keys.size);
  process_interrupts();
  return rv;
}

static bool input_poll(int ms)
{
  event_poll_until(ms, input_ready());
  return input_ready();
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int ms)
{
  if (typebuf_was_filled || rbuffer_pending(input_buffer)) {
    return kInputAvail;
  }

  if (input_poll(ms)) {
    return eof && rstream_pending(read_stream) == 0 ?
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

  convert_input();
  process_interrupts();
  started_reading = true;
}

static void convert_input(void)
{
  if (embedded_mode || !rbuffer_available(input_buffer)) {
    // No input buffer space
    return;
  }

  bool convert = input_conv.vc_type != CONV_NONE;
  // Set unconverted data/length
  char *data = rbuffer_read_ptr(read_buffer);
  size_t data_length = rbuffer_pending(read_buffer);
  size_t converted_length = data_length;

  if (convert) {
    // Perform input conversion according to `input_conv`
    size_t unconverted_length = 0;
    data = (char *)string_convert_ext(&input_conv,
                                      (uint8_t *)data,
                                      (int *)&converted_length,
                                      (int *)&unconverted_length);
    data_length -= unconverted_length;
  }

  // The conversion code will be gone eventually, for now assume `input_buffer`
  // always has space for the converted data(it's many times the size of
  // `read_buffer`, so it's hard to imagine a scenario where the converted data
  // doesn't fit)
  assert(converted_length <= rbuffer_available(input_buffer));
  // Write processed data to input buffer.
  (void)rbuffer_write(input_buffer, data, converted_length);
  // Adjust raw buffer pointers
  rbuffer_consumed(read_buffer, data_length);

  if (convert) {
    // data points to memory allocated by `string_convert_ext`, free it.
    free(data);
  }
}

static void process_interrupts(void)
{
  if (!ctrl_c_interrupts) {
    return;
  }

  char *inbuf = rbuffer_read_ptr(input_buffer);
  size_t count = rbuffer_pending(input_buffer), consume_count = 0;

  for (int i = (int)count - 1; i >= 0; i--) {
    if (inbuf[i] == 3) {
      got_int = true;
      consume_count = (size_t)i;
      break;
    }
  }

  if (got_int) {
    // Remove everything typed before the CTRL-C
    rbuffer_consumed(input_buffer, consume_count);
  }
}

// Check if there's pending input
static bool input_ready(void)
{
  event_process();

  return typebuf_was_filled ||                    // API call filled typeahead
         (!embedded_mode && (
            rbuffer_pending(input_buffer) > 0 ||  // Stdin input
            eof));                                // Stdin closed
}

