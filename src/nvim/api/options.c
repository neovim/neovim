#include <assert.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/options.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/context.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#include "api/options.c.generated.h"

static int validate_option_value_args(Dict(option) *opts, char *name, bool allow_tab,
                                      OptIndex *opt_idxp, int *opt_flags, OptScope *scope,
                                      void **from, char **filetype, set_op_T *operation,
                                      bool *dry_run, Error *err)
{
#define HAS_KEY_X(d, v) HAS_KEY(d, option, v)
  // Validate incompatible argument combinations first, then resolve handles and scope.
  VALIDATE_CON(!HAS_KEY_X(opts, filetype)
               || (!HAS_KEY_X(opts, scope) && !HAS_KEY_X(opts, buf)
                   && !HAS_KEY_X(opts, win) && !HAS_KEY_X(opts, tab)),
               "filetype", "'scope', 'buf', 'win' or 'tab'", {
    return FAIL;
  });

  VALIDATE_CON(!HAS_KEY_X(opts, tab) || allow_tab, "tab", "this function", {
    return FAIL;
  });

  VALIDATE_CON(!HAS_KEY_X(opts, tab)
               || (!HAS_KEY_X(opts, win) && !HAS_KEY_X(opts, buf)
                   && !HAS_KEY_X(opts, filetype) && !HAS_KEY_X(opts, scope)),
               "tab", "'win', 'buf', 'filetype' or 'scope'", {
    return FAIL;
  });

  VALIDATE_CON(!(HAS_KEY_X(opts, win) && HAS_KEY_X(opts, buf)), "buf", "win", {
    return FAIL;
  });

  if (HAS_KEY_X(opts, scope)) {
    if (!strcmp(opts->scope.data, "local")) {
      *opt_flags = OPT_LOCAL;
    } else if (!strcmp(opts->scope.data, "global")) {
      *opt_flags = OPT_GLOBAL;
    } else {
      VALIDATE_EXP(false, "scope", "'local' or 'global'", NULL, {
        return FAIL;
      });
    }
  }

  *scope = kOptScopeGlobal;

  if (filetype != NULL && HAS_KEY_X(opts, filetype)) {
    *filetype = opts->filetype.data;
  }

  if (HAS_KEY_X(opts, win)) {
    *scope = kOptScopeWin;
    *from = find_window_by_handle(opts->win, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  if (HAS_KEY_X(opts, buf)) {
    VALIDATE_CON(!(HAS_KEY_X(opts, scope) && *opt_flags == OPT_GLOBAL), "buf", "global scope", {
      return FAIL;
    });
    *opt_flags = OPT_LOCAL;
    *scope = kOptScopeBuf;
    *from = find_buffer_by_handle(opts->buf, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  if (HAS_KEY_X(opts, tab)) {
    *scope = kOptScopeTab;
    *from = find_tab_by_handle(opts->tab, err);
    if (ERROR_SET(err)) {
      return FAIL;
    }
  }

  *opt_idxp = find_option(name);
  if (*opt_idxp == kOptInvalid) {
    // unknown option
    api_set_error(err, kErrorTypeValidation, "Unknown option '%s'", name);
    return FAIL;
  }

  if (operation != NULL && HAS_KEY_X(opts, operation)) {
    if (strequal(opts->operation.data, "set")) {
      *operation = OP_NONE;
    } else if (strequal(opts->operation.data, "append")) {
      *operation = OP_ADDING;
    } else if (strequal(opts->operation.data, "prepend")) {
      *operation = OP_PREPENDING;
    } else if (strequal(opts->operation.data, "remove")) {
      *operation = OP_REMOVING;
    } else {
      VALIDATE_EXP(false, "operation", "'set', 'append', 'prepend', or 'remove'", NULL, {
        return FAIL;
      });
    }

    VALIDATE_CON(*operation == OP_NONE || option_has_type(*opt_idxp,
                                                          kOptValTypeString)
                 || option_has_type(*opt_idxp, kOptValTypeNumber),
                 opts->operation.data,
                 "boolean options", {
      return FAIL;
    });
  }

  if (dry_run != NULL && HAS_KEY_X(opts, dry_run)) {
    *dry_run = opts->dry_run;
  }

  // Reject keys whose scope the option doesn't support.
  VALIDATE_CON(!HAS_KEY_X(opts, tab) || option_has_scope(*opt_idxp, kOptScopeTab),
               "tab", name, { return FAIL; });

  // If 'buf' or 'win' is passed, make sure the option supports it.
  if (*scope == kOptScopeBuf || *scope == kOptScopeWin) {
    if (!option_has_scope(*opt_idxp, *scope)) {
      char *tgt = *scope == kOptScopeBuf ? "buf" : "win";
      char *global = option_has_scope(*opt_idxp, kOptScopeGlobal) ? "global " : "";
      char *req = option_has_scope(*opt_idxp, kOptScopeBuf)
                  ? "buffer-local "
                  : (option_has_scope(*opt_idxp, kOptScopeWin) ? "window-local " : "");

      api_set_error(err, kErrorTypeValidation, "'%s' cannot be passed for %s%soption '%s'",
                    tgt, global, req, name);
      return FAIL;
    }
  }

  return ERROR_SET(err) ? FAIL : OK;
#undef HAS_KEY_X
}

/// Create a dummy buffer and run the FileType autocmd on it.
static buf_T *do_ft_buf(const char *filetype, CtxSwitch *aco, Error *err)
  FUNC_ATTR_NONNULL_ARG(2, 3)
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

  // Open a memline for use by autocommands.
  if (ml_open(ftbuf) == FAIL) {
    api_set_error(err, kErrorTypeException, "Could not load internal buffer");
    return ftbuf;
  }

  bufref_T bufref;
  set_bufref(&bufref, ftbuf);

  // Set curwin/curbuf to buf and save a few things.
  ctx_switch(aco, NULL, NULL, ftbuf, 0);

  set_option_direct(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("hide"), OPT_LOCAL, SID_NONE);
  set_option_direct(kOptBuftype, STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL, SID_NONE);
  assert(ftbuf->b_ml.ml_mfp->mf_fd < 0);  // ml_open() should not have opened swapfile already
  ftbuf->b_p_swf = false;
  ftbuf->b_p_ml = false;
  ftbuf->b_p_ft = xstrdup(filetype);

  if (!has_event(EVENT_FILETYPE)) {
    return ftbuf;  // Nothing more to do.
  }

  bool did_au_ft = false;
  TRY_WRAP(err, {
    did_au_ft = do_filetype_autocmd(ftbuf, true);
  });

  if (!bufref_valid(&bufref)) {
    if (!ERROR_SET(err)) {
      api_set_error(err, kErrorTypeException, "Internal buffer was deleted");
    }
    return NULL;
  }

  if (!did_au_ft && !ERROR_SET(err)) {
    api_set_error(err, kErrorTypeException, "Could not execute FileType autocommands");
  }
  return ftbuf;
}

static void wipe_ft_buf(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  block_autocmds();

  bufref_T bufref;
  set_bufref(&bufref, buf);

  close_windows(buf, false);
  // Autocommands are blocked, but 'bufhidden' may have wiped it already.
  // Also can't wipe if the buffer is somehow still in a window or current.
  if (bufref_valid(&bufref) && buf != curbuf && buf->b_nwindows == 0) {
    wipe_buffer(buf, false);
  }
  if (bufref_valid(&bufref)) {
    buf->b_flags &= ~BF_DUMMY;  // Couldn't wipe; keep it instead.
  }

  unblock_autocmds();
}

/// Gets the value of an option. The behavior of this function matches that of
/// |:set|: the local value of an option is returned if it exists; otherwise,
/// the global value is returned. Local values always correspond to the current
/// buffer or window, unless "buf" or "win" is set in {opts}.
///
/// @param name      Option name
/// @param opts      Optional parameters
///                  - buf: Buffer number. Used for getting buffer local options.
///                         Implies {scope} is "local".
///                  - filetype: |filetype|. Used to get the default option for a
///                    specific filetype. Cannot be used with any other option.
///                    Note: this will trigger |ftplugin| and all |FileType|
///                    autocommands for the corresponding filetype.
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - tab: |tab-ID| for tab-local options. Currently only
///                    supports "cmdheight". Tabpage `0` means the current tabpage.
///                  - win: |window-ID|. Used for getting window local options.
/// @param[out] err  Error details, if any
/// @return          Option value
Object nvim_get_option_value(String name, Dict(option) *opts, Error *err)
  FUNC_API_SINCE(9) FUNC_API_RET_ALLOC
{
  OptIndex opt_idx = 0;
  int opt_flags = 0;
  OptScope scope = kOptScopeGlobal;
  void *from = NULL;
  char *filetype = NULL;

  if (!validate_option_value_args(opts, name.data, true, &opt_idx, &opt_flags, &scope, &from,
                                  &filetype, NULL, NULL, err)) {
    return (Object)OBJECT_INIT;
  }

  CtxSwitch aco = { 0 };

  buf_T *ftbuf = do_ft_buf(filetype, &aco, err);
  if (ERROR_SET(err)) {
    // Restore curwin/curbuf and a few other things.
    ctx_restore(&aco);
    if (ftbuf != NULL) {
      wipe_ft_buf(ftbuf);
    }
    return (Object)OBJECT_INIT;
  }

  if (ftbuf != NULL) {
    assert(!from);
    from = ftbuf;
  }

  OptVal value = get_option_value_for(opt_idx, opt_flags, scope, from, err);

  // Restore curwin/curbuf and a few other things.
  ctx_restore(&aco);
  if (ftbuf != NULL) {
    wipe_ft_buf(ftbuf);
  }

  if (ERROR_SET(err)) {
    goto err;
  }

  VALIDATE_S(value.type != kOptValTypeNil, "option", name.data, {
    goto err;
  });

  return optval_as_object(value);
err:
  optval_free(value);
  return (Object)OBJECT_INIT;
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
///                  - buf: Buffer number. Used for setting buffer local option.
///                  - dry_run: (`boolean?`, default: false) If true, then the
///                    option value won't be set.
///                  - operation: One of "set", "append", "prepend", or "remove".
///                    Corresponds to |:set=|, |:set+=|, |:set^=|, and |:set-=|.
///                    Default is "set".
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - tab: |tab-ID| for tab-local options (currently only 'cmdheight'). Tabpage 0
///                    means the current tabpage. If a non-current tab is given, the value will take
///                    effect when it is switched-to.
///                  - win: |window-ID|. Used for setting window local option.
/// @param[out] err  Error details, if any
/// @return          Option value
Object nvim_set_option_value(uint64_t channel_id, String name, Object value, Dict(option) *opts,
                             Arena *arena, Error *err)
  FUNC_API_SINCE(9)
{
  OptIndex opt_idx = 0;
  int opt_flags = 0;
  OptScope scope = kOptScopeGlobal;
  set_op_T operation = OP_NONE;
  void *to = NULL;
  bool dry_run = false;
  if (!validate_option_value_args(opts, name.data, true, &opt_idx, &opt_flags, &scope, &to, NULL,
                                  &operation, &dry_run, err)) {
    return NIL;
  }

  // If:
  // - window id is provided
  // - scope is not provided
  // - option is global or local to window (global-local)
  //
  // Then force scope to local since we don't want to change the global option
  if (scope == kOptScopeWin && opt_flags == 0) {
    if (option_has_scope(opt_idx, kOptScopeGlobal)) {
      opt_flags = OPT_LOCAL;
    }
  }

  // Convert the incoming value into an OptVal.
  bool error = false;
  OptVal optval_right = object_as_optval_for(opt_idx, value, operation, &error);

  VALIDATE_EXP(!error, name.data, "a valid type", api_typename(value.type), {
    return NIL;
  });

  OptVal merged_val = NIL_OPTVAL;
  const char *errmsg = NULL;
  vimoption_T *option = get_option(opt_idx);

  // Need to use varp specific to buf/win to ensure that merges are handled
  // correctly when the supplied buf/win are different than curbuf/curwin.
  buf_T *buf = scope == kOptScopeBuf ? to : curbuf;
  win_T *win = scope == kOptScopeWin ? to : curwin;
  void *varp = get_varp_from(option, buf, win);
  char *argp = NULL;

  switch (optval_right.type) {
  case kOptValTypeNil:
    break;
  case kOptValTypeString: {
    char *optval_escaped = escape_option_str_cmdline(optval_right.data.string.data);
    // We need a leading equal sign because get_option_newval is used for
    // cmdline stuff and expects an =
    argp = arena_printf(arena, "=%s", optval_escaped).data;
    XFREE_CLEAR(optval_escaped);
    break;
  }
  case kOptValTypeNumber:
    argp = arena_printf(arena, "=%" PRId64, optval_right.data.number).data;
    break;
  case kOptValTypeBoolean:
    merged_val = optval_right;
    break;
  }

  optval_free(optval_right);

  if (optval_right.type == kOptValTypeNumber || optval_right.type == kOptValTypeString) {
    OptVal oldval = optval_from_varp(opt_idx, varp);
    merged_val = get_option_newval(opt_idx, opt_flags, PREFIX_NONE, &argp, 0, operation,
                                   option->flags, varp, &oldval, NULL, 0, &errmsg);
    VALIDATE(errmsg == NULL, "%s", errmsg, {
      return NIL;
    });
  }

  if (!dry_run) {
    WITH_SCRIPT_CONTEXT(channel_id, {
      set_option_value_for(name.data, opt_idx, merged_val, opt_flags, scope, to, err);
    });
  }

  // Return the value in its structured (list/map/set) form.
  Object rv = optval_to_struct(opt_idx, merged_val, arena);
  optval_free(merged_val);
  return rv;
}

/// Gets the option information for all options.
///
/// The dict has the full option names as keys and option metadata dicts as detailed at
/// |nvim_get_option_info2()|.
///
/// @see |nvim_get_commands()|
///
/// @return dict of all options
Dict nvim_get_all_options_info(Arena *arena, Error *err)
  FUNC_API_SINCE(7)
{
  return get_all_vimoptions(arena);
}

/// Gets the option information for one option from arbitrary buffer or window
///
/// Resulting dict has keys:
/// - name: Name of the option (like 'filetype')
/// - shortname: Shortened name of the option (like 'ft')
/// - type: type of option ("string", "number" or "boolean")
/// - default: The default value for the option
/// - was_set: Whether the option was set.
///
/// - last_set_sid: Last set script id (if any)
/// - last_set_linenr: line number where option was set
/// - last_set_chan: Channel where option was set (0 for local)
///
/// - scope: one of "global", "win", "buf", or "tab"
/// - global_local: whether win or buf option has a global value
///
/// - commalist: List of comma separated values
/// - flaglist: List of single char flags
///
/// When {scope} is not provided, the last set information applies to the local
/// value in the current buffer or window if it is available, otherwise the
/// global value information is returned. This behavior can be disabled by
/// explicitly specifying {scope} in the {opts} table.
///
/// @param name      Option name
/// @param opts      Optional parameters
///                  - buf: Buffer number. Used for getting buffer local options.
///                         Implies {scope} is "local".
///                  - scope: One of "global" or "local". Analogous to
///                  |:setglobal| and |:setlocal|, respectively.
///                  - win: |window-ID|. Used for getting window local options.
/// @param[out] err Error details, if any
/// @return         Option Information
DictAs(get_option_info) nvim_get_option_info2(String name, Dict(option) *opts, Arena *arena,
                                              Error *err)
  FUNC_API_SINCE(11)
{
  OptIndex opt_idx = 0;
  int opt_flags = 0;
  OptScope scope = kOptScopeGlobal;
  void *from = NULL;
  // TODO(justinmk): support tab-local option.
  if (!validate_option_value_args(opts, name.data, false, &opt_idx, &opt_flags, &scope, &from, NULL,
                                  NULL, NULL, err)) {
    return (Dict)ARRAY_DICT_INIT;
  }

  buf_T *buf = (scope == kOptScopeBuf) ? (buf_T *)from : curbuf;
  win_T *win = (scope == kOptScopeWin) ? (win_T *)from : curwin;

  return get_vimoption(name, opt_flags, buf, win, arena, err);
}
