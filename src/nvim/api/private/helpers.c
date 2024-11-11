#include <assert.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_eval.h"
#include "nvim/garray_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/map_defs.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/version.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/api_metadata.generated.h"
# include "api/private/helpers.c.generated.h"
#endif

/// Start block that may cause Vimscript exceptions while evaluating another code
///
/// Used when caller is supposed to be operating when other Vimscript code is being
/// processed and that “other Vimscript code” must not be affected.
///
/// @param[out]  tstate  Location where try state should be saved.
void try_enter(TryState *const tstate)
{
  // TODO(ZyX-I): Check whether try_enter()/try_leave() may use
  //              enter_cleanup()/leave_cleanup(). Or
  //              save_dbg_stuff()/restore_dbg_stuff().
  *tstate = (TryState) {
    .current_exception = current_exception,
    .msg_list = (const msglist_T *const *)msg_list,
    .private_msg_list = NULL,
    .trylevel = trylevel,
    .got_int = got_int,
    .did_throw = did_throw,
    .need_rethrow = need_rethrow,
    .did_emsg = did_emsg,
  };
  msg_list = &tstate->private_msg_list;
  current_exception = NULL;
  trylevel = 1;
  got_int = false;
  did_throw = false;
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
  assert(!did_throw);
  assert(!did_emsg);
  assert(msg_list == &tstate->private_msg_list);
  assert(*msg_list == NULL);
  assert(current_exception == NULL);
  msg_list = (msglist_T **)tstate->msg_list;
  current_exception = tstate->current_exception;
  trylevel = tstate->trylevel;
  got_int = tstate->got_int;
  did_throw = tstate->did_throw;
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
    if (did_throw) {
      // If we got an interrupt, discard the current exception
      discard_current_exception();
    }

    api_set_error(err, kErrorTypeException, "Keyboard interrupt");
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    bool should_free;
    char *msg = get_exception_string(*msg_list,
                                     ET_ERROR,
                                     NULL,
                                     &should_free);
    api_set_error(err, kErrorTypeException, "%s", msg);
    free_global_msglist();

    if (should_free) {
      xfree(msg);
    }
  } else if (did_throw || need_rethrow) {
    if (*current_exception->throw_name != NUL) {
      if (current_exception->throw_lnum != 0) {
        api_set_error(err, kErrorTypeException, "%s, line %" PRIdLINENR ": %s",
                      current_exception->throw_name, current_exception->throw_lnum,
                      current_exception->value);
      } else {
        api_set_error(err, kErrorTypeException, "%s: %s",
                      current_exception->throw_name, current_exception->value);
      }
    } else {
      api_set_error(err, kErrorTypeException, "%s", current_exception->value);
    }
    discard_current_exception();
  }

  return ERROR_SET(err);
}

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Arena *arena, Error *err)
{
  dictitem_T *const di = tv_dict_find(dict, key.data, (ptrdiff_t)key.size);

  if (di == NULL) {
    api_set_error(err, kErrorTypeValidation, "Key not found: %s", key.data);
    return (Object)OBJECT_INIT;
  }

  return vim_to_object(&di->di_tv, arena, true);
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
    api_set_error(err, kErrorTypeException, "Dict is locked");
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
Object dict_set_var(dict_T *dict, String key, Object value, bool del, bool retval, Arena *arena,
                    Error *err)
{
  Object rv = OBJECT_INIT;
  dictitem_T *di = dict_check_writable(dict, key, del, err);

  if (ERROR_SET(err)) {
    return rv;
  }

  bool watched = tv_dict_is_watched(dict);

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      api_set_error(err, kErrorTypeValidation, "Key not found: %s", key.data);
    } else {
      // Notify watchers
      if (watched) {
        tv_dict_watcher_notify(dict, key.data, NULL, &di->di_tv);
      }
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv, arena, false);
      }
      // Delete the entry
      tv_dict_item_remove(dict, di);
    }
  } else {
    // Update the key
    typval_T tv;

    // Convert the object to a vimscript type in the temporary variable
    object_to_vim(value, &tv, err);

    typval_T oldtv = TV_INITIAL_VALUE;

    if (di == NULL) {
      // Need to create an entry
      di = tv_dict_item_alloc_len(key.data, key.size);
      tv_dict_add(dict, di);
    } else {
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv, arena, false);
      }
      bool type_error = false;
      if (dict == &vimvardict
          && !before_set_vvar(key.data, di, &tv, true, watched, &type_error)) {
        tv_clear(&tv);
        if (type_error) {
          api_set_error(err, kErrorTypeValidation,
                        "Setting v:%s to value with wrong type", key.data);
        }
        return rv;
      }
      if (watched) {
        tv_copy(&di->di_tv, &oldtv);
      }
      tv_clear(&di->di_tv);
    }

    // Update the value
    tv_copy(&tv, &di->di_tv);

    // Notify watchers
    if (watched) {
      tv_dict_watcher_notify(dict, key.data, &tv, &oldtv);
      tv_clear(&oldtv);
    }

    // Clear the temporary variable
    tv_clear(&tv);
  }

  return rv;
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
  return cbuf_to_string(str, strnlen(str, maxsize));
}

String cstrn_as_string(char *str, size_t maxsize)
  FUNC_ATTR_NONNULL_ALL
{
  return cbuf_as_string(str, strnlen(str, maxsize));
}

/// Creates a String using the given C string. Unlike
/// cstr_to_string this function DOES NOT copy the C string.
///
/// @param str the C string to use
/// @return The resulting String, or an empty String if
///           str was NULL
String cstr_as_string(const char *str) FUNC_ATTR_PURE
{
  if (str == NULL) {
    return (String)STRING_INIT;
  }
  return (String){ .data = (char *)str, .size = strlen(str) };
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
Array string_to_array(const String input, bool crlf, Arena *arena)
{
  ArrayBuilder ret = ARRAY_DICT_INIT;
  kvi_init(ret);
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
    String s = CBUF_TO_ARENA_STR(arena, start, line_len);
    memchrsub(s.data, NUL, NL, line_len);
    kvi_push(ret, STRING_OBJ(s));
    // If line ends at end-of-buffer, add empty final item.
    // This is "readfile()-style", see also ":help channel-lines".
    if (i + 1 == input.size && (*end == NL || (crlf && *end == CAR))) {
      kvi_push(ret, STRING_OBJ(STRING_INIT));
    }
  }

  return arena_take_arraybuilder(arena, &ret);
}

/// Normalizes 0-based indexes to buffer line numbers.
int64_t normalize_index(buf_T *buf, int64_t index, bool end_exclusive, bool *oob)
{
  assert(buf->b_ml.ml_line_count > 0);
  int64_t max_index = buf->b_ml.ml_line_count + (int)end_exclusive - 1;
  // A negative index counts from the bottom.
  index = index < 0 ? max_index + index + 1 : index;

  // Check for oob and clamp.
  if (index > max_index) {
    *oob = true;
    index = max_index;
  } else if (index < 0) {
    *oob = true;
    index = 0;
  }
  // Convert the index to a 1-based line number.
  index++;
  return index;
}

/// Returns a substring of a buffer line
///
/// @param buf          Buffer handle
/// @param lnum         Line number (1-based)
/// @param start_col    Starting byte offset into line (0-based)
/// @param end_col      Ending byte offset into line (0-based, exclusive)
/// @param err          Error object
/// @return The text between start_col and end_col on line lnum of buffer buf
String buf_get_text(buf_T *buf, int64_t lnum, int64_t start_col, int64_t end_col, Error *err)
{
  String rv = STRING_INIT;

  if (lnum >= MAXLNUM) {
    api_set_error(err, kErrorTypeValidation, "Line index is too high");
    return rv;
  }

  char *bufstr = ml_get_buf(buf, (linenr_T)lnum);
  colnr_T line_length = ml_get_buf_len(buf, (linenr_T)lnum);

  start_col = start_col < 0 ? line_length + start_col + 1 : start_col;
  end_col = end_col < 0 ? line_length + end_col + 1 : end_col;

  start_col = MIN(MAX(0, start_col), line_length);
  end_col = MIN(MAX(0, end_col), line_length);

  if (start_col > end_col) {
    api_set_error(err, kErrorTypeValidation, "start_col must be less than or equal to end_col");
    return rv;
  }

  return cbuf_as_string(bufstr + start_col, (size_t)(end_col - start_col));
}

void api_free_string(String value)
{
  xfree(value.data);
}

Array arena_array(Arena *arena, size_t max_size)
{
  Array arr = ARRAY_DICT_INIT;
  kv_fixsize_arena(arena, arr, max_size);
  return arr;
}

Dict arena_dict(Arena *arena, size_t max_size)
{
  Dict dict = ARRAY_DICT_INIT;
  kv_fixsize_arena(arena, dict, max_size);
  return dict;
}

String arena_string(Arena *arena, String str)
{
  if (str.size) {
    return cbuf_as_string(arena_memdupz(arena, str.data, str.size), str.size);
  } else {
    return (String){ .data = arena ? "" : xstrdup(""), .size = 0 };
  }
}

Array arena_take_arraybuilder(Arena *arena, ArrayBuilder *arr)
{
  Array ret = arena_array(arena, kv_size(*arr));
  ret.size = kv_size(*arr);
  memcpy(ret.items, arr->items, sizeof(ret.items[0]) * ret.size);
  kvi_destroy(*arr);
  return ret;
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

  case kObjectTypeDict:
    api_free_dict(value.data.dict);
    break;

  case kObjectTypeLuaRef:
    api_free_luaref(value.data.luaref);
    break;
  }
}

void api_free_array(Array value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_free_object(value.items[i]);
  }

  xfree(value.items);
}

void api_free_dict(Dict value)
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

// initialized once, never freed
static ArenaMem mem_for_metadata = NULL;

/// @returns a shared value. caller must not modify it!
Object api_metadata(void)
{
  static Object metadata = OBJECT_INIT;

  if (metadata.type == kObjectTypeNil) {
    Arena arena = ARENA_EMPTY;
    Error err = ERROR_INIT;
    metadata = unpack((char *)packed_api_metadata, sizeof(packed_api_metadata), &arena, &err);
    if (ERROR_SET(&err) || metadata.type != kObjectTypeDict) {
      abort();
    }
    mem_for_metadata = arena_finish(&arena);
  }

  return metadata;
}

String api_metadata_raw(void)
{
  return cbuf_as_string((char *)packed_api_metadata, sizeof(packed_api_metadata));
}

// all the copy_[object] functions allow arena=NULL,
// then global allocations are used, and the resulting object
// should be freed with an api_free_[object] function

String copy_string(String str, Arena *arena)
{
  if (str.data != NULL) {
    return (String){ .data = arena_memdupz(arena, str.data, str.size), .size = str.size };
  } else {
    return (String)STRING_INIT;
  }
}

Array copy_array(Array array, Arena *arena)
{
  Array rv = arena_array(arena, array.size);
  for (size_t i = 0; i < array.size; i++) {
    ADD(rv, copy_object(array.items[i], arena));
  }
  return rv;
}

Dict copy_dict(Dict dict, Arena *arena)
{
  Dict rv = arena_dict(arena, dict.size);
  for (size_t i = 0; i < dict.size; i++) {
    KeyValuePair item = dict.items[i];
    PUT_C(rv, copy_string(item.key, arena).data, copy_object(item.value, arena));
  }
  return rv;
}

/// Creates a deep clone of an object
Object copy_object(Object obj, Arena *arena)
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
    return STRING_OBJ(copy_string(obj.data.string, arena));

  case kObjectTypeArray:
    return ARRAY_OBJ(copy_array(obj.data.array, arena));

  case kObjectTypeDict:
    return DICT_OBJ(copy_dict(obj.data.dict, arena));

  case kObjectTypeLuaRef:
    return LUAREF_OBJ(api_new_luaref(obj.data.luaref));
  }
  UNREACHABLE;
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
    return nil_value;  // caller decides what NIL (missing retval in Lua) means
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
    int id = (int)obj.data.integer;
    return (1 <= id && id <= highlight_num_groups()) ? id : 0;
  } else {
    api_set_error(err, kErrorTypeValidation, "Invalid highlight: %s", what);
    return 0;
  }
}

char *api_typename(ObjectType t)
{
  switch (t) {
  case kObjectTypeNil:
    return "nil";
  case kObjectTypeBoolean:
    return "Boolean";
  case kObjectTypeInteger:
    return "Integer";
  case kObjectTypeFloat:
    return "Float";
  case kObjectTypeString:
    return "String";
  case kObjectTypeArray:
    return "Array";
  case kObjectTypeDict:
    return "Dict";
  case kObjectTypeLuaRef:
    return "Function";
  case kObjectTypeBuffer:
    return "Buffer";
  case kObjectTypeWindow:
    return "Window";
  case kObjectTypeTabpage:
    return "Tabpage";
  }
  UNREACHABLE;
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

    String str = copy_string(chunk.items[0].data.string, NULL);

    int hl_id = 0;
    if (chunk.size == 2) {
      String hl = chunk.items[1].data.string;
      if (hl.size > 0) {
        // TODO(bfredl): use object_to_hl_id and allow integer
        hl_id = syn_check_group(hl.data, hl.size);
      }
    }
    kv_push(hl_msg, ((HlMessageChunk){ .text = str, .hl_id = hl_id }));
  }

  return hl_msg;

free_exit:
  hl_msg_free(hl_msg);
  return (HlMessage)KV_INITIAL_VALUE;
}

// see also nlua_pop_keydict for the lua specific implementation
bool api_dict_to_keydict(void *retval, FieldHashfn hashy, Dict dict, Error *err)
{
  for (size_t i = 0; i < dict.size; i++) {
    String k = dict.items[i].key;
    KeySetLink *field = hashy(k.data, k.size);
    if (!field) {
      api_set_error(err, kErrorTypeValidation, "Invalid key: '%.*s'", (int)k.size, k.data);
      return false;
    }

    if (field->opt_index >= 0) {
      OptKeySet *ks = (OptKeySet *)retval;
      ks->is_set_ |= (1ULL << field->opt_index);
    }

    char *mem = ((char *)retval + field->ptr_off);
    Object *value = &dict.items[i].value;

    if (field->type == kObjectTypeNil) {
      *(Object *)mem = *value;
    } else if (field->type == kObjectTypeInteger) {
      if (field->is_hlgroup) {
        int hl_id = 0;
        if (value->type != kObjectTypeNil) {
          hl_id = object_to_hl_id(*value, k.data, err);
          if (ERROR_SET(err)) {
            return false;
          }
        }
        *(Integer *)mem = hl_id;
      } else {
        VALIDATE_T(field->str, kObjectTypeInteger, value->type, {
          return false;
        });

        *(Integer *)mem = value->data.integer;
      }
    } else if (field->type == kObjectTypeFloat) {
      Float *val = (Float *)mem;
      if (value->type == kObjectTypeInteger) {
        *val = (Float)value->data.integer;
      } else {
        VALIDATE_T(field->str, kObjectTypeFloat, value->type, {
          return false;
        });
        *val = value->data.floating;
      }
    } else if (field->type == kObjectTypeBoolean) {
      // caller should check HAS_KEY to override the nil behavior, or GET_BOOL_OR_TRUE
      // to directly use true when nil
      *(Boolean *)mem = api_object_to_bool(*value, field->str, false, err);
      if (ERROR_SET(err)) {
        return false;
      }
    } else if (field->type == kObjectTypeString) {
      VALIDATE_T(field->str, kObjectTypeString, value->type, {
        return false;
      });
      *(String *)mem = value->data.string;
    } else if (field->type == kObjectTypeArray) {
      VALIDATE_T(field->str, kObjectTypeArray, value->type, {
        return false;
      });
      *(Array *)mem = value->data.array;
    } else if (field->type == kObjectTypeDict) {
      Dict *val = (Dict *)mem;
      // allow empty array as empty dict for lua (directly or via lua-client RPC)
      if (value->type == kObjectTypeArray && value->data.array.size == 0) {
        *val = (Dict)ARRAY_DICT_INIT;
      } else if (value->type == kObjectTypeDict) {
        *val = value->data.dict;
      } else {
        api_err_exp(err, field->str, api_typename((ObjectType)field->type),
                    api_typename(value->type));
        return false;
      }
    } else if (field->type == kObjectTypeBuffer || field->type == kObjectTypeWindow
               || field->type == kObjectTypeTabpage) {
      if (value->type == kObjectTypeInteger || value->type == (ObjectType)field->type) {
        *(handle_T *)mem = (handle_T)value->data.integer;
      } else {
        api_err_exp(err, field->str, api_typename((ObjectType)field->type),
                    api_typename(value->type));
        return false;
      }
    } else if (field->type == kObjectTypeLuaRef) {
      api_set_error(err, kErrorTypeValidation, "Invalid key: '%.*s' is only allowed from Lua",
                    (int)k.size, k.data);
      return false;
    } else {
      abort();
    }
  }

  return true;
}

Dict api_keydict_to_dict(void *value, KeySetLink *table, size_t max_size, Arena *arena)
{
  Dict rv = arena_dict(arena, max_size);
  for (size_t i = 0; table[i].str; i++) {
    KeySetLink *field = &table[i];
    bool is_set = true;
    if (field->opt_index >= 0) {
      OptKeySet *ks = (OptKeySet *)value;
      is_set = ks->is_set_ & (1ULL << field->opt_index);
    }

    if (!is_set) {
      continue;
    }

    char *mem = ((char *)value + field->ptr_off);
    Object val = NIL;

    if (field->type == kObjectTypeNil) {
      val = *(Object *)mem;
    } else if (field->type == kObjectTypeInteger) {
      val = INTEGER_OBJ(*(Integer *)mem);
    } else if (field->type == kObjectTypeFloat) {
      val = FLOAT_OBJ(*(Float *)mem);
    } else if (field->type == kObjectTypeBoolean) {
      val = BOOLEAN_OBJ(*(Boolean *)mem);
    } else if (field->type == kObjectTypeString) {
      val = STRING_OBJ(*(String *)mem);
    } else if (field->type == kObjectTypeArray) {
      val = ARRAY_OBJ(*(Array *)mem);
    } else if (field->type == kObjectTypeDict) {
      val = DICT_OBJ(*(Dict *)mem);
    } else if (field->type == kObjectTypeBuffer || field->type == kObjectTypeWindow
               || field->type == kObjectTypeTabpage) {
      val.data.integer = *(handle_T *)mem;
      val.type = (ObjectType)field->type;
    } else if (field->type == kObjectTypeLuaRef) {
      // do nothing
    } else {
      abort();
    }

    PUT_C(rv, field->str, val);
  }

  return rv;
}

void api_luarefs_free_object(Object value)
{
  // TODO(bfredl): this is more complicated than it needs to be.
  // we should be able to lock down more specifically where luarefs can be
  switch (value.type) {
  case kObjectTypeLuaRef:
    api_free_luaref(value.data.luaref);
    break;

  case kObjectTypeArray:
    api_luarefs_free_array(value.data.array);
    break;

  case kObjectTypeDict:
    api_luarefs_free_dict(value.data.dict);
    break;

  default:
    break;
  }
}

void api_luarefs_free_keydict(void *dict, KeySetLink *table)
{
  for (size_t i = 0; table[i].str; i++) {
    char *mem = ((char *)dict + table[i].ptr_off);
    if (table[i].type == kObjectTypeNil) {
      api_luarefs_free_object(*(Object *)mem);
    } else if (table[i].type == kObjectTypeLuaRef) {
      api_free_luaref(*(LuaRef *)mem);
    } else if (table[i].type == kObjectTypeDict) {
      api_luarefs_free_dict(*(Dict *)mem);
    }
  }
}

void api_luarefs_free_array(Array value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_luarefs_free_object(value.items[i]);
  }
}

void api_luarefs_free_dict(Dict value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_luarefs_free_object(value.items[i].value);
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
  assert(INT32_MIN <= line && line <= INT32_MAX);
  pos_T pos = { (linenr_T)line, (int)col, 0 };
  res = setmark_pos(*name.data, &pos, buf->handle, NULL);
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
const char *get_default_stl_hl(win_T *wp, bool use_winbar, int stc_hl_id)
{
  if (wp == NULL) {
    return "TabLineFill";
  } else if (use_winbar) {
    return (wp == curwin) ? "WinBar" : "WinBarNC";
  } else if (stc_hl_id > 0) {
    return syn_id2name(stc_hl_id);
  } else {
    return (wp == curwin) ? "StatusLine" : "StatusLineNC";
  }
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
