#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/helpers.h"
#include "nvim/api/defs.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/memory.h"
#include "nvim/eval.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"

#include "nvim/lib/khash.h"


#if defined(ARCH_64)
#define ptr_hash_func(key) kh_int64_hash_func(key)
#elif defined(ARCH_32)
#define ptr_hash_func(key) kh_int_hash_func(key)
#endif

KHASH_INIT(Lookup, uintptr_t, char, 0, ptr_hash_func, kh_int_hash_equal)

/// Recursion helper for the `vim_to_object`. This uses a pointer table
/// to avoid infinite recursion due to cyclic references
///
/// @param obj The source object
/// @param lookup Lookup table containing pointers to all processed objects
/// @return The converted value
static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup);

static bool object_to_vim(Object obj, typval_T *tv, Error *err);

static void set_option_value_for(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 int opt_type,
                                 void *from,
                                 Error *err);

static void set_option_value_err(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 Error *err);

void try_start()
{
  ++trylevel;
}

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
    strncpy(err->msg, msg, sizeof(err->msg));
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

Object dict_get_value(dict_T *dict, String key, Error *err)
{
  Object rv;
  hashitem_T *hi;
  dictitem_T *di;
  char *k = xstrndup(key.data, key.size);
  hi = hash_find(&dict->dv_hashtab, (uint8_t *)k);
  free(k);

  if (HASHITEM_EMPTY(hi)) {
    set_api_error("Key not found", err);
    return rv;
  }

  di = dict_lookup(hi);
  rv = vim_to_object(&di->di_tv);

  return rv;
}

Object dict_set_value(dict_T *dict, String key, Object value, Error *err)
{
  Object rv = {.type = kObjectTypeNil};

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
      char *k = xstrndup(key.data, key.size);
      di = dictitem_alloc((uint8_t *)k);
      free(k);
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

Object get_option_from(void *from, int type, String name, Error *err)
{
  Object rv = {.type = kObjectTypeNil};

  if (name.size == 0) {
    set_api_error("Empty option name", err);
    return rv;
  }

  // Return values
  int64_t numval;
  char *stringval = NULL;
  // copy the option name into 0-delimited string
  char *key = xstrndup(name.data, name.size);
  int flags = get_option_value_strict(key, &numval, &stringval, type, from);
  free(key);

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

void set_option_to(void *to, int type, String name, Object value, Error *err)
{
  if (name.size == 0) {
    set_api_error("Empty option name", err);
    return;
  }

  char *key = xstrndup(name.data, name.size);
  int flags = get_option_value_strict(key, NULL, NULL, type, to);

  if (flags == 0) {
    set_api_error("invalid option name", err);
    goto cleanup;
  }

  if (value.type == kObjectTypeNil) {
    if (type == SREQ_GLOBAL) {
      set_api_error("unable to unset option", err);
      goto cleanup;
    } else if (!(flags & SOPT_GLOBAL)) {
      set_api_error("cannot unset option that doesn't have a global value",
                     err);
      goto cleanup;
    } else {
      unset_global_local_option(key, to);
      goto cleanup;
    }
  }

  int opt_flags = (type ? OPT_LOCAL : OPT_GLOBAL);

  if (flags & SOPT_BOOL) {
    if (value.type != kObjectTypeBoolean) {
      set_api_error("option requires a boolean value", err);
      goto cleanup;
    }
    bool val = value.data.boolean;
    set_option_value_for(key, val, NULL, opt_flags, type, to, err);

  } else if (flags & SOPT_NUM) {
    if (value.type != kObjectTypeInteger) {
      set_api_error("option requires an integer value", err);
      goto cleanup;
    }

    if (value.data.integer > INT_MAX || value.data.integer < INT_MIN) {
      set_api_error("Option value outside range", err);
      return;
    }

    int val = (int)value.data.integer;
    set_option_value_for(key, val, NULL, opt_flags, type, to, err);
  } else {
    if (value.type != kObjectTypeString) {
      set_api_error("option requires a string value", err);
      goto cleanup;
    }

    char *val = xstrndup(value.data.string.data, value.data.string.size);
    set_option_value_for(key, 0, val, opt_flags, type, to, err);
  }

cleanup:
  free(key);
}

Object vim_to_object(typval_T *obj)
{
  Object rv;
  // We use a lookup table to break out of cyclic references
  khash_t(Lookup) *lookup = kh_init(Lookup);
  rv = vim_to_object_rec(obj, lookup);
  // Free the table
  kh_destroy(Lookup, lookup);
  return rv;
}

buf_T *find_buffer(Buffer buffer, Error *err)
{
  if (buffer > INT_MAX || buffer < INT_MIN) {
    set_api_error("Invalid buffer id", err);
    return NULL;
  }

  buf_T *buf = buflist_findnr((int)buffer);

  if (buf == NULL) {
    set_api_error("Invalid buffer id", err);
  }

  return buf;
}

win_T * find_window(Window window, Error *err)
{
  tabpage_T *tp;
  win_T *wp;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (!--window) {
      return wp;
    }
  }

  set_api_error("Invalid window id", err);
  return NULL;
}

tabpage_T * find_tab(Tabpage tabpage, Error *err)
{
  if (tabpage > INT_MAX || tabpage < INT_MIN) {
    set_api_error("Invalid tabpage id", err);
    return NULL;
  }

  tabpage_T *rv = find_tabpage((int)tabpage);

  if (!rv) {
    set_api_error("Invalid tabpage id", err);
  }

  return rv;
}

static bool object_to_vim(Object obj, typval_T *tv, Error *err)
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
      tv->vval.v_string = (uint8_t *)xstrndup(obj.data.string.data,
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

        char *k = xstrndup(key.data, key.size);
        dictitem_T *di = dictitem_alloc((uint8_t *)k);
        free(k);

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
  }

  return true;
}

static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup)
{
  Object rv = {.type = kObjectTypeNil};

  if (obj->v_type == VAR_LIST || obj->v_type == VAR_DICT) {
    int ret;
    // Container object, add it to the lookup table
    kh_put(Lookup, lookup, (uintptr_t)obj, &ret);
    if (!ret) {
      // It's already present, meaning we alredy processed it so just return
      // nil instead.
      return rv;
    }
  }

  switch (obj->v_type) {
    case VAR_STRING:
      if (obj->vval.v_string != NULL) {
        rv.type = kObjectTypeString;
        rv.data.string.data = xstrdup((char *)obj->vval.v_string);
        rv.data.string.size = strlen(rv.data.string.data);
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
              rv.data.dictionary.items[i].key.data =
                xstrdup((char *)hi->hi_key);
              rv.data.dictionary.items[i].key.size =
                strlen((char *)hi->hi_key);
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
