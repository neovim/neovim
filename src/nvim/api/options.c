// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/api/options.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/window.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/options.c.generated.h"
#endif

static int validate_option_value_args(Dict(option) *opts, int *scope, int *opt_type, void **from,
                                      char **filetype, Error *err)
{
  if (HAS_KEY(opts->scope)) {
    VALIDATE_T("scope", kObjectTypeString, opts->scope.type, {
      return FAIL;
    });

    if (!strcmp(opts->scope.data.string.data, "local")) {
      *scope = OPT_LOCAL;
    } else if (!strcmp(opts->scope.data.string.data, "global")) {
      *scope = OPT_GLOBAL;
    } else {
      VALIDATE_EXP(false, "scope", "'local' or 'global'", NULL, {
        return FAIL;
      });
    }
  }

  *opt_type = SREQ_GLOBAL;

  if (filetype != NULL && HAS_KEY(opts->filetype)) {
    VALIDATE_T("scope", kObjectTypeString, opts->filetype.type, {
      return FAIL;
    });

    *filetype = opts->filetype.data.string.data;
  }

  if (HAS_KEY(opts->win)) {
    VALIDATE_T_HANDLE("win", kObjectTypeWindow, opts->win.type, {
      return FAIL;
    });

    *opt_type = SREQ_WIN;
    *from = find_window_by_handle((int)opts->win.data.integer, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  if (HAS_KEY(opts->buf)) {
    VALIDATE_T_HANDLE("buf", kObjectTypeBuffer, opts->buf.type, {
      return FAIL;
    });

    *scope = OPT_LOCAL;
    *opt_type = SREQ_BUF;
    *from = find_buffer_by_handle((int)opts->buf.data.integer, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  VALIDATE((!HAS_KEY(opts->filetype)
            || !(HAS_KEY(opts->buf) || HAS_KEY(opts->scope) || HAS_KEY(opts->win))),
           "%s", "cannot use 'filetype' with 'scope', 'buf' or 'win'", {
    return FAIL;
  });

  VALIDATE((!HAS_KEY(opts->scope) || !HAS_KEY(opts->buf)), "%s",
           "cannot use both 'scope' and 'buf'", {
    return FAIL;
  });

  VALIDATE((!HAS_KEY(opts->win) || !HAS_KEY(opts->buf)), "%s", "cannot use both 'buf' and 'win'", {
    return FAIL;
  });

  return OK;
}

/// Create a dummy buffer and run the FileType autocmd on it.
static buf_T *do_ft_buf(char *filetype, aco_save_T *aco, Error *err)
{
  if (filetype == NULL) {
    return NULL;
  }

  // Allocate a buffer without putting it in the buffer list.
  buf_T *ftbuf = buflist_new(NULL, NULL, 1, BLN_DUMMY);
  if (ftbuf == NULL) {
    api_set_error(err, kErrorTypeException, "Could not create internal buffer");
    return NULL;
  }

  // Set curwin/curbuf to buf and save a few things.
  aucmd_prepbuf(aco, ftbuf);

  TRY_WRAP(err, {
    set_option_value("bufhidden", 0L, "hide", OPT_LOCAL);
    set_option_value("buftype", 0L, "nofile", OPT_LOCAL);
    set_option_value("swapfile", 0L, NULL, OPT_LOCAL);
    set_option_value("modeline", 0L, NULL, OPT_LOCAL);  // 'nomodeline'

    ftbuf->b_p_ft = xstrdup(filetype);
    do_filetype_autocmd(ftbuf, false);
  });

  return ftbuf;
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
///                  - filetype: |filetype|. Used to get the default option for a
///                    specific filetype. Cannot be used with any other option.
///                    Note: this will trigger |ftplugin| and all |FileType|
///                    autocommands for the corresponding filetype.
/// @param[out] err  Error details, if any
/// @return          Option value
Object nvim_get_option_value(String name, Dict(option) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  Object rv = OBJECT_INIT;

  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *from = NULL;
  char *filetype = NULL;

  if (!validate_option_value_args(opts, &scope, &opt_type, &from, &filetype, err)) {
    return rv;
  }

  aco_save_T aco;

  buf_T *ftbuf = do_ft_buf(filetype, &aco, err);
  if (ERROR_SET(err)) {
    return rv;
  }

  if (ftbuf != NULL) {
    assert(!from);
    from = ftbuf;
  }

  long numval = 0;
  char *stringval = NULL;
  getoption_T result = access_option_value_for(name.data, &numval, &stringval, scope, opt_type,
                                               from, true, err);

  if (ftbuf != NULL) {
    // restore curwin/curbuf and a few other things
    aucmd_restbuf(&aco);

    assert(curbuf != ftbuf);  // safety check
    wipe_buffer(ftbuf, false);
  }

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
    VALIDATE_S(false, "option", name.data, {
      return rv;
    });
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
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - win: |window-ID|. Used for setting window local option.
///                  - buf: Buffer number. Used for setting buffer local option.
/// @param[out] err  Error details, if any
void nvim_set_option_value(uint64_t channel_id, String name, Object value, Dict(option) *opts,
                           Error *err)
  FUNC_API_SINCE(9)
{
  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *to = NULL;
  if (!validate_option_value_args(opts, &scope, &opt_type, &to, NULL, err)) {
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
    numval = (long)value.data.integer;
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
    VALIDATE_EXP(false, name.data, "Integer/Boolean/String", api_typename(value.type), {
      return;
    });
  }

  WITH_SCRIPT_CONTEXT(channel_id, {
    access_option_value_for(name.data, &numval, &stringval, scope, opt_type, to, false, err);
  });
}

/// Gets the option information for all options.
///
/// The dictionary has the full option names as keys and option metadata
/// dictionaries as detailed at |nvim_get_option_info2()|.
///
/// @return dictionary of all options
Dictionary nvim_get_all_options_info(Error *err)
  FUNC_API_SINCE(7)
{
  return get_all_vimoptions();
}

/// Gets the option information for one option from arbitrary buffer or window
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
/// When {scope} is not provided, the last set information applies to the local
/// value in the current buffer or window if it is available, otherwise the
/// global value information is returned. This behavior can be disabled by
/// explicitly specifying {scope} in the {opts} table.
///
/// @param name      Option name
/// @param opts      Optional parameters
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - win: |window-ID|. Used for getting window local options.
///                  - buf: Buffer number. Used for getting buffer local options.
///                         Implies {scope} is "local".
/// @param[out] err Error details, if any
/// @return         Option Information
Dictionary nvim_get_option_info2(String name, Dict(option) *opts, Error *err)
  FUNC_API_SINCE(11)
{
  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *from = NULL;
  if (!validate_option_value_args(opts, &scope, &opt_type, &from, NULL, err)) {
    return (Dictionary)ARRAY_DICT_INIT;
  }

  buf_T *buf = (opt_type == SREQ_BUF) ? (buf_T *)from : curbuf;
  win_T *win = (opt_type == SREQ_WIN) ? (win_T *)from : curwin;

  return get_vimoption(name, scope, buf, win, err);
}

static getoption_T access_option_value(char *key, long *numval, char **stringval, int opt_flags,
                                       bool get, Error *err)
{
  if (get) {
    return get_option_value(key, numval, stringval, NULL, opt_flags);
  } else {
    const char *errmsg;
    if ((errmsg = set_option_value(key, *numval, *stringval, opt_flags))) {
      if (try_end(err)) {
        return 0;
      }

      api_set_error(err, kErrorTypeException, "%s", errmsg);
    }
    return 0;
  }
}

getoption_T access_option_value_for(char *key, long *numval, char **stringval, int opt_flags,
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
