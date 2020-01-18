// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <string.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/os/input.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
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
#include "nvim/state.h"
#include "nvim/msgpack_rpc/channel.h"

#define READ_BUFFER_SIZE 0xfff
#define INPUT_BUFFER_SIZE (READ_BUFFER_SIZE * 4)

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof
} InbufPollResult;

static Stream read_stream = { .closed = true };  // Input before UI starts.
static RBuffer *input_buffer = NULL;
static bool input_eof = false;
static int global_fd = -1;
static bool blocking = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.c.generated.h"
#endif

void input_init(void)
{
  input_buffer = rbuffer_new(INPUT_BUFFER_SIZE + MAX_KEY_CODE_LEN);
}

void input_global_fd_init(int fd)
{
  global_fd = fd;
}

/// Global TTY (or pipe for "-es") input stream, before UI starts.
int input_global_fd(void)
{
  return global_fd;
}

void input_start(int fd)
{
  if (!read_stream.closed) {
    return;
  }

  input_global_fd_init(fd);
  rstream_init_fd(&main_loop, &read_stream, fd, READ_BUFFER_SIZE);
  rstream_start(&read_stream, input_read_cb, NULL);
}

void input_stop(void)
{
  if (read_stream.closed) {
    return;
  }

  rstream_stop(&read_stream);
  stream_close(&read_stream, NULL, NULL);
}

static void cursorhold_event(void **argv)
{
  event_T event = State & INSERT ? EVENT_CURSORHOLDI : EVENT_CURSORHOLD;
  apply_autocmds(event, NULL, NULL, false, curbuf);
  did_cursorhold = true;
}

static void create_cursorhold_event(bool events_enabled)
{
  // If events are enabled and the queue has any items, this function should not
  // have been called(inbuf_poll would return kInputAvail)
  // TODO(tarruda): Cursorhold should be implemented as a timer set during the
  // `state_check` callback for the states where it can be triggered.
  assert(!events_enabled || multiqueue_empty(main_loop.events));
  multiqueue_put(main_loop.events, cursorhold_event, 0);
}

/// Low level input function
///
/// wait until either the input buffer is non-empty or , if `events` is not NULL
/// until `events` is non-empty.
int os_inchar(uint8_t *buf, int maxlen, int ms, int tb_change_cnt,
              MultiQueue *events)
{
  if (maxlen && rbuffer_size(input_buffer)) {
    return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
  }

  InbufPollResult result;
  if (ms >= 0) {
    if ((result = inbuf_poll(ms, events)) == kInputNone) {
      return 0;
    }
  } else {
    if ((result = inbuf_poll((int)p_ut, events)) == kInputNone) {
      if (read_stream.closed && silent_mode) {
        // Drained eventloop & initial input; exit silent/batch-mode (-es/-Es).
        read_error_exit();
      }

      if (trigger_cursorhold() && !typebuf_changed(tb_change_cnt)) {
        create_cursorhold_event(events == main_loop.events);
      } else {
        before_blocking();
        result = inbuf_poll(-1, events);
      }
    }
  }

  // If input was put directly in typeahead buffer bail out here.
  if (typebuf_changed(tb_change_cnt)) {
    return 0;
  }

  if (maxlen && rbuffer_size(input_buffer)) {
    // Safe to convert rbuffer_read to int, it will never overflow since we use
    // relatively small buffers.
    return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
  }

  // If there are events, return the keys directly
  if (maxlen && pending_events(events)) {
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
  return inbuf_poll(0, NULL) == kInputAvail;
}

// Check for CTRL-C typed by reading all available characters.
void os_breakcheck(void)
{
  int save_us = updating_screen;
  // We do not want screen_resize() to redraw here.
  updating_screen++;

  if (!got_int) {
    loop_poll_events(&main_loop, 0);
  }

  updating_screen = save_us;
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
  char *ptr = keys.data;
  char *end = ptr + keys.size;

  while (rbuffer_space(input_buffer) >= 6 && ptr < end) {
    uint8_t buf[6] = { 0 };
    unsigned int new_size
        = trans_special((const uint8_t **)&ptr, (size_t)(end - ptr), buf, true,
                        false);

    if (new_size) {
      new_size = handle_mouse_event(&ptr, buf, new_size);
      rbuffer_write(input_buffer, (char *)buf, new_size);
      continue;
    }

    if (*ptr == '<') {
      char *old_ptr = ptr;
      // Invalid or incomplete key sequence, skip until the next '>' or *end.
      do {
        ptr++;
      } while (ptr < end && *ptr != '>');
      if (*ptr != '>') {
        // Incomplete key sequence, return without consuming.
        ptr = old_ptr;
        break;
      }
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

static uint8_t check_multiclick(int code, int grid, int row, int col)
{
  static int orig_num_clicks = 0;
  static int orig_mouse_code = 0;
  static int orig_mouse_grid = 0;
  static int orig_mouse_col = 0;
  static int orig_mouse_row = 0;
  static uint64_t orig_mouse_time = 0;  // time of previous mouse click

  if (code == KE_LEFTRELEASE || code == KE_RIGHTRELEASE
      || code == KE_MIDDLERELEASE) {
    return 0;
  }
  uint64_t mouse_time = os_hrtime();    // time of current mouse click (ns)

  // compute the time elapsed since the previous mouse click and
  // convert p_mouse from ms to ns
  uint64_t timediff = mouse_time - orig_mouse_time;
  uint64_t mouset = (uint64_t)p_mouset * 1000000;
  if (code == orig_mouse_code
      && timediff < mouset
      && orig_num_clicks != 4
      && orig_mouse_grid == grid
      && orig_mouse_col == col
      && orig_mouse_row == row) {
    orig_num_clicks++;
  } else {
    orig_num_clicks = 1;
  }
  orig_mouse_code = code;
  orig_mouse_grid = grid;
  orig_mouse_col = col;
  orig_mouse_row = row;
  orig_mouse_time = mouse_time;

  uint8_t modifiers = 0;
  if (orig_num_clicks == 2) {
    modifiers |= MOD_MASK_2CLICK;
  } else if (orig_num_clicks == 3) {
    modifiers |= MOD_MASK_3CLICK;
  } else if (orig_num_clicks == 4) {
    modifiers |= MOD_MASK_4CLICK;
  }
  return modifiers;
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
      // Make sure the mouse position is valid.  Some terminals may
      // return weird values.
      if (col >= Columns) {
        col = Columns - 1;
      }
      if (row >= Rows) {
        row = Rows - 1;
      }
      mouse_grid = 0;
      mouse_row = row;
      mouse_col = col;
    }
    *ptr += advance;
  }

  uint8_t modifiers = check_multiclick(mouse_code, mouse_grid,
                                       mouse_row, mouse_col);

  if (modifiers) {
    if (buf[1] != KS_MODIFIER) {
      // no modifiers in the buffer yet, shift the bytes 3 positions
      memcpy(buf + 3, buf, 3);
      // add the modifier sequence
      buf[0] = K_SPECIAL;
      buf[1] = KS_MODIFIER;
      buf[2] = modifiers;
      bufsize += 3;
    } else {
      buf[2] |= modifiers;
    }
  }

  return bufsize;
}

size_t input_enqueue_mouse(int code, uint8_t modifier,
                           int grid, int row, int col)
{
  modifier |= check_multiclick(code, grid, row, col);
  uint8_t buf[7], *p = buf;
  if (modifier) {
    p[0] = K_SPECIAL;
    p[1] = KS_MODIFIER;
    p[2] = modifier;
    p += 3;
  }
  p[0] = K_SPECIAL;
  p[1] = KS_EXTRA;
  p[2] = (uint8_t)code;

  mouse_grid = grid;
  mouse_row = row;
  mouse_col = col;

  size_t written = 3 + (size_t)(p-buf);
  rbuffer_write(input_buffer, (char *)buf, written);
  return written;
}

/// @return true if the main loop is blocked and waiting for input.
bool input_blocking(void)
{
  return blocking;
}

// This is a replacement for the old `WaitForChar` function in os_unix.c
static InbufPollResult inbuf_poll(int ms, MultiQueue *events)
{
  if (input_ready(events)) {
    return kInputAvail;
  }

  if (do_profiling == PROF_YES && ms) {
    prof_inchar_enter();
  }

  if ((ms == - 1 || ms > 0) && events == NULL && !input_eof) {
    // The pending input provoked a blocking wait. Do special events now. #6247
    blocking = true;
    multiqueue_process_events(ch_before_blocking_events);
  }
  DLOG("blocking... events_enabled=%d events_pending=%d", events != NULL,
       events && !multiqueue_empty(events));
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, ms,
                            input_ready(events) || input_eof);
  blocking = false;

  if (do_profiling == PROF_YES && ms) {
    prof_inchar_exit();
  }

  if (input_ready(events)) {
    return kInputAvail;
  } else {
    return input_eof ? kInputEof : kInputNone;
  }
}

void input_done(void)
{
  input_eof = true;
}

bool input_available(void)
{
  return rbuffer_size(input_buffer) != 0;
}

static void input_read_cb(Stream *stream, RBuffer *buf, size_t c, void *data,
                          bool at_eof)
{
  if (at_eof) {
    input_done();
  }

  assert(rbuffer_space(input_buffer) >= rbuffer_size(buf));
  RBUFFER_UNTIL_EMPTY(buf, ptr, len) {
    (void)rbuffer_write(input_buffer, ptr, len);
    rbuffer_consumed(buf, len);
  }
}

static void process_interrupts(void)
{
  if ((mapped_ctrl_c | curbuf->b_mapped_ctrl_c) & get_real_state()) {
    return;
  }

  size_t consume_count = 0;
  RBUFFER_EACH_REVERSE(input_buffer, c, i) {
    if ((uint8_t)c == Ctrl_C) {
      got_int = true;
      consume_count = i;
      break;
    }
  }

  if (got_int && consume_count) {
    // Remove all unprocessed input (typeahead) before the CTRL-C.
    rbuffer_consumed(input_buffer, consume_count);
  }
}

// Helper function used to push bytes from the 'event' key sequence partially
// between calls to os_inchar when maxlen < 3
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
static bool input_ready(MultiQueue *events)
{
  return (typebuf_was_filled             // API call filled typeahead
          || rbuffer_size(input_buffer)  // Input buffer filled
          || pending_events(events));          // Events must be processed
}

// Exit because of an input read error.
static void read_error_exit(void)
{
  if (silent_mode) {  // Normal way to exit for "nvim -es".
    getout(0);
  }
  STRCPY(IObuff, _("Vim: Error reading input, exiting...\n"));
  preserve_exit();
}

static bool pending_events(MultiQueue *events)
{
  return events && !multiqueue_empty(events);
}
