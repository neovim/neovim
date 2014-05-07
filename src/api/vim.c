#include <stdint.h>
#include <stdlib.h>

#include "api/vim.h"
#include "api/defs.h"

void vim_push_keys(String str)
{
  abort();
}

void vim_command(String str, Error *err)
{
  abort();
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
