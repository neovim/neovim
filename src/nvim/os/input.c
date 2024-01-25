#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/rstream.h"
#include "nvim/event/stream.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/profile.h"
#include "nvim/rbuffer.h"
#include "nvim/rbuffer_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"

#define READ_BUFFER_SIZE 0xfff
#define INPUT_BUFFER_SIZE (READ_BUFFER_SIZE * 4)

typedef enum {
  kInputNone,
  kInputAvail,
  kInputEof,
} InbufPollResult;

static Stream read_stream = { .closed = true };  // Input before UI starts.
static RBuffer *input_buffer = NULL;
static bool input_eof = false;
static bool blocking = false;
static int cursorhold_time = 0;  ///< time waiting for CursorHold event
static int cursorhold_tb_change_cnt = 0;  ///< tb_change_cnt when waiting started

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/input.c.generated.h"
#endif

void input_init(void)
{
  input_buffer = rbuffer_new(INPUT_BUFFER_SIZE + MAX_KEY_CODE_LEN);
}

void input_start(void)
{
  if (!read_stream.closed) {
    return;
  }

  used_stdin = true;
  rstream_init_fd(&main_loop, &read_stream, STDIN_FILENO, READ_BUFFER_SIZE);
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

#ifdef EXITFREE
void input_free_all_mem(void)
{
  rbuffer_free(input_buffer);
}
#endif

static void cursorhold_event(void **argv)
{
  event_T event = State & MODE_INSERT ? EVENT_CURSORHOLDI : EVENT_CURSORHOLD;
  apply_autocmds(event, NULL, NULL, false, curbuf);
  did_cursorhold = true;
}

static void create_cursorhold_event(bool events_enabled)
{
  // If events are enabled and the queue has any items, this function should not
  // have been called (inbuf_poll would return kInputAvail).
  // TODO(tarruda): Cursorhold should be implemented as a timer set during the
  // `state_check` callback for the states where it can be triggered.
  assert(!events_enabled || multiqueue_empty(main_loop.events));
  multiqueue_put(main_loop.events, cursorhold_event, NULL);
}

static void restart_cursorhold_wait(int tb_change_cnt)
{
  cursorhold_time = 0;
  cursorhold_tb_change_cnt = tb_change_cnt;
}

/// Low level input function
///
/// Wait until either the input buffer is non-empty or, if `events` is not NULL
/// until `events` is non-empty.
int os_inchar(uint8_t *buf, int maxlen, int ms, int tb_change_cnt, MultiQueue *events)
{
  // This check is needed so that feeding typeahead from RPC can prevent CursorHold.
  if (tb_change_cnt != cursorhold_tb_change_cnt) {
    restart_cursorhold_wait(tb_change_cnt);
  }

  if (maxlen && rbuffer_size(input_buffer)) {
    restart_cursorhold_wait(tb_change_cnt);
    return (int)rbuffer_read(input_buffer, (char *)buf, (size_t)maxlen);
  }

  // No risk of a UI flood, so disable CTRL-C "interrupt" behavior if it's mapped.
  if ((mapped_ctrl_c | curbuf->b_mapped_ctrl_c) & get_real_state()) {
    ctrl_c_interrupts = false;
  }

  InbufPollResult result;
  if (ms >= 0) {
    if ((result = inbuf_poll(ms, events)) == kInputNone) {
      return 0;
    }
  } else {
    uint64_t wait_start = os_hrtime();
    cursorhold_time = MIN(cursorhold_time, (int)p_ut);
    if ((result = inbuf_poll((int)p_ut - cursorhold_time, events)) == kInputNone) {
      if (read_stream.closed && silent_mode) {
        // Drained eventloop & initial input; exit silent/batch-mode (-es/-Es).
        read_error_exit();
      }
      restart_cursorhold_wait(tb_change_cnt);
      if (trigger_cursorhold() && !typebuf_changed(tb_change_cnt)) {
        create_cursorhold_event(events == main_loop.events);
      } else {
        before_blocking();
        result = inbuf_poll(-1, events);
      }
    } else {
      cursorhold_time += (int)((os_hrtime() - wait_start) / 1000000);
    }
  }

  ctrl_c_interrupts = true;

  // If input was put directly in typeahead buffer bail out here.
  if (typebuf_changed(tb_change_cnt)) {
    return 0;
  }

  if (maxlen && rbuffer_size(input_buffer)) {
    restart_cursorhold_wait(tb_change_cnt);
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

/// Poll for fast events. `got_int` will be set to `true` if CTRL-C was typed.
///
/// This invokes a full libuv loop iteration which can be quite costly.
/// Prefer `line_breakcheck()` if called in a busy inner loop.
///
/// Caller must at least check `got_int` before calling this function again.
/// checking for other low-level input state like `input_available()` might
/// also be relevant (i e to throttle idle processing when user input is
/// available)
void os_breakcheck(void)
{
  if (got_int) {
    return;
  }

  loop_poll_events(&main_loop, 0);
}

#define BREAKCHECK_SKIP 1000
static int breakcheck_count = 0;

/// Check for CTRL-C pressed, but only once in a while.
///
/// Should be used instead of os_breakcheck() for functions that check for
/// each line in the file.  Calling os_breakcheck() each time takes too much
/// time, because it will use system calls to check for input.
void line_breakcheck(void)
{
  if (++breakcheck_count >= BREAKCHECK_SKIP) {
    breakcheck_count = 0;
    os_breakcheck();
  }
}

/// Like line_breakcheck() but check 10 times less often.
void fast_breakcheck(void)
{
  if (++breakcheck_count >= BREAKCHECK_SKIP * 10) {
    breakcheck_count = 0;
    os_breakcheck();
  }
}

/// Like line_breakcheck() but check 100 times less often.
void veryfast_breakcheck(void)
{
  if (++breakcheck_count >= BREAKCHECK_SKIP * 100) {
    breakcheck_count = 0;
    os_breakcheck();
  }
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
  const char *ptr = keys.data;
  const char *end = ptr + keys.size;

  while (rbuffer_space(input_buffer) >= 19 && ptr < end) {
    // A "<x>" form occupies at least 1 characters, and produces up
    // to 19 characters (1 + 5 * 3 for the char and 3 for a modifier).
    // In the case of K_SPECIAL(0x80), 3 bytes are escaped and needed,
    // but since the keys are UTF-8, so the first byte cannot be
    // K_SPECIAL(0x80).
    uint8_t buf[19] = { 0 };
    // Do not simplify the keys here. Simplification will be done later.
    unsigned new_size
      = trans_special(&ptr, (size_t)(end - ptr), (char *)buf, FSK_KEYCODE, true, NULL);

    if (new_size) {
      new_size = handle_mouse_event(&ptr, buf, new_size);
      rbuffer_write(input_buffer, (char *)buf, new_size);
      continue;
    }

    if (*ptr == '<') {
      const char *old_ptr = ptr;
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

    // copy the character, escaping K_SPECIAL
    if ((uint8_t)(*ptr) == K_SPECIAL) {
      rbuffer_write(input_buffer, (char *)&(uint8_t){ K_SPECIAL }, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){ KS_SPECIAL }, 1);
      rbuffer_write(input_buffer, (char *)&(uint8_t){ KE_FILLER }, 1);
    } else {
      rbuffer_write(input_buffer, ptr, 1);
    }
    ptr++;
  }

  size_t rv = (size_t)(ptr - keys.data);
  process_ctrl_c();
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

  if ((code >= KE_MOUSEDOWN && code <= KE_MOUSERIGHT) || code == KE_MOUSEMOVE) {
    return 0;
  }

  // For click events the number of clicks is updated.
  if (code == KE_LEFTMOUSE || code == KE_RIGHTMOUSE || code == KE_MIDDLEMOUSE
      || code == KE_X1MOUSE || code == KE_X2MOUSE) {
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
    orig_mouse_time = mouse_time;
  }
  // For drag and release events the number of clicks is kept.

  orig_mouse_grid = grid;
  orig_mouse_col = col;
  orig_mouse_row = row;

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
static unsigned handle_mouse_event(const char **ptr, uint8_t *buf, unsigned bufsize)
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
           || (mouse_code >= KE_MOUSEDOWN && mouse_code <= KE_MOUSERIGHT)
           || mouse_code == KE_MOUSEMOVE)) {
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

size_t input_enqueue_mouse(int code, uint8_t modifier, int grid, int row, int col)
{
  modifier |= check_multiclick(code, grid, row, col);
  uint8_t buf[7];
  uint8_t *p = buf;
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

  size_t written = 3 + (size_t)(p - buf);
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
  if (os_input_ready(events)) {
    return kInputAvail;
  }

  if (do_profiling == PROF_YES && ms) {
    prof_inchar_enter();
  }

  if ((ms == -1 || ms > 0) && events != main_loop.events && !input_eof) {
    // The pending input provoked a blocking wait. Do special events now. #6247
    blocking = true;
    multiqueue_process_events(ch_before_blocking_events);
  }
  DLOG("blocking... events_enabled=%d events_pending=%d", events != NULL,
       events && !multiqueue_empty(events));
  LOOP_PROCESS_EVENTS_UNTIL(&main_loop, NULL, ms,
                            os_input_ready(events) || input_eof);
  blocking = false;

  if (do_profiling == PROF_YES && ms) {
    prof_inchar_exit();
  }

  if (os_input_ready(events)) {
    return kInputAvail;
  }
  return input_eof ? kInputEof : kInputNone;
}

bool input_available(void)
{
  return rbuffer_size(input_buffer) != 0;
}

static void input_read_cb(Stream *stream, RBuffer *buf, size_t c, void *data, bool at_eof)
{
  if (at_eof) {
    input_eof = true;
  }

  assert(rbuffer_space(input_buffer) >= rbuffer_size(buf));
  RBUFFER_UNTIL_EMPTY(buf, ptr, len) {
    (void)rbuffer_write(input_buffer, ptr, len);
    rbuffer_consumed(buf, len);
  }
}

static void process_ctrl_c(void)
{
  if (!ctrl_c_interrupts) {
    return;
  }

  size_t consume_count = 0;
  RBUFFER_EACH_REVERSE(input_buffer, c, i) {
    if ((uint8_t)c == Ctrl_C
        || ((uint8_t)c == 'C' && i >= 3
            && (uint8_t)(*rbuffer_get(input_buffer, i - 3)) == K_SPECIAL
            && (uint8_t)(*rbuffer_get(input_buffer, i - 2)) == KS_MODIFIER
            && (uint8_t)(*rbuffer_get(input_buffer, i - 1)) == MOD_MASK_CTRL)) {
      *rbuffer_get(input_buffer, i) = Ctrl_C;
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

/// Check if there's pending input already in typebuf or `events`
bool os_input_ready(MultiQueue *events)
{
  return (typebuf_was_filled             // API call filled typeahead
          || rbuffer_size(input_buffer)  // Input buffer filled
          || pending_events(events));    // Events must be processed
}

// Exit because of an input read error.
static void read_error_exit(void)
  FUNC_ATTR_NORETURN
{
  if (silent_mode) {  // Normal way to exit for "nvim -es".
    getout(0);
  }
  preserve_exit(_("Vim: Error reading input, exiting...\n"));
}

static bool pending_events(MultiQueue *events)
{
  return events && !multiqueue_empty(events);
}
