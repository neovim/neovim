#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "api/vim.h"
#include "api/defs.h"
#include "../vim.h"
#include "types.h"
#include "ascii.h"
#include "ex_docmd.h"
#include "screen.h"
#include "eval.h"
#include "misc2.h"
#include "memory.h"

#include "lib/khash.h"

KHASH_SET_INIT_INT64(Lookup)

/// Start block that may cause vimscript exceptions
static void try_start(void);

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
static bool try_end(Error *err);

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
static Object vim_to_object(typval_T *vim_obj);

/// Recursion helper for the `vim_to_object`. This uses a pointer table
/// to avoid infinite recursion due to cyclic references
///
/// @param obj The source object
/// @param lookup Lookup table containing pointers to all processed objects
/// @return The converted value
static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup);

void vim_push_keys(String str)
{
  abort();
}

void vim_command(String str, Error *err)
{
  // We still use 0-terminated strings, so we must convert.
  char cmd_str[str.size + 1];
  memcpy(cmd_str, str.data, str.size);
  cmd_str[str.size] = NUL;
  // Run the command
  try_start();
  do_cmdline_cmd((char_u *)cmd_str);
  update_screen(VALID);
  try_end(err);
}

Object vim_eval(String str, Error *err)
{
  Object rv;

  char expr_str[str.size + 1];
  memcpy(expr_str, str.data, str.size);
  expr_str[str.size] = NUL;
  // Evaluate the expression
  try_start();
  typval_T *expr_result = eval_expr((char_u *)expr_str, NULL);

  if (!try_end(err)) {
    // No errors, convert the result
    rv = vim_to_object(expr_result);
  }

  // Free the vim object
  free_tv(expr_result);
  return rv;
}

int64_t vim_strwidth(String str)
{
  return mb_string2cells((char_u *)str.data, str.size);
}

StringArray vim_list_runtime_paths(void)
{
  StringArray rv = {.size = 0};
  uint8_t *rtp = p_rtp;

  if (*rtp == NUL) {
    // No paths
    return rv;
  }

  // Count the number of paths in rtp
  while (*rtp != NUL) {
    if (*rtp == ',') {
      rv.size++;
    }
    rtp++;
  }

  // index
  uint32_t i = 0;
  // Allocate memory for the copies
  rv.items = xmalloc(sizeof(String) * rv.size);
  // reset the position
  rtp = p_rtp;
  // Start copying
  while (*rtp != NUL) {
    rv.items[i].data = xmalloc(MAXPATHL);
    // Copy the path from 'runtimepath' to rv.items[i]
    rv.items[i].size = copy_option_part(&rtp,
                                       (char_u *)rv.items[i].data,
                                       MAXPATHL,
                                       ",");
    i++;
  }

  return rv;
}

void vim_change_directory(String dir)
{
  abort();
}

String vim_get_current_line(void)
{
  abort();
}

void vim_set_current_line(String line)
{
  abort();
}

Object vim_get_var(bool special, String name, Error *err)
{
  abort();
}

void vim_set_var(bool special, String name, Object value, Error *err)
{
  abort();
}

String vim_get_option(String name, Error *err)
{
  abort();
}

void vim_set_option(String name, String value, Error *err)
{
  abort();
}

void vim_del_option(String name, Error *err)
{
  abort();
}

void vim_out_write(String str)
{
  abort();
}

void vim_err_write(String str)
{
  abort();
}

int64_t vim_get_buffer_count(void)
{
  abort();
}

Buffer vim_get_buffer(int64_t num, Error *err)
{
  abort();
}

Buffer vim_get_current_buffer(void)
{
  abort();
}

void vim_set_current_buffer(Buffer buffer)
{
  abort();
}

int64_t vim_get_window_count(void)
{
  abort();
}

Window vim_get_window(int64_t num, Error *err)
{
  abort();
}

Window vim_get_current_window(void)
{
  abort();
}

void vim_set_current_window(Window window)
{
  abort();
}

int64_t vim_get_tabpage_count(void)
{
  abort();
}

Tabpage vim_get_tabpage(int64_t num, Error *err)
{
  abort();
}

Tabpage vim_get_current_tabpage(void)
{
  abort();
}

void vim_set_current_tabpage(Tabpage tabpage)
{
  abort();
}

static void try_start()
{
  ++trylevel;
}

static bool try_end(Error *err)
{
  --trylevel;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    const char msg[] = "Keyboard interrupt";

    if (did_throw) {
      // If we got an interrupt, discard the current exception 
      discard_current_exception();
    }

    strncpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
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
    strncpy(err->msg, (char *)current_exception->value, sizeof(err->msg));
    err->set = true;
  }

  return err->set;
}

static Object vim_to_object(typval_T *obj)
{
  Object rv;
  // We use a lookup table to break out of cyclic references 
  khash_t(Lookup) *lookup = kh_init(Lookup);
  rv = vim_to_object_rec(obj, lookup);
  // Free the table
  kh_destroy(Lookup, lookup);
  return rv;
}

static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup)
{
  Object rv = {.type = kObjectTypeNil};

  if (obj->v_type == VAR_LIST || obj->v_type == VAR_DICT) {
    int ret;
    // Container object, add it to the lookup table
    kh_put(Lookup, lookup, (uint64_t)obj, &ret);
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
      rv.type = kObjectTypeInt;
      rv.data.integer = obj->vval.v_number;
      break;

    case VAR_FLOAT:
      rv.type = kObjectTypeFloat;
      rv.data.floating_point = obj->vval.v_float;
      break;

    case VAR_LIST:
      {
        list_T *list = obj->vval.v_list;
        listitem_T *item;

        if (list != NULL) {
          rv.type = kObjectTypeArray;
          rv.data.array.size = list->lv_len;
          rv.data.array.items = xmalloc(list->lv_len * sizeof(Object));

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
