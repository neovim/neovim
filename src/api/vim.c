#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include "api/vim.h"
#include "api/defs.h"
#include "../vim.h"
#include "types.h"
#include "ascii.h"
#include "ex_docmd.h"
#include "screen.h"
#include "memory.h"

/// Start block that may cause vimscript exceptions
static void try_start(void);

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
static bool try_end(Error *err);

void vim_push_keys(String str)
{
  abort();
}

void vim_command(String str, Error *err)
{
  // We still use 0-terminated strings, so we must convert.
  char cmd_str[str.size + 1];
  memcpy(cmd_str, str.data, str.size);
  cmd_str[str.size] = NUL;
  // Run the command
  try_start();
  do_cmdline_cmd((char_u *)cmd_str);
  update_screen(VALID);
  try_end(err);
}

Object vim_eval(String str, Error *err)
{
  abort();
}

int64_t vim_strwidth(String str)
{
  abort();
}

StringArray vim_list_runtime_paths(void)
{
  abort();
}

void vim_change_directory(String dir)
{
  abort();
}

String vim_get_current_line(void)
{
  abort();
}

void vim_set_current_line(String line)
{
  abort();
}

Object vim_get_var(bool special, String name, Error *err)
{
  abort();
}

void vim_set_var(bool special, String name, Object value, Error *err)
{
  abort();
}

String vim_get_option(String name, Error *err)
{
  abort();
}

void vim_set_option(String name, String value, Error *err)
{
  abort();
}

void vim_del_option(String name, Error *err)
{
  abort();
}

void vim_out_write(String str)
{
  abort();
}

void vim_err_write(String str)
{
  abort();
}

int64_t vim_get_buffer_count(void)
{
  abort();
}

Buffer vim_get_buffer(int64_t num, Error *err)
{
  abort();
}

Buffer vim_get_current_buffer(void)
{
  abort();
}

void vim_set_current_buffer(Buffer buffer)
{
  abort();
}

int64_t vim_get_window_count(void)
{
  abort();
}

Window vim_get_window(int64_t num, Error *err)
{
  abort();
}

Window vim_get_current_window(void)
{
  abort();
}

void vim_set_current_window(Window window)
{
  abort();
}

int64_t vim_get_tabpage_count(void)
{
  abort();
}

Tabpage vim_get_tabpage(int64_t num, Error *err)
{
  abort();
}

Tabpage vim_get_current_tabpage(void)
{
  abort();
}

void vim_set_current_tabpage(Tabpage tabpage)
{
  abort();
}

static void try_start()
{
  ++trylevel;
}

static bool try_end(Error *err)
{
  --trylevel;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    const char msg[] = "Keyboard interrupt";

    if (did_throw) {
      // If we got an interrupt, discard the current exception 
      discard_current_exception();
    }

    strncpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = (char *)get_exception_string(*msg_list,
                                             ET_ERROR,
                                             NULL,
                                             &should_free);
    strncpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
    free_global_msglist();

    if (should_free) {
      free(msg);
    }
  } else if (did_throw) {
    strncpy(err->msg, (char *)current_exception->value, sizeof(err->msg));
    err->set = true;
  }

  return err->set;
}
