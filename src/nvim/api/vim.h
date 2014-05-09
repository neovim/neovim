#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/private/defs.h"

void vim_push_keys(String str);

void vim_command(String str, Error *err);

Object vim_eval(String str, Error *err);

Integer vim_strwidth(String str, Error *err);

StringArray vim_list_runtime_paths(void);

void vim_change_directory(String dir, Error *err);

String vim_get_current_line(Error *err);

void vim_del_current_line(Error *err);

void vim_set_current_line(String line, Error *err);

Object vim_get_var(String name, Error *err);

Object vim_set_var(String name, Object value, Error *err);

Object vim_get_vvar(String name, Error *err);

Object vim_get_option(String name, Error *err);

void vim_set_option(String name, Object value, Error *err);

void vim_out_write(String str);

void vim_err_write(String str);

BufferArray vim_get_buffers(void);

Buffer vim_get_current_buffer(void);

void vim_set_current_buffer(Buffer buffer, Error *err);

WindowArray vim_get_windows(void);

Window vim_get_current_window(void);

void vim_set_current_window(Window window, Error *err);

TabpageArray vim_get_tabpages(void);

Tabpage vim_get_current_tabpage(void);

void vim_set_current_tabpage(Tabpage tabpage, Error *err);

void vim_subscribe(uint64_t channel_id, String event);

void vim_unsubscribe(uint64_t channel_id, String event);

#endif  // NVIM_API_VIM_H

