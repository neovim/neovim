#include <termkey.h>

#include "nvim/ascii.h"
#include "nvim/misc2.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"
#include "nvim/os/rstream.h"

#define PASTETOGGLE_KEY "<f37>"

struct term_input {
  int in_fd;
  bool paste_enabled;
  TermKey *tk;
  uv_pipe_t input_handle;
  uv_timer_t timer_handle;
  RBuffer *read_buffer;
  RStream *read_stream;
};

static void forward_simple_utf8(TermKeyKey *key)
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

  buf[len] = 0;
  input_enqueue((String){.data = buf, .size = len});
}

static void forward_modified_utf8(TermKey *tk, TermKeyKey *key)
{
  size_t len;
  char buf[64];

  if (key->type == TERMKEY_TYPE_KEYSYM
      && key->code.sym == TERMKEY_SYM_ESCAPE) {
    len = (size_t)snprintf(buf, sizeof(buf), "<Esc>");
  } else {
    len = termkey_strfkey(tk, buf, sizeof(buf), key, TERMKEY_FORMAT_VIM);
  }

  input_enqueue((String){.data = buf, .size = len});
}

static void forward_mouse_event(TermKey *tk, TermKeyKey *key)
{
  char buf[64];
  size_t len = 0;
  int button, row, col;
  TermKeyMouseEvent ev;
  termkey_interpret_mouse(tk, key, &ev, &button, &row, &col);

  if (ev != TERMKEY_MOUSE_PRESS && ev != TERMKEY_MOUSE_DRAG) {
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
  }

  len += (size_t)snprintf(buf + len, sizeof(buf) - len, "><%d,%d>", col, row);
  input_enqueue((String){.data = buf, .size = len});
}

static TermKeyResult tk_getkey(TermKey *tk, TermKeyKey *key, bool force)
{
  return force ? termkey_getkey_force(tk, key) : termkey_getkey(tk, key);
}

static void timer_cb(uv_timer_t *handle);

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
      forward_simple_utf8(&key);
    } else if (key.type == TERMKEY_TYPE_UNICODE ||
               key.type == TERMKEY_TYPE_FUNCTION ||
               key.type == TERMKEY_TYPE_KEYSYM) {
      forward_modified_utf8(input->tk, &key);
    } else if (key.type == TERMKEY_TYPE_MOUSE) {
      forward_mouse_event(input->tk, &key);
    }
  }

  if (result != TERMKEY_RES_AGAIN) {
    return;
  }

  int ms  = get_key_code_timeout();

  if (ms > 0) {
    // Stop the current timer if already running
    uv_timer_stop(&input->timer_handle);
    uv_timer_start(&input->timer_handle, timer_cb, (uint32_t)ms, 0);
  } else {
    tk_getkeys(input, true);
  }
}


static void timer_cb(uv_timer_t *handle)
{
  tk_getkeys(handle->data, true);
}

static bool handle_bracketed_paste(TermInput *input)
{
  char *ptr = rbuffer_read_ptr(input->read_buffer);
  size_t len = rbuffer_pending(input->read_buffer);
  if (len > 5 && (!strncmp(ptr, "\x1b[200~", 6)
        || !strncmp(ptr, "\x1b[201~", 6))) {
    bool enable = ptr[4] == '0';
    // Advance past the sequence
    rbuffer_consumed(input->read_buffer, 6);
    if (input->paste_enabled == enable) {
      return true;
    }
    if (enable) {
      // Get the current mode
      int state = get_real_state();
      if (state & NORMAL) {
        // Enter insert mode
        input_enqueue(cstr_as_string("i"));
      } else if (state & VISUAL) {
        // Remove the selected text and enter insert mode
        input_enqueue(cstr_as_string("c"));
      } else if (!(state & INSERT)) {
        // Don't mess with the paste option
        return true;
      }
    }
    input_enqueue(cstr_as_string(PASTETOGGLE_KEY));
    input->paste_enabled = enable;
    return true;
  }
  return false;
}

static bool handle_forced_escape(TermInput *input)
{
  char *ptr = rbuffer_read_ptr(input->read_buffer);
  size_t len = rbuffer_pending(input->read_buffer);
  if (len > 1 && ptr[0] == ESC && ptr[1] == NUL) {
    // skip the ESC and NUL and push one <esc> to the input buffer
    termkey_push_bytes(input->tk, ptr, 1);
    rbuffer_consumed(input->read_buffer, 2);
    tk_getkeys(input, true);
    return true;
  }
  return false;
}

static void read_cb(RStream *rstream, void *rstream_data, bool eof)
{
  if (eof) {
    input_done();
    return;
  }

  TermInput *input = rstream_data;

  do {
    if (handle_bracketed_paste(input) || handle_forced_escape(input)) {
      continue;
    }
    char *ptr = rbuffer_read_ptr(input->read_buffer);
    size_t len = rbuffer_pending(input->read_buffer);
    // Find the next 'esc' and push everything up to it(excluding)
    size_t i;
    for (i = ptr[0] == ESC ? 1 : 0; i < len; i++) {
      if (ptr[i] == '\x1b') {
        break;
      }
    }
    size_t consumed = termkey_push_bytes(input->tk, ptr, i);
    rbuffer_consumed(input->read_buffer, consumed);
    tk_getkeys(input, false);
  } while (rbuffer_pending(input->read_buffer));
}

static TermInput *term_input_new(void)
{
  TermInput *rv = xmalloc(sizeof(TermInput));
  rv->paste_enabled = false;
  // read input from stderr if stdin is not a tty
  rv->in_fd = os_isatty(0) ? 0 : (os_isatty(2) ? 2 : 0);

  // Set terminal encoding based on environment(taken from libtermkey source
  // code)
  const char *e;
  int flags = 0;
  if (((e = os_getenv("LANG")) || (e = os_getenv("LC_MESSAGES"))
        || (e = os_getenv("LC_ALL"))) && (e = strchr(e, '.')) && e++ &&
      (strcasecmp(e, "UTF-8") == 0 || strcasecmp(e, "UTF8") == 0)) {
    flags |= TERMKEY_FLAG_UTF8;
  } else {
    flags |= TERMKEY_FLAG_RAW;
  }

  rv->tk = termkey_new_abstract(os_getenv("TERM"), flags);
  int curflags = termkey_get_canonflags(rv->tk);
  termkey_set_canonflags(rv->tk, curflags | TERMKEY_CANON_DELBS);
  // setup input handle
  uv_pipe_init(uv_default_loop(), &rv->input_handle, 0);
  uv_pipe_open(&rv->input_handle, rv->in_fd);
  rv->input_handle.data = NULL;
  rv->read_buffer = rbuffer_new(0xfff);
  rv->read_stream = rstream_new(read_cb, rv->read_buffer, rv);
  rstream_set_stream(rv->read_stream, (uv_stream_t *)&rv->input_handle);
  rstream_start(rv->read_stream);
  // initialize a timer handle for handling ESC with libtermkey
  uv_timer_init(uv_default_loop(), &rv->timer_handle);
  rv->timer_handle.data = rv;
  // Set the pastetoggle option to a special key that will be sent when
  // \e[20{0,1}~/ are received
  Error err = ERROR_INIT;
  vim_set_option(cstr_as_string("pastetoggle"),
      STRING_OBJ(cstr_as_string(PASTETOGGLE_KEY)), &err);
  return rv;
}

static void term_input_destroy(TermInput *input)
{
  uv_timer_stop(&input->timer_handle);
  rstream_stop(input->read_stream);
  rstream_free(input->read_stream);
  uv_close((uv_handle_t *)&input->input_handle, NULL);
  uv_close((uv_handle_t *)&input->timer_handle, NULL);
  termkey_destroy(input->tk);
  event_poll(0);  // Run once to remove references to input/timer handles
  free(input->input_handle.data);
  free(input);
}
