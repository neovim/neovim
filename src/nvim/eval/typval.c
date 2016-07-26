#include <stddef.h>
#include <stdbool.h>
#include <assert.h>

#include "nvim/eval/typval.h"
#include "nvim/eval/gc.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/typval_encode.h"
#include "nvim/types.h"
#include "nvim/assert.h"
#include "nvim/memory.h"
#include "nvim/globals.h"
// TODO(ZyX-I): Move line_breakcheck out of misc1
#include "nvim/misc1.h"  // For line_breakcheck

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/typval.c.generated.h"
#endif

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
listitem_T *tv_list_item_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC
{
  return xmalloc(sizeof(listitem_T));
}

/// Free a list item
///
/// Also clears the value. Does not touch watchers.
///
/// @param[out]  item  Item to free.
void tv_list_item_free(listitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  tv_clear(&item->li_tv);
  xfree(item);
}

/// Remove a list item from a List and free it
///
/// Also clears the value.
///
/// @param[out]  l  List to remove item from.
/// @param[in,out]  item  Item to remove.
void tv_list_item_remove(list_T *const l, listitem_T *const item)
  FUNC_ATTR_NONNULL_ALL
{
  tv_list_remove_items(l, item, item);
  tv_list_item_free(item);
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

//{{{2 Lists
//{{{3 Alloc/free

/// Allocate an empty list
///
/// Caller should take care of the reference count.
///
/// @return [allocated] new list.
list_T *tv_list_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC
{
  list_T *const list = xcalloc(1, sizeof(list_T));

  // Prepend the list to the list of lists for garbage collection.
  if (gc_first_list != NULL) {
    gc_first_list->lv_used_prev = list;
  }
  list->lv_used_prev = NULL;
  list->lv_used_next = gc_first_list;
  gc_first_list = list;
  return list;
}

/// Free a list, including all items it points to
///
/// Ignores the reference count.
///
/// @param[in,out]  l  List to free.
/// @param[in]  recurse  If true, free containers found in list.
void tv_list_free(list_T *const l, const bool recurse)
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

  for (listitem_T *item = l->lv_first; item != NULL; item = l->lv_first) {
    // Remove the item before deleting it.
    l->lv_first = item->li_next;
    if (recurse || (item->li_tv.v_type != VAR_LIST
                    && item->li_tv.v_type != VAR_DICT)) {
      tv_clear(&item->li_tv);
    }
    xfree(item);
  }
  xfree(l);
}

/// Unreference a list
///
/// Decrements the reference count and frees when it becomes zero or less.
///
/// @param[in,out]  l  List to unreference.
void tv_list_unref(list_T *const l)
{
  if (l != NULL && --l->lv_refcount <= 0) {
    tv_list_free(l, true);
  }
}

//{{{3 Add/remove

/// Remove items "item" to "item2" from list "l".
///
/// @warning Does not free the listitem or the value!
///
/// @param[out]  l  List to remove from.
/// @param[in]  item  First item to remove.
/// @param[in]  item2  Last item to remove.
void tv_list_remove_items(list_T *const l, listitem_T *const item,
                          listitem_T *const item2)
{
  // notify watchers
  for (listitem_T *ip = item; ip != NULL; ip = ip->li_next) {
    l->lv_len--;
    tv_list_watch_fix(l, ip);
    if (ip == item2) {
      break;
    }
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

/// Insert list item
///
/// @param[out]  l  List to insert to.
/// @param[in,out]  ni  Item to insert.
/// @param[in]  item  Item to insert before. If NULL, inserts at the end of the
///                   list.
void tv_list_insert(list_T *const l, listitem_T *const ni,
                    listitem_T *const item)
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

/// Insert VimL value into a list
///
/// @param[out]  l  List to insert to.
/// @param[in,out]  tv  Value to insert. Is copied (@see copy_tv()) to an
///                     allocated listitem_T and inserted.
/// @param[in]  item  Item to insert before. If NULL, inserts at the end of the
///                   list.
void tv_list_insert_tv(list_T *const l, typval_T *const tv,
                       listitem_T *const item)
{
  listitem_T *const ni = tv_list_item_alloc();

  copy_tv(tv, &ni->li_tv);
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

/// Append VimL value to the end of list
///
/// @param[out]  l  List to append to.
/// @param[in,out]  tv  Value to append. Is copied (@see copy_tv()) to an
///                     allocated listitem_T.
void tv_list_append_tv(list_T *const l, typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T  *li = tv_list_item_alloc();
  copy_tv(tv, &li->li_tv);
  tv_list_append(l, li);
}

/// Append a list to a list as one item
///
/// @param[out]  l  List to append to.
/// @param[in,out]  itemlist  List to append. Reference count is increased.
void tv_list_append_list(list_T *const list, list_T *const itemlist)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T  *li = tv_list_item_alloc();

  li->li_tv.v_type = VAR_LIST;
  li->li_tv.v_lock = 0;
  li->li_tv.vval.v_list = itemlist;
  tv_list_append(list, li);
  if (itemlist != NULL) {
    itemlist->lv_refcount++;
  }
}

/// Append a dictionary to a list
///
/// @param[out]  l  List to append to.
/// @param[in,out]  dict  Dictionary to append. Reference count is increased.
void tv_list_append_dict(list_T *const list, dict_T *const dict)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T  *li = tv_list_item_alloc();

  li->li_tv.v_type = VAR_DICT;
  li->li_tv.v_lock = 0;
  li->li_tv.vval.v_dict = dict;
  tv_list_append(list, li);
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
void tv_list_append_string(list_T *const l, const char *const str,
                           const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (str == NULL) {
    assert(len == 0 || len == -1);
    tv_list_append_allocated_string(l, NULL);
  } else {
    tv_list_append_allocated_string(l, (len >= 0
                                        ? xmemdupz(str, (size_t)len)
                                        : xstrdup(str)));
  }
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
  listitem_T *const li = tv_list_item_alloc();

  tv_list_append(l, li);
  li->li_tv.v_type = VAR_STRING;
  li->li_tv.v_lock = VAR_UNLOCKED;
  li->li_tv.vval.v_string = (char_u *)str;
}

/// Append number to the list
///
/// @param[out]  l  List to append to.
/// @param[in]  n  Number to append. Will be recorded in the allocated
///                listitem_T.
void tv_list_append_number(list_T *const l, const varnumber_T n)
{
  listitem_T *const li = tv_list_item_alloc();
  li->li_tv.v_type = VAR_NUMBER;
  li->li_tv.v_lock = VAR_UNLOCKED;
  li->li_tv.vval.v_number = n;
  tv_list_append(l, li);
}

//{{{3 Operations on the whole list

/// Make a copy of list
///
/// @param[in]  conv  If non-NULL, then all internal strings will be converted.
/// @param[in]  orig  Original list to copy.
/// @param[in]  deep  If false, then shallow copy will be done.
/// @param[in]  copyID  See var_item_copy().
///
/// @return Copied list. May be NULL in case original list is NULL or some
///         failure happens. The refcount of the new list is set to 1.
list_T *tv_list_copy(const vimconv_T *const conv, list_T *const orig,
                     const bool deep, const int copyID)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (orig == NULL) {
    return NULL;
  }

  list_T *copy = tv_list_alloc();
  if (copyID != 0) {
    // Do this before adding the items, because one of the items may
    // refer back to this list.
    orig->lv_copyID = copyID;
    orig->lv_copylist = copy;
  }
  listitem_T *item;
  for (item = orig->lv_first; item != NULL && !got_int;
       item = item->li_next) {
    listitem_T *const ni = tv_list_item_alloc();
    if (deep) {
      if (var_item_copy(conv, &item->li_tv, &ni->li_tv, deep, copyID) == FAIL) {
        xfree(ni);
        break;
      }
    } else {
      copy_tv(&item->li_tv, &ni->li_tv);
    }
    tv_list_append(copy, ni);
  }
  copy->lv_refcount++;
  if (item != NULL) {
    tv_list_unref(copy);
    copy = NULL;
  }

  return copy;
}

/// Extend first list with the second
///
/// @param[out]  l1  List to extend.
/// @param[in]  l2  List to extend with.
/// @param[in]  bef  If not NULL, extends before this item.
void tv_list_extend(list_T *const l1, list_T *const l2,
                    listitem_T *const bef)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  int todo = l2->lv_len;
  // We also quit the loop when we have inserted the original item count of
  // the list, avoid a hang when we extend a list with itself.
  for (listitem_T  *item = l2->lv_first
       ; item != NULL && --todo >= 0
       ; item = item->li_next) {
    tv_list_insert_tv(l1, &item->li_tv, bef);
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
  list_T      *l;

  if (l1 == NULL || l2 == NULL) {
    return FAIL;
  }

  // make a copy of the first list.
  l = tv_list_copy(NULL, l1, false, 0);
  if (l == NULL) {
    return FAIL;
  }
  tv->v_type = VAR_LIST;
  tv->vval.v_list = l;

  // append all items from the second list
  tv_list_extend(l, l2, NULL);
  return OK;
}

typedef struct {
  char_u *s;
  char_u *tofree;
} Join;

/// Join list into a string, helper function
///
/// @param[out]  gap  Garray where result will be saved.
/// @param[in]  l  List to join.
/// @param[in]  sep  Used separator.
/// @param[in]  join_gap  Garray to keep each list item string.
///
/// @return OK in case of success, FAIL otherwise.
static int list_join_inner(garray_T *const gap, list_T *const l,
                           const char *const sep, garray_T *const join_gap)
  FUNC_ATTR_NONNULL_ALL
{
  int sumlen = 0;
  bool first = true;
  listitem_T  *item;

  /* Stringify each item in the list. */
  for (item = l->lv_first; item != NULL && !got_int; item = item->li_next) {
    char *s;
    size_t len;
    s = encode_tv2echo(&item->li_tv, &len);
    if (s == NULL) {
      return FAIL;
    }

    sumlen += (int) len;

    Join *const p = GA_APPEND_VIA_PTR(Join, join_gap);
    p->tofree = p->s = (char_u *) s;

    line_breakcheck();
  }

  /* Allocate result buffer with its total size, avoid re-allocation and
   * multiple copy operations.  Add 2 for a tailing ']' and NUL. */
  if (join_gap->ga_len >= 2)
    sumlen += (int)STRLEN(sep) * (join_gap->ga_len - 1);
  ga_grow(gap, sumlen + 2);

  for (int i = 0; i < join_gap->ga_len && !got_int; ++i) {
    if (first) {
      first = false;
    } else {
      ga_concat(gap, (const char_u *) sep);
    }
    const Join *const p = ((const Join *)join_gap->ga_data) + i;

    if (p->s != NULL)
      ga_concat(gap, p->s);
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
  FUNC_ATTR_NONNULL_ALL
{
  if (l->lv_len < 1) {
    return OK;
  }

  garray_T join_ga;
  int retval;

  ga_init(&join_ga, (int)sizeof(Join), l->lv_len);
  retval = list_join_inner(gap, l, sep, &join_ga);

#define FREE_JOIN_TOFREE(join) xfree((join)->tofree)
  GA_DEEP_CLEAR(&join_ga, Join, FREE_JOIN_TOFREE);
#undef FREE_JOIN_TOFREE

  return retval;
}

/// Chech whether two lists are equal
///
/// @param[in]  l1  First list to compare.
/// @param[in]  l2  Second list to compare.
/// @param[in]  ic  True if case is to be ignored.
/// @param[in]  recursive  True when used recursively.
bool tv_list_equal(list_T *const l1, list_T *const l2, const bool ic,
                const bool recursive)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (l1 == NULL || l2 == NULL) {
    // FIXME? compare empty list with NULL list equal
    return false;
  }
  if (l1 == l2) {
    return true;
  }
  if (tv_list_len(l1) != tv_list_len(l2)) {
    return false;
  }

  listitem_T *item1 = l1->lv_first;
  listitem_T *item2 = l2->lv_first;
  for (; item1 != NULL && item2 != NULL
       ; item1 = item1->li_next, item2 = item2->li_next) {
    if (!tv_equal(&item1->li_tv, &item2->li_tv, ic, recursive)) {
      return false;
    }
  }
  assert(item1 == NULL && item2 == NULL);
  return true;
}

//{{{3 Indexing/searching

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

  // Negative index is relative to the end.
  if (n < 0) {
    n = l->lv_len + n;
  }

  // Check for index out of range.
  if (n < 0 || n >= l->lv_len) {
    return NULL;
  }

  int idx;
  listitem_T  *item;

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
varnumber_T tv_list_find_nr(list_T *const l, const int n, bool *ret_error)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  listitem_T  *li;

  li = tv_list_find(l, n);
  if (li == NULL) {
    if (ret_error != NULL) {
      *ret_error = true;
    }
    return -1;
  }
  return get_tv_number_chk(&li->li_tv, ret_error);
}

/// Get list item l[n - 1] as a string
///
/// @param[in]  l  List to index.
/// @param[in]  n  Index in a list.
///
/// @return [allocated] Copy of the list item string value.
char *tv_list_find_str(list_T *l, int n)
  FUNC_ATTR_MALLOC
{
  listitem_T  *li;

  li = tv_list_find(l, n - 1);
  if (li == NULL) {
    EMSGN(_(e_listidx), n);
    return NULL;
  }
  return (char *)get_tv_string(&li->li_tv);
}

/// Locate item in a list and return its index
///
/// @param[in]  l  List to search.
/// @param[in]  item  Item to search for.
///
/// @return Index of an item or -1 if item is not in the list.
long tv_list_idx_of_item(const list_T *const l, const listitem_T *const item)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (l == NULL) {
    return -1;
  }
  long idx = 0;
  listitem_T *li;
  for (li = l->lv_first; li != NULL && li != item; li = li->li_next) {
    idx++;
  }
  if (li == NULL) {
    return -1;
  }
  return idx;
}
//{{{1 Generic typval operations
//{{{2 Init/alloc/clear
//{{{3 Alloc

/// Allocate an empty list for a return value
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where list is saved.
///
/// @return [allocated] pointer to the created list.
list_T *tv_list_alloc_ret(typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC
{
  list_T *const l = tv_list_alloc();
  ret_tv->vval.v_list = l;
  ret_tv->v_type = VAR_LIST;
  l->lv_refcount++;
  return l;
}

//{{{3 Clear
#define TYPVAL_ENCODE_ALLOW_SPECIALS false

#define TYPVAL_ENCODE_CONV_NIL() \
    do { \
      tv->vval.v_special = kSpecialVarFalse; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_BOOL(ignored) \
    TYPVAL_ENCODE_CONV_NIL()

#define TYPVAL_ENCODE_CONV_NUMBER(ignored) \
    do { \
      (void)ignored; \
      tv->vval.v_number = 0; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(ignored) \
    assert(false)

#define TYPVAL_ENCODE_CONV_FLOAT(ignored) \
    do { \
      tv->vval.v_float = 0; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_STRING(str, ignored) \
    do { \
      xfree(str); \
      tv->vval.v_string = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING(ignored1, ignored2)

#define TYPVAL_ENCODE_CONV_EXT_STRING(ignored1, ignored2, ignored3)

#define TYPVAL_ENCODE_CONV_FUNC(fun) \
    do { \
      func_unref(fun); \
      if (fun != (char_u *)tv_empty_string) { \
        xfree(fun); \
      } \
      tv->vval.v_string = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST() \
    do { \
      tv_list_unref(tv->vval.v_list); \
      tv->vval.v_list = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_EMPTY_DICT() \
    do { \
      dict_unref(tv->vval.v_dict); \
      tv->vval.v_dict = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_LIST_START(ignored) \
    do { \
      if (tv->vval.v_list->lv_refcount > 1) { \
        tv->vval.v_list->lv_refcount--; \
        tv->vval.v_list = NULL; \
        tv->v_lock = VAR_UNLOCKED; \
        return OK; \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS()

#define TYPVAL_ENCODE_CONV_LIST_END() \
    do { \
      typval_T *const cur_tv = cur_mpsv->tv; \
      assert(cur_tv->v_type == VAR_LIST); \
      tv_list_unref(cur_tv->vval.v_list); \
      cur_tv->vval.v_list = NULL; \
      cur_tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_DICT_START(ignored) \
    do { \
      if (tv->vval.v_dict->dv_refcount > 1) { \
        tv->vval.v_dict->dv_refcount--; \
        tv->vval.v_dict = NULL; \
        tv->v_lock = VAR_UNLOCKED; \
        return OK; \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK(ignored1, ignored2)

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY()

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS()

#define TYPVAL_ENCODE_CONV_DICT_END() \
    do { \
      typval_T *const cur_tv = cur_mpsv->tv; \
      assert(cur_tv->v_type == VAR_DICT); \
      dict_unref(cur_tv->vval.v_dict); \
      cur_tv->vval.v_dict = NULL; \
      cur_tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_RECURSE(ignored1, ignored2)

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(static, nothing, void *, ignored)

#undef TYPVAL_ENCODE_ALLOW_SPECIALS
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_FUNC
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_RECURSE

/// Free memory for a variable value and set the value to NULL or 0
///
/// @param[in,out]  varp  Value to free.
void tv_clear(typval_T *varp)
{
  if (varp != NULL && varp->v_type != VAR_UNKNOWN) {
    encode_vim_to_nothing(varp, varp, "tv_clear argument");
  }
}
//{{{2 Locks

/// Lock or unlock an item
///
/// @param[out]  tv  Item to (un)lock.
/// @param[in]  deep  Levels to (un)lock, -1 to (un)lock everything.
/// @param[in]  lock  True if it is needed to lock an item, false to unlock.
void tv_item_lock(typval_T *const tv, const int deep, const bool lock)
{
  // TODO(ZyX-I): Make this not recursive
  static int recurse = 0;

  if (recurse >= DICT_MAXNEST) {
    EMSG(_("E743: variable nested too deep for (un)lock"));
    return;
  }
  if (deep == 0) {
    return;
  }
  recurse++;

  // lock/unlock the item itself
#define UN_LOCK(lock, var) \
  do { \
    var = ((VarLockStatus[]) { \
      [VAR_UNLOCKED] = (lock ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_LOCKED] = (lock ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_FIXED] = VAR_FIXED, \
    })[var]; \
  } while (0)
  UN_LOCK(lock, tv->v_lock);

  switch (tv->v_type) {
    case VAR_LIST: {
      list_T *const l = tv->vval.v_list;
      if (l != NULL) {
        UN_LOCK(lock, l->lv_lock);
        if (deep < 0 || deep > 1) {
          // recursive: lock/unlock the items the List contains
          for (listitem_T *li = l->lv_first; li != NULL; li = li->li_next) {
            tv_item_lock(&li->li_tv, deep - 1, lock);
          }
        }
      }
      break;
    }
    case VAR_DICT: {
      dict_T *const d = tv->vval.v_dict;
      if (d != NULL) {
        UN_LOCK(lock, d->dv_lock);
        if (deep < 0 || deep > 1) {
          // recursive: lock/unlock the items the List contains
          int todo = (int)d->dv_hashtab.ht_used;
          for (hashitem_T *hi = d->dv_hashtab.ht_array; todo > 0; hi++) {
            if (!HASHITEM_EMPTY(hi)) {
              todo--;
              tv_item_lock(&HI2DI(hi)->di_tv, deep - 1, lock);
            }
          }
        }
      }
      break;
    }
    case VAR_NUMBER:
    case VAR_FLOAT:
    case VAR_STRING:
    case VAR_FUNC:
    case VAR_SPECIAL: {
      break;
    }
    case VAR_UNKNOWN: {
      assert(false);
    }
  }
#undef UN_LOCK
  recurse--;
}

/// Check whether VimL value is locked itself or refers to a locked container
///
/// @param[in]  tv  Value to check.
///
/// @return True if value is locked, false otherwise.
bool tv_islocked(const typval_T *const tv)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return ((tv->v_lock & VAR_LOCKED)
          || (tv->v_type == VAR_LIST
              && tv->vval.v_list != NULL
              && (tv->vval.v_list->lv_lock & VAR_LOCKED))
          || (tv->v_type == VAR_DICT
              && tv->vval.v_dict != NULL
              && (tv->vval.v_dict->dv_lock & VAR_LOCKED)));
}
