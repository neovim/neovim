#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#define set_api_error(message, err)                \
  do {                                             \
    xstrlcpy(err->msg, message, sizeof(err->msg)); \
    err->set = true;                               \
  } while (0)

void try_start(void);

bool try_end(Error *err);

Object dict_get_value(dict_T *dict, String key, Error *err);

Object dict_set_value(dict_T *dict, String key, Object value, Error *err);

Object get_option_from(void *from, int type, String name, Error *err);

void set_option_to(void *to, int type, String name, Object value, Error *err);

Object vim_to_object(typval_T *obj);

buf_T *find_buffer(Buffer buffer, Error *err);

win_T * find_window(Window window, Error *err);

tabpage_T * find_tab(Tabpage tabpage, Error *err);

/// Copies a C string into a String (binary safe string, characters + length)
///
/// @param str the C string to copy
/// @return the resulting String, if the input string was NULL, then an
///         empty String is returned
String cstr_to_string(const char *str);

#endif  // NVIM_API_PRIVATE_HELPERS_H

