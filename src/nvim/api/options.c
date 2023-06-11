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
    set_option_value("bufhidden", STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL);
    set_option_value("buftype", STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL);
    set_option_value("swapfile", BOOLEAN_OPTVAL(false), OPT_LOCAL);
    set_option_value("modeline", BOOLEAN_OPTVAL(false), OPT_LOCAL);  // 'nomodeline'

    ftbuf->b_p_ft = xstrdup(filetype);
    do_filetype_autocmd(ftbuf, false);
  });

  return ftbuf;
}

/// Consume an OptVal and convert it to an API Object.
static Object optval_as_object(OptVal o)
{
  switch (o.type) {
  case kOptValTypeNil:
    return NIL;
  case kOptValTypeBoolean:
    switch (o.data.boolean) {
    case kFalse:
    case kTrue:
      return BOOLEAN_OBJ(o.data.boolean);
    case kNone:
      return NIL;
    default:
      abort();
    }
  case kOptValTypeNumber:
    return INTEGER_OBJ(o.data.number);
  case kOptValTypeString:
    return STRING_OBJ(o.data.string);
  default:
    abort();
  }
}

/// Consume an API Object and convert it to an OptVal.
static OptVal object_as_optval(Object o, bool *error)
{
  switch (o.type) {
  case kObjectTypeNil:
    return NIL_OPTVAL;
  case kObjectTypeBoolean:
    return BOOLEAN_OPTVAL(o.data.boolean);
  case kObjectTypeInteger:
    return NUMBER_OPTVAL(o.data.integer);
  case kObjectTypeString:
    return STRING_OPTVAL(o.data.string);
  default:
    *error = true;
    return NIL_OPTVAL;
  }
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
  OptVal value = NIL_OPTVAL;

  int scope = 0;
  int opt_type = SREQ_GLOBAL;
  void *from = NULL;
  char *filetype = NULL;

  if (!validate_option_value_args(opts, &scope, &opt_type, &from, &filetype, err)) {
    goto err;
  }

  aco_save_T aco;

  buf_T *ftbuf = do_ft_buf(filetype, &aco, err);
  if (ERROR_SET(err)) {
    goto err;
  }

  if (ftbuf != NULL) {
    assert(!from);
    from = ftbuf;
  }

  bool hidden;
  value = get_option_value_for(name.data, NULL, scope, &hidden, opt_type, from, err);

  if (ftbuf != NULL) {
    // restore curwin/curbuf and a few other things
    aucmd_restbuf(&aco);

    assert(curbuf != ftbuf);  // safety check
    wipe_buffer(ftbuf, false);
  }

  if (ERROR_SET(err)) {
    goto err;
  }

  VALIDATE_S(!hidden && value.type != kOptValTypeNil, "option", name.data, {
    goto err;
  });

  return optval_as_object(value);
err:
  optval_free(value);
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

  bool error = false;
  OptVal optval = object_as_optval(value, &error);

  // Handle invalid option value type.
  if (error) {
    // Don't use `name` in the error message here, because `name` can be any String.
    VALIDATE_EXP(false, "value", "Integer/Boolean/String", api_typename(value.type), {
      return;
    });
  }

  WITH_SCRIPT_CONTEXT(channel_id, {
    set_option_value_for(name.data, optval, scope, opt_type, to, err);
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

/// Switch current context to get/set option value for window/buffer.
///
/// @param[out]  ctx       Current context. switchwin_T for window and aco_save_T for buffer.
/// @param[in]   opt_type  Option type. See SREQ_* in option_defs.h.
/// @param[in]   from      Target buffer/window.
/// @param[out]  err       Error message, if any.
///
/// @return  true if context was switched, false otherwise.
static bool switch_option_context(void *const ctx, int opt_type, void *const from, Error *err)
{
  switch (opt_type) {
  case SREQ_WIN: {
    win_T *const win = (win_T *)from;
    switchwin_T *const switchwin = (switchwin_T *)ctx;

    if (win == curwin) {
      return false;
    }

    if (switch_win_noblock(switchwin, win, win_find_tabpage(win), true)
        == FAIL) {
      restore_win_noblock(switchwin, true);

      if (try_end(err)) {
        return false;
      }
      api_set_error(err, kErrorTypeException, "Problem while switching windows");
      return false;
    }
    return true;
  }
  case SREQ_BUF: {
    buf_T *const buf = (buf_T *)from;
    aco_save_T *const aco = (aco_save_T *)ctx;

    if (buf == curbuf) {
      return false;
    }
    aucmd_prepbuf(aco, buf);
    return true;
  }
  case SREQ_GLOBAL:
    return false;
  default:
    abort();  // This should never happen.
  }
}

/// Restore context after getting/setting option for window/buffer. See switch_option_context() for
/// params.
static void restore_option_context(void *const ctx, const int opt_type)
{
  switch (opt_type) {
  case SREQ_WIN:
    restore_win_noblock((switchwin_T *)ctx, true);
    break;
  case SREQ_BUF:
    aucmd_restbuf((aco_save_T *)ctx);
    break;
  case SREQ_GLOBAL:
    break;
  default:
    abort();  // This should never happen.
  }
}

/// Get option value for buffer / window.
///
/// @param[in]   name      Option name.
/// @param[out]  flagsp    Set to the option flags (P_xxxx) (if not NULL).
/// @param[in]   scope     Option scope (can be OPT_LOCAL, OPT_GLOBAL or a combination).
/// @param[out]  hidden    Whether option is hidden.
/// @param[in]   opt_type  Option type. See SREQ_* in option_defs.h.
/// @param[in]   from      Target buffer/window.
/// @param[out]  err       Error message, if any.
///
/// @return  Option value. Must be freed by caller.
OptVal get_option_value_for(const char *const name, uint32_t *flagsp, int scope, bool *hidden,
                            const int opt_type, void *const from, Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = opt_type == SREQ_WIN ? (void *)&switchwin
                                   : (opt_type == SREQ_BUF ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, opt_type, from, err);
  if (ERROR_SET(err)) {
    return NIL_OPTVAL;
  }

  OptVal retv = get_option_value(name, flagsp, scope, hidden);

  if (switched) {
    restore_option_context(ctx, opt_type);
  }

  return retv;
}

/// Set option value for buffer / window.
///
/// @param[in]   name       Option name.
/// @param[in]   value      Option value.
/// @param[in]   opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///                         If OPT_CLEAR is set, the value of the option
///                         is cleared  (the exact semantics of this depend
///                         on the option).
/// @param[in]   opt_type   Option type. See SREQ_* in option_defs.h.
/// @param[in]   from       Target buffer/window.
/// @param[out]  err        Error message, if any.
void set_option_value_for(const char *const name, OptVal value, const int opt_flags,
                          const int opt_type, void *const from, Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = opt_type == SREQ_WIN ? (void *)&switchwin
                                   : (opt_type == SREQ_BUF ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, opt_type, from, err);
  if (ERROR_SET(err)) {
    return;
  }

  const char *const errmsg = set_option_value(name, value, opt_flags);
  if (errmsg) {
    api_set_error(err, kErrorTypeException, "%s", errmsg);
  }

  if (switched) {
    restore_option_context(ctx, opt_type);
  }
}
