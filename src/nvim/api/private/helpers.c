#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/handle.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/memory.h"
#include "nvim/eval.h"
#include "nvim/map_defs.h"
#include "nvim/map.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.c.generated.h"
#endif

/// Start block that may cause vimscript exceptions
void try_start(void)
{
  ++trylevel;
}

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
bool try_end(Error *err)
{
  --trylevel;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    if (did_throw) {
      // If we got an interrupt, discard the current exception
      discard_current_exception();
    }

    set_api_error("Keyboard interrupt", err);
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = (char *)get_exception_string(*msg_list,
                                             ET_ERROR,
                                             NULL,
                                             &should_free);
    xstrlcpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
    free_global_msglist();

    if (should_free) {
      free(msg);
    }
  } else if (did_throw) {
    set_api_error((char *)current_exception->value, err);
  }

  return err->set;
}

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Error *err)
{
  hashitem_T *hi = hash_find(&dict->dv_hashtab, (uint8_t *) key.data);

  if (HASHITEM_EMPTY(hi)) {
    set_api_error("Key not found", err);
    return (Object) OBJECT_INIT;
  }

  dictitem_T *di = dict_lookup(hi);
  return vim_to_object(&di->di_tv);
}

/// Set a value in a dict. Objects are recursively expanded into their
/// vimscript equivalents. Passing 'nil' as value deletes the key.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param[out] err Details of an error that may have occurred
/// @return the old value, if any
Object dict_set_value(dict_T *dict, String key, Object value, Error *err)
{
  Object rv = OBJECT_INIT;

  if (dict->dv_lock) {
    set_api_error("Dictionary is locked", err);
    return rv;
  }

  if (key.size == 0) {
    set_api_error("Empty dictionary keys aren't allowed", err);
    return rv;
  }

  if (key.size > INT_MAX) {
    set_api_error("Key length is too high", err);
    return rv;
  }

  dictitem_T *di = dict_find(dict, (uint8_t *)key.data, (int)key.size);

  if (value.type == kObjectTypeNil) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      set_api_error("Key doesn't exist", err);
    } else {
      // Return the old value
      rv = vim_to_object(&di->di_tv);
      // Delete the entry
      hashitem_T *hi = hash_find(&dict->dv_hashtab, di->di_key);
      hash_remove(&dict->dv_hashtab, hi);
      dictitem_free(di);
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
      di = dictitem_alloc((uint8_t *) key.data);
      dict_add(dict, di);
    } else {
      // Return the old value
      clear_tv(&di->di_tv);
    }

    // Update the value
    copy_tv(&tv, &di->di_tv);
    // Clear the temporary variable
    clear_tv(&tv);
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
    set_api_error("Empty option name", err);
    return rv;
  }

  // Return values
  int64_t numval;
  char *stringval = NULL;
  int flags = get_option_value_strict(name.data, &numval, &stringval,
                                      type, from);

  if (!flags) {
    set_api_error("invalid option name", err);
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
      set_api_error(N_("Unable to get option value"), err);
    }
  } else {
    set_api_error(N_("internal error: unknown option type"), err);
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
void set_option_to(void *to, int type, String name, Object value, Error *err)
{
  if (name.size == 0) {
    set_api_error("Empty option name", err);
    return;
  }

  int flags = get_option_value_strict(name.data, NULL, NULL, type, to);

  if (flags == 0) {
    set_api_error("invalid option name", err);
    return;
  }

  if (value.type == kObjectTypeNil) {
    if (type == SREQ_GLOBAL) {
      set_api_error("unable to unset option", err);
      return;
    } else if (!(flags & SOPT_GLOBAL)) {
      set_api_error("cannot unset option that doesn't have a global value",
                     err);
      return;
    } else {
      unset_global_local_option(name.data, to);
      return;
    }
  }

  int opt_flags = (type ? OPT_LOCAL : OPT_GLOBAL);

  if (flags & SOPT_BOOL) {
    if (value.type != kObjectTypeBoolean) {
      set_api_error("option requires a boolean value", err);
      return;
    }

    bool val = value.data.boolean;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else if (flags & SOPT_NUM) {
    if (value.type != kObjectTypeInteger) {
      set_api_error("option requires an integer value", err);
      return;
    }

    if (value.data.integer > INT_MAX || value.data.integer < INT_MIN) {
      set_api_error("Option value outside range", err);
      return;
    }

    int val = (int) value.data.integer;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else {
    if (value.type != kObjectTypeString) {
      set_api_error("option requires a string value", err);
      return;
    }

    set_option_value_for(name.data, 0, value.data.string.data,
            opt_flags, type, to, err);
  }
}

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
Object vim_to_object(typval_T *obj)
{
  Object rv;
  // We use a lookup table to break out of cyclic references
  PMap(ptr_t) *lookup = pmap_new(ptr_t)();
  rv = vim_to_object_rec(obj, lookup);
  // Free the table
  pmap_free(ptr_t)(lookup);
  return rv;
}

buf_T *find_buffer_by_handle(Buffer buffer, Error *err)
{
  buf_T *rv = handle_get_buffer(buffer);

  if (!rv) {
    set_api_error("Invalid buffer id", err);
  }

  return rv;
}

win_T * find_window_by_handle(Window window, Error *err)
{
  win_T *rv = handle_get_window(window);

  if (!rv) {
    set_api_error("Invalid window id", err);
  }

  return rv;
}

tabpage_T * find_tab_by_handle(Tabpage tabpage, Error *err)
{
  tabpage_T *rv = handle_get_tabpage(tabpage);

  if (!rv) {
    set_api_error("Invalid tabpage id", err);
  }

  return rv;
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
        return (String) STRING_INIT;
    }

    size_t len = strlen(str);
    return (String) {
        .data = xmemdupz(str, len),
        .size = len
    };
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
    return (String) STRING_INIT;
  }
  return (String) {.data = str, .size = strlen(str)};
}

bool object_to_vim(Object obj, typval_T *tv, Error *err)
{
  tv->v_type = VAR_UNKNOWN;
  tv->v_lock = 0;

  switch (obj.type) {
    case kObjectTypeNil:
      tv->v_type = VAR_NUMBER;
      tv->vval.v_number = 0;
      break;

    case kObjectTypeBoolean:
      tv->v_type = VAR_NUMBER;
      tv->vval.v_number = obj.data.boolean;
      break;

    case kObjectTypeInteger:
      if (obj.data.integer > INT_MAX || obj.data.integer < INT_MIN) {
        set_api_error("Integer value outside range", err);
        return false;
      }

      tv->v_type = VAR_NUMBER;
      tv->vval.v_number = (int)obj.data.integer;
      break;

    case kObjectTypeFloat:
      tv->v_type = VAR_FLOAT;
      tv->vval.v_float = obj.data.floating;
      break;

    case kObjectTypeString:
      tv->v_type = VAR_STRING;
      tv->vval.v_string = xmemdupz(obj.data.string.data,
                                   obj.data.string.size);
      break;

    case kObjectTypeArray:
      tv->v_type = VAR_LIST;
      tv->vval.v_list = list_alloc();

      for (uint32_t i = 0; i < obj.data.array.size; i++) {
        Object item = obj.data.array.items[i];
        listitem_T *li = listitem_alloc();

        if (!object_to_vim(item, &li->li_tv, err)) {
          // cleanup
          listitem_free(li);
          list_free(tv->vval.v_list, true);
          return false;
        }

        list_append(tv->vval.v_list, li);
      }
      tv->vval.v_list->lv_refcount++;
      break;

    case kObjectTypeDictionary:
      tv->v_type = VAR_DICT;
      tv->vval.v_dict = dict_alloc();

      for (uint32_t i = 0; i < obj.data.dictionary.size; i++) {
        KeyValuePair item = obj.data.dictionary.items[i];
        String key = item.key;

        if (key.size == 0) {
          set_api_error("Empty dictionary keys aren't allowed", err);
          // cleanup
          dict_free(tv->vval.v_dict, true);
          return false;
        }

        dictitem_T *di = dictitem_alloc((uint8_t *) key.data);

        if (!object_to_vim(item.value, &di->di_tv, err)) {
          // cleanup
          dictitem_free(di);
          dict_free(tv->vval.v_dict, true);
          return false;
        }

        dict_add(tv->vval.v_dict, di);
      }
      tv->vval.v_dict->dv_refcount++;
      break;
    default:
      abort();
  }

  return true;
}

/// Recursion helper for the `vim_to_object`. This uses a pointer table
/// to avoid infinite recursion due to cyclic references
///
/// @param obj The source object
/// @param lookup Lookup table containing pointers to all processed objects
/// @return The converted value
static Object vim_to_object_rec(typval_T *obj, PMap(ptr_t) *lookup)
{
  Object rv = OBJECT_INIT;

  if (obj->v_type == VAR_LIST || obj->v_type == VAR_DICT) {
    // Container object, add it to the lookup table
    if (pmap_has(ptr_t)(lookup, obj)) {
      // It's already present, meaning we alredy processed it so just return
      // nil instead.
      return rv;
    }
    pmap_put(ptr_t)(lookup, obj, NULL);
  }

  switch (obj->v_type) {
    case VAR_STRING:
      if (obj->vval.v_string != NULL) {
        rv.type = kObjectTypeString;
        rv.data.string = cstr_to_string((char *) obj->vval.v_string);
      }
      break;

    case VAR_NUMBER:
      rv.type = kObjectTypeInteger;
      rv.data.integer = obj->vval.v_number;
      break;

    case VAR_FLOAT:
      rv.type = kObjectTypeFloat;
      rv.data.floating = obj->vval.v_float;
      break;

    case VAR_LIST:
      {
        list_T *list = obj->vval.v_list;
        listitem_T *item;

        if (list != NULL) {
          rv.type = kObjectTypeArray;
          assert(list->lv_len >= 0);
          rv.data.array.size = (size_t)list->lv_len;
          rv.data.array.items = xmalloc(rv.data.array.size * sizeof(Object));

          uint32_t i = 0;
          for (item = list->lv_first; item != NULL; item = item->li_next) {
            rv.data.array.items[i] = vim_to_object_rec(&item->li_tv, lookup);
            i++;
          }
        }
      }
      break;

    case VAR_DICT:
      {
        dict_T *dict = obj->vval.v_dict;
        hashtab_T *ht;
        uint64_t todo;
        hashitem_T *hi;
        dictitem_T *di;

        if (dict != NULL) {
          ht = &obj->vval.v_dict->dv_hashtab;
          todo = ht->ht_used;
          rv.type = kObjectTypeDictionary;

          // Count items
          rv.data.dictionary.size = 0;
          for (hi = ht->ht_array; todo > 0; ++hi) {
            if (!HASHITEM_EMPTY(hi)) {
              todo--;
              rv.data.dictionary.size++;
            }
          }

          rv.data.dictionary.items =
            xmalloc(rv.data.dictionary.size * sizeof(KeyValuePair));
          todo = ht->ht_used;
          uint32_t i = 0;

          // Convert all
          for (hi = ht->ht_array; todo > 0; ++hi) {
            if (!HASHITEM_EMPTY(hi)) {
              di = dict_lookup(hi);
              // Convert key
              rv.data.dictionary.items[i].key =
                cstr_to_string((char *) hi->hi_key);
              // Convert value
              rv.data.dictionary.items[i].value =
                vim_to_object_rec(&di->di_tv, lookup);
              todo--;
              i++;
            }
          }
        }
      }
      break;
  }

  return rv;
}


static void set_option_value_for(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 int opt_type,
                                 void *from,
                                 Error *err)
{
  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  buf_T *save_curbuf = NULL;

  try_start();
  switch (opt_type)
  {
    case SREQ_WIN:
      if (switch_win(&save_curwin, &save_curtab, (win_T *)from,
            win_find_tabpage((win_T *)from), false) == FAIL)
      {
        if (try_end(err)) {
          return;
        }
        set_api_error("problem while switching windows", err);
        return;
      }
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_win(save_curwin, save_curtab, true);
      break;
    case SREQ_BUF:
      switch_buffer(&save_curbuf, (buf_T *)from);
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_buffer(save_curbuf);
      break;
    case SREQ_GLOBAL:
      set_option_value_err(key, numval, stringval, opt_flags, err);
      break;
  }

  if (err->set) {
    return;
  }

  try_end(err);
}


static void set_option_value_err(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 Error *err)
{
  char *errmsg;

  if ((errmsg = (char *)set_option_value((uint8_t *)key,
                                         numval,
                                         (uint8_t *)stringval,
                                         opt_flags)))
  {
    if (try_end(err)) {
      return;
    }

    set_api_error(errmsg, err);
  }
}
