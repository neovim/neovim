#ifndef NEOVIM_API_HELPERS_H
#define NEOVIM_API_HELPERS_H

#include <stdbool.h>

#include "api/defs.h"
#include "../vim.h"

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
/// @param bool If true it will pop the value from the dict
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, bool pop, Error *err);

/// Set a value in a dict. Objects are recursively expanded into their
/// vimscript equivalents.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param[out] err Details of an error that may have occurred
/// @return the old value, if any
Object dict_set_value(dict_T *dict, String key, Object value, Error *err);

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
Object vim_to_object(typval_T *obj);

#endif /* NEOVIM_API_HELPERS_H */

