// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// sign.c: functions for managing with signs
//


#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/ex_docmd.h"
#include "nvim/fold.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/sign.h"
#include "nvim/syntax.h"
#include "nvim/vim.h"

/// Struct to hold the sign properties.
typedef struct sign sign_T;

struct sign
{
  sign_T *sn_next;       // next sign in list
  int sn_typenr;      // type number of sign
  char_u *sn_name;       // name of sign
  char_u *sn_icon;       // name of pixmap
  char_u *sn_text;       // text used instead of pixmap
  int sn_line_hl;     // highlight ID for line
  int sn_text_hl;     // highlight ID for text
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
///
static signgroup_T *sign_group_ref(const char_u *groupname)
{
  hash_T hash;
  hashitem_T *hi;
  signgroup_T *group;

  hash = hash_hash(groupname);
  hi = hash_lookup(&sg_table, (char *)groupname, STRLEN(groupname), hash);
  if (HASHITEM_EMPTY(hi)) {
    // new group
    group = xmalloc((unsigned)(sizeof(signgroup_T) + STRLEN(groupname)));

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
static void sign_group_unref(char_u *groupname)
{
  hashitem_T *hi;
  signgroup_T *group;

  hi = hash_find(&sg_table, groupname);
  if (!HASHITEM_EMPTY(hi)) {
    group = HI2SG(hi);
    group->sg_refcount--;
    if (group->sg_refcount == 0) {
      // All the signs in this group are removed
      hash_remove(&sg_table, hi);
      xfree(group);
    }
  }
}

/// @return true if 'sign' is in 'group'.
/// A sign can either be in the global group (sign->group == NULL)
/// or in a named group. If 'group' is '*', then the sign is part of the group.
bool sign_in_group(sign_entry_T *sign, const char_u *group)
{
  return ((group != NULL && STRCMP(group, "*") == 0)
          || (group == NULL && sign->se_group == NULL)
          || (group != NULL && sign->se_group != NULL
              && STRCMP(group, sign->se_group->sg_name) == 0));
}

/// Get the next free sign identifier in the specified group
int sign_group_get_next_signid(buf_T *buf, const char_u *groupname)
{
  int id = 1;
  signgroup_T *group = NULL;
  sign_entry_T *sign;
  hashitem_T *hi;
  int found = false;

  if (groupname != NULL) {
    hi = hash_find(&sg_table, groupname);
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
                        const char_u *group, int prio, linenr_T lnum, int typenr,
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
  buf->b_signcols_valid = false;

  if (prev == NULL) {
    // When adding first sign need to redraw the windows to create the
    // column for signs.
    if (buf->b_signlist == NULL) {
      redraw_buf_later(buf, NOT_VALID);
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
static void insert_sign_by_lnum_prio(buf_T *buf, sign_entry_T *prev, int id, const char_u *group,
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

/// Get the name of a sign by its typenr.
char_u *sign_typenr2name(int typenr)
{
  sign_T *sp;

  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (sp->sn_typenr == typenr) {
      return sp->sn_name;
    }
  }
  return (char_u *)_("[Deleted]");
}

/// Return information about a sign in a Dict
dict_T *sign_get_info(sign_entry_T *sign)
{
  dict_T *d = tv_dict_alloc();
  tv_dict_add_nr(d,  S_LEN("id"), sign->se_id);
  tv_dict_add_str(d, S_LEN("group"), ((sign->se_group == NULL)
                                      ? (char *)""
                                      : (char *)sign->se_group->sg_name));
  tv_dict_add_nr(d,  S_LEN("lnum"), sign->se_lnum);
  tv_dict_add_str(d, S_LEN("name"), (char *)sign_typenr2name(sign->se_typenr));
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
void buf_addsign(buf_T *buf, int id, const char_u *groupname, int prio, linenr_T lnum, int typenr,
                 bool has_text_or_icon)
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
linenr_T buf_change_sign_type(buf_T *buf, int markId, const char_u *group, int typenr, int prio)
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
sign_attrs_T *sign_get_attr(SignType type, sign_attrs_T sattrs[], int idx, int max_signs)
{
  sign_attrs_T *matches[SIGN_SHOW_MAX];
  int nr_matches = 0;

  for (int i = 0; i < SIGN_SHOW_MAX; i++) {
    if (   (type == SIGN_TEXT   && sattrs[i].sat_text   != NULL)
           || (type == SIGN_LINEHL && sattrs[i].sat_linehl != 0)
           || (type == SIGN_NUMHL  && sattrs[i].sat_numhl  != 0)) {
      matches[nr_matches] = &sattrs[i];
      nr_matches++;
      // attr list is sorted with most important (priority, id), thus we
      // may stop as soon as we have max_signs matches
      if (nr_matches >= max_signs) {
        break;
      }
    }
  }

  if (nr_matches > idx) {
    return matches[nr_matches - idx - 1];
  }

  return NULL;
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

/// Return the attributes of all the signs placed on line 'lnum' in buffer
/// 'buf'. Used when refreshing the screen. Returns the number of signs.
/// @param buf Buffer in which to search
/// @param lnum Line in which to search
/// @param sattrs Output array for attrs
/// @return Number of signs of which attrs were found
int buf_get_signattrs(buf_T *buf, linenr_T lnum, sign_attrs_T sattrs[])
{
  sign_entry_T *sign;
  sign_T *sp;

  int nr_matches = 0;

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    if (sign->se_lnum > lnum) {
      // Signs are sorted by line number in the buffer. No need to check
      // for signs after the specified line number 'lnum'.
      break;
    }

    if (sign->se_lnum == lnum) {
      sign_attrs_T sattr;
      memset(&sattr, 0, sizeof(sattr));
      sattr.sat_typenr = sign->se_typenr;
      sp = find_sign_by_typenr(sign->se_typenr);
      if (sp != NULL) {
        sattr.sat_text = sp->sn_text;
        if (sattr.sat_text != NULL && sp->sn_text_hl != 0) {
          sattr.sat_texthl = syn_id2attr(sp->sn_text_hl);
        }
        if (sp->sn_line_hl != 0) {
          sattr.sat_linehl = syn_id2attr(sp->sn_line_hl);
        }
        if (sp->sn_num_hl != 0) {
          sattr.sat_numhl = syn_id2attr(sp->sn_num_hl);
        }
      }

      sattrs[nr_matches] = sattr;
      nr_matches++;
      if (nr_matches == SIGN_SHOW_MAX) {
        break;
      }
    }
  }
  return nr_matches;
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
linenr_T buf_delsign(buf_T *buf, linenr_T atlnum, int id, char_u *group)
{
  sign_entry_T **lastp;  // pointer to pointer to current sign
  sign_entry_T *sign;    // a sign in a b_signlist
  sign_entry_T *next;    // the next sign in a b_signlist
  linenr_T lnum;       // line number whose sign was deleted

  buf->b_signcols_valid = false;
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
      if (sign->se_group != NULL) {
        sign_group_unref(sign->se_group->sg_name);
      }
      xfree(sign);
      redraw_buf_line_later(buf, lnum);
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
    redraw_buf_later(buf, NOT_VALID);
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
int buf_findsign(buf_T *buf, int id, char_u *group)
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
static sign_entry_T *buf_getsign_at_line(buf_T *buf, linenr_T lnum, char_u *groupname)
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
int buf_findsign_id(buf_T *buf, linenr_T lnum, char_u *groupname)
{
  sign_entry_T *sign;   // a sign in the signlist

  sign = buf_getsign_at_line(buf, lnum, groupname);
  if (sign != NULL) {
    return sign->se_id;
  }

  return 0;
}

/// Delete signs in buffer "buf".
void buf_delete_signs(buf_T *buf, char_u *group)
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
  buf->b_signcols_valid = false;
}

/// List placed signs for "rbuf".  If "rbuf" is NULL do it for all buffers.
void sign_list_placed(buf_T *rbuf, char_u *sign_group)
{
  buf_T *buf;
  sign_entry_T *sign;
  char lbuf[MSG_BUF_LEN];
  char group[MSG_BUF_LEN];

  MSG_PUTS_TITLE(_("\n--- Signs ---"));
  msg_putchar('\n');
  if (rbuf == NULL) {
    buf = firstbuf;
  } else {
    buf = rbuf;
  }
  while (buf != NULL && !got_int) {
    if (buf->b_signlist != NULL) {
      vim_snprintf(lbuf, MSG_BUF_LEN, _("Signs for %s:"), buf->b_fname);
      MSG_PUTS_ATTR(lbuf, HL_ATTR(HLF_D));
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
      MSG_PUTS(lbuf);
      msg_putchar('\n');
    }
    if (rbuf != NULL) {
      break;
    }
    buf = buf->b_next;
  }
}

/// Adjust a placed sign for inserted/deleted lines.
void sign_mark_adjust(linenr_T line1, linenr_T line2, long amount, long amount_after)
{
  sign_entry_T *sign;           // a sign in a b_signlist
  sign_entry_T *next;           // the next sign in a b_signlist
  sign_entry_T *last = NULL;    // pointer to pointer to current sign
  sign_entry_T **lastp = NULL;  // pointer to pointer to current sign
  linenr_T new_lnum;            // new line number to assign to sign
  int is_fixed = 0;
  int signcol = win_signcol_configured(curwin, &is_fixed);

  curbuf->b_signcols_valid = false;
  lastp = &curbuf->b_signlist;

  for (sign = curbuf->b_signlist; sign != NULL; sign = next) {
    next = sign->se_next;
    new_lnum = sign->se_lnum;
    if (sign->se_lnum >= line1 && sign->se_lnum <= line2) {
      if (amount != MAXLNUM) {
        new_lnum += amount;
      } else if (!is_fixed || signcol >= 2) {
        *lastp = next;
        if (next) {
          next->se_prev = last;
        }
        xfree(sign);
        continue;
      }
    } else if (sign->se_lnum > line2) {
      new_lnum += amount_after;
    }
    // If the new sign line number is past the last line in the buffer,
    // then don't adjust the line number. Otherwise, it will always be past
    // the last line and will not be visible.
    if (sign->se_lnum >= line1 && new_lnum <= curbuf->b_ml.ml_line_count) {
      sign->se_lnum = new_lnum;
    }

    last = sign;
    lastp = &sign->se_next;
  }
}

/// Find index of a ":sign" subcmd from its name.
/// "*end_cmd" must be writable.
///
/// @param begin_cmd  begin of sign subcmd
/// @param end_cmd  just after sign subcmd
static int sign_cmd_idx(char_u *begin_cmd, char_u *end_cmd)
{
  int idx;
  char_u save = *end_cmd;

  *end_cmd = (char_u)NUL;
  for (idx = 0; ; idx++) {
    if (cmds[idx] == NULL || STRCMP(begin_cmd, cmds[idx]) == 0) {
      break;
    }
  }
  *end_cmd = save;
  return idx;
}

/// Find a sign by name. Also returns pointer to the previous sign.
static sign_T *sign_find(const char_u *name, sign_T **sp_prev)
{
  sign_T *sp;

  if (sp_prev != NULL) {
    *sp_prev = NULL;
  }
  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (STRCMP(sp->sn_name, name) == 0) {
      break;
    }
    if (sp_prev != NULL) {
      *sp_prev = sp;
    }
  }

  return sp;
}

/// Allocate a new sign
static sign_T *alloc_new_sign(char_u *name)
{
  sign_T *sp;
  sign_T *lp;
  int start = next_sign_typenr;

  // Allocate a new sign.
  sp = xcalloc(1, sizeof(sign_T));

  // Check that next_sign_typenr is not already being used.
  // This only happens after wrapping around.  Hopefully
  // another one got deleted and we can use its number.
  for (lp = first_sign; lp != NULL; ) {
    if (lp->sn_typenr == next_sign_typenr) {
      next_sign_typenr++;
      if (next_sign_typenr == MAX_TYPENR) {
        next_sign_typenr = 1;
      }
      if (next_sign_typenr == start) {
        xfree(sp);
        EMSG(_("E612: Too many signs defined"));
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

  sp->sn_name = vim_strsave(name);

  return sp;
}

/// Initialize the icon information for a new sign
static void sign_define_init_icon(sign_T *sp, char_u *icon)
{
  xfree(sp->sn_icon);
  sp->sn_icon = vim_strsave(icon);
  backslash_halve(sp->sn_icon);
}

/// Initialize the text for a new sign
static int sign_define_init_text(sign_T *sp, char_u *text)
{
  char_u *s;
  char_u *endp;
  int cells;
  size_t len;

  endp = text + (int)STRLEN(text);
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
  for (s = text; s < endp; s += (*mb_ptr2len)(s)) {
    if (!vim_isprintc(utf_ptr2char(s))) {
      break;
    }
    cells += utf_ptr2cells(s);
  }
  // Currently must be empty, one or two display cells
  if (s != endp || cells > 2) {
    EMSG2(_("E239: Invalid sign text: %s"), text);
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
  sp->sn_text = vim_strnsave(text, len);

  if (cells == 1) {
    STRCPY(sp->sn_text + len - 1, " ");
  }

  return OK;
}

/// Define a new sign or update an existing sign
int sign_define_by_name(char_u *name, char_u *icon, char_u *linehl, char_u *text, char_u *texthl,
                        char_u *numhl)
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
        redraw_buf_later(wp->w_buffer, NOT_VALID);
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
    sp->sn_line_hl = syn_check_group(linehl, (int)STRLEN(linehl));
  }

  if (texthl != NULL) {
    sp->sn_text_hl = syn_check_group(texthl, (int)STRLEN(texthl));
  }

  if (numhl != NULL) {
    sp->sn_num_hl = syn_check_group(numhl, (int)STRLEN(numhl));
  }

  return OK;
}

/// Free the sign specified by 'name'.
int sign_undefine_by_name(const char_u *name)
{
  sign_T *sp_prev;
  sign_T *sp;

  sp = sign_find(name, &sp_prev);
  if (sp == NULL) {
    EMSG2(_("E155: Unknown sign: %s"), name);
    return FAIL;
  }
  sign_undefine(sp, sp_prev);

  return OK;
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

/// List the signs matching 'name'
static void sign_list_by_name(char_u *name)
{
  sign_T *sp;

  sp = sign_find(name, NULL);
  if (sp != NULL) {
    sign_list_defined(sp);
  } else {
    EMSG2(_("E155: Unknown sign: %s"), name);
  }
}


/// Place a sign at the specified file location or update a sign.
int sign_place(int *sign_id, const char_u *sign_group, const char_u *sign_name, buf_T *buf,
               linenr_T lnum, int prio)
{
  sign_T *sp;

  // Check for reserved character '*' in group name
  if (sign_group != NULL && (*sign_group == '*' || *sign_group == '\0')) {
    return FAIL;
  }

  for (sp = first_sign; sp != NULL; sp = sp->sn_next) {
    if (STRCMP(sp->sn_name, sign_name) == 0) {
      break;
    }
  }
  if (sp == NULL) {
    EMSG2(_("E155: Unknown sign: %s"), sign_name);
    return FAIL;
  }
  if (*sign_id == 0) {
    *sign_id = sign_group_get_next_signid(buf, sign_group);
  }

  if (lnum > 0) {
    // ":sign place {id} line={lnum} name={name} file={fname}":
    // place a sign
    bool has_text_or_icon = sp->sn_text != NULL || sp->sn_icon != NULL;
    buf_addsign(buf,
                *sign_id,
                sign_group,
                prio,
                lnum,
                sp->sn_typenr,
                has_text_or_icon);
  } else {
    // ":sign place {id} file={fname}": change sign type and/or priority
    lnum = buf_change_sign_type(buf, *sign_id, sign_group, sp->sn_typenr, prio);
  }
  if (lnum > 0) {
    redraw_buf_line_later(buf, lnum);

    // When displaying signs in the 'number' column, if the width of the
    // number column is less than 2, then force recomputing the width.
    may_force_numberwidth_recompute(buf, false);
  } else {
    EMSG2(_("E885: Not possible to change sign %s"), sign_name);
    return FAIL;
  }

  return OK;
}

/// Unplace the specified sign
int sign_unplace(int sign_id, char_u *sign_group, buf_T *buf, linenr_T atlnum)
{
  if (buf->b_signlist == NULL) {  // No signs in the buffer
    return OK;
  }
  if (sign_id == 0) {
    // Delete all the signs in the specified buffer
    redraw_buf_later(buf, NOT_VALID);
    buf_delete_signs(buf, sign_group);
  } else {
    linenr_T lnum;

    // Delete only the specified signs
    lnum = buf_delsign(buf, atlnum, sign_id, sign_group);
    if (lnum == 0) {
      return FAIL;
    }
    redraw_buf_line_later(buf, lnum);
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
static void sign_unplace_at_cursor(char_u *groupname)
{
  int id = -1;

  id = buf_findsign_id(curwin->w_buffer, curwin->w_cursor.lnum, groupname);
  if (id > 0) {
    sign_unplace(id, groupname, curwin->w_buffer, curwin->w_cursor.lnum);
  } else {
    EMSG(_("E159: Missing sign number"));
  }
}

/// Jump to a sign.
linenr_T sign_jump(int sign_id, char_u *sign_group, buf_T *buf)
{
  linenr_T lnum;

  if ((lnum = buf_findsign(buf, sign_id, sign_group)) <= 0) {
    EMSGN(_("E157: Invalid sign ID: %" PRId64), sign_id);
    return -1;
  }

  // goto a sign ...
  if (buf_jump_open_win(buf) != NULL) {     // ... in a current window
    curwin->w_cursor.lnum = lnum;
    check_cursor_lnum();
    beginline(BL_WHITE);
  } else {      // ... not currently in a window
    if (buf->b_fname == NULL) {
      EMSG(_("E934: Cannot jump to a buffer that does not have a name"));
      return -1;
    }
    size_t cmdlen = STRLEN(buf->b_fname) + 24;
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
static void sign_define_cmd(char_u *sign_name, char_u *cmdline)
{
  char_u *arg;
  char_u *p = cmdline;
  char_u *icon = NULL;
  char_u *text = NULL;
  char_u *linehl = NULL;
  char_u *texthl = NULL;
  char_u *numhl = NULL;
  int failed = false;

  // set values for a defined sign.
  for (;;) {
    arg = skipwhite(p);
    if (*arg == NUL) {
      break;
    }
    p = skiptowhite_esc(arg);
    if (STRNCMP(arg, "icon=", 5) == 0) {
      arg += 5;
      icon = vim_strnsave(arg, (size_t)(p - arg));
    } else if (STRNCMP(arg, "text=", 5) == 0) {
      arg += 5;
      text = vim_strnsave(arg, (size_t)(p - arg));
    } else if (STRNCMP(arg, "linehl=", 7) == 0) {
      arg += 7;
      linehl = vim_strnsave(arg, (size_t)(p - arg));
    } else if (STRNCMP(arg, "texthl=", 7) == 0) {
      arg += 7;
      texthl = vim_strnsave(arg, (size_t)(p - arg));
    } else if (STRNCMP(arg, "numhl=", 6) == 0) {
      arg += 6;
      numhl = vim_strnsave(arg, (size_t)(p - arg));
    } else {
      EMSG2(_(e_invarg2), arg);
      failed = true;
      break;
    }
  }

  if (!failed) {
    sign_define_by_name(sign_name, icon, linehl, text, texthl, numhl);
  }

  xfree(icon);
  xfree(text);
  xfree(linehl);
  xfree(texthl);
  xfree(numhl);
}

/// ":sign place" command
static void sign_place_cmd(buf_T *buf, linenr_T lnum, char_u *sign_name, int id, char_u *group,
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
      EMSG(_(e_invarg));
    } else {
      sign_list_placed(buf, group);
    }
  } else {
    // Place a new sign
    if (sign_name == NULL || buf == NULL
        || (group != NULL && *group == '\0')) {
      EMSG(_(e_invarg));
      return;
    }

    sign_place(&id, group, sign_name, buf, lnum, prio);
  }
}

/// ":sign unplace" command
static void sign_unplace_cmd(buf_T *buf, linenr_T lnum, char_u *sign_name, int id, char_u *group)
{
  if (lnum >= 0 || sign_name != NULL || (group != NULL && *group == '\0')) {
    EMSG(_(e_invarg));
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
static void sign_jump_cmd(buf_T *buf, linenr_T lnum, char_u *sign_name, int id, char_u *group)
{
  if (sign_name == NULL && group == NULL && id == -1) {
    EMSG(_(e_argreq));
    return;
  }

  if (buf == NULL || (group != NULL && *group == '\0')
      || lnum >= 0 || sign_name != NULL) {
    // File or buffer is not specified or an empty group is used
    // or a line number or a sign name is specified.
    EMSG(_(e_invarg));
    return;
  }

  (void)sign_jump(id, group, buf);
}

/// Parse the command line arguments for the ":sign place", ":sign unplace" and
/// ":sign jump" commands.
/// The supported arguments are: line={lnum} name={name} group={group}
/// priority={prio} and file={fname} or buffer={nr}.
static int parse_sign_cmd_args(int cmd, char_u *arg, char_u **sign_name, int *signid,
                               char_u **group, int *prio, buf_T **buf, linenr_T *lnum)
{
  char_u *arg1;
  char_u *name;
  char_u *filename = NULL;
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
    if (STRNCMP(arg, "line=", 5) == 0) {
      arg += 5;
      *lnum = atoi((char *)arg);
      arg = skiptowhite(arg);
      lnum_arg = true;
    } else if (STRNCMP(arg, "*", 1) == 0 && cmd == SIGNCMD_UNPLACE) {
      if (*signid != -1) {
        EMSG(_(e_invarg));
        return FAIL;
      }
      *signid = -2;
      arg = skiptowhite(arg + 1);
    } else if (STRNCMP(arg, "name=", 5) == 0) {
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
    } else if (STRNCMP(arg, "group=", 6) == 0) {
      arg += 6;
      *group = arg;
      arg = skiptowhite(arg);
      if (*arg != NUL) {
        *arg++ = NUL;
      }
    } else if (STRNCMP(arg, "priority=", 9) == 0) {
      arg += 9;
      *prio = atoi((char *)arg);
      arg = skiptowhite(arg);
    } else if (STRNCMP(arg, "file=", 5) == 0) {
      arg += 5;
      filename = arg;
      *buf = buflist_findname_exp(arg);
      break;
    } else if (STRNCMP(arg, "buffer=", 7) == 0) {
      arg += 7;
      filename = arg;
      *buf = buflist_findnr(getdigits_int(&arg, true, 0));
      if (*skipwhite(arg) != NUL) {
        EMSG(_(e_trailing));
      }
      break;
    } else {
      EMSG(_(e_invarg));
      return FAIL;
    }
    arg = skipwhite(arg);
  }

  if (filename != NULL && *buf == NULL) {
    EMSG2(_("E158: Invalid buffer name: %s"), filename);
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
  char_u *arg = eap->arg;
  char_u *p;
  int idx;
  sign_T *sp;

  // Parse the subcommand.
  p = skiptowhite(arg);
  idx = sign_cmd_idx(arg, p);
  if (idx == SIGNCMD_LAST) {
    EMSG2(_("E160: Unknown sign command: %s"), arg);
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
      EMSG(_("E156: Missing sign name"));
    } else {
      char_u *name;

      // Isolate the sign name.  If it's a number skip leading zeroes,
      // so that "099" and "99" are the same sign.  But keep "0".
      p = skiptowhite(arg);
      if (*p != NUL) {
        *p++ = NUL;
      }
      while (arg[0] == '0' && arg[1] != NUL) {
        arg++;
      }
      name = vim_strsave(arg);

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
    char_u *sign_name = NULL;
    char_u *group = NULL;
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

  tv_dict_add_str(retdict, S_LEN("name"), (char *)sp->sn_name);
  if (sp->sn_icon != NULL) {
    tv_dict_add_str(retdict, S_LEN("icon"), (char *)sp->sn_icon);
  }
  if (sp->sn_text != NULL) {
    tv_dict_add_str(retdict, S_LEN("text"), (char *)sp->sn_text);
  }
  if (sp->sn_line_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_line_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("linehl"), (char *)p);
  }
  if (sp->sn_text_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_text_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("texthl"), (char *)p);
  }
  if (sp->sn_num_hl > 0) {
    p = get_highlight_name_ext(NULL, sp->sn_num_hl - 1, false);
    if (p == NULL) {
      p = "NONE";
    }
    tv_dict_add_str(retdict, S_LEN("numhl"), (char *)p);
  }
}

/// If 'name' is NULL, return a list of all the defined signs.
/// Otherwise, return information about the specified sign.
void sign_getlist(const char_u *name, list_T *retlist)
{
  sign_T *sp = first_sign;
  dict_T *dict;

  if (name != NULL) {
    sp = sign_find(name, NULL);
    if (sp == NULL) {
      return;
    }
  }

  for (; sp != NULL && !got_int; sp = sp->sn_next) {
    dict = tv_dict_alloc();
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
  dict_T *d;
  list_T *const l = tv_list_alloc(kListLenMayKnow);

  FOR_ALL_SIGNS_IN_BUF(buf, sign) {
    d = sign_get_info(sign);
    tv_list_append_dict(l, d);
  }
  return l;
}

/// Return information about all the signs placed in a buffer
static void sign_get_placed_in_buf(buf_T *buf, linenr_T lnum, int sign_id, const char_u *sign_group,
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
void sign_get_placed(buf_T *buf, linenr_T lnum, int sign_id, const char_u *sign_group,
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
  smsg("sign %s", sp->sn_name);
  if (sp->sn_icon != NULL) {
    msg_puts(" icon=");
    msg_outtrans(sp->sn_icon);
    msg_puts(_(" (not supported)"));
  }
  if (sp->sn_text != NULL) {
    msg_puts(" text=");
    msg_outtrans(sp->sn_text);
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

static enum
{
  EXP_SUBCMD,   // expand :sign sub-commands
  EXP_DEFINE,   // expand :sign define {name} args
  EXP_PLACE,    // expand :sign place {id} args
  EXP_LIST,     // expand :sign place args
  EXP_UNPLACE,  // expand :sign unplace"
  EXP_SIGN_NAMES,   // expand with name of placed signs
  EXP_SIGN_GROUPS,  // expand with name of placed sign groups
} expand_what;

// Return the n'th sign name (used for command line completion)
static char_u *get_nth_sign_name(int idx)
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

// Return the n'th sign group name (used for command line completion)
static char_u *get_nth_sign_group_name(int idx)
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
char_u *get_sign_name(expand_T *xp, int idx)
{
  switch (expand_what) {
  case EXP_SUBCMD:
    return (char_u *)cmds[idx];
  case EXP_DEFINE: {
    char *define_arg[] = { "icon=", "linehl=", "text=", "texthl=", "numhl=",
                           NULL };
    return (char_u *)define_arg[idx];
  }
  case EXP_PLACE: {
    char *place_arg[] = { "line=", "name=", "group=", "priority=", "file=",
                          "buffer=", NULL };
    return (char_u *)place_arg[idx];
  }
  case EXP_LIST: {
    char *list_arg[] = { "group=", "file=", "buffer=", NULL };
    return (char_u *)list_arg[idx];
  }
  case EXP_UNPLACE: {
    char *unplace_arg[] = { "group=", "file=", "buffer=", NULL };
    return (char_u *)unplace_arg[idx];
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
void set_context_in_sign_cmd(expand_T *xp, char_u *arg)
{
  char_u *end_subcmd;
  char_u *last;
  int cmd_idx;
  char_u *begin_subcmd_args;

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
  char_u *p = begin_subcmd_args;
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
      if (STRNCMP(last, "texthl", 6) == 0
          || STRNCMP(last, "linehl", 6) == 0
          || STRNCMP(last, "numhl", 5) == 0) {
        xp->xp_context = EXPAND_HIGHLIGHT;
      } else if (STRNCMP(last, "icon", 4) == 0) {
        xp->xp_context = EXPAND_FILES;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
      break;
    case SIGNCMD_PLACE:
      if (STRNCMP(last, "name", 4) == 0) {
        expand_what = EXP_SIGN_NAMES;
      } else if (STRNCMP(last, "group", 5) == 0) {
        expand_what = EXP_SIGN_GROUPS;
      } else if (STRNCMP(last, "file", 4) == 0) {
        xp->xp_context = EXPAND_BUFFERS;
      } else {
        xp->xp_context = EXPAND_NOTHING;
      }
      break;
    case SIGNCMD_UNPLACE:
    case SIGNCMD_JUMP:
      if (STRNCMP(last, "group", 5) == 0) {
        expand_what = EXP_SIGN_GROUPS;
      } else if (STRNCMP(last, "file", 4) == 0) {
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
int sign_define_from_dict(const char *name_arg, dict_T *dict)
{
  char *name = NULL;
  char *icon = NULL;
  char *linehl = NULL;
  char *text = NULL;
  char *texthl = NULL;
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
    numhl  = tv_dict_get_string(dict, "numhl", true);
  }

  if (sign_define_by_name((char_u *)name, (char_u *)icon, (char_u *)linehl,
                          (char_u *)text, (char_u *)texthl, (char_u *)numhl)
      == OK) {
    retval = 0;
  }

cleanup:
  xfree(name);
  xfree(icon);
  xfree(linehl);
  xfree(text);
  xfree(texthl);
  xfree(numhl);

  return retval;
}

/// Define multiple signs using attributes from list 'l' and store the return
/// values in 'retlist'.
void sign_define_multiple(list_T *l, list_T *retlist)
{
  int retval;

  TV_LIST_ITER_CONST(l, li, {
    retval = -1;
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_DICT) {
      retval = sign_define_from_dict(NULL, TV_LIST_ITEM_TV(li)->vval.v_dict);
    } else {
      EMSG(_(e_dictreq));
    }
    tv_list_append_number(retlist, retval);
  });
}

/// Place a new sign using the values specified in dict 'dict'. Returns the sign
/// identifier if successfully placed, otherwise returns 0.
int sign_place_from_dict(typval_T *id_tv, typval_T *group_tv, typval_T *name_tv, typval_T *buf_tv,
                         dict_T *dict)
{
  int sign_id = 0;
  char_u *group = NULL;
  char_u *sign_name = NULL;
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
      EMSG(_(e_invarg));
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
    group = (char_u *)tv_get_string_chk(group_tv);
    if (group == NULL) {
      goto cleanup;
    }
    if (group[0] == '\0') {  // global sign group
      group = NULL;
    } else {
      group = vim_strsave(group);
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
  sign_name = (char_u *)tv_get_string_chk(name_tv);
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
      EMSG(_(e_invarg));
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

/// Undefine multiple signs
void sign_undefine_multiple(list_T *l, list_T *retlist)
{
  char_u *name;
  int retval;

  TV_LIST_ITER_CONST(l, li, {
    retval = -1;
    name = (char_u *)tv_get_string_chk(TV_LIST_ITEM_TV(li));
    if (name != NULL && (sign_undefine_by_name(name) == OK)) {
      retval = 0;
    }
    tv_list_append_number(retlist, retval);
  });
}

/// Unplace the sign with attributes specified in 'dict'. Returns 0 on success
/// and -1 on failure.
int sign_unplace_from_dict(typval_T *group_tv, dict_T *dict)
{
  dictitem_T *di;
  int sign_id = 0;
  buf_T *buf = NULL;
  char_u *group = NULL;
  int retval = -1;

  // sign group
  if (group_tv != NULL) {
    group = (char_u *)tv_get_string(group_tv);
  } else {
    group = (char_u *)tv_dict_get_string(dict, "group", false);
  }
  if (group != NULL) {
    if (group[0] == '\0') {  // global sign group
      group = NULL;
    } else {
      group = vim_strsave(group);
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
        EMSG(_(e_invarg));
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

