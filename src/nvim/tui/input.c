
#include "nvim/tui/input.h"
#include "nvim/vim.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/main.h"
#include "nvim/misc2.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"
#include "nvim/event/rstream.h"

#define PASTETOGGLE_KEY "<Paste>"
#define FOCUSGAINED_KEY "<FocusGained>"
#define FOCUSLOST_KEY   "<FocusLost>"
#define KEY_BUFFER_SIZE 0xfff

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.c.generated.h"
#endif

void term_input_init(TermInput *input, Loop *loop)
{
  input->loop = loop;
  input->paste_enabled = false;
  input->in_fd = 0;
  input->key_buffer = rbuffer_new(KEY_BUFFER_SIZE);
  uv_mutex_init(&input->key_buffer_mutex);
  uv_cond_init(&input->key_buffer_cond);

  const char *term = os_getenv("TERM");
  if (!term) {
    term = "";  // termkey_new_abstract assumes non-null (#2745)
  }
  int enc_flag = enc_utf8 ? TERMKEY_FLAG_UTF8 : TERMKEY_FLAG_RAW;
  input->tk = termkey_new_abstract(term, enc_flag);

  int curflags = termkey_get_canonflags(input->tk);
  termkey_set_canonflags(input->tk, curflags | TERMKEY_CANON_DELBS);
  // setup input handle
  rstream_init_fd(loop, &input->read_stream, input->in_fd, 0xfff, input);
  // initialize a timer handle for handling ESC with libtermkey
  time_watcher_init(loop, &input->timer_handle, input);
}

void term_input_destroy(TermInput *input)
{
  rbuffer_free(input->key_buffer);
  uv_mutex_destroy(&input->key_buffer_mutex);
  uv_cond_destroy(&input->key_buffer_cond);
  time_watcher_close(&input->timer_handle, NULL);
  stream_close(&input->read_stream, NULL);
  termkey_destroy(input->tk);
}

void term_input_start(TermInput *input)
{
  rstream_start(&input->read_stream, read_cb);
}

void term_input_stop(TermInput *input)
{
  rstream_stop(&input->read_stream);
  time_watcher_stop(&input->timer_handle);
}

static void input_done_event(void **argv)
{
  input_done();
}

static void wait_input_enqueue(void **argv)
{
  TermInput *input = argv[0];
  RBUFFER_UNTIL_EMPTY(input->key_buffer, buf, len) {
    size_t consumed = input_enqueue((String){.data = buf, .size = len});
    if (consumed) {
      rbuffer_consumed(input->key_buffer, consumed);
    }
    rbuffer_reset(input->key_buffer);
    if (consumed < len) {
      break;
    }
  }
  uv_mutex_lock(&input->key_buffer_mutex);
  input->waiting = false;
  uv_cond_signal(&input->key_buffer_cond);
  uv_mutex_unlock(&input->key_buffer_mutex);
}

static void flush_input(TermInput *input, bool wait_until_empty)
{
  size_t drain_boundary = wait_until_empty ? 0 : 0xff;
  do {
    uv_mutex_lock(&input->key_buffer_mutex);
    loop_schedule(&main_loop, event_create(1, wait_input_enqueue, 1, input));
    input->waiting = true;
    while (input->waiting) {
      uv_cond_wait(&input->key_buffer_cond, &input->key_buffer_mutex);
    }
    uv_mutex_unlock(&input->key_buffer_mutex);
  } while (rbuffer_size(input->key_buffer) > drain_boundary);
}

static void enqueue_input(TermInput *input, char *buf, size_t size)
{
  if (rbuffer_size(input->key_buffer) >
      rbuffer_capacity(input->key_buffer) - 0xff) {
    // don't ever let the buffer get too full or we risk putting incomplete keys
    // into it
    flush_input(input, false);
  }
  rbuffer_write(input->key_buffer, buf, size);
}

static void forward_simple_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len = 0;
  char buf[64];
  char *ptr = key->utf8;

  while (*ptr) {
    if (*ptr == '<') {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "<lt>");
    } else {
      buf[len++] = *ptr;
    }
    ptr++;
  }

  enqueue_input(input, buf, len);
}

static void forward_modified_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len;
  char buf[64];

  if (key->type == TERMKEY_TYPE_KEYSYM
      && key->code.sym == TERMKEY_SYM_ESCAPE) {
    len = (size_t)snprintf(buf, sizeof(buf), "<Esc>");
  } else if (key->type == TERMKEY_TYPE_KEYSYM
      && key->code.sym == TERMKEY_SYM_SUSPEND) {
    len = (size_t)snprintf(buf, sizeof(buf), "<C-Z>");
  } else {
    len = termkey_strfkey(input->tk, buf, sizeof(buf), key, TERMKEY_FORMAT_VIM);
  }

  enqueue_input(input, buf, len);
}

static void forward_mouse_event(TermInput *input, TermKeyKey *key)
{
  char buf[64];
  size_t len = 0;
  int button, row, col;
  TermKeyMouseEvent ev;
  termkey_interpret_mouse(input->tk, key, &ev, &button, &row, &col);

  if (ev != TERMKEY_MOUSE_PRESS && ev != TERMKEY_MOUSE_DRAG
      && ev != TERMKEY_MOUSE_RELEASE) {
    return;
  }

  row--; col--;  // Termkey uses 1-based coordinates
  buf[len++] = '<';

  if (key->modifiers & TERMKEY_KEYMOD_SHIFT) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "S-");
  }

  if (key->modifiers & TERMKEY_KEYMOD_CTRL) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "C-");
  }

  if (key->modifiers & TERMKEY_KEYMOD_ALT) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "A-");
  }

  if (button == 1) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Left");
  } else if (button == 2) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Middle");
  } else if (button == 3) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Right");
  }

  if (ev == TERMKEY_MOUSE_PRESS) {
    if (button == 4) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelUp");
    } else if (button == 5) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelDown");
    } else {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Mouse");
    }
  } else if (ev == TERMKEY_MOUSE_DRAG) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Drag");
  } else if (ev == TERMKEY_MOUSE_RELEASE) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Release");
  }

  len += (size_t)snprintf(buf + len, sizeof(buf) - len, "><%d,%d>", col, row);
  enqueue_input(input, buf, len);
}

static TermKeyResult tk_getkey(TermKey *tk, TermKeyKey *key, bool force)
{
  return force ? termkey_getkey_force(tk, key) : termkey_getkey(tk, key);
}

static void timer_cb(TimeWatcher *watcher, void *data);

static int get_key_code_timeout(void)
{
  Integer ms = -1;
  // Check 'ttimeout' to determine if we should send ESC after 'ttimeoutlen'.
  // See :help 'ttimeout' for more information
  Error err = ERROR_INIT;
  if (vim_get_option(cstr_as_string("ttimeout"), &err).data.boolean) {
    ms = vim_get_option(cstr_as_string("ttimeoutlen"), &err).data.integer;
  }

  return (int)ms;
}

static void tk_getkeys(TermInput *input, bool force)
{
  TermKeyKey key;
  TermKeyResult result;

  while ((result = tk_getkey(input->tk, &key, force)) == TERMKEY_RES_KEY) {
    if (key.type == TERMKEY_TYPE_UNICODE && !key.modifiers) {
      forward_simple_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_UNICODE
               || key.type == TERMKEY_TYPE_FUNCTION
               || key.type == TERMKEY_TYPE_KEYSYM) {
      forward_modified_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_MOUSE) {
      forward_mouse_event(input, &key);
    }
  }

  if (result != TERMKEY_RES_AGAIN || input->paste_enabled) {
    return;
  }

  int ms  = get_key_code_timeout();

  if (ms > 0) {
    // Stop the current timer if already running
    time_watcher_stop(&input->timer_handle);
    time_watcher_start(&input->timer_handle, timer_cb, (uint32_t)ms, 0);
  } else {
    tk_getkeys(input, true);
  }
}

static void timer_cb(TimeWatcher *watcher, void *data)
{
  tk_getkeys(data, true);
  flush_input(data, true);
}

/// Handle focus events.
///
/// If the upcoming sequence of bytes in the input stream matches either the
/// escape code for focus gained `<ESC>[I` or focus lost `<ESC>[O` then consume
/// that sequence and push the appropriate event into the input queue
///
/// @param input the input stream
/// @return true iff handle_focus_event consumed some input
static bool handle_focus_event(TermInput *input)
{
  if (rbuffer_size(input->read_stream.buffer) > 2
      && (!rbuffer_cmp(input->read_stream.buffer, "\x1b[I", 3)
          || !rbuffer_cmp(input->read_stream.buffer, "\x1b[O", 3))) {
    // Advance past the sequence
    bool focus_gained = *rbuffer_get(input->read_stream.buffer, 2) == 'I';
    rbuffer_consumed(input->read_stream.buffer, 3);
    if (focus_gained) {
      enqueue_input(input, FOCUSGAINED_KEY, sizeof(FOCUSGAINED_KEY) - 1);
    } else {
      enqueue_input(input, FOCUSLOST_KEY, sizeof(FOCUSLOST_KEY) - 1);
    }
    return true;
  }
  return false;
}

static bool handle_bracketed_paste(TermInput *input)
{
  if (rbuffer_size(input->read_stream.buffer) > 5
      && (!rbuffer_cmp(input->read_stream.buffer, "\x1b[200~", 6)
          || !rbuffer_cmp(input->read_stream.buffer, "\x1b[201~", 6))) {
    bool enable = *rbuffer_get(input->read_stream.buffer, 4) == '0';
    // Advance past the sequence
    rbuffer_consumed(input->read_stream.buffer, 6);
    if (input->paste_enabled == enable) {
      return true;
    }
    enqueue_input(input, PASTETOGGLE_KEY, sizeof(PASTETOGGLE_KEY) - 1);
    input->paste_enabled = enable;
    return true;
  }
  return false;
}

static bool handle_forced_escape(TermInput *input)
{
  if (rbuffer_size(input->read_stream.buffer) > 1
      && !rbuffer_cmp(input->read_stream.buffer, "\x1b\x00", 2)) {
    // skip the ESC and NUL and push one <esc> to the input buffer
    size_t rcnt;
    termkey_push_bytes(input->tk, rbuffer_read_ptr(input->read_stream.buffer,
          &rcnt), 1);
    rbuffer_consumed(input->read_stream.buffer, 2);
    tk_getkeys(input, true);
    return true;
  }
  return false;
}

static void restart_reading(void **argv);

static void read_cb(Stream *stream, RBuffer *buf, size_t c, void *data,
    bool eof)
{
  TermInput *input = data;

  if (eof) {
    if (input->in_fd == 0 && !os_isatty(0) && os_isatty(2)) {
      // Started reading from stdin which is not a pty but failed. Switch to
      // stderr since it is a pty.
      //
      // This is how we support commands like:
      //
      // echo q | nvim -es
      //
      // and
      //
      // ls *.md | xargs nvim
      input->in_fd = 2;
      stream_close(&input->read_stream, NULL);
      queue_put(input->loop->fast_events, restart_reading, 1, input);
    } else {
      loop_schedule(&main_loop, event_create(1, input_done_event, 0));
    }
    return;
  }

  do {
    if (handle_focus_event(input)
        || handle_bracketed_paste(input)
        || handle_forced_escape(input)) {
      continue;
    }

    // Find the next 'esc' and push everything up to it(excluding). This is done
    // so the `handle_bracketed_paste`/`handle_forced_escape` calls above work
    // as expected.
    size_t count = 0;
    RBUFFER_EACH(input->read_stream.buffer, c, i) {
      count = i + 1;
      if (c == '\x1b' && count > 1) {
        count--;
        break;
      }
    }

    RBUFFER_UNTIL_EMPTY(input->read_stream.buffer, ptr, len) {
      size_t consumed = termkey_push_bytes(input->tk, ptr, MIN(count, len));
      // termkey_push_bytes can return (size_t)-1, so it is possible that
      // `consumed > input->read_stream.buffer->size`, but since tk_getkeys is
      // called soon, it shouldn't happen
      assert(consumed <= input->read_stream.buffer->size);
      rbuffer_consumed(input->read_stream.buffer, consumed);
      // Need to process the keys now since there's no guarantee "count" will
      // fit into libtermkey's input buffer.
      tk_getkeys(input, false);
      if (!(count -= consumed)) {
        break;
      }
    }
  } while (rbuffer_size(input->read_stream.buffer));
  flush_input(input, true);
  // Make sure the next input escape sequence fits into the ring buffer
  // without wrap around, otherwise it could be misinterpreted.
  rbuffer_reset(input->read_stream.buffer);
}

static void restart_reading(void **argv)
{
  TermInput *input = argv[0];
  rstream_init_fd(input->loop, &input->read_stream, input->in_fd, 0xfff, input);
  rstream_start(&input->read_stream, read_cb);
}
