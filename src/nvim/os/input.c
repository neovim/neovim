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
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/memory.h"
#include "nvim/keymap.h"
#include "nvim/mbyte.h"
#include "nvim/fileio.h"
#include "nvim/ex_cmds2.h"
#include "nvim/getchar.h"
#include "nvim/main.h"
#include "nvim/misc1.h"

#define READ_BUFFER_SIZE 0xfff
#define INPUT_BUFFER_SIZE (READ_BUFFER_SIZE * 4)

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

static RStream *read_stream = NULL;
static RBuffer *read_buffer = NULL, *input_buffer = NULL;
static bool eof = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.c.generated.h"
#endif
// Helper function used to push bytes from the 'event' key sequence partially
// between calls to os_inchar when maxlen < 3

void input_init(void)
{
  input_buffer = rbuffer_new(INPUT_BUFFER_SIZE + MAX_KEY_CODE_LEN);
}

void input_start_stdin(void)
{
  if (read_stream) {
    return;
  }

  read_buffer = rbuffer_new(READ_BUFFER_SIZE);
  read_stream = rstream_new(read_cb, read_buffer, NULL);
  rstream_set_file(read_stream, fileno(stdin));
  rstream_start(read_stream);
}

void input_stop_stdin(void)
{
  if (!read_stream) {
    return;
  }

  rstream_stop(read_stream);
  rstream_free(read_stream);
  read_stream = NULL;
}

// Low level input function.
int os_inchar(uint8_t *buf, int maxlen, int ms, int tb_change_cnt)
{
  if (rbuffer_pending(input_buffer)) {
    return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
  }

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

  if (rbuffer_pending(input_buffer)) {
    // Safe to convert rbuffer_read to int, it will never overflow since we use
    // relatively small buffers.
    return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
  }

  // If there are deferred events, return the keys directly
  if (event_has_deferred()) {
    return push_event_key(buf, maxlen);
  }

  if (result == kInputEof) {
    read_error_exit();
  }

  return 0;
}

// Check if a character is available for reading
bool os_char_avail(void)
{
  return inbuf_poll(0) == kInputAvail;
}

// Check for CTRL-C typed by reading all available characters.
void os_breakcheck(void)
{
  event_poll(0);
}

/// Test whether a file descriptor refers to a terminal.
///
/// @param fd File descriptor.
/// @return `true` if file descriptor refers to a terminal.
bool os_isatty(int fd)
{
    return uv_guess_handle(fd) == UV_TTY;
}

size_t input_enqueue(String keys)
{
  char *ptr = keys.data, *end = ptr + keys.size;

  while (rbuffer_available(input_buffer) >= 6 && ptr < end) {
    uint8_t buf[6] = {0};
    unsigned int new_size = trans_special((uint8_t **)&ptr, buf, true);

    if (new_size) {
      new_size = handle_mouse_event(&ptr, buf, new_size);
      rbuffer_write(input_buffer, (char *)buf, new_size);
      continue;
    }

    if (*ptr == '<') {
      // Invalid key sequence, skip until the next '>' or until *end
      do {
        ptr++;
      } while (ptr < end && *ptr != '>');
      ptr++;
      continue;
    }

    // copy the character, escaping CSI and K_SPECIAL
    if ((uint8_t)*ptr == CSI) {
      rbuffer_write(input_buffer, (char *)&(uint8_t){K_SPECIAL}, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){KS_EXTRA}, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){KE_CSI}, 1);
    } else if ((uint8_t)*ptr == K_SPECIAL) {
      rbuffer_write(input_buffer, (char *)&(uint8_t){K_SPECIAL}, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){KS_SPECIAL}, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){KE_FILLER}, 1);
    } else {
      rbuffer_write(input_buffer, ptr, 1);
    }
    ptr++;
  }

  size_t rv = (size_t)(ptr - keys.data);
  process_interrupts();
  return rv;
}

// Mouse event handling code(Extract row/col if available and detect multiple
// clicks)
static unsigned int handle_mouse_event(char **ptr, uint8_t *buf,
                                       unsigned int bufsize)
{
  int mouse_code = 0;
  int type = 0;

  if (bufsize == 3) {
    mouse_code = buf[2];
    type = buf[1];
  } else if (bufsize == 6) {
    // prefixed with K_SPECIAL KS_MODIFIER mod
    mouse_code = buf[5];
    type = buf[4];
  }

  if (type != KS_EXTRA
      || !((mouse_code >= KE_LEFTMOUSE && mouse_code <= KE_RIGHTRELEASE)
        || (mouse_code >= KE_MOUSEDOWN && mouse_code <= KE_MOUSERIGHT))) {
    return bufsize;
  }

  // a <[COL],[ROW]> sequence can follow and will set the mouse_row/mouse_col
  // global variables. This is ugly but its how the rest of the code expects to
  // find mouse coordinates, and it would be too expensive to refactor this
  // now.
  int col, row, advance;
  if (sscanf(*ptr, "<%d,%d>%n", &col, &row, &advance) != EOF && advance) {
    if (col >= 0 && row >= 0) {
      mouse_row = row;
      mouse_col = col;
    }
    *ptr += advance;
  }

  static int orig_num_clicks = 0;
  static int orig_mouse_code = 0;
  static int orig_mouse_col = 0;
  static int orig_mouse_row = 0;
  static uint64_t orig_mouse_time = 0;  // time of previous mouse click
  uint64_t mouse_time = os_hrtime();    // time of current mouse click

  // compute the time elapsed since the previous mouse click and
  // convert p_mouse from ms to ns
  uint64_t timediff = mouse_time - orig_mouse_time;
  uint64_t mouset = (uint64_t)p_mouset * 1000000;
  if (mouse_code == orig_mouse_code
      && timediff < mouset
      && orig_num_clicks != 4
      && orig_mouse_col == mouse_col
      && orig_mouse_row == mouse_row) {
    orig_num_clicks++;
  } else {
    orig_num_clicks = 1;
  }
  orig_mouse_code = mouse_code;
  orig_mouse_col = mouse_col;
  orig_mouse_row = mouse_row;
  orig_mouse_time = mouse_time;

  int modifiers = 0;
  if (orig_num_clicks == 2) {
    modifiers |= MOD_MASK_2CLICK;
  } else if (orig_num_clicks == 3) {
    modifiers |= MOD_MASK_3CLICK;
  } else if (orig_num_clicks == 4) {
    modifiers |= MOD_MASK_4CLICK;
  }

  if (modifiers) {
    if (buf[1] != KS_MODIFIER) {
      // no modifiers in the buffer yet, shift the bytes 3 positions
      memcpy(buf + 3, buf, 3);
      // add the modifier sequence
      buf[0] = K_SPECIAL;
      buf[1] = KS_MODIFIER;
      buf[2] = (uint8_t)modifiers;
      bufsize += 3;
    } else {
      buf[2] |= (uint8_t)modifiers;
    }
  }

  return bufsize;
}

static bool input_poll(int ms)
{
  if (do_profiling == PROF_YES && ms) {
    prof_inchar_enter();
  }

  event_poll_until(ms, input_ready() || eof);

  if (do_profiling == PROF_YES && ms) {
    prof_inchar_exit();
  }

  return input_ready();
}

void input_done(void)
{
  eof = true;
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int ms)
{
  if (input_ready() || input_poll(ms)) {
    return kInputAvail;
  }

  return eof ? kInputEof : kInputNone;
}

static void read_cb(RStream *rstream, void *data, bool at_eof)
{
  if (at_eof) {
    eof = true;
  }

  char *buf = rbuffer_read_ptr(read_buffer);
  size_t buf_size = rbuffer_pending(read_buffer);
  (void)rbuffer_write(input_buffer, buf, buf_size);
  rbuffer_consumed(read_buffer, buf_size);
}

static void process_interrupts(void)
{
  if (mapped_ctrl_c) {
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
static bool input_ready(void)
{
  return typebuf_was_filled ||                 // API call filled typeahead
         rbuffer_pending(input_buffer) > 0 ||  // Input buffer filled
         event_has_deferred();                 // Events must be processed
}

// Exit because of an input read error.
static void read_error_exit(void)
{
  if (silent_mode)      /* Normal way to exit for "ex -s" */
    getout(0);
  STRCPY(IObuff, _("Vim: Error reading input, exiting...\n"));
  preserve_exit();
}
