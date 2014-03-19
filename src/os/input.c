#include <stdbool.h>


#include "os/input.h"
#include "os/io.h"
#include "vim.h"
#include "getchar.h"
#include "types.h"
#include "fileio.h"
#include "ui.h"


static int cursorhold_key(char_u *buf);
static int signal_key(char_u *buf);
static poll_result_t inbuf_poll(int32_t ms);


int mch_inchar(char_u *buf, int maxlen, long ms, int tb_change_cnt) {
  poll_result_t result;

  if (ms >= 0) {
    if ((result = inbuf_poll(ms)) != POLL_INPUT) {
      return 0;
    }
  } else {
    if ((result = inbuf_poll(p_ut)) != POLL_INPUT) {
      if (trigger_cursorhold() && maxlen >= 3 &&
          !typebuf_changed(tb_change_cnt)) {
        return cursorhold_key(buf);

      }

      before_blocking();
      result = inbuf_poll(-1);
    }
  }

  /* If input was put directly in typeahead buffer bail out here. */
  if (typebuf_changed(tb_change_cnt))
    return 0;

  if (result == POLL_EOF) {
    read_error_exit();
    return 0;
  }

  if (result == POLL_SIGNAL) {
    return signal_key(buf);
  }

  return read_from_input_buf(buf, (long)maxlen);
}

bool mch_char_avail() {
  return inbuf_poll(0);
}

/*
 * Check for CTRL-C typed by reading all available characters.
 * In cooked mode we should get SIGINT, no need to check.
 */
void mch_breakcheck() {
  if (curr_tmode == TMODE_RAW && mch_char_avail())
    fill_input_buf(FALSE);
}

/* This is a replacement for the old `WaitForChar` function in os_unix.c */
static poll_result_t inbuf_poll(int32_t ms) {
  if (input_available())
    return true;

  return io_poll(ms);
}

static int cursorhold_key(char_u *buf) {
  buf[0] = K_SPECIAL;
  buf[1] = KS_EXTRA;
  buf[2] = KE_CURSORHOLD;
  return 3;
}

static int signal_key(char_u *buf) {
  buf[0] = K_SPECIAL;
  buf[1] = KS_EXTRA;
  buf[2] = KE_SIGNAL;
  return 3;
}
