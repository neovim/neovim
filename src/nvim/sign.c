// sign.c: functions for managing with signs

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/extmark.h"
#include "nvim/fold.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/marktree.h"
#include "nvim/marktree_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"
#include "nvim/sign_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "sign.c.generated.h"
#endif

static PMap(cstr_t) sign_map = MAP_INIT;
static kvec_t(Integer) sign_ns = KV_INITIAL_VALUE;

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

// Convert the supplied "group" to a namespace filter
static int64_t group_get_ns(const char *group)
{
  if (group == NULL) {
    return 0;           // Global namespace
  } else if (strcmp(group, "*") == 0) {
    return UINT32_MAX;  // All namespaces
  }
  // Specific or non-existing namespace
  int ns = map_get(String, int)(&namespace_ids, cstr_as_string(group));
  return ns ? ns : -1;
}

static const char *sign_get_name(DecorSignHighlight *sh)
{
  char *name = sh->sign_name;
  return !name ? "" : map_has(cstr_t, &sign_map, name) ? name : "[Deleted]";
}

/// Create or update a sign extmark.
///
/// @param buf  buffer to store sign in
/// @param id  sign ID
/// @param group  sign group
/// @param prio  sign priority
/// @param lnum  line number which gets the mark
/// @param sp  sign properties
static void buf_set_sign(buf_T *buf, uint32_t *id, char *group, int prio, linenr_T lnum, sign_T *sp)
{
  if (group && !map_get(String, int)(&namespace_ids, cstr_as_string(group))) {
    kv_push(sign_ns, nvim_create_namespace(cstr_as_string(group)));
  }

  uint32_t ns = group ? (uint32_t)nvim_create_namespace(cstr_as_string(group)) : 0;
  DecorSignHighlight sign = DECOR_SIGN_HIGHLIGHT_INIT;

  sign.flags |= kSHIsSign;
  memcpy(sign.text, sp->sn_text, SIGN_WIDTH * sizeof(schar_T));
  sign.sign_name = xstrdup(sp->sn_name);
  sign.hl_id = sp->sn_text_hl;
  sign.line_hl_id = sp->sn_line_hl;
  sign.number_hl_id = sp->sn_num_hl;
  sign.cursorline_hl_id = sp->sn_cul_hl;
  sign.priority = (DecorPriority)prio;

  bool has_hl = (sp->sn_line_hl || sp->sn_num_hl || sp->sn_cul_hl);
  uint16_t decor_flags = (sp->sn_text[0] ? MT_FLAG_DECOR_SIGNTEXT : 0)
                         | (has_hl ? MT_FLAG_DECOR_SIGNHL : 0);

  DecorInline decor = { .ext = true, .data.ext = { .vt = NULL, .sh_idx = decor_put_sh(sign) } };
  extmark_set(buf, ns, id, MIN(buf->b_ml.ml_line_count, lnum) - 1, 0, -1, -1,
              decor, decor_flags, true, false, true, true, NULL);
}

/// For an existing, placed sign with "id", modify the sign, group or priority.
/// Returns the line number of the sign, or zero if the sign is not found.
///
/// @param buf  buffer to store sign in
/// @param id  sign ID
/// @param group  sign group
/// @param prio  sign priority
/// @param sp  sign pointer
static linenr_T buf_mod_sign(buf_T *buf, uint32_t *id, char *group, int prio, sign_T *sp)
{
  int64_t ns = group_get_ns(group);
  if (ns < 0 || (group && ns == 0)) {
    return 0;
  }

  MTKey mark = marktree_lookup_ns(buf->b_marktree, (uint32_t)ns, *id, false, NULL);
  if (mark.pos.row >= 0) {
    buf_set_sign(buf, id, group, prio, mark.pos.row + 1, sp);
  }
  return mark.pos.row + 1;
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
  int64_t ns = group_get_ns(group);
  if (ns < 0 || (group && ns == 0)) {
    return 0;
  }
  return marktree_lookup_ns(buf->b_marktree, (uint32_t)ns, (uint32_t)id, false, NULL).pos.row + 1;
}

/// qsort() function to sort signs by line number, priority, id and recency.
static int sign_row_cmp(const void *p1, const void *p2)
{
  const MTKey *s1 = (MTKey *)p1;
  const MTKey *s2 = (MTKey *)p2;

  if (s1->pos.row != s2->pos.row) {
    return s1->pos.row > s2->pos.row ? 1 : -1;
  }

  DecorSignHighlight *sh1 = decor_find_sign(mt_decor(*s1));
  DecorSignHighlight *sh2 = decor_find_sign(mt_decor(*s2));
  assert(sh1 && sh2);
  SignItem si1 = { sh1, s1->id };
  SignItem si2 = { sh2, s2->id };

  return sign_item_cmp(&si1, &si2);
}

/// Delete the specified sign(s)
///
/// @param buf  buffer sign is stored in or NULL for all buffers
/// @param group  sign group
/// @param id  sign id
/// @param atlnum  single sign at this line, specified signs at any line when -1
static int buf_delete_signs(buf_T *buf, char *group, int id, linenr_T atlnum)
{
  int64_t ns = group_get_ns(group);
  if (ns < 0) {
    return FAIL;
  }

  MarkTreeIter itr[1];
  int row = atlnum > 0 ? atlnum - 1 : 0;
  kvec_t(MTKey) signs = KV_INITIAL_VALUE;
  // Store signs at a specific line number to remove one later.
  if (atlnum > 0) {
    if (!marktree_itr_get_overlap(buf->b_marktree, row, 0, itr)) {
      return FAIL;
    }

    MTPair pair;
    while (marktree_itr_step_overlap(buf->b_marktree, itr, &pair)) {
      if ((ns == UINT32_MAX || ns == pair.start.ns) && mt_decor_sign(pair.start)) {
        kv_push(signs, pair.start);
      }
    }
  } else {
    marktree_itr_get(buf->b_marktree, 0, 0, itr);
  }

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (row && mark.pos.row > row) {
      break;
    }
    if (!mt_end(mark) && mt_decor_sign(mark)
        && (id == 0 || (int)mark.id == id)
        && (ns == UINT32_MAX || ns == mark.ns)) {
      if (atlnum > 0) {
        kv_push(signs, mark);
        marktree_itr_next(buf->b_marktree, itr);
      } else {
        extmark_del(buf, itr, mark, true);
      }
    } else {
      marktree_itr_next(buf->b_marktree, itr);
    }
  }

  // Sort to remove the highest priority sign at a specific line number.
  if (kv_size(signs)) {
    qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(MTKey), sign_row_cmp);
    extmark_del_id(buf, kv_A(signs, 0).ns, kv_A(signs, 0).id);
    kv_destroy(signs);
  } else if (atlnum > 0) {
    return FAIL;
  }

  return OK;
}

bool buf_has_signs(const buf_T *buf)
{
  return (buf_meta_total(buf, kMTMetaSignHL) + buf_meta_total(buf, kMTMetaSignText));
}

/// List placed signs for "rbuf".  If "rbuf" is NULL do it for all buffers.
static void sign_list_placed(buf_T *rbuf, char *group)
{
  char lbuf[MSG_BUF_LEN];
  char namebuf[MSG_BUF_LEN];
  char groupbuf[MSG_BUF_LEN];
  buf_T *buf = rbuf ? rbuf : firstbuf;
  int64_t ns = group_get_ns(group);

  msg_puts_title(_("\n--- Signs ---"));
  msg_putchar('\n');

  while (buf != NULL && !got_int) {
    if (buf_has_signs(buf)) {
      vim_snprintf(lbuf, MSG_BUF_LEN, _("Signs for %s:"), buf->b_fname);
      msg_puts_hl(lbuf, HLF_D, false);
      msg_putchar('\n');
    }

    if (ns >= 0) {
      MarkTreeIter itr[1];
      kvec_t(MTKey) signs = KV_INITIAL_VALUE;
      marktree_itr_get(buf->b_marktree, 0, 0, itr);

      while (itr->x) {
        MTKey mark = marktree_itr_current(itr);
        if (!mt_end(mark) && mt_decor_sign(mark)
            && (ns == UINT32_MAX || ns == mark.ns)) {
          kv_push(signs, mark);
        }
        marktree_itr_next(buf->b_marktree, itr);
      }

      if (kv_size(signs)) {
        qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(MTKey), sign_row_cmp);

        for (size_t i = 0; i < kv_size(signs); i++) {
          namebuf[0] = NUL;
          groupbuf[0] = NUL;
          MTKey mark = kv_A(signs, i);

          DecorSignHighlight *sh = decor_find_sign(mt_decor(mark));
          if (sh->sign_name != NULL) {
            vim_snprintf(namebuf, MSG_BUF_LEN, _("  name=%s"), sign_get_name(sh));
          }
          if (mark.ns != 0) {
            vim_snprintf(groupbuf, MSG_BUF_LEN, _("  group=%s"), describe_ns((int)mark.ns, ""));
          }
          vim_snprintf(lbuf, MSG_BUF_LEN, _("    line=%" PRIdLINENR "  id=%u%s%s  priority=%d"),
                       mark.pos.row + 1, mark.id, groupbuf, namebuf, sh->priority);
          msg_puts(lbuf);
          msg_putchar('\n');
        }
        kv_destroy(signs);
      }
    }

    if (rbuf != NULL) {
      return;
    }
    buf = buf->b_next;
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

/// buf must be SIGN_WIDTH * MAX_SCHAR_SIZE (no extra +1 needed)
size_t describe_sign_text(char *buf, schar_T *sign_text)
{
  size_t p = 0;
  for (int i = 0; i < SIGN_WIDTH; i++) {
    schar_get(buf + p, sign_text[i]);
    size_t len = strlen(buf + p);
    if (len == 0) {
      break;
    }
    p += len;
  }
  return p;
}

/// Initialize the "text" for a new sign and store in "sign_text".
/// "sp" is NULL for signs added through nvim_buf_set_extmark().
int init_sign_text(sign_T *sp, schar_T *sign_text, char *text)
{
  char *s;
  char *endp = text + (int)strlen(text);

  for (s = sp ? text : endp; s + 1 < endp; s++) {
    if (*s == '\\') {
      // Remove a backslash, so that it is possible to use a space.
      STRMOVE(s, s + 1);
      endp--;
    }
  }
  // Count cells and check for non-printable chars
  int cells = 0;
  for (s = text; s < endp; s += utfc_ptr2len(s)) {
    int c;
    sign_text[cells] = utfc_ptr2schar(s, &c);
    if (!vim_isprintc(c)) {
      break;
    }
    int width = utf_ptr2cells(s);
    if (width == 2) {
      sign_text[cells + 1] = 0;
    }
    cells += width;
  }
  // Currently must be empty, one or two display cells
  if (s != endp || cells > SIGN_WIDTH) {
    if (sp != NULL) {
      semsg(_("E239: Invalid sign text: %s"), text);
    }
    return FAIL;
  }

  if (cells < 1) {
    sign_text[0] = 0;
  } else if (cells == 1) {
    sign_text[1] = schar_from_ascii(' ');
  }

  return OK;
}

/// Define a new sign or update an existing sign
static int sign_define_by_name(char *name, char *icon, char *text, char *linehl, char *texthl,
                               char *culhl, char *numhl, int prio)
{
  cstr_t *key;
  bool new_sign = false;
  sign_T **sp = (sign_T **)pmap_put_ref(cstr_t)(&sign_map, name, &key, &new_sign);

  if (new_sign) {
    *key = xstrdup(name);
    *sp = xcalloc(1, sizeof(sign_T));
    (*sp)->sn_name = (char *)(*key);
  }

  // Set values for a defined sign.
  if (icon != NULL) {
    /// Initialize the icon information for a new sign
    xfree((*sp)->sn_icon);
    (*sp)->sn_icon = xstrdup(icon);
    backslash_halve((*sp)->sn_icon);
  }

  if (text != NULL && (init_sign_text(*sp, (*sp)->sn_text, text) == FAIL)) {
    return FAIL;
  }

  (*sp)->sn_priority = prio;

  char *arg[] = { linehl, texthl, culhl, numhl };
  int *hl[] = { &(*sp)->sn_line_hl, &(*sp)->sn_text_hl, &(*sp)->sn_cul_hl, &(*sp)->sn_num_hl };
  for (int i = 0; i < 4; i++) {
    if (arg[i] != NULL) {
      *hl[i] = *arg[i] ? syn_check_group(arg[i], strlen(arg[i])) : 0;
    }
  }

  // Update already placed signs and redraw if necessary when modifying a sign.
  if (!new_sign) {
    bool did_redraw = false;
    for (size_t i = 0; i < kv_size(decor_items); i++) {
      DecorSignHighlight *sh = &kv_A(decor_items, i);
      if (sh->sign_name && strcmp(sh->sign_name, name) == 0) {
        memcpy(sh->text, (*sp)->sn_text, SIGN_WIDTH * sizeof(schar_T));
        sh->hl_id = (*sp)->sn_text_hl;
        sh->line_hl_id = (*sp)->sn_line_hl;
        sh->number_hl_id = (*sp)->sn_num_hl;
        sh->cursorline_hl_id = (*sp)->sn_cul_hl;
        if (!did_redraw) {
          FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
            if (buf_has_signs(wp->w_buffer)) {
              redraw_buf_later(wp->w_buffer, UPD_NOT_VALID);
            }
          }
          did_redraw = true;
        }
      }
    }
  }
  return OK;
}

/// Free the sign specified by 'name'.
static int sign_undefine_by_name(const char *name)
{
  sign_T *sp = pmap_del(cstr_t)(&sign_map, name, NULL);
  if (sp == NULL) {
    semsg(_("E155: Unknown sign: %s"), name);
    return FAIL;
  }

  xfree(sp->sn_name);
  xfree(sp->sn_icon);
  xfree(sp);
  return OK;
}

/// List one sign.
static void sign_list_defined(sign_T *sp)
{
  smsg(0, "sign %s", sp->sn_name);
  if (sp->sn_icon != NULL) {
    msg_puts(" icon=");
    msg_outtrans(sp->sn_icon, 0, false);
    msg_puts(_(" (not supported)"));
  }
  if (sp->sn_text[0]) {
    msg_puts(" text=");
    char buf[SIGN_WIDTH * MAX_SCHAR_SIZE];
    describe_sign_text(buf, sp->sn_text);
    msg_outtrans(buf, 0, false);
  }
  if (sp->sn_priority > 0) {
    char lbuf[MSG_BUF_LEN];
    vim_snprintf(lbuf, MSG_BUF_LEN, " priority=%d", sp->sn_priority);
    msg_puts(lbuf);
  }
  static char *arg[] = { " linehl=", " texthl=", " culhl=", " numhl=" };
  int hl[] = { sp->sn_line_hl, sp->sn_text_hl, sp->sn_cul_hl, sp->sn_num_hl };
  for (int i = 0; i < 4; i++) {
    if (hl[i] > 0) {
      msg_puts(arg[i]);
      const char *p = get_highlight_name_ext(NULL, hl[i] - 1, false);
      msg_puts(p ? p : "NONE");
    }
  }
}

/// List the signs matching 'name'
static void sign_list_by_name(char *name)
{
  sign_T *sp = pmap_get(cstr_t)(&sign_map, name);
  if (sp != NULL) {
    sign_list_defined(sp);
  } else {
    semsg(_("E155: Unknown sign: %s"), name);
  }
}

/// Place a sign at the specified file location or update a sign.
static int sign_place(uint32_t *id, char *group, char *name, buf_T *buf, linenr_T lnum, int prio)
{
  // Check for reserved character '*' in group name
  if (group != NULL && (*group == '*' || *group == NUL)) {
    return FAIL;
  }

  sign_T *sp = pmap_get(cstr_t)(&sign_map, name);
  if (sp == NULL) {
    semsg(_("E155: Unknown sign: %s"), name);
    return FAIL;
  }

  // Use the default priority value for this sign.
  if (prio == -1) {
    prio = (sp->sn_priority != -1) ? sp->sn_priority : SIGN_DEF_PRIO;
  }

  if (lnum > 0) {
    // ":sign place {id} line={lnum} name={name} file={fname}": place a sign
    buf_set_sign(buf, id, group, prio, lnum, sp);
  } else {
    // ":sign place {id} file={fname}": change sign type and/or priority
    lnum = buf_mod_sign(buf, id, group, prio, sp);
  }
  if (lnum <= 0) {
    semsg(_("E885: Not possible to change sign %s"), name);
    return FAIL;
  }

  return OK;
}

static int sign_unplace_inner(buf_T *buf, int id, char *group, linenr_T atlnum)
{
  if (!buf_has_signs(buf)) {  // No signs in the buffer
    return FAIL;
  }

  if (id == 0 || atlnum > 0 || (group != NULL && *group == '*')) {
    // Delete multiple specified signs
    if (!buf_delete_signs(buf, group, id, atlnum)) {
      return FAIL;
    }
  } else {
    // Delete only a single sign
    int64_t ns = group_get_ns(group);
    if (ns < 0 || !extmark_del_id(buf, (uint32_t)ns, (uint32_t)id)) {
      return FAIL;
    }
  }

  return OK;
}

/// Unplace the specified sign for a single or all buffers
static int sign_unplace(buf_T *buf, int id, char *group, linenr_T atlnum)
{
  if (buf != NULL) {
    return sign_unplace_inner(buf, id, group, atlnum);
  } else {
    int retval = OK;
    FOR_ALL_BUFFERS(cbuf) {
      if (!sign_unplace_inner(cbuf, id, group, atlnum)) {
        retval = FAIL;
      }
    }
    return retval;
  }
}

/// Jump to a sign.
static linenr_T sign_jump(int id, char *group, buf_T *buf)
{
  linenr_T lnum = buf_findsign(buf, id, group);

  if (lnum <= 0) {
    semsg(_("E157: Invalid sign ID: %" PRId32), id);
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
    snprintf(cmd, cmdlen, "e +%" PRId64 " %s", (int64_t)lnum, buf->b_fname);
    do_cmdline_cmd(cmd);
    xfree(cmd);
  }

  foldOpenCursor();

  return lnum;
}

/// ":sign define {name} ..." command
static void sign_define_cmd(char *name, char *cmdline)
{
  char *icon = NULL;
  char *text = NULL;
  char *linehl = NULL;
  char *texthl = NULL;
  char *culhl = NULL;
  char *numhl = NULL;
  int prio = -1;

  // set values for a defined sign.
  while (true) {
    char *arg = skipwhite(cmdline);
    if (*arg == NUL) {
      break;
    }
    cmdline = skiptowhite_esc(arg);
    if (strncmp(arg, "icon=", 5) == 0) {
      icon = arg + 5;
    } else if (strncmp(arg, "text=", 5) == 0) {
      text = arg + 5;
    } else if (strncmp(arg, "linehl=", 7) == 0) {
      linehl = arg + 7;
    } else if (strncmp(arg, "texthl=", 7) == 0) {
      texthl = arg + 7;
    } else if (strncmp(arg, "culhl=", 6) == 0) {
      culhl = arg + 6;
    } else if (strncmp(arg, "numhl=", 6) == 0) {
      numhl = arg + 6;
    } else if (strncmp(arg, "priority=", 9) == 0) {
      prio = atoi(arg + 9);
    } else {
      semsg(_(e_invarg2), arg);
      return;
    }
    if (*cmdline == NUL) {
      break;
    }
    *cmdline++ = NUL;
  }

  sign_define_by_name(name, icon, text, linehl, texthl, culhl, numhl, prio);
}

/// ":sign place" command
static void sign_place_cmd(buf_T *buf, linenr_T lnum, char *name, int id, char *group, int prio)
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
    if (lnum >= 0 || name != NULL || (group != NULL && *group == NUL)) {
      emsg(_(e_invarg));
    } else {
      sign_list_placed(buf, group);
    }
  } else {
    // Place a new sign
    if (name == NULL || buf == NULL || (group != NULL && *group == NUL)) {
      emsg(_(e_invarg));
      return;
    }
    uint32_t uid = (uint32_t)id;
    sign_place(&uid, group, name, buf, lnum, prio);
  }
}

/// ":sign unplace" command
static void sign_unplace_cmd(buf_T *buf, linenr_T lnum, const char *name, int id, char *group)
{
  if (lnum >= 0 || name != NULL || (group != NULL && *group == NUL)) {
    emsg(_(e_invarg));
    return;
  }

  if (id == -1) {
    lnum = curwin->w_cursor.lnum;
    buf = curwin->w_buffer;
  }

  if (!sign_unplace(buf, MAX(0, id), group, lnum) && lnum > 0) {
    emsg(_("E159: Missing sign number"));
  }
}

/// Jump to a placed sign commands:
///   :sign jump {id} file={fname}
///   :sign jump {id} buffer={nr}
///   :sign jump {id} group={group} file={fname}
///   :sign jump {id} group={group} buffer={nr}
static void sign_jump_cmd(buf_T *buf, linenr_T lnum, const char *name, int id, char *group)
{
  if (name == NULL && group == NULL && id == -1) {
    emsg(_(e_argreq));
    return;
  }

  if (buf == NULL || (group != NULL && *group == NUL) || lnum >= 0 || name != NULL) {
    // File or buffer is not specified or an empty group is used
    // or a line number or a sign name is specified.
    emsg(_(e_invarg));
    return;
  }

  sign_jump(id, group, buf);
}

/// Parse the command line arguments for the ":sign place", ":sign unplace" and
/// ":sign jump" commands.
/// The supported arguments are: line={lnum} name={name} group={group}
/// priority={prio} and file={fname} or buffer={nr}.
static int parse_sign_cmd_args(int cmd, char *arg, char **name, int *id, char **group, int *prio,
                               buf_T **buf, linenr_T *lnum)
{
  char *arg1 = arg;
  char *filename = NULL;
  bool lnum_arg = false;

  // first arg could be placed sign id
  if (ascii_isdigit(*arg)) {
    *id = getdigits_int(&arg, true, 0);
    if (!ascii_iswhite(*arg) && *arg != NUL) {
      *id = -1;
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
      if (*id != -1) {
        emsg(_(e_invarg));
        return FAIL;
      }
      *id = -2;
      arg = skiptowhite(arg + 1);
    } else if (strncmp(arg, "name=", 5) == 0) {
      arg += 5;
      char *namep = arg;
      arg = skiptowhite(arg);
      if (*arg != NUL) {
        *arg++ = NUL;
      }
      while (namep[0] == '0' && namep[1] != NUL) {
        namep++;
      }
      *name = namep;
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
    semsg(_(e_invalid_buffer_name_str), filename);
    return FAIL;
  }

  // If the filename is not supplied for the sign place or the sign jump
  // command, then use the current buffer.
  if (filename == NULL && ((cmd == SIGNCMD_PLACE && lnum_arg) || cmd == SIGNCMD_JUMP)) {
    *buf = curwin->w_buffer;
  }
  return OK;
}

/// ":sign" command
void ex_sign(exarg_T *eap)
{
  char *arg = eap->arg;

  // Parse the subcommand.
  char *p = skiptowhite(arg);
  int idx = sign_cmd_idx(arg, p);
  if (idx == SIGNCMD_LAST) {
    semsg(_("E160: Unknown sign command: %s"), arg);
    return;
  }
  arg = skipwhite(p);

  if (idx <= SIGNCMD_LIST) {
    // Define, undefine or list signs.
    if (idx == SIGNCMD_LIST && *arg == NUL) {
      // ":sign list": list all defined signs
      sign_T *sp;
      map_foreach_value(&sign_map, sp, {
        sign_list_defined(sp);
      });
    } else if (*arg == NUL) {
      emsg(_("E156: Missing sign name"));
    } else {
      // Isolate the sign name.  If it's a number skip leading zeroes,
      // so that "099" and "99" are the same sign.  But keep "0".
      p = skiptowhite(arg);
      if (*p != NUL) {
        *p++ = NUL;
      }
      while (arg[0] == '0' && arg[1] != NUL) {
        arg++;
      }

      if (idx == SIGNCMD_DEFINE) {
        sign_define_cmd(arg, p);
      } else if (idx == SIGNCMD_LIST) {
        // ":sign list {name}"
        sign_list_by_name(arg);
      } else {
        // ":sign undefine {name}"
        sign_undefine_by_name(arg);
      }

      return;
    }
  } else {
    int id = -1;
    linenr_T lnum = -1;
    char *name = NULL;
    char *group = NULL;
    int prio = -1;
    buf_T *buf = NULL;

    // Parse command line arguments
    if (parse_sign_cmd_args(idx, arg, &name, &id, &group, &prio, &buf, &lnum) == FAIL) {
      return;
    }

    if (idx == SIGNCMD_PLACE) {
      sign_place_cmd(buf, lnum, name, id, group, prio);
    } else if (idx == SIGNCMD_UNPLACE) {
      sign_unplace_cmd(buf, lnum, name, id, group);
    } else if (idx == SIGNCMD_JUMP) {
      sign_jump_cmd(buf, lnum, name, id, group);
    }
  }
}

/// Get dictionary of information for a defined sign "sp"
static dict_T *sign_get_info_dict(sign_T *sp)
{
  dict_T *d = tv_dict_alloc();

  tv_dict_add_str(d, S_LEN("name"), sp->sn_name);

  if (sp->sn_icon != NULL) {
    tv_dict_add_str(d, S_LEN("icon"), sp->sn_icon);
  }
  if (sp->sn_text[0]) {
    char buf[SIGN_WIDTH * MAX_SCHAR_SIZE];
    describe_sign_text(buf, sp->sn_text);
    tv_dict_add_str(d, S_LEN("text"), buf);
  }
  if (sp->sn_priority > 0) {
    tv_dict_add_nr(d, S_LEN("priority"), sp->sn_priority);
  }
  static char *arg[] = { "linehl", "texthl", "culhl", "numhl" };
  int hl[] = { sp->sn_line_hl, sp->sn_text_hl, sp->sn_cul_hl, sp->sn_num_hl };
  for (int i = 0; i < 4; i++) {
    if (hl[i] > 0) {
      const char *p = get_highlight_name_ext(NULL, hl[i] - 1, false);
      tv_dict_add_str(d, arg[i], strlen(arg[i]), p ? p : "NONE");
    }
  }
  return d;
}

/// Get dictionary of information for placed sign "mark"
static dict_T *sign_get_placed_info_dict(MTKey mark)
{
  dict_T *d = tv_dict_alloc();

  DecorSignHighlight *sh = decor_find_sign(mt_decor(mark));

  tv_dict_add_str(d, S_LEN("name"), sign_get_name(sh));
  tv_dict_add_nr(d,  S_LEN("id"), (int)mark.id);
  tv_dict_add_str(d, S_LEN("group"), describe_ns((int)mark.ns, ""));
  tv_dict_add_nr(d,  S_LEN("lnum"), mark.pos.row + 1);
  tv_dict_add_nr(d,  S_LEN("priority"), sh->priority);
  return d;
}

/// Returns information about signs placed in a buffer as list of dicts.
list_T *get_buffer_signs(buf_T *buf)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  list_T *const l = tv_list_alloc(kListLenMayKnow);
  MarkTreeIter itr[1];
  marktree_itr_get(buf->b_marktree, 0, 0, itr);

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (!mt_end(mark) && mt_decor_sign(mark)) {
      tv_list_append_dict(l, sign_get_placed_info_dict(mark));
    }
    marktree_itr_next(buf->b_marktree, itr);
  }

  return l;
}

/// @return  information about all the signs placed in a buffer
static void sign_get_placed_in_buf(buf_T *buf, linenr_T lnum, int sign_id, const char *group,
                                   list_T *retlist)
{
  dict_T *d = tv_dict_alloc();
  tv_list_append_dict(retlist, d);

  tv_dict_add_nr(d, S_LEN("bufnr"), buf->b_fnum);

  list_T *l = tv_list_alloc(kListLenMayKnow);
  tv_dict_add_list(d, S_LEN("signs"), l);

  int64_t ns = group_get_ns(group);
  if (!buf_has_signs(buf) || ns < 0) {
    return;
  }

  MarkTreeIter itr[1];
  kvec_t(MTKey) signs = KV_INITIAL_VALUE;
  marktree_itr_get(buf->b_marktree, lnum ? lnum - 1 : 0, 0, itr);

  while (itr->x) {
    MTKey mark = marktree_itr_current(itr);
    if (lnum && mark.pos.row >= lnum) {
      break;
    }
    if (!mt_end(mark)
        && (ns == UINT32_MAX || ns == mark.ns)
        && ((lnum == 0 && sign_id == 0)
            || (sign_id == 0 && lnum == mark.pos.row + 1)
            || (lnum == 0 && sign_id == (int)mark.id)
            || (lnum == mark.pos.row + 1 && sign_id == (int)mark.id))) {
      if (mt_decor_sign(mark)) {
        kv_push(signs, mark);
      }
    }
    marktree_itr_next(buf->b_marktree, itr);
  }

  if (kv_size(signs)) {
    qsort((void *)&kv_A(signs, 0), kv_size(signs), sizeof(MTKey), sign_row_cmp);
    for (size_t i = 0; i < kv_size(signs); i++) {
      tv_list_append_dict(l, sign_get_placed_info_dict(kv_A(signs, i)));
    }
    kv_destroy(signs);
  }
}

/// Get a list of signs placed in buffer 'buf'. If 'num' is non-zero, return the
/// sign placed at the line number. If 'lnum' is zero, return all the signs
/// placed in 'buf'. If 'buf' is NULL, return signs placed in all the buffers.
static void sign_get_placed(buf_T *buf, linenr_T lnum, int id, const char *group, list_T *retlist)
{
  if (buf != NULL) {
    sign_get_placed_in_buf(buf, lnum, id, group, retlist);
  } else {
    FOR_ALL_BUFFERS(cbuf) {
      if (buf_has_signs(cbuf)) {
        sign_get_placed_in_buf(cbuf, 0, id, group, retlist);
      }
    }
  }
}

void free_signs(void)
{
  cstr_t name;
  kvec_t(cstr_t) names = KV_INITIAL_VALUE;
  map_foreach_key(&sign_map, name, {
    kv_push(names, name);
  });
  for (size_t i = 0; i < kv_size(names); i++) {
    sign_undefine_by_name(kv_A(names, i));
  }
  kv_destroy(names);
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
  cstr_t name;
  int current_idx = 0;
  map_foreach_key(&sign_map, name, {
    if (current_idx++ == idx) {
      return (char *)name;
    }
  });
  return NULL;
}

/// @return  the n'th sign group name (used for command line completion)
static char *get_nth_sign_group_name(int idx)
{
  // Complete with name of sign groups already defined
  if (idx < (int)kv_size(sign_ns)) {
    return (char *)describe_ns((NS)kv_A(sign_ns, idx), "");
  }
  return NULL;
}

/// Function given to ExpandGeneric() to obtain the sign command expansion.
char *get_sign_name(expand_T *xp, int idx)
{
  switch (expand_what) {
  case EXP_SUBCMD:
    return cmds[idx];
  case EXP_DEFINE: {
    char *define_arg[] = { "culhl=", "icon=", "linehl=", "numhl=", "text=", "texthl=",
                           "priority=", NULL };
    return define_arg[idx];
  }
  case EXP_PLACE: {
    char *place_arg[] = { "line=", "name=", "group=", "priority=", "file=", "buffer=", NULL };
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
  // Default: expand subcommands.
  xp->xp_context = EXPAND_SIGN;
  expand_what = EXP_SUBCMD;
  xp->xp_pattern = arg;

  char *end_subcmd = skiptowhite(arg);
  if (*end_subcmd == NUL) {
    // expand subcmd name
    // :sign {subcmd}<CTRL-D>
    return;
  }

  int cmd_idx = sign_cmd_idx(arg, end_subcmd);

  // :sign {subcmd} {subcmd_args}
  //                |
  //                begin_subcmd_args
  char *begin_subcmd_args = skipwhite(end_subcmd);

  // Expand last argument of subcmd.
  //
  // :sign define {name} {args}...
  //              |
  //              p

  // Loop until reaching last argument.
  char *last;
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
static int sign_define_from_dict(char *name, dict_T *dict)
{
  if (name == NULL) {
    name = tv_dict_get_string(dict, "name", false);
    if (name == NULL || name[0] == NUL) {
      return -1;
    }
  }

  char *icon = NULL;
  char *linehl = NULL;
  char *text = NULL;
  char *texthl = NULL;
  char *culhl = NULL;
  char *numhl = NULL;
  int prio = -1;

  if (dict != NULL) {
    icon = tv_dict_get_string(dict, "icon", false);
    linehl = tv_dict_get_string(dict, "linehl", false);
    text = tv_dict_get_string(dict, "text", false);
    texthl = tv_dict_get_string(dict, "texthl", false);
    culhl = tv_dict_get_string(dict, "culhl", false);
    numhl = tv_dict_get_string(dict, "numhl", false);
    prio = (int)tv_dict_get_number_def(dict, "priority", -1);
  }

  return sign_define_by_name(name, icon, text, linehl, texthl, culhl, numhl, prio) - 1;
}

/// Define multiple signs using attributes from list 'l' and store the return
/// values in 'retlist'.
static void sign_define_multiple(list_T *l, list_T *retlist)
{
  TV_LIST_ITER_CONST(l, li, {
    int retval = -1;
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
  if (argvars[0].v_type == VAR_LIST && argvars[1].v_type == VAR_UNKNOWN) {
    // Define multiple signs
    tv_list_alloc_ret(rettv, kListLenMayKnow);

    sign_define_multiple(argvars[0].vval.v_list, rettv->vval.v_list);
    return;
  }

  // Define a single sign
  rettv->vval.v_number = -1;

  char *name = (char *)tv_get_string_chk(&argvars[0]);
  if (name == NULL) {
    return;
  }

  if (tv_check_for_opt_dict_arg(argvars, 1) == FAIL) {
    return;
  }

  dict_T *d = argvars[1].v_type == VAR_DICT ? argvars[1].vval.v_dict : NULL;
  rettv->vval.v_number = sign_define_from_dict(name, d);
}

/// "sign_getdefined()" function
void f_sign_getdefined(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, 0);

  if (argvars[0].v_type == VAR_UNKNOWN) {
    sign_T *sp;
    map_foreach_value(&sign_map, sp, {
      tv_list_append_dict(rettv->vval.v_list, sign_get_info_dict(sp));
    });
  } else {
    sign_T *sp = pmap_get(cstr_t)(&sign_map, tv_get_string(&argvars[0]));
    if (sp != NULL) {
      tv_list_append_dict(rettv->vval.v_list, sign_get_info_dict(sp));
    }
  }
}

/// "sign_getplaced()" function
void f_sign_getplaced(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  buf_T *buf = NULL;
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
      dictitem_T *di;
      dict_T *dict = argvars[1].vval.v_dict;
      if ((di = tv_dict_find(dict, "lnum", -1)) != NULL) {
        // get signs placed at this line
        lnum = tv_get_lnum(&di->di_tv);
        if (lnum <= 0) {
          return;
        }
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
        if (*group == NUL) {  // empty string means global group
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
  rettv->vval.v_number = -1;

  // Sign identifier
  bool notanum = false;
  int id = (int)tv_get_number_chk(&argvars[0], &notanum);
  if (notanum) {
    return;
  }
  if (id <= 0) {
    emsg(_(e_invarg));
    return;
  }

  // Sign group
  char *group = (char *)tv_get_string_chk(&argvars[1]);
  if (group == NULL) {
    return;
  }
  if (group[0] == NUL) {
    group = NULL;
  }

  // Buffer to place the sign
  buf_T *buf = get_buf_arg(&argvars[2]);
  if (buf == NULL) {
    return;
  }

  rettv->vval.v_number = sign_jump(id, group, buf);
}

/// Place a new sign using the values specified in dict 'dict'. Returns the sign
/// identifier if successfully placed, otherwise returns -1.
static int sign_place_from_dict(typval_T *id_tv, typval_T *group_tv, typval_T *name_tv,
                                typval_T *buf_tv, dict_T *dict)
{
  dictitem_T *di;

  int id = 0;
  bool notanum = false;
  if (id_tv == NULL) {
    di = tv_dict_find(dict, "id", -1);
    if (di != NULL) {
      id_tv = &di->di_tv;
    }
  }
  if (id_tv != NULL) {
    id = (int)tv_get_number_chk(id_tv, &notanum);
    if (notanum) {
      return -1;
    }
    if (id < 0) {
      emsg(_(e_invarg));
      return -1;
    }
  }

  char *group = NULL;
  if (group_tv == NULL) {
    di = tv_dict_find(dict, "group", -1);
    if (di != NULL) {
      group_tv = &di->di_tv;
    }
  }
  if (group_tv != NULL) {
    group = (char *)tv_get_string_chk(group_tv);
    if (group == NULL) {
      return -1;
    }
    if (group[0] == NUL) {
      group = NULL;
    }
  }

  char *name = NULL;
  if (name_tv == NULL) {
    di = tv_dict_find(dict, "name", -1);
    if (di != NULL) {
      name_tv = &di->di_tv;
    }
  }
  if (name_tv == NULL) {
    return -1;
  }
  name = (char *)tv_get_string_chk(name_tv);
  if (name == NULL) {
    return -1;
  }

  if (buf_tv == NULL) {
    di = tv_dict_find(dict, "buffer", -1);
    if (di != NULL) {
      buf_tv = &di->di_tv;
    }
  }
  if (buf_tv == NULL) {
    return -1;
  }
  buf_T *buf = get_buf_arg(buf_tv);
  if (buf == NULL) {
    return -1;
  }

  linenr_T lnum = 0;
  di = tv_dict_find(dict, "lnum", -1);
  if (di != NULL) {
    lnum = tv_get_lnum(&di->di_tv);
    if (lnum <= 0) {
      emsg(_(e_invarg));
      return -1;
    }
  }

  int prio = -1;
  di = tv_dict_find(dict, "priority", -1);
  if (di != NULL) {
    prio = (int)tv_get_number_chk(&di->di_tv, &notanum);
    if (notanum) {
      return -1;
    }
  }

  uint32_t uid = (uint32_t)id;
  if (sign_place(&uid, group, name, buf, lnum, prio) == OK) {
    return (int)uid;
  }

  return -1;
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

  rettv->vval.v_number = sign_place_from_dict(&argvars[0], &argvars[1],
                                              &argvars[2], &argvars[3], dict);
}

/// "sign_placelist()" function.  Place multiple signs.
void f_sign_placelist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }

  // Process the List of sign attributes
  TV_LIST_ITER_CONST(argvars[0].vval.v_list, li, {
    int sign_id = -1;
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
  TV_LIST_ITER_CONST(l, li, {
    int retval = -1;
    char *name = (char *)tv_get_string_chk(TV_LIST_ITEM_TV(li));
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
  int id = 0;
  buf_T *buf = NULL;
  char *group = (group_tv != NULL) ? (char *)tv_get_string(group_tv)
                                   : tv_dict_get_string(dict, "group", false);
  if (group != NULL && group[0] == NUL) {
    group = NULL;
  }

  if (dict != NULL) {
    if ((di = tv_dict_find(dict, "buffer", -1)) != NULL) {
      buf = get_buf_arg(&di->di_tv);
      if (buf == NULL) {
        return -1;
      }
    }
    if (tv_dict_find(dict, "id", -1) != NULL) {
      id = (int)tv_dict_get_number(dict, "id");
      if (id <= 0) {
        emsg(_(e_invarg));
        return -1;
      }
    }
  }

  return sign_unplace(buf, id, group, 0) - 1;
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
  tv_list_alloc_ret(rettv, kListLenMayKnow);

  if (argvars[0].v_type != VAR_LIST) {
    emsg(_(e_listreq));
    return;
  }

  TV_LIST_ITER_CONST(argvars[0].vval.v_list, li, {
    int retval = -1;
    if (TV_LIST_ITEM_TV(li)->v_type == VAR_DICT) {
      retval = sign_unplace_from_dict(NULL, TV_LIST_ITEM_TV(li)->vval.v_dict);
    } else {
      emsg(_(e_dictreq));
    }
    tv_list_append_number(rettv->vval.v_list, retval);
  });
}
