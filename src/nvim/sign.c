// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// sign.c: functions for managing with signs
//

#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/fold.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/pos.h"
#include "nvim/sign.h"
#include "nvim/sign_defs.h"
#include "nvim/strings.h"
#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/window.h"

/// Struct to hold the sign properties.
typedef struct sign sign_T;

struct sign {
  sign_T *sn_next;    // next sign in list
  int sn_typenr;      // type number of sign
  char *sn_name;      // name of sign
  char *sn_icon;      // name of pixmap
  char *sn_text;      // text used instead of pixmap
  int sn_line_hl;     // highlight ID for line
  int sn_text_hl;     // highlight ID for text
  int sn_cul_hl;      // highlight ID for text on current line when 'cursorline' is set
  int sn_num_hl;      // highlight ID for line number
};

static sign_T *first_sign = NULL;
static int next_sign_typenr = 1;

static void sign_list_defined(sign_T *sp);
static void sign_undefine(sign_T *sp, sign_T *sp_prev);

static char *cmds[] = {
  "define",
#define SIGNCMD_DEFINE  0
  "undefine",
#define SIGNCMD_UNDEFINE 1
  "list",
#define SIGNCMD_LIST    2
  "place",
#define SIGNCMD_PLACE   3
  "unplace",
#define SIGNCMD_UNPLACE 4
  "jump",
#define SIGNCMD_JUMP    5
  NULL
#define SIGNCMD_LAST    6
};

static hashtab_T sg_table;  // sign group (signgroup_T) hashtable
static int next_sign_id = 1;  // next sign id in the global group

/// Initialize data needed for managing signs
void init_signs(void)
{
  hash_init(&sg_table);  // sign group hash table
}

/// A new sign in group 'groupname' is added. If the group is not present,
/// create it. Otherwise reference the group.
static signgroup_T *sign_group_ref(const char *groupname)
{
  hash_T hash;
  hashitem_T *hi;
  signgroup_T *group;

  hash = hash_hash(groupname);
  hi = hash_lookup(&sg_table, groupname, strlen(groupname), hash);
  if (HASHITEM_EMPTY(hi)) {
    // new group
    group = xmalloc(offsetof(signgroup_T, sg_name) + strlen(groupname) + 1);

    STRCPY(group->sg_name, groupname);
    group->sg_refcount = 1;
    group->sg_next_sign_id = 1;
    hash_add_item(&sg_table, hi, group->sg_name, hash);
  } else {
    // existing group
    group = HI2SG(hi);
    group->sg_refcount++;
  }

  return group;
}

/// A sign in group 'groupname' is removed. If all the signs in this group are
/// removed, then remove the group.
static void sign_group_unref(char *groupname)
{
  hashitem_T *hi = hash_find(&sg_table, groupname);
  if (HASHITEM_EMPTY(hi)) {
    return;
  }

  signgroup_T *group = HI2SG(hi);
  group->sg_refcount--;
  if (group->sg_refcount == 0) {
    // All the signs in this group are removed
    hash_remove(&sg_table, hi);
    xfree(group);
  }
}

/// @return true if 'sign' is in 'group'.
/// A sign can either be in the global group (sign->group == NULL)
/// or in a named group. If 'group' is '*', then the sign is part of the group.
static bool sign_in_group(sign_entry_T *sign, const char *group)
{
  return ((group != NULL && strcmp(group, "*") == 0)
          || (group == NULL && sign->se_group == NULL)
          || (group != NULL && sign->se_group != NULL
              && strcmp(group, sign->se_group->sg_name) == 0));
}

/// Get the next free sign identifier in the specified group
static int sign_group_get_next_signid(buf_T *buf, const char *groupname)
{
  int id = 1;
  signgroup_T *group = NULL;
  sign_entry_T *sign;
  int found = false;

  if (groupname != NULL) {
    hashitem_T *hi = hash_find(&sg_table, groupname);
    if (HASHITEM_EMPTY(hi)) {
      return id;
    }
    group = HI2SG(hi);
  }

  // Search for the next usable sign identifier
  while (!found) {
    if (group == NULL) {
      id = next_sign_id++;    // global group
    } else {
      id = group->sg_next_sign_id++;
    }

    // Check whether this sign is already placed in the buffer
    found = true;
    FOR_ALL_SIGNS_IN_BUF(buf, sign) {
      if (id == sign->se_id && sign_in_group(sign, groupname)) {
        found = false;    // sign identifier is in use
        break;
      }
    }
  }

  return id;
}

/// Insert a new sign into the signlist for buffer 'buf' between the 'prev' and
/// 'next' signs.
///
/// @param buf  buffer to store sign in
/// @param prev  previous sign entry
/// @param next  next sign entry
/// @param id  sign ID
/// @param group  sign group; NULL for global group
/// @param prio  sign priority
/// @param lnum  line number which gets the mark
/// @param typenr  typenr of sign we are adding
/// @param has_text_or_icon  sign has text or icon
static void insert_sign(buf_T *buf, sign_entry_T *prev, sign_entry_T *next, int id,
                        const char *group, int prio, linenr_T lnum, int typenr,
                        bool has_text_or_icon)
{
  sign_entry_T *newsign = xmalloc(sizeof(sign_entry_T));
  newsign->se_id = id;
  newsign->se_lnum = lnum;
  newsign->se_typenr = typenr;
  newsign->se_has_text_or_icon = has_text_or_icon;
  if (group != NULL) {
    newsign->se_group = sign_group_ref(group);
  } else {
    newsign->se_group = NULL;
  }
  newsign->se_priority = prio;
  newsign->se_next = next;
  newsign->se_prev = prev;
  if (next != NULL) {
    next->se_prev = newsign;
  }

  buf_signcols_add_check(buf, newsign);

  if (prev == NULL) {
    // When adding first sign need to redraw the windows to create the
    // column for signs.
    if (buf->b_signlist == NULL) {
      redraw_buf_later(buf, UPD_NOT_VALID);
      changed_line_abv_curs();
    }

    // first sign in signlist
    buf->b_signlist = newsign;
  } else {
    prev->se_next = newsign;
  }
}

/// Insert a new sign sorted by line number and sign priority.
///
/// @param buf  buffer to store sign in
/// @param prev  previous sign entry
/// @param id  sign ID
/// @param group  sign group; NULL for global group
/// @param prio  sign priority
/// @param lnum  line number which gets the mark
/// @param typenr  typenr of sign we are adding
/// @param has_text_or_icon  sign has text or icon
static void insert_sign_by_lnum_prio(buf_T *buf, sign_entry_T *prev, int id, const char *group,
                                     int prio, linenr_T lnum, int typenr, bool has_text_or_icon)
{
  sign_entry_T *sign;

  // keep signs sorted by lnum, priority and id: insert new sign at
  // the proper position in the list for this lnum.
  while (prev != NULL && prev->se_lnum == lnum
         && (prev->se_priority < prio
             || (prev->se_priority == prio && prev->se_id <= id))) {
    prev = prev->se_prev;
  }
  if (prev == NULL) {
    sign = buf->b_signlist;
  } else {
    sign = prev->se_next;
  }

  insert_sign(buf, prev, sign, id, group, prio, lnum, typenr, has_text_or_icon);
}

/// Lookup a sign by typenr. Returns NULL if sign is not found.
static sign_T *find_sign_by_typenr(int typenr)
{
  sign_T *sp;

  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (sp->sn_typenr == typenr) {
      return sp;
    }
  }
  return NULL;
}

/// Get the name of a sign by its typenr.
static char *sign_typenr2name(int typenr)
{
  sign_T *sp;

  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (sp->sn_typenr == typenr) {
      return sp->sn_name;
    }
  }
  return _("[Deleted]");
}

/// Return information about a sign in a Dict
static dict_T *sign_get_info(sign_entry_T *sign)
{
  dict_T *d = tv_dict_alloc();
  tv_dict_add_nr(d,  S_LEN("id"), sign->se_id);
  tv_dict_add_str(d, S_LEN("group"), ((sign->se_group == NULL)
                                      ? ""
                                      : sign->se_group->sg_name));
  tv_dict_add_nr(d,  S_LEN("lnum"), sign->se_lnum);
  tv_dict_add_str(d, S_LEN("name"), sign_typenr2name(sign->se_typenr));
  tv_dict_add_nr(d,  S_LEN("priority"), sign->se_priority);

  return d;
}

// Sort the signs placed on the same line as "sign" by priority.  Invoked after
// changing the priority of an already placed sign.  Assumes the signs in the
// buffer are sorted by line number and priority.
static void sign_sort_by_prio_on_line(buf_T *buf, sign_entry_T *sign)
  FUNC_ATTR_NONNULL_ALL
{
  // If there is only one sign in the buffer or only one sign on the line or
  // the sign is already sorted by priority, then return.
  if ((sign->se_prev == NULL
       || sign->se_prev->se_lnum != sign->se_lnum
       || sign->se_prev->se_priority > sign->se_priority)
      && (sign->se_next == NULL
          || sign->se_next->se_lnum != sign->se_lnum
          || sign->se_next->se_priority < sign->se_priority)) {
    return;
  }

  // One or more signs on the same line as 'sign'
  // Find a sign after which 'sign' should be inserted

  // First search backward for a sign with higher priority on the same line
  sign_entry_T *p = sign;
  while (p->se_prev != NULL
         && p->se_prev->se_lnum == sign->se_lnum
         && p->se_prev->se_priority <= sign->se_priority) {
    p = p->se_prev;
  }
  if (p == sign) {
    // Sign not found. Search forward for a sign with priority just before
    // 'sign'.
    p = sign->se_next;
    while (p->se_next != NULL
           && p->se_next->se_lnum == sign->se_lnum
           && p->se_next->se_priority > sign->se_priority) {
      p = p->se_next;
    }
  }

  // Remove 'sign' from the list
  if (buf->b_signlist == sign) {
    buf->b_signlist = sign->se_next;
  }
  if (sign->se_prev != NULL) {
    sign->se_prev->se_next = sign->se_next;
  }
  if (sign->se_next != NULL) {
    sign->se_next->se_prev = sign->se_prev;
  }
  sign->se_prev = NULL;
  sign->se_next = NULL;

  // Re-insert 'sign' at the right place
  if (p->se_priority <= sign->se_priority) {
    // 'sign' has a higher priority and should be inserted before 'p'
    sign->se_prev = p->se_prev;
    sign->se_next = p;
    p->se_prev = sign;
    if (sign->se_prev != NULL) {
      sign->se_prev->se_next = sign;
    }
    if (buf->b_signlist == p) {
      buf->b_signlist = sign;
    }
  } else {
    // 'sign' has a lower priority and should be inserted after 'p'
    sign->se_prev = p;
    sign->se_next = p->se_next;
    p->se_next = sign;
    if (sign->se_next != NULL) {
      sign->se_next->se_prev = sign;
    }
  }
}

/// Add the sign into the signlist. Find the right spot to do it though.
///
/// @param buf  buffer to store sign in
/// @param id  sign ID
/// @param groupname  sign group
/// @param prio  sign priority
/// @param lnum  line number which gets the mark
/// @param typenr  typenr of sign we are adding
/// @param has_text_or_icon  sign has text or icon
static void buf_addsign(buf_T *buf, int id, const char *groupname, int prio, linenr_T lnum,
                        int typenr, bool has_text_or_icon)
{
  sign_entry_T *sign;    // a sign in the signlist
  sign_entry_T *prev;    // the previous sign

  prev = NULL;
  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (lnum == sign->se_lnum && id == sign->se_id
        && sign_in_group(sign, groupname)) {
      // Update an existing sign
      sign->se_typenr = typenr;
      sign->se_priority = prio;
      sign_sort_by_prio_on_line(buf, sign);
      return;
    } else if (lnum < sign->se_lnum) {
      insert_sign_by_lnum_prio(buf,
                               prev,
                               id,
                               groupname,
                               prio,
                               lnum,
                               typenr,
                               has_text_or_icon);
      return;
    }
    prev = sign;
  }

  insert_sign_by_lnum_prio(buf,
                           prev,
                           id,
                           groupname,
                           prio,
                           lnum,
                           typenr,
                           has_text_or_icon);
}

/// For an existing, placed sign "markId" change the type to "typenr".
/// Returns the line number of the sign, or zero if the sign is not found.
///
/// @param buf  buffer to store sign in
/// @param markId  sign ID
/// @param group  sign group
/// @param typenr  typenr of sign we are adding
/// @param prio  sign priority
static linenr_T buf_change_sign_type(buf_T *buf, int markId, const char *group, int typenr,
                                     int prio)
{
  sign_entry_T *sign;  // a sign in the signlist

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (sign->se_id == markId && sign_in_group(sign, group)) {
      sign->se_typenr = typenr;
      sign->se_priority = prio;
      sign_sort_by_prio_on_line(buf, sign);
      return sign->se_lnum;
    }
  }

  return (linenr_T)0;
}

/// Return the sign attrs which has the attribute specified by 'type'. Returns
/// NULL if a sign is not found with the specified attribute.
/// @param type Type of sign to look for
/// @param sattrs Sign attrs to search through
/// @param idx if there multiple signs, this index will pick the n-th
///        out of the most `max_signs` sorted ascending by Id.
/// @param max_signs the number of signs, with priority for the ones
///        with the highest Ids.
/// @return Attrs of the matching sign, or NULL
SignTextAttrs *sign_get_attr(int idx, SignTextAttrs sattrs[], int max_signs)
{
  SignTextAttrs *matches[SIGN_SHOW_MAX];
  int sattr_matches = 0;

  for (int i = 0; i < SIGN_SHOW_MAX; i++) {
    if (sattrs[i].text != NULL) {
      matches[sattr_matches++] = &sattrs[i];
      // attr list is sorted with most important (priority, id), thus we
      // may stop as soon as we have max_signs matches
      if (sattr_matches >= max_signs) {
        break;
      }
    }
  }

  if (sattr_matches > idx) {
    return matches[sattr_matches - idx - 1];
  }

  return NULL;
}

/// Return the attributes of all the signs placed on line 'lnum' in buffer
/// 'buf'. Used when refreshing the screen. Returns the number of signs.
/// @param buf Buffer in which to search
/// @param lnum Line in which to search
/// @param sattrs Output array for attrs
/// @return Number of signs of which attrs were found
int buf_get_signattrs(buf_T *buf, linenr_T lnum, SignTextAttrs sattrs[], HlPriId *num_id,
                      HlPriId *line_id, HlPriId *cul_id)
{
  sign_entry_T *sign;

  int sattr_matches = 0;

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (sign->se_lnum > lnum) {
      // Signs are sorted by line number in the buffer. No need to check
      // for signs after the specified line number 'lnum'.
      break;
    }

    if (sign->se_lnum < lnum) {
      continue;
    }

    sign_T *sp = find_sign_by_typenr(sign->se_typenr);
    if (sp == NULL) {
      continue;
    }

    if (sp->sn_text != NULL && sattr_matches < SIGN_SHOW_MAX) {
      sattrs[sattr_matches++] = (SignTextAttrs) {
        .text = sp->sn_text,
        .hl_id = sp->sn_text_hl,
        .priority = sign->se_priority
      };
    }

    struct { HlPriId *dest; int hl; } cattrs[] = {
      { line_id, sp->sn_line_hl },
      { num_id,  sp->sn_num_hl  },
      { cul_id,  sp->sn_cul_hl  },
      { NULL, -1 },
    };
    for (int i = 0; cattrs[i].dest; i++) {
      if (cattrs[i].hl != 0 && sign->se_priority >= cattrs[i].dest->priority) {
        *cattrs[i].dest = (HlPriId) {
          .hl_id = cattrs[i].hl,
          .priority = sign->se_priority
        };
      }
    }
  }
  return sattr_matches;
}

/// Delete sign 'id' in group 'group' from buffer 'buf'.
/// If 'id' is zero, then delete all the signs in group 'group'. Otherwise
/// delete only the specified sign.
/// If 'group' is '*', then delete the sign in all the groups. If 'group' is
/// NULL, then delete the sign in the global group. Otherwise delete the sign in
/// the specified group.
///
/// @param buf  buffer sign is stored in
/// @param atlnum  sign at this line, 0 - at any line
/// @param id  sign id
/// @param group  sign group
///
/// @return  the line number of the deleted sign. If multiple signs are deleted,
/// then returns the line number of the last sign deleted.
static linenr_T buf_delsign(buf_T *buf, linenr_T atlnum, int id, char *group)
{
  sign_entry_T **lastp;  // pointer to pointer to current sign
  sign_entry_T *sign;    // a sign in a b_signlist
  sign_entry_T *next;    // the next sign in a b_signlist
  linenr_T lnum;       // line number whose sign was deleted

  lastp = &buf->b_signlist;
  lnum = 0;
  for (sign = buf->b_signlist; sign != NULL; sign = next) {
    next = sign->se_next;
    if ((id == 0 || sign->se_id == id)
        && (atlnum == 0 || sign->se_lnum == atlnum)
        && sign_in_group(sign, group)) {
      *lastp = next;
      if (next != NULL) {
        next->se_prev = sign->se_prev;
      }
      lnum = sign->se_lnum;
      buf_signcols_del_check(buf, lnum, lnum);
      if (sign->se_group != NULL) {
        sign_group_unref(sign->se_group->sg_name);
      }
      xfree(sign);
      redraw_buf_line_later(buf, lnum, false);
      // Check whether only one sign needs to be deleted
      // If deleting a sign with a specific identifier in a particular
      // group or deleting any sign at a particular line number, delete
      // only one sign.
      if (group == NULL
          || (*group != '*' && id != 0)
          || (*group == '*' && atlnum != 0)) {
        break;
      }
    } else {
      lastp = &sign->se_next;
    }
  }

  // When deleting the last sign the cursor position may change, because the
  // sign columns no longer shows.  And the 'signcolumn' may be hidden.
  if (buf->b_signlist == NULL) {
    redraw_buf_later(buf, UPD_NOT_VALID);
    changed_line_abv_curs();
  }

  return lnum;
}

/// Find the line number of the sign with the requested id in group 'group'. If
/// the sign does not exist, return 0 as the line number. This will still let
/// the correct file get loaded.
///
/// @param buf  buffer to store sign in
/// @param id  sign ID
/// @param group  sign group
static int buf_findsign(buf_T *buf, int id, char *group)
{
  sign_entry_T *sign;  // a sign in the signlist

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (sign->se_id == id && sign_in_group(sign, group)) {
      return (int)sign->se_lnum;
    }
  }

  return 0;
}

/// Return the sign at line 'lnum' in buffer 'buf'. Returns NULL if a sign is
/// not found at the line. If 'groupname' is NULL, searches in the global group.
///
/// @param buf  buffer whose sign we are searching for
/// @param lnum  line number of sign
/// @param groupname  sign group name
static sign_entry_T *buf_getsign_at_line(buf_T *buf, linenr_T lnum, char *groupname)
{
  sign_entry_T *sign;    // a sign in the signlist

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (sign->se_lnum > lnum) {
      // Signs are sorted by line number in the buffer. No need to check
      // for signs after the specified line number 'lnum'.
      break;
    }

    if (sign->se_lnum == lnum && sign_in_group(sign, groupname)) {
      return sign;
    }
  }

  return NULL;
}

/// Return the identifier of the sign at line number 'lnum' in buffer 'buf'.
///
/// @param buf  buffer whose sign we are searching for
/// @param lnum  line number of sign
/// @param groupname  sign group name
static int buf_findsign_id(buf_T *buf, linenr_T lnum, char *groupname)
{
  sign_entry_T *sign;   // a sign in the signlist

  sign = buf_getsign_at_line(buf, lnum, groupname);
  if (sign != NULL) {
    return sign->se_id;
  }

  return 0;
}

/// Delete signs in buffer "buf".
void buf_delete_signs(buf_T *buf, char *group)
{
  sign_entry_T *sign;
  sign_entry_T **lastp;  // pointer to pointer to current sign
  sign_entry_T *next;

  // When deleting the last sign need to redraw the windows to remove the
  // sign column. Not when curwin is NULL (this means we're exiting).
  if (buf->b_signlist != NULL && curwin != NULL) {
    changed_line_abv_curs();
  }

  lastp = &buf->b_signlist;
  for (sign = buf->b_signlist; sign != NULL; sign = next) {
    next = sign->se_next;
    if (sign_in_group(sign, group)) {
      *lastp = next;
      if (next != NULL) {
        next->se_prev = sign->se_prev;
      }
      if (sign->se_group != NULL) {
        sign_group_unref(sign->se_group->sg_name);
      }
      xfree(sign);
    } else {
      lastp = &sign->se_next;
    }
  }
  buf_signcols_del_check(buf, 1, MAXLNUM);
}

/// List placed signs for "rbuf".  If "rbuf" is NULL do it for all buffers.
static void sign_list_placed(buf_T *rbuf, char *sign_group)
{
  buf_T *buf;
  sign_entry_T *sign;
  char lbuf[MSG_BUF_LEN];
  char group[MSG_BUF_LEN];

  msg_puts_title(_("\n--- Signs ---"));
  msg_putchar('\n');
  if (rbuf == NULL) {
    buf = firstbuf;
  } else {
    buf = rbuf;
  }
  while (buf != NULL && !got_int) {
    if (buf->b_signlist != NULL) {
      vim_snprintf(lbuf, MSG_BUF_LEN, _("Signs for %s:"), buf->b_fname);
      msg_puts_attr(lbuf, HL_ATTR(HLF_D));
      msg_putchar('\n');
    }
    FOR_ALL_SIGNS_IN_BUF(buf, sign) {
      if (got_int) {
        break;
      }
      if (!sign_in_group(sign, sign_group)) {
        continue;
      }
      if (sign->se_group != NULL) {
        vim_snprintf(group, MSG_BUF_LEN, _("  group=%s"),
                     sign->se_group->sg_name);
      } else {
        group[0] = '\0';
      }
      vim_snprintf(lbuf, MSG_BUF_LEN,
                   _("    line=%ld  id=%d%s  name=%s  priority=%d"),
                   (long)sign->se_lnum, sign->se_id, group,
                   sign_typenr2name(sign->se_typenr), sign->se_priority);
      msg_puts(lbuf);
      msg_putchar('\n');
    }
    if (rbuf != NULL) {
      break;
    }
    buf = buf->b_next;
  }
}

/// Adjust or delete a placed sign for inserted/deleted lines.
///
/// @return  the new line number of the sign, or 0 if the sign is in deleted lines.
static linenr_T sign_adjust_one(const linenr_T se_lnum, linenr_T line1, linenr_T line2,
                                linenr_T amount, linenr_T amount_after)
{
  if (se_lnum < line1) {
    // Ignore changes to lines after the sign
    return se_lnum;
  }
  if (se_lnum > line2) {
    // Lines inserted or deleted before the sign
    return se_lnum + amount_after;
  }
  if (amount == MAXLNUM) {  // sign in deleted lines
    return 0;
  }
  return se_lnum + amount;
}

/// Adjust placed signs for inserted/deleted lines.
void sign_mark_adjust(buf_T *buf, linenr_T line1, linenr_T line2, linenr_T amount,
                      linenr_T amount_after)
{
  sign_entry_T *sign;           // a sign in a b_signlist
  sign_entry_T *next;           // the next sign in a b_signlist
  sign_entry_T *last = NULL;    // pointer to pointer to current sign
  sign_entry_T **lastp = NULL;  // pointer to pointer to current sign
  linenr_T new_lnum;            // new line number to assign to sign
  int is_fixed = 0;
  int signcol = curwin->w_buffer == buf ? win_signcol_configured(curwin, &is_fixed) : 0;

  if (amount == MAXLNUM) {  // deleting
    buf_signcols_del_check(buf, line1, line2);
  }

  lastp = &buf->b_signlist;

  for (sign = buf->b_signlist; sign != NULL; sign = next) {
    next = sign->se_next;

    new_lnum = sign_adjust_one(sign->se_lnum, line1, line2, amount, amount_after);
    if (new_lnum == 0) {  // sign in deleted lines
      if (!is_fixed || signcol >= 2) {
        *lastp = next;
        if (next) {
          next->se_prev = last;
        }
        xfree(sign);
        continue;
      }
    } else {
      // If the new sign line number is past the last line in the buffer,
      // then don't adjust the line number. Otherwise, it will always be past
      // the last line and will not be visible.
      if (new_lnum <= buf->b_ml.ml_line_count) {
        sign->se_lnum = new_lnum;
      }
    }

    last = sign;
    lastp = &sign->se_next;
  }

  new_lnum = sign_adjust_one(buf->b_signcols.sentinel, line1, line2, amount, amount_after);
  if (new_lnum != 0) {
    buf->b_signcols.sentinel = new_lnum;
  }
}

/// Find index of a ":sign" subcmd from its name.
/// "*end_cmd" must be writable.
///
/// @param begin_cmd  begin of sign subcmd
/// @param end_cmd  just after sign subcmd
static int sign_cmd_idx(char *begin_cmd, char *end_cmd)
{
  int idx;
  char save = *end_cmd;

  *end_cmd = NUL;
  for (idx = 0;; idx++) {
    if (cmds[idx] == NULL || strcmp(begin_cmd, cmds[idx]) == 0) {
      break;
    }
  }
  *end_cmd = save;
  return idx;
}

/// Find a sign by name. Also returns pointer to the previous sign.
static sign_T *sign_find(const char *name, sign_T **sp_prev)
{
  sign_T *sp;

  if (sp_prev != NULL) {
    *sp_prev = NULL;
  }
  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (strcmp(sp->sn_name, name) == 0) {
      break;
    }
    if (sp_prev != NULL) {
      *sp_prev = sp;
    }
  }

  return sp;
}

/// Allocate a new sign
static sign_T *alloc_new_sign(char *name)
{
  sign_T *sp;
  sign_T *lp;
  int start = next_sign_typenr;

  // Allocate a new sign.
  sp = xcalloc(1, sizeof(sign_T));

  // Check that next_sign_typenr is not already being used.
  // This only happens after wrapping around.  Hopefully
  // another one got deleted and we can use its number.
  for (lp = first_sign; lp != NULL;) {
    if (lp->sn_typenr == next_sign_typenr) {
      next_sign_typenr++;
      if (next_sign_typenr == MAX_TYPENR) {
        next_sign_typenr = 1;
      }
      if (next_sign_typenr == start) {
        xfree(sp);
        emsg(_("E612: Too many signs defined"));
        return NULL;
      }
      lp = first_sign;  // start all over
      continue;
    }
    lp = lp->sn_next;
  }

  sp->sn_typenr = next_sign_typenr;
  if (++next_sign_typenr == MAX_TYPENR) {
    next_sign_typenr = 1;  // wrap around
  }

  sp->sn_name = xstrdup(name);

  return sp;
}

/// Initialize the icon information for a new sign
static void sign_define_init_icon(sign_T *sp, char *icon)
{
  xfree(sp->sn_icon);
  sp->sn_icon = xstrdup(icon);
  backslash_halve(sp->sn_icon);
}

/// Initialize the text for a new sign
static int sign_define_init_text(sign_T *sp, char *text)
{
  char *s;
  char *endp;
  int cells;
  size_t len;

  endp = text + (int)strlen(text);
  for (s = text; s + 1 < endp; s++) {
    if (*s == '\\') {
      // Remove a backslash, so that it is possible
      // to use a space.
      STRMOVE(s, s + 1);
      endp--;
    }
  }
  // Count cells and check for non-printable chars
  cells = 0;
  for (s = text; s < endp; s += utfc_ptr2len(s)) {
    if (!vim_isprintc(utf_ptr2char(s))) {
      break;
    }
    cells += utf_ptr2cells(s);
  }
  // Currently must be empty, one or two display cells
  if (s != endp || cells > 2) {
    semsg(_("E239: Invalid sign text: %s"), text);
    return FAIL;
  }
  if (cells < 1) {
    sp->sn_text = NULL;
    return OK;
  }

  xfree(sp->sn_text);
  // Allocate one byte more if we need to pad up
  // with a space.
  len = (size_t)(endp - text + ((cells == 1) ? 1 : 0));
  sp->sn_text = xstrnsave(text, len);

  if (cells == 1) {
    STRCPY(sp->sn_text + len - 1, " ");
  }

  return OK;
}

/// Define a new sign or update an existing sign
static int sign_define_by_name(char *name, char *icon, char *linehl, char *text, char *texthl,
                               char *culhl, char *numhl)
{
  sign_T *sp_prev;
  sign_T *sp;

  sp = sign_find(name, &sp_prev);
  if (sp == NULL) {
    sp = alloc_new_sign(name);
    if (sp == NULL) {
      return FAIL;
    }

    // add the new sign to the list of signs
    if (sp_prev == NULL) {
      first_sign = sp;
    } else {
      sp_prev->sn_next = sp;
    }
  } else {
    // Signs may already exist, a redraw is needed in windows with a
    // non-empty sign list.
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer->b_signlist != NULL) {
        redraw_buf_later(wp->w_buffer, UPD_NOT_VALID);
      }
    }
  }

  // set values for a defined sign.
  if (icon != NULL) {
    sign_define_init_icon(sp, icon);
  }

  if (text != NULL && (sign_define_init_text(sp, text) == FAIL)) {
    return FAIL;
  }

  if (linehl != NULL) {
    if (*linehl == NUL) {
      sp->sn_line_hl = 0;
    } else {
      sp->sn_line_hl = syn_check_group(linehl, strlen(linehl));
    }
  }

  if (texthl != NULL) {
    if (*texthl == NUL) {
      sp->sn_text_hl = 0;
    } else {
      sp->sn_text_hl = syn_check_group(texthl, strlen(texthl));
    }
  }

  if (culhl != NULL) {
    if (*culhl == NUL) {
      sp->sn_cul_hl = 0;
    } else {
      sp->sn_cul_hl = syn_check_group(culhl, strlen(culhl));
    }
  }

  if (numhl != NULL) {
    if (*numhl == NUL) {
      sp->sn_num_hl = 0;
    } else {
      sp->sn_num_hl = syn_check_group(numhl, strlen(numhl));
    }
  }

  return OK;
}

/// Free the sign specified by 'name'.
static int sign_undefine_by_name(const char *name)
{
  sign_T *sp_prev;
  sign_T *sp;

  sp = sign_find(name, &sp_prev);
  if (sp == NULL) {
    semsg(_("E155: Unknown sign: %s"), name);
    return FAIL;
  }
  sign_undefine(sp, sp_prev);

  return OK;
}

/// List the signs matching 'name'
static void sign_list_by_name(char *name)
{
  sign_T *sp;

  sp = sign_find(name, NULL);
  if (sp != NULL) {
    sign_list_defined(sp);
  } else {
    semsg(_("E155: Unknown sign: %s"), name);
  }
}

static void may_force_numberwidth_recompute(buf_T *buf, int unplace)
{
  FOR_ALL_TAB_WINDOWS(tp, wp)
  if (wp->w_buffer == buf
      && (wp->w_p_nu || wp->w_p_rnu)
      && (unplace || wp->w_nrwidth_width < 2)
      && (*wp->w_p_scl == 'n' && *(wp->w_p_scl + 1) == 'u')) {
    wp->w_nrwidth_line_count = 0;
  }
}

/// Place a sign at the specified file location or update a sign.
static int sign_place(int *sign_id, const char *sign_group, const char *sign_name, buf_T *buf,
                      linenr_T lnum, int prio)
{
  sign_T *sp;

  // Check for reserved character '*' in group name
  if (sign_group != NULL && (*sign_group == '*' || *sign_group == '\0')) {
    return FAIL;
  }

  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (strcmp(sp->sn_name, sign_name) == 0) {
      break;
    }
  }
  if (sp == NULL) {
    semsg(_("E155: Unknown sign: %s"), sign_name);
    return FAIL;
  }
  if (*sign_id == 0) {
    *sign_id = sign_group_get_next_signid(buf, sign_group);
  }

  if (lnum > 0) {
    // ":sign place {id} line={lnum} name={name} file={fname}":
    // place a sign
    bool has_text_or_icon = sp->sn_text != NULL || sp->sn_icon != NULL;
    buf_addsign(buf, *sign_id, sign_group, prio, lnum, sp->sn_typenr, has_text_or_icon);
  } else {
    // ":sign place {id} file={fname}": change sign type and/or priority
    lnum = buf_change_sign_type(buf, *sign_id, sign_group, sp->sn_typenr, prio);
  }
  if (lnum > 0) {
    redraw_buf_line_later(buf, lnum, false);

    // When displaying signs in the 'number' column, if the width of the
    // number column is less than 2, then force recomputing the width.
    may_force_numberwidth_recompute(buf, false);
  } else {
    semsg(_("E885: Not possible to change sign %s"), sign_name);
    return FAIL;
  }

  return OK;
}

/// Unplace the specified sign
static int sign_unplace(int sign_id, char *sign_group, buf_T *buf, linenr_T atlnum)
{
  if (buf->b_signlist == NULL) {  // No signs in the buffer
    return OK;
  }
  if (sign_id == 0) {
    // Delete all the signs in the specified buffer
    redraw_buf_later(buf, UPD_NOT_VALID);
    buf_delete_signs(buf, sign_group);
  } else {
    linenr_T lnum;

    // Delete only the specified signs
    lnum = buf_delsign(buf, atlnum, sign_id, sign_group);
    if (lnum == 0) {
      return FAIL;
    }
    redraw_buf_line_later(buf, lnum, false);
  }

  // When all the signs in a buffer are removed, force recomputing the
  // number column width (if enabled) in all the windows displaying the
  // buffer if 'signcolumn' is set to 'number' in that window.
  if (buf->b_signlist == NULL) {
    may_force_numberwidth_recompute(buf, true);
  }

  return OK;
}

/// Unplace the sign at the current cursor line.
static void sign_unplace_at_cursor(char *groupname)
{
  int id = -1;

  id = buf_findsign_id(curwin->w_buffer, curwin->w_cursor.lnum, groupname);
  if (id > 0) {
    sign_unplace(id, groupname, curwin->w_buffer, curwin->w_cursor.lnum);
  } else {
    emsg(_("E159: Missing sign number"));
  }
}

/// Jump to a sign.
static linenr_T sign_jump(int sign_id, char *sign_group, buf_T *buf)
{
  linenr_T lnum;

  if ((lnum = buf_findsign(buf, sign_id, sign_group)) <= 0) {
    semsg(_("E157: Invalid sign ID: %" PRId64), (int64_t)sign_id);
    return -1;
  }

  // goto a sign ...
  if (buf_jump_open_win(buf) != NULL) {     // ... in a current window
    curwin->w_cursor.lnum = lnum;
    check_cursor_lnum(curwin);
    beginline(BL_WHITE);
  } else {      // ... not currently in a window
    if (buf->b_fname == NULL) {
      emsg(_("E934: Cannot jump to a buffer that does not have a name"));
      return -1;
    }
    size_t cmdlen = strlen(buf->b_fname) + 24;
    char *cmd = xmallocz(cmdlen);
    snprintf(cmd, cmdlen, "e +%" PRId64 " %s",
             (int64_t)lnum, buf->b_fname);
    do_cmdline_cmd(cmd);
    xfree(cmd);
  }

  foldOpenCursor();

  return lnum;
}

/// ":sign define {name} ..." command
static void sign_define_cmd(char *sign_name, char *cmdline)
{
  char *p = cmdline;
  char *icon = NULL;
  char *text = NULL;
  char *linehl = NULL;
  char *texthl = NULL;
  char *culhl = NULL;
  char *numhl = NULL;
  int failed = false;

  // set values for a defined sign.
  while (true) {
    char *arg = skipwhite(p);
    if (*arg == NUL) {
      break;
    }
    p = skiptowhite_esc(arg);
    if (strncmp(arg, "icon=", 5) == 0) {
      arg += 5;
      XFREE_CLEAR(icon);
      icon = xstrnsave(arg, (size_t)(p - arg));
    } else if (strncmp(arg, "text=", 5) == 0) {
      arg += 5;
      XFREE_CLEAR(text);
      text = xstrnsave(arg, (size_t)(p - arg));
    } else if (strncmp(arg, "linehl=", 7) == 0) {
      arg += 7;
      XFREE_CLEAR(linehl);
      linehl = xstrnsave(arg, (size_t)(p - arg));
    } else if (strncmp(arg, "texthl=", 7) == 0) {
      arg += 7;
      XFREE_CLEAR(texthl);
      texthl = xstrnsave(arg, (size_t)(p - arg));
    } else if (strncmp(arg, "culhl=", 6) == 0) {
      arg += 6;
      XFREE_CLEAR(culhl);
      culhl = xstrnsave(arg, (size_t)(p - arg));
    } else if (strncmp(arg, "numhl=", 6) == 0) {
      arg += 6;
      XFREE_CLEAR(numhl);
      numhl = xstrnsave(arg, (size_t)(p - arg));
    } else {
      semsg(_(e_invarg2), arg);
      failed = true;
      break;
    }
  }

  if (!failed) {
    sign_define_by_name(sign_name, icon, linehl, text,
                        texthl, culhl, numhl);
  }

  xfree(icon);
  xfree(text);
  xfree(linehl);
  xfree(texthl);
  xfree(culhl);
  xfree(numhl);
}

/// ":sign place" command
static void sign_place_cmd(buf_T *buf, linenr_T lnum, char *sign_name, int id, char *group,
                           int prio)
{
  if (id <= 0) {
    // List signs placed in a file/buffer
    //   :sign place file={fname}
    //   :sign place group={group} file={fname}
    //   :sign place group=* file={fname}
    //   :sign place buffer={nr}
    //   :sign place group={group} buffer={nr}
    //   :sign place group=* buffer={nr}
    //   :sign place
    //   :sign place group={group}
    //   :sign place group=*
    if (lnum >= 0 || sign_name != NULL
        || (group != NULL && *group == '\0')) {
      emsg(_(e_invarg));
    } else {
      sign_list_placed(buf, group);
    }
  } else {
    // Place a new sign
    if (sign_name == NULL || buf == NULL
        || (group != NULL && *group == '\0')) {
      emsg(_(e_invarg));
      return;
    }

    sign_place(&id, group, sign_name, buf, lnum, prio);
  }
}

/// ":sign unplace" command
static void sign_unplace_cmd(buf_T *buf, linenr_T lnum, const char *sign_name, int id, char *group)
{
  if (lnum >= 0 || sign_name != NULL || (group != NULL && *group == '\0')) {
    emsg(_(e_invarg));
    return;
  }

  if (id == -2) {
    if (buf != NULL) {
      // :sign unplace * file={fname}
      // :sign unplace * group={group} file={fname}
      // :sign unplace * group=* file={fname}
      // :sign unplace * buffer={nr}
      // :sign unplace * group={group} buffer={nr}
      // :sign unplace * group=* buffer={nr}
      sign_unplace(0, group, buf, 0);
    } else {
      // :sign unplace *
      // :sign unplace * group={group}
      // :sign unplace * group=*
      FOR_ALL_BUFFERS(cbuf) {
        if (cbuf->b_signlist != NULL) {
          buf_delete_signs(cbuf, group);
        }
      }
    }
  } else {
    if (buf != NULL) {
      // :sign unplace {id} file={fname}
      // :sign unplace {id} group={group} file={fname}
      // :sign unplace {id} group=* file={fname}
      // :sign unplace {id} buffer={nr}
      // :sign unplace {id} group={group} buffer={nr}
      // :sign unplace {id} group=* buffer={nr}
      sign_unplace(id, group, buf, 0);
    } else {
      if (id == -1) {
        // :sign unplace group={group}
        // :sign unplace group=*
        sign_unplace_at_cursor(group);
      } else {
        // :sign unplace {id}
        // :sign unplace {id} group={group}
        // :sign unplace {id} group=*
        FOR_ALL_BUFFERS(cbuf) {
          sign_unplace(id, group, cbuf, 0);
        }
      }
    }
  }
}

/// Jump to a placed sign commands:
///   :sign jump {id} file={fname}
///   :sign jump {id} buffer={nr}
///   :sign jump {id} group={group} file={fname}
///   :sign jump {id} group={group} buffer={nr}
static void sign_jump_cmd(buf_T *buf, linenr_T lnum, const char *sign_name, int id, char *group)
{
  if (sign_name == NULL && group == NULL && id == -1) {
    emsg(_(e_argreq));
    return;
  }

  if (buf == NULL || (group != NULL && *group == '\0')
      || lnum >= 0 || sign_name != NULL) {
    // File or buffer is not specified or an empty group is used
    // or a line number or a sign name is specified.
    emsg(_(e_invarg));
    return;
  }

  (void)sign_jump(id, group, buf);
}

/// Parse the command line arguments for the ":sign place", ":sign unplace" and
/// ":sign jump" commands.
/// The supported arguments are: line={lnum} name={name} group={group}
/// priority={prio} and file={fname} or buffer={nr}.
static int parse_sign_cmd_args(int cmd, char *arg, char **sign_name, int *signid, char **group,
                               int *prio, buf_T **buf, linenr_T *lnum)
{
  char *arg1;
  char *name;
  char *filename = NULL;
  int lnum_arg = false;

  // first arg could be placed sign id
  arg1 = arg;
  if (ascii_isdigit(*arg)) {
    *signid = getdigits_int(&arg, true, 0);
    if (!ascii_iswhite(*arg) && *arg != NUL) {
      *signid = -1;
      arg = arg1;
    } else {
      arg = skipwhite(arg);
    }
  }

  while (*arg != NUL) {
    if (strncmp(arg, "line=", 5) == 0) {
      arg += 5;
      *lnum = atoi(arg);
      arg = skiptowhite(arg);
      lnum_arg = true;
    } else if (strncmp(arg, "*", 1) == 0 && cmd == SIGNCMD_UNPLACE) {
      if (*signid != -1) {
        emsg(_(e_invarg));
        return FAIL;
      }
      *signid = -2;
      arg = skiptowhite(arg + 1);
    } else if (strncmp(arg, "name=", 5) == 0) {
      arg += 5;
      name = arg;
      arg = skiptowhite(arg);
      if (*arg != NUL) {
        *arg++ = NUL;
      }
      while (name[0] == '0' && name[1] != NUL) {
        name++;
      }
      *sign_name = name;
    } else if (strncmp(arg, "group=", 6) == 0) {
      arg += 6;
      *group = arg;
      arg = skiptowhite(arg);
      if (*arg != NUL) {
        *arg++ = NUL;
      }
    } else if (strncmp(arg, "priority=", 9) == 0) {
      arg += 9;
      *prio = atoi(arg);
      arg = skiptowhite(arg);
    } else if (strncmp(arg, "file=", 5) == 0) {
      arg += 5;
      filename = arg;
      *buf = buflist_findname_exp(arg);
      break;
    } else if (strncmp(arg, "buffer=", 7) == 0) {
      arg += 7;
      filename = arg;
      *buf = buflist_findnr(getdigits_int(&arg, true, 0));
      if (*skipwhite(arg) != NUL) {
        semsg(_(e_trailing_arg), arg);
      }
      break;
    } else {
      emsg(_(e_invarg));
      return FAIL;
    }
    arg = skipwhite(arg);
  }

  if (filename != NULL && *buf == NULL) {
    semsg(_("E158: Invalid buffer name: %s"), filename);
    return FAIL;
  }

  // If the filename is not supplied for the sign place or the sign jump
  // command, then use the current buffer.
  if (filename == NULL && ((cmd == SIGNCMD_PLACE && lnum_arg)
                           || cmd == SIGNCMD_JUMP)) {
    *buf = curwin->w_buffer;
  }
  return OK;
}

/// ":sign" command
void ex_sign(exarg_T *eap)
{
  char *arg = eap->arg;
  char *p;
  int idx;
  sign_T *sp;

  // Parse the subcommand.
  p = skiptowhite(arg);
  idx = sign_cmd_idx(arg, p);
  if (idx == SIGNCMD_LAST) {
    semsg(_("E160: Unknown sign command: %s"), arg);
    return;
  }
  arg = skipwhite(p);

  if (idx <= SIGNCMD_LIST) {
    // Define, undefine or list signs.
    if (idx == SIGNCMD_LIST && *arg == NUL) {
      // ":sign list": list all defined signs
      for (sp = first_sign; sp != NULL && !got_int; sp = sp->sn_next) {
        sign_list_defined(sp);
      }
    } else if (*arg == NUL) {
      emsg(_("E156: Missing sign name"));
    } else {
      char *name;

      // Isolate the sign name.  If it's a number skip leading zeroes,
      // so that "099" and "99" are the same sign.  But keep "0".
      p = skiptowhite(arg);
      if (*p != NUL) {
        *p++ = NUL;
      }
      while (arg[0] == '0' && arg[1] != NUL) {
        arg++;
      }
      name = xstrdup(arg);

      if (idx == SIGNCMD_DEFINE) {
        sign_define_cmd(name, p);
      } else if (idx == SIGNCMD_LIST) {
        // ":sign list {name}"
        sign_list_by_name(name);
      } else {
        // ":sign undefine {name}"
        sign_undefine_by_name(name);
      }

      xfree(name);
      return;
    }
  } else {
    int id = -1;
    linenr_T lnum = -1;
    char *sign_name = NULL;
    char *group = NULL;
    int prio = SIGN_DEF_PRIO;
    buf_T *buf = NULL;

    // Parse command line arguments
    if (parse_sign_cmd_args(idx, arg, &sign_name, &id, &group, &prio,
                            &buf, &lnum) == FAIL) {
      return;
    }

    if (idx == SIGNCMD_PLACE) {
      sign_place_cmd(buf, lnum, sign_name, id, group, prio);
    } else if (idx == SIGNCMD_UNPLACE) {
      sign_unplace_cmd(buf, lnum, sign_name, id, group);
    } else if (idx == SIGNCMD_JUMP) {
      sign_jump_cmd(buf, lnum, sign_name, id, group);
    }
  }
}

/// Return information about a specified sign
static void sign_getinfo(sign_T *sp, dict_T *retdict)
{
  const char *p;

  tv_dict_add_str(retdict, S_LEN("name"), sp->sn_name);
  if (sp->sn_icon != NULL) {
    tv_dict_add_str(retdict, S_LEN("icon"), sp->sn_icon);
  }
  if (sp->sn_text != NULL) {
    tv_dict_add_str(retdict, S_LEN("text"), sp->sn_text);
  }
  if (sp->sn_line_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_line_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("linehl"), p);
  }
  if (sp->sn_text_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_text_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("texthl"), p);
  }
  if (sp->sn_cul_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_cul_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("culhl"), p);
  }
  if (sp->sn_num_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_num_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("numhl"), p);
  }
}

/// If 'name' is NULL, return a list of all the defined signs.
/// Otherwise, return information about the specified sign.
static void sign_getlist(const char *name, list_T *retlist)
{
  sign_T *sp = first_sign;

  if (name != NULL) {
    sp = sign_find(name, NULL);
    if (sp == NULL) {
      return;
    }
  }

  for (; sp != NULL && !got_int; sp = sp->sn_next) {
    dict_T *dict = tv_dict_alloc();
    tv_list_append_dict(retlist, dict);
    sign_getinfo(sp, dict);

    if (name != NULL) {     // handle only the specified sign
      break;
    }
  }
}

/// Returns information about signs placed in a buffer as list of dicts.
list_T *get_buffer_signs(buf_T *buf)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  sign_entry_T *sign;
  list_T *const l = tv_list_alloc(kListLenMayKnow);

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    dict_T *d = sign_get_info(sign);
    tv_list_append_dict(l, d);
  }
  return l;
}

/// @return  information about all the signs placed in a buffer
static void sign_get_placed_in_buf(buf_T *buf, linenr_T lnum, int sign_id, const char *sign_group,
                                   list_T *retlist)
{
  dict_T *d;
  list_T *l;
  sign_entry_T *sign;

  d = tv_dict_alloc();
  tv_list_append_dict(retlist, d);

  tv_dict_add_nr(d, S_LEN("bufnr"), (long)buf->b_fnum);

  l = tv_list_alloc(kListLenMayKnow);
  tv_dict_add_list(d, S_LEN("signs"), l);

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (!sign_in_group(sign, sign_group)) {
      continue;
    }
    if ((lnum == 0 && sign_id == 0)
        || (sign_id == 0 && lnum == sign->se_lnum)
        || (lnum == 0 && sign_id == sign->se_id)
        || (lnum == sign->se_lnum && sign_id == sign->se_id)) {
      tv_list_append_dict(l, sign_get_info(sign));
    }
  }
}

/// Get a list of signs placed in buffer 'buf'. If 'num' is non-zero, return the
/// sign placed at the line number. If 'lnum' is zero, return all the signs
/// placed in 'buf'. If 'buf' is NULL, return signs placed in all the buffers.
static void sign_get_placed(buf_T *buf, linenr_T lnum, int sign_id, const char *sign_group,
                            list_T *retlist)
{
  if (buf != NULL) {
    sign_get_placed_in_buf(buf, lnum, sign_id, sign_group, retlist);
  } else {
    FOR_ALL_BUFFERS(cbuf) {
      if (cbuf->b_signlist != NULL) {
        sign_get_placed_in_buf(cbuf, 0, sign_id, sign_group, retlist);
      }
    }
  }
}

/// List one sign.
static void sign_list_defined(sign_T *sp)
{
  smsg(0, "sign %s", sp->sn_name);
  if (sp->sn_icon != NULL) {
    msg_puts(" icon=");
    msg_outtrans(sp->sn_icon, 0);
    msg_puts(_(" (not supported)"));
  }
  if (sp->sn_text != NULL) {
    msg_puts(" text=");
    msg_outtrans(sp->sn_text, 0);
  }
  if (sp->sn_line_hl > 0) {
    msg_puts(" linehl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_line_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
  if (sp->sn_text_hl > 0) {
    msg_puts(" texthl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_text_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
  if (sp->sn_cul_hl > 0) {
    msg_puts(" culhl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_cul_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
  if (sp->sn_num_hl > 0) {
    msg_puts(" numhl=");
    const char *const p = get_highlight_name_ext(NULL,
                                                 sp->sn_num_hl - 1, false);
    if (p == NULL) {
      msg_puts("NONE");
    } else {
      msg_puts(p);
    }
  }
}

/// Undefine a sign and free its memory.
static void sign_undefine(sign_T *sp, sign_T *sp_prev)
{
  xfree(sp->sn_name);
  xfree(sp->sn_icon);
  xfree(sp->sn_text);
  if (sp_prev == NULL) {
    first_sign = sp->sn_next;
  } else {
    sp_prev->sn_next = sp->sn_next;
  }
  xfree(sp);
}

/// Undefine/free all signs.
void free_signs(void)
{
  while (first_sign != NULL) {
    sign_undefine(first_sign, NULL);
  }
}

static enum {
  EXP_SUBCMD,   // expand :sign sub-commands
  EXP_DEFINE,   // expand :sign define {name} args
  EXP_PLACE,    // expand :sign place {id} args
  EXP_LIST,     // expand :sign place args
  EXP_UNPLACE,  // expand :sign unplace"
  EXP_SIGN_NAMES,   // expand with name of placed signs
  EXP_SIGN_GROUPS,  // expand with name of placed sign groups
} expand_what;

/// @return  the n'th sign name (used for command line completion)
static char *get_nth_sign_name(int idx)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Complete with name of signs already defined
  int current_idx = 0;
  for (sign_T *sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (current_idx++ == idx) {
      return sp->sn_name;
    }
  }
  return NULL;
}

/// @return  the n'th sign group name (used for command line completion)
static char *get_nth_sign_group_name(int idx)
{
  // Complete with name of sign groups already defined
  int current_idx = 0;
  int todo = (int)sg_table.ht_used;
  for (hashitem_T *hi = sg_table.ht_array; todo > 0; hi++) {
    if (!HASHITEM_EMPTY(hi)) {
      todo--;
      if (current_idx++ == idx) {
        signgroup_T *const group = HI2SG(hi);
        return group->sg_name;
      }
    }
  }
  return NULL;
}

/// Function given to ExpandGeneric() to obtain the sign command
/// expansion.
char *get_sign_name(expand_T *xp, int idx)
{
  switch (expand_what) {
  case EXP_SUBCMD:
    return cmds[idx];
  case EXP_DEFINE: {
    char *define_arg[] = { "culhl=", "icon=", "linehl=", "numhl=", "text=", "texthl=",
                           NULL };
    return define_arg[idx];
  }
  case EXP_PLACE: {
    char *place_arg[] = { "line=", "name=", "group=", "priority=", "file=",
                          "buffer=", NULL };
    return place_arg[idx];
  }
  case EXP_LIST: {
    char *list_arg[] = { "group=", "file=", "buffer=", NULL };
    return list_arg[idx];
  }
  case EXP_UNPLACE: {
    char *unplace_arg[] = { "group=", "file=", "buffer=", NULL };
    return unplace_arg[idx];
  }
  case EXP_SIGN_NAMES:
    return get_nth_sign_name(idx);
  case EXP_SIGN_GROUPS:
    return get_nth_sign_group_name(idx);
  default:
    return NULL;
  }
}

/// Handle command line completion for :sign command.
void set_context_in_sign_cmd(expand_T *xp, char *arg)
{
  char *end_subcmd;
  char *last;
  int cmd_idx;
  char *begin_subcmd_args;

  // Default: expand subcommands.
  xp->xp_context = EXPAND_SIGN;
  expand_what = EXP_SUBCMD;
  xp->xp_pattern = arg;

  end_subcmd = skiptowhite(arg);
  if (*end_subcmd == NUL) {
    // expand subcmd name
    // :sign {subcmd}<CTRL-D>
    return;
  }

  cmd_idx = sign_cmd_idx(arg, end_subcmd);

  // :sign {subcmd} {subcmd_args}
  //                |
  //                begin_subcmd_args
  begin_subcmd_args = skipwhite(end_subcmd);

  // Expand last argument of subcmd.
  //
  // :sign define {name} {args}...
  //              |
  //              p

  // Loop until reaching last argument.
  char *p = begin_subcmd_args;
  do {
    p = skipwhite(p);
    last = p;
    p = skiptowhite(p);
  } while (*p != NUL);

  p = vim_strchr(last, '=');

  // :sign define {name} {args}... {last}=
  //                               |     |
  //                            last     p
  if (p == NULL) {
    // Expand last argument name (before equal sign).
    xp->xp_pattern = last;
    switch (cmd_idx) {
    case SIGNCMD_DEFINE:
      expand_what = EXP_DEFINE;
      break;
    case SIGNCMD_PLACE:
      // List placed signs
      if (ascii_isdigit(*begin_subcmd_args)) {
        //   :sign place {id} {args}...
        expand_what = EXP_PLACE;
      } else {
        //   :sign place {args}...
        expand_what = EXP_LIST;
      }
      break;
    case SIGNCMD_LIST:
    case SIGNCMD_UNDEFINE:
      // :sign list <CTRL-D>
      // :sign undefine <CTRL-D>
      expand_what = EXP_SIGN_NAMES;
      break;
    case SIGNCMD_JUMP:
    case SIGNCMD_UNPLACE:
      expand_what = EXP_UNPLACE;
      break;
    default:
      xp->xp_context = EXPAND_NOTHING;
    }
  } else {
    // Expand last argument value (after equal sign).
    xp->xp_pattern = p + 1;
    switch (cmd_idx) {
    case SIGNCMD_DEFINE:
      if (strncmp(last, "texthl", 6) == 0
          || strncmp(last, "linehl", 6) == 0
          || strncmp(last, "culhl", 5) == 0
          || strncmp(last, "numhl", 5) == 0) {
        xp->xp_context = EXPAND_HIGHLIGHT;
      } else if (strncmp(last, "icon", 4) == 0) {
        xp->xp_context = EXPAND_FILES;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
      break;
    case SIGNCMD_PLACE:
      if (strncmp(last, "name", 4) == 0) {
        expand_what = EXP_SIGN_NAMES;
      } else if (strncmp(last, "group", 5) == 0) {
        expand_what = EXP_SIGN_GROUPS;
      } else if (strncmp(last, "file", 4) == 0) {
        xp->xp_context = EXPAND_BUFFERS;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
      break;
    case SIGNCMD_UNPLACE:
    case SIGNCMD_JUMP:
      if (strncmp(last, "group", 5) == 0) {
        expand_what = EXP_SIGN_GROUPS;
      } else if (strncmp(last, "file", 4) == 0) {
        xp->xp_context = EXPAND_BUFFERS;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
      break;
    default:
      xp->xp_context = EXPAND_NOTHING;
    }
  }
}

/// Define a sign using the attributes in 'dict'. Returns 0 on success and -1 on
/// failure.
static int sign_define_from_dict(const char *name_arg, dict_T *dict)
{
  char *name = NULL;
  char *icon = NULL;
  char *linehl = NULL;
  char *text = NULL;
  char *texthl = NULL;
  char *culhl = NULL;
  char *numhl = NULL;
  int retval = -1;

  if (name_arg == NULL) {
    if (dict == NULL) {
      return -1;
    }
    name = tv_dict_get_string(dict, "name", true);
  } else {
    name = xstrdup(name_arg);
  }
  if (name == NULL || name[0] == NUL) {
    goto cleanup;
  }
  if (dict != NULL) {
    icon   = tv_dict_get_string(dict, "icon", true);
    linehl = tv_dict_get_string(dict, "linehl", true);
    text   = tv_dict_get_string(dict, "text", true);
    texthl = tv_dict_get_string(dict, "texthl", true);
    culhl  = tv_dict_get_string(dict, "culhl", true);
    numhl  = tv_dict_get_string(dict, "numhl", true);
  }

  if (sign_define_by_name(name, icon, linehl,
                          text, texthl, culhl, numhl)
      == OK) {
    retval = 0;
  }

cleanup:
  xfree(name);
  xfree(icon);
  xfree(linehl);
  xfree(text);
  xfree(texthl);
  xfree(culhl);
  xfree(numhl);

  return retval;
}

/// Define multiple signs using attributes from list 'l' and store the return
/// values in 'retlist'.
static void sign_define_multiple(list_T *l, list_T *retlist)
{
  int retval;

  TV_LIST_ITER_CONST(l, li, {
    retval = -1;
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_DICT) {
      retval = sign_define_from_dict(NULL, TV_LIST_ITEM_TV(li)->vval.v_dict);
    } else {
      emsg(_(e_dictreq));
    }
    tv_list_append_number(retlist, retval);
  });
}

/// "sign_define()" function
void f_sign_define(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *name;

  if (argvars[0].v_type == VAR_LIST && argvars[1].v_type == VAR_UNKNOWN) {
    // Define multiple signs
    tv_list_alloc_ret(rettv, kListLenMayKnow);

    sign_define_multiple(argvars[0].vval.v_list, rettv->vval.v_list);
    return;
  }

  // Define a single sign
  rettv->vval.v_number = -1;

  name = tv_get_string_chk(&argvars[0]);
  if (name == NULL) {
    return;
  }

  if (tv_check_for_opt_dict_arg(argvars, 1) == FAIL) {
    return;
  }

  rettv->vval.v_number = sign_define_from_dict(name,
                                               argvars[1].v_type ==
                                               VAR_DICT ? argvars[1].vval.v_dict : NULL);
}

/// "sign_getdefined()" function
void f_sign_getdefined(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *name = NULL;

  tv_list_alloc_ret(rettv, 0);

  if (argvars[0].v_type != VAR_UNKNOWN) {
    name = tv_get_string(&argvars[0]);
  }

  sign_getlist(name, rettv->vval.v_list);
}

/// "sign_getplaced()" function
void f_sign_getplaced(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_T *buf = NULL;
  dictitem_T *di;
  linenr_T lnum = 0;
  int sign_id = 0;
  const char *group = NULL;
  bool notanum = false;

  tv_list_alloc_ret(rettv, 0);

  if (argvars[0].v_type != VAR_UNKNOWN) {
    // get signs placed in the specified buffer
    buf = get_buf_arg(&argvars[0]);
    if (buf == NULL) {
      return;
    }

    if (argvars[1].v_type != VAR_UNKNOWN) {
      if (tv_check_for_nonnull_dict_arg(argvars, 1) == FAIL) {
        return;
      }
      dict_T *dict = argvars[1].vval.v_dict;
      if ((di = tv_dict_find(dict, "lnum", -1)) != NULL) {
        // get signs placed at this line
        lnum = (linenr_T)tv_get_number_chk(&di->di_tv, &notanum);
        if (notanum) {
          return;
        }
        (void)lnum;
        lnum = tv_get_lnum(&di->di_tv);
      }
      if ((di = tv_dict_find(dict, "id", -1)) != NULL) {
        // get sign placed with this identifier
        sign_id = (int)tv_get_number_chk(&di->di_tv, &notanum);
        if (notanum) {
          return;
        }
      }
      if ((di = tv_dict_find(dict, "group", -1)) != NULL) {
        group = tv_get_string_chk(&di->di_tv);
        if (group == NULL) {
          return;
        }
        if (*group == '\0') {  // empty string means global group
          group = NULL;
        }
      }
    }
  }

  sign_get_placed(buf, lnum, sign_id, group, rettv->vval.v_list);
}

/// "sign_jump()" function
void f_sign_jump(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int sign_id;
  char *sign_group = NULL;
  buf_T *buf;
  bool notanum = false;

  rettv->vval.v_number = -1;

  // Sign identifier
  sign_id = (int)tv_get_number_chk(&argvars[0], &notanum);
  if (notanum) {
    return;
  }
  if (sign_id <= 0) {
    emsg(_(e_invarg));
    return;
  }

  // Sign group
  const char *sign_group_chk = tv_get_string_chk(&argvars[1]);
  if (sign_group_chk == NULL) {
    return;
  }
  if (sign_group_chk[0] == '\0') {
    sign_group = NULL;  // global sign group
  } else {
    sign_group = xstrdup(sign_group_chk);
  }

  // Buffer to place the sign
  buf = get_buf_arg(&argvars[2]);
  if (buf == NULL) {
    goto cleanup;
  }

  rettv->vval.v_number = sign_jump(sign_id, sign_group, buf);

cleanup:
  xfree(sign_group);
}

/// Place a new sign using the values specified in dict 'dict'. Returns the sign
/// identifier if successfully placed, otherwise returns 0.
static int sign_place_from_dict(typval_T *id_tv, typval_T *group_tv, typval_T *name_tv,
                                typval_T *buf_tv, dict_T *dict)
{
  int sign_id = 0;
  char *group = NULL;
  const char *sign_name = NULL;
  buf_T *buf = NULL;
  dictitem_T *di;
  linenr_T lnum = 0;
  int prio = SIGN_DEF_PRIO;
  bool notanum = false;
  int ret_sign_id = -1;

  // sign identifier
  if (id_tv == NULL) {
    di = tv_dict_find(dict, "id", -1);
    if (di != NULL) {
      id_tv = &di->di_tv;
    }
  }
  if (id_tv == NULL) {
    sign_id = 0;
  } else {
    sign_id = (int)tv_get_number_chk(id_tv, &notanum);
    if (notanum) {
      return -1;
    }
    if (sign_id < 0) {
      emsg(_(e_invarg));
      return -1;
    }
  }

  // sign group
  if (group_tv == NULL) {
    di = tv_dict_find(dict, "group", -1);
    if (di != NULL) {
      group_tv = &di->di_tv;
    }
  }
  if (group_tv == NULL) {
    group = NULL;  // global group
  } else {
    group = (char *)tv_get_string_chk(group_tv);
    if (group == NULL) {
      goto cleanup;
    }
    if (group[0] == '\0') {  // global sign group
      group = NULL;
    } else {
      group = xstrdup(group);
    }
  }

  // sign name
  if (name_tv == NULL) {
    di = tv_dict_find(dict, "name", -1);
    if (di != NULL) {
      name_tv = &di->di_tv;
    }
  }
  if (name_tv == NULL) {
    goto cleanup;
  }
  sign_name = tv_get_string_chk(name_tv);
  if (sign_name == NULL) {
    goto cleanup;
  }

  // buffer to place the sign
  if (buf_tv == NULL) {
    di = tv_dict_find(dict, "buffer", -1);
    if (di != NULL) {
      buf_tv = &di->di_tv;
    }
  }
  if (buf_tv == NULL) {
    goto cleanup;
  }
  buf = get_buf_arg(buf_tv);
  if (buf == NULL) {
    goto cleanup;
  }

  // line number of the sign
  di = tv_dict_find(dict, "lnum", -1);
  if (di != NULL) {
    lnum = tv_get_lnum(&di->di_tv);
    if (lnum <= 0) {
      emsg(_(e_invarg));
      goto cleanup;
    }
  }

  // sign priority
  di = tv_dict_find(dict, "priority", -1);
  if (di != NULL) {
    prio = (int)tv_get_number_chk(&di->di_tv, &notanum);
    if (notanum) {
      goto cleanup;
    }
  }

  if (sign_place(&sign_id, group, sign_name, buf, lnum, prio) == OK) {
    ret_sign_id = sign_id;
  }

cleanup:
  xfree(group);

  return ret_sign_id;
}

/// "sign_place()" function
void f_sign_place(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  dict_T *dict = NULL;

  rettv->vval.v_number = -1;

  if (argvars[4].v_type != VAR_UNKNOWN) {
    if (tv_check_for_nonnull_dict_arg(argvars, 4) == FAIL) {
      return;
    }
    dict = argvars[4].vval.v_dict;
  }

  rettv->vval.v_number = sign_place_from_dict(&argvars[0], &argvars[1], &argvars[2], &argvars[3],
                                              dict);
}

/// "sign_placelist()" function.  Place multiple signs.
void f_sign_placelist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int sign_id;

  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }

  // Process the List of sign attributes
  TV_LIST_ITER_CONST(argvars[0].vval.v_list, li, {
    sign_id = -1;
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_DICT) {
      sign_id = sign_place_from_dict(NULL, NULL, NULL, NULL, TV_LIST_ITEM_TV(li)->vval.v_dict);
    } else {
      emsg(_(e_dictreq));
    }
    tv_list_append_number(rettv->vval.v_list, sign_id);
  });
}

/// Undefine multiple signs
static void sign_undefine_multiple(list_T *l, list_T *retlist)
{
  char *name;
  int retval;

  TV_LIST_ITER_CONST(l, li, {
    retval = -1;
    name = (char *)tv_get_string_chk(TV_LIST_ITEM_TV(li));
    if (name != NULL && (sign_undefine_by_name(name) == OK)) {
      retval = 0;
    }
    tv_list_append_number(retlist, retval);
  });
}

/// "sign_undefine()" function
void f_sign_undefine(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (argvars[0].v_type == VAR_LIST && argvars[1].v_type == VAR_UNKNOWN) {
    // Undefine multiple signs
    tv_list_alloc_ret(rettv, kListLenMayKnow);

    sign_undefine_multiple(argvars[0].vval.v_list, rettv->vval.v_list);
    return;
  }

  rettv->vval.v_number = -1;

  if (argvars[0].v_type == VAR_UNKNOWN) {
    // Free all the signs
    free_signs();
    rettv->vval.v_number = 0;
  } else {
    // Free only the specified sign
    const char *name = tv_get_string_chk(&argvars[0]);
    if (name == NULL) {
      return;
    }

    if (sign_undefine_by_name(name) == OK) {
      rettv->vval.v_number = 0;
    }
  }
}

/// Unplace the sign with attributes specified in 'dict'. Returns 0 on success
/// and -1 on failure.
static int sign_unplace_from_dict(typval_T *group_tv, dict_T *dict)
{
  dictitem_T *di;
  int sign_id = 0;
  buf_T *buf = NULL;
  char *group = NULL;
  int retval = -1;

  // sign group
  if (group_tv != NULL) {
    group = (char *)tv_get_string(group_tv);
  } else {
    group = tv_dict_get_string(dict, "group", false);
  }
  if (group != NULL) {
    if (group[0] == '\0') {  // global sign group
      group = NULL;
    } else {
      group = xstrdup(group);
    }
  }

  if (dict != NULL) {
    if ((di = tv_dict_find(dict, "buffer", -1)) != NULL) {
      buf = get_buf_arg(&di->di_tv);
      if (buf == NULL) {
        goto cleanup;
      }
    }
    if (tv_dict_find(dict, "id", -1) != NULL) {
      sign_id = (int)tv_dict_get_number(dict, "id");
      if (sign_id <= 0) {
        emsg(_(e_invarg));
        goto cleanup;
      }
    }
  }

  if (buf == NULL) {
    // Delete the sign in all the buffers
    retval = 0;
    FOR_ALL_BUFFERS(buf2) {
      if (sign_unplace(sign_id, group, buf2, 0) != OK) {
        retval = -1;
      }
    }
  } else if (sign_unplace(sign_id, group, buf, 0) == OK) {
    retval = 0;
  }

cleanup:
  xfree(group);

  return retval;
}

/// "sign_unplace()" function
void f_sign_unplace(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  dict_T *dict = NULL;

  rettv->vval.v_number = -1;

  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_opt_dict_arg(argvars, 1) == FAIL) {
    return;
  }

  if (argvars[1].v_type != VAR_UNKNOWN) {
    dict = argvars[1].vval.v_dict;
  }

  rettv->vval.v_number = sign_unplace_from_dict(&argvars[0], dict);
}

/// "sign_unplacelist()" function
void f_sign_unplacelist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int retval;

  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }

  TV_LIST_ITER_CONST(argvars[0].vval.v_list, li, {
    retval = -1;
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_DICT) {
      retval = sign_unplace_from_dict(NULL, TV_LIST_ITEM_TV(li)->vval.v_dict);
    } else {
      emsg(_(e_dictreq));
    }
    tv_list_append_number(rettv->vval.v_list, retval);
  });
}
