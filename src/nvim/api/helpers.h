#ifndef NVIM_API_HELPERS_H
#define NVIM_API_HELPERS_H

#include <stdbool.h>

#include "nvim/api/defs.h"
#include "nvim/vim.h"

#define set_api_error(message, err)                \
  do {                                             \
    strncpy(err->msg, message, sizeof(err->msg));  \
    err->set = true;                               \
  } while (0)

/// Start block that may cause vimscript exceptions
void try_start(void);

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
bool try_end(Error *err);

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Error *err);

/// Set a value in a dict. Objects are recursively expanded into their
/// vimscript equivalents. Passing 'nil' as value deletes the key.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param[out] err Details of an error that may have occurred
/// @return the old value, if any
Object dict_set_value(dict_T *dict, String key, Object value, Error *err);

/// Gets the value of a global or local(buffer, window) option.
///
/// @param from If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return the option value
Object get_option_from(void *from, int type, String name, Error *err);

/// Sets the value of a global or local(buffer, window) option.
///
/// @param to If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
void set_option_to(void *to, int type, String name, Object value, Error *err);

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
Object vim_to_object(typval_T *obj);

/// Finds the pointer for a window number
///
/// @param window the window number
/// @param[out] err Details of an error that may have occurred
/// @return the window pointer
buf_T *find_buffer(Buffer buffer, Error *err);

/// Finds the pointer for a window number
///
/// @param window the window number
/// @param[out] err Details of an error that may have occurred
/// @return the window pointer
win_T * find_window(Window window, Error *err);

/// Finds the pointer for a tabpage number
///
/// @param tabpage the tabpage number
/// @param[out] err Details of an error that may have occurred
/// @return the tabpage pointer
tabpage_T * find_tab(Tabpage tabpage, Error *err);

/// Copies a C string into a String (binary safe string, characters + length)
///
/// @param str the C string to copy
/// @return the resulting String, if the input string was NULL, then an
///         empty String is returned
String cstr_to_string(const char *str);

#endif  // NVIM_API_HELPERS_H

