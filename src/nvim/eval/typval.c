// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>

#include "nvim/lib/queue.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/gc.h"
#include "nvim/eval/executor.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval_encode.h"
#include "nvim/eval.h"
#include "nvim/types.h"
#include "nvim/assert.h"
#include "nvim/memory.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/pos.h"
#include "nvim/charset.h"
#include "nvim/garray.h"
#include "nvim/gettext.h"
#include "nvim/macros.h"
#include "nvim/mbyte.h"
#include "nvim/message.h"
// TODO(ZyX-I): Move line_breakcheck out of misc1
#include "nvim/misc1.h"  // For line_breakcheck
#include "nvim/os/fileio.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/typval.c.generated.h"
#endif

bool tv_in_free_unref_items = false;

// TODO(ZyX-I): Remove DICT_MAXNEST, make users be non-recursive instead

#define DICT_MAXNEST 100

const char *const tv_empty_string = "";

//{{{1 Lists
//{{{2 List log
#ifdef LOG_LIST_ACTIONS
ListLog *list_log_first = NULL;
ListLog *list_log_last = NULL;

/// Write list log to the given file
///
/// @param[in]  fname  File to write log to. Will be appended to if already
///                    present.
void list_write_log(const char *const fname)
  FUNC_ATTR_NONNULL_ALL
{
  FileDescriptor fp;
  const int fo_ret = file_open(&fp, fname, kFileCreate|kFileAppend, 0600);
  if (fo_ret != 0) {
    emsgf(_("E5142: Failed to open file %s: %s"), fname, os_strerror(fo_ret));
    return;
  }
  for (ListLog *chunk = list_log_first; chunk != NULL;) {
    for (size_t i = 0; i < chunk->size; i++) {
      char buf[10 + 1 + ((16 + 3) * 3) + (8 + 2) + 2];
      //       act  :     hex  " c:"      len "[]" "\n\0"
      const ListLogEntry entry = chunk->entries[i];
      const size_t snp_len = (size_t)snprintf(
          buf, sizeof(buf),
          "%-10.10s: l:%016" PRIxPTR "[%08d] 1:%016" PRIxPTR " 2:%016" PRIxPTR
          "\n",
          entry.action, entry.l, entry.len, entry.li1, entry.li2);
      assert(snp_len + 1 == sizeof(buf));
      const ptrdiff_t fw_ret = file_write(&fp, buf, snp_len);
      if (fw_ret != (ptrdiff_t)snp_len) {
        assert(fw_ret < 0);
        if (i) {
          memmove(chunk->entries, chunk->entries + i,
                  sizeof(chunk->entries[0]) * (chunk->size - i));
          chunk->size -= i;
        }
        emsgf(_("E5143: Failed to write to file %s: %s"),
              fname, os_strerror((int)fw_ret));
        return;
      }
    }
    list_log_first = chunk->next;
    xfree(chunk);
    chunk = list_log_first;
  }
  const int fc_ret = file_close(&fp, true);
  if (fc_ret != 0) {
    emsgf(_("E5144: Failed to close file %s: %s"), fname, os_strerror(fc_ret));
  }
}

#ifdef EXITFREE
/// Free list log
void list_free_log(void)
{
  for (ListLog *chunk = list_log_first; chunk != NULL;) {
    list_log_first = chunk->next;
    xfree(chunk);
    chunk = list_log_first;
  }
}
#endif
#endif
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
///                  becomes accessible from VimL. It is still valid to
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
  list_log(list, NULL, (void *)(uintptr_t)len, "alloc");
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

  memset(sl, 0, sizeof(staticList10_T));
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
  list_log((const list_T *)sl, &sl->sl_items[0], &sl->sl_items[SL_SIZE - 1],
           "s10init");
#undef SL_SIZE
}

/// Initialize static list with undefined number of elements
///
/// @param[out]  l  List to initialize.
void tv_list_init_static(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  memset(l, 0, sizeof(*l));
  l->lv_refcount = DO_NOT_FREE_CNT;
  list_log(l, NULL, NULL, "sinit");
}

/// Free items contained in a list
///
/// @param[in,out]  l  List to clear.
void tv_list_free_contents(list_T *const l)
  FUNC_ATTR_NONNULL_ALL
{
  list_log(l, NULL, NULL, "freecont");
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
  list_log(l, NULL, NULL, "freelist");

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
  if (!tv_in_free_unref_items) {
    tv_list_free_contents(l);
    tv_list_free_list(l);
  }
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
void tv_list_drop_items(list_T *const l, listitem_T *const item,
                        listitem_T *const item2)
  FUNC_ATTR_NONNULL_ALL
{
  list_log(l, item, item2, "drop");
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
  list_log(l, l->lv_first, l->lv_last, "afterdrop");
}

/// Like tv_list_drop_items, but also frees all removed items
void tv_list_remove_items(list_T *const l, listitem_T *const item,
                          listitem_T *const item2)
  FUNC_ATTR_NONNULL_ALL
{
  list_log(l, item, item2, "remove");
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
void tv_list_move_items(list_T *const l, listitem_T *const item,
                        listitem_T *const item2, list_T *const tgt_l,
                        const int cnt)
  FUNC_ATTR_NONNULL_ALL
{
  list_log(l, item, item2, "move");
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
  list_log(tgt_l, tgt_l->lv_first, tgt_l->lv_last, "movetgt");
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
    list_log(l, ni, item, "insert");
  }
}

/// Insert VimL value into a list
///
/// @param[out]  l  List to insert to.
/// @param[in,out]  tv  Value to insert. Is copied (@see tv_copy()) to an
///                     allocated listitem_T and inserted.
/// @param[in]  item  Item to insert before. If NULL, inserts at the end of the
///                   list.
void tv_list_insert_tv(list_T *const l, typval_T *const tv,
                       listitem_T *const item)
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
  list_log(l, item, NULL, "append");
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
void tv_list_append_string(list_T *const l, const char *const str,
                           const ssize_t len)
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
    .vval.v_string = (char_u *)str,
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
list_T *tv_list_copy(const vimconv_T *const conv, list_T *const orig,
                     const bool deep, const int copyID)
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

/// Extend first list with the second
///
/// @param[out]  l1  List to extend.
/// @param[in]  l2  List to extend with.
/// @param[in]  bef  If not NULL, extends before this item.
void tv_list_extend(list_T *const l1, list_T *const l2,
                    listitem_T *const bef)
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
    p->tofree = p->s = (char_u *)s;

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
      ga_concat(gap, (const char_u *)sep);
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

/// Chech whether two lists are equal
///
/// @param[in]  l1  First list to compare.
/// @param[in]  l2  Second list to compare.
/// @param[in]  ic  True if case is to be ignored.
/// @param[in]  recursive  True when used recursively.
///
/// @return True if lists are equal, false otherwise.
bool tv_list_equal(list_T *const l1, list_T *const l2, const bool ic,
                   const bool recursive)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (l1 == l2) {
    return true;
  }
  if (l1 == NULL || l2 == NULL) {
    return false;
  }
  if (tv_list_len(l1) != tv_list_len(l2)) {
    return false;
  }

  listitem_T *item1 = tv_list_first(l1);
  listitem_T *item2 = tv_list_first(l2);
  for (; item1 != NULL && item2 != NULL
       ; (item1 = TV_LIST_ITEM_NEXT(l1, item1),
          item2 = TV_LIST_ITEM_NEXT(l2, item2))) {
    if (!tv_equal(TV_LIST_ITEM_TV(item1), TV_LIST_ITEM_TV(item2), ic,
                  recursive)) {
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
  list_log(l, NULL, NULL, "reverse");
#define SWAP(a, b) \
  do { \
    tmp = a; \
    a = b; \
    b = tmp; \
  } while (0)
  listitem_T *tmp;

  SWAP(l->lv_first, l->lv_last);
  for (listitem_T *li = l->lv_first; li != NULL; li = li->li_next) {
    SWAP(li->li_next, li->li_prev);
  }
#undef SWAP

  l->lv_idx = l->lv_len - l->lv_idx - 1;
}

// FIXME Add unit tests for tv_list_item_sort().

/// Sort list using libc qsort
///
/// @param[in,out]  l  List to sort, will be sorted in-place.
/// @param  ptrs  Preallocated array of items to sort, must have at least
///               tv_list_len(l) entries. Should not be initialized.
/// @param[in]  item_compare_func  Function used to compare list items.
/// @param  errp  Location where information about whether error occurred is
///               saved by item_compare_func. If boolean there appears to be
///               true list will not be modified. Must be initialized to false
///               by the caller.
void tv_list_item_sort(list_T *const l, ListSortItem *const ptrs,
                       const ListSorter item_compare_func,
                       bool *errp)
  FUNC_ATTR_NONNULL_ARG(3, 4)
{
  const int len = tv_list_len(l);
  if (len <= 1) {
    return;
  }
  list_log(l, NULL, NULL, "sort");
  int i = 0;
  TV_LIST_ITER(l, li, {
    ptrs[i].item = li;
    ptrs[i].idx = i;
    i++;
  });
  // Sort the array with item pointers.
  qsort(ptrs, (size_t)len, sizeof(ListSortItem), item_compare_func);
  if (!(*errp)) {
    // Clear the list and append the items in the sorted order.
    l->lv_first    = NULL;
    l->lv_last     = NULL;
    l->lv_idx_item = NULL;
    l->lv_len      = 0;
    for (i = 0; i < len; i++) {
      tv_list_append(l, ptrs[i].item);
    }
  }
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
  list_log(l, l->lv_idx_item, (void *)(uintptr_t)l->lv_idx, "find");

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
    EMSG2(_(e_listidx), (int64_t)n);
    return NULL;
  }
  return tv_get_string(TV_LIST_ITEM_TV(li));
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
    case kCallbackFuncref: {
      return STRCMP(cb1->data.funcref, cb2->data.funcref) == 0;
    }
    case kCallbackPartial: {
      // FIXME: this is inconsistent with tv_equal but is needed for precision
      // maybe change dictwatcheradd to return a watcher id instead?
      return cb1->data.partial == cb2->data.partial;
    }
    case kCallbackNone: {
      return true;
    }
  }
  abort();
  return false;
}

/// Unref/free callback
void callback_free(Callback *callback)
  FUNC_ATTR_NONNULL_ALL
{
  switch (callback->type) {
    case kCallbackFuncref: {
      func_unref(callback->data.funcref);
      xfree(callback->data.funcref);
      break;
    }
    case kCallbackPartial: {
      partial_unref(callback->data.partial);
      break;
    }
    case kCallbackNone: {
      break;
    }
  }
  callback->type = kCallbackNone;
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
                            const size_t key_pattern_len,
                            Callback callback)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (dict == NULL) {
    return false;
  }

  QUEUE *w = NULL;
  DictWatcher *watcher = NULL;
  bool matched = false;
  QUEUE_FOREACH(w, &dict->watchers) {
    watcher = tv_dict_watcher_node_data(w);
    if (tv_callback_equal(&watcher->callback, &callback)
        && watcher->key_pattern_len == key_pattern_len
        && memcmp(watcher->key_pattern, key_pattern, key_pattern_len) == 0) {
      matched = true;
      break;
    }
  }

  if (!matched) {
    return false;
  }

  QUEUE_REMOVE(w);
  tv_dict_watcher_free(watcher);
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
  } else {
    return strcmp(key, watcher->key_pattern) == 0;
  }
}

/// Send a change notification to all dictionary watchers that match given key
///
/// @param[in]  dict  Dictionary which was modified.
/// @param[in]  key  Key which was modified.
/// @param[in]  newtv  New key value.
/// @param[in]  oldtv  Old key value.
void tv_dict_watcher_notify(dict_T *const dict, const char *const key,
                            typval_T *const newtv, typval_T *const oldtv)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  typval_T argv[3];

  argv[0].v_type = VAR_DICT;
  argv[0].v_lock = VAR_UNLOCKED;
  argv[0].vval.v_dict = dict;
  argv[1].v_type = VAR_STRING;
  argv[1].v_lock = VAR_UNLOCKED;
  argv[1].vval.v_string = (char_u *)xstrdup(key);
  argv[2].v_type = VAR_DICT;
  argv[2].v_lock = VAR_UNLOCKED;
  argv[2].vval.v_dict = tv_dict_alloc();
  argv[2].vval.v_dict->dv_refcount++;

  if (newtv) {
    dictitem_T *const v = tv_dict_item_alloc_len(S_LEN("new"));
    tv_copy(newtv, &v->di_tv);
    tv_dict_add(argv[2].vval.v_dict, v);
  }

  if (oldtv) {
    dictitem_T *const v = tv_dict_item_alloc_len(S_LEN("old"));
    tv_copy(oldtv, &v->di_tv);
    tv_dict_add(argv[2].vval.v_dict, v);
  }

  typval_T rettv;

  QUEUE *w;
  QUEUE_FOREACH(w, &dict->watchers) {
    DictWatcher *watcher = tv_dict_watcher_node_data(w);
    if (!watcher->busy && tv_dict_watcher_matches(watcher, key)) {
      rettv = TV_INITIAL_VALUE;
      watcher->busy = true;
      callback_call(&watcher->callback, 3, argv, &rettv);
      watcher->busy = false;
      tv_clear(&rettv);
    }
  }

  for (size_t i = 1; i < ARRAY_SIZE(argv); i++) {
    tv_clear(argv + i);
  }
}

//{{{2 Dictionary item

/// Allocate a dictionary item
///
/// @note that the value of the item (->di_tv) still needs to be initialized.
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
  return di;
}

/// Allocate a dictionary item
///
/// @note that the value of the item (->di_tv) still needs to be initialized.
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
static dictitem_T *tv_dict_item_copy(dictitem_T *const di)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  dictitem_T *const new_di = tv_dict_item_alloc((const char *)di->di_key);
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
    emsgf(_(e_intern2), "tv_dict_item_remove()");
  } else {
    hash_remove(&dict->dv_hashtab, hi);
  }
  tv_dict_item_free(item);
}

//{{{2 Alloc/free

/// Allocate an empty dictionary
///
/// @return [allocated] new dictionary.
dict_T *tv_dict_alloc(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  dict_T *const d = xmalloc(sizeof(dict_T));

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
  if (!tv_in_free_unref_items) {
    tv_dict_free_contents(d);
    tv_dict_free_dict(d);
  }
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
dictitem_T *tv_dict_find(const dict_T *const d, const char *const key,
                         const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (d == NULL) {
    return NULL;
  }
  hashitem_T *const hi = (len < 0
                          ? hash_find(&d->dv_hashtab, (const char_u *)key)
                          : hash_find_len(&d->dv_hashtab, key, (size_t)len));
  if (HASHITEM_EMPTY(hi)) {
    return NULL;
  }
  return TV_DICT_HI2DI(hi);
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
  dictitem_T *const di = tv_dict_find(d, key, -1);
  if (di == NULL) {
    return 0;
  }
  return tv_get_number(&di->di_tv);
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
char *tv_dict_get_string(const dict_T *const d, const char *const key,
                         const bool save)
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
const char *tv_dict_get_string_buf(const dict_T *const d, const char *const key,
                                   char *const numbuf)
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
const char *tv_dict_get_string_buf_chk(const dict_T *const d,
                                       const char *const key,
                                       const ptrdiff_t key_len,
                                       char *const numbuf,
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
bool tv_dict_get_callback(dict_T *const d,
                          const char *const key, const ptrdiff_t key_len,
                          Callback *const result)
  FUNC_ATTR_NONNULL_ARG(2, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  result->type = kCallbackNone;

  dictitem_T *const di = tv_dict_find(d, key, key_len);

  if (di == NULL) {
    return true;
  }

  if (!tv_is_func(di->di_tv) && di->di_tv.v_type != VAR_STRING) {
    EMSG(_("E6000: Argument is not a function or function name"));
    return false;
  }

  typval_T tv;
  tv_copy(&di->di_tv, &tv);
  set_selfdict(&tv, d);
  const bool res = callback_from_typval(result, &tv);
  tv_clear(&tv);
  return res;
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
int tv_dict_add_list(dict_T *const d, const char *const key,
                     const size_t key_len, list_T *const list)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_lock = VAR_UNLOCKED;
  item->di_tv.v_type = VAR_LIST;
  item->di_tv.vval.v_list = list;
  tv_list_ref(list);
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
int tv_dict_add_dict(dict_T *const d, const char *const key,
                     const size_t key_len, dict_T *const dict)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_lock = VAR_UNLOCKED;
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
int tv_dict_add_nr(dict_T *const d, const char *const key,
                   const size_t key_len, const varnumber_T nr)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_lock = VAR_UNLOCKED;
  item->di_tv.v_type = VAR_NUMBER;
  item->di_tv.vval.v_number = nr;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a special entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  val SpecialVarValue to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_special(dict_T *const d, const char *const key,
                        const size_t key_len, SpecialVarValue val)
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_lock = VAR_UNLOCKED;
  item->di_tv.v_type = VAR_SPECIAL;
  item->di_tv.vval.v_special = val;
  if (tv_dict_add(d, item) == FAIL) {
    tv_dict_item_free(item);
    return FAIL;
  }
  return OK;
}

/// Add a string entry to dictionary
///
/// @param[out]  d  Dictionary to add entry to.
/// @param[in]  key  Key to add.
/// @param[in]  key_len  Key length.
/// @param[in]  val  String to add.
///
/// @return OK in case of success, FAIL when key already exists.
int tv_dict_add_str(dict_T *const d,
                    const char *const key, const size_t key_len,
                    const char *const val)
  FUNC_ATTR_NONNULL_ALL
{
  return tv_dict_add_allocated_str(d, key, key_len, xstrdup(val));
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
int tv_dict_add_allocated_str(dict_T *const d,
                              const char *const key, const size_t key_len,
                              char *const val)
  FUNC_ATTR_NONNULL_ALL
{
  dictitem_T *const item = tv_dict_item_alloc_len(key, key_len);

  item->di_tv.v_lock = VAR_UNLOCKED;
  item->di_tv.v_type = VAR_STRING;
  item->di_tv.vval.v_string = (char_u *)val;
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
/// @param[in]  action  "error", "force", "keep":
///
///                     e*, including "error": duplicate key gives an error.
///                     f*, including "force": duplicate d2 keys override d1.
///                     other, including "keep": duplicate d2 keys ignored.
void tv_dict_extend(dict_T *const d1, dict_T *const d2,
                    const char *const action)
  FUNC_ATTR_NONNULL_ALL
{
  const bool watched = tv_dict_is_watched(d1);
  const char *const arg_errmsg = _("extend() argument");
  const size_t arg_errmsg_len = strlen(arg_errmsg);

  TV_DICT_ITER(d2, di2, {
    dictitem_T *const di1 = tv_dict_find(d1, (const char *)di2->di_key, -1);
    if (d1->dv_scope != VAR_NO_SCOPE) {
      // Disallow replacing a builtin function in l: and g:.
      // Check the key to be valid when adding to any scope.
      if (d1->dv_scope == VAR_DEF_SCOPE
          && tv_is_func(di2->di_tv)
          && !var_check_func_name((const char *)di2->di_key, di1 == NULL)) {
        break;
      }
      if (!valid_varname((const char *)di2->di_key)) {
        break;
      }
    }
    if (di1 == NULL) {
      dictitem_T *const new_di = tv_dict_item_copy(di2);
      if (tv_dict_add(d1, new_di) == FAIL) {
        tv_dict_item_free(new_di);
      } else if (watched) {
        tv_dict_watcher_notify(d1, (const char *)new_di->di_key, &new_di->di_tv,
                               NULL);
      }
    } else if (*action == 'e') {
      emsgf(_("E737: Key already exists: %s"), di2->di_key);
      break;
    } else if (*action == 'f' && di2 != di1) {
      typval_T oldtv;

      if (tv_check_lock(di1->di_tv.v_lock, arg_errmsg, arg_errmsg_len)
          || var_check_ro(di1->di_flags, arg_errmsg, arg_errmsg_len)) {
        break;
      }

      if (watched) {
        tv_copy(&di1->di_tv, &oldtv);
      }

      tv_clear(&di1->di_tv);
      tv_copy(&di2->di_tv, &di1->di_tv);

      if (watched) {
        tv_dict_watcher_notify(d1, (const char *)di1->di_key, &di1->di_tv,
                               &oldtv);
        tv_clear(&oldtv);
      }
    }
  });
}

/// Compare two dictionaries
///
/// @param[in]  d1  First dictionary.
/// @param[in]  d2  Second dictionary.
/// @param[in]  ic  True if case is to be ignored.
/// @param[in]  recursive  True when used recursively.
bool tv_dict_equal(dict_T *const d1, dict_T *const d2,
                   const bool ic, const bool recursive)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (d1 == d2) {
    return true;
  }
  if (d1 == NULL || d2 == NULL) {
    return false;
  }
  if (tv_dict_len(d1) != tv_dict_len(d2)) {
    return false;
  }

  TV_DICT_ITER(d1, di1, {
    dictitem_T *const di2 = tv_dict_find(d2, (const char *)di1->di_key, -1);
    if (di2 == NULL) {
      return false;
    }
    if (!tv_equal(&di1->di_tv, &di2->di_tv, ic, recursive)) {
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
dict_T *tv_dict_copy(const vimconv_T *const conv,
                     dict_T *const orig,
                     const bool deep,
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
      new_di = tv_dict_item_alloc((const char *)di->di_key);
    } else {
      size_t len = STRLEN(di->di_key);
      char *const key = (char *)string_convert(conv, di->di_key, &len);
      if (key == NULL) {
        new_di = tv_dict_item_alloc_len((const char *)di->di_key, len);
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

//{{{1 Generic typval operations
//{{{2 Init/alloc/clear
//{{{3 Alloc

/// Allocate an empty list for a return value
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where list is saved.
/// @param[in]  len  Expected number of items to be populated before list
///                  becomes accessible from VimL. It is still valid to
///                  underpopulate a list, value only controls how many elements
///                  will be allocated in advance. @see ListLenSpecials.
///
/// @return [allocated] pointer to the created list.
list_T *tv_list_alloc_ret(typval_T *const ret_tv, const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ALL
{
  list_T *const l = tv_list_alloc(len);
  tv_list_set_ret(ret_tv, l);
  ret_tv->v_lock = VAR_UNLOCKED;
  return l;
}

/// Allocate an empty dictionary for a return value
///
/// Also sets reference count.
///
/// @param[out]  ret_tv  Structure where dictionary is saved.
void tv_dict_alloc_ret(typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  dict_T *const d = tv_dict_alloc();
  tv_dict_set_ret(ret_tv, d);
  ret_tv->v_lock = VAR_UNLOCKED;
}

//{{{3 Clear
#define TYPVAL_ENCODE_ALLOW_SPECIALS false

#define TYPVAL_ENCODE_CONV_NIL(tv) \
    do { \
      tv->vval.v_special = kSpecialVarFalse; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_BOOL(tv, num) \
    TYPVAL_ENCODE_CONV_NIL(tv)

#define TYPVAL_ENCODE_CONV_NUMBER(tv, num) \
    do { \
      (void)num; \
      tv->vval.v_number = 0; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(tv, num)

#define TYPVAL_ENCODE_CONV_FLOAT(tv, flt) \
    do { \
      tv->vval.v_float = 0; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_STRING(tv, buf, len) \
    do { \
      xfree(buf); \
      tv->vval.v_string = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING(tv, buf, len)

#define TYPVAL_ENCODE_CONV_EXT_STRING(tv, buf, len, type)

static inline int _nothing_conv_func_start(typval_T *const tv,
                                           char_u *const fun)
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
    if ((const char *)fun != tv_empty_string) {
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
      tv_list_unref(tv->vval.v_list); \
      tv->vval.v_list = NULL; \
      tv->v_lock = VAR_UNLOCKED; \
    } while (0)

static inline void _nothing_conv_empty_dict(typval_T *const tv,
                                            dict_T **const dictp)
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
      assert((void *)&dict != (void *)&TYPVAL_ENCODE_NODICT_VAR); \
      _nothing_conv_empty_dict(tv, ((dict_T **)&dict)); \
    } while (0)

static inline int _nothing_conv_real_list_after_start(
    typval_T *const tv, MPConvStackVal *const mpsv)
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
      if (_nothing_conv_real_list_after_start(tv, &mpsv) != NOTDONE) { \
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

static inline int _nothing_conv_real_dict_after_start(
    typval_T *const tv, dict_T **const dictp, const void *const nodictvar,
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
      if (_nothing_conv_real_dict_after_start( \
          tv, (dict_T **)&dict, (void *)&TYPVAL_ENCODE_NODICT_VAR, \
          &mpsv) != NOTDONE) { \
        goto typval_encode_stop_converting_one_item; \
      } \
    } while (0)

#define TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK(tv, dict)
#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(tv, dict)
#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict)

static inline void _nothing_conv_dict_end(typval_T *const tv,
                                          dict_T **const dictp,
                                          const void *const nodictvar)
  FUNC_ATTR_ALWAYS_INLINE
{
  if ((const void *)dictp != nodictvar) {
    tv_dict_unref(*dictp);
    *dictp = NULL;
  }
}
#define TYPVAL_ENCODE_CONV_DICT_END(tv, dict) \
    _nothing_conv_dict_end(tv, (dict_T **)&dict, \
                           (void *)&TYPVAL_ENCODE_NODICT_VAR)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type)

#define TYPVAL_ENCODE_SCOPE static
#define TYPVAL_ENCODE_NAME nothing
#define TYPVAL_ENCODE_FIRST_ARG_TYPE const void *const
#define TYPVAL_ENCODE_FIRST_ARG_NAME ignored
#define TYPVAL_ENCODE_TRANSLATE_OBJECT_NAME
#include "nvim/eval/typval_encode.c.h"
#undef TYPVAL_ENCODE_SCOPE
#undef TYPVAL_ENCODE_NAME
#undef TYPVAL_ENCODE_FIRST_ARG_TYPE
#undef TYPVAL_ENCODE_FIRST_ARG_NAME
#undef TYPVAL_ENCODE_TRANSLATE_OBJECT_NAME

#undef TYPVAL_ENCODE_ALLOW_SPECIALS
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
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
  if (tv != NULL && tv->v_type != VAR_UNKNOWN) {
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
}

//{{{3 Free

/// Free allocated VimL object and value stored inside
///
/// @param  tv  Object to free.
void tv_free(typval_T *tv)
{
  if (tv != NULL) {
    switch (tv->v_type) {
      case VAR_PARTIAL: {
        partial_unref(tv->vval.v_partial);
        break;
      }
      case VAR_FUNC: {
        func_unref(tv->vval.v_string);
        FALLTHROUGH;
      }
      case VAR_STRING: {
        xfree(tv->vval.v_string);
        break;
      }
      case VAR_LIST: {
        tv_list_unref(tv->vval.v_list);
        break;
      }
      case VAR_DICT: {
        tv_dict_unref(tv->vval.v_dict);
        break;
      }
      case VAR_SPECIAL:
      case VAR_NUMBER:
      case VAR_FLOAT:
      case VAR_UNKNOWN: {
        break;
      }
    }
    xfree(tv);
  }
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
    case VAR_SPECIAL: {
      break;
    }
    case VAR_STRING:
    case VAR_FUNC: {
      if (from->vval.v_string != NULL) {
        to->vval.v_string = vim_strsave(from->vval.v_string);
        if (from->v_type == VAR_FUNC) {
          func_ref(to->vval.v_string);
        }
      }
      break;
    }
    case VAR_PARTIAL: {
      if (to->vval.v_partial != NULL) {
        to->vval.v_partial->pt_refcount++;
      }
      break;
    }
    case VAR_LIST: {
      tv_list_ref(to->vval.v_list);
      break;
    }
    case VAR_DICT: {
      if (from->vval.v_dict != NULL) {
        to->vval.v_dict->dv_refcount++;
      }
      break;
    }
    case VAR_UNKNOWN: {
      emsgf(_(e_intern2), "tv_copy(UNKNOWN)");
      break;
    }
  }
}

//{{{2 Locks

/// Lock or unlock an item
///
/// @param[out]  tv  Item to (un)lock.
/// @param[in]  deep  Levels to (un)lock, -1 to (un)lock everything.
/// @param[in]  lock  True if it is needed to lock an item, false to unlock.
void tv_item_lock(typval_T *const tv, const int deep, const bool lock)
  FUNC_ATTR_NONNULL_ALL
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
#define CHANGE_LOCK(lock, var) \
  do { \
    var = ((VarLockStatus[]) { \
      [VAR_UNLOCKED] = (lock ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_LOCKED] = (lock ? VAR_LOCKED : VAR_UNLOCKED), \
      [VAR_FIXED] = VAR_FIXED, \
    })[var]; \
  } while (0)
  CHANGE_LOCK(lock, tv->v_lock);

  switch (tv->v_type) {
    case VAR_LIST: {
      list_T *const l = tv->vval.v_list;
      if (l != NULL) {
        CHANGE_LOCK(lock, l->lv_lock);
        if (deep < 0 || deep > 1) {
          // Recursive: lock/unlock the items the List contains.
          TV_LIST_ITER(l, li, {
            tv_item_lock(TV_LIST_ITEM_TV(li), deep - 1, lock);
          });
        }
      }
      break;
    }
    case VAR_DICT: {
      dict_T *const d = tv->vval.v_dict;
      if (d != NULL) {
        CHANGE_LOCK(lock, d->dv_lock);
        if (deep < 0 || deep > 1) {
          // recursive: lock/unlock the items the List contains
          TV_DICT_ITER(d, di, {
            tv_item_lock(&di->di_tv, deep - 1, lock);
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
    case VAR_SPECIAL: {
      break;
    }
    case VAR_UNKNOWN: {
      assert(false);
    }
  }
#undef CHANGE_LOCK
  recurse--;
}

/// Check whether VimL value is locked itself or refers to a locked container
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
/// @param[in]  lock  Lock status.
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
bool tv_check_lock(const VarLockStatus lock, const char *name,
                   size_t name_len)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *error_message = NULL;
  switch (lock) {
    case VAR_UNLOCKED: {
      return false;
    }
    case VAR_LOCKED: {
      error_message = N_("E741: Value is locked: %.*s");
      break;
    }
    case VAR_FIXED: {
      error_message = N_("E742: Cannot change value of %.*s");
      break;
    }
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

  emsgf(_(error_message), (int)name_len, name);

  return true;
}

//{{{2 Comparison

static int tv_equal_recurse_limit;

/// Compare two VimL values
///
/// Like "==", but strings and numbers are different, as well as floats and
/// numbers.
///
/// @warning Too nested structures may be considered equal even if they are not.
///
/// @param[in]  tv1  First value to compare.
/// @param[in]  tv2  Second value to compare.
/// @param[in]  ic  True if case is to be ignored.
/// @param[in]  recursive  True when used recursively.
///
/// @return true if values are equal.
bool tv_equal(typval_T *const tv1, typval_T *const tv2, const bool ic,
              const bool recursive)
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
  if (!recursive) {
    tv_equal_recurse_limit = 1000;
  }
  if (recursive_cnt >= tv_equal_recurse_limit) {
    tv_equal_recurse_limit--;
    return true;
  }

  switch (tv1->v_type) {
    case VAR_LIST: {
      recursive_cnt++;
      const bool r = tv_list_equal(tv1->vval.v_list, tv2->vval.v_list, ic,
                                   true);
      recursive_cnt--;
      return r;
    }
    case VAR_DICT: {
      recursive_cnt++;
      const bool r = tv_dict_equal(tv1->vval.v_dict, tv2->vval.v_dict, ic,
                                   true);
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
    case VAR_NUMBER: {
      return tv1->vval.v_number == tv2->vval.v_number;
    }
    case VAR_FLOAT: {
      return tv1->vval.v_float == tv2->vval.v_float;
    }
    case VAR_STRING: {
      char buf1[NUMBUFLEN];
      char buf2[NUMBUFLEN];
      const char *s1 = tv_get_string_buf(tv1, buf1);
      const char *s2 = tv_get_string_buf(tv2, buf2);
      return mb_strcmp_ic((bool)ic, s1, s2) == 0;
    }
    case VAR_SPECIAL: {
      return tv1->vval.v_special == tv2->vval.v_special;
    }
    case VAR_UNKNOWN: {
      // VAR_UNKNOWN can be the result of an invalid expression, let’s say it
      // does not equal anything, not even self.
      return false;
    }
  }

  assert(false);
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
    case VAR_STRING: {
      return true;
    }
    case VAR_FLOAT: {
      EMSG(_("E805: Expected a Number or a String, Float found"));
      return false;
    }
    case VAR_PARTIAL:
    case VAR_FUNC: {
      EMSG(_("E703: Expected a Number or a String, Funcref found"));
      return false;
    }
    case VAR_LIST: {
      EMSG(_("E745: Expected a Number or a String, List found"));
      return false;
    }
    case VAR_DICT: {
      EMSG(_("E728: Expected a Number or a String, Dictionary found"));
      return false;
    }
    case VAR_SPECIAL: {
      EMSG(_("E5300: Expected a Number or a String"));
      return false;
    }
    case VAR_UNKNOWN: {
      EMSG2(_(e_intern2), "tv_check_str_or_nr(UNKNOWN)");
      return false;
    }
  }
  assert(false);
  return false;
}

#define FUNC_ERROR "E703: Using a Funcref as a Number"

static const char *const num_errors[] = {
  [VAR_PARTIAL]=N_(FUNC_ERROR),
  [VAR_FUNC]=N_(FUNC_ERROR),
  [VAR_LIST]=N_("E745: Using a List as a Number"),
  [VAR_DICT]=N_("E728: Using a Dictionary as a Number"),
  [VAR_FLOAT]=N_("E805: Using a Float as a Number"),
  [VAR_UNKNOWN]=N_("E685: using an invalid value as a Number"),
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
    case VAR_SPECIAL:
    case VAR_STRING: {
      return true;
    }
    case VAR_FUNC:
    case VAR_PARTIAL:
    case VAR_LIST:
    case VAR_DICT:
    case VAR_FLOAT:
    case VAR_UNKNOWN: {
      EMSG(_(num_errors[tv->v_type]));
      return false;
    }
  }
  assert(false);
  return false;
}

#define FUNC_ERROR "E729: using Funcref as a String"

static const char *const str_errors[] = {
  [VAR_PARTIAL]=N_(FUNC_ERROR),
  [VAR_FUNC]=N_(FUNC_ERROR),
  [VAR_LIST]=N_("E730: using List as a String"),
  [VAR_DICT]=N_("E731: using Dictionary as a String"),
  [VAR_FLOAT]=((const char *)e_float_as_string),
  [VAR_UNKNOWN]=N_("E908: using an invalid value as a String"),
};

#undef FUNC_ERROR

/// Check that given value is a VimL String or can be "cast" to it.
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
    case VAR_SPECIAL:
    case VAR_STRING: {
      return true;
    }
    case VAR_PARTIAL:
    case VAR_FUNC:
    case VAR_LIST:
    case VAR_DICT:
    case VAR_FLOAT:
    case VAR_UNKNOWN: {
      EMSG(_(str_errors[tv->v_type]));
      return false;
    }
  }
  assert(false);
  return false;
}

//{{{2 Get

/// Get the number value of a VimL object
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

/// Get the number value of a VimL object
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
    case VAR_FLOAT: {
      EMSG(_(num_errors[tv->v_type]));
      break;
    }
    case VAR_NUMBER: {
      return tv->vval.v_number;
    }
    case VAR_STRING: {
      varnumber_T n = 0;
      if (tv->vval.v_string != NULL) {
        vim_str2nr(tv->vval.v_string, NULL, NULL, STR2NR_ALL, &n, NULL, 0);
      }
      return n;
    }
    case VAR_SPECIAL: {
      switch (tv->vval.v_special) {
        case kSpecialVarTrue: {
          return 1;
        }
        case kSpecialVarFalse:
        case kSpecialVarNull: {
          return 0;
        }
      }
      break;
    }
    case VAR_UNKNOWN: {
      emsgf(_(e_intern2), "tv_get_number(UNKNOWN)");
      break;
    }
  }
  if (ret_error != NULL) {
    *ret_error = true;
  }
  return (ret_error == NULL ? -1 : 0);
}

/// Get the line number from VimL object
///
/// @param[in]  tv  Object to get value from. Is expected to be a number or
///                 a special string like ".", "$", … (works with current buffer
///                 only).
///
/// @return Line number or -1 or 0.
linenr_T tv_get_lnum(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  linenr_T lnum = (linenr_T)tv_get_number_chk(tv, NULL);
  if (lnum == 0) {  // No valid number, try using same function as line() does.
    int fnum;
    pos_T *const fp = var2fpos(tv, true, &fnum);
    if (fp != NULL) {
      lnum = fp->lnum;
    }
  }
  return lnum;
}

/// Get the floating-point value of a VimL object
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
    case VAR_NUMBER: {
      return (float_T)(tv->vval.v_number);
    }
    case VAR_FLOAT: {
      return tv->vval.v_float;
    }
    case VAR_PARTIAL:
    case VAR_FUNC: {
      EMSG(_("E891: Using a Funcref as a Float"));
      break;
    }
    case VAR_STRING: {
      EMSG(_("E892: Using a String as a Float"));
      break;
    }
    case VAR_LIST: {
      EMSG(_("E893: Using a List as a Float"));
      break;
    }
    case VAR_DICT: {
      EMSG(_("E894: Using a Dictionary as a Float"));
      break;
    }
    case VAR_SPECIAL: {
      EMSG(_("E907: Using a special value as a Float"));
      break;
    }
    case VAR_UNKNOWN: {
      emsgf(_(e_intern2), "tv_get_float(UNKNOWN)");
      break;
    }
  }
  return 0;
}

/// Get the string value of a "stringish" VimL object.
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
    case VAR_NUMBER: {
      snprintf(buf, NUMBUFLEN, "%" PRIdVARNUMBER, tv->vval.v_number);  // -V576
      return buf;
    }
    case VAR_STRING: {
      if (tv->vval.v_string != NULL) {
        return (const char *)tv->vval.v_string;
      }
      return "";
    }
    case VAR_SPECIAL: {
      STRCPY(buf, encode_special_var_names[tv->vval.v_special]);
      return buf;
    }
    case VAR_PARTIAL:
    case VAR_FUNC:
    case VAR_LIST:
    case VAR_DICT:
    case VAR_FLOAT:
    case VAR_UNKNOWN: {
      EMSG(_(str_errors[tv->v_type]));
      return false;
    }
  }
  return NULL;
}

/// Get the string value of a "stringish" VimL object.
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

/// Get the string value of a "stringish" VimL object.
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

/// Get the string value of a "stringish" VimL object.
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
  const char *const res = (const char *)tv_get_string_buf_chk(tv, buf);

  return res != NULL ? res : "";
}
