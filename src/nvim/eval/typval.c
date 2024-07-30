#include <assert.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/charset.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/gc.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/typval_encode.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/input.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

/// struct storing information about current sort
typedef struct {
  int item_compare_ic;
  bool item_compare_lc;
  bool item_compare_numeric;
  bool item_compare_numbers;
  bool item_compare_float;
  const char *item_compare_func;
  partial_T *item_compare_partial;
  dict_T *item_compare_selfdict;
  bool item_compare_func_err;
} sortinfo_T;

/// Structure representing one list item, used for sort array.
typedef struct {
  listitem_T *item;  ///< Sorted list item.
  int idx;  ///< Sorted list item index.
} ListSortItem;

typedef int (*ListSorter)(const void *, const void *);

/// Type for tv_dict2list() function
typedef enum {
  kDict2ListKeys,    ///< List dictionary keys.
  kDict2ListValues,  ///< List dictionary values.
  kDict2ListItems,   ///< List dictionary contents: [keys, values].
} DictListType;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/typval.c.generated.h"
#endif

static const char e_variable_nested_too_deep_for_unlock[]
  = N_("E743: Variable nested too deep for (un)lock");
static const char e_using_invalid_value_as_string[]
  = N_("E908: Using an invalid value as a String");
static const char e_string_required_for_argument_nr[]
  = N_("E1174: String required for argument %d");
static const char e_non_empty_string_required_for_argument_nr[]
  = N_("E1175: Non-empty string required for argument %d");
static const char e_dict_required_for_argument_nr[]
  = N_("E1206: Dictionary required for argument %d");
static const char e_number_required_for_argument_nr[]
  = N_("E1210: Number required for argument %d");
static const char e_list_required_for_argument_nr[]
  = N_("E1211: List required for argument %d");
static const char e_bool_required_for_argument_nr[]
  = N_("E1212: Bool required for argument %d");
static const char e_float_or_number_required_for_argument_nr[]
  = N_("E1219: Float or Number required for argument %d");
static const char e_string_or_number_required_for_argument_nr[]
  = N_("E1220: String or Number required for argument %d");
static const char e_string_or_list_required_for_argument_nr[]
  = N_("E1222: String or List required for argument %d");
static const char e_string_list_or_dict_required_for_argument_nr[]
  = N_("E1225: String, List or Dictionary required for argument %d");
static const char e_list_or_blob_required_for_argument_nr[]
  = N_("E1226: List or Blob required for argument %d");
static const char e_blob_required_for_argument_nr[]
  = N_("E1238: Blob required for argument %d");
static const char e_invalid_value_for_blob_nr[]
  = N_("E1239: Invalid value for blob: %d");
static const char e_string_list_or_blob_required_for_argument_nr[]
  = N_("E1252: String, List or Blob required for argument %d");
static const char e_string_or_function_required_for_argument_nr[]
  = N_("E1256: String or function required for argument %d");
static const char e_non_null_dict_required_for_argument_nr[]
  = N_("E1297: Non-NULL Dictionary required for argument %d");

bool tv_in_free_unref_items = false;

// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100

const char *const tv_empty_string = "";

//{{{1 Lists
//{{{2 List item

/// Allocate a list item
///
/// @warning Allocated item is not initialized, do not forget to initialize it
///          and specifically set lv_lock.
///
/// @return [allocated] new list item.
static listitem_T *tv_list_item_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC
{
  return xmalloc(sizeof(listitem_T));
}

/// Remove a list item from a List and free it
///
/// Also clears the value.
///
/// @param[out]  l  List to remove item from.
/// @param[in,out]  item  Item to remove.
///
/// @return Pointer to the list item just after removed one, NULL if removed
///         item was the last one.
listitem_T *tv_list_item_remove(list_T *const l, listitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T *const next_item = TV_LIST_ITEM_NEXT(l, item);
  tv_list_drop_items(l, item, item);
  tv_clear(TV_LIST_ITEM_TV(item));
  xfree(item);
  return next_item;
}

//{{{2 List watchers

/// Add a watcher to a list
///
/// @param[out]  l  List to add watcher to.
/// @param[in]  lw  Watcher to add.
void tv_list_watch_add(list_T *const l, listwatch_T *const lw)
  FUNC_ATTR_NONNULL_ALL
{
  lw->lw_next = l->lv_watch;
  l->lv_watch = lw;
}

/// Remove a watcher from a list
///
/// Does not give a warning if watcher was not found.
///
/// @param[out]  l  List to remove watcher from.
/// @param[in]  lwrem  Watcher to remove.
void tv_list_watch_remove(list_T *const l, listwatch_T *const lwrem)
  FUNC_ATTR_NONNULL_ALL
{
  listwatch_T **lwp = &l->lv_watch;
  for (listwatch_T *lw = l->lv_watch; lw != NULL; lw = lw->lw_next) {
    if (lw == lwrem) {
      *lwp = lw->lw_next;
      break;
    }
    lwp = &lw->lw_next;
  }
}

/// Advance watchers to the next item
///
/// Used just before removing an item from a list.
///
/// @param[out]  l  List from which item is removed.
/// @param[in]  item  List item being removed.
void tv_list_watch_fix(list_T *const l, const listitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  for (listwatch_T *lw = l->lv_watch; lw != NULL; lw = lw->lw_next) {
    if (lw->lw_item == item) {
      lw->lw_item = item->li_next;
    }
  }
}

//{{{2 Alloc/free

/// Allocate an empty list
///
/// Caller should take care of the reference count.
///
/// @param[in]  len  Expected number of items to be populated before list
///                  becomes accessible from Vimscript. It is still valid to
///                  underpopulate a list, value only controls how many elements
///                  will be allocated in advance. Currently does nothing.
///                  @see ListLenSpecials.
///
/// @return [allocated] new list.
list_T *tv_list_alloc(const ptrdiff_t len)
  FUNC_ATTR_NONNULL_RET
{
  list_T *const list = xcalloc(1, sizeof(list_T));

  // Prepend the list to the list of lists for garbage collection.
  if (gc_first_list != NULL) {
    gc_first_list->lv_used_prev = list;
  }
  list->lv_used_prev = NULL;
  list->lv_used_next = gc_first_list;
  gc_first_list = list;
  list->lua_table_ref = LUA_NOREF;
  return list;
}

/// Initialize a static list with 10 items
///
/// @param[out]  sl  Static list to initialize.
void tv_list_init_static10(staticList10_T *const sl)
  FUNC_ATTR_NONNULL_ALL
{
#define SL_SIZE ARRAY_SIZE(sl->sl_items)
  list_T *const l = &sl->sl_list;

  CLEAR_POINTER(sl);
  l->lv_first = &sl->sl_items[0];
  l->lv_last = &sl->sl_items[SL_SIZE - 1];
  l->lv_refcount = DO_NOT_FREE_CNT;
  tv_list_set_lock(l, VAR_FIXED);
  sl->sl_list.lv_len = 10;

  sl->sl_items[0].li_prev = NULL;
  sl->sl_items[0].li_next = &sl->sl_items[1];
  sl->sl_items[SL_SIZE - 1].li_prev = &sl->sl_items[SL_SIZE - 2];
  sl->sl_items[SL_SIZE - 1].li_next = NULL;

  for (size_t i = 1; i < SL_SIZE - 1; i++) {
    listitem_T *const li = &sl->sl_items[i];
    li->li_prev = li - 1;
    li->li_next = li + 1;
  }
#undef SL_SIZE
}

/// Initialize static list with undefined number of elements
///
/// @param[out]  l  List to initialize.
void tv_list_init_static(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  CLEAR_POINTER(l);
  l->lv_refcount = DO_NOT_FREE_CNT;
}

/// Free items contained in a list
///
/// @param[in,out]  l  List to clear.
void tv_list_free_contents(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  for (listitem_T *item = l->lv_first; item != NULL; item = l->lv_first) {
    // Remove the item before deleting it.
    l->lv_first = item->li_next;
    tv_clear(&item->li_tv);
    xfree(item);
  }
  l->lv_len = 0;
  l->lv_idx_item = NULL;
  l->lv_last = NULL;
  assert(l->lv_watch == NULL);
}

/// Free a list itself, ignoring items it contains
///
/// Ignores the reference count.
///
/// @param[in,out]  l  List to free.
void tv_list_free_list(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  // Remove the list from the list of lists for garbage collection.
  if (l->lv_used_prev == NULL) {
    gc_first_list = l->lv_used_next;
  } else {
    l->lv_used_prev->lv_used_next = l->lv_used_next;
  }
  if (l->lv_used_next != NULL) {
    l->lv_used_next->lv_used_prev = l->lv_used_prev;
  }

  NLUA_CLEAR_REF(l->lua_table_ref);
  xfree(l);
}

/// Free a list, including all items it points to
///
/// Ignores the reference count. Does not do anything if
/// tv_in_free_unref_items is true.
///
/// @param[in,out]  l  List to free.
void tv_list_free(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  if (tv_in_free_unref_items) {
    return;
  }

  tv_list_free_contents(l);
  tv_list_free_list(l);
}

/// Unreference a list
///
/// Decrements the reference count and frees when it becomes zero or less.
///
/// @param[in,out]  l  List to unreference.
void tv_list_unref(list_T *const l)
{
  if (l != NULL && --l->lv_refcount <= 0) {
    tv_list_free(l);
  }
}

//{{{2 Add/remove

/// Remove items "item" to "item2" from list "l"
///
/// @warning Does not free the listitem or the value!
///
/// @param[out]  l  List to remove from.
/// @param[in]  item  First item to remove.
/// @param[in]  item2  Last item to remove.
void tv_list_drop_items(list_T *const l, listitem_T *const item, listitem_T *const item2)
  FUNC_ATTR_NONNULL_ALL
{
  // Notify watchers.
  for (listitem_T *ip = item; ip != item2->li_next; ip = ip->li_next) {
    l->lv_len--;
    tv_list_watch_fix(l, ip);
  }

  if (item2->li_next == NULL) {
    l->lv_last = item->li_prev;
  } else {
    item2->li_next->li_prev = item->li_prev;
  }
  if (item->li_prev == NULL) {
    l->lv_first = item2->li_next;
  } else {
    item->li_prev->li_next = item2->li_next;
  }
  l->lv_idx_item = NULL;
}

/// Like tv_list_drop_items, but also frees all removed items
void tv_list_remove_items(list_T *const l, listitem_T *const item, listitem_T *const item2)
  FUNC_ATTR_NONNULL_ALL
{
  tv_list_drop_items(l, item, item2);
  for (listitem_T *li = item;;) {
    tv_clear(TV_LIST_ITEM_TV(li));
    listitem_T *const nli = li->li_next;
    xfree(li);
    if (li == item2) {
      break;
    }
    li = nli;
  }
}

/// Move items "item" to "item2" from list "l" to the end of the list "tgt_l"
///
/// @param[out]  l  List to move from.
/// @param[in]  item  First item to move.
/// @param[in]  item2  Last item to move.
/// @param[out]  tgt_l  List to move to.
/// @param[in]  cnt  Number of items moved.
void tv_list_move_items(list_T *const l, listitem_T *const item, listitem_T *const item2,
                        list_T *const tgt_l, const int cnt)
  FUNC_ATTR_NONNULL_ALL
{
  tv_list_drop_items(l, item, item2);
  item->li_prev = tgt_l->lv_last;
  item2->li_next = NULL;
  if (tgt_l->lv_last == NULL) {
    tgt_l->lv_first = item;
  } else {
    tgt_l->lv_last->li_next = item;
  }
  tgt_l->lv_last = item2;
  tgt_l->lv_len += cnt;
}

/// Insert list item
///
/// @param[out]  l  List to insert to.
/// @param[in,out]  ni  Item to insert.
/// @param[in]  item  Item to insert before. If NULL, inserts at the end of the
///                   list.
void tv_list_insert(list_T *const l, listitem_T *const ni, listitem_T *const item)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (item == NULL) {
    // Append new item at end of list.
    tv_list_append(l, ni);
  } else {
    // Insert new item before existing item.
    ni->li_prev = item->li_prev;
    ni->li_next = item;
    if (item->li_prev == NULL) {
      l->lv_first = ni;
      l->lv_idx++;
    } else {
      item->li_prev->li_next = ni;
      l->lv_idx_item = NULL;
    }
    item->li_prev = ni;
    l->lv_len++;
  }
}

/// Insert Vimscript value into a list
///
/// @param[out]  l  List to insert to.
/// @param[in,out]  tv  Value to insert. Is copied (@see tv_copy()) to an
///                     allocated listitem_T and inserted.
/// @param[in]  item  Item to insert before. If NULL, inserts at the end of the
///                   list.
void tv_list_insert_tv(list_T *const l, typval_T *const tv, listitem_T *const item)
{
  listitem_T *const ni = tv_list_item_alloc();

  tv_copy(tv, &ni->li_tv);
  tv_list_insert(l, ni, item);
}

/// Append item to the end of list
///
/// @param[out]  l  List to append to.
/// @param[in,out]  item  Item to append.
void tv_list_append(list_T *const l, listitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  if (l->lv_last == NULL) {
    // empty list
    l->lv_first = item;
    l->lv_last = item;
    item->li_prev = NULL;
  } else {
    l->lv_last->li_next = item;
    item->li_prev = l->lv_last;
    l->lv_last = item;
  }
  l->lv_len++;
  item->li_next = NULL;
}

/// Append Vimscript value to the end of list
///
/// @param[out]  l  List to append to.
/// @param[in,out]  tv  Value to append. Is copied (@see tv_copy()) to an
///                     allocated listitem_T.
void tv_list_append_tv(list_T *const l, typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T *const li = tv_list_item_alloc();
  tv_copy(tv, TV_LIST_ITEM_TV(li));
  tv_list_append(l, li);
}

/// Like tv_list_append_tv(), but tv is moved to a list
///
/// This means that it is no longer valid to use contents of the typval_T after
/// function exits.
void tv_list_append_owned_tv(list_T *const l, typval_T tv)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T *const li = tv_list_item_alloc();
  *TV_LIST_ITEM_TV(li) = tv;
  tv_list_append(l, li);
}

/// Append a list to a list as one item
///
/// @param[out]  l  List to append to.
/// @param[in,out]  itemlist  List to append. Reference count is increased.
void tv_list_append_list(list_T *const l, list_T *const itemlist)
  FUNC_ATTR_NONNULL_ARG(1)
{
  tv_list_append_owned_tv(l, (typval_T) {
    .v_type = VAR_LIST,
    .v_lock = VAR_UNLOCKED,
    .vval.v_list = itemlist,
  });
  tv_list_ref(itemlist);
}

/// Append a dictionary to a list
///
/// @param[out]  l  List to append to.
/// @param[in,out]  dict  Dictionary to append. Reference count is increased.
void tv_list_append_dict(list_T *const l, dict_T *const dict)
  FUNC_ATTR_NONNULL_ARG(1)
{
  tv_list_append_owned_tv(l, (typval_T) {
    .v_type = VAR_DICT,
    .v_lock = VAR_UNLOCKED,
    .vval.v_dict = dict,
  });
  if (dict != NULL) {
    dict->dv_refcount++;
  }
}

/// Make a copy of "str" and append it as an item to list "l"
///
/// @param[out]  l  List to append to.
/// @param[in]  str  String to append.
/// @param[in]  len  Length of the appended string. May be -1, in this
///                  case string is considered to be usual zero-terminated
///                  string or NULL “empty” string.
void tv_list_append_string(list_T *const l, const char *const str, const ssize_t len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  tv_list_append_owned_tv(l, (typval_T) {
    .v_type = VAR_STRING,
    .v_lock = VAR_UNLOCKED,
    .vval.v_string = (str == NULL
                      ? NULL
                      : (len >= 0
                         ? xmemdupz(str, (size_t)len)
                         : xstrdup(str))),
  });
}

/// Append given string to the list
///
/// Unlike list_append_string this function does not copy the string.
///
/// @param[out]  l    List to append to.
/// @param[in]   str  String to append.
void tv_list_append_allocated_string(list_T *const l, char *const str)
  FUNC_ATTR_NONNULL_ARG(1)
{
  tv_list_append_owned_tv(l, (typval_T) {
    .v_type = VAR_STRING,
    .v_lock = VAR_UNLOCKED,
    .vval.v_string = str,
  });
}

/// Append number to the list
///
/// @param[out]  l  List to append to.
/// @param[in]  n  Number to append. Will be recorded in the allocated
///                listitem_T.
void tv_list_append_number(list_T *const l, const varnumber_T n)
{
  tv_list_append_owned_tv(l, (typval_T) {
    .v_type = VAR_NUMBER,
    .v_lock = VAR_UNLOCKED,
    .vval.v_number = n,
  });
}

//{{{2 Operations on the whole list

/// Make a copy of list
///
/// @param[in]  conv  If non-NULL, then all internal strings will be converted.
///                   Only used when `deep` is true.
/// @param[in]  orig  Original list to copy.
/// @param[in]  deep  If false, then shallow copy will be done.
/// @param[in]  copyID  See var_item_copy().
///
/// @return Copied list. May be NULL in case original list is NULL or some
///         failure happens. The refcount of the new list is set to 1.
list_T *tv_list_copy(const vimconv_T *const conv, list_T *const orig, const bool deep,
                     const int copyID)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (orig == NULL) {
    return NULL;
  }

  list_T *copy = tv_list_alloc(tv_list_len(orig));
  tv_list_ref(copy);
  if (copyID != 0) {
    // Do this before adding the items, because one of the items may
    // refer back to this list.
    orig->lv_copyID = copyID;
    orig->lv_copylist = copy;
  }
  TV_LIST_ITER(orig, item, {
    if (got_int) {
      break;
    }
    listitem_T *const ni = tv_list_item_alloc();
    if (deep) {
      if (var_item_copy(conv, TV_LIST_ITEM_TV(item), TV_LIST_ITEM_TV(ni),
                        deep, copyID) == FAIL) {
        xfree(ni);
        goto tv_list_copy_error;
      }
    } else {
      tv_copy(TV_LIST_ITEM_TV(item), TV_LIST_ITEM_TV(ni));
    }
    tv_list_append(copy, ni);
  });

  return copy;

tv_list_copy_error:
  tv_list_unref(copy);
  return NULL;
}

/// Get the list item in "l" with index "n1".  "n1" is adjusted if needed.
/// Return NULL if there is no such item.
listitem_T *tv_list_check_range_index_one(list_T *const l, int *const n1, const bool quiet)
{
  listitem_T *li = tv_list_find_index(l, n1);
  if (li != NULL) {
    return li;
  }

  if (!quiet) {
    semsg(_(e_list_index_out_of_range_nr), (int64_t)(*n1));
  }
  return NULL;
}

/// Check that "n2" can be used as the second index in a range of list "l".
/// If "n1" or "n2" is negative it is changed to the positive index.
/// "li1" is the item for item "n1".
/// Return OK or FAIL.
int tv_list_check_range_index_two(list_T *const l, int *const n1, const listitem_T *const li1,
                                  int *const n2, const bool quiet)
{
  if (*n2 < 0) {
    listitem_T *ni = tv_list_find(l, *n2);
    if (ni == NULL) {
      if (!quiet) {
        semsg(_(e_list_index_out_of_range_nr), (int64_t)(*n2));
      }
      return FAIL;
    }
    *n2 = tv_list_idx_of_item(l, ni);
  }

  // Check that n2 isn't before n1.
  if (*n1 < 0) {
    *n1 = tv_list_idx_of_item(l, li1);
  }
  if (*n2 < *n1) {
    if (!quiet) {
      semsg(_(e_list_index_out_of_range_nr), (int64_t)(*n2));
    }
    return FAIL;
  }
  return OK;
}

/// Assign values from list "src" into a range of "dest".
/// "idx1_arg" is the index of the first item in "dest" to be replaced.
/// "idx2" is the index of last item to be replaced, but when "empty_idx2" is
/// true then replace all items after "idx1".
/// "op" is the operator, normally "=" but can be "+=" and the like.
/// "varname" is used for error messages.
/// Returns OK or FAIL.
int tv_list_assign_range(list_T *const dest, list_T *const src, const int idx1_arg, const int idx2,
                         const bool empty_idx2, const char *const op, const char *const varname)
{
  int idx1 = idx1_arg;
  listitem_T *const first_li = tv_list_find_index(dest, &idx1);
  listitem_T *src_li;

  // Check whether any of the list items is locked before making any changes.
  int idx = idx1;
  listitem_T *dest_li = first_li;
  for (src_li = tv_list_first(src); src_li != NULL && dest_li != NULL;) {
    if (value_check_lock(TV_LIST_ITEM_TV(dest_li)->v_lock, varname, TV_CSTRING)) {
      return FAIL;
    }
    src_li = TV_LIST_ITEM_NEXT(src, src_li);
    if (src_li == NULL || (!empty_idx2 && idx2 == idx)) {
      break;
    }
    dest_li = TV_LIST_ITEM_NEXT(dest, dest_li);
    idx++;
  }

  // Assign the List values to the list items.
  idx = idx1;
  dest_li = first_li;
  for (src_li = tv_list_first(src); src_li != NULL;) {
    assert(dest_li != NULL);
    if (op != NULL && *op != '=') {
      eexe_mod_op(TV_LIST_ITEM_TV(dest_li), TV_LIST_ITEM_TV(src_li), op);
    } else {
      tv_clear(TV_LIST_ITEM_TV(dest_li));
      tv_copy(TV_LIST_ITEM_TV(src_li), TV_LIST_ITEM_TV(dest_li));
    }
    src_li = TV_LIST_ITEM_NEXT(src, src_li);
    if (src_li == NULL || (!empty_idx2 && idx2 == idx)) {
      break;
    }
    if (TV_LIST_ITEM_NEXT(dest, dest_li) == NULL) {
      // Need to add an empty item.
      tv_list_append_number(dest, 0);
      // "dest_li" may have become invalid after append, don’t use it.
      dest_li = tv_list_last(dest);  // Valid again.
    } else {
      dest_li = TV_LIST_ITEM_NEXT(dest, dest_li);
    }
    idx++;
  }
  if (src_li != NULL) {
    emsg(_("E710: List value has more items than target"));
    return FAIL;
  }
  if (empty_idx2
      ? (dest_li != NULL && TV_LIST_ITEM_NEXT(dest, dest_li) != NULL)
      : idx != idx2) {
    emsg(_("E711: List value has not enough items"));
    return FAIL;
  }
  return OK;
}

/// Flatten up to "maxitems" in "list", starting at "first" to depth "maxdepth".
/// When "first" is NULL use the first item.
/// Does nothing if "maxdepth" is 0.
///
/// @param[in,out] list   List to flatten
/// @param[in] maxdepth   Maximum depth that will be flattened
///
/// @return OK or FAIL
void tv_list_flatten(list_T *list, listitem_T *first, int64_t maxitems, int64_t maxdepth)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T *item;
  int done = 0;
  if (maxdepth == 0) {
    return;
  }

  if (first == NULL) {
    item = list->lv_first;
  } else {
    item = first;
  }

  while (item != NULL && done < maxitems) {
    listitem_T *next = item->li_next;

    fast_breakcheck();
    if (got_int) {
      return;
    }
    if (item->li_tv.v_type == VAR_LIST) {
      list_T *itemlist = item->li_tv.vval.v_list;

      tv_list_drop_items(list, item, item);
      tv_list_extend(list, itemlist, next);

      if (maxdepth > 0) {
        tv_list_flatten(list,
                        item->li_prev == NULL ? list->lv_first : item->li_prev->li_next,
                        itemlist->lv_len, maxdepth - 1);
      }
      tv_clear(&item->li_tv);
      xfree(item);
    }

    done++;
    item = next;
  }
}

/// "items(list)" function
/// Caller must have already checked that argvars[0] is a List.
static void tv_list2items(typval_T *argvars, typval_T *rettv)
{
  list_T *l = argvars[0].vval.v_list;

  tv_list_alloc_ret(rettv, tv_list_len(l));
  if (l == NULL) {
    return;  // null list behaves like an empty list
  }

  varnumber_T idx = 0;
  TV_LIST_ITER(l, li, {
    list_T *l2 = tv_list_alloc(2);
    tv_list_append_list(rettv->vval.v_list, l2);
    tv_list_append_number(l2, idx);
    tv_list_append_tv(l2, TV_LIST_ITEM_TV(li));
    idx++;
  });
}

/// "items(string)" function
/// Caller must have already checked that argvars[0] is a String.
static void tv_string2items(typval_T *argvars, typval_T *rettv)
{
  const char *p = argvars[0].vval.v_string;

  tv_list_alloc_ret(rettv, kListLenMayKnow);
  if (p == NULL) {
    return;  // null string behaves like an empty string
  }

  for (varnumber_T idx = 0; *p != NUL; idx++) {
    int len = utfc_ptr2len(p);
    if (len == 0) {
      break;
    }
    list_T *l2 = tv_list_alloc(2);
    tv_list_append_list(rettv->vval.v_list, l2);
    tv_list_append_number(l2, idx);
    tv_list_append_string(l2, p, len);
    p += len;
  }
}

/// Extend first list with the second
///
/// @param[out]  l1  List to extend.
/// @param[in]  l2  List to extend with.
/// @param[in]  bef  If not NULL, extends before this item.
void tv_list_extend(list_T *const l1, list_T *const l2, listitem_T *const bef)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int todo = tv_list_len(l2);
  listitem_T *const befbef = (bef == NULL ? NULL : bef->li_prev);
  listitem_T *const saved_next = (befbef == NULL ? NULL : befbef->li_next);
  // We also quit the loop when we have inserted the original item count of
  // the list, avoid a hang when we extend a list with itself.
  for (listitem_T *item = tv_list_first(l2)
       ; item != NULL && todo--
       ; item = (item == befbef ? saved_next : item->li_next)) {
    tv_list_insert_tv(l1, TV_LIST_ITEM_TV(item), bef);
  }
}

/// Concatenate lists into a new list
///
/// @param[in]  l1  First list.
/// @param[in]  l2  Second list.
/// @param[out]  ret_tv  Location where new list is saved.
///
/// @return OK or FAIL.
int tv_list_concat(list_T *const l1, list_T *const l2, typval_T *const tv)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  list_T *l;

  tv->v_type = VAR_LIST;
  tv->v_lock = VAR_UNLOCKED;
  if (l1 == NULL && l2 == NULL) {
    l = NULL;
  } else if (l1 == NULL) {
    l = tv_list_copy(NULL, l2, false, 0);
  } else {
    l = tv_list_copy(NULL, l1, false, 0);
    if (l != NULL && l2 != NULL) {
      tv_list_extend(l, l2, NULL);
    }
  }
  if (l == NULL && !(l1 == NULL && l2 == NULL)) {
    return FAIL;
  }

  tv->vval.v_list = l;
  return OK;
}

static list_T *tv_list_slice(list_T *ol, varnumber_T n1, varnumber_T n2)
{
  list_T *l = tv_list_alloc(n2 - n1 + 1);
  listitem_T *item = tv_list_find(ol, (int)n1);
  for (; n1 <= n2; n1++) {
    tv_list_append_tv(l, TV_LIST_ITEM_TV(item));
    item = TV_LIST_ITEM_NEXT(rettv->vval.v_list, item);
  }
  return l;
}

int tv_list_slice_or_index(list_T *list, bool range, varnumber_T n1_arg, varnumber_T n2_arg,
                           bool exclusive, typval_T *rettv, bool verbose)
{
  int len = tv_list_len(rettv->vval.v_list);
  varnumber_T n1 = n1_arg;
  varnumber_T n2 = n2_arg;

  if (n1 < 0) {
    n1 = len + n1;
  }
  if (n1 < 0 || n1 >= len) {
    // For a range we allow invalid values and return an empty list.
    // A list index out of range is an error.
    if (!range) {
      if (verbose) {
        semsg(_(e_list_index_out_of_range_nr), (int64_t)n1_arg);
      }
      return FAIL;
    }
    n1 = len;
  }
  if (range) {
    if (n2 < 0) {
      n2 = len + n2;
    } else if (n2 >= len) {
      n2 = len - (exclusive ? 0 : 1);
    }
    if (exclusive) {
      n2--;
    }
    if (n2 < 0 || n2 + 1 < n1) {
      n2 = -1;
    }
    list_T *l = tv_list_slice(rettv->vval.v_list, n1, n2);
    tv_clear(rettv);
    tv_list_set_ret(rettv, l);
  } else {
    // copy the item to "var1" to avoid that freeing the list makes it
    // invalid.
    typval_T var1;
    tv_copy(TV_LIST_ITEM_TV(tv_list_find(rettv->vval.v_list, (int)n1)), &var1);
    tv_clear(rettv);
    *rettv = var1;
  }
  return OK;
}

typedef struct {
  char *s;
  char *tofree;
} Join;

/// Join list into a string, helper function
///
/// @param[out]  gap  Garray where result will be saved.
/// @param[in]  l  List to join.
/// @param[in]  sep  Used separator.
/// @param[in]  join_gap  Garray to keep each list item string.
///
/// @return OK in case of success, FAIL otherwise.
static int list_join_inner(garray_T *const gap, list_T *const l, const char *const sep,
                           garray_T *const join_gap)
  FUNC_ATTR_NONNULL_ALL
{
  size_t sumlen = 0;
  bool first = true;

  // Stringify each item in the list.
  TV_LIST_ITER(l, item, {
    if (got_int) {
      break;
    }
    char *s;
    size_t len;
    s = encode_tv2echo(TV_LIST_ITEM_TV(item), &len);
    if (s == NULL) {
      return FAIL;
    }

    sumlen += len;

    Join *const p = GA_APPEND_VIA_PTR(Join, join_gap);
    p->tofree = p->s = s;

    line_breakcheck();
  });

  // Allocate result buffer with its total size, avoid re-allocation and
  // multiple copy operations.  Add 2 for a tailing ']' and NUL.
  if (join_gap->ga_len >= 2) {
    sumlen += strlen(sep) * (size_t)(join_gap->ga_len - 1);
  }
  ga_grow(gap, (int)sumlen + 2);

  for (int i = 0; i < join_gap->ga_len && !got_int; i++) {
    if (first) {
      first = false;
    } else {
      ga_concat(gap, sep);
    }
    const Join *const p = ((const Join *)join_gap->ga_data) + i;

    if (p->s != NULL) {
      ga_concat(gap, p->s);
    }
    line_breakcheck();
  }

  return OK;
}

/// Join list into a string using given separator
///
/// @param[out]  gap  Garray where result will be saved.
/// @param[in]  l  Joined list.
/// @param[in]  sep  Separator.
///
/// @return OK in case of success, FAIL otherwise.
int tv_list_join(garray_T *const gap, list_T *const l, const char *const sep)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!tv_list_len(l)) {
    return OK;
  }

  garray_T join_ga;
  int retval;

  ga_init(&join_ga, (int)sizeof(Join), tv_list_len(l));
  retval = list_join_inner(gap, l, sep, &join_ga);

#define FREE_JOIN_TOFREE(join) xfree((join)->tofree)
  GA_DEEP_CLEAR(&join_ga, Join, FREE_JOIN_TOFREE);
#undef FREE_JOIN_TOFREE

  return retval;
}

/// "join()" function
void f_join(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }
  const char *const sep = (argvars[1].v_type == VAR_UNKNOWN
                           ? " "
                           : tv_get_string_chk(&argvars[1]));

  rettv->v_type = VAR_STRING;

  if (sep != NULL) {
    garray_T ga;
    ga_init(&ga, (int)sizeof(char), 80);
    tv_list_join(&ga, argvars[0].vval.v_list, sep);
    ga_append(&ga, NUL);
    rettv->vval.v_string = ga.ga_data;
  } else {
    rettv->vval.v_string = NULL;
  }
}

/// "list2str()" function
void f_list2str(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  garray_T ga;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_invarg));
    return;
  }

  list_T *const l = argvars[0].vval.v_list;
  if (l == NULL) {
    return;  // empty list results in empty string
  }

  ga_init(&ga, 1, 80);
  char buf[MB_MAXBYTES + 1];

  TV_LIST_ITER_CONST(l, li, {
    buf[utf_char2bytes((int)tv_get_number(TV_LIST_ITEM_TV(li)), buf)] = NUL;
    ga_concat(&ga, buf);
  });
  ga_append(&ga, NUL);

  rettv->vval.v_string = ga.ga_data;
}

/// "remove({list})" function
void tv_list_remove(typval_T *argvars, typval_T *rettv, const char *arg_errmsg)
{
  list_T *l;
  bool error = false;

  if (value_check_lock(tv_list_locked((l = argvars[0].vval.v_list)),
                       arg_errmsg, TV_TRANSLATE)) {
    return;
  }

  int64_t idx = tv_get_number_chk(&argvars[1], &error);

  listitem_T *item;

  if (error) {
    // Type error: do nothing, errmsg already given.
  } else if ((item = tv_list_find(l, (int)idx)) == NULL) {
    semsg(_(e_list_index_out_of_range_nr), idx);
  } else {
    if (argvars[2].v_type == VAR_UNKNOWN) {
      // Remove one item, return its value.
      tv_list_drop_items(l, item, item);
      *rettv = *TV_LIST_ITEM_TV(item);
      xfree(item);
    } else {
      listitem_T *item2;
      // Remove range of items, return list with values.
      int64_t end = tv_get_number_chk(&argvars[2], &error);
      if (error) {
        // Type error: do nothing.
      } else if ((item2 = tv_list_find(l, (int)end)) == NULL) {
        semsg(_(e_list_index_out_of_range_nr), end);
      } else {
        int cnt = 0;

        listitem_T *li;
        for (li = item; li != NULL; li = TV_LIST_ITEM_NEXT(l, li)) {
          cnt++;
          if (li == item2) {
            break;
          }
        }
        if (li == NULL) {  // Didn't find "item2" after "item".
          emsg(_(e_invrange));
        } else {
          tv_list_move_items(l, item, item2, tv_list_alloc_ret(rettv, cnt),
                             cnt);
        }
      }
    }
  }
}

static sortinfo_T *sortinfo = NULL;

#define ITEM_COMPARE_FAIL 999

/// Compare functions for f_sort() and f_uniq() below.
static int item_compare(const void *s1, const void *s2, bool keep_zero)
{
  ListSortItem *const si1 = (ListSortItem *)s1;
  ListSortItem *const si2 = (ListSortItem *)s2;

  typval_T *const tv1 = TV_LIST_ITEM_TV(si1->item);
  typval_T *const tv2 = TV_LIST_ITEM_TV(si2->item);

  int res;

  if (sortinfo->item_compare_numbers) {
    const varnumber_T v1 = tv_get_number(tv1);
    const varnumber_T v2 = tv_get_number(tv2);

    res = v1 == v2 ? 0 : v1 > v2 ? 1 : -1;
    goto item_compare_end;
  }

  if (sortinfo->item_compare_float) {
    const float_T v1 = tv_get_float(tv1);
    const float_T v2 = tv_get_float(tv2);

    res = v1 == v2 ? 0 : v1 > v2 ? 1 : -1;
    goto item_compare_end;
  }

  char *tofree1 = NULL;
  char *tofree2 = NULL;
  char *p1;
  char *p2;

  // encode_tv2string() puts quotes around a string and allocates memory.  Don't
  // do that for string variables. Use a single quote when comparing with
  // a non-string to do what the docs promise.
  if (tv1->v_type == VAR_STRING) {
    if (tv2->v_type != VAR_STRING || sortinfo->item_compare_numeric) {
      p1 = "'";
    } else {
      p1 = tv1->vval.v_string;
    }
  } else {
    tofree1 = p1 = encode_tv2string(tv1, NULL);
  }
  if (tv2->v_type == VAR_STRING) {
    if (tv1->v_type != VAR_STRING || sortinfo->item_compare_numeric) {
      p2 = "'";
    } else {
      p2 = tv2->vval.v_string;
    }
  } else {
    tofree2 = p2 = encode_tv2string(tv2, NULL);
  }
  if (p1 == NULL) {
    p1 = "";
  }
  if (p2 == NULL) {
    p2 = "";
  }
  if (!sortinfo->item_compare_numeric) {
    if (sortinfo->item_compare_lc) {
      res = strcoll(p1, p2);
    } else {
      res = sortinfo->item_compare_ic ? STRICMP(p1, p2) : strcmp(p1, p2);
    }
  } else {
    double n1 = strtod(p1, &p1);
    double n2 = strtod(p2, &p2);
    res = n1 == n2 ? 0 : n1 > n2 ? 1 : -1;
  }

  xfree(tofree1);
  xfree(tofree2);

item_compare_end:
  // When the result would be zero, compare the item indexes.  Makes the
  // sort stable.
  if (res == 0 && !keep_zero) {
    // WARNING: When using uniq si1 and si2 are actually listitem_T **, no
    // indexes are there.
    res = si1->idx > si2->idx ? 1 : -1;
  }
  return res;
}

static int item_compare_keeping_zero(const void *s1, const void *s2)
{
  return item_compare(s1, s2, true);
}

static int item_compare_not_keeping_zero(const void *s1, const void *s2)
{
  return item_compare(s1, s2, false);
}

static int item_compare2(const void *s1, const void *s2, bool keep_zero)
{
  typval_T rettv;
  typval_T argv[3];
  const char *func_name;
  partial_T *partial = sortinfo->item_compare_partial;

  // shortcut after failure in previous call; compare all items equal
  if (sortinfo->item_compare_func_err) {
    return 0;
  }

  ListSortItem *si1 = (ListSortItem *)s1;
  ListSortItem *si2 = (ListSortItem *)s2;

  if (partial == NULL) {
    func_name = sortinfo->item_compare_func;
  } else {
    func_name = partial_name(partial);
  }

  // Copy the values.  This is needed to be able to set v_lock to VAR_FIXED
  // in the copy without changing the original list items.
  tv_copy(TV_LIST_ITEM_TV(si1->item), &argv[0]);
  tv_copy(TV_LIST_ITEM_TV(si2->item), &argv[1]);

  rettv.v_type = VAR_UNKNOWN;  // tv_clear() uses this
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_evaluate = true;
  funcexe.fe_partial = partial;
  funcexe.fe_selfdict = sortinfo->item_compare_selfdict;
  int res = call_func(func_name, -1, &rettv, 2, argv, &funcexe);
  tv_clear(&argv[0]);
  tv_clear(&argv[1]);

  if (res == FAIL) {
    // XXX: ITEM_COMPARE_FAIL is unused
    res = ITEM_COMPARE_FAIL;
    sortinfo->item_compare_func_err = true;
  } else {
    res = (int)tv_get_number_chk(&rettv, &sortinfo->item_compare_func_err);
    if (res > 0) {
      res = 1;
    } else if (res < 0) {
      res = -1;
    }
  }
  if (sortinfo->item_compare_func_err) {
    res = ITEM_COMPARE_FAIL;  // return value has wrong type
  }
  tv_clear(&rettv);

  // When the result would be zero, compare the pointers themselves.  Makes
  // the sort stable.
  if (res == 0 && !keep_zero) {
    // WARNING: When using uniq si1 and si2 are actually listitem_T **, no
    // indexes are there.
    res = si1->idx > si2->idx ? 1 : -1;
  }

  return res;
}

static int item_compare2_keeping_zero(const void *s1, const void *s2)
{
  return item_compare2(s1, s2, true);
}

static int item_compare2_not_keeping_zero(const void *s1, const void *s2)
{
  return item_compare2(s1, s2, false);
}

/// sort() List "l"
static void do_sort(list_T *l, sortinfo_T *info)
{
  const int len = tv_list_len(l);

  // Make an array with each entry pointing to an item in the List.
  ListSortItem *ptrs = xmalloc((size_t)((unsigned)len * sizeof(ListSortItem)));

  // f_sort(): ptrs will be the list to sort
  int i = 0;
  TV_LIST_ITER(l, li, {
    ptrs[i].item = li;
    ptrs[i].idx = i;
    i++;
  });

  info->item_compare_func_err = false;
  ListSorter item_compare_func = ((info->item_compare_func == NULL
                                   && info->item_compare_partial == NULL)
                                  ? item_compare_not_keeping_zero
                                  : item_compare2_not_keeping_zero);

  // Sort the array with item pointers.
  qsort(ptrs, (size_t)len, sizeof(ListSortItem), item_compare_func);
  if (!info->item_compare_func_err) {
    // Clear the list and append the items in the sorted order.
    l->lv_first = NULL;
    l->lv_last = NULL;
    l->lv_idx_item = NULL;
    l->lv_len = 0;
    for (i = 0; i < len; i++) {
      tv_list_append(l, ptrs[i].item);
    }
  }
  if (info->item_compare_func_err) {
    emsg(_("E702: Sort compare function failed"));
  }

  xfree(ptrs);
}

/// uniq() List "l"
static void do_uniq(list_T *l, sortinfo_T *info)
{
  const int len = tv_list_len(l);

  // Make an array with each entry pointing to an item in the List.
  ListSortItem *ptrs = xmalloc((size_t)((unsigned)len * sizeof(ListSortItem)));

  // f_uniq(): ptrs will be a stack of items to remove.

  info->item_compare_func_err = false;
  ListSorter item_compare_func = ((info->item_compare_func == NULL
                                   && info->item_compare_partial == NULL)
                                  ? item_compare_keeping_zero
                                  : item_compare2_keeping_zero);

  for (listitem_T *li = TV_LIST_ITEM_NEXT(l, tv_list_first(l)); li != NULL;) {
    listitem_T *const prev_li = TV_LIST_ITEM_PREV(l, li);
    if (item_compare_func(&prev_li, &li) == 0) {
      li = tv_list_item_remove(l, li);
    } else {
      li = TV_LIST_ITEM_NEXT(l, li);
    }
    if (info->item_compare_func_err) {
      emsg(_("E882: Uniq compare function failed"));
      break;
    }
  }

  xfree(ptrs);
}

/// Parse the optional arguments to sort() and uniq() and return the values in "info".
static int parse_sort_uniq_args(typval_T *argvars, sortinfo_T *info)
{
  info->item_compare_ic = false;
  info->item_compare_lc = false;
  info->item_compare_numeric = false;
  info->item_compare_numbers = false;
  info->item_compare_float = false;
  info->item_compare_func = NULL;
  info->item_compare_partial = NULL;
  info->item_compare_selfdict = NULL;

  if (argvars[1].v_type == VAR_UNKNOWN) {
    return OK;
  }

  // optional second argument: {func}
  if (argvars[1].v_type == VAR_FUNC) {
    info->item_compare_func = argvars[1].vval.v_string;
  } else if (argvars[1].v_type == VAR_PARTIAL) {
    info->item_compare_partial = argvars[1].vval.v_partial;
  } else {
    bool error = false;
    int nr = (int)tv_get_number_chk(&argvars[1], &error);
    if (error) {
      return FAIL;  // type error; errmsg already given
    }
    if (nr == 1) {
      info->item_compare_ic = true;
    } else if (argvars[1].v_type != VAR_NUMBER) {
      info->item_compare_func = tv_get_string(&argvars[1]);
    } else if (nr != 0) {
      emsg(_(e_invarg));
      return FAIL;
    }
    if (info->item_compare_func != NULL) {
      if (*info->item_compare_func == NUL) {
        // empty string means default sort
        info->item_compare_func = NULL;
      } else if (strcmp(info->item_compare_func, "n") == 0) {
        info->item_compare_func = NULL;
        info->item_compare_numeric = true;
      } else if (strcmp(info->item_compare_func, "N") == 0) {
        info->item_compare_func = NULL;
        info->item_compare_numbers = true;
      } else if (strcmp(info->item_compare_func, "f") == 0) {
        info->item_compare_func = NULL;
        info->item_compare_float = true;
      } else if (strcmp(info->item_compare_func, "i") == 0) {
        info->item_compare_func = NULL;
        info->item_compare_ic = true;
      } else if (strcmp(info->item_compare_func, "l") == 0) {
        info->item_compare_func = NULL;
        info->item_compare_lc = true;
      }
    }
  }

  if (argvars[2].v_type != VAR_UNKNOWN) {
    // optional third argument: {dict}
    if (tv_check_for_dict_arg(argvars, 2) == FAIL) {
      return FAIL;
    }
    info->item_compare_selfdict = argvars[2].vval.v_dict;
  }

  return OK;
}

/// "sort()" or "uniq()" function
static void do_sort_uniq(typval_T *argvars, typval_T *rettv, bool sort)
{
  if (argvars[0].v_type != VAR_LIST) {
    semsg(_(e_listarg), sort ? "sort()" : "uniq()");
    return;
  }

  // Pointer to current info struct used in compare function. Save and restore
  // the current one for nested calls.
  sortinfo_T info;
  sortinfo_T *old_sortinfo = sortinfo;
  sortinfo = &info;

  const char *const arg_errmsg = (sort ? N_("sort() argument") : N_("uniq() argument"));
  list_T *const l = argvars[0].vval.v_list;
  if (value_check_lock(tv_list_locked(l), arg_errmsg, TV_TRANSLATE)) {
    goto theend;
  }
  tv_list_set_ret(rettv, l);

  const int len = tv_list_len(l);
  if (len <= 1) {
    goto theend;  // short list sorts pretty quickly
  }
  if (parse_sort_uniq_args(argvars, &info) == FAIL) {
    goto theend;
  }

  if (sort) {
    do_sort(l, &info);
  } else {
    do_uniq(l, &info);
  }

theend:
  sortinfo = old_sortinfo;
}

/// "sort({list})" function
void f_sort(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_sort_uniq(argvars, rettv, true);
}

/// "uniq({list})" function
void f_uniq(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_sort_uniq(argvars, rettv, false);
}

/// Check whether two lists are equal
///
/// @param[in]  l1  First list to compare.
/// @param[in]  l2  Second list to compare.
/// @param[in]  ic  True if case is to be ignored.
///
/// @return True if lists are equal, false otherwise.
bool tv_list_equal(list_T *const l1, list_T *const l2, const bool ic)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (l1 == l2) {
    return true;
  }
  if (tv_list_len(l1) != tv_list_len(l2)) {
    return false;
  }
  if (tv_list_len(l1) == 0) {
    // empty and NULL list are considered equal
    return true;
  }
  if (l1 == NULL || l2 == NULL) {
    return false;
  }

  listitem_T *item1 = tv_list_first(l1);
  listitem_T *item2 = tv_list_first(l2);
  for (; item1 != NULL && item2 != NULL
       ; (item1 = TV_LIST_ITEM_NEXT(l1, item1),
          item2 = TV_LIST_ITEM_NEXT(l2, item2))) {
    if (!tv_equal(TV_LIST_ITEM_TV(item1), TV_LIST_ITEM_TV(item2), ic)) {
      return false;
    }
  }
  assert(item1 == NULL && item2 == NULL);
  return true;
}

/// Reverse list in-place
///
/// @param[in,out]  l  List to reverse.
void tv_list_reverse(list_T *const l)
{
  if (tv_list_len(l) <= 1) {
    return;
  }
#define SWAP(a, b) \
  do { \
    tmp = (a); \
    (a) = (b); \
    (b) = tmp; \
  } while (0)
  listitem_T *tmp;

  SWAP(l->lv_first, l->lv_last);
  for (listitem_T *li = l->lv_first; li != NULL; li = li->li_next) {
    SWAP(li->li_next, li->li_prev);
  }
#undef SWAP

  l->lv_idx = l->lv_len - l->lv_idx - 1;
}

//{{{2 Indexing/searching

/// Locate item with a given index in a list and return it
///
/// @param[in]  l  List to index.
/// @param[in]  n  Index. Negative index is counted from the end, -1 is the last
///                item.
///
/// @return Item at the given index or NULL if `n` is out of range.
listitem_T *tv_list_find(list_T *const l, int n)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  STATIC_ASSERT(sizeof(n) == sizeof(l->lv_idx),
                "n and lv_idx sizes do not match");
  if (l == NULL) {
    return NULL;
  }

  n = tv_list_uidx(l, n);
  if (n == -1) {
    return NULL;
  }

  int idx;
  listitem_T *item;

  // When there is a cached index may start search from there.
  if (l->lv_idx_item != NULL) {
    if (n < l->lv_idx / 2) {
      // Closest to the start of the list.
      item = l->lv_first;
      idx = 0;
    } else if (n > (l->lv_idx + l->lv_len) / 2) {
      // Closest to the end of the list.
      item = l->lv_last;
      idx = l->lv_len - 1;
    } else {
      // Closest to the cached index.
      item = l->lv_idx_item;
      idx = l->lv_idx;
    }
  } else {
    if (n < l->lv_len / 2) {
      // Closest to the start of the list.
      item = l->lv_first;
      idx = 0;
    } else {
      // Closest to the end of the list.
      item = l->lv_last;
      idx = l->lv_len - 1;
    }
  }

  while (n > idx) {
    // Search forward.
    item = item->li_next;
    idx++;
  }
  while (n < idx) {
    // Search backward.
    item = item->li_prev;
    idx--;
  }

  assert(idx == n);
  // Cache the used index.
  l->lv_idx = idx;
  l->lv_idx_item = item;

  return item;
}

/// Get list item l[n] as a number
///
/// @param[in]  l  List to index.
/// @param[in]  n  Index in a list.
/// @param[out]  ret_error  Location where 1 will be saved if index was not
///                         found. May be NULL. If everything is OK,
///                         `*ret_error` is not touched.
///
/// @return Integer value at the given index or -1.
varnumber_T tv_list_find_nr(list_T *const l, const int n, bool *const ret_error)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const listitem_T *const li = tv_list_find(l, n);
  if (li == NULL) {
    if (ret_error != NULL) {
      *ret_error = true;
    }
    return -1;
  }
  return tv_get_number_chk(TV_LIST_ITEM_TV(li), ret_error);
}

/// Get list item l[n] as a string
///
/// @param[in]  l  List to index.
/// @param[in]  n  Index in a list.
///
/// @return List item string value or NULL in case of error.
const char *tv_list_find_str(list_T *const l, const int n)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const listitem_T *const li = tv_list_find(l, n);
  if (li == NULL) {
    semsg(_(e_list_index_out_of_range_nr), (int64_t)n);
    return NULL;
  }
  return tv_get_string(TV_LIST_ITEM_TV(li));
}

/// Like tv_list_find() but when a negative index is used that is not found use
/// zero and set "idx" to zero.  Used for first index of a range.
static listitem_T *tv_list_find_index(list_T *const l, int *const idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  listitem_T *li = tv_list_find(l, *idx);
  if (li != NULL) {
    return li;
  }

  if (*idx < 0) {
    *idx = 0;
    li = tv_list_find(l, *idx);
  }
  return li;
}

/// Locate item in a list and return its index
///
/// @param[in]  l  List to search.
/// @param[in]  item  Item to search for.
///
/// @return Index of an item or -1 if item is not in the list.
int tv_list_idx_of_item(const list_T *const l, const listitem_T *const item)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (l == NULL) {
    return -1;
  }
  int idx = 0;
  TV_LIST_ITER_CONST(l, li, {
    if (li == item) {
      return idx;
    }
    idx++;
  });
  return -1;
}

//{{{1 Dictionaries
//{{{2 Dictionary watchers

/// Perform all necessary cleanup for a `DictWatcher` instance
///
/// @param  watcher  Watcher to free.
static void tv_dict_watcher_free(DictWatcher *watcher)
  FUNC_ATTR_NONNULL_ALL
{
  callback_free(&watcher->callback);
  xfree(watcher->key_pattern);
  xfree(watcher);
}

/// Add watcher to a dictionary
///
/// @param[in]  dict  Dictionary to add watcher to.
/// @param[in]  key_pattern  Pattern to watch for.
/// @param[in]  key_pattern_len  Key pattern length.
/// @param  callback  Function to be called on events.
void tv_dict_watcher_add(dict_T *const dict, const char *const key_pattern,
                         const size_t key_pattern_len, Callback callback)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (dict == NULL) {
    return;
  }
  DictWatcher *const watcher = xmalloc(sizeof(DictWatcher));
  watcher->key_pattern = xmemdupz(key_pattern, key_pattern_len);
  watcher->key_pattern_len = key_pattern_len;
  watcher->callback = callback;
  watcher->busy = false;
  watcher->needs_free = false;
  QUEUE_INSERT_TAIL(&dict->watchers, &watcher->node);
}

/// Check whether two callbacks are equal
///
/// @param[in]  cb1  First callback to check.
/// @param[in]  cb2  Second callback to check.
///
/// @return True if they are equal, false otherwise.
bool tv_callback_equal(const Callback *cb1, const Callback *cb2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (cb1->type != cb2->type) {
    return false;
  }
  switch (cb1->type) {
  case kCallbackFuncref:
    return strcmp(cb1->data.funcref, cb2->data.funcref) == 0;
  case kCallbackPartial:
    // FIXME: this is inconsistent with tv_equal but is needed for precision
    // maybe change dictwatcheradd to return a watcher id instead?
    return cb1->data.partial == cb2->data.partial;
  case kCallbackLua:
    return cb1->data.luaref == cb2->data.luaref;
  case kCallbackNone:
    return true;
  }
  abort();
  return false;
}

/// Unref/free callback
void callback_free(Callback *callback)
  FUNC_ATTR_NONNULL_ALL
{
  switch (callback->type) {
  case kCallbackFuncref:
    func_unref(callback->data.funcref);
    xfree(callback->data.funcref);
    break;
  case kCallbackPartial:
    partial_unref(callback->data.partial);
    break;
  case kCallbackLua:
    NLUA_CLEAR_REF(callback->data.luaref);
    break;
  case kCallbackNone:
    break;
  }
  callback->type = kCallbackNone;
  callback->data.funcref = NULL;
}

/// Copy a callback into a typval_T.
void callback_put(Callback *cb, typval_T *tv)
  FUNC_ATTR_NONNULL_ALL
{
  switch (cb->type) {
  case kCallbackPartial:
    tv->v_type = VAR_PARTIAL;
    tv->vval.v_partial = cb->data.partial;
    cb->data.partial->pt_refcount++;
    break;
  case kCallbackFuncref:
    tv->v_type = VAR_FUNC;
    tv->vval.v_string = xstrdup(cb->data.funcref);
    func_ref(cb->data.funcref);
    break;
  case kCallbackLua:
  // TODO(tjdevries): Unified Callback.
  // At this point this isn't possible, but it'd be nice to put
  // these handled more neatly in one place.
  // So instead, we just do the default and put nil
  default:
    tv->v_type = VAR_SPECIAL;
    tv->vval.v_special = kSpecialVarNull;
    break;
  }
}

// Copy callback from "src" to "dest", incrementing the refcounts.
void callback_copy(Callback *dest, Callback *src)
  FUNC_ATTR_NONNULL_ALL
{
  dest->type = src->type;
  switch (src->type) {
  case kCallbackPartial:
    dest->data.partial = src->data.partial;
    dest->data.partial->pt_refcount++;
    break;
  case kCallbackFuncref:
    dest->data.funcref = xstrdup(src->data.funcref);
    func_ref(src->data.funcref);
    break;
  case kCallbackLua:
    dest->data.luaref = api_new_luaref(src->data.luaref);
    break;
  default:
    dest->data.funcref = NULL;
    break;
  }
}

/// Generate a string description of a callback
char *callback_to_string(Callback *cb, Arena *arena)
{
  if (cb->type == kCallbackLua) {
    return nlua_funcref_str(cb->data.luaref, arena);
  }

  const size_t msglen = 100;
  char *msg = xmallocz(msglen);

  switch (cb->type) {
  case kCallbackFuncref:
    // TODO(tjdevries): Is this enough space for this?
    snprintf(msg, msglen, "<vim function: %s>", cb->data.funcref);
    break;
  case kCallbackPartial:
    snprintf(msg, msglen, "<vim partial: %s>", cb->data.partial->pt_name);
    break;
  default:
    *msg = NUL;
    break;
  }
  return msg;
}

/// Remove watcher from a dictionary
///
/// @param  dict  Dictionary to remove watcher from.
/// @param[in]  key_pattern  Pattern to remove watcher for.
/// @param[in]  key_pattern_len  Pattern length.
/// @param  callback  Callback to remove watcher for.
///
/// @return True on success, false if relevant watcher was not found.
bool tv_dict_watcher_remove(dict_T *const dict, const char *const key_pattern,
                            const size_t key_pattern_len, Callback callback)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (dict == NULL) {
    return false;
  }

  QUEUE *w = NULL;
  DictWatcher *watcher = NULL;
  bool matched = false;
  bool queue_is_busy = false;
  QUEUE_FOREACH(w, &dict->watchers, {
    watcher = tv_dict_watcher_node_data(w);
    if (watcher->busy) {
      queue_is_busy = true;
    }
    if (tv_callback_equal(&watcher->callback, &callback)
        && watcher->key_pattern_len == key_pattern_len
        && memcmp(watcher->key_pattern, key_pattern, key_pattern_len) == 0) {
      matched = true;
      break;
    }
  })

  if (!matched) {
    return false;
  }

  if (queue_is_busy) {
    watcher->needs_free = true;
  } else {
    QUEUE_REMOVE(w);
    tv_dict_watcher_free(watcher);
  }
  return true;
}

/// Test if `key` matches with with `watcher->key_pattern`
///
/// @param[in]  watcher  Watcher to check key pattern from.
/// @param[in]  key  Key to check.
///
/// @return true if key matches, false otherwise.
static bool tv_dict_watcher_matches(DictWatcher *watcher, const char *const key)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  // For now only allow very simple globbing in key patterns: a '*' at the end
  // of the string means it should match everything up to the '*' instead of the
  // whole string.
  const size_t len = watcher->key_pattern_len;
  if (len && watcher->key_pattern[len - 1] == '*') {
    return strncmp(key, watcher->key_pattern, len - 1) == 0;
  }
  return strcmp(key, watcher->key_pattern) == 0;
}

/// Send a change notification to all dictionary watchers that match given key
///
/// @param[in]  dict  Dictionary which was modified.
/// @param[in]  key  Key which was modified.
/// @param[in]  newtv  New key value.
/// @param[in]  oldtv  Old key value.
void tv_dict_watcher_notify(dict_T *const dict, const char *const key, typval_T *const newtv,
                            typval_T *const oldtv)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  typval_T argv[3];

  argv[0].v_type = VAR_DICT;
  argv[0].v_lock = VAR_UNLOCKED;
  argv[0].vval.v_dict = dict;
  argv[1].v_type = VAR_STRING;
  argv[1].v_lock = VAR_UNLOCKED;
  argv[1].vval.v_string = xstrdup(key);
  argv[2].v_type = VAR_DICT;
  argv[2].v_lock = VAR_UNLOCKED;
  argv[2].vval.v_dict = tv_dict_alloc();
  argv[2].vval.v_dict->dv_refcount++;

  if (newtv) {
    dictitem_T *const v = tv_dict_item_alloc_len(S_LEN("new"));
    tv_copy(newtv, &v->di_tv);
    tv_dict_add(argv[2].vval.v_dict, v);
  }

  if (oldtv && oldtv->v_type != VAR_UNKNOWN) {
    dictitem_T *const v = tv_dict_item_alloc_len(S_LEN("old"));
    tv_copy(oldtv, &v->di_tv);
    tv_dict_add(argv[2].vval.v_dict, v);
  }

  typval_T rettv;

  bool any_needs_free = false;
  dict->dv_refcount++;
  QUEUE *w;
  QUEUE_FOREACH(w, &dict->watchers, {
    DictWatcher *watcher = tv_dict_watcher_node_data(w);
    if (!watcher->busy && tv_dict_watcher_matches(watcher, key)) {
      rettv = TV_INITIAL_VALUE;
      watcher->busy = true;
      callback_call(&watcher->callback, 3, argv, &rettv);
      watcher->busy = false;
      tv_clear(&rettv);
      if (watcher->needs_free) {
        any_needs_free = true;
      }
    }
  })
  if (any_needs_free) {
    QUEUE_FOREACH(w, &dict->watchers, {
      DictWatcher *watcher = tv_dict_watcher_node_data(w);
      if (watcher->needs_free) {
        QUEUE_REMOVE(w);
        tv_dict_watcher_free(watcher);
      }
    })
  }
  tv_dict_unref(dict);

  for (size_t i = 1; i < ARRAY_SIZE(argv); i++) {
    tv_clear(argv + i);
  }
}

//{{{2 Dictionary item

/// Allocate a dictionary item
///
/// @note that the type and value of the item (->di_tv) still needs to
///       be initialized.
///
/// @param[in]  key  Key, is copied to the new item.
/// @param[in]  key_len  Key length.
///
/// @return [allocated] new dictionary item.
dictitem_T *tv_dict_item_alloc_len(const char *const key, const size_t key_len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_MALLOC
{
  dictitem_T *const di = xmalloc(offsetof(dictitem_T, di_key) + key_len + 1);
  memcpy(di->di_key, key, key_len);
  di->di_key[key_len] = NUL;
  di->di_flags = DI_FLAGS_ALLOC;
  di->di_tv.v_lock = VAR_UNLOCKED;
  di->di_tv.v_type = VAR_UNKNOWN;
  return di;
}

/// Allocate a dictionary item
///
/// @note that the type and value of the item (->di_tv) still needs to
///       be initialized.
///
/// @param[in]  key  Key, is copied to the new item.
///
/// @return [allocated] new dictionary item.
dictitem_T *tv_dict_item_alloc(const char *const key)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_MALLOC
{
  return tv_dict_item_alloc_len(key, strlen(key));
}

/// Free a dictionary item, also clearing the value
///
/// @param  item  Item to free.
void tv_dict_item_free(dictitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  tv_clear(&item->di_tv);
  if (item->di_flags & DI_FLAGS_ALLOC) {
    xfree(item);
  }
}

/// Make a copy of a dictionary item
///
/// @param[in]  di  Item to copy.
///
/// @return [allocated] new dictionary item.
dictitem_T *tv_dict_item_copy(dictitem_T *const di)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  dictitem_T *const new_di = tv_dict_item_alloc(di->di_key);
  tv_copy(&di->di_tv, &new_di->di_tv);
  return new_di;
}

/// Remove item from dictionary and free it
///
/// @param  dict  Dictionary to remove item from.
/// @param  item  Item to remove.
void tv_dict_item_remove(dict_T *const dict, dictitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  hashitem_T *const hi = hash_find(&dict->dv_hashtab, item->di_key);
  if (HASHITEM_EMPTY(hi)) {
    semsg(_(e_intern2), "tv_dict_item_remove()");
  } else {
    hash_remove(&dict->dv_hashtab, hi);
  }
  tv_dict_item_free(item);
}

//{{{2 Alloc/free

/// Allocate an empty dictionary.
/// Caller should take care of the reference count.
///
/// @return [allocated] new dictionary.
dict_T *tv_dict_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  dict_T *const d = xcalloc(1, sizeof(dict_T));

  // Add the dict to the list of dicts for garbage collection.
  if (gc_first_dict != NULL) {
    gc_first_dict->dv_used_prev = d;
  }
  d->dv_used_next = gc_first_dict;
  d->dv_used_prev = NULL;
  gc_first_dict = d;

  hash_init(&d->dv_hashtab);
  d->dv_lock = VAR_UNLOCKED;
  d->dv_scope = VAR_NO_SCOPE;
  d->dv_refcount = 0;
  d->dv_copyID = 0;
  QUEUE_INIT(&d->watchers);

  d->lua_table_ref = LUA_NOREF;

  return d;
}

/// Free items contained in a dictionary
///
/// @param[in,out]  d  Dictionary to clear.
void tv_dict_free_contents(dict_T *const d)
  FUNC_ATTR_NONNULL_ALL
{
  // Lock the hashtab, we don't want it to resize while freeing items.
  hash_lock(&d->dv_hashtab);
  assert(d->dv_hashtab.ht_locked > 0);
  HASHTAB_ITER(&d->dv_hashtab, hi, {
    // Remove the item before deleting it, just in case there is
    // something recursive causing trouble.
    dictitem_T *const di = TV_DICT_HI2DI(hi);
    hash_remove(&d->dv_hashtab, hi);
    tv_dict_item_free(di);
  });

  while (!QUEUE_EMPTY(&d->watchers)) {
    QUEUE *w = QUEUE_HEAD(&d->watchers);
    QUEUE_REMOVE(w);
    DictWatcher *watcher = tv_dict_watcher_node_data(w);
    tv_dict_watcher_free(watcher);
  }

  hash_clear(&d->dv_hashtab);
  d->dv_hashtab.ht_locked--;
  hash_init(&d->dv_hashtab);
}

/// Free a dictionary itself, ignoring items it contains
///
/// Ignores the reference count.
///
/// @param[in,out]  d  Dictionary to free.
void tv_dict_free_dict(dict_T *const d)
  FUNC_ATTR_NONNULL_ALL
{
  // Remove the dict from the list of dicts for garbage collection.
  if (d->dv_used_prev == NULL) {
    gc_first_dict = d->dv_used_next;
  } else {
    d->dv_used_prev->dv_used_next = d->dv_used_next;
  }
  if (d->dv_used_next != NULL) {
    d->dv_used_next->dv_used_prev = d->dv_used_prev;
  }

  NLUA_CLEAR_REF(d->lua_table_ref);
  xfree(d);
}

/// Free a dictionary, including all items it contains
///
/// Ignores the reference count.
///
/// @param  d  Dictionary to free.
void tv_dict_free(dict_T *const d)
  FUNC_ATTR_NONNULL_ALL
{
  if (tv_in_free_unref_items) {
    return;
  }

  tv_dict_free_contents(d);
  tv_dict_free_dict(d);
}

/// Unreference a dictionary
///
/// Decrements the reference count and frees dictionary when it becomes zero.
///
/// @param[in]  d  Dictionary to operate on.
void tv_dict_unref(dict_T *const d)
{
  if (d != NULL && --d->dv_refcount <= 0) {
    tv_dict_free(d);
  }
}

//{{{2 Indexing/searching

/// Find item in dictionary
///
/// @param[in]  d  Dictionary to check.
/// @param[in]  key  Dictionary key.
/// @param[in]  len  Key length. If negative, then strlen(key) is used.
///
/// @return found item or NULL if nothing was found.
dictitem_T *tv_dict_find(const dict_T *const d, const char *const key, const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (d == NULL) {
    return NULL;
  }
  hashitem_T *const hi = (len < 0
                          ? hash_find(&d->dv_hashtab, key)
                          : hash_find_len(&d->dv_hashtab, key, (size_t)len));
  if (HASHITEM_EMPTY(hi)) {
    return NULL;
  }
  return TV_DICT_HI2DI(hi);
}

/// Get a typval item from a dictionary and copy it into "rettv".
///
/// @param[in]  d  Dictionary to check.
/// @param[in]  key  Dictionary key.
/// @param[in]  rettv  Return value.
/// @return OK in case of success or FAIL if nothing was found.
int tv_dict_get_tv(dict_T *d, const char *const key, typval_T *rettv)
{
  dictitem_T *const di = tv_dict_find(d, key, -1);
  if (di == NULL) {
    return FAIL;
  }

  tv_copy(&di->di_tv, rettv);
  return OK;
}

/// Get a number item from a dictionary
///
/// Returns 0 if the entry does not exist.
///
/// @param[in]  d  Dictionary to get item from.
/// @param[in]  key  Key to find in dictionary.
///
/// @return Dictionary item.
varnumber_T tv_dict_get_number(const dict_T *const d, const char *const key)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return tv_dict_get_number_def(d, key, 0);
}

/// Get a number item from a dictionary.
///
/// Returns "def" if the entry doesn't exist.
///
/// @param[in]  d  Dictionary to get item from.
/// @param[in]  key  Key to find in dictionary.
/// @param[in]  def  Default value.
///
/// @return Dictionary item.
varnumber_T tv_dict_get_number_def(const dict_T *const d, const char *const key, const int def)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  dictitem_T *const di = tv_dict_find(d, key, -1);
  if (di == NULL) {
    return def;
  }
  return tv_get_number(&di->di_tv);
}

varnumber_T tv_dict_get_bool(const dict_T *const d, const char *const key, const int def)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  dictitem_T *const di = tv_dict_find(d, key, -1);
  if (di == NULL) {
    return def;
  }
  return tv_get_bool(&di->di_tv);
}

/// Converts a dict to an environment
char **tv_dict_to_env(dict_T *denv)
{
  size_t env_size = (size_t)tv_dict_len(denv);

  size_t i = 0;
  char **env = NULL;

  // + 1 for NULL
  env = xmalloc((env_size + 1) * sizeof(*env));

  TV_DICT_ITER(denv, var, {
    const char *str = tv_get_string(&var->di_tv);
    assert(str);
    size_t len = strlen(var->di_key) + strlen(str) + strlen("=") + 1;
    env[i] = xmalloc(len);
    snprintf(env[i], len, "%s=%s", var->di_key, str);
    i++;
  });

  // must be null terminated
  env[env_size] = NULL;
  return env;
}

/// Get a string item from a dictionary
///
/// @param[in]  d  Dictionary to get item from.
/// @param[in]  key  Dictionary key.
/// @param[in]  save  If true, returned string will be placed in the allocated
///                   memory.
///
/// @return NULL if key does not exist, empty string in case of type error,
///         string item value otherwise. If returned value is not NULL, it may
///         be allocated depending on `save` argument.
char *tv_dict_get_string(const dict_T *const d, const char *const key, const bool save)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char numbuf[NUMBUFLEN];
  const char *const s = tv_dict_get_string_buf(d, key, numbuf);
  if (save && s != NULL) {
    return xstrdup(s);
  }
  return (char *)s;
}

/// Get a string item from a dictionary
///
/// @param[in]  d  Dictionary to get item from.
/// @param[in]  key  Dictionary key.
/// @param[in]  numbuf  Buffer for non-string items converted to strings, at
///                     least of #NUMBUFLEN length.
///
/// @return NULL if key does not exist, empty string in case of type error,
///         string item value otherwise.
const char *tv_dict_get_string_buf(const dict_T *const d, const char *const key, char *const numbuf)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const dictitem_T *const di = tv_dict_find(d, key, -1);
  if (di == NULL) {
    return NULL;
  }
  return tv_get_string_buf(&di->di_tv, numbuf);
}

/// Get a string item from a dictionary
///
/// @param[in]  d  Dictionary to get item from.
/// @param[in]  key  Dictionary key.
/// @param[in]  key_len  Key length.
/// @param[in]  numbuf  Buffer for non-string items converted to strings, at
///                     least of #NUMBUFLEN length.
/// @param[in]  def  Default return when key does not exist.
///
/// @return `def` when key does not exist,
///         NULL in case of type error,
///         string item value in case of success.
const char *tv_dict_get_string_buf_chk(const dict_T *const d, const char *const key,
                                       const ptrdiff_t key_len, char *const numbuf,
                                       const char *const def)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const dictitem_T *const di = tv_dict_find(d, key, key_len);
  if (di == NULL) {
    return def;
  }
  return tv_get_string_buf_chk(&di->di_tv, numbuf);
}

/// Get a function from a dictionary
///
/// @param[in]  d  Dictionary to get callback from.
/// @param[in]  key  Dictionary key.
/// @param[in]  key_len  Key length, may be -1 to use strlen().
/// @param[out]  result  The address where a pointer to the wanted callback
///                      will be left.
///
/// @return true/false on success/failure.
bool tv_dict_get_callback(dict_T *const d, const char *const key, const ptrdiff_t key_len,
                          Callback *const result)
  FUNC_ATTR_NONNULL_ARG(2, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  result->type = kCallbackNone;

  dictitem_T *const di = tv_dict_find(d, key, key_len);

  if (di == NULL) {
    return true;
  }

  if (!tv_is_func(di->di_tv) && di->di_tv.v_type != VAR_STRING) {
    emsg(_("E6000: Argument is not a function or function name"));
    return false;
  }

  typval_T tv;
  tv_copy(&di->di_tv, &tv);
  set_selfdict(&tv, d);
  const bool res = callback_from_typval(result, &tv);
  tv_clear(&tv);
  return res;
}

/// Check for adding a function to g: or l:.
/// If the name is wrong give an error message and return true.
int tv_dict_wrong_func_name(dict_T *d, typval_T *tv, const char *name)
{
  return (d == &globvardict || &d->dv_hashtab == get_funccal_local_ht())
         && tv_is_func(*tv)
         && var_wrong_func_name(name, true);
}

//{{{2 dict_add*

/// Add item to dictionary
///
/// @param[out]  d  Dictionary to add to.
/// @param[in]  item  Item to add.
///
/// @return FAIL if key already exists.
int tv_dict_add(dict_T *const d, dictitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  if (tv_dict_wrong_func_name(d, &item->di_tv, item->di_key)) {
    return FAIL;
  }
  return hash_add(&d->dv_hashtab, item->di_key);
}

/// Add a list entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param  list  List to add. Will have reference count incremented.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_list(dict_T *const d, const char *const key, const size_t key_len,
                     list_T *const list)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_LIST;
  item->di_tv.vval.v_list = list;
  tv_list_ref(list);
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a typval entry to dictionary.
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
///
/// @return FAIL if out of memory or key already exists.
int tv_dict_add_tv(dict_T *d, const char *key, const size_t key_len, typval_T *tv)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  tv_copy(tv, &item->di_tv);
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a dictionary entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param  dict  Dictionary to add. Will have reference count incremented.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_dict(dict_T *const d, const char *const key, const size_t key_len,
                     dict_T *const dict)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_DICT;
  item->di_tv.vval.v_dict = dict;
  dict->dv_refcount++;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a number entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  nr  Number to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_nr(dict_T *const d, const char *const key, const size_t key_len,
                   const varnumber_T nr)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_NUMBER;
  item->di_tv.vval.v_number = nr;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a floating point number entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  nr  Floating point number to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_float(dict_T *const d, const char *const key, const size_t key_len,
                      const float_T nr)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_FLOAT;
  item->di_tv.vval.v_float = nr;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a boolean entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  val BoolVarValue to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_bool(dict_T *const d, const char *const key, const size_t key_len, BoolVarValue val)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_BOOL;
  item->di_tv.vval.v_bool = val;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a string entry to dictionary
///
/// @see tv_dict_add_allocated_str
int tv_dict_add_str(dict_T *const d, const char *const key, const size_t key_len,
                    const char *const val)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  return tv_dict_add_str_len(d, key, key_len, val, -1);
}

/// Add a string entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  val  String to add. NULL adds empty string.
/// @param[in]  len  Use this many bytes from `val`, or -1 for whole string.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_str_len(dict_T *const d, const char *const key, const size_t key_len,
                        const char *const val, int len)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  char *s = NULL;
  if (val != NULL) {
    s = (len < 0) ? xstrdup(val) : xstrndup(val, (size_t)len);
  }
  return tv_dict_add_allocated_str(d, key, key_len, s);
}

/// Add a string entry to dictionary
///
/// Unlike tv_dict_add_str() saves val to the new dictionary item in place of
/// creating a new copy.
///
/// @warning String will be freed even in case addition fails.
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  val  String to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_allocated_str(dict_T *const d, const char *const key, const size_t key_len,
                              char *const val)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_type = VAR_STRING;
  item->di_tv.vval.v_string = val;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

//{{{2 Operations on the whole dict

/// Clear all the keys of a Dictionary. "d" remains a valid empty Dictionary.
///
/// @param  d  The Dictionary to clear
void tv_dict_clear(dict_T *const d)
  FUNC_ATTR_NONNULL_ALL
{
  hash_lock(&d->dv_hashtab);
  assert(d->dv_hashtab.ht_locked > 0);

  HASHTAB_ITER(&d->dv_hashtab, hi, {
    tv_dict_item_free(TV_DICT_HI2DI(hi));
    hash_remove(&d->dv_hashtab, hi);
  });

  hash_unlock(&d->dv_hashtab);
}

/// Extend dictionary with items from another dictionary
///
/// @param  d1  Dictionary to extend.
/// @param[in]  d2  Dictionary to extend with.
/// @param[in]  action  "error", "force", "move", "keep":
///                     e*, including "error": duplicate key gives an error.
///                     f*, including "force": duplicate d2 keys override d1.
///                     m*, including "move": move items instead of copying.
///                     other, including "keep": duplicate d2 keys ignored.
void tv_dict_extend(dict_T *const d1, dict_T *const d2, const char *const action)
  FUNC_ATTR_NONNULL_ALL
{
  const bool watched = tv_dict_is_watched(d1);
  const char *const arg_errmsg = _("extend() argument");
  const size_t arg_errmsg_len = strlen(arg_errmsg);

  if (*action == 'm') {
    hash_lock(&d2->dv_hashtab);  // don't rehash on hash_remove()
  }

  HASHTAB_ITER(&d2->dv_hashtab, hi2, {
    dictitem_T *const di2 = TV_DICT_HI2DI(hi2);
    dictitem_T *const di1 = tv_dict_find(d1, di2->di_key, -1);
    // Check the key to be valid when adding to any scope.
    if (d1->dv_scope != VAR_NO_SCOPE && !valid_varname(di2->di_key)) {
      break;
    }
    if (di1 == NULL) {
      if (*action == 'm') {
        // Cheap way to move a dict item from "d2" to "d1".
        // If dict_add() fails then "d2" won't be empty.
        dictitem_T *const new_di = di2;
        if (tv_dict_add(d1, new_di) == OK) {
          hash_remove(&d2->dv_hashtab, hi2);
          tv_dict_watcher_notify(d1, new_di->di_key, &new_di->di_tv, NULL);
        }
      } else {
        dictitem_T *const new_di = tv_dict_item_copy(di2);
        if (tv_dict_add(d1, new_di) == FAIL) {
          tv_dict_item_free(new_di);
        } else if (watched) {
          tv_dict_watcher_notify(d1, new_di->di_key, &new_di->di_tv, NULL);
        }
      }
    } else if (*action == 'e') {
      semsg(_("E737: Key already exists: %s"), di2->di_key);
      break;
    } else if (*action == 'f' && di2 != di1) {
      typval_T oldtv;

      if (value_check_lock(di1->di_tv.v_lock, arg_errmsg, arg_errmsg_len)
          || var_check_ro(di1->di_flags, arg_errmsg, arg_errmsg_len)) {
        break;
      }
      // Disallow replacing a builtin function.
      if (tv_dict_wrong_func_name(d1, &di2->di_tv, di2->di_key)) {
        break;
      }

      if (watched) {
        tv_copy(&di1->di_tv, &oldtv);
      }

      tv_clear(&di1->di_tv);
      tv_copy(&di2->di_tv, &di1->di_tv);

      if (watched) {
        tv_dict_watcher_notify(d1, di1->di_key, &di1->di_tv, &oldtv);
        tv_clear(&oldtv);
      }
    }
  });

  if (*action == 'm') {
    hash_unlock(&d2->dv_hashtab);
  }
}

/// Compare two dictionaries
///
/// @param[in]  d1  First dictionary.
/// @param[in]  d2  Second dictionary.
/// @param[in]  ic  True if case is to be ignored.
///
/// @return True if dictionaries are equal, false otherwise.
bool tv_dict_equal(dict_T *const d1, dict_T *const d2, const bool ic)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (d1 == d2) {
    return true;
  }
  if (tv_dict_len(d1) != tv_dict_len(d2)) {
    return false;
  }
  if (tv_dict_len(d1) == 0) {
    // empty and NULL dicts are considered equal
    return true;
  }
  if (d1 == NULL || d2 == NULL) {
    return false;
  }

  TV_DICT_ITER(d1, di1, {
    dictitem_T *const di2 = tv_dict_find(d2, di1->di_key, -1);
    if (di2 == NULL) {
      return false;
    }
    if (!tv_equal(&di1->di_tv, &di2->di_tv, ic)) {
      return false;
    }
  });
  return true;
}

/// Make a copy of dictionary
///
/// @param[in]  conv  If non-NULL, then all internal strings will be converted.
/// @param[in]  orig  Original dictionary to copy.
/// @param[in]  deep  If false, then shallow copy will be done.
/// @param[in]  copyID  See var_item_copy().
///
/// @return Copied dictionary. May be NULL in case original dictionary is NULL
///         or some failure happens. The refcount of the new dictionary is set
///         to 1.
dict_T *tv_dict_copy(const vimconv_T *const conv, dict_T *const orig, const bool deep,
                     const int copyID)
{
  if (orig == NULL) {
    return NULL;
  }

  dict_T *copy = tv_dict_alloc();
  if (copyID != 0) {
    orig->dv_copyID = copyID;
    orig->dv_copydict = copy;
  }
  TV_DICT_ITER(orig, di, {
    if (got_int) {
      break;
    }
    dictitem_T *new_di;
    if (conv == NULL || conv->vc_type == CONV_NONE) {
      new_di = tv_dict_item_alloc(di->di_key);
    } else {
      size_t len = strlen(di->di_key);
      char *const key = string_convert(conv, di->di_key, &len);
      if (key == NULL) {
        new_di = tv_dict_item_alloc_len(di->di_key, len);
      } else {
        new_di = tv_dict_item_alloc_len(key, len);
        xfree(key);
      }
    }
    if (deep) {
      if (var_item_copy(conv, &di->di_tv, &new_di->di_tv, deep,
                        copyID) == FAIL) {
        xfree(new_di);
        break;
      }
    } else {
      tv_copy(&di->di_tv, &new_di->di_tv);
    }
    if (tv_dict_add(copy, new_di) == FAIL) {
      tv_dict_item_free(new_di);
      break;
    }
  });

  copy->dv_refcount++;
  if (got_int) {
    tv_dict_unref(copy);
    copy = NULL;
  }

  return copy;
}

/// Set all existing keys in "dict" as read-only.
///
/// This does not protect against adding new keys to the Dictionary.
///
/// @param  dict  The dict whose keys should be frozen.
void tv_dict_set_keys_readonly(dict_T *const dict)
  FUNC_ATTR_NONNULL_ALL
{
  TV_DICT_ITER(dict, di, {
    di->di_flags |= DI_FLAGS_RO | DI_FLAGS_FIX;
  });
}

//{{{1 Blobs
//{{{2 Alloc/free

/// Allocate an empty blob.
///
/// Caller should take care of the reference count.
///
/// @return [allocated] new blob.
blob_T *tv_blob_alloc(void)
  FUNC_ATTR_NONNULL_RET
{
  blob_T *const blob = xcalloc(1, sizeof(blob_T));
  ga_init(&blob->bv_ga, 1, 100);
  return blob;
}

/// Free a blob. Ignores the reference count.
///
/// @param[in,out]  b  Blob to free.
void tv_blob_free(blob_T *const b)
  FUNC_ATTR_NONNULL_ALL
{
  ga_clear(&b->bv_ga);
  xfree(b);
}

/// Unreference a blob.
///
/// Decrements the reference count and frees blob when it becomes zero.
///
/// @param[in,out]  b  Blob to operate on.
void tv_blob_unref(blob_T *const b)
{
  if (b != NULL && --b->bv_refcount <= 0) {
    tv_blob_free(b);
  }
}

//{{{2 Operations on the whole blob

/// Check whether two blobs are equal.
///
/// @param[in]  b1  First blob.
/// @param[in]  b2  Second blob.
///
/// @return true if blobs are equal, false otherwise.
bool tv_blob_equal(const blob_T *const b1, const blob_T *const b2)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const int len1 = tv_blob_len(b1);
  const int len2 = tv_blob_len(b2);

  // empty and NULL are considered the same
  if (len1 == 0 && len2 == 0) {
    return true;
  }
  if (b1 == b2) {
    return true;
  }
  if (len1 != len2) {
    return false;
  }

  for (int i = 0; i < b1->bv_ga.ga_len; i++) {
    if (tv_blob_get(b1, i) != tv_blob_get(b2, i)) {
      return false;
    }
  }
  return true;
}

/// Returns a slice of "blob" from index "n1" to "n2" in "rettv".  The length of
/// the blob is "len".  Returns an empty blob if the indexes are out of range.
static int tv_blob_slice(const blob_T *blob, int len, varnumber_T n1, varnumber_T n2,
                         bool exclusive, typval_T *rettv)
{
  // The resulting variable is a sub-blob.  If the indexes
  // are out of range the result is empty.
  if (n1 < 0) {
    n1 = len + n1;
    if (n1 < 0) {
      n1 = 0;
    }
  }
  if (n2 < 0) {
    n2 = len + n2;
  } else if (n2 >= len) {
    n2 = len - (exclusive ? 0 : 1);
  }
  if (exclusive) {
    n2--;
  }
  if (n1 >= len || n2 < 0 || n1 > n2) {
    tv_clear(rettv);
    rettv->v_type = VAR_BLOB;
    rettv->vval.v_blob = NULL;
  } else {
    blob_T *const new_blob = tv_blob_alloc();
    ga_grow(&new_blob->bv_ga, (int)(n2 - n1 + 1));
    new_blob->bv_ga.ga_len = (int)(n2 - n1 + 1);
    for (int i = (int)n1; i <= (int)n2; i++) {
      tv_blob_set(new_blob, i - (int)n1, tv_blob_get(rettv->vval.v_blob, i));
    }
    tv_clear(rettv);
    tv_blob_set_ret(rettv, new_blob);
  }

  return OK;
}

/// Return the byte value in "blob" at index "idx" in "rettv".  If the index is
/// too big or negative that is an error.  The length of the blob is "len".
static int tv_blob_index(const blob_T *blob, int len, varnumber_T idx, typval_T *rettv)
{
  // The resulting variable is a byte value.
  // If the index is too big or negative that is an error.
  if (idx < 0) {
    idx = len + idx;
  }
  if (idx < len && idx >= 0) {
    const int v = (int)tv_blob_get(rettv->vval.v_blob, (int)idx);
    tv_clear(rettv);
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = v;
  } else {
    semsg(_(e_blobidx), idx);
    return FAIL;
  }

  return OK;
}

int tv_blob_slice_or_index(const blob_T *blob, bool is_range, varnumber_T n1, varnumber_T n2,
                           bool exclusive, typval_T *rettv)
{
  int len = tv_blob_len(rettv->vval.v_blob);

  if (is_range) {
    return tv_blob_slice(blob, len, n1, n2, exclusive, rettv);
  } else {
    return tv_blob_index(blob, len, n1, rettv);
  }
}

/// Check if "n1" is a valid index for a blob with length "bloblen".
int tv_blob_check_index(int bloblen, varnumber_T n1, bool quiet)
{
  if (n1 < 0 || n1 > bloblen) {
    if (!quiet) {
      semsg(_(e_blobidx), n1);
    }
    return FAIL;
  }
  return OK;
}

/// Check if "n1"-"n2" is a valid range for a blob with length "bloblen".
int tv_blob_check_range(int bloblen, varnumber_T n1, varnumber_T n2, bool quiet)
{
  if (n2 < 0 || n2 >= bloblen || n2 < n1) {
    if (!quiet) {
      semsg(_(e_blobidx), n2);
    }
    return FAIL;
  }
  return OK;
}

/// Set bytes "n1" to "n2" (inclusive) in "dest" to the value of "src".
/// Caller must make sure "src" is a blob.
/// Returns FAIL if the number of bytes does not match.
int tv_blob_set_range(blob_T *dest, varnumber_T n1, varnumber_T n2, typval_T *src)
{
  if (n2 - n1 + 1 != tv_blob_len(src->vval.v_blob)) {
    emsg(_("E972: Blob value does not have the right number of bytes"));
    return FAIL;
  }

  for (int il = (int)n1, ir = 0; il <= (int)n2; il++) {
    tv_blob_set(dest, il, tv_blob_get(src->vval.v_blob, ir++));
  }
  return OK;
}

/// Store one byte "byte" in blob "blob" at "idx".
/// Append one byte if needed.
void tv_blob_set_append(blob_T *blob, int idx, uint8_t byte)
{
  garray_T *gap = &blob->bv_ga;

  // Allow for appending a byte.  Setting a byte beyond
  // the end is an error otherwise.
  if (idx <= gap->ga_len) {
    if (idx == gap->ga_len) {
      ga_grow(gap, 1);
      gap->ga_len++;
    }
    tv_blob_set(blob, idx, byte);
  }
}

/// "remove({blob})" function
void tv_blob_remove(typval_T *argvars, typval_T *rettv, const char *arg_errmsg)
{
  blob_T *const b = argvars[0].vval.v_blob;

  if (b != NULL && value_check_lock(b->bv_lock, arg_errmsg, TV_TRANSLATE)) {
    return;
  }

  bool error = false;
  int64_t idx = tv_get_number_chk(&argvars[1], &error);

  if (!error) {
    const int len = tv_blob_len(b);

    if (idx < 0) {
      // count from the end
      idx = len + idx;
    }
    if (idx < 0 || idx >= len) {
      semsg(_(e_blobidx), idx);
      return;
    }
    if (argvars[2].v_type == VAR_UNKNOWN) {
      // Remove one item, return its value.
      uint8_t *const p = (uint8_t *)b->bv_ga.ga_data;
      rettv->vval.v_number = (varnumber_T)(*(p + idx));
      memmove(p + idx, p + idx + 1, (size_t)(len - idx - 1));
      b->bv_ga.ga_len--;
    } else {
      // Remove range of items, return blob with values.
      int64_t end = tv_get_number_chk(&argvars[2], &error);
      if (error) {
        return;
      }
      if (end < 0) {
        // count from the end
        end = len + end;
      }
      if (end >= len || idx > end) {
        semsg(_(e_blobidx), end);
        return;
      }
      blob_T *const blob = tv_blob_alloc();
      blob->bv_ga.ga_len = (int)(end - idx + 1);
      ga_grow(&blob->bv_ga, (int)(end - idx + 1));

      uint8_t *const p = (uint8_t *)b->bv_ga.ga_data;
      memmove(blob->bv_ga.ga_data, p + idx, (size_t)(end - idx + 1));
      tv_blob_set_ret(rettv, blob);

      if (len - end - 1 > 0) {
        memmove(p + idx, p + end + 1, (size_t)(len - end - 1));
      }
      b->bv_ga.ga_len -= (int)(end - idx + 1);
    }
  }
}

/// blob2list() function
void f_blob2list(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (tv_check_for_blob_arg(argvars, 0) == FAIL) {
    return;
  }

  blob_T *const blob = argvars->vval.v_blob;
  list_T *const l = rettv->vval.v_list;
  for (int i = 0; i < tv_blob_len(blob); i++) {
    tv_list_append_number(l, tv_blob_get(blob, i));
  }
}

/// list2blob() function
void f_list2blob(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  blob_T *blob = tv_blob_alloc_ret(rettv);

  if (tv_check_for_list_arg(argvars, 0) == FAIL) {
    return;
  }

  list_T *const l = argvars->vval.v_list;
  if (l == NULL) {
    return;
  }

  TV_LIST_ITER_CONST(l, li, {
    bool error = false;
    varnumber_T n = tv_get_number_chk(TV_LIST_ITEM_TV(li), &error);
    if (error || n < 0 || n > 255) {
      if (!error) {
        semsg(_(e_invalid_value_for_blob_nr), (int)n);
      }
      ga_clear(&blob->bv_ga);
      return;
    }
    ga_append(&blob->bv_ga, (uint8_t)n);
  });
}

//{{{1 Generic typval operations
//{{{2 Init/alloc/clear
//{{{3 Alloc

/// Allocate an empty list for a return value
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where list is saved.
/// @param[in]  len  Expected number of items to be populated before list
///                  becomes accessible from Vimscript. It is still valid to
///                  underpopulate a list, value only controls how many elements
///                  will be allocated in advance. @see ListLenSpecials.
///
/// @return [allocated] pointer to the created list.
list_T *tv_list_alloc_ret(typval_T *const ret_tv, const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  list_T *const l = tv_list_alloc(len);
  tv_list_set_ret(ret_tv, l);
  ret_tv->v_lock = VAR_UNLOCKED;
  return l;
}

dict_T *tv_dict_alloc_lock(VarLockStatus lock)
  FUNC_ATTR_NONNULL_RET
{
  dict_T *const d = tv_dict_alloc();
  d->dv_lock = lock;
  return d;
}

/// Allocate an empty dictionary for a return value
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where dictionary is saved.
void tv_dict_alloc_ret(typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  dict_T *const d = tv_dict_alloc_lock(VAR_UNLOCKED);
  tv_dict_set_ret(ret_tv, d);
}

/// Turn a dictionary into a list
///
/// @param[in] argvars Arguments to items(). The first argument is check for being
///                    a dictionary, will give an error if not.
/// @param[out] rettv  Location where result will be saved.
/// @param[in] what    What to save in rettv.
static void tv_dict2list(typval_T *const argvars, typval_T *const rettv, const DictListType what)
{
  if ((what == kDict2ListItems
       ? tv_check_for_string_or_list_or_dict_arg(argvars, 0)
       : tv_check_for_dict_arg(argvars, 0)) == FAIL) {
    tv_list_alloc_ret(rettv, 0);
    return;
  }

  dict_T *d = argvars[0].vval.v_dict;
  tv_list_alloc_ret(rettv, tv_dict_len(d));
  if (d == NULL) {
    // NULL dict behaves like an empty dict
    return;
  }

  TV_DICT_ITER(d, di, {
    typval_T tv_item = { .v_lock = VAR_UNLOCKED };

    switch (what) {
      case kDict2ListKeys:
        tv_item.v_type = VAR_STRING;
        tv_item.vval.v_string = xstrdup(di->di_key);
        break;
      case kDict2ListValues:
        tv_copy(&di->di_tv, &tv_item);
        break;
      case kDict2ListItems: {
        // items()
        list_T *const sub_l = tv_list_alloc(2);
        tv_item.v_type = VAR_LIST;
        tv_item.vval.v_list = sub_l;
        tv_list_ref(sub_l);
        tv_list_append_string(sub_l, di->di_key, -1);
        tv_list_append_tv(sub_l, &di->di_tv);
        break;
      }
    }

    tv_list_append_owned_tv(rettv->vval.v_list, tv_item);
  });
}

/// "items(dict)" function
void f_items(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (argvars[0].v_type == VAR_STRING) {
    tv_string2items(argvars, rettv);
  } else if (argvars[0].v_type == VAR_LIST) {
    tv_list2items(argvars, rettv);
  } else {
    tv_dict2list(argvars, rettv, kDict2ListItems);
  }
}

/// "keys()" function
void f_keys(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict2list(argvars, rettv, kDict2ListKeys);
}

/// "values(dict)" function
void f_values(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict2list(argvars, rettv, kDict2ListValues);
}

/// "has_key()" function
void f_has_key(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_dict_arg(argvars, 0) == FAIL) {
    return;
  }

  if (argvars[0].vval.v_dict == NULL) {
    return;
  }

  rettv->vval.v_number = tv_dict_find(argvars[0].vval.v_dict,
                                      tv_get_string(&argvars[1]),
                                      -1) != NULL;
}

/// "remove({dict})" function
void tv_dict_remove(typval_T *argvars, typval_T *rettv, const char *arg_errmsg)
{
  dict_T *d;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    semsg(_(e_toomanyarg), "remove()");
  } else if ((d = argvars[0].vval.v_dict) != NULL
             && !value_check_lock(d->dv_lock, arg_errmsg, TV_TRANSLATE)) {
    const char *key = tv_get_string_chk(&argvars[1]);
    if (key != NULL) {
      dictitem_T *di = tv_dict_find(d, key, -1);
      if (di == NULL) {
        semsg(_(e_dictkey), key);
      } else if (!var_check_fixed(di->di_flags, arg_errmsg, TV_TRANSLATE)
                 && !var_check_ro(di->di_flags, arg_errmsg, TV_TRANSLATE)) {
        *rettv = di->di_tv;
        di->di_tv = TV_INITIAL_VALUE;
        tv_dict_item_remove(d, di);
        if (tv_dict_is_watched(d)) {
          tv_dict_watcher_notify(d, key, NULL, rettv);
        }
      }
    }
  }
}

/// Allocate an empty blob for a return value.
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where blob is saved.
blob_T *tv_blob_alloc_ret(typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  blob_T *const b = tv_blob_alloc();
  tv_blob_set_ret(ret_tv, b);
  return b;
}

/// Copy a blob typval to a different typval.
///
/// @param[in]  from  Blob object to copy from.
/// @param[out]  to  Blob object to copy to.
void tv_blob_copy(blob_T *const from, typval_T *const to)
  FUNC_ATTR_NONNULL_ARG(2)
{
  to->v_type = VAR_BLOB;
  to->v_lock = VAR_UNLOCKED;
  if (from == NULL) {
    to->vval.v_blob = NULL;
  } else {
    tv_blob_alloc_ret(to);
    int len = from->bv_ga.ga_len;

    if (len > 0) {
      to->vval.v_blob->bv_ga.ga_data = xmemdup(from->bv_ga.ga_data, (size_t)len);
    }
    to->vval.v_blob->bv_ga.ga_len = len;
    to->vval.v_blob->bv_ga.ga_maxlen = len;
  }
}

//{{{3 Clear
#define TYPVAL_ENCODE_ALLOW_SPECIALS false
#define TYPVAL_ENCODE_CHECK_BEFORE

#define TYPVAL_ENCODE_CONV_NIL(tv) \
  do { \
    (tv)->vval.v_special = kSpecialVarNull; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

#define TYPVAL_ENCODE_CONV_BOOL(tv, num) \
  do { \
    (tv)->vval.v_bool = kBoolVarFalse; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

#define TYPVAL_ENCODE_CONV_NUMBER(tv, num) \
  do { \
    (void)(num); \
    (tv)->vval.v_number = 0; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(tv, num)

#define TYPVAL_ENCODE_CONV_FLOAT(tv, flt) \
  do { \
    (tv)->vval.v_float = 0; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

#define TYPVAL_ENCODE_CONV_STRING(tv, buf, len) \
  do { \
    xfree(buf); \
    (tv)->vval.v_string = NULL; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING(tv, buf, len)

#define TYPVAL_ENCODE_CONV_EXT_STRING(tv, buf, len, type)

#define TYPVAL_ENCODE_CONV_BLOB(tv, blob, len) \
  do { \
    tv_blob_unref((tv)->vval.v_blob); \
    (tv)->vval.v_blob = NULL; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

static inline int _nothing_conv_func_start(typval_T *const tv, char *const fun)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ARG(1)
{
  tv->v_lock = VAR_UNLOCKED;
  if (tv->v_type == VAR_PARTIAL) {
    partial_T *const pt_ = tv->vval.v_partial;
    if (pt_ != NULL && pt_->pt_refcount > 1) {
      pt_->pt_refcount--;
      tv->vval.v_partial = NULL;
      return OK;
    }
  } else {
    func_unref(fun);
    if (fun != tv_empty_string) {
      xfree(fun);
    }
    tv->vval.v_string = NULL;
  }
  return NOTDONE;
}
#define TYPVAL_ENCODE_CONV_FUNC_START(tv, fun) \
  do { \
    if (_nothing_conv_func_start(tv, fun) != NOTDONE) { \
      return OK; \
    } \
  } while (0)

#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF(tv, len)

static inline void _nothing_conv_func_end(typval_T *const tv, const int copyID)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  if (tv->v_type == VAR_PARTIAL) {
    partial_T *const pt = tv->vval.v_partial;
    if (pt == NULL) {
      return;
    }
    // Dictionary should already be freed by the time.
    // If it was not freed then it is a part of the reference cycle.
    assert(pt->pt_dict == NULL || pt->pt_dict->dv_copyID == copyID);
    pt->pt_dict = NULL;
    // As well as all arguments.
    pt->pt_argc = 0;
    assert(pt->pt_refcount <= 1);
    partial_unref(pt);
    tv->vval.v_partial = NULL;
    assert(tv->v_lock == VAR_UNLOCKED);
  }
}
#define TYPVAL_ENCODE_CONV_FUNC_END(tv) _nothing_conv_func_end(tv, copyID)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST(tv) \
  do { \
    tv_list_unref((tv)->vval.v_list); \
    (tv)->vval.v_list = NULL; \
    (tv)->v_lock = VAR_UNLOCKED; \
  } while (0)

static inline void _nothing_conv_empty_dict(typval_T *const tv, dict_T **const dictp)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ARG(2)
{
  tv_dict_unref(*dictp);
  *dictp = NULL;
  if (tv != NULL) {
    tv->v_lock = VAR_UNLOCKED;
  }
}
#define TYPVAL_ENCODE_CONV_EMPTY_DICT(tv, dict) \
  do { \
    assert((void *)&(dict) != (void *)&TYPVAL_ENCODE_NODICT_VAR); \
    _nothing_conv_empty_dict(tv, ((dict_T **)&(dict))); \
  } while (0)

static inline int _nothing_conv_real_list_after_start(typval_T *const tv,
                                                      MPConvStackVal *const mpsv)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(tv != NULL);
  tv->v_lock = VAR_UNLOCKED;
  if (tv->vval.v_list->lv_refcount > 1) {
    tv->vval.v_list->lv_refcount--;
    tv->vval.v_list = NULL;
    mpsv->data.l.li = NULL;
    return OK;
  }
  return NOTDONE;
}
#define TYPVAL_ENCODE_CONV_LIST_START(tv, len)

#define TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START(tv, mpsv) \
  do { \
    if (_nothing_conv_real_list_after_start(tv, &(mpsv)) != NOTDONE) { \
      goto typval_encode_stop_converting_one_item; \
    } \
  } while (0)

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS(tv)

static inline void _nothing_conv_list_end(typval_T *const tv)
  FUNC_ATTR_ALWAYS_INLINE
{
  if (tv == NULL) {
    return;
  }
  assert(tv->v_type == VAR_LIST);
  list_T *const list = tv->vval.v_list;
  tv_list_unref(list);
  tv->vval.v_list = NULL;
}
#define TYPVAL_ENCODE_CONV_LIST_END(tv) _nothing_conv_list_end(tv)

static inline int _nothing_conv_real_dict_after_start(typval_T *const tv, dict_T **const dictp,
                                                      const void *const nodictvar,
                                                      MPConvStackVal *const mpsv)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (tv != NULL) {
    tv->v_lock = VAR_UNLOCKED;
  }
  if ((const void *)dictp != nodictvar && (*dictp)->dv_refcount > 1) {
    (*dictp)->dv_refcount--;
    *dictp = NULL;
    mpsv->data.d.todo = 0;
    return OK;
  }
  return NOTDONE;
}
#define TYPVAL_ENCODE_CONV_DICT_START(tv, dict, len)

#define TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START(tv, dict, mpsv) \
  do { \
    if (_nothing_conv_real_dict_after_start(tv, (dict_T **)&(dict), \
                                            (void *)&TYPVAL_ENCODE_NODICT_VAR, &(mpsv)) \
        != NOTDONE) { \
      goto typval_encode_stop_converting_one_item; \
    } \
  } while (0)

#define TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK(tv, dict)
#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(tv, dict)
#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict)

static inline void _nothing_conv_dict_end(typval_T *const tv, dict_T **const dictp,
                                          const void *const nodictvar)
  FUNC_ATTR_ALWAYS_INLINE
{
  if ((const void *)dictp != nodictvar) {
    tv_dict_unref(*dictp);
    *dictp = NULL;
  }
}
#define TYPVAL_ENCODE_CONV_DICT_END(tv, dict) \
  _nothing_conv_dict_end(tv, (dict_T **)&(dict), \
                         (void *)&TYPVAL_ENCODE_NODICT_VAR)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type)

#define TYPVAL_ENCODE_SCOPE static
#define TYPVAL_ENCODE_NAME nothing
#define TYPVAL_ENCODE_FIRST_ARG_TYPE const void *const
#define TYPVAL_ENCODE_FIRST_ARG_NAME ignored
#include "nvim/eval/typval_encode.c.h"

#undef TYPVAL_ENCODE_SCOPE
#undef TYPVAL_ENCODE_NAME
#undef TYPVAL_ENCODE_FIRST_ARG_TYPE
#undef TYPVAL_ENCODE_FIRST_ARG_NAME

#undef TYPVAL_ENCODE_ALLOW_SPECIALS
#undef TYPVAL_ENCODE_CHECK_BEFORE
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_BLOB
#undef TYPVAL_ENCODE_CONV_FUNC_START
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF
#undef TYPVAL_ENCODE_CONV_FUNC_END
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START
#undef TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_RECURSE

/// Free memory for a variable value and set the value to NULL or 0
///
/// @param[in,out]  tv  Value to free.
void tv_clear(typval_T *const tv)
{
  if (tv == NULL || tv->v_type == VAR_UNKNOWN) {
    return;
  }

  // WARNING: do not translate the string here, gettext is slow and function
  // is used *very* often. At the current state encode_vim_to_nothing() does
  // not error out and does not use the argument anywhere.
  //
  // If situation changes and this argument will be used, translate it in the
  // place where it is used.
  const int evn_ret = encode_vim_to_nothing(NULL, tv, "tv_clear() argument");
  (void)evn_ret;
  assert(evn_ret == OK);
}

//{{{3 Free

/// Free allocated Vimscript object and value stored inside
///
/// @param  tv  Object to free.
void tv_free(typval_T *tv)
{
  if (tv == NULL) {
    return;
  }

  switch (tv->v_type) {
  case VAR_PARTIAL:
    partial_unref(tv->vval.v_partial);
    break;
  case VAR_FUNC:
    func_unref(tv->vval.v_string);
    FALLTHROUGH;
  case VAR_STRING:
    xfree(tv->vval.v_string);
    break;
  case VAR_BLOB:
    tv_blob_unref(tv->vval.v_blob);
    break;
  case VAR_LIST:
    tv_list_unref(tv->vval.v_list);
    break;
  case VAR_DICT:
    tv_dict_unref(tv->vval.v_dict);
    break;
  case VAR_BOOL:
  case VAR_SPECIAL:
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_UNKNOWN:
    break;
  }
  xfree(tv);
}

//{{{3 Copy

/// Copy typval from one location to another
///
/// When needed allocates string or increases reference count. Does not make
/// a copy of a container, but copies its reference!
///
/// It is OK for `from` and `to` to point to the same location; this is used to
/// make a copy later.
///
/// @param[in]  from  Location to copy from.
/// @param[out]  to  Location to copy to.
void tv_copy(const typval_T *const from, typval_T *const to)
{
  to->v_type = from->v_type;
  to->v_lock = VAR_UNLOCKED;
  memmove(&to->vval, &from->vval, sizeof(to->vval));
  switch (from->v_type) {
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_BOOL:
  case VAR_SPECIAL:
    break;
  case VAR_STRING:
  case VAR_FUNC:
    if (from->vval.v_string != NULL) {
      to->vval.v_string = xstrdup(from->vval.v_string);
      if (from->v_type == VAR_FUNC) {
        func_ref(to->vval.v_string);
      }
    }
    break;
  case VAR_PARTIAL:
    if (to->vval.v_partial != NULL) {
      to->vval.v_partial->pt_refcount++;
    }
    break;
  case VAR_BLOB:
    if (from->vval.v_blob != NULL) {
      to->vval.v_blob->bv_refcount++;
    }
    break;
  case VAR_LIST:
    tv_list_ref(to->vval.v_list);
    break;
  case VAR_DICT:
    if (from->vval.v_dict != NULL) {
      to->vval.v_dict->dv_refcount++;
    }
    break;
  case VAR_UNKNOWN:
    semsg(_(e_intern2), "tv_copy(UNKNOWN)");
    break;
  }
}

//{{{2 Locks

/// Lock or unlock an item
///
/// @param[out]  tv  Item to (un)lock.
/// @param[in]  deep  Levels to (un)lock, -1 to (un)lock everything.
/// @param[in]  lock  True if it is needed to lock an item, false to unlock.
/// @param[in]  check_refcount  If true, do not lock a list or dict with a
///                             reference count larger than 1.
void tv_item_lock(typval_T *const tv, const int deep, const bool lock, const bool check_refcount)
  FUNC_ATTR_NONNULL_ALL
{
  // TODO(ZyX-I): Make this not recursive
  static int recurse = 0;

  if (recurse >= DICT_MAXNEST) {
    emsg(_(e_variable_nested_too_deep_for_unlock));
    return;
  }
  if (deep == 0) {
    return;
  }
  recurse++;

  // lock/unlock the item itself
#define CHANGE_LOCK(lock, var) \
  do { \
    (var) = ((VarLockStatus[]) { \
      [VAR_UNLOCKED] = ((lock) ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_LOCKED] = ((lock) ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_FIXED] = VAR_FIXED, \
    })[var]; \
  } while (0)
  CHANGE_LOCK(lock, tv->v_lock);

  switch (tv->v_type) {
  case VAR_BLOB: {
    blob_T *const b = tv->vval.v_blob;
    if (b != NULL && !(check_refcount && b->bv_refcount > 1)) {
      CHANGE_LOCK(lock, b->bv_lock);
    }
    break;
  }
  case VAR_LIST: {
    list_T *const l = tv->vval.v_list;
    if (l != NULL && !(check_refcount && l->lv_refcount > 1)) {
      CHANGE_LOCK(lock, l->lv_lock);
      if (deep < 0 || deep > 1) {
        // Recursive: lock/unlock the items the List contains.
        TV_LIST_ITER(l, li, {
            tv_item_lock(TV_LIST_ITEM_TV(li), deep - 1, lock, check_refcount);
          });
      }
    }
    break;
  }
  case VAR_DICT: {
    dict_T *const d = tv->vval.v_dict;
    if (d != NULL && !(check_refcount && d->dv_refcount > 1)) {
      CHANGE_LOCK(lock, d->dv_lock);
      if (deep < 0 || deep > 1) {
        // recursive: lock/unlock the items the List contains
        TV_DICT_ITER(d, di, {
            tv_item_lock(&di->di_tv, deep - 1, lock, check_refcount);
          });
      }
    }
    break;
  }
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_STRING:
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_BOOL:
  case VAR_SPECIAL:
    break;
  case VAR_UNKNOWN:
    abort();
  }
#undef CHANGE_LOCK
  recurse--;
}

/// Check whether Vimscript value is locked itself or refers to a locked container
///
/// @warning Fixed container is not the same as locked.
///
/// @param[in]  tv  Value to check.
///
/// @return True if value is locked, false otherwise.
bool tv_islocked(const typval_T *const tv)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return ((tv->v_lock == VAR_LOCKED)
          || (tv->v_type == VAR_LIST
              && (tv_list_locked(tv->vval.v_list) == VAR_LOCKED))
          || (tv->v_type == VAR_DICT
              && tv->vval.v_dict != NULL
              && (tv->vval.v_dict->dv_lock == VAR_LOCKED)));
}

/// Return true if typval is locked
///
/// Also gives an error message when typval is locked.
///
/// @param[in]  tv  Typval.
/// @param[in]  name  Variable name, used in the error message.
/// @param[in]  name_len  Variable name length. Use #TV_TRANSLATE to translate
///                       variable name and compute the length. Use #TV_CSTRING
///                       to compute the length with strlen() without
///                       translating.
///
///                       Both #TV_… values are used for optimization purposes:
///                       variable name with its length is needed only in case
///                       of error, when no error occurs computing them is
///                       a waste of CPU resources. This especially applies to
///                       gettext.
///
/// @return true if variable is locked, false otherwise.
bool tv_check_lock(const typval_T *tv, const char *name, size_t name_len)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  VarLockStatus lock = VAR_UNLOCKED;

  switch (tv->v_type) {
  case VAR_BLOB:
    if (tv->vval.v_blob != NULL) {
      lock = tv->vval.v_blob->bv_lock;
    }
    break;
  case VAR_LIST:
    if (tv->vval.v_list != NULL) {
      lock = tv->vval.v_list->lv_lock;
    }
    break;
  case VAR_DICT:
    if (tv->vval.v_dict != NULL) {
      lock = tv->vval.v_dict->dv_lock;
    }
    break;
  default:
    break;
  }
  return value_check_lock(tv->v_lock, name, name_len)
         || (lock != VAR_UNLOCKED && value_check_lock(lock, name, name_len));
}

/// @return true if variable "name" has a locked (immutable) value
bool value_check_lock(VarLockStatus lock, const char *name, size_t name_len)
{
  const char *error_message = NULL;
  switch (lock) {
  case VAR_UNLOCKED:
    return false;
  case VAR_LOCKED:
    error_message = N_("E741: Value is locked: %.*s");
    break;
  case VAR_FIXED:
    error_message = N_("E742: Cannot change value of %.*s");
    break;
  }
  assert(error_message != NULL);

  if (name == NULL) {
    name = _("Unknown");
    name_len = strlen(name);
  } else if (name_len == TV_TRANSLATE) {
    name = _(name);
    name_len = strlen(name);
  } else if (name_len == TV_CSTRING) {
    name_len = strlen(name);
  }

  semsg(_(error_message), (int)name_len, name);

  return true;
}

//{{{2 Comparison

static int tv_equal_recurse_limit;

/// Compare two Vimscript values
///
/// Like "==", but strings and numbers are different, as well as floats and
/// numbers.
///
/// @warning Too nested structures may be considered equal even if they are not.
///
/// @param[in]  tv1  First value to compare.
/// @param[in]  tv2  Second value to compare.
/// @param[in]  ic  True if case is to be ignored.
///
/// @return true if values are equal.
bool tv_equal(typval_T *const tv1, typval_T *const tv2, const bool ic)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  // TODO(ZyX-I): Make this not recursive
  static int recursive_cnt = 0;  // Catch recursive loops.

  if (!(tv_is_func(*tv1) && tv_is_func(*tv2)) && tv1->v_type != tv2->v_type) {
    return false;
  }

  // Catch lists and dicts that have an endless loop by limiting
  // recursiveness to a limit.  We guess they are equal then.
  // A fixed limit has the problem of still taking an awful long time.
  // Reduce the limit every time running into it. That should work fine for
  // deeply linked structures that are not recursively linked and catch
  // recursiveness quickly.
  if (recursive_cnt == 0) {
    tv_equal_recurse_limit = 1000;
  }
  if (recursive_cnt >= tv_equal_recurse_limit) {
    tv_equal_recurse_limit--;
    return true;
  }

  switch (tv1->v_type) {
  case VAR_LIST: {
    recursive_cnt++;
    const bool r = tv_list_equal(tv1->vval.v_list, tv2->vval.v_list, ic);
    recursive_cnt--;
    return r;
  }
  case VAR_DICT: {
    recursive_cnt++;
    const bool r = tv_dict_equal(tv1->vval.v_dict, tv2->vval.v_dict, ic);
    recursive_cnt--;
    return r;
  }
  case VAR_PARTIAL:
  case VAR_FUNC: {
    if ((tv1->v_type == VAR_PARTIAL && tv1->vval.v_partial == NULL)
        || (tv2->v_type == VAR_PARTIAL && tv2->vval.v_partial == NULL)) {
      return false;
    }
    recursive_cnt++;
    const bool r = func_equal(tv1, tv2, ic);
    recursive_cnt--;
    return r;
  }
  case VAR_BLOB:
    return tv_blob_equal(tv1->vval.v_blob, tv2->vval.v_blob);
  case VAR_NUMBER:
    return tv1->vval.v_number == tv2->vval.v_number;
  case VAR_FLOAT:
    return tv1->vval.v_float == tv2->vval.v_float;
  case VAR_STRING: {
    char buf1[NUMBUFLEN];
    char buf2[NUMBUFLEN];
    const char *s1 = tv_get_string_buf(tv1, buf1);
    const char *s2 = tv_get_string_buf(tv2, buf2);
    return mb_strcmp_ic(ic, s1, s2) == 0;
  }
  case VAR_BOOL:
    return tv1->vval.v_bool == tv2->vval.v_bool;
  case VAR_SPECIAL:
    return tv1->vval.v_special == tv2->vval.v_special;
  case VAR_UNKNOWN:
    // VAR_UNKNOWN can be the result of an invalid expression, let’s say it
    // does not equal anything, not even self.
    return false;
  }

  abort();
  return false;
}

//{{{2 Type checks

/// Check that given value is a number or string
///
/// Error messages are compatible with tv_get_number() previously used for the
/// same purpose in buf*() functions. Special values are not accepted (previous
/// behaviour: silently fail to find buffer).
///
/// @param[in]  tv  Value to check.
///
/// @return true if everything is OK, false otherwise.
bool tv_check_str_or_nr(const typval_T *const tv)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  switch (tv->v_type) {
  case VAR_NUMBER:
  case VAR_STRING:
    return true;
  case VAR_FLOAT:
    emsg(_("E805: Expected a Number or a String, Float found"));
    return false;
  case VAR_PARTIAL:
  case VAR_FUNC:
    emsg(_("E703: Expected a Number or a String, Funcref found"));
    return false;
  case VAR_LIST:
    emsg(_("E745: Expected a Number or a String, List found"));
    return false;
  case VAR_DICT:
    emsg(_("E728: Expected a Number or a String, Dictionary found"));
    return false;
  case VAR_BLOB:
    emsg(_("E974: Expected a Number or a String, Blob found"));
    return false;
  case VAR_BOOL:
    emsg(_("E5299: Expected a Number or a String, Boolean found"));
    return false;
  case VAR_SPECIAL:
    emsg(_("E5300: Expected a Number or a String"));
    return false;
  case VAR_UNKNOWN:
    semsg(_(e_intern2), "tv_check_str_or_nr(UNKNOWN)");
    return false;
  }
  abort();
  return false;
}

#define FUNC_ERROR "E703: Using a Funcref as a Number"

static const char *const num_errors[] = {
  [VAR_PARTIAL] = N_(FUNC_ERROR),
  [VAR_FUNC] = N_(FUNC_ERROR),
  [VAR_LIST] = N_("E745: Using a List as a Number"),
  [VAR_DICT] = N_("E728: Using a Dictionary as a Number"),
  [VAR_FLOAT] = N_("E805: Using a Float as a Number"),
  [VAR_BLOB] = N_("E974: Using a Blob as a Number"),
  [VAR_UNKNOWN] = N_("E685: using an invalid value as a Number"),
};

#undef FUNC_ERROR

/// Check that given value is a number or can be converted to it
///
/// Error messages are compatible with tv_get_number_chk() previously used for
/// the same purpose.
///
/// @param[in]  tv  Value to check.
///
/// @return true if everything is OK, false otherwise.
bool tv_check_num(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (tv->v_type) {
  case VAR_NUMBER:
  case VAR_BOOL:
  case VAR_SPECIAL:
  case VAR_STRING:
    return true;
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_LIST:
  case VAR_DICT:
  case VAR_FLOAT:
  case VAR_BLOB:
  case VAR_UNKNOWN:
    emsg(_(num_errors[tv->v_type]));
    return false;
  }
  abort();
  return false;
}

#define FUNC_ERROR "E729: Using a Funcref as a String"

static const char *const str_errors[] = {
  [VAR_PARTIAL] = N_(FUNC_ERROR),
  [VAR_FUNC] = N_(FUNC_ERROR),
  [VAR_LIST] = N_("E730: Using a List as a String"),
  [VAR_DICT] = N_("E731: Using a Dictionary as a String"),
  [VAR_BLOB] = N_("E976: Using a Blob as a String"),
  [VAR_UNKNOWN] = e_using_invalid_value_as_string,
};

#undef FUNC_ERROR

/// Check that given value is a Vimscript String or can be "cast" to it.
///
/// Error messages are compatible with tv_get_string_chk() previously used for
/// the same purpose.
///
/// @param[in]  tv  Value to check.
///
/// @return true if everything is OK, false otherwise.
bool tv_check_str(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (tv->v_type) {
  case VAR_NUMBER:
  case VAR_BOOL:
  case VAR_SPECIAL:
  case VAR_STRING:
  case VAR_FLOAT:
    return true;
  case VAR_PARTIAL:
  case VAR_FUNC:
  case VAR_LIST:
  case VAR_DICT:
  case VAR_BLOB:
  case VAR_UNKNOWN:
    emsg(_(str_errors[tv->v_type]));
    return false;
  }
  abort();
  return false;
}

//{{{2 Get

/// Get the number value of a Vimscript object
///
/// @note Use tv_get_number_chk() if you need to determine whether there was an
///       error.
///
/// @param[in]  tv  Object to get value from.
///
/// @return Number value: vim_str2nr() output for VAR_STRING objects, value
///         for VAR_NUMBER objects, -1 for other types.
varnumber_T tv_get_number(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool error = false;
  return tv_get_number_chk(tv, &error);
}

/// Get the number value of a Vimscript object
///
/// @param[in]  tv  Object to get value from.
/// @param[out]  ret_error  If type error occurred then `true` will be written
///                         to this location. Otherwise it is not touched.
///
///                         @note Needs to be initialized to `false` to be
///                               useful.
///
/// @return Number value: vim_str2nr() output for VAR_STRING objects, value
///         for VAR_NUMBER objects, -1 (ret_error == NULL) or 0 (otherwise) for
///         other types.
varnumber_T tv_get_number_chk(const typval_T *const tv, bool *const ret_error)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  switch (tv->v_type) {
  case VAR_FUNC:
  case VAR_PARTIAL:
  case VAR_LIST:
  case VAR_DICT:
  case VAR_BLOB:
  case VAR_FLOAT:
    emsg(_(num_errors[tv->v_type]));
    break;
  case VAR_NUMBER:
    return tv->vval.v_number;
  case VAR_STRING: {
    varnumber_T n = 0;
    if (tv->vval.v_string != NULL) {
      vim_str2nr(tv->vval.v_string, NULL, NULL, STR2NR_ALL, &n, NULL, 0, false, NULL);
    }
    return n;
  }
  case VAR_BOOL:
    return tv->vval.v_bool == kBoolVarTrue ? 1 : 0;
  case VAR_SPECIAL:
    return 0;
  case VAR_UNKNOWN:
    semsg(_(e_intern2), "tv_get_number(UNKNOWN)");
    break;
  }
  if (ret_error != NULL) {
    *ret_error = true;
  }
  return (ret_error == NULL ? -1 : 0);
}

varnumber_T tv_get_bool(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return tv_get_number_chk(tv, NULL);
}

varnumber_T tv_get_bool_chk(const typval_T *const tv, bool *const ret_error)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  return tv_get_number_chk(tv, ret_error);
}

/// Get the line number from Vimscript object
///
/// @param[in]  tv  Object to get value from. Is expected to be a number or
///                 a special string like ".", "$", … (works with current buffer
///                 only).
///
/// @return Line number or -1 or 0.
linenr_T tv_get_lnum(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const int did_emsg_before = did_emsg;
  linenr_T lnum = (linenr_T)tv_get_number_chk(tv, NULL);
  if (lnum <= 0 && did_emsg_before == did_emsg && tv->v_type != VAR_NUMBER) {
    int fnum;
    // No valid number, try using same function as line() does.
    pos_T *const fp = var2fpos(tv, true, &fnum, false);
    if (fp != NULL) {
      lnum = fp->lnum;
    }
  }
  return lnum;
}

/// Get the floating-point value of a Vimscript object
///
/// Raises an error if object is not number or floating-point.
///
/// @param[in]  tv  Object to get value of.
///
/// @return Floating-point value of the variable or zero.
float_T tv_get_float(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (tv->v_type) {
  case VAR_NUMBER:
    return (float_T)(tv->vval.v_number);
  case VAR_FLOAT:
    return tv->vval.v_float;
  case VAR_PARTIAL:
  case VAR_FUNC:
    emsg(_("E891: Using a Funcref as a Float"));
    break;
  case VAR_STRING:
    emsg(_("E892: Using a String as a Float"));
    break;
  case VAR_LIST:
    emsg(_("E893: Using a List as a Float"));
    break;
  case VAR_DICT:
    emsg(_("E894: Using a Dictionary as a Float"));
    break;
  case VAR_BOOL:
    emsg(_("E362: Using a boolean value as a Float"));
    break;
  case VAR_SPECIAL:
    emsg(_("E907: Using a special value as a Float"));
    break;
  case VAR_BLOB:
    emsg(_("E975: Using a Blob as a Float"));
    break;
  case VAR_UNKNOWN:
    semsg(_(e_intern2), "tv_get_float(UNKNOWN)");
    break;
  }
  return 0;
}

/// Give an error and return FAIL unless "args[idx]" is a string.
int tv_check_for_string_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_STRING) {
    semsg(_(e_string_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a non-empty string.
int tv_check_for_nonempty_string_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (tv_check_for_string_arg(args, idx) == FAIL) {
    return FAIL;
  }
  if (args[idx].vval.v_string == NULL || *args[idx].vval.v_string == NUL) {
    semsg(_(e_non_empty_string_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Check for an optional string argument at "idx"
int tv_check_for_opt_string_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return (args[idx].v_type == VAR_UNKNOWN
          || tv_check_for_string_arg(args, idx) != FAIL) ? OK : FAIL;
}

/// Give an error and return FAIL unless "args[idx]" is a number.
int tv_check_for_number_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_NUMBER) {
    semsg(_(e_number_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Check for an optional number argument at "idx"
int tv_check_for_opt_number_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return (args[idx].v_type == VAR_UNKNOWN
          || tv_check_for_number_arg(args, idx) != FAIL) ? OK : FAIL;
}

/// Give an error and return FAIL unless "args[idx]" is a float or a number.
int tv_check_for_float_or_nr_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_FLOAT && args[idx].v_type != VAR_NUMBER) {
    semsg(_(e_float_or_number_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a bool.
int tv_check_for_bool_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_BOOL
      && !(args[idx].v_type == VAR_NUMBER
           && (args[idx].vval.v_number == 0
               || args[idx].vval.v_number == 1))) {
    semsg(_(e_bool_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Check for an optional bool argument at "idx".
/// Return FAIL if the type is wrong.
int tv_check_for_opt_bool_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type == VAR_UNKNOWN) {
    return OK;
  }
  return tv_check_for_bool_arg(args, idx);
}

/// Give an error and return FAIL unless "args[idx]" is a blob.
int tv_check_for_blob_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_BLOB) {
    semsg(_(e_blob_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a list.
int tv_check_for_list_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_LIST) {
    semsg(_(e_list_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a dict.
int tv_check_for_dict_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_DICT) {
    semsg(_(e_dict_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a non-NULL dict.
int tv_check_for_nonnull_dict_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (tv_check_for_dict_arg(args, idx) == FAIL) {
    return FAIL;
  }
  if (args[idx].vval.v_dict == NULL) {
    semsg(_(e_non_null_dict_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Check for an optional dict argument at "idx"
int tv_check_for_opt_dict_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return (args[idx].v_type == VAR_UNKNOWN
          || tv_check_for_dict_arg(args, idx) != FAIL) ? OK : FAIL;
}

/// Give an error and return FAIL unless "args[idx]" is a string or
/// a number.
int tv_check_for_string_or_number_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_STRING && args[idx].v_type != VAR_NUMBER) {
    semsg(_(e_string_or_number_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a buffer number.
/// Buffer number can be a number or a string.
int tv_check_for_buffer_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return tv_check_for_string_or_number_arg(args, idx);
}

/// Give an error and return FAIL unless "args[idx]" is a line number.
/// Line number can be a number or a string.
int tv_check_for_lnum_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return tv_check_for_string_or_number_arg(args, idx);
}

/// Give an error and return FAIL unless "args[idx]" is a string or a list.
int tv_check_for_string_or_list_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_STRING && args[idx].v_type != VAR_LIST) {
    semsg(_(e_string_or_list_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a string, a list or a blob.
int tv_check_for_string_or_list_or_blob_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_STRING
      && args[idx].v_type != VAR_LIST
      && args[idx].v_type != VAR_BLOB) {
    semsg(_(e_string_list_or_blob_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Check for an optional string or list argument at "idx"
int tv_check_for_opt_string_or_list_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return (args[idx].v_type == VAR_UNKNOWN
          || tv_check_for_string_or_list_arg(args, idx) != FAIL) ? OK : FAIL;
}

/// Give an error and return FAIL unless "args[idx]" is a string or a list or a dict
int tv_check_for_string_or_list_or_dict_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_STRING
      && args[idx].v_type != VAR_LIST
      && args[idx].v_type != VAR_DICT) {
    semsg(_(e_string_list_or_dict_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a string
/// or a function reference.
int tv_check_for_string_or_func_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_PARTIAL
      && args[idx].v_type != VAR_FUNC
      && args[idx].v_type != VAR_STRING) {
    semsg(_(e_string_or_function_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Give an error and return FAIL unless "args[idx]" is a list or a blob.
int tv_check_for_list_or_blob_arg(const typval_T *const args, const int idx)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (args[idx].v_type != VAR_LIST && args[idx].v_type != VAR_BLOB) {
    semsg(_(e_list_or_blob_required_for_argument_nr), idx + 1);
    return FAIL;
  }
  return OK;
}

/// Get the string value of a "stringish" Vimscript object.
///
/// @param[in]  tv  Object to get value of.
/// @param  buf  Buffer used to hold numbers and special variables converted to
///              string. When function encounters one of these stringified value
///              will be written to buf and buf will be returned.
///
///              Buffer must have NUMBUFLEN size.
///
/// @return Object value if it is VAR_STRING object, number converted to
///         a string for VAR_NUMBER, v: variable name for VAR_SPECIAL or NULL.
const char *tv_get_string_buf_chk(const typval_T *const tv, char *const buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (tv->v_type) {
  case VAR_NUMBER:
    snprintf(buf, NUMBUFLEN, "%" PRIdVARNUMBER, tv->vval.v_number);
    return buf;
  case VAR_FLOAT:
    vim_snprintf(buf, NUMBUFLEN, "%g", tv->vval.v_float);
    return buf;
  case VAR_STRING:
    if (tv->vval.v_string != NULL) {
      return tv->vval.v_string;
    }
    return "";
  case VAR_BOOL:
    STRCPY(buf, encode_bool_var_names[tv->vval.v_bool]);
    return buf;
  case VAR_SPECIAL:
    STRCPY(buf, encode_special_var_names[tv->vval.v_special]);
    return buf;
  case VAR_PARTIAL:
  case VAR_FUNC:
  case VAR_LIST:
  case VAR_DICT:
  case VAR_BLOB:
  case VAR_UNKNOWN:
    emsg(_(str_errors[tv->v_type]));
    return NULL;
  }
  abort();
  return NULL;
}

/// Get the string value of a "stringish" Vimscript object.
///
/// @warning For number and special values it uses a single, static buffer. It
///          may be used only once, next call to tv_get_string may reuse it. Use
///          tv_get_string_buf() if you need to use tv_get_string() output after
///          calling it again.
///
/// @param[in]  tv  Object to get value of.
///
/// @return Object value if it is VAR_STRING object, number converted to
///         a string for VAR_NUMBER, v: variable name for VAR_SPECIAL or NULL.
const char *tv_get_string_chk(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char mybuf[NUMBUFLEN];

  return tv_get_string_buf_chk(tv, mybuf);
}

/// Get the string value of a "stringish" Vimscript object.
///
/// @warning For number and special values it uses a single, static buffer. It
///          may be used only once, next call to tv_get_string may reuse it. Use
///          tv_get_string_buf() if you need to use tv_get_string() output after
///          calling it again.
///
/// @note tv_get_string_chk() and tv_get_string_buf_chk() are similar, but
///       return NULL on error.
///
/// @param[in]  tv  Object to get value of.
///
/// @return Object value if it is VAR_STRING object, number converted to
///         a string for VAR_NUMBER, v: variable name for VAR_SPECIAL or empty
///         string.
const char *tv_get_string(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char mybuf[NUMBUFLEN];
  return tv_get_string_buf((typval_T *)tv, mybuf);
}

/// Get the string value of a "stringish" Vimscript object.
///
/// @note tv_get_string_chk() and tv_get_string_buf_chk() are similar, but
///       return NULL on error.
///
/// @param[in]  tv  Object to get value of.
/// @param  buf  Buffer used to hold numbers and special variables converted to
///              string. When function encounters one of these stringified value
///              will be written to buf and buf will be returned.
///
///              Buffer must have NUMBUFLEN size.
///
/// @return Object value if it is VAR_STRING object, number converted to
///         a string for VAR_NUMBER, v: variable name for VAR_SPECIAL or empty
///         string.
const char *tv_get_string_buf(const typval_T *const tv, char *const buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *const res = tv_get_string_buf_chk(tv, buf);

  return res != NULL ? res : "";
}

/// Return true when "tv" is not falsy: non-zero, non-empty string, non-empty
/// list, etc.  Mostly like what JavaScript does, except that empty list and
/// empty dictionary are false.
bool tv2bool(const typval_T *const tv)
{
  switch (tv->v_type) {
  case VAR_NUMBER:
    return tv->vval.v_number != 0;
  case VAR_FLOAT:
    return tv->vval.v_float != 0.0;
  case VAR_PARTIAL:
    return tv->vval.v_partial != NULL;
  case VAR_FUNC:
  case VAR_STRING:
    return tv->vval.v_string != NULL && *tv->vval.v_string != NUL;
  case VAR_LIST:
    return tv->vval.v_list != NULL && tv->vval.v_list->lv_len > 0;
  case VAR_DICT:
    return tv->vval.v_dict != NULL && tv->vval.v_dict->dv_hashtab.ht_used > 0;
  case VAR_BOOL:
    return tv->vval.v_bool == kBoolVarTrue;
  case VAR_SPECIAL:
    return tv->vval.v_special != kSpecialVarNull;
  case VAR_BLOB:
    return tv->vval.v_blob != NULL && tv->vval.v_blob->bv_ga.ga_len > 0;
  case VAR_UNKNOWN:
    break;
  }
  return false;
}
