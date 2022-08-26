// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/options.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/options.c.generated.h"
#endif

static int validate_option_value_args(Dict(option) *opts, int *scope, int *opt_type, void **from,
                                      Error *err)
{
  if (opts->scope.type == kObjectTypeString) {
    if (!strcmp(opts->scope.data.string.data, "local")) {
      *scope = OPT_LOCAL;
    } else if (!strcmp(opts->scope.data.string.data, "global")) {
      *scope = OPT_GLOBAL;
    } else {
      api_set_error(err, kErrorTypeValidation, "invalid scope: must be 'local' or 'global'");
      return FAIL;
    }
  } else if (HAS_KEY(opts->scope)) {
    api_set_error(err, kErrorTypeValidation, "invalid value for key: scope");
    return FAIL;
  }

  *opt_type = SREQ_GLOBAL;

  if (opts->win.type == kObjectTypeInteger) {
    *opt_type = SREQ_WIN;
    *from = find_window_by_handle((int)opts->win.data.integer, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  } else if (HAS_KEY(opts->win)) {
    api_set_error(err, kErrorTypeValidation, "invalid value for key: win");
    return FAIL;
  }

  if (opts->buf.type == kObjectTypeInteger) {
    *scope = OPT_LOCAL;
    *opt_type = SREQ_BUF;
    *from = find_buffer_by_handle((int)opts->buf.data.integer, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  } else if (HAS_KEY(opts->buf)) {
    api_set_error(err, kErrorTypeValidation, "invalid value for key: buf");
    return FAIL;
  }

  if (HAS_KEY(opts->scope) && HAS_KEY(opts->buf)) {
    api_set_error(err, kErrorTypeValidation, "scope and buf cannot be used together");
    return FAIL;
  }

  if (HAS_KEY(opts->win) && HAS_KEY(opts->buf)) {
    api_set_error(err, kErrorTypeValidation, "buf and win cannot be used together");
    return FAIL;
  }

  return OK;
}

/// Gets the value of an option. The behavior of this function matches that of
/// |:set|: the local value of an option is returned if it exists; otherwise,
/// the global value is returned. Local values always correspond to the current
/// buffer or window, unless "buf" or "win" is set in {opts}.
///
/// @param name      Option name
/// @param opts      Optional parameters
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - win: |window-ID|. Used for getting window local options.
///                  - buf: Buffer number. Used for getting buffer local options.
///                         Implies {scope} is "local".
/// @param[out] err  Error details, if any
/// @return          Option value
Object nvim_get_option_value(String name, Dict(option) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  Object rv = OBJECT_INIT;

  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *from = NULL;
  if (!validate_option_value_args(opts, &scope, &opt_type, &from, err)) {
    return rv;
  }

  long numval = 0;
  char *stringval = NULL;
  getoption_T result = access_option_value_for(name.data, &numval, &stringval, scope, opt_type,
                                               from, true, err);
  if (ERROR_SET(err)) {
    return rv;
  }

  switch (result) {
  case gov_string:
    rv = STRING_OBJ(cstr_as_string(stringval));
    break;
  case gov_number:
    rv = INTEGER_OBJ(numval);
    break;
  case gov_bool:
    switch (numval) {
    case 0:
    case 1:
      rv = BOOLEAN_OBJ(numval);
      break;
    default:
      // Boolean options that return something other than 0 or 1 should return nil. Currently this
      // only applies to 'autoread' which uses -1 as a local value to indicate "unset"
      rv = NIL;
      break;
    }
    break;
  default:
    api_set_error(err, kErrorTypeValidation, "unknown option '%s'", name.data);
    return rv;
  }

  return rv;
}

/// Sets the value of an option. The behavior of this function matches that of
/// |:set|: for global-local options, both the global and local value are set
/// unless otherwise specified with {scope}.
///
/// Note the options {win} and {buf} cannot be used together.
///
/// @param name      Option name
/// @param value     New option value
/// @param opts      Optional parameters
///                  - scope: One of 'global' or 'local'. Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - win: |window-ID|. Used for setting window local option.
///                  - buf: Buffer number. Used for setting buffer local option.
/// @param[out] err  Error details, if any
void nvim_set_option_value(String name, Object value, Dict(option) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *to = NULL;
  if (!validate_option_value_args(opts, &scope, &opt_type, &to, err)) {
    return;
  }

  // If:
  // - window id is provided
  // - scope is not provided
  // - option is global or local to window (global-local)
  //
  // Then force scope to local since we don't want to change the global option
  if (opt_type == SREQ_WIN && scope == 0) {
    int flags = get_option_value_strict(name.data, NULL, NULL, opt_type, to);
    if (flags & SOPT_GLOBAL) {
      scope = OPT_LOCAL;
    }
  }

  long numval = 0;
  char *stringval = NULL;

  switch (value.type) {
  case kObjectTypeInteger:
    numval = value.data.integer;
    break;
  case kObjectTypeBoolean:
    numval = value.data.boolean ? 1 : 0;
    break;
  case kObjectTypeString:
    stringval = value.data.string.data;
    break;
  case kObjectTypeNil:
    scope |= OPT_CLEAR;
    break;
  default:
    api_set_error(err, kErrorTypeValidation, "invalid value for option");
    return;
  }

  access_option_value_for(name.data, &numval, &stringval, scope, opt_type, to, false, err);
}

/// Gets the option information for all options.
///
/// The dictionary has the full option names as keys and option metadata
/// dictionaries as detailed at |nvim_get_option_info|.
///
/// @return dictionary of all options
Dictionary nvim_get_all_options_info(Error *err)
  FUNC_API_SINCE(7)
{
  return get_all_vimoptions();
}

/// Gets the option information for one option
///
/// Resulting dictionary has keys:
///     - name: Name of the option (like 'filetype')
///     - shortname: Shortened name of the option (like 'ft')
///     - type: type of option ("string", "number" or "boolean")
///     - default: The default value for the option
///     - was_set: Whether the option was set.
///
///     - last_set_sid: Last set script id (if any)
///     - last_set_linenr: line number where option was set
///     - last_set_chan: Channel where option was set (0 for local)
///
///     - scope: one of "global", "win", or "buf"
///     - global_local: whether win or buf option has a global value
///
///     - commalist: List of comma separated values
///     - flaglist: List of single char flags
///
///
/// @param          name Option name
/// @param[out] err Error details, if any
/// @return         Option Information
Dictionary nvim_get_option_info(String name, Error *err)
  FUNC_API_SINCE(7)
{
  return get_vimoption(name, err);
}
/// Sets the global value of an option.
///
/// @param channel_id
/// @param name     Option name
/// @param value    New option value
/// @param[out] err Error details, if any
void nvim_set_option(uint64_t channel_id, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  set_option_to(channel_id, NULL, SREQ_GLOBAL, name, value, err);
}

/// Gets the global value of an option.
///
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return         Option value (global)
Object nvim_get_option(String name, Error *err)
  FUNC_API_SINCE(1)
{
  return get_option_from(NULL, SREQ_GLOBAL, name, err);
}

/// Gets a buffer option value
///
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Option name
/// @param[out] err   Error details, if any
/// @return Option value
Object nvim_buf_get_option(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return (Object)OBJECT_INIT;
  }

  return get_option_from(buf, SREQ_BUF, name, err);
}

/// Sets a buffer option value. Passing `nil` as value deletes the option (only
/// works if there's a global fallback)
///
/// @param channel_id
/// @param buffer     Buffer handle, or 0 for current buffer
/// @param name       Option name
/// @param value      Option value
/// @param[out] err   Error details, if any
void nvim_buf_set_option(uint64_t channel_id, Buffer buffer, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);

  if (!buf) {
    return;
  }

  set_option_to(channel_id, buf, SREQ_BUF, name, value, err);
}

/// Gets a window option value
///
/// @param window   Window handle, or 0 for current window
/// @param name     Option name
/// @param[out] err Error details, if any
/// @return Option value
Object nvim_win_get_option(Window window, String name, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return (Object)OBJECT_INIT;
  }

  return get_option_from(win, SREQ_WIN, name, err);
}

/// Sets a window option value. Passing `nil` as value deletes the option (only
/// works if there's a global fallback)
///
/// @param channel_id
/// @param window   Window handle, or 0 for current window
/// @param name     Option name
/// @param value    Option value
/// @param[out] err Error details, if any
void nvim_win_set_option(uint64_t channel_id, Window window, String name, Object value, Error *err)
  FUNC_API_SINCE(1)
{
  win_T *win = find_window_by_handle(window, err);

  if (!win) {
    return;
  }

  set_option_to(channel_id, win, SREQ_WIN, name, value, err);
}

/// Gets the value of a global or local (buffer, window) option.
///
/// @param from If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return the option value
Object get_option_from(void *from, int type, String name, Error *err)
{
  Object rv = OBJECT_INIT;

  if (name.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Empty option name");
    return rv;
  }

  // Return values
  int64_t numval;
  char *stringval = NULL;
  int flags = get_option_value_strict(name.data, &numval, &stringval,
                                      type, from);

  if (!flags) {
    api_set_error(err, kErrorTypeValidation, "Invalid option name: '%s'",
                  name.data);
    return rv;
  }

  if (flags & SOPT_BOOL) {
    rv.type = kObjectTypeBoolean;
    rv.data.boolean = numval ? true : false;
  } else if (flags & SOPT_NUM) {
    rv.type = kObjectTypeInteger;
    rv.data.integer = numval;
  } else if (flags & SOPT_STRING) {
    if (stringval) {
      rv.type = kObjectTypeString;
      rv.data.string.data = stringval;
      rv.data.string.size = strlen(stringval);
    } else {
      api_set_error(err, kErrorTypeException,
                    "Failed to get value for option '%s'",
                    name.data);
    }
  } else {
    api_set_error(err,
                  kErrorTypeException,
                  "Unknown type for option '%s'",
                  name.data);
  }

  return rv;
}

/// Sets the value of a global or local (buffer, window) option.
///
/// @param to If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
void set_option_to(uint64_t channel_id, void *to, int type, String name, Object value, Error *err)
{
  if (name.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Empty option name");
    return;
  }

  int flags = get_option_value_strict(name.data, NULL, NULL, type, to);

  if (flags == 0) {
    api_set_error(err, kErrorTypeValidation, "Invalid option name '%s'",
                  name.data);
    return;
  }

  if (value.type == kObjectTypeNil) {
    if (type == SREQ_GLOBAL) {
      api_set_error(err, kErrorTypeException, "Cannot unset option '%s'",
                    name.data);
      return;
    } else if (!(flags & SOPT_GLOBAL)) {
      api_set_error(err,
                    kErrorTypeException,
                    "Cannot unset option '%s' "
                    "because it doesn't have a global value",
                    name.data);
      return;
    } else {
      unset_global_local_option(name.data, to);
      return;
    }
  }

  long numval = 0;
  char *stringval = NULL;

  if (flags & SOPT_BOOL) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Option '%s' requires a Boolean value",
                    name.data);
      return;
    }

    numval = value.data.boolean;
  } else if (flags & SOPT_NUM) {
    if (value.type != kObjectTypeInteger) {
      api_set_error(err, kErrorTypeValidation,
                    "Option '%s' requires an integer value",
                    name.data);
      return;
    }

    if (value.data.integer > INT_MAX || value.data.integer < INT_MIN) {
      api_set_error(err, kErrorTypeValidation,
                    "Value for option '%s' is out of range",
                    name.data);
      return;
    }

    numval = (int)value.data.integer;
  } else {
    if (value.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation,
                    "Option '%s' requires a string value",
                    name.data);
      return;
    }

    stringval = value.data.string.data;
  }

  // For global-win-local options -> setlocal
  // For        win-local options -> setglobal and setlocal (opt_flags == 0)
  const int opt_flags = (type == SREQ_WIN && !(flags & SOPT_GLOBAL)) ? 0 :
                        (type == SREQ_GLOBAL)                        ? OPT_GLOBAL : OPT_LOCAL;

  WITH_SCRIPT_CONTEXT(channel_id, {
    access_option_value_for(name.data, &numval, &stringval, opt_flags, type, to, false, err);
  });
}

static getoption_T access_option_value(char *key, long *numval, char **stringval, int opt_flags,
                                       bool get, Error *err)
{
  if (get) {
    return get_option_value(key, numval, stringval, opt_flags);
  } else {
    char *errmsg;
    if ((errmsg = set_option_value(key, *numval, *stringval, opt_flags))) {
      if (try_end(err)) {
        return 0;
      }

      api_set_error(err, kErrorTypeException, "%s", errmsg);
    }
    return 0;
  }
}

static getoption_T access_option_value_for(char *key, long *numval, char **stringval, int opt_flags,
                                           int opt_type, void *from, bool get, Error *err)
{
  bool need_switch = false;
  switchwin_T switchwin;
  aco_save_T aco;
  getoption_T result = 0;

  try_start();
  switch (opt_type) {
  case SREQ_WIN:
    need_switch = (win_T *)from != curwin;
    if (need_switch) {
      if (switch_win_noblock(&switchwin, (win_T *)from, win_find_tabpage((win_T *)from), true)
          == FAIL) {
        restore_win_noblock(&switchwin, true);
        if (try_end(err)) {
          return result;
        }
        api_set_error(err, kErrorTypeException, "Problem while switching windows");
        return result;
      }
    }
    result = access_option_value(key, numval, stringval, opt_flags, get, err);
    if (need_switch) {
      restore_win_noblock(&switchwin, true);
    }
    break;
  case SREQ_BUF:
    need_switch = (buf_T *)from != curbuf;
    if (need_switch) {
      aucmd_prepbuf(&aco, (buf_T *)from);
    }
    result = access_option_value(key, numval, stringval, opt_flags, get, err);
    if (need_switch) {
      aucmd_restbuf(&aco);
    }
    break;
  case SREQ_GLOBAL:
    result = access_option_value(key, numval, stringval, opt_flags, get, err);
    break;
  }

  if (ERROR_SET(err)) {
    return result;
  }

  try_end(err);

  return result;
}
