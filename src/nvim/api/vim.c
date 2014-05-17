#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/vim.h"
#include "nvim/api/helpers.h"
#include "nvim/api/defs.h"
#include "nvim/api/buffer.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/types.h"
#include "nvim/ascii.h"
#include "nvim/ex_docmd.h"
#include "nvim/screen.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/eval.h"
#include "nvim/misc2.h"

#define LINE_BUFFER_SIZE 4096

/// Writes a message to vim output or error buffer. The string is split
/// and flushed after each newline. Incomplete lines are kept for writing
/// later.
///
/// @param message The message to write
/// @param to_err True if it should be treated as an error message(use
///        `emsg` instead of `msg` to print each line)
static void write_msg(String message, bool to_err);

void vim_push_keys(String str)
{
  abort();
}

void vim_command(String str, Error *err)
{
  // We still use 0-terminated strings, so we must convert.
  char *cmd_str = xstrndup(str.data, str.size);
  // Run the command
  try_start();
  do_cmdline_cmd((char_u *)cmd_str);
  free(cmd_str);
  update_screen(VALID);
  try_end(err);
}

Object vim_eval(String str, Error *err)
{
  Object rv;
  char *expr_str = xstrndup(str.data, str.size);
  // Evaluate the expression
  try_start();
  typval_T *expr_result = eval_expr((char_u *)expr_str, NULL);
  free(expr_str);

  if (!try_end(err)) {
    // No errors, convert the result
    rv = vim_to_object(expr_result);
  }

  // Free the vim object
  free_tv(expr_result);
  return rv;
}

Integer vim_strwidth(String str, Error *err)
{
  if (str.size > INT_MAX) {
    set_api_error("String length is too high", err);
    return 0;
  }

  return mb_string2cells((char_u *)str.data, (int)str.size);
}

StringArray vim_list_runtime_paths(void)
{
  StringArray rv = {.size = 0};
  uint8_t *rtp = p_rtp;

  if (*rtp == NUL) {
    // No paths
    return rv;
  }

  // Count the number of paths in rtp
  while (*rtp != NUL) {
    if (*rtp == ',') {
      rv.size++;
    }
    rtp++;
  }

  // index
  uint32_t i = 0;
  // Allocate memory for the copies
  rv.items = xmalloc(sizeof(String) * rv.size);
  // reset the position
  rtp = p_rtp;
  // Start copying
  while (*rtp != NUL) {
    rv.items[i].data = xmalloc(MAXPATHL);
    // Copy the path from 'runtimepath' to rv.items[i]
    int length = copy_option_part(&rtp,
                                 (char_u *)rv.items[i].data,
                                 MAXPATHL,
                                 ",");
    assert(length >= 0);
    rv.items[i].size = (size_t)length;
    i++;
  }

  return rv;
}

void vim_change_directory(String dir, Error *err)
{
  char string[MAXPATHL];
  strncpy(string, dir.data, dir.size);

  try_start();

  if (vim_chdir((char_u *)string)) {
    if (!try_end(err)) {
      set_api_error("failed to change directory", err);
    }
    return;
  }

  post_chdir(false);
  try_end(err);
}

String vim_get_current_line(Error *err)
{
  return buffer_get_line(curbuf->b_fnum, curwin->w_cursor.lnum - 1, err);
}

void vim_set_current_line(String line, Error *err)
{
  buffer_set_line(curbuf->b_fnum, curwin->w_cursor.lnum - 1, line, err);
}

void vim_del_current_line(Error *err)
{
  buffer_del_line(curbuf->b_fnum, curwin->w_cursor.lnum - 1, err);
}

Object vim_get_var(String name, Error *err)
{
  return dict_get_value(&globvardict, name, err);
}

Object vim_set_var(String name, Object value, Error *err)
{
  return dict_set_value(&globvardict, name, value, err);
}

Object vim_get_vvar(String name, Error *err)
{
  return dict_get_value(&vimvardict, name, err);
}

Object vim_get_option(String name, Error *err)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

void vim_set_option(String name, Object value, Error *err)
{
  set_option_to(NULL, SREQ_GLOBAL, name, value, err);
}

void vim_out_write(String str)
{
  write_msg(str, false);
}

void vim_err_write(String str)
{
  write_msg(str, true);
}

Integer vim_get_buffer_count(void)
{
  buf_T *b = firstbuf;
  Integer n = 0;

  while (b) {
    n++;
    b = b->b_next;
  }

  return n;
}

Buffer vim_get_current_buffer(void)
{
  return curbuf->b_fnum;
}

void vim_set_current_buffer(Buffer buffer, Error *err)
{
  if (!find_buffer(buffer, err)) {
    return;
  }

  try_start();
  if (do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, (int)buffer, 0) == FAIL) {
    if (try_end(err)) {
      return;
    }

    char msg[256];
    snprintf(msg, sizeof(msg), "failed to switch to buffer %d", (int)buffer);
    set_api_error(msg, err);
    return;
  }

  try_end(err);
}

Integer vim_get_window_count(void)
{
  tabpage_T *tp;
  win_T *wp;
  Integer rv = 0;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    rv++;
  }

  return rv;
}

Window vim_get_current_window(void)
{
  tabpage_T *tp;
  win_T *wp;
  Window rv = 1;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp == curwin) {
      return rv;
    }

    rv++;
  }

  // There should always be a current window
  abort();
}

void vim_set_current_window(Window window, Error *err)
{
  win_T *win = find_window(window, err);

  if (!win) {
    return;
  }

  try_start();
  win_goto(win);

  if (win != curwin) {
    if (try_end(err)) {
      return;
    }
    set_api_error("did not switch to the specified window", err);
    return;
  }

  try_end(err);
}

Integer vim_get_tabpage_count(void)
{
  tabpage_T *tp = first_tabpage;
  Integer rv = 0;

  while (tp != NULL) {
    tp = tp->tp_next;
    rv++;
  }

  return rv;
}

Tabpage vim_get_current_tabpage(void)
{
  Tabpage rv = 1;
  tabpage_T *t;

  for (t = first_tabpage; t != NULL && t != curtab; t = t->tp_next) {
    rv++;
  }

  return rv;
}

void vim_set_current_tabpage(Tabpage tabpage, Error *err)
{
  if (!find_tab(tabpage, err)) {
    return;
  }

  try_start();
  goto_tabpage((int)tabpage);
  try_end(err);
}

static void write_msg(String message, bool to_err)
{
  static int pos = 0;
  static char line_buf[LINE_BUFFER_SIZE];

  for (uint32_t i = 0; i < message.size; i++) {
    if (message.data[i] == NL || pos == LINE_BUFFER_SIZE - 1) {
      // Flush line
      line_buf[pos] = NUL;
      if (to_err) {
        emsg((uint8_t *)line_buf);
      } else {
        msg((uint8_t *)line_buf);
      }

      pos = 0;
      continue;
    }

    line_buf[pos++] = message.data[i];
  }
}
