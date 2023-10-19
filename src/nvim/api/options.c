// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/keysets.h"
#include "nvim/api/options.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/eval/window.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/options.c.generated.h"
#endif

static int validate_option_value_args(Dict(option) *opts, char *name, int *scope,
                                      OptReqScope *req_scope, void **from, char **filetype,
                                      Error *err)
{
#define HAS_KEY_X(d, v) HAS_KEY(d, option, v)
  if (HAS_KEY_X(opts, scope)) {
    if (!strcmp(opts->scope.data, "local")) {
      *scope = OPT_LOCAL;
    } else if (!strcmp(opts->scope.data, "global")) {
      *scope = OPT_GLOBAL;
    } else {
      VALIDATE_EXP(false, "scope", "'local' or 'global'", NULL, {
        return FAIL;
      });
    }
  }

  *req_scope = kOptReqGlobal;

  if (filetype != NULL && HAS_KEY_X(opts, filetype)) {
    *filetype = opts->filetype.data;
  }

  if (HAS_KEY_X(opts, win)) {
    *req_scope = kOptReqWin;
    *from = find_window_by_handle(opts->win, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  if (HAS_KEY_X(opts, buf)) {
    *scope = OPT_LOCAL;
    *req_scope = kOptReqBuf;
    *from = find_buffer_by_handle(opts->buf, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  VALIDATE((!HAS_KEY_X(opts, filetype)
            || !(HAS_KEY_X(opts, buf) || HAS_KEY_X(opts, scope) || HAS_KEY_X(opts, win))),
           "%s", "cannot use 'filetype' with 'scope', 'buf' or 'win'", {
    return FAIL;
  });

  VALIDATE((!HAS_KEY_X(opts, scope) || !HAS_KEY_X(opts, buf)), "%s",
           "cannot use both 'scope' and 'buf'", {
    return FAIL;
  });

  VALIDATE((!HAS_KEY_X(opts, win) || !HAS_KEY_X(opts, buf)),
           "%s", "cannot use both 'buf' and 'win'", {
    return FAIL;
  });

  int flags = get_option_attrs(name);
  if (flags == 0) {
    // hidden or unknown option
    api_set_error(err, kErrorTypeValidation, "Unknown option '%s'", name);
  } else if (*req_scope == kOptReqBuf || *req_scope == kOptReqWin) {
    // if 'buf' or 'win' is passed, make sure the option supports it
    int req_flags = *req_scope == kOptReqBuf ? SOPT_BUF : SOPT_WIN;
    if (!(flags & req_flags)) {
      char *tgt = *req_scope & kOptReqBuf ? "buf" : "win";
      char *global = flags & SOPT_GLOBAL ? "global ": "";
      char *req = flags & SOPT_BUF ? "buffer-local " :
                  flags & SOPT_WIN ? "window-local " : "";

      api_set_error(err, kErrorTypeValidation, "'%s' cannot be passed for %s%soption '%s'",
                    tgt, global, req, name);
    }
  }

  return OK;
#undef HAS_KEY_X
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
  OptReqScope req_scope = kOptReqGlobal;
  void *from = NULL;
  char *filetype = NULL;

  if (!validate_option_value_args(opts, name.data, &scope, &req_scope, &from, &filetype, err)) {
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
  value = get_option_value_for(name.data, NULL, scope, &hidden, req_scope, from, err);

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
  OptReqScope req_scope = kOptReqGlobal;
  void *to = NULL;
  if (!validate_option_value_args(opts, name.data, &scope, &req_scope, &to, NULL, err)) {
    return;
  }

  // If:
  // - window id is provided
  // - scope is not provided
  // - option is global or local to window (global-local)
  //
  // Then force scope to local since we don't want to change the global option
  if (req_scope == kOptReqWin && scope == 0) {
    int flags = get_option_attrs(name.data);
    if (flags & SOPT_GLOBAL) {
      scope = OPT_LOCAL;
    }
  }

  bool error = false;
  OptVal optval = object_as_optval(value, &error);

  // Handle invalid option value type.
  // Don't use `name` in the error message here, because `name` can be any String.
  // No need to check if value type actually matches the types for the option, as set_option_value()
  // already handles that.
  VALIDATE_EXP(!error, "value", "valid option type", api_typename(value.type), {
    return;
  });

  WITH_SCRIPT_CONTEXT(channel_id, {
    set_option_value_for(name.data, optval, scope, req_scope, to, err);
  });
}

/// Gets the option information for all options.
///
/// The dictionary has the full option names as keys and option metadata
/// dictionaries as detailed at |nvim_get_option_info2()|.
///
/// @see |nvim_get_commands()|
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
  OptReqScope req_scope = kOptReqGlobal;
  void *from = NULL;
  if (!validate_option_value_args(opts, name.data, &scope, &req_scope, &from, NULL, err)) {
    return (Dictionary)ARRAY_DICT_INIT;
  }

  buf_T *buf = (req_scope == kOptReqBuf) ? (buf_T *)from : curbuf;
  win_T *win = (req_scope == kOptReqWin) ? (win_T *)from : curwin;

  return get_vimoption(name, scope, buf, win, err);
}

/// Switch current context to get/set option value for window/buffer.
///
/// @param[out]  ctx        Current context. switchwin_T for window and aco_save_T for buffer.
/// @param       req_scope  Requested option scope. See OptReqScope in option.h.
/// @param[in]   from       Target buffer/window.
/// @param[out]  err        Error message, if any.
///
/// @return  true if context was switched, false otherwise.
static bool switch_option_context(void *const ctx, OptReqScope req_scope, void *const from,
                                  Error *err)
{
  switch (req_scope) {
  case kOptReqWin: {
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
  case kOptReqBuf: {
    buf_T *const buf = (buf_T *)from;
    aco_save_T *const aco = (aco_save_T *)ctx;

    if (buf == curbuf) {
      return false;
    }
    aucmd_prepbuf(aco, buf);
    return true;
  }
  case kOptReqGlobal:
    return false;
  }
  UNREACHABLE;
}

/// Restore context after getting/setting option for window/buffer. See switch_option_context() for
/// params.
static void restore_option_context(void *const ctx, OptReqScope req_scope)
{
  switch (req_scope) {
  case kOptReqWin:
    restore_win_noblock((switchwin_T *)ctx, true);
    break;
  case kOptReqBuf:
    aucmd_restbuf((aco_save_T *)ctx);
    break;
  case kOptReqGlobal:
    break;
  }
}

/// Get attributes for an option.
///
/// @param  name  Option name.
///
/// @return  Option attributes.
///          0 for hidden or unknown option.
///          See SOPT_* in option_defs.h for other flags.
int get_option_attrs(char *name)
{
  int opt_idx = findoption(name);

  if (opt_idx < 0) {
    return 0;
  }

  vimoption_T *opt = get_option(opt_idx);

  if (is_tty_option(opt->fullname)) {
    return SOPT_STRING | SOPT_GLOBAL;
  }

  // Hidden option
  if (opt->var == NULL) {
    return 0;
  }

  int attrs = 0;

  if (opt->flags & P_BOOL) {
    attrs |= SOPT_BOOL;
  } else if (opt->flags & P_NUM) {
    attrs |= SOPT_NUM;
  } else if (opt->flags & P_STRING) {
    attrs |= SOPT_STRING;
  }

  if (opt->indir == PV_NONE || (opt->indir & PV_BOTH)) {
    attrs |= SOPT_GLOBAL;
  }
  if (opt->indir & PV_WIN) {
    attrs |= SOPT_WIN;
  } else if (opt->indir & PV_BUF) {
    attrs |= SOPT_BUF;
  }

  return attrs;
}

/// Check if option has a value in the requested scope.
///
/// @param  name       Option name.
/// @param  req_scope  Requested option scope. See OptReqScope in option.h.
///
/// @return  true if option has a value in the requested scope, false otherwise.
static bool option_has_scope(char *name, OptReqScope req_scope)
{
  int opt_idx = findoption(name);

  if (opt_idx < 0) {
    return false;
  }

  vimoption_T *opt = get_option(opt_idx);

  // Hidden option.
  if (opt->var == NULL) {
    return false;
  }
  // TTY option.
  if (is_tty_option(opt->fullname)) {
    return req_scope == kOptReqGlobal;
  }

  switch (req_scope) {
  case kOptReqGlobal:
    return opt->var != VAR_WIN;
  case kOptReqBuf:
    return opt->indir & PV_BUF;
  case kOptReqWin:
    return opt->indir & PV_WIN;
  }
  UNREACHABLE;
}

/// Get the option value in the requested scope.
///
/// @param       name       Option name.
/// @param       req_scope  Requested option scope. See OptReqScope in option.h.
/// @param[in]   from       Pointer to buffer or window for local option value.
/// @param[out]  err        Error message, if any.
///
/// @return  Option value in the requested scope. Returns a Nil option value if option is not found,
/// hidden or if it isn't present in the requested scope. (i.e. has no global, window-local or
/// buffer-local value depending on opt_scope).
OptVal get_option_value_strict(char *name, OptReqScope req_scope, void *from, Error *err)
{
  OptVal retv = NIL_OPTVAL;

  if (!option_has_scope(name, req_scope)) {
    return retv;
  }
  if (get_tty_option(name, &retv.data.string.data)) {
    retv.type = kOptValTypeString;
    return retv;
  }

  int opt_idx = findoption(name);
  assert(opt_idx != 0);  // option_has_scope() already verifies if option name is valid.

  vimoption_T *opt = get_option(opt_idx);
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = req_scope == kOptReqWin ? (void *)&switchwin
                                    : (req_scope == kOptReqBuf ? (void *)&aco : NULL);
  bool switched = switch_option_context(ctx, req_scope, from, err);
  if (ERROR_SET(err)) {
    return retv;
  }

  char *varp = get_varp_scope(opt, req_scope == kOptReqGlobal ? OPT_GLOBAL : OPT_LOCAL);
  retv = optval_from_varp(opt_idx, varp);

  if (switched) {
    restore_option_context(ctx, req_scope);
  }

  return retv;
}

/// Get option value for buffer / window.
///
/// @param[in]   name       Option name.
/// @param[out]  flagsp     Set to the option flags (P_xxxx) (if not NULL).
/// @param[in]   scope      Option scope (can be OPT_LOCAL, OPT_GLOBAL or a combination).
/// @param[out]  hidden     Whether option is hidden.
/// @param       req_scope  Requested option scope. See OptReqScope in option.h.
/// @param[in]   from       Target buffer/window.
/// @param[out]  err        Error message, if any.
///
/// @return  Option value. Must be freed by caller.
OptVal get_option_value_for(const char *const name, uint32_t *flagsp, int scope, bool *hidden,
                            const OptReqScope req_scope, void *const from, Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = req_scope == kOptReqWin ? (void *)&switchwin
                                      : (req_scope == kOptReqBuf ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, req_scope, from, err);
  if (ERROR_SET(err)) {
    return NIL_OPTVAL;
  }

  OptVal retv = get_option_value(name, flagsp, scope, hidden);

  if (switched) {
    restore_option_context(ctx, req_scope);
  }

  return retv;
}

/// Set option value for buffer / window.
///
/// @param[in]   name        Option name.
/// @param[in]   value       Option value.
/// @param[in]   opt_flags   Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
/// @param       req_scope   Requested option scope. See OptReqScope in option.h.
/// @param[in]   from        Target buffer/window.
/// @param[out]  err         Error message, if any.
void set_option_value_for(const char *const name, OptVal value, const int opt_flags,
                          const OptReqScope req_scope, void *const from, Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = req_scope == kOptReqWin ? (void *)&switchwin
                                      : (req_scope == kOptReqBuf ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, req_scope, from, err);
  if (ERROR_SET(err)) {
    return;
  }

  const char *const errmsg = set_option_value(name, value, opt_flags);
  if (errmsg) {
    api_set_error(err, kErrorTypeException, "%s", errmsg);
  }

  if (switched) {
    restore_option_context(ctx, req_scope);
  }
}
