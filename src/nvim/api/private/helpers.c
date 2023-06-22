// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <msgpack/unpack.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_eval.h"
#include "nvim/garray.h"
#include "nvim/highlight_group.h"
#include "nvim/lua/executor.h"
#include "nvim/map.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/pos.h"
#include "nvim/ui.h"
#include "nvim/version.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/funcs_metadata.generated.h"
# include "api/private/helpers.c.generated.h"
# include "api/private/ui_events_metadata.generated.h"
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
  } else if (did_throw) {
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

  bool watched = tv_dict_is_watched(dict);

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      api_set_error(err, kErrorTypeValidation, "Key not found: %s",
                    key.data);
    } else {
      // Notify watchers
      if (watched) {
        tv_dict_watcher_notify(dict, key.data, NULL, &di->di_tv);
      }
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

    typval_T oldtv = TV_INITIAL_VALUE;

    if (di == NULL) {
      // Need to create an entry
      di = tv_dict_item_alloc_len(key.data, key.size);
      tv_dict_add(dict, di);
    } else {
      if (watched) {
        tv_copy(&di->di_tv, &oldtv);
      }
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv);
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

  char *bufstr = ml_get_buf(buf, (linenr_T)lnum, false);
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

  return cstrn_as_string(&bufstr[start_col], (size_t)(end_col - start_col));
}

void api_free_string(String value)
{
  if (!value.data) {
    return;
  }

  xfree(value.data);
}

Array arena_array(Arena *arena, size_t max_size)
{
  Array arr = ARRAY_DICT_INIT;
  kv_fixsize_arena(arena, arr, max_size);
  return arr;
}

Dictionary arena_dict(Arena *arena, size_t max_size)
{
  Dictionary dict = ARRAY_DICT_INIT;
  kv_fixsize_arena(arena, dict, max_size);
  return dict;
}

String arena_string(Arena *arena, String str)
{
  if (str.size) {
    return cbuf_as_string(arena_memdupz(arena, str.data, str.size), str.size);
  } else {
    return (String)STRING_INIT;
  }
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

/// @returns a shared value. caller must not modify it!
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

  return metadata;
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
  ADD(ui_options, CSTR_TO_OBJ("rgb"));
  for (UIExtension i = 0; i < kUIExtCount; i++) {
    if (ui_ext_names[i][0] != '_') {
      ADD(ui_options, CSTR_TO_OBJ(ui_ext_names[i]));
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
  PUT(buffer_metadata, "prefix", CSTR_TO_OBJ("nvim_buf_"));

  Dictionary window_metadata = ARRAY_DICT_INIT;
  PUT(window_metadata, "id",
      INTEGER_OBJ(kObjectTypeWindow - EXT_OBJECT_TYPE_SHIFT));
  PUT(window_metadata, "prefix", CSTR_TO_OBJ("nvim_win_"));

  Dictionary tabpage_metadata = ARRAY_DICT_INIT;
  PUT(tabpage_metadata, "id",
      INTEGER_OBJ(kObjectTypeTabpage - EXT_OBJECT_TYPE_SHIFT));
  PUT(tabpage_metadata, "prefix", CSTR_TO_OBJ("nvim_tabpage_"));

  PUT(types, "Buffer", DICTIONARY_OBJ(buffer_metadata));
  PUT(types, "Window", DICTIONARY_OBJ(window_metadata));
  PUT(types, "Tabpage", DICTIONARY_OBJ(tabpage_metadata));

  PUT(*metadata, "types", DICTIONARY_OBJ(types));
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

Dictionary copy_dictionary(Dictionary dict, Arena *arena)
{
  Dictionary rv = arena_dict(arena, dict.size);
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

  case kObjectTypeDictionary:
    return DICTIONARY_OBJ(copy_dictionary(obj.data.dictionary, arena));

  case kObjectTypeLuaRef:
    return LUAREF_OBJ(api_new_luaref(obj.data.luaref));

  default:
    abort();
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
    return MAX((int)obj.data.integer, 0);
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
  case kObjectTypeDictionary:
    return "Dict";
  case kObjectTypeLuaRef:
    return "Function";
  case kObjectTypeBuffer:
    return "Buffer";
  case kObjectTypeWindow:
    return "Window";
  case kObjectTypeTabpage:
    return "Tabpage";
  default:
    abort();
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

    String str = copy_string(chunk.items[0].data.string, NULL);

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
  hl_msg_free(hl_msg);
  return (HlMessage)KV_INITIAL_VALUE;
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
  assert(INT32_MIN <= line && line <= INT32_MAX);
  pos_T pos = { (linenr_T)line, (int)col, (int)col };
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
