
#include <assert.h>
#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/eval_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"  // for emsg
#include "nvim/strings.h"
#include "nvim/typval.h"
#include "nvim/vim.h"

#include "nvim/charset.h"

// List {{{

/// Allocates an empty header for a list.
/// Caller should take care of the reference count.
list_T *list_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC
{
  list_T *list = xcalloc(1, sizeof(list_T));

  // Prepend the list to the list of lists for garbage collection.
  if (first_list != NULL) {
    first_list->lv_used_prev = list;
  }
  list->lv_used_prev = NULL;
  list->lv_used_next = first_list;
  first_list = list;
  return list;
}

/// Unreferences a list: decrement the reference count and free it when it
/// becomes zero.
void list_unref(list_T *l)
{
  if (l != NULL && --l->lv_refcount <= 0) {
    list_free(l, true);
  }
}

/// Frees a list, including all items it points to.
/// Ignores the reference count.
/// @param l The list to free.
/// @param recurse If true, free lists and dictionaries recursively.
void list_free(list_T *l, int recurse)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T *item;

  // Remove the list from the list of lists for garbage collection.
  if (l->lv_used_prev == NULL) {
    first_list = l->lv_used_next;
  } else {
    l->lv_used_prev->lv_used_next = l->lv_used_next;
  }
  if (l->lv_used_next != NULL) {
    l->lv_used_next->lv_used_prev = l->lv_used_prev;
  }

  for (item = l->lv_first; item != NULL; item = l->lv_first) {
    // Remove the item before deleting it.
    l->lv_first = item->li_next;
    if (recurse || (item->li_tv.v_type != VAR_LIST
                    && item->li_tv.v_type != VAR_DICT)) {
      clear_tv(&item->li_tv);
    }
    xfree(item);
  }
  xfree(l);
}

/// Allocate a list item.
listitem_T *listitem_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC
{
  return xmalloc(sizeof(listitem_T));
}

/// Frees a list item.  Also clears the value.  Does not notify watchers.
void listitem_free(listitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  clear_tv(&item->li_tv);
  xfree(item);
}

/// Removes a list item from a List and free it.  Also clears the value.
void listitem_remove(list_T *l, listitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  vim_list_remove(l, item, item);
  listitem_free(item);
}

/// Returns the number of items in a list.
long list_len(list_T *l)
  FUNC_ATTR_NONNULL_ALL
{
  return l ? l->lv_len : 0L;
}

/// Returns true when two lists have exactly the same values.
/// @param l1 the first list
/// @param l2 the second list
/// @param ic ignore case for strings
/// @param recursive true when used recursively
bool list_equal(list_T *l1, list_T *l2, bool ic, bool recursive)
{
  listitem_T  *item1, *item2;

  if (l1 == NULL || l2 == NULL) {
    return false;
  }
  if (l1 == l2) {
    return true;
  }
  if (list_len(l1) != list_len(l2)) {
    return false;
  }

  for (item1 = l1->lv_first, item2 = l2->lv_first;
       item1 != NULL && item2 != NULL;
       item1 = item1->li_next, item2 = item2->li_next) {
    if (!tv_equal(&item1->li_tv, &item2->li_tv, ic, recursive)) {
      return false;
    }
  }
  return item1 == NULL && item2 == NULL;
}

/// Returns true when two dictionaries have exactly the same key/values.
/// @param d1 the first list
/// @param d2 the second list
/// @param ic ignore case for strings
/// @param recursive true when used recursively
bool dict_equal(dict_T *d1, dict_T *d2, int ic, int recursive)
{
  hashitem_T  *hi;
  dictitem_T  *item2;
  int todo;

  if (d1 == NULL || d2 == NULL) {
    return false;
  }
  if (d1 == d2) {
    return true;
  }
  if (dict_len(d1) != dict_len(d2)) {
    return false;
  }

  todo = (int)d1->dv_hashtab.ht_used;
  for (hi = d1->dv_hashtab.ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      item2 = dict_find(d2, hi->hi_key, -1);
      if (item2 == NULL) {
        return false;
      }
      if (!tv_equal(&HI2DI(hi)->di_tv, &item2->di_tv, ic, recursive)) {
        return false;
      }
      --todo;
    }
  }
  return true;
}

/// Returns true if "tv1" and "tv2" have the same value.
/// Compares the items just like "==" would compare them, but strings and
/// numbers are different.  Floats and numbers are also different.
/// @param tv1 the first list
/// @param tv2 the second list
/// @param ic ignore case for strings
/// @param recursive true when used recursively
bool tv_equal(typval_T *tv1, typval_T *tv2, bool ic, bool recursive)
  FUNC_ATTR_NONNULL_ALL
{
  static int tv_equal_recurse_limit;

  char_u buf1[NUMBUFLEN], buf2[NUMBUFLEN];
  char_u      *s1, *s2;
  static int recursive_cnt = 0;             /* catch recursive loops */
  int r;

  if (tv1->v_type != tv2->v_type) {
    return false;
  }

  /* Catch lists and dicts that have an endless loop by limiting
   * recursiveness to a limit.  We guess they are equal then.
   * A fixed limit has the problem of still taking an awful long time.
   * Reduce the limit every time running into it. That should work fine for
   * deeply linked structures that are not recursively linked and catch
   * recursiveness quickly. */
  if (!recursive) {
    tv_equal_recurse_limit = 1000;
  }
  if (recursive_cnt >= tv_equal_recurse_limit) {
    --tv_equal_recurse_limit;
    return true;
  }

  switch (tv1->v_type) {
  case VAR_LIST:
    ++recursive_cnt;
    r = list_equal(tv1->vval.v_list, tv2->vval.v_list, ic, true);
    --recursive_cnt;
    return r;

  case VAR_DICT:
    ++recursive_cnt;
    r = dict_equal(tv1->vval.v_dict, tv2->vval.v_dict, ic, true);
    --recursive_cnt;
    return r;

  case VAR_FUNC:
    return tv1->vval.v_string != NULL
           && tv2->vval.v_string != NULL
           && STRCMP(tv1->vval.v_string, tv2->vval.v_string) == 0;

  case VAR_NUMBER:
    return tv1->vval.v_number == tv2->vval.v_number;

  case VAR_FLOAT:
    return tv1->vval.v_float == tv2->vval.v_float;

  case VAR_STRING:
    s1 = get_tv_string_buf(tv1, buf1);
    s2 = get_tv_string_buf(tv2, buf2);
    return (ic ? mb_stricmp(s1, s2) : STRCMP(s1, s2)) == 0;
  }

  EMSG2(_(e_intern2), "tv_equal()");
  return true;
}

/// Locates item with index "n" in list "l" and return it.
/// A negative index is counted from the end; -1 is the last item.
/// Returns NULL when "n" is out of range.
listitem_T *list_find(list_T *l, long n)
{
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

  // When there is a cached index may start search from there.
  listitem_T  *item;
  int idx;
  if (l->lv_idx_item != NULL) {
    if (n < l->lv_idx / 2) {
      // closest to the start of the list
      item = l->lv_first;
      idx = 0;
    } else if (n > (l->lv_idx + l->lv_len) / 2) {
      // closest to the end of the list
      item = l->lv_last;
      idx = l->lv_len - 1;
    } else {
      // closest to the cached index
      item = l->lv_idx_item;
      idx = l->lv_idx;
    }
  } else {
    if (n < l->lv_len / 2) {
      // closest to the start of the list
      item = l->lv_first;
      idx = 0;
    } else {
      // closest to the end of the list
      item = l->lv_last;
      idx = l->lv_len - 1;
    }
  }

  while (n > idx) {
    // search forward
    item = item->li_next;
    ++idx;
  }
  while (n < idx) {
    // search backward
    item = item->li_prev;
    --idx;
  }

  // cache the used index
  l->lv_idx = idx;
  l->lv_idx_item = item;

  return item;
}

/// Gets list item "l[idx]" as a number.
/// @param l the list to search
/// @param idx the index to retrieve
/// @param errorp set to true on error
long list_find_nr(list_T *l, long idx, int *errorp)
{
  listitem_T *li = list_find(l, idx);
  if (li == NULL) {
    if (errorp != NULL)
      *errorp = true;
    return -1L;
  }
  return get_tv_number_chk(&li->li_tv, errorp);
}

/// Gets list item "l[idx - 1]" as a string.  Returns NULL for failure.
char_u *list_find_str(list_T *l, long idx)
{
  listitem_T *li = list_find(l, idx - 1);
  if (li == NULL) {
    EMSGN(_(e_listidx), idx);
    return NULL;
  }
  return get_tv_string(&li->li_tv);
}

/// Locates "item" list "l" and return its index.
/// Returns -1 when "item" is not in the list.
long list_idx_of_item(list_T *l, listitem_T *item)
{
  long idx = 0;
  listitem_T  *li = l ? l->lv_first : NULL;
  for (; li != NULL && li != item; li = li->li_next) {
    ++idx;
  }
  if (li == NULL) {
    return -1;
  }
  return idx;
}

/// Appends item "item" to the end of list "l".
void list_append(list_T *l, listitem_T *item)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (l->lv_last == NULL) {
    /* empty list */
    l->lv_first = item;
    l->lv_last = item;
    item->li_prev = NULL;
  } else {
    l->lv_last->li_next = item;
    item->li_prev = l->lv_last;
    l->lv_last = item;
  }
  ++l->lv_len;
  item->li_next = NULL;
}

/// Appends typval_T "tv" to the end of list "l".
void list_append_tv(list_T *l, typval_T *tv)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T  *li = listitem_alloc();
  copy_tv(tv, &li->li_tv);
  list_append(l, li);
}

/// Adds a list to a list.
void list_append_list(list_T *list, list_T *itemlist)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T  *li = listitem_alloc();

  li->li_tv.v_type = VAR_LIST;
  li->li_tv.v_lock = 0;
  li->li_tv.vval.v_list = itemlist;
  list_append(list, li);
  ++itemlist->lv_refcount;
}

/// Adds a dictionary to a list.  Used by getqflist().
void list_append_dict(list_T *list, dict_T *dict)
  FUNC_ATTR_NONNULL_ALL
{
  listitem_T  *li = listitem_alloc();

  li->li_tv.v_type = VAR_DICT;
  li->li_tv.v_lock = 0;
  li->li_tv.vval.v_dict = dict;
  list_append(list, li);
  ++dict->dv_refcount;
}

/// Makes a copy of "str" and append it as an item to list "l".
/// When "len" >= 0 use "str[len]".
void list_append_string(list_T *l, char_u *str, int len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T *li = listitem_alloc();

  list_append(l, li);
  li->li_tv.v_type = VAR_STRING;
  li->li_tv.v_lock = 0;

  if (str == NULL) {
    li->li_tv.vval.v_string = NULL;
  } else {
    li->li_tv.vval.v_string = (len >= 0) ? vim_strnsave(str, (size_t)len)
                                         : vim_strsave(str);
  }
}

/// Appends "n" to list "l".
void list_append_number(list_T *l, varnumber_T n)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T *li = listitem_alloc();
  li->li_tv.v_type = VAR_NUMBER;
  li->li_tv.v_lock = 0;
  li->li_tv.vval.v_number = n;
  list_append(l, li);
}

/// Inserts typval_T "tv" in list "l" before "item".
/// If "item" is NULL append at the end.
void list_insert_tv(list_T *l, typval_T *tv, listitem_T *item)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listitem_T  *ni = listitem_alloc();

  copy_tv(tv, &ni->li_tv);
  list_insert(l, ni, item);
}

void list_insert(list_T *l, listitem_T *ni, listitem_T *item)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (item == NULL) {
    // Append new item at end of list.
    list_append(l, ni);
  } else {
    // Insert new item before existing item.
    ni->li_prev = item->li_prev;
    ni->li_next = item;
    if (item->li_prev == NULL) {
      l->lv_first = ni;
      ++l->lv_idx;
    } else {
      item->li_prev->li_next = ni;
      l->lv_idx_item = NULL;
    }
    item->li_prev = ni;
    ++l->lv_len;
  }
}

/// Extends "l1" with "l2".
/// If "bef" is NULL append at the end, otherwise insert before this item.
void list_extend(list_T *l1, list_T *l2, listitem_T *bef)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  int todo = l2->lv_len;

  // We also quit the loop when we have inserted the original item count of
  // the list, avoid a hang when we extend a list with itself.
  for (listitem_T *item = l2->lv_first; item != NULL && --todo >= 0;
       item = item->li_next) {
    list_insert_tv(l1, &item->li_tv, bef);
  }
}

/// Concatenates lists "l1" and "l2" into a new list, stored in "tv".
/// Return false on failure to copy.
bool list_concat(list_T *l1, list_T *l2, typval_T *tv)
{
  if (l1 == NULL || l2 == NULL) {
    return false;
  }

  /* make a copy of the first list. */
  list_T *l = list_copy(l1, false, 0);
  if (l == NULL) {
    return false;
  }
  tv->v_type = VAR_LIST;
  tv->vval.v_list = l;

  /* append all items from the second list */
  list_extend(l, l2, NULL);
  return true;
}

/// Makes a copy of list "orig".  Shallow if "deep" is false.
/// The refcount of the new list is set to 1.
/// See item_copy() for "copyID".
/// @returns NULL if orig is NULL or some failure happens.
list_T *list_copy(list_T *orig, bool deep, int copyID)
{
  if (orig == NULL) {
    return NULL;
  }

  list_T *copy = list_alloc();
  if (copyID != 0) {
    /* Do this before adding the items, because one of the items may
     * refer back to this list. */
    orig->lv_copyID = copyID;
    orig->lv_copylist = copy;
  }

  listitem_T *item;
  for (item = orig->lv_first; item != NULL && !got_int;
       item = item->li_next) {
    listitem_T *ni = listitem_alloc();
    if (deep) {
      if (!item_copy(&item->li_tv, &ni->li_tv, deep, copyID)) {
        xfree(ni);
        break;
      }
    } else {
      copy_tv(&item->li_tv, &ni->li_tv);
    }
    list_append(copy, ni);
  }
  ++copy->lv_refcount;
  if (item != NULL) {
    list_unref(copy);
    copy = NULL;
  }

  return copy;
}

/// Remove items "item" to "item2" from list "l".
/// @warning Does not free the listitem or the value!
void vim_list_remove(list_T *l, listitem_T *item, listitem_T *item2)
{
  // notify watchers
  for (listitem_T *ip = item; ip != NULL; ip = ip->li_next) {
    --l->lv_len;
    list_fix_watch(l, ip);
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

/// Adds a watcher to a list.
void list_add_watch(list_T *l, listwatch_T *lw)
  FUNC_ATTR_NONNULL_ARG(1)
{
  lw->lw_next = l->lv_watch;
  l->lv_watch = lw;
}

/*
 * Remove a watcher from a list.
 * No warning when it isn't found...
 */
void list_rem_watch(list_T *l, listwatch_T *lwrem)
  FUNC_ATTR_NONNULL_ARG(1)
{
  listwatch_T *lw, **lwp;

  lwp = &l->lv_watch;
  for (lw = l->lv_watch; lw != NULL; lw = lw->lw_next) {
    if (lw == lwrem) {
      *lwp = lw->lw_next;
      break;
    }
    lwp = &lw->lw_next;
  }
}

/*
 * Just before removing an item from a list: advance watchers to the next
 * item.
 */
void list_fix_watch(list_T *l, listitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  listwatch_T *lw;

  for (lw = l->lv_watch; lw != NULL; lw = lw->lw_next)
    if (lw->lw_item == item)
      lw->lw_item = item->li_next;
}

/// Allocates an empty header for a dictionary.
dict_T *dict_alloc(void) FUNC_ATTR_NONNULL_RET
{
  dict_T *d = xmalloc(sizeof(dict_T));

  // Add the dict to the list of dicts for garbage collection.
  if (first_dict != NULL) {
    first_dict->dv_used_prev = d;
  }
  d->dv_used_next = first_dict;
  d->dv_used_prev = NULL;
  first_dict = d;

  hash_init(&d->dv_hashtab);
  d->dv_lock = 0;
  d->dv_scope = 0;
  d->dv_refcount = 0;
  d->dv_copyID = 0;
  d->internal_refcount = 0;

  return d;
}

// }}}
// Dictionaries {{{

/// Returns the dictitem that an entry in a hashtable points to.
dictitem_T *dict_lookup(hashitem_T *hi)
  FUNC_ATTR_NONNULL_ALL
{
  return HI2DI(hi);
}

/// Initializes dictionary "dict" as a scope and set variable "dict_var" to
/// point to it.
void init_var_dict(dict_T *dict, dictitem_T *dict_var, char scope)
{
  hash_init(&dict->dv_hashtab);
  dict->dv_lock = 0;
  dict->dv_scope = scope;
  dict->dv_refcount = DO_NOT_FREE_CNT;
  dict->dv_copyID = 0;
  dict_var->di_tv.vval.v_dict = dict;
  dict_var->di_tv.v_type = VAR_DICT;
  dict_var->di_tv.v_lock = VAR_FIXED;
  dict_var->di_flags = DI_FLAGS_RO | DI_FLAGS_FIX;
  dict_var->di_key[0] = NUL;
}

/// Unreference a dictionary initialized by init_var_dict().
void unref_var_dict(dict_T *dict)
  FUNC_ATTR_NONNULL_ALL
{
  /* Now the dict needs to be freed if no one else is using it, go back to
   * normal reference counting. */
  dict->dv_refcount -= DO_NOT_FREE_CNT - 1;
  dict_unref(dict);
}



/// Unreferences a Dictionary: decrement the reference count and free it when it
/// becomes zero.
void dict_unref(dict_T *d)
{
  if (d != NULL && --d->dv_refcount <= 0)
    dict_free(d, true);
}

/// Free a Dictionary, including all items it contains.
/// Ignores the reference count.
/// @param d the dictionary to free
/// @param recurse free Lists and Dictionaries recursively
void dict_free(dict_T *d, int recurse)
  FUNC_ATTR_NONNULL_ALL
{
  // Remove the dict from the list of dicts for garbage collection.
  if (d->dv_used_prev == NULL) {
    first_dict = d->dv_used_next;
  } else {
    d->dv_used_prev->dv_used_next = d->dv_used_next;
  }
  if (d->dv_used_next != NULL) {
    d->dv_used_next->dv_used_prev = d->dv_used_prev;
  }

  // Lock the hashtab, we don't want it to resize while freeing items.
  hash_lock(&d->dv_hashtab);
  assert(d->dv_hashtab.ht_locked > 0);
  int todo = (int)d->dv_hashtab.ht_used;
  for (hashitem_T *hi = d->dv_hashtab.ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      /* Remove the item before deleting it, just in case there is
       * something recursive causing trouble. */
      dictitem_T *di = HI2DI(hi);
      hash_remove(&d->dv_hashtab, hi);
      if (recurse || (di->di_tv.v_type != VAR_LIST
                      && di->di_tv.v_type != VAR_DICT))
        clear_tv(&di->di_tv);
      xfree(di);
      --todo;
    }
  }
  hash_clear(&d->dv_hashtab);
  xfree(d);
}

/// Allocate a Dictionary item.
/// The "key" is copied to the new item.
/// @note that the value of the item "di_tv" still needs to be initialized!
dictitem_T *dictitem_alloc(const char_u *key)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di = xmalloc(sizeof(dictitem_T) + STRLEN(key));
#ifndef __clang_analyzer__
  STRCPY(di->di_key, key);
#endif
  di->di_flags = 0;
  return di;
}

/// Makes a copy of a Dictionary item.
dictitem_T *dictitem_copy(const dictitem_T *org)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di = xmalloc(sizeof(dictitem_T) + STRLEN(org->di_key));

  STRCPY(di->di_key, org->di_key);
  di->di_flags = 0;
  copy_tv(&org->di_tv, &di->di_tv);

  return di;
}

/// Removes item "item" from Dictionary "dict" and frees it.
void dictitem_remove(dict_T *dict, dictitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  hashitem_T *hi = hash_find(&dict->dv_hashtab, item->di_key);
  if (HASHITEM_EMPTY(hi)) {
    EMSG2(_(e_intern2), "dictitem_remove()");
  } else {
    hash_remove(&dict->dv_hashtab, hi);
  }
  dictitem_free(item);
}

/// Frees a dict item.  Also clears the value.
void dictitem_free(dictitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  clear_tv(&item->di_tv);
  xfree(item);
}

/// Makes a copy of dict "d".  Shallow if "deep" is false.
/// @post The refcount of the new dict equals 1.
/// @param orig The original dictionary.
/// @param deep Makes a shallow copy if false.
/// @param copyID See @ref item_copy().
/// @returns NULL if orig is NULL or some other failure.
dict_T *dict_copy(dict_T *orig, bool deep, int copyID)
  FUNC_ATTR_MALLOC
{
  if (orig == NULL) {
    return NULL;
  }

  dict_T *copy = dict_alloc();

  if (copyID != 0) {
    orig->dv_copyID = copyID;
    orig->dv_copydict = copy;
  }
  int todo = (int)orig->dv_hashtab.ht_used;
  for (hashitem_T *hi = orig->dv_hashtab.ht_array; todo > 0 && !got_int;
       ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;

      dictitem_T *di = dictitem_alloc(hi->hi_key);
      if (deep) {
        if (!item_copy(&HI2DI(hi)->di_tv, &di->di_tv, deep, copyID)) {
          xfree(di);
          break;
        }
      } else {
        copy_tv(&HI2DI(hi)->di_tv, &di->di_tv);
      }
      if (!dict_add(copy, di)) {
        dictitem_free(di);
        break;
      }
    }
  }

  ++copy->dv_refcount;
  if (todo > 0) {
    dict_unref(copy);
    copy = NULL;
  }

  return copy;
}

/// Adds item "item" to Dictionary "d".
/// @returns false when key already exists.
bool dict_add(dict_T *d, dictitem_T *item)
  FUNC_ATTR_NONNULL_ALL
{
  return hash_add(&d->dv_hashtab, item->di_key);
}

/// Adds a number or string entry to dictionary "d".
/// When "str" is NULL use number "nr", otherwise use "str".
/// @returns false when key already exists.
bool dict_add_nr_str(dict_T *d, char *key, varnumber_T nr, char_u *str)
{
  dictitem_T  *item;

  item = dictitem_alloc((char_u *)key);
  item->di_tv.v_lock = 0;
  if (str == NULL) {
    item->di_tv.v_type = VAR_NUMBER;
    item->di_tv.vval.v_number = nr;
  } else {
    item->di_tv.v_type = VAR_STRING;
    item->di_tv.vval.v_string = vim_strsave(str);
  }
  if (!dict_add(d, item)) {
    dictitem_free(item);
    return false;
  }
  return true;
}

/// Adds a list entry to dictionary "d".
/// @returns false when key already exists.
bool dict_add_list(dict_T *d, char *key, list_T *list)
{
  dictitem_T *item = dictitem_alloc((char_u *)key);

  item->di_tv.v_lock = 0;
  item->di_tv.v_type = VAR_LIST;
  item->di_tv.vval.v_list = list;
  if (!dict_add(d, item)) {
    dictitem_free(item);
    return false;
  }
  ++list->lv_refcount;
  return true;
}

/// Gets the number of items in a Dictionary.
long dict_len(dict_T *d)
{
  return d ? (long)d->dv_hashtab.ht_used : 0L;
}

/// Finds item "key[len]" in Dictionary "d".
/// If "len" is negative use strlen(key).
/// @returns NULL when not found.
dictitem_T *dict_find(dict_T *d, char_u *key, int len)
  FUNC_ATTR_NONNULL_ALL
{
#define AKEYLEN 200
  char_u buf[AKEYLEN];
  char_u      *akey;
  char_u      *tofree = NULL;

  if (len < 0) {
    akey = key;
  } else if (len >= AKEYLEN) {
    tofree = akey = vim_strnsave(key, (size_t)len);
  } else {
    // Avoid a malloc/free by using buf[].
    STRLCPY(buf, key, len + 1);
    akey = buf;
  }

  hashitem_T *hi = hash_find(&d->dv_hashtab, akey);
  xfree(tofree);
  return HASHITEM_EMPTY(hi) ? NULL : HI2DI(hi);
}

/// Gets a string item from a dictionary.
/// When "save" is true allocate memory for it.
/// @returns NULL if the entry doesn't exist.
char_u *get_dict_string(dict_T *d, char_u *key, int save)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di = dict_find(d, key, -1);
  if (di == NULL) {
    return NULL;
  }
  char_u *s = get_tv_string(&di->di_tv);
  if (save) {
    s = vim_strsave(s);
  }
  return s;
}

/// Gets a number item from a dictionary.
/// @returns 0 if the entry doesn't exist.
long get_dict_number(dict_T *d, char_u *key)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di = dict_find(d, key, -1);
  return di ? get_tv_number(&di->di_tv) : 0;
}

// }}}
// typvals {{{

/// Frees the memory for a variable type-value.
void free_tv(typval_T *varp)
{
  if (varp != NULL) {
    switch (varp->v_type) {
    case VAR_FUNC:
      func_unref(varp->vval.v_string);
    /*FALLTHROUGH*/
    case VAR_STRING:
      xfree(varp->vval.v_string);
      break;
    case VAR_LIST:
      list_unref(varp->vval.v_list);
      break;
    case VAR_DICT:
      dict_unref(varp->vval.v_dict);
      break;
    case VAR_NUMBER:
    case VAR_FLOAT:
    case VAR_UNKNOWN:
      break;
    default:
      EMSG2(_(e_intern2), "free_tv()");
      break;
    }
    xfree(varp);
  }
}

/// Frees the memory for a variable value and set the value to NULL or 0.
void clear_tv(typval_T *varp)
{
  if (varp != NULL) {
    switch (varp->v_type) {
    case VAR_FUNC:
      func_unref(varp->vval.v_string);
      if (varp->vval.v_string != empty_string) {
        xfree(varp->vval.v_string);
      }
      varp->vval.v_string = NULL;
      break;
    case VAR_STRING:
      xfree(varp->vval.v_string);
      varp->vval.v_string = NULL;
      break;
    case VAR_LIST:
      list_unref(varp->vval.v_list);
      varp->vval.v_list = NULL;
      break;
    case VAR_DICT:
      dict_unref(varp->vval.v_dict);
      varp->vval.v_dict = NULL;
      break;
    case VAR_NUMBER:
      varp->vval.v_number = 0;
      break;
    case VAR_FLOAT:
      varp->vval.v_float = 0.0;
      break;
    case VAR_UNKNOWN:
      break;
    default:
      EMSG2(_(e_intern2), "clear_tv()");
    }
    varp->v_lock = 0;
  }
}

/// Sets the value of a variable to NULL without freeing items.
void init_tv(typval_T *varp)
{
  if (varp != NULL) {
    memset(varp, 0, sizeof(typval_T));
  }
}

/// Gets the number value of a variable.
/// If it is a String variable, uses vim_str2nr().
/// @returns the number, or 0 for incompatible types
long get_tv_number(typval_T *varp)
  FUNC_ATTR_NONNULL_ALL
{
  int error = false;
  return get_tv_number_chk(varp, &error);  // return 0L on error
}

/// get_tv_number_chk() is similar to get_tv_number(), but informs the
/// caller of incompatible types.
/// @post sets *denote to true if not NULL and the type is incompatible
/// @returns the number represented by `varp`, or `-1` if incompatible and
///          `denote` is `NULL`.
long get_tv_number_chk(typval_T *varp, int *denote)
FUNC_ATTR_NONNULL_ARG(1)
{
  long n = 0L;

  switch (varp->v_type) {
  case VAR_NUMBER:
    return (long)(varp->vval.v_number);
  case VAR_FLOAT:
    EMSG(_("E805: Using a Float as a Number"));
    break;
  case VAR_FUNC:
    EMSG(_("E703: Using a Funcref as a Number"));
    break;
  case VAR_STRING:
    if (varp->vval.v_string != NULL) {
      vim_str2nr(varp->vval.v_string, NULL, NULL,
                 true, true, &n, NULL);
    }
    return n;
  case VAR_LIST:
    EMSG(_("E745: Using a List as a Number"));
    break;
  case VAR_DICT:
    EMSG(_("E728: Using a Dictionary as a Number"));
    break;
  default:
    EMSG2(_(e_intern2), "get_tv_number()");
    break;
  }
  if (denote == NULL) {         // useful for values that must be unsigned
    n = -1;
  } else {
    *denote = true;
  }
  return n;
}

/// Gets the string value of a variable.
/// If it is a Number variable, the number is converted into a string.
/// @warning uses a single, static buffer.  YOU CAN ONLY USE IT ONCE!
/// @returns a non-null string
char_u *get_tv_string(const typval_T *varp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  static char_u mybuf[NUMBUFLEN];
  return get_tv_string_buf(varp, mybuf);
}

/// List get_tv_string(), but uses a given buffer.
/// @returns a non-null string
char_u *get_tv_string_buf(const typval_T *varp, char_u *buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char_u      *res =  get_tv_string_buf_chk(varp, buf);
  return res != NULL ? res : (char_u *)"";
}

/// Like get_tv_string_buf(), but uses a static buffer.
/// @warning YOU CAN ONLY USE IT ONCE!
/// @returns a non-null string
char_u *get_tv_string_chk(const typval_T *varp)
  FUNC_ATTR_NONNULL_ALL
{
  static char_u mybuf[NUMBUFLEN];
  return get_tv_string_buf_chk(varp, mybuf);
}

/// Evaluates `varp` to a string.
/// @returns the string value of `varp` or NULL on error.
char_u *get_tv_string_buf_chk(const typval_T *varp, char_u *buf)
  FUNC_ATTR_NONNULL_ALL
{
  switch (varp->v_type) {
  case VAR_NUMBER:
    sprintf((char *)buf, "%" PRId64, (int64_t)varp->vval.v_number);  // NOLINT
    return buf;
  case VAR_FUNC:
    EMSG(_("E729: using Funcref as a String"));
    break;
  case VAR_LIST:
    EMSG(_("E730: using List as a String"));
    break;
  case VAR_DICT:
    EMSG(_("E731: using Dictionary as a String"));
    break;
  case VAR_FLOAT:
    EMSG(_(e_float_as_string));
    break;
  case VAR_STRING:
    return varp->vval.v_string ? varp->vval.v_string : (char_u *)"";
  default:
    EMSG2(_(e_intern2), "get_tv_string_buf()");
    break;
  }
  return NULL;
}

/// Returns true if typeval "tv" is set to be locked (immutable).
/// Also give an error message, using "name".
bool tv_check_lock(int lock, char_u *name)
{
  if (lock & VAR_LOCKED) {
    EMSG2(_("E741: Value is locked: %s"),
        name == NULL ? (char_u *)_("Unknown") : name);
    return true;
  }
  if (lock & VAR_FIXED) {
    EMSG2(_("E742: Cannot change value of %s"),
        name == NULL ? (char_u *)_("Unknown") : name);
    return true;
  }
  return false;
}

/// Copies the values from typval_T "from" to typval_T "to".
/// When needed allocates string or increases reference count.
/// Does not make a copy of a list or dict but copies the reference!
/// It is OK for "from" and "to" to point to the same item.  This is used to
/// make a copy later.
void copy_tv(const typval_T *from, typval_T *to)
  FUNC_ATTR_NONNULL_ALL
{
  to->v_type = from->v_type;
  to->v_lock = 0;
  switch (from->v_type) {
  case VAR_NUMBER:
    to->vval.v_number = from->vval.v_number;
    break;
  case VAR_FLOAT:
    to->vval.v_float = from->vval.v_float;
    break;
  case VAR_STRING:
  case VAR_FUNC:
    if (from->vval.v_string == NULL) {
      to->vval.v_string = NULL;
    } else {
      to->vval.v_string = vim_strsave(from->vval.v_string);
      if (from->v_type == VAR_FUNC) {
        func_ref(to->vval.v_string);
      }
    }
    break;
  case VAR_LIST:
    if (from->vval.v_list == NULL) {
      to->vval.v_list = NULL;
    } else {
      to->vval.v_list = from->vval.v_list;
      ++to->vval.v_list->lv_refcount;
    }
    break;
  case VAR_DICT:
    if (from->vval.v_dict == NULL) {
      to->vval.v_dict = NULL;
    } else {
      to->vval.v_dict = from->vval.v_dict;
      ++to->vval.v_dict->dv_refcount;
    }
    break;
  default:
    EMSG2(_(e_intern2), "copy_tv()");
    break;
  }
}

/// Makes a copy of an item.
/// Lists and Dictionaries are also copied.  A deep copy if "deep" is set.
/// For deepcopy() "copyID" is zero for a full copy or the ID for when a
/// reference to an already copied list/dict can be used.
/// @returns true if copies successfully
bool item_copy(typval_T *from, typval_T *to, bool deep, int copyID)
  FUNC_ATTR_NONNULL_ALL
{
  static int recurse = 0;
  bool ret = true;

  if (recurse >= DICT_MAXNEST) {
    EMSG(_("E698: variable nested too deep for making a copy"));
    return false;
  }
  ++recurse;

  switch (from->v_type) {
  case VAR_NUMBER:
  case VAR_FLOAT:
  case VAR_STRING:
  case VAR_FUNC:
    copy_tv(from, to);
    break;
  case VAR_LIST:
    to->v_type = VAR_LIST;
    to->v_lock = 0;
    if (from->vval.v_list == NULL) {
      to->vval.v_list = NULL;
    } else if (copyID != 0 && from->vval.v_list->lv_copyID == copyID) {
      // use the copy made earlier
      to->vval.v_list = from->vval.v_list->lv_copylist;
      ++to->vval.v_list->lv_refcount;
    } else {
      to->vval.v_list = list_copy(from->vval.v_list, deep, copyID);
    }
    if (to->vval.v_list == NULL) {
      ret = false;
    }
    break;
  case VAR_DICT:
    to->v_type = VAR_DICT;
    to->v_lock = 0;
    if (from->vval.v_dict == NULL)
      to->vval.v_dict = NULL;
    else if (copyID != 0 && from->vval.v_dict->dv_copyID == copyID) {
      /* use the copy made earlier */
      to->vval.v_dict = from->vval.v_dict->dv_copydict;
      ++to->vval.v_dict->dv_refcount;
    } else {
      to->vval.v_dict = dict_copy(from->vval.v_dict, deep, copyID);
    }
    if (to->vval.v_dict == NULL) {
      ret = false;
    }
    break;
  default:
    EMSG2(_(e_intern2), "item_copy()");
    ret = false;
  }
  --recurse;
  return ret;
}

// }}}
// funcs {{{

/// Frees a function and remove it from the list of functions.
void func_free(ufunc_T *fp)
  FUNC_ATTR_NONNULL_ALL
{
  // clear this function
  ga_clear_strings(&(fp->uf_args));
  ga_clear_strings(&(fp->uf_lines));
  xfree(fp->uf_tml_count);
  xfree(fp->uf_tml_total);
  xfree(fp->uf_tml_self);

  // remove the function from the function hashtable
  hashitem_T *hi = hash_find(&func_hashtab, UF2HIKEY(fp));
  if (HASHITEM_EMPTY(hi)) {
    EMSG2(_(e_intern2), "func_free()");
  } else {
    hash_remove(&func_hashtab, hi);
  }

  xfree(fp);
}

/// Unreferences a Function: decrement the reference count and free it when it
/// becomes zero.  Only for numbered functions.
void func_unref(char_u *name)
{
  if (name != NULL && isdigit(*name)) {
    ufunc_T *fp = find_func(name);
    if (fp == NULL) {
      EMSG2(_(e_intern2), "func_unref()");
    } else {
      user_func_unref(fp);
    }
  }
}

void user_func_unref(ufunc_T *fp)
  FUNC_ATTR_NONNULL_ALL
{
  // Only delete it when it's not being used.  Otherwise it's done
  // when "uf_calls" becomes zero.
  if (--fp->uf_refcount <= 0 && fp->uf_calls == 0) {
    func_free(fp);
  }
}

/// Count a reference to a Function.
void func_ref(char_u *name)
{
  if (name != NULL && isdigit(*name)) {
    ufunc_T *fp = find_func(name);
    if (fp == NULL) {
      EMSG2(_(e_intern2), "func_ref()");
    } else {
      ++fp->uf_refcount;
    }
  }
}

/// Finds a function by name, return pointer to it in ufuncs.
/// @returns NULL for unknown function.
ufunc_T *find_func(char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  hashitem_T *hi = hash_find(&func_hashtab, name);
  return !HASHITEM_EMPTY(hi) ? HI2UF(hi) : NULL;
}

void free_all_functions(void)
{
  // Need to start all over every time, because func_free() may change the
  // hash table.
  while (func_hashtab.ht_used > 0) {
    for (hashitem_T *hi = func_hashtab.ht_array;; ++hi)
      if (!HASHITEM_EMPTY(hi)) {
        func_free(HI2UF(hi));
        break;
      }
  }
}

/// Returns true if "name" looks like a builtin function name: starts with a
/// lower case letter and doesn't contain AUTOLOAD_CHAR.
/// "len" is the length of "name", or -1 for NUL terminated.
bool builtin_function(char_u *name, int len)
  FUNC_ATTR_NONNULL_ALL
{
  if (!ASCII_ISLOWER(name[0])) {
    return false;
  }

  char_u *p = vim_strchr(name, AUTOLOAD_CHAR);
  return p == NULL || (len > 0 && p > name + len);
}

/// Cleans up a list of internal variables.
/// Frees all allocated variables and the value they contain.
/// Clears hashtab "ht", does not free it.
void vars_clear(hashtab_T *ht)
  FUNC_ATTR_NONNULL_ALL
{
  vars_clear_ext(ht, true);
}

/// Like vars_clear(), but only frees the value if "free_val" is true.
void vars_clear_ext(hashtab_T *ht, bool free_val)
  FUNC_ATTR_NONNULL_ALL
{
  hash_lock(ht);
  int todo = (int)ht->ht_used;
  for (hashitem_T *hi = ht->ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;

      /* Free the variable.  Don't remove it from the hashtab,
       * ht_array might change then.  hash_clear() takes care of it
       * later. */
      dictitem_T *v = HI2DI(hi);
      if (free_val) {
        clear_tv(&v->di_tv);
      }
      if ((v->di_flags & DI_FLAGS_FIX) == 0) {
        xfree(v);
      }
    }
  }
  hash_clear(ht);
  ht->ht_used = 0;
}

/// Deletes a variable from hashtab "ht" at item "hi".
/// Clears the variable value and free the dictitem.
void delete_var(hashtab_T *ht, hashitem_T *hi)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *di = HI2DI(hi);
  hash_remove(ht, hi);
  clear_tv(&di->di_tv);
  xfree(di);
}
