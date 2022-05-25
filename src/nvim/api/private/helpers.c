// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/extmark.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/highlight_group.h"
#include "nvim/lib/kvec.h"
#include "nvim/lua/executor.h"
#include "nvim/map.h"
#include "nvim/map_defs.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/ui.h"
#include "nvim/version.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/funcs_metadata.generated.h"
# include "api/private/helpers.c.generated.h"
# include "api/private/ui_events_metadata.generated.h"
#endif

/// Start block that may cause VimL exceptions while evaluating another code
///
/// Used when caller is supposed to be operating when other VimL code is being
/// processed and that “other VimL code” must not be affected.
///
/// @param[out]  tstate  Location where try state should be saved.
void try_enter(TryState *const tstate)
{
  // TODO(ZyX-I): Check whether try_enter()/try_leave() may use
  //              enter_cleanup()/leave_cleanup(). Or
  //              save_dbg_stuff()/restore_dbg_stuff().
  *tstate = (TryState) {
    .current_exception = current_exception,
    .msg_list = (const struct msglist *const *)msg_list,
    .private_msg_list = NULL,
    .trylevel = trylevel,
    .got_int = got_int,
    .need_rethrow = need_rethrow,
    .did_emsg = did_emsg,
  };
  msg_list = &tstate->private_msg_list;
  current_exception = NULL;
  trylevel = 1;
  got_int = false;
  need_rethrow = false;
  did_emsg = false;
}

/// End try block, set the error message if any and restore previous state
///
/// @warning Return is consistent with most functions (false on error), not with
///          try_end (true on error).
///
/// @param[in]  tstate  Previous state to restore.
/// @param[out]  err  Location where error should be saved.
///
/// @return false if error occurred, true otherwise.
bool try_leave(const TryState *const tstate, Error *const err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const bool ret = !try_end(err);
  assert(trylevel == 0);
  assert(!need_rethrow);
  assert(!got_int);
  assert(!did_emsg);
  assert(msg_list == &tstate->private_msg_list);
  assert(*msg_list == NULL);
  assert(current_exception == NULL);
  msg_list = (struct msglist **)tstate->msg_list;
  current_exception = tstate->current_exception;
  trylevel = tstate->trylevel;
  got_int = tstate->got_int;
  need_rethrow = tstate->need_rethrow;
  did_emsg = tstate->did_emsg;
  return ret;
}

/// Start block that may cause vimscript exceptions
///
/// Each try_start() call should be mirrored by try_end() call.
///
/// To be used as a replacement of `:try … catch … endtry` in C code, in cases
/// when error flag could not already be set. If there may be pending error
/// state at the time try_start() is executed which needs to be preserved,
/// try_enter()/try_leave() pair should be used instead.
void try_start(void)
{
  trylevel++;
}

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
bool try_end(Error *err)
{
  // Note: all globals manipulated here should be saved/restored in
  // try_enter/try_leave.
  trylevel--;

  // Set by emsg(), affects aborting().  See also enter_cleanup().
  did_emsg = false;
  force_abort = false;

  if (got_int) {
    if (current_exception) {
      // If we got an interrupt, discard the current exception
      discard_current_exception();
    }

    api_set_error(err, kErrorTypeException, "Keyboard interrupt");
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = get_exception_string(*msg_list,
                                     ET_ERROR,
                                     NULL,
                                     &should_free);
    api_set_error(err, kErrorTypeException, "%s", msg);
    free_global_msglist();

    if (should_free) {
      xfree(msg);
    }
  } else if (current_exception) {
    api_set_error(err, kErrorTypeException, "%s", current_exception->value);
    discard_current_exception();
  }

  return ERROR_SET(err);
}

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Error *err)
{
  dictitem_T *const di = tv_dict_find(dict, key.data, (ptrdiff_t)key.size);

  if (di == NULL) {
    api_set_error(err, kErrorTypeValidation, "Key not found: %s", key.data);
    return (Object)OBJECT_INIT;
  }

  return vim_to_object(&di->di_tv);
}

dictitem_T *dict_check_writable(dict_T *dict, String key, bool del, Error *err)
{
  dictitem_T *di = tv_dict_find(dict, key.data, (ptrdiff_t)key.size);

  if (di != NULL) {
    if (di->di_flags & DI_FLAGS_RO) {
      api_set_error(err, kErrorTypeException, "Key is read-only: %s", key.data);
    } else if (di->di_flags & DI_FLAGS_LOCK) {
      api_set_error(err, kErrorTypeException, "Key is locked: %s", key.data);
    } else if (del && (di->di_flags & DI_FLAGS_FIX)) {
      api_set_error(err, kErrorTypeException, "Key is fixed: %s", key.data);
    }
  } else if (dict->dv_lock) {
    api_set_error(err, kErrorTypeException, "Dictionary is locked");
  } else if (key.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Key name is empty");
  } else if (key.size > INT_MAX) {
    api_set_error(err, kErrorTypeValidation, "Key name is too long");
  }

  return di;
}

/// Set a value in a scope dict. Objects are recursively expanded into their
/// vimscript equivalents.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param del Delete key in place of setting it. Argument `value` is ignored in
///            this case.
/// @param retval If true the old value will be converted and returned.
/// @param[out] err Details of an error that may have occurred
/// @return The old value if `retval` is true and the key was present, else NIL
Object dict_set_var(dict_T *dict, String key, Object value, bool del, bool retval, Error *err)
{
  Object rv = OBJECT_INIT;
  dictitem_T *di = dict_check_writable(dict, key, del, err);

  if (ERROR_SET(err)) {
    return rv;
  }

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      api_set_error(err, kErrorTypeValidation, "Key not found: %s",
                    key.data);
    } else {
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv);
      }
      // Delete the entry
      tv_dict_item_remove(dict, di);
    }
  } else {
    // Update the key
    typval_T tv;

    // Convert the object to a vimscript type in the temporary variable
    if (!object_to_vim(value, &tv, err)) {
      return rv;
    }

    if (di == NULL) {
      // Need to create an entry
      di = tv_dict_item_alloc_len(key.data, key.size);
      tv_dict_add(dict, di);
    } else {
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv);
      }
      tv_clear(&di->di_tv);
    }

    // Update the value
    tv_copy(&tv, &di->di_tv);
    // Clear the temporary variable
    tv_clear(&tv);
  }

  return rv;
}

/// Gets the value of a global or local(buffer, window) option.
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

/// Sets the value of a global or local(buffer, window) option.
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

  int numval = 0;
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

  WITH_SCRIPT_CONTEXT(channel_id, {
    const int opt_flags = (type == SREQ_WIN && !(flags & SOPT_GLOBAL))
                          ? 0 : (type == SREQ_GLOBAL)
                                ? OPT_GLOBAL : OPT_LOCAL;

    set_option_value_for(name.data, numval, stringval,
                         opt_flags, type, to, err);
  });
}

buf_T *find_buffer_by_handle(Buffer buffer, Error *err)
{
  if (buffer == 0) {
    return curbuf;
  }

  buf_T *rv = handle_get_buffer(buffer);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid buffer id: %d", buffer);
  }

  return rv;
}

win_T *find_window_by_handle(Window window, Error *err)
{
  if (window == 0) {
    return curwin;
  }

  win_T *rv = handle_get_window(window);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid window id: %d", window);
  }

  return rv;
}

tabpage_T *find_tab_by_handle(Tabpage tabpage, Error *err)
{
  if (tabpage == 0) {
    return curtab;
  }

  tabpage_T *rv = handle_get_tabpage(tabpage);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid tabpage id: %d", tabpage);
  }

  return rv;
}

/// Allocates a String consisting of a single char. Does not support multibyte
/// characters. The resulting string is also NUL-terminated, to facilitate
/// interoperating with code using C strings.
///
/// @param char the char to convert
/// @return the resulting String, if the input char was NUL, an
///         empty String is returned
String cchar_to_string(char c)
{
  char buf[] = { c, NUL };
  return (String){
    .data = xmemdupz(buf, 1),
    .size = (c != NUL) ? 1 : 0
  };
}

/// Copies a C string into a String (binary safe string, characters + length).
/// The resulting string is also NUL-terminated, to facilitate interoperating
/// with code using C strings.
///
/// @param str the C string to copy
/// @return the resulting String, if the input string was NULL, an
///         empty String is returned
String cstr_to_string(const char *str)
{
  if (str == NULL) {
    return (String)STRING_INIT;
  }

  size_t len = strlen(str);
  return (String){
    .data = xmemdupz(str, len),
    .size = len,
  };
}

/// Copies a String to an allocated, NUL-terminated C string.
///
/// @param str the String to copy
/// @return the resulting C string
char *string_to_cstr(String str)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  return xstrndup(str.data, str.size);
}

/// Copies buffer to an allocated String.
/// The resulting string is also NUL-terminated, to facilitate interoperating
/// with code using C strings.
///
/// @param buf the buffer to copy
/// @param size length of the buffer
/// @return the resulting String, if the input string was NULL, an
///         empty String is returned
String cbuf_to_string(const char *buf, size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  return (String){
    .data = xmemdupz(buf, size),
    .size = size
  };
}

String cstrn_to_string(const char *str, size_t maxsize)
  FUNC_ATTR_NONNULL_ALL
{
  return cbuf_to_string(str, STRNLEN(str, maxsize));
}

/// Creates a String using the given C string. Unlike
/// cstr_to_string this function DOES NOT copy the C string.
///
/// @param str the C string to use
/// @return The resulting String, or an empty String if
///           str was NULL
String cstr_as_string(char *str) FUNC_ATTR_PURE
{
  if (str == NULL) {
    return (String)STRING_INIT;
  }
  return (String){ .data = str, .size = strlen(str) };
}

/// Return the owned memory of a ga as a String
///
/// Reinitializes the ga to a valid empty state.
String ga_take_string(garray_T *ga)
{
  String str = { .data = (char *)ga->ga_data, .size = (size_t)ga->ga_len };
  ga->ga_data = NULL;
  ga->ga_len = 0;
  ga->ga_maxlen = 0;
  return str;
}

/// Creates "readfile()-style" ArrayOf(String) from a binary string.
///
/// - Lines break at \n (NL/LF/line-feed).
/// - NUL bytes are replaced with NL.
/// - If the last byte is a linebreak an extra empty list item is added.
///
/// @param input  Binary string
/// @param crlf  Also break lines at CR and CRLF.
/// @return [allocated] String array
Array string_to_array(const String input, bool crlf)
{
  Array ret = ARRAY_DICT_INIT;
  for (size_t i = 0; i < input.size; i++) {
    const char *start = input.data + i;
    const char *end = start;
    size_t line_len = 0;
    for (; line_len < input.size - i; line_len++) {
      end = start + line_len;
      if (*end == NL || (crlf && *end == CAR)) {
        break;
      }
    }
    i += line_len;
    if (crlf && *end == CAR && i + 1 < input.size && *(end + 1) == NL) {
      i += 1;  // Advance past CRLF.
    }
    String s = {
      .size = line_len,
      .data = xmemdupz(start, line_len),
    };
    memchrsub(s.data, NUL, NL, line_len);
    ADD(ret, STRING_OBJ(s));
    // If line ends at end-of-buffer, add empty final item.
    // This is "readfile()-style", see also ":help channel-lines".
    if (i + 1 == input.size && (*end == NL || (crlf && *end == CAR))) {
      ADD(ret, STRING_OBJ(STRING_INIT));
    }
  }

  return ret;
}

/// Set, tweak, or remove a mapping in a mode. Acts as the implementation for
/// functions like @ref nvim_buf_set_keymap.
///
/// Arguments are handled like @ref nvim_set_keymap unless noted.
/// @param  buffer    Buffer handle for a specific buffer, or 0 for the current
///                   buffer, or -1 to signify global behavior ("all buffers")
/// @param  is_unmap  When true, removes the mapping that matches {lhs}.
void modify_keymap(uint64_t channel_id, Buffer buffer, bool is_unmap, String mode, String lhs,
                   String rhs, Dict(keymap) *opts, Error *err)
{
  LuaRef lua_funcref = LUA_NOREF;
  bool global = (buffer == -1);
  if (global) {
    buffer = 0;
  }
  buf_T *target_buf = find_buffer_by_handle(buffer, err);

  if (!target_buf) {
    return;
  }

  const sctx_T save_current_sctx = api_set_sctx(channel_id);

  if (opts != NULL && opts->callback.type == kObjectTypeLuaRef) {
    lua_funcref = opts->callback.data.luaref;
    opts->callback.data.luaref = LUA_NOREF;
  }
  MapArguments parsed_args = MAP_ARGUMENTS_INIT;
  if (opts) {
#define KEY_TO_BOOL(name) \
  parsed_args.name = api_object_to_bool(opts->name, #name, false, err); \
  if (ERROR_SET(err)) { \
    goto fail_and_free; \
  }

    KEY_TO_BOOL(nowait);
    KEY_TO_BOOL(noremap);
    KEY_TO_BOOL(silent);
    KEY_TO_BOOL(script);
    KEY_TO_BOOL(expr);
    KEY_TO_BOOL(unique);
#undef KEY_TO_BOOL
  }
  parsed_args.buffer = !global;

  set_maparg_lhs_rhs(lhs.data, lhs.size,
                     rhs.data, rhs.size, lua_funcref,
                     CPO_TO_CPO_FLAGS, &parsed_args);
  if (opts != NULL && opts->desc.type == kObjectTypeString) {
    parsed_args.desc = string_to_cstr(opts->desc.data.string);
  } else {
    parsed_args.desc = NULL;
  }
  if (parsed_args.lhs_len > MAXMAPLEN || parsed_args.alt_lhs_len > MAXMAPLEN) {
    api_set_error(err, kErrorTypeValidation,  "LHS exceeds maximum map length: %s", lhs.data);
    goto fail_and_free;
  }

  if (mode.size > 1) {
    api_set_error(err, kErrorTypeValidation, "Shortname is too long: %s", mode.data);
    goto fail_and_free;
  }
  int mode_val;  // integer value of the mapping mode, to be passed to do_map()
  char *p = (mode.size) ? mode.data : "m";
  if (STRNCMP(p, "!", 2) == 0) {
    mode_val = get_map_mode(&p, true);  // mapmode-ic
  } else {
    mode_val = get_map_mode(&p, false);
    if (mode_val == (MODE_VISUAL | MODE_SELECT | MODE_NORMAL | MODE_OP_PENDING) && mode.size > 0) {
      // get_map_mode() treats unrecognized mode shortnames as ":map".
      // This is an error unless the given shortname was empty string "".
      api_set_error(err, kErrorTypeValidation, "Invalid mode shortname: \"%s\"", p);
      goto fail_and_free;
    }
  }

  if (parsed_args.lhs_len == 0) {
    api_set_error(err, kErrorTypeValidation, "Invalid (empty) LHS");
    goto fail_and_free;
  }

  bool is_noremap = parsed_args.noremap;
  assert(!(is_unmap && is_noremap));

  if (!is_unmap && lua_funcref == LUA_NOREF
      && (parsed_args.rhs_len == 0 && !parsed_args.rhs_is_noop)) {
    if (rhs.size == 0) {  // assume that the user wants RHS to be a <Nop>
      parsed_args.rhs_is_noop = true;
    } else {
      // the given RHS was nonempty and not a <Nop>, but was parsed as if it
      // were empty?
      assert(false && "Failed to parse nonempty RHS!");
      api_set_error(err, kErrorTypeValidation, "Parsing of nonempty RHS failed: %s", rhs.data);
      goto fail_and_free;
    }
  } else if (is_unmap && (parsed_args.rhs_len || parsed_args.rhs_lua != LUA_NOREF)) {
    if (parsed_args.rhs_len) {
      api_set_error(err, kErrorTypeValidation,
                    "Gave nonempty RHS in unmap command: %s", parsed_args.rhs);
    } else {
      api_set_error(err, kErrorTypeValidation, "Gave nonempty RHS for unmap");
    }
    goto fail_and_free;
  }

  // buf_do_map() reads noremap/unmap as its own argument.
  int maptype_val = 0;
  if (is_unmap) {
    maptype_val = 1;
  } else if (is_noremap) {
    maptype_val = 2;
  }

  switch (buf_do_map(maptype_val, &parsed_args, mode_val, 0, target_buf)) {
  case 0:
    break;
  case 1:
    api_set_error(err, kErrorTypeException, (char *)e_invarg, 0);
    goto fail_and_free;
  case 2:
    api_set_error(err, kErrorTypeException, (char *)e_nomap, 0);
    goto fail_and_free;
  case 5:
    api_set_error(err, kErrorTypeException,
                  "E227: mapping already exists for %s", parsed_args.lhs);
    goto fail_and_free;
  default:
    assert(false && "Unrecognized return code!");
    goto fail_and_free;
  }  // switch

  parsed_args.rhs_lua = LUA_NOREF;  // don't clear ref on success
fail_and_free:
  current_sctx = save_current_sctx;
  NLUA_CLEAR_REF(parsed_args.rhs_lua);
  xfree(parsed_args.rhs);
  xfree(parsed_args.orig_rhs);
  XFREE_CLEAR(parsed_args.desc);
}

/// Collects `n` buffer lines into array `l`, optionally replacing newlines
/// with NUL.
///
/// @param buf Buffer to get lines from
/// @param n Number of lines to collect
/// @param replace_nl Replace newlines ("\n") with NUL
/// @param start Line number to start from
/// @param[out] l Lines are copied here
/// @param err[out] Error, if any
/// @return true unless `err` was set
bool buf_collect_lines(buf_T *buf, size_t n, int64_t start, bool replace_nl, Array *l, Error *err)
{
  for (size_t i = 0; i < n; i++) {
    int64_t lnum = start + (int64_t)i;

    if (lnum >= MAXLNUM) {
      if (err != NULL) {
        api_set_error(err, kErrorTypeValidation, "Line index is too high");
      }
      return false;
    }

    const char *bufstr = (char *)ml_get_buf(buf, (linenr_T)lnum, false);
    Object str = STRING_OBJ(cstr_to_string(bufstr));

    if (replace_nl) {
      // Vim represents NULs as NLs, but this may confuse clients.
      strchrsub(str.data.string.data, '\n', '\0');
    }

    l->items[i] = str;
  }

  return true;
}

/// Returns a substring of a buffer line
///
/// @param buf          Buffer handle
/// @param lnum         Line number (1-based)
/// @param start_col    Starting byte offset into line (0-based)
/// @param end_col      Ending byte offset into line (0-based, exclusive)
/// @param replace_nl   Replace newlines ('\n') with null ('\0')
/// @param err          Error object
/// @return The text between start_col and end_col on line lnum of buffer buf
String buf_get_text(buf_T *buf, int64_t lnum, int64_t start_col, int64_t end_col, bool replace_nl,
                    Error *err)
{
  String rv = STRING_INIT;

  if (lnum >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line index is too high");
    return rv;
  }

  const char *bufstr = (char *)ml_get_buf(buf, (linenr_T)lnum, false);
  size_t line_length = strlen(bufstr);

  start_col = start_col < 0 ? (int64_t)line_length + start_col + 1 : start_col;
  end_col = end_col < 0 ? (int64_t)line_length + end_col + 1 : end_col;

  if (start_col >= MAXCOL || end_col >= MAXCOL) {
    api_set_error(err, kErrorTypeValidation, "Column index is too high");
    return rv;
  }

  if (start_col > end_col) {
    api_set_error(err, kErrorTypeValidation, "start_col must be less than end_col");
    return rv;
  }

  if ((size_t)start_col >= line_length) {
    return rv;
  }

  rv = cstrn_to_string(&bufstr[start_col], (size_t)(end_col - start_col));
  if (replace_nl) {
    strchrsub(rv.data, '\n', '\0');
  }

  return rv;
}

void api_free_string(String value)
{
  if (!value.data) {
    return;
  }

  xfree(value.data);
}

void api_free_object(Object value)
{
  switch (value.type) {
  case kObjectTypeNil:
  case kObjectTypeBoolean:
  case kObjectTypeInteger:
  case kObjectTypeFloat:
  case kObjectTypeBuffer:
  case kObjectTypeWindow:
  case kObjectTypeTabpage:
    break;

  case kObjectTypeString:
    api_free_string(value.data.string);
    break;

  case kObjectTypeArray:
    api_free_array(value.data.array);
    break;

  case kObjectTypeDictionary:
    api_free_dictionary(value.data.dictionary);
    break;

  case kObjectTypeLuaRef:
    api_free_luaref(value.data.luaref);
    break;

  default:
    abort();
  }
}

void api_free_array(Array value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_free_object(value.items[i]);
  }

  xfree(value.items);
}

void api_free_dictionary(Dictionary value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_free_string(value.items[i].key);
    api_free_object(value.items[i].value);
  }

  xfree(value.items);
}

void api_clear_error(Error *value)
  FUNC_ATTR_NONNULL_ALL
{
  if (!ERROR_SET(value)) {
    return;
  }
  xfree(value->msg);
  value->msg = NULL;
  value->type = kErrorTypeNone;
}

Dictionary api_metadata(void)
{
  static Dictionary metadata = ARRAY_DICT_INIT;

  if (!metadata.size) {
    PUT(metadata, "version", DICTIONARY_OBJ(version_dict()));
    init_function_metadata(&metadata);
    init_ui_event_metadata(&metadata);
    init_error_type_metadata(&metadata);
    init_type_metadata(&metadata);
  }

  return copy_object(DICTIONARY_OBJ(metadata)).data.dictionary;
}

static void init_function_metadata(Dictionary *metadata)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  if (msgpack_unpack_next(&unpacked,
                          (const char *)funcs_metadata,
                          sizeof(funcs_metadata),
                          NULL) != MSGPACK_UNPACK_SUCCESS) {
    abort();
  }
  Object functions;
  msgpack_rpc_to_object(&unpacked.data, &functions);
  msgpack_unpacked_destroy(&unpacked);
  PUT(*metadata, "functions", functions);
}

static void init_ui_event_metadata(Dictionary *metadata)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  if (msgpack_unpack_next(&unpacked,
                          (const char *)ui_events_metadata,
                          sizeof(ui_events_metadata),
                          NULL) != MSGPACK_UNPACK_SUCCESS) {
    abort();
  }
  Object ui_events;
  msgpack_rpc_to_object(&unpacked.data, &ui_events);
  msgpack_unpacked_destroy(&unpacked);
  PUT(*metadata, "ui_events", ui_events);
  Array ui_options = ARRAY_DICT_INIT;
  ADD(ui_options, STRING_OBJ(cstr_to_string("rgb")));
  for (UIExtension i = 0; i < kUIExtCount; i++) {
    if (ui_ext_names[i][0] != '_') {
      ADD(ui_options, STRING_OBJ(cstr_to_string(ui_ext_names[i])));
    }
  }
  PUT(*metadata, "ui_options", ARRAY_OBJ(ui_options));
}

static void init_error_type_metadata(Dictionary *metadata)
{
  Dictionary types = ARRAY_DICT_INIT;

  Dictionary exception_metadata = ARRAY_DICT_INIT;
  PUT(exception_metadata, "id", INTEGER_OBJ(kErrorTypeException));

  Dictionary validation_metadata = ARRAY_DICT_INIT;
  PUT(validation_metadata, "id", INTEGER_OBJ(kErrorTypeValidation));

  PUT(types, "Exception", DICTIONARY_OBJ(exception_metadata));
  PUT(types, "Validation", DICTIONARY_OBJ(validation_metadata));

  PUT(*metadata, "error_types", DICTIONARY_OBJ(types));
}

static void init_type_metadata(Dictionary *metadata)
{
  Dictionary types = ARRAY_DICT_INIT;

  Dictionary buffer_metadata = ARRAY_DICT_INIT;
  PUT(buffer_metadata, "id",
      INTEGER_OBJ(kObjectTypeBuffer - EXT_OBJECT_TYPE_SHIFT));
  PUT(buffer_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_buf_")));

  Dictionary window_metadata = ARRAY_DICT_INIT;
  PUT(window_metadata, "id",
      INTEGER_OBJ(kObjectTypeWindow - EXT_OBJECT_TYPE_SHIFT));
  PUT(window_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_win_")));

  Dictionary tabpage_metadata = ARRAY_DICT_INIT;
  PUT(tabpage_metadata, "id",
      INTEGER_OBJ(kObjectTypeTabpage - EXT_OBJECT_TYPE_SHIFT));
  PUT(tabpage_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_tabpage_")));

  PUT(types, "Buffer", DICTIONARY_OBJ(buffer_metadata));
  PUT(types, "Window", DICTIONARY_OBJ(window_metadata));
  PUT(types, "Tabpage", DICTIONARY_OBJ(tabpage_metadata));

  PUT(*metadata, "types", DICTIONARY_OBJ(types));
}

String copy_string(String str)
{
  if (str.data != NULL) {
    return (String){ .data = xmemdupz(str.data, str.size), .size = str.size };
  } else {
    return (String)STRING_INIT;
  }
}

Array copy_array(Array array)
{
  Array rv = ARRAY_DICT_INIT;
  for (size_t i = 0; i < array.size; i++) {
    ADD(rv, copy_object(array.items[i]));
  }
  return rv;
}

Dictionary copy_dictionary(Dictionary dict)
{
  Dictionary rv = ARRAY_DICT_INIT;
  for (size_t i = 0; i < dict.size; i++) {
    KeyValuePair item = dict.items[i];
    PUT(rv, item.key.data, copy_object(item.value));
  }
  return rv;
}

/// Creates a deep clone of an object
Object copy_object(Object obj)
{
  switch (obj.type) {
  case kObjectTypeBuffer:
  case kObjectTypeTabpage:
  case kObjectTypeWindow:
  case kObjectTypeNil:
  case kObjectTypeBoolean:
  case kObjectTypeInteger:
  case kObjectTypeFloat:
    return obj;

  case kObjectTypeString:
    return STRING_OBJ(copy_string(obj.data.string));

  case kObjectTypeArray:
    return ARRAY_OBJ(copy_array(obj.data.array));

  case kObjectTypeDictionary:
    return DICTIONARY_OBJ(copy_dictionary(obj.data.dictionary));

  case kObjectTypeLuaRef:
    return LUAREF_OBJ(api_new_luaref(obj.data.luaref));

  default:
    abort();
  }
}

void set_option_value_for(char *key, long numval, char *stringval, int opt_flags, int opt_type,
                          void *from, Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;

  try_start();
  switch (opt_type) {
  case SREQ_WIN:
    if (switch_win_noblock(&switchwin, (win_T *)from, win_find_tabpage((win_T *)from), true)
        == FAIL) {
      restore_win_noblock(&switchwin, true);
      if (try_end(err)) {
        return;
      }
      api_set_error(err,
                    kErrorTypeException,
                    "Problem while switching windows");
      return;
    }
    set_option_value_err(key, numval, stringval, opt_flags, err);
    restore_win_noblock(&switchwin, true);
    break;
  case SREQ_BUF:
    aucmd_prepbuf(&aco, (buf_T *)from);
    set_option_value_err(key, numval, stringval, opt_flags, err);
    aucmd_restbuf(&aco);
    break;
  case SREQ_GLOBAL:
    set_option_value_err(key, numval, stringval, opt_flags, err);
    break;
  }

  if (ERROR_SET(err)) {
    return;
  }

  try_end(err);
}

static void set_option_value_err(char *key, long numval, char *stringval, int opt_flags, Error *err)
{
  char *errmsg;

  if ((errmsg = set_option_value(key, numval, stringval, opt_flags))) {
    if (try_end(err)) {
      return;
    }

    api_set_error(err, kErrorTypeException, "%s", errmsg);
  }
}

void api_set_error(Error *err, ErrorType errType, const char *format, ...)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PRINTF(3, 4)
{
  assert(kErrorTypeNone != errType);
  va_list args1;
  va_list args2;
  va_start(args1, format);
  va_copy(args2, args1);
  int len = vsnprintf(NULL, 0, format, args1);
  va_end(args1);
  assert(len >= 0);
  // Limit error message to 1 MB.
  size_t bufsize = MIN((size_t)len + 1, 1024 * 1024);
  err->msg = xmalloc(bufsize);
  vsnprintf(err->msg, bufsize, format, args2);
  va_end(args2);

  err->type = errType;
}

/// Get an array containing dictionaries describing mappings
/// based on mode and buffer id
///
/// @param  mode  The abbreviation for the mode
/// @param  buf  The buffer to get the mapping array. NULL for global
/// @param  from_lua  Whether it is called from internal lua api.
/// @returns Array of maparg()-like dictionaries describing mappings
ArrayOf(Dictionary) keymap_array(String mode, buf_T *buf, bool from_lua)
{
  Array mappings = ARRAY_DICT_INIT;
  dict_T *const dict = tv_dict_alloc();

  // Convert the string mode to the integer mode
  // that is stored within each mapblock
  char *p = mode.data;
  int int_mode = get_map_mode(&p, 0);

  // Determine the desired buffer value
  long buffer_value = (buf == NULL) ? 0 : buf->handle;

  for (int i = 0; i < MAX_MAPHASH; i++) {
    for (const mapblock_T *current_maphash = get_maphash(i, buf);
         current_maphash;
         current_maphash = current_maphash->m_next) {
      if (current_maphash->m_simplified) {
        continue;
      }
      // Check for correct mode
      if (int_mode & current_maphash->m_mode) {
        mapblock_fill_dict(dict, current_maphash, buffer_value, false);
        Object api_dict = vim_to_object((typval_T[]) { { .v_type = VAR_DICT,
                                                         .vval.v_dict = dict } });
        if (from_lua) {
          Dictionary d = api_dict.data.dictionary;
          for (size_t j = 0; j < d.size; j++) {
            if (strequal("callback", d.items[j].key.data)) {
              d.items[j].value.type = kObjectTypeLuaRef;
              d.items[j].value.data.luaref = api_new_luaref((LuaRef)d.items[j].value.data.integer);
              break;
            }
          }
        }
        ADD(mappings, api_dict);
        tv_dict_clear(dict);
      }
    }
  }
  tv_dict_free(dict);

  return mappings;
}

/// Gets the line and column of an extmark.
///
/// Extmarks may be queried by position, name or even special names
/// in the future such as "cursor".
///
/// @param[out] lnum extmark line
/// @param[out] colnr extmark column
///
/// @return true if the extmark was found, else false
bool extmark_get_index_from_obj(buf_T *buf, Integer ns_id, Object obj, int
                                *row, colnr_T *col, Error *err)
{
  // Check if it is mark id
  if (obj.type == kObjectTypeInteger) {
    Integer id = obj.data.integer;
    if (id == 0) {
      *row = 0;
      *col = 0;
      return true;
    } else if (id == -1) {
      *row = MAXLNUM;
      *col = MAXCOL;
      return true;
    } else if (id < 0) {
      api_set_error(err, kErrorTypeValidation, "Mark id must be positive");
      return false;
    }

    ExtmarkInfo extmark = extmark_from_id(buf, (uint32_t)ns_id, (uint32_t)id);
    if (extmark.row >= 0) {
      *row = extmark.row;
      *col = extmark.col;
      return true;
    } else {
      api_set_error(err, kErrorTypeValidation, "No mark with requested id");
      return false;
    }

    // Check if it is a position
  } else if (obj.type == kObjectTypeArray) {
    Array pos = obj.data.array;
    if (pos.size != 2
        || pos.items[0].type != kObjectTypeInteger
        || pos.items[1].type != kObjectTypeInteger) {
      api_set_error(err, kErrorTypeValidation,
                    "Position must have 2 integer elements");
      return false;
    }
    Integer pos_row = pos.items[0].data.integer;
    Integer pos_col = pos.items[1].data.integer;
    *row = (int)(pos_row >= 0 ? pos_row  : MAXLNUM);
    *col = (colnr_T)(pos_col >= 0 ? pos_col : MAXCOL);
    return true;
  } else {
    api_set_error(err, kErrorTypeValidation,
                  "Position must be a mark id Integer or position Array");
    return false;
  }
}

VirtText parse_virt_text(Array chunks, Error *err, int *width)
{
  VirtText virt_text = KV_INITIAL_VALUE;
  int w = 0;
  for (size_t i = 0; i < chunks.size; i++) {
    if (chunks.items[i].type != kObjectTypeArray) {
      api_set_error(err, kErrorTypeValidation, "Chunk is not an array");
      goto free_exit;
    }
    Array chunk = chunks.items[i].data.array;
    if (chunk.size == 0 || chunk.size > 2
        || chunk.items[0].type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation,
                    "Chunk is not an array with one or two strings");
      goto free_exit;
    }

    String str = chunk.items[0].data.string;

    int hl_id = 0;
    if (chunk.size == 2) {
      Object hl = chunk.items[1];
      if (hl.type == kObjectTypeArray) {
        Array arr = hl.data.array;
        for (size_t j = 0; j < arr.size; j++) {
          hl_id = object_to_hl_id(arr.items[j], "virt_text highlight", err);
          if (ERROR_SET(err)) {
            goto free_exit;
          }
          if (j < arr.size - 1) {
            kv_push(virt_text, ((VirtTextChunk){ .text = NULL,
                                                 .hl_id = hl_id }));
          }
        }
      } else {
        hl_id = object_to_hl_id(hl, "virt_text highlight", err);
        if (ERROR_SET(err)) {
          goto free_exit;
        }
      }
    }

    char *text = transstr(str.size > 0 ? str.data : "", false);  // allocates
    w += (int)mb_string2cells(text);

    kv_push(virt_text, ((VirtTextChunk){ .text = text, .hl_id = hl_id }));
  }

  *width = w;
  return virt_text;

free_exit:
  clear_virttext(&virt_text);
  return virt_text;
}

/// Force obj to bool.
/// If it fails, returns false and sets err
/// @param obj          The object to coerce to a boolean
/// @param what         The name of the object, used for error message
/// @param nil_value    What to return if the type is nil.
/// @param err          Set if there was an error in converting to a bool
bool api_object_to_bool(Object obj, const char *what, bool nil_value, Error *err)
{
  if (obj.type == kObjectTypeBoolean) {
    return obj.data.boolean;
  } else if (obj.type == kObjectTypeInteger) {
    return obj.data.integer;  // C semantics: non-zero int is true
  } else if (obj.type == kObjectTypeNil) {
    return nil_value;  // caller decides what NIL (missing retval in lua) means
  } else {
    api_set_error(err, kErrorTypeValidation, "%s is not a boolean", what);
    return false;
  }
}

int object_to_hl_id(Object obj, const char *what, Error *err)
{
  if (obj.type == kObjectTypeString) {
    String str = obj.data.string;
    return str.size ? syn_check_group(str.data, str.size) : 0;
  } else if (obj.type == kObjectTypeInteger) {
    return MAX((int)obj.data.integer, 0);
  } else {
    api_set_error(err, kErrorTypeValidation,
                  "%s is not a valid highlight", what);
    return 0;
  }
}

HlMessage parse_hl_msg(Array chunks, Error *err)
{
  HlMessage hl_msg = KV_INITIAL_VALUE;
  for (size_t i = 0; i < chunks.size; i++) {
    if (chunks.items[i].type != kObjectTypeArray) {
      api_set_error(err, kErrorTypeValidation, "Chunk is not an array");
      goto free_exit;
    }
    Array chunk = chunks.items[i].data.array;
    if (chunk.size == 0 || chunk.size > 2
        || chunk.items[0].type != kObjectTypeString
        || (chunk.size == 2 && chunk.items[1].type != kObjectTypeString)) {
      api_set_error(err, kErrorTypeValidation,
                    "Chunk is not an array with one or two strings");
      goto free_exit;
    }

    String str = copy_string(chunk.items[0].data.string);

    int attr = 0;
    if (chunk.size == 2) {
      String hl = chunk.items[1].data.string;
      if (hl.size > 0) {
        // TODO(bfredl): use object_to_hl_id and allow integer
        int hl_id = syn_check_group(hl.data, hl.size);
        attr = hl_id > 0 ? syn_id2attr(hl_id) : 0;
      }
    }
    kv_push(hl_msg, ((HlMessageChunk){ .text = str, .attr = attr }));
  }

  return hl_msg;

free_exit:
  clear_hl_msg(&hl_msg);
  return hl_msg;
}

bool api_dict_to_keydict(void *rv, field_hash hashy, Dictionary dict, Error *err)
{
  for (size_t i = 0; i < dict.size; i++) {
    String k = dict.items[i].key;
    Object *field = hashy(rv, k.data, k.size);
    if (!field) {
      api_set_error(err, kErrorTypeValidation, "Invalid key: '%.*s'", (int)k.size, k.data);
      return false;
    }

    *field = dict.items[i].value;
  }

  return true;
}

void api_free_keydict(void *dict, KeySetLink *table)
{
  for (size_t i = 0; table[i].str; i++) {
    api_free_object(*(Object *)((char *)dict + table[i].ptr_off));
  }
}

/// Set a named mark
/// buffer and mark name must be validated already
/// @param buffer     Buffer to set the mark on
/// @param name       Mark name
/// @param line       Line number
/// @param col        Column/row number
/// @return true if the mark was set, else false
bool set_mark(buf_T *buf, String name, Integer line, Integer col, Error *err)
{
  buf = buf == NULL ? curbuf : buf;
  // If line == 0 the marks is being deleted
  bool res = false;
  bool deleting = false;
  if (line == 0) {
    col = 0;
    deleting = true;
  } else {
    if (col > MAXCOL) {
      api_set_error(err, kErrorTypeValidation, "Column value outside range");
      return res;
    }
    if (line < 1 || line > buf->b_ml.ml_line_count) {
      api_set_error(err, kErrorTypeValidation, "Line value outside range");
      return res;
    }
  }
  pos_T pos = { line, (int)col, (int)col };
  res = setmark_pos(*name.data, &pos, buf->handle);
  if (!res) {
    if (deleting) {
      api_set_error(err, kErrorTypeException,
                    "Failed to delete named mark: %c", *name.data);
    } else {
      api_set_error(err, kErrorTypeException,
                    "Failed to set named mark: %c", *name.data);
    }
  }
  return res;
}

/// Get default statusline highlight for window
const char *get_default_stl_hl(win_T *wp, bool use_winbar)
{
  if (wp == NULL) {
    return "TabLineFill";
  } else if (use_winbar) {
    return (wp == curwin) ? "WinBar" : "WinBarNC";
  } else {
    return (wp == curwin) ? "StatusLine" : "StatusLineNC";
  }
}

void create_user_command(String name, Object command, Dict(user_command) *opts, int flags,
                         Error *err)
{
  uint32_t argt = 0;
  long def = -1;
  cmd_addr_T addr_type_arg = ADDR_NONE;
  int compl = EXPAND_NOTHING;
  char *compl_arg = NULL;
  char *rep = NULL;
  LuaRef luaref = LUA_NOREF;
  LuaRef compl_luaref = LUA_NOREF;

  if (!uc_validate_name(name.data)) {
    api_set_error(err, kErrorTypeValidation, "Invalid command name");
    goto err;
  }

  if (mb_islower(name.data[0])) {
    api_set_error(err, kErrorTypeValidation, "'name' must begin with an uppercase letter");
    goto err;
  }

  if (HAS_KEY(opts->range) && HAS_KEY(opts->count)) {
    api_set_error(err, kErrorTypeValidation, "'range' and 'count' are mutually exclusive");
    goto err;
  }

  if (opts->nargs.type == kObjectTypeInteger) {
    switch (opts->nargs.data.integer) {
    case 0:
      // Default value, nothing to do
      break;
    case 1:
      argt |= EX_EXTRA | EX_NOSPC | EX_NEEDARG;
      break;
    default:
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'nargs'");
      goto err;
    }
  } else if (opts->nargs.type == kObjectTypeString) {
    if (opts->nargs.data.string.size > 1) {
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'nargs'");
      goto err;
    }

    switch (opts->nargs.data.string.data[0]) {
    case '*':
      argt |= EX_EXTRA;
      break;
    case '?':
      argt |= EX_EXTRA | EX_NOSPC;
      break;
    case '+':
      argt |= EX_EXTRA | EX_NEEDARG;
      break;
    default:
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'nargs'");
      goto err;
    }
  } else if (HAS_KEY(opts->nargs)) {
    api_set_error(err, kErrorTypeValidation, "Invalid value for 'nargs'");
    goto err;
  }

  if (HAS_KEY(opts->complete) && !argt) {
    api_set_error(err, kErrorTypeValidation, "'complete' used without 'nargs'");
    goto err;
  }

  if (opts->range.type == kObjectTypeBoolean) {
    if (opts->range.data.boolean) {
      argt |= EX_RANGE;
      addr_type_arg = ADDR_LINES;
    }
  } else if (opts->range.type == kObjectTypeString) {
    if (opts->range.data.string.data[0] == '%' && opts->range.data.string.size == 1) {
      argt |= EX_RANGE | EX_DFLALL;
      addr_type_arg = ADDR_LINES;
    } else {
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'range'");
      goto err;
    }
  } else if (opts->range.type == kObjectTypeInteger) {
    argt |= EX_RANGE | EX_ZEROR;
    def = opts->range.data.integer;
    addr_type_arg = ADDR_LINES;
  } else if (HAS_KEY(opts->range)) {
    api_set_error(err, kErrorTypeValidation, "Invalid value for 'range'");
    goto err;
  }

  if (opts->count.type == kObjectTypeBoolean) {
    if (opts->count.data.boolean) {
      argt |= EX_COUNT | EX_ZEROR | EX_RANGE;
      addr_type_arg = ADDR_OTHER;
      def = 0;
    }
  } else if (opts->count.type == kObjectTypeInteger) {
    argt |= EX_COUNT | EX_ZEROR | EX_RANGE;
    addr_type_arg = ADDR_OTHER;
    def = opts->count.data.integer;
  } else if (HAS_KEY(opts->count)) {
    api_set_error(err, kErrorTypeValidation, "Invalid value for 'count'");
    goto err;
  }

  if (opts->addr.type == kObjectTypeString) {
    if (parse_addr_type_arg(opts->addr.data.string.data, (int)opts->addr.data.string.size,
                            &addr_type_arg) != OK) {
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'addr'");
      goto err;
    }

    if (addr_type_arg != ADDR_LINES) {
      argt |= EX_ZEROR;
    }
  } else if (HAS_KEY(opts->addr)) {
    api_set_error(err, kErrorTypeValidation, "Invalid value for 'addr'");
    goto err;
  }

  if (api_object_to_bool(opts->bang, "bang", false, err)) {
    argt |= EX_BANG;
  } else if (ERROR_SET(err)) {
    goto err;
  }

  if (api_object_to_bool(opts->bar, "bar", false, err)) {
    argt |= EX_TRLBAR;
  } else if (ERROR_SET(err)) {
    goto err;
  }

  if (api_object_to_bool(opts->register_, "register", false, err)) {
    argt |= EX_REGSTR;
  } else if (ERROR_SET(err)) {
    goto err;
  }

  if (api_object_to_bool(opts->keepscript, "keepscript", false, err)) {
    argt |= EX_KEEPSCRIPT;
  } else if (ERROR_SET(err)) {
    goto err;
  }

  bool force = api_object_to_bool(opts->force, "force", true, err);
  if (ERROR_SET(err)) {
    goto err;
  }

  if (opts->complete.type == kObjectTypeLuaRef) {
    compl = EXPAND_USER_LUA;
    compl_luaref = api_new_luaref(opts->complete.data.luaref);
  } else if (opts->complete.type == kObjectTypeString) {
    if (parse_compl_arg(opts->complete.data.string.data,
                        (int)opts->complete.data.string.size, &compl, &argt,
                        &compl_arg) != OK) {
      api_set_error(err, kErrorTypeValidation, "Invalid value for 'complete'");
      goto err;
    }
  } else if (HAS_KEY(opts->complete)) {
    api_set_error(err, kErrorTypeValidation, "Invalid value for 'complete'");
    goto err;
  }

  switch (command.type) {
  case kObjectTypeLuaRef:
    luaref = api_new_luaref(command.data.luaref);
    if (opts->desc.type == kObjectTypeString) {
      rep = opts->desc.data.string.data;
    } else {
      snprintf((char *)IObuff, IOSIZE, "<Lua function %d>", luaref);
      rep = (char *)IObuff;
    }
    break;
  case kObjectTypeString:
    rep = command.data.string.data;
    break;
  default:
    api_set_error(err, kErrorTypeValidation, "'command' must be a string or Lua function");
    goto err;
  }

  if (uc_add_command(name.data, name.size, rep, argt, def, flags, compl, compl_arg, compl_luaref,
                     addr_type_arg, luaref, force) != OK) {
    api_set_error(err, kErrorTypeException, "Failed to create user command");
    // Do not goto err, since uc_add_command now owns luaref, compl_luaref, and compl_arg
  }

  return;

err:
  NLUA_CLEAR_REF(luaref);
  NLUA_CLEAR_REF(compl_luaref);
  xfree(compl_arg);
}

int find_sid(uint64_t channel_id)
{
  switch (channel_id) {
  case VIML_INTERNAL_CALL:
  // TODO(autocmd): Figure out what this should be
  // return SID_API_CLIENT;
  case LUA_INTERNAL_CALL:
    return SID_LUA;
  default:
    return SID_API_CLIENT;
  }
}

/// Sets sctx for API calls.
///
/// @param channel_id     api clients id. Used to determine if it's a internal
///                       call or a rpc call.
/// @return returns       previous value of current_sctx. To be used
///                       to be used for restoring sctx to previous state.
sctx_T api_set_sctx(uint64_t channel_id)
{
  sctx_T old_current_sctx = current_sctx;
  if (channel_id != VIML_INTERNAL_CALL) {
    current_sctx.sc_sid =
      channel_id == LUA_INTERNAL_CALL ? SID_LUA : SID_API_CLIENT;
    current_sctx.sc_lnum = 0;
  }
  return old_current_sctx;
}

// adapted from sign.c:sign_define_init_text.
// TODO(lewis6991): Consider merging
int init_sign_text(char **sign_text, char *text)
{
  char *s;

  char *endp = text + (int)STRLEN(text);

  // Count cells and check for non-printable chars
  int cells = 0;
  for (s = text; s < endp; s += utfc_ptr2len(s)) {
    if (!vim_isprintc(utf_ptr2char(s))) {
      break;
    }
    cells += utf_ptr2cells(s);
  }
  // Currently must be empty, one or two display cells
  if (s != endp || cells > 2) {
    return FAIL;
  }
  if (cells < 1) {
    return OK;
  }

  // Allocate one byte more if we need to pad up
  // with a space.
  size_t len = (size_t)(endp - text + ((cells == 1) ? 1 : 0));
  *sign_text = xstrnsave(text, len);

  if (cells == 1) {
    STRCPY(*sign_text + len - 1, " ");
  }

  return OK;
}

/// Check if a string contains only whitespace characters.
bool string_iswhite(String str)
{
  for (size_t i = 0; i < str.size; i++) {
    if (!ascii_iswhite(str.data[i])) {
      // Found a non-whitespace character
      return false;
    } else if (str.data[i] == NUL) {
      // Terminate at first occurence of a NUL character
      break;
    }
  }
  return true;
}

/// Build cmdline string for command, used by `nvim_cmd()`.
///
/// @return OK or FAIL.
void build_cmdline_str(char **cmdlinep, exarg_T *eap, CmdParseInfo *cmdinfo, char **args,
                       size_t argc)
{
  StringBuilder cmdline = KV_INITIAL_VALUE;

  // Add command modifiers
  if (cmdinfo->cmdmod.tab != 0) {
    kv_printf(cmdline, "%dtab ", cmdinfo->cmdmod.tab - 1);
  }
  if (cmdinfo->verbose != -1) {
    kv_printf(cmdline, "%ldverbose ", cmdinfo->verbose);
  }

  if (cmdinfo->emsg_silent) {
    kv_concat(cmdline, "silent! ");
  } else if (cmdinfo->silent) {
    kv_concat(cmdline, "silent ");
  }

  switch (cmdinfo->cmdmod.split & (WSP_ABOVE | WSP_BELOW | WSP_TOP | WSP_BOT)) {
  case WSP_ABOVE:
    kv_concat(cmdline, "aboveleft ");
    break;
  case WSP_BELOW:
    kv_concat(cmdline, "belowright ");
    break;
  case WSP_TOP:
    kv_concat(cmdline, "topleft ");
    break;
  case WSP_BOT:
    kv_concat(cmdline, "botright ");
    break;
  default:
    break;
  }

#define CMDLINE_APPEND_IF(cond, str) \
  do { \
    if (cond) { \
      kv_concat(cmdline, str); \
    } \
  } while (0)

  CMDLINE_APPEND_IF(cmdinfo->cmdmod.split & WSP_VERT, "vertical ");
  CMDLINE_APPEND_IF(cmdinfo->sandbox, "sandbox ");
  CMDLINE_APPEND_IF(cmdinfo->noautocmd, "noautocmd ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.browse, "browse ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.confirm, "confirm ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.hide, "hide ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.keepalt, "keepalt ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.keepjumps, "keepjumps ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.keepmarks, "keepmarks ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.keeppatterns, "keeppatterns ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.lockmarks, "lockmarks ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.noswapfile, "noswapfile ");
#undef CMDLINE_APPEND_IF

  // Command range / count.
  if (eap->argt & EX_RANGE) {
    if (eap->addr_count == 1) {
      kv_printf(cmdline, "%ld", eap->line2);
    } else if (eap->addr_count > 1) {
      kv_printf(cmdline, "%ld,%ld", eap->line1, eap->line2);
      eap->addr_count = 2;  // Make sure address count is not greater than 2
    }
  }

  // Keep the index of the position where command name starts, so eap->cmd can point to it.
  size_t cmdname_idx = cmdline.size;
  kv_printf(cmdline, "%s", eap->cmd);

  // Command bang.
  if (eap->argt & EX_BANG && eap->forceit) {
    kv_printf(cmdline, "!");
  }

  // Command register.
  if (eap->argt & EX_REGSTR && eap->regname) {
    kv_printf(cmdline, " %c", eap->regname);
  }

  // Iterate through each argument and store the starting index and length of each argument
  size_t *argidx = xcalloc(argc, sizeof(size_t));
  eap->argc = argc;
  eap->arglens = xcalloc(argc, sizeof(size_t));
  for (size_t i = 0; i < argc; i++) {
    argidx[i] = cmdline.size + 1;  // add 1 to account for the space.
    eap->arglens[i] = STRLEN(args[i]);
    kv_printf(cmdline, " %s", args[i]);
  }

  // Now that all the arguments are appended, use the command index and argument indices to set the
  // values of eap->cmd, eap->arg and eap->args.
  eap->cmd = cmdline.items + cmdname_idx;
  eap->args = xcalloc(argc, sizeof(char *));
  for (size_t i = 0; i < argc; i++) {
    eap->args[i] = cmdline.items + argidx[i];
  }
  // If there isn't an argument, make eap->arg point to end of cmdline.
  eap->arg = argc > 0 ? eap->args[0] : cmdline.items + cmdline.size;

  // Finally, make cmdlinep point to the cmdline string.
  *cmdlinep = cmdline.items;
  xfree(argidx);

  // Replace, :make and :grep with 'makeprg' and 'grepprg'.
  char *p = replace_makeprg(eap, eap->arg, cmdlinep);
  if (p != eap->arg) {
    // If replace_makeprg modified the cmdline string, correct the argument pointers.
    assert(argc == 1);
    eap->arg = p;
    eap->args[0] = p;
  }
}
