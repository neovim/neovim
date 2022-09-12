// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_getln.h"
#include "nvim/hardcopy.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/mapping.h"
#include "nvim/memline.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/optionstr.h"
#include "nvim/quickfix.h"
#include "nvim/runtime.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "optionstr.c.generated.h"
#endif

static char e_unclosed_expression_sequence[]
  = N_("E540: Unclosed expression sequence");
static char e_unbalanced_groups[]
  = N_("E542: unbalanced groups");
static char e_backupext_and_patchmode_are_equal[]
  = N_("E589: 'backupext' and 'patchmode' are equal");
static char e_showbreak_contains_unprintable_or_wide_character[]
  = N_("E595: 'showbreak' contains unprintable or wide character");

static char *(p_ambw_values[]) = { "single", "double", NULL };
static char *(p_bg_values[]) = { "light", "dark", NULL };
static char *(p_bkc_values[]) = { "yes", "auto", "no", "breaksymlink", "breakhardlink", NULL };
static char *(p_bo_values[]) = { "all", "backspace", "cursor", "complete", "copy", "ctrlg", "error",
                                 "esc", "ex", "hangul", "lang", "mess", "showmatch", "operator",
                                 "register", "shell", "spell", "wildmode", NULL };
static char *(p_nf_values[]) = { "bin", "octal", "hex", "alpha", "unsigned", NULL };
static char *(p_ff_values[]) = { FF_UNIX, FF_DOS, FF_MAC, NULL };
static char *(p_cmp_values[]) = { "internal", "keepascii", NULL };
static char *(p_dy_values[]) = { "lastline", "truncate", "uhex", "msgsep", NULL };
static char *(p_fdo_values[]) = { "all", "block", "hor", "mark", "percent", "quickfix", "search",
                                  "tag", "insert", "undo", "jump", NULL };
/// Also used for 'viewoptions'!  Keep in sync with SSOP_ flags.
static char *(p_ssop_values[]) = { "buffers", "winpos", "resize", "winsize", "localoptions",
                                   "options", "help", "blank", "globals", "slash", "unix", "sesdir",
                                   "curdir", "folds", "cursor", "tabpages", "terminal", "skiprtp",
                                   NULL };
// Keep in sync with SWB_ flags in option_defs.h
static char *(p_swb_values[]) = { "useopen", "usetab", "split", "newtab", "vsplit", "uselast",
                                  NULL };
static char *(p_tc_values[]) = { "followic", "ignore", "match", "followscs", "smart", NULL };
static char *(p_ve_values[]) = { "block", "insert", "all", "onemore", "none", "NONE", NULL };
static char *(p_wop_values[]) = { "tagfile", "pum", NULL };
static char *(p_wak_values[]) = { "yes", "menu", "no", NULL };
static char *(p_mousem_values[]) = { "extend", "popup", "popup_setpos", "mac", NULL };
static char *(p_sel_values[]) = { "inclusive", "exclusive", "old", NULL };
static char *(p_slm_values[]) = { "mouse", "key", "cmd", NULL };
static char *(p_km_values[]) = { "startsel", "stopsel", NULL };
static char *(p_scbopt_values[]) = { "ver", "hor", "jump", NULL };
static char *(p_debug_values[]) = { "msg", "throw", "beep", NULL };
static char *(p_ead_values[]) = { "both", "ver", "hor", NULL };
static char *(p_buftype_values[]) = { "nofile", "nowrite", "quickfix", "help", "acwrite",
                                      "terminal", "prompt", NULL };
static char *(p_bufhidden_values[]) = { "hide", "unload", "delete", "wipe", NULL };
static char *(p_bs_values[]) = { "indent", "eol", "start", "nostop", NULL };
static char *(p_fdm_values[]) = { "manual", "expr", "marker", "indent",
                                  "syntax",  "diff", NULL };
static char *(p_fcl_values[]) = { "all", NULL };
static char *(p_cot_values[]) = { "menu", "menuone", "longest", "preview", "noinsert", "noselect",
                                  NULL };
#ifdef BACKSLASH_IN_FILENAME
static char *(p_csl_values[]) = { "slash", "backslash", NULL };
#endif

static char *(p_scl_values[]) = { "yes", "no", "auto", "auto:1", "auto:2", "auto:3", "auto:4",
                                  "auto:5", "auto:6", "auto:7", "auto:8", "auto:9", "yes:1",
                                  "yes:2", "yes:3", "yes:4", "yes:5", "yes:6", "yes:7", "yes:8",
                                  "yes:9", "number", NULL };
static char *(p_fdc_values[]) = { "auto", "auto:1", "auto:2", "auto:3", "auto:4", "auto:5",
                                  "auto:6", "auto:7", "auto:8", "auto:9", "0", "1", "2", "3", "4",
                                  "5", "6", "7", "8", "9", NULL };
static char *(p_cb_values[]) = { "unnamed", "unnamedplus", NULL };
static char *(p_spo_values[]) = { "camel", "noplainbuffer", NULL };
static char *(p_icm_values[]) = { "nosplit", "split", NULL };
static char *(p_jop_values[]) = { "stack", "view", NULL };
static char *(p_tpf_values[]) = { "BS", "HT", "FF", "ESC", "DEL", "C0", "C1", NULL };
static char *(p_rdb_values[]) = { "compositor", "nothrottle", "invalid", "nodelta", NULL };

/// All possible flags for 'shm'.
static char SHM_ALL[] = { SHM_RO, SHM_MOD, SHM_FILE, SHM_LAST, SHM_TEXT, SHM_LINES, SHM_NEW,
                          SHM_WRI, SHM_ABBREVIATIONS, SHM_WRITE, SHM_TRUNC, SHM_TRUNCALL,
                          SHM_OVER, SHM_OVERALL, SHM_SEARCH, SHM_ATTENTION, SHM_INTRO,
                          SHM_COMPLETIONMENU, SHM_RECORDING, SHM_FILEINFO, SHM_SEARCHCOUNT, 0, };

/// After setting various option values: recompute variables that depend on
/// option values.
void didset_string_options(void)
{
  (void)opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, true);
  (void)opt_strings_flags(p_bkc, p_bkc_values, &bkc_flags, true);
  (void)opt_strings_flags(p_bo, p_bo_values, &bo_flags, true);
  (void)opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true);
  (void)opt_strings_flags(p_vop, p_ssop_values, &vop_flags, true);
  (void)opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, true);
  (void)opt_strings_flags(p_dy, p_dy_values, &dy_flags, true);
  (void)opt_strings_flags(p_rdb, p_rdb_values, &rdb_flags, true);
  (void)opt_strings_flags(p_tc, p_tc_values, &tc_flags, false);
  (void)opt_strings_flags(p_tpf, p_tpf_values, &tpf_flags, true);
  (void)opt_strings_flags(p_ve, p_ve_values, &ve_flags, true);
  (void)opt_strings_flags(p_swb, p_swb_values, &swb_flags, true);
  (void)opt_strings_flags(p_wop, p_wop_values, &wop_flags, true);
  (void)opt_strings_flags(p_jop, p_jop_values, &jop_flags, true);
  (void)opt_strings_flags(p_cb, p_cb_values, &cb_flags, true);
}

/// Trigger the OptionSet autocommand.
/// "opt_idx"   is the index of the option being set.
/// "opt_flags" can be OPT_LOCAL etc.
/// "oldval"    the old value
/// "oldval_l"  the old local value (only non-NULL if global and local value are set)
/// "oldval_g"  the old global value (only non-NULL if global and local value are set)
/// "newval"    the new value
void trigger_optionsset_string(int opt_idx, int opt_flags, char *oldval, char *oldval_l,
                               char *oldval_g, char *newval)
{
  // Don't do this recursively.
  if (oldval != NULL
      && newval != NULL
      && *get_vim_var_str(VV_OPTION_TYPE) == NUL) {
    char buf_type[7];

    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_OLD, oldval, -1);
    set_vim_var_string(VV_OPTION_NEW, newval, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    if (opt_flags & OPT_LOCAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setlocal", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, oldval, -1);
    }
    if (opt_flags & OPT_GLOBAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setglobal", -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, oldval, -1);
    }
    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
      set_vim_var_string(VV_OPTION_COMMAND, "set", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, oldval_l, -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, oldval_g, -1);
    }
    if (opt_flags & OPT_MODELINE) {
      set_vim_var_string(VV_OPTION_COMMAND, "modeline", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, oldval, -1);
    }
    apply_autocmds(EVENT_OPTIONSET, get_option_fullname(opt_idx), NULL, false, NULL);
    reset_v_option_vars();
  }
}

static char *illegal_char(char *errbuf, size_t errbuflen, int c)
{
  if (errbuf == NULL) {
    return "";
  }
  vim_snprintf(errbuf, errbuflen, _("E539: Illegal character <%s>"),
               (char *)transchar(c));
  return errbuf;
}

/// Check string options in a buffer for NULL value.
void check_buf_options(buf_T *buf)
{
  check_string_option(&buf->b_p_bh);
  check_string_option(&buf->b_p_bt);
  check_string_option(&buf->b_p_fenc);
  check_string_option(&buf->b_p_ff);
  check_string_option(&buf->b_p_def);
  check_string_option(&buf->b_p_inc);
  check_string_option(&buf->b_p_inex);
  check_string_option(&buf->b_p_inde);
  check_string_option(&buf->b_p_indk);
  check_string_option(&buf->b_p_fp);
  check_string_option(&buf->b_p_fex);
  check_string_option(&buf->b_p_kp);
  check_string_option(&buf->b_p_mps);
  check_string_option(&buf->b_p_fo);
  check_string_option(&buf->b_p_flp);
  check_string_option(&buf->b_p_isk);
  check_string_option(&buf->b_p_com);
  check_string_option(&buf->b_p_cms);
  check_string_option(&buf->b_p_nf);
  check_string_option(&buf->b_p_qe);
  check_string_option(&buf->b_p_syn);
  check_string_option(&buf->b_s.b_syn_isk);
  check_string_option(&buf->b_s.b_p_spc);
  check_string_option(&buf->b_s.b_p_spf);
  check_string_option(&buf->b_s.b_p_spl);
  check_string_option(&buf->b_s.b_p_spo);
  check_string_option(&buf->b_p_sua);
  check_string_option(&buf->b_p_cink);
  check_string_option(&buf->b_p_cino);
  parse_cino(buf);
  check_string_option(&buf->b_p_ft);
  check_string_option(&buf->b_p_cinw);
  check_string_option(&buf->b_p_cinsd);
  check_string_option(&buf->b_p_cpt);
  check_string_option(&buf->b_p_cfu);
  check_string_option(&buf->b_p_ofu);
  check_string_option(&buf->b_p_keymap);
  check_string_option(&buf->b_p_gp);
  check_string_option(&buf->b_p_mp);
  check_string_option(&buf->b_p_efm);
  check_string_option(&buf->b_p_ep);
  check_string_option(&buf->b_p_path);
  check_string_option(&buf->b_p_tags);
  check_string_option(&buf->b_p_tfu);
  check_string_option(&buf->b_p_tc);
  check_string_option(&buf->b_p_dict);
  check_string_option(&buf->b_p_tsr);
  check_string_option(&buf->b_p_tsrfu);
  check_string_option(&buf->b_p_lw);
  check_string_option(&buf->b_p_bkc);
  check_string_option(&buf->b_p_menc);
  check_string_option(&buf->b_p_vsts);
  check_string_option(&buf->b_p_vts);
}

/// Free the string allocated for an option.
/// Checks for the string being empty_option. This may happen if we're out of
/// memory, xstrdup() returned NULL, which was replaced by empty_option by
/// check_options().
/// Does NOT check for P_ALLOCED flag!
void free_string_option(char *p)
{
  if (p != empty_option) {
    xfree(p);
  }
}

void clear_string_option(char **pp)
{
  if (*pp != empty_option) {
    xfree(*pp);
  }
  *pp = empty_option;
}

void check_string_option(char **pp)
{
  if (*pp == NULL) {
    *pp = empty_option;
  }
}

/// Set global value for string option when it's a local option.
///
/// @param opt_idx  option index
/// @param varp  pointer to option variable
static void set_string_option_global(int opt_idx, char **varp)
{
  char **p;

  // the global value is always allocated
  if (is_window_local_option(opt_idx)) {
    p = (char **)GLOBAL_WO(varp);
  } else {
    p = (char **)get_option_var(opt_idx);
  }
  if (!is_global_option(opt_idx) && p != varp) {
    char *s = xstrdup(*varp);
    free_string_option(*p);
    *p = s;
  }
}

/// Set a string option to a new value (without checking the effect).
/// The string is copied into allocated memory.
/// if ("opt_idx" == -1) "name" is used, otherwise "opt_idx" is used.
/// When "set_sid" is zero set the scriptID to current_sctx.sc_sid.  When
/// "set_sid" is SID_NONE don't set the scriptID.  Otherwise set the scriptID to
/// "set_sid".
///
/// @param opt_flags  OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL
void set_string_option_direct(const char *name, int opt_idx, const char *val, int opt_flags,
                              int set_sid)
{
  char *s;
  char **varp;
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int idx = opt_idx;

  if (idx == -1) {  // Use name.
    idx = findoption(name);
    if (idx < 0) {  // Not found (should not happen).
      internal_error("set_string_option_direct()");
      siemsg(_("For option %s"), name);
      return;
    }
  }

  if (is_hidden_option(idx)) {       // can't set hidden option
    return;
  }

  assert((void *)get_option_var(idx) != (void *)&p_shada);

  s = xstrdup(val);
  {
    varp = (char **)get_option_varp_scope(idx, both ? OPT_LOCAL : opt_flags);
    if ((opt_flags & OPT_FREE) && (get_option_flags(idx) & P_ALLOCED)) {
      free_string_option(*varp);
    }
    *varp = s;

    // For buffer/window local option may also set the global value.
    if (both) {
      set_string_option_global(idx, varp);
    }

    set_option_flag(idx, P_ALLOCED);

    // When setting both values of a global option with a local value,
    // make the local value empty, so that the global value is used.
    if (is_global_local_option(idx) && both) {
      free_string_option(*varp);
      *varp = empty_option;
    }
    if (set_sid != SID_NONE) {
      sctx_T script_ctx;

      if (set_sid == 0) {
        script_ctx = current_sctx;
      } else {
        script_ctx.sc_sid = set_sid;
        script_ctx.sc_seq = 0;
        script_ctx.sc_lnum = 0;
      }
      set_option_sctx_idx(idx, opt_flags, script_ctx);
    }
  }
}

/// Like set_string_option_direct(), but for a window-local option in "wp".
/// Blocks autocommands to avoid the old curwin becoming invalid.
void set_string_option_direct_in_win(win_T *wp, const char *name, int opt_idx, const char *val,
                                     int opt_flags, int set_sid)
{
  win_T *save_curwin = curwin;

  block_autocmds();
  curwin = wp;
  curbuf = curwin->w_buffer;
  set_string_option_direct(name, opt_idx, val, opt_flags, set_sid);
  curwin = save_curwin;
  curbuf = curwin->w_buffer;
  unblock_autocmds();
}

/// Set a string option to a new value, handling the effects
///
/// @param[in]  opt_idx  Option to set.
/// @param[in]  value  New value.
/// @param[in]  opt_flags  Option flags: expected to contain #OPT_LOCAL and/or
///                        #OPT_GLOBAL.
///
/// @return NULL on success, an untranslated error message on error.
char *set_string_option(const int opt_idx, const char *const value, const int opt_flags)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (is_hidden_option(opt_idx)) {  // don't set hidden option
    return NULL;
  }

  char *const s = xstrdup(value);
  char **const varp
    = (char **)get_option_varp_scope(opt_idx,
                                     (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
                                     ? (is_global_local_option(opt_idx)
                                        ? OPT_GLOBAL : OPT_LOCAL)
                                     : opt_flags);
  char *const oldval = *varp;
  char *oldval_l = NULL;
  char *oldval_g = NULL;

  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    oldval_l = *(char **)get_option_varp_scope(opt_idx, OPT_LOCAL);
    oldval_g = *(char **)get_option_varp_scope(opt_idx, OPT_GLOBAL);
  }

  *varp = s;

  char *const saved_oldval = xstrdup(oldval);
  char *const saved_oldval_l = (oldval_l != NULL) ? xstrdup(oldval_l) : 0;
  char *const saved_oldval_g = (oldval_g != NULL) ? xstrdup(oldval_g) : 0;
  char *const saved_newval = xstrdup(s);

  int value_checked = false;
  char *const errmsg = did_set_string_option(opt_idx, varp, oldval,
                                             NULL, 0,
                                             opt_flags, &value_checked);
  if (errmsg == NULL) {
    did_set_option(opt_idx, opt_flags, true, value_checked);
  }

  // call autocommand after handling side effects
  if (errmsg == NULL) {
    if (!starting) {
      trigger_optionsset_string(opt_idx, opt_flags, saved_oldval, saved_oldval_l, saved_oldval_g,
                                saved_newval);
    }
    if (get_option_flags(opt_idx) & P_UI_OPTION) {
      ui_call_option_set(cstr_as_string(get_option_fullname(opt_idx)),
                         STRING_OBJ(cstr_as_string(saved_newval)));
    }
  }
  xfree(saved_oldval);
  xfree(saved_oldval_l);
  xfree(saved_oldval_g);
  xfree(saved_newval);

  return errmsg;
}

/// Return true if "val" is a valid 'filetype' name.
/// Also used for 'syntax' and 'keymap'.
static bool valid_filetype(const char *val)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return valid_name(val, ".-_");
}

/// Handle setting 'mousescroll'.
/// @return error message, NULL if it's OK.
static char *check_mousescroll(char *string)
{
  long vertical = -1;
  long horizontal = -1;

  for (;;) {
    char *end = vim_strchr(string, ',');
    size_t length = end ? (size_t)(end - string) : strlen(string);

    // Both "ver:" and "hor:" are 4 bytes long.
    // They should be followed by at least one digit.
    if (length <= 4) {
      return e_invarg;
    }

    long *direction;

    if (memcmp(string, "ver:", 4) == 0) {
      direction = &vertical;
    } else if (memcmp(string, "hor:", 4) == 0) {
      direction = &horizontal;
    } else {
      return e_invarg;
    }

    // If the direction has already been set, this is a duplicate.
    if (*direction != -1) {
      return e_invarg;
    }

    // Verify that only digits follow the colon.
    for (size_t i = 4; i < length; i++) {
      if (!ascii_isdigit(string[i])) {
        return N_("E548: digit expected");
      }
    }

    string += 4;
    *direction = getdigits_int(&string, false, -1);

    // Num options are generally kept within the signed int range.
    // We know this number won't be negative because we've already checked for
    // a minus sign. We'll allow 0 as a means of disabling mouse scrolling.
    if (*direction == -1) {
      return e_invarg;
    }

    if (!end) {
      break;
    }

    string = end + 1;
  }

  // If a direction wasn't set, fallback to the default value.
  p_mousescroll_vert = (vertical == -1) ? MOUSESCROLL_VERT_DFLT : vertical;
  p_mousescroll_hor = (horizontal == -1) ? MOUSESCROLL_HOR_DFLT : horizontal;

  return NULL;
}

/// Handle setting 'signcolumn' for value 'val'
///
/// @return OK when the value is valid, FAIL otherwise
static int check_signcolumn(char *val)
{
  if (*val == NUL) {
    return FAIL;
  }
  // check for basic match
  if (check_opt_strings(val, p_scl_values, false) == OK) {
    return OK;
  }

  // check for 'auto:<NUMBER>-<NUMBER>'
  if (strlen(val) == 8
      && !STRNCMP(val, "auto:", 5)
      && ascii_isdigit(val[5])
      && val[6] == '-'
      && ascii_isdigit(val[7])) {
    int min = val[5] - '0';
    int max = val[7] - '0';
    if (min < 1 || max < 2 || min > 8 || max > 9 || min >= max) {
      return FAIL;
    }
    return OK;
  }

  return FAIL;
}

/// Check validity of options with the 'statusline' format.
/// Return an untranslated error message or NULL.
char *check_stl_option(char *s)
{
  int groupdepth = 0;
  static char errbuf[80];

  while (*s) {
    // Check for valid keys after % sequences
    while (*s && *s != '%') {
      s++;
    }
    if (!*s) {
      break;
    }
    s++;
    if (*s == '%' || *s == STL_TRUNCMARK || *s == STL_SEPARATE) {
      s++;
      continue;
    }
    if (*s == ')') {
      s++;
      if (--groupdepth < 0) {
        break;
      }
      continue;
    }
    if (*s == '-') {
      s++;
    }
    while (ascii_isdigit(*s)) {
      s++;
    }
    if (*s == STL_USER_HL) {
      continue;
    }
    if (*s == '.') {
      s++;
      while (*s && ascii_isdigit(*s)) {
        s++;
      }
    }
    if (*s == '(') {
      groupdepth++;
      continue;
    }
    if (vim_strchr(STL_ALL, *s) == NULL) {
      return illegal_char(errbuf, sizeof(errbuf), *s);
    }
    if (*s == '{') {
      bool reevaluate = (*++s == '%');

      if (reevaluate && *++s == '}') {
        // "}" is not allowed immediately after "%{%"
        return illegal_char(errbuf, sizeof(errbuf), '}');
      }
      while ((*s != '}' || (reevaluate && s[-1] != '%')) && *s) {
        s++;
      }
      if (*s != '}') {
        return e_unclosed_expression_sequence;
      }
    }
  }
  if (groupdepth != 0) {
    return e_unbalanced_groups;
  }
  return NULL;
}

static int shada_idx = -1;

/// Handle string options that need some action to perform when changed.
/// The new value must be allocated.
///
/// @param opt_idx  index in options[] table
/// @param varp  pointer to the option variable
/// @param oldval  previous value of the option
/// @param errbuf  buffer for errors, or NULL
/// @param errbuflen  length of errors buffer
/// @param opt_flags  OPT_LOCAL and/or OPT_GLOBAL
/// @param value_checked  value was checked to be safe, no need to set P_INSECURE
///
/// @return  NULL for success, or an untranslated error message for an error
char *did_set_string_option(int opt_idx, char **varp, char *oldval, char *errbuf, size_t errbuflen,
                            int opt_flags, int *value_checked)
{
  char *errmsg = NULL;
  char *s, *p;
  int did_chartab = false;
  bool free_oldval = (get_option_flags(opt_idx) & P_ALLOCED);
  bool value_changed = false;

  // Get the global option to compare with, otherwise we would have to check
  // two values for all local options.
  char **gvarp = (char **)get_option_varp_scope(opt_idx, OPT_GLOBAL);

  // Disallow changing some options from secure mode
  if ((secure || sandbox != 0)
      && (get_option_flags(opt_idx) & P_SECURE)) {
    errmsg = e_secure;
  } else if (((get_option_flags(opt_idx) & P_NFNAME)
              && strpbrk(*varp, (secure ? "/\\*?[|;&<>\r\n" : "/\\*?[<>\r\n")) != NULL)
             || ((get_option_flags(opt_idx) & P_NDNAME)
                 && strpbrk(*varp, "*?[|;&<>\r\n") != NULL)) {
    // Check for a "normal" directory or file name in some options.  Disallow a
    // path separator (slash and/or backslash), wildcards and characters that
    // are often illegal in a file name. Be more permissive if "secure" is off.
    errmsg = e_invarg;
  } else if (gvarp == &p_bkc) {  // 'backupcopy'
    char *bkc = p_bkc;
    unsigned int *flags = &bkc_flags;

    if (opt_flags & OPT_LOCAL) {
      bkc = curbuf->b_p_bkc;
      flags = &curbuf->b_bkc_flags;
    }

    if ((opt_flags & OPT_LOCAL) && *bkc == NUL) {
      // make the local value empty: use the global value
      *flags = 0;
    } else {
      if (opt_strings_flags(bkc, p_bkc_values, flags, true) != OK) {
        errmsg = e_invarg;
      }

      if (((*flags & BKC_AUTO) != 0)
          + ((*flags & BKC_YES) != 0)
          + ((*flags & BKC_NO) != 0) != 1) {
        // Must have exactly one of "auto", "yes"  and "no".
        (void)opt_strings_flags(oldval, p_bkc_values, flags, true);
        errmsg = e_invarg;
      }
    }
  } else if (varp == &p_bex || varp == &p_pm) {  // 'backupext' and 'patchmode'
    if (strcmp(*p_bex == '.' ? p_bex + 1 : p_bex,
               *p_pm == '.' ? p_pm + 1 : p_pm) == 0) {
      errmsg = e_backupext_and_patchmode_are_equal;
    }
  } else if (varp == &curwin->w_p_briopt) {  // 'breakindentopt'
    if (briopt_check(curwin) == FAIL) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_isi
             || varp == &(curbuf->b_p_isk)
             || varp == &p_isp
             || varp == &p_isf) {
    // 'isident', 'iskeyword', 'isprint or 'isfname' option: refill g_chartab[]
    // If the new option is invalid, use old value.  'lisp' option: refill
    // g_chartab[] for '-' char
    if (init_chartab() == FAIL) {
      did_chartab = true;           // need to restore it below
      errmsg = e_invarg;            // error in value
    }
  } else if (varp == &p_hf) {  // 'helpfile'
    // May compute new values for $VIM and $VIMRUNTIME
    if (didset_vim) {
      vim_unsetenv_ext("VIM");
    }
    if (didset_vimruntime) {
      vim_unsetenv_ext("VIMRUNTIME");
    }
  } else if (varp == &p_rtp || varp == &p_pp) {  // 'runtimepath' 'packpath'
    runtime_search_path_invalidate();
  } else if (varp == &curwin->w_p_culopt
             || gvarp == &curwin->w_allbuf_opt.wo_culopt) {  // 'cursorlineopt'
    if (**varp == NUL || fill_culopt_flags(*varp, curwin) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &curwin->w_p_cc) {  // 'colorcolumn'
    errmsg = check_colorcolumn(curwin);
  } else if (varp == (char **)&p_hlg) {  // 'helplang'
    // Check for "", "ab", "ab,cd", etc.
    for (s = (char *)p_hlg; *s != NUL; s += 3) {
      if (s[1] == NUL || ((s[2] != ',' || s[3] == NUL) && s[2] != NUL)) {
        errmsg = e_invarg;
        break;
      }
      if (s[2] == NUL) {
        break;
      }
    }
  } else if (varp == &p_hl) {  // 'highlight'
    if (strcmp(*varp, HIGHLIGHT_INIT) != 0) {
      errmsg = e_unsupportedoption;
    }
  } else if (varp == &p_jop) {  // 'jumpoptions'
    if (opt_strings_flags(p_jop, p_jop_values, &jop_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_nf) {  // 'nrformats'
    if (check_opt_strings(*varp, p_nf_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_ssop) {  // 'sessionoptions'
    if (opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true) != OK) {
      errmsg = e_invarg;
    }
    if ((ssop_flags & SSOP_CURDIR) && (ssop_flags & SSOP_SESDIR)) {
      // Don't allow both "sesdir" and "curdir".
      (void)opt_strings_flags(oldval, p_ssop_values, &ssop_flags, true);
      errmsg = e_invarg;
    }
  } else if (varp == &p_vop) {  // 'viewoptions'
    if (opt_strings_flags(p_vop, p_ssop_values, &vop_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_rdb) {  // 'redrawdebug'
    if (opt_strings_flags(p_rdb, p_rdb_values, &rdb_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_sbo) {  // 'scrollopt'
    if (check_opt_strings(p_sbo, p_scbopt_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_ambw || (int *)varp == &p_emoji) {  // 'ambiwidth'
    if (check_opt_strings(p_ambw, p_ambw_values, false) != OK) {
      errmsg = e_invarg;
    } else {
      errmsg = check_chars_options();
    }
  } else if (varp == &p_bg) {  // 'background'
    if (check_opt_strings(p_bg, p_bg_values, false) == OK) {
      int dark = (*p_bg == 'd');

      init_highlight(false, false);

      if (dark != (*p_bg == 'd') && get_var_value("g:colors_name") != NULL) {
        // The color scheme must have set 'background' back to another
        // value, that's not what we want here.  Disable the color
        // scheme and set the colors again.
        do_unlet(S_LEN("g:colors_name"), true);
        free_string_option(p_bg);
        p_bg = xstrdup((dark ? "dark" : "light"));
        check_string_option(&p_bg);
        init_highlight(false, false);
      }
    } else {
      errmsg = e_invarg;
    }
  } else if (varp == &p_wim) {  // 'wildmode'
    if (check_opt_wim() == FAIL) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_wop) {  // 'wildoptions'
    if (opt_strings_flags(p_wop, p_wop_values, &wop_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_wak) {  // 'winaltkeys'
    if (*p_wak == NUL
        || check_opt_strings(p_wak, p_wak_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_ei) {  // 'eventignore'
    if (check_ei() == FAIL) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_enc || gvarp == &p_fenc || gvarp == &p_menc) {
    // 'encoding', 'fileencoding' and 'makeencoding'
    if (gvarp == &p_fenc) {
      if (!MODIFIABLE(curbuf) && opt_flags != OPT_GLOBAL) {
        errmsg = e_modifiable;
      } else if (vim_strchr(*varp, ',') != NULL) {
        // No comma allowed in 'fileencoding'; catches confusing it
        // with 'fileencodings'.
        errmsg = e_invarg;
      } else {
        // May show a "+" in the title now.
        redraw_titles();
        // Add 'fileencoding' to the swap file.
        ml_setflags(curbuf);
      }
    }

    if (errmsg == NULL) {
      // canonize the value, so that strcmp() can be used on it
      p = enc_canonize(*varp);
      xfree(*varp);
      *varp = p;
      if (varp == &p_enc) {
        // only encoding=utf-8 allowed
        if (strcmp(p_enc, "utf-8") != 0) {
          errmsg = e_unsupportedoption;
        } else {
          spell_reload();
        }
      }
    }
  } else if (varp == &p_penc) {
    // Canonize printencoding if VIM standard one
    p = enc_canonize(p_penc);
    xfree(p_penc);
    p_penc = p;
  } else if (varp == &curbuf->b_p_keymap) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    } else {
      int secure_save = secure;

      // Reset the secure flag, since the value of 'keymap' has
      // been checked to be safe.
      secure = 0;

      // load or unload key mapping tables
      errmsg = keymap_init();

      secure = secure_save;

      // Since we check the value, there is no need to set P_INSECURE,
      // even when the value comes from a modeline.
      *value_checked = true;
    }

    if (errmsg == NULL) {
      if (*curbuf->b_p_keymap != NUL) {
        // Installed a new keymap, switch on using it.
        curbuf->b_p_iminsert = B_IMODE_LMAP;
        if (curbuf->b_p_imsearch != B_IMODE_USE_INSERT) {
          curbuf->b_p_imsearch = B_IMODE_LMAP;
        }
      } else {
        // Cleared the keymap, may reset 'iminsert' and 'imsearch'.
        if (curbuf->b_p_iminsert == B_IMODE_LMAP) {
          curbuf->b_p_iminsert = B_IMODE_NONE;
        }
        if (curbuf->b_p_imsearch == B_IMODE_LMAP) {
          curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
        }
      }
      if ((opt_flags & OPT_LOCAL) == 0) {
        set_iminsert_global();
        set_imsearch_global();
      }
      status_redraw_curbuf();
    }
  } else if (gvarp == &p_ff) {  // 'fileformat'
    if (!MODIFIABLE(curbuf) && !(opt_flags & OPT_GLOBAL)) {
      errmsg = e_modifiable;
    } else if (check_opt_strings(*varp, p_ff_values, false) != OK) {
      errmsg = e_invarg;
    } else {
      redraw_titles();
      // update flag in swap file
      ml_setflags(curbuf);
      // Redraw needed when switching to/from "mac": a CR in the text
      // will be displayed differently.
      if (get_fileformat(curbuf) == EOL_MAC || *oldval == 'm') {
        redraw_curbuf_later(UPD_NOT_VALID);
      }
    }
  } else if (varp == &p_ffs) {  // 'fileformats'
    if (check_opt_strings(p_ffs, p_ff_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_mps) {  // 'matchpairs'
    for (p = *varp; *p != NUL; p++) {
      int x2 = -1;
      int x3 = -1;

      p += utfc_ptr2len(p);
      if (*p != NUL) {
        x2 = (unsigned char)(*p++);
      }
      if (*p != NUL) {
        x3 = utf_ptr2char(p);
        p += utfc_ptr2len(p);
      }
      if (x2 != ':' || x3 == -1 || (*p != NUL && *p != ',')) {
        errmsg = e_invarg;
        break;
      }
      if (*p == NUL) {
        break;
      }
    }
  } else if (gvarp == &p_com) {  // 'comments'
    for (s = *varp; *s;) {
      while (*s && *s != ':') {
        if (vim_strchr(COM_ALL, *s) == NULL
            && !ascii_isdigit(*s) && *s != '-') {
          errmsg = illegal_char(errbuf, errbuflen, *s);
          break;
        }
        s++;
      }
      if (*s++ == NUL) {
        errmsg = N_("E524: Missing colon");
      } else if (*s == ',' || *s == NUL) {
        errmsg = N_("E525: Zero length string");
      }
      if (errmsg != NULL) {
        break;
      }
      while (*s && *s != ',') {
        if (*s == '\\' && s[1] != NUL) {
          s++;
        }
        s++;
      }
      s = skip_to_option_part(s);
    }
  } else if (varp == &p_lcs || varp == &p_fcs) {  // global 'listchars' or 'fillchars'
    char **local_ptr = varp == &p_lcs ? &curwin->w_p_lcs : &curwin->w_p_fcs;
    // only apply the global value to "curwin" when it does not have a local value
    errmsg =
      set_chars_option(curwin, varp, **local_ptr == NUL || !(opt_flags & OPT_GLOBAL));
    if (errmsg == NULL) {
      // If the current window is set to use the global
      // 'listchars'/'fillchars' value, clear the window-local value.
      if (!(opt_flags & OPT_GLOBAL)) {
        clear_string_option(local_ptr);
      }
      FOR_ALL_TAB_WINDOWS(tp, wp) {
        // If the current window has a local value need to apply it
        // again, it was changed when setting the global value.
        // If no error was returned above, we don't expect an error
        // here, so ignore the return value.
        local_ptr = varp == &p_lcs ? &wp->w_p_lcs : &wp->w_p_fcs;
        if (**local_ptr == NUL) {
          (void)set_chars_option(wp, local_ptr, true);
        }
      }
      redraw_all_later(UPD_NOT_VALID);
    }
  } else if (varp == &curwin->w_p_lcs) {  // local 'listchars'
    errmsg = set_chars_option(curwin, varp, true);
  } else if (varp == &curwin->w_p_fcs) {  // local 'fillchars'
    errmsg = set_chars_option(curwin, varp, true);
  } else if (varp == &p_cedit) {  // 'cedit'
    errmsg = check_cedit();
  } else if (varp == &p_vfile) {  // 'verbosefile'
    verbose_stop();
    if (*p_vfile != NUL && verbose_open() == FAIL) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_shada) {  // 'shada'
    // TODO(ZyX-I): Remove this code in the future, alongside with &viminfo
    //              option.
    opt_idx = ((get_option_fullname(opt_idx)[0] == 'v')
               ? (shada_idx == -1 ? ((shada_idx = findoption("shada"))) : shada_idx)
               : opt_idx);
    // Update free_oldval now that we have the opt_idx for 'shada', otherwise
    // there would be a disconnect between the check for P_ALLOCED at the start
    // of the function and the set of P_ALLOCED at the end of the function.
    free_oldval = (get_option_flags(opt_idx) & P_ALLOCED);
    for (s = p_shada; *s;) {
      // Check it's a valid character
      if (vim_strchr("!\"%'/:<@cfhnrs", *s) == NULL) {
        errmsg = illegal_char(errbuf, errbuflen, *s);
        break;
      }
      if (*s == 'n') {          // name is always last one
        break;
      } else if (*s == 'r') {  // skip until next ','
        while (*++s && *s != ',') {}
      } else if (*s == '%') {
        // optional number
        while (ascii_isdigit(*++s)) {}
      } else if (*s == '!' || *s == 'h' || *s == 'c') {
        s++;                    // no extra chars
      } else {                    // must have a number
        while (ascii_isdigit(*++s)) {}

        if (!ascii_isdigit(*(s - 1))) {
          if (errbuf != NULL) {
            vim_snprintf(errbuf, errbuflen,
                         _("E526: Missing number after <%s>"),
                         transchar_byte(*(s - 1)));
            errmsg = errbuf;
          } else {
            errmsg = "";
          }
          break;
        }
      }
      if (*s == ',') {
        s++;
      } else if (*s) {
        if (errbuf != NULL) {
          errmsg = N_("E527: Missing comma");
        } else {
          errmsg = "";
        }
        break;
      }
    }
    if (*p_shada && errmsg == NULL && get_shada_parameter('\'') < 0) {
      errmsg = N_("E528: Must specify a ' value");
    }
  } else if (gvarp == &p_sbr) {  // 'showbreak'
    for (s = *varp; *s;) {
      if (ptr2cells(s) != 1) {
        errmsg = e_showbreak_contains_unprintable_or_wide_character;
      }
      MB_PTR_ADV(s);
    }
  } else if (varp == &p_guicursor) {  // 'guicursor'
    errmsg = parse_shape_opt(SHAPE_CURSOR);
  } else if (varp == &p_popt) {
    errmsg = parse_printoptions();
  } else if (varp == &p_pmfn) {
    errmsg = parse_printmbfont();
  } else if (varp == &p_langmap) {  // 'langmap'
    langmap_set();
  } else if (varp == &p_breakat) {  // 'breakat'
    fill_breakat_flags();
  } else if (varp == &p_titlestring || varp == &p_iconstring) {
    // 'titlestring' and 'iconstring'
    int flagval = (varp == &p_titlestring) ? STL_IN_TITLE : STL_IN_ICON;

    // NULL => statusline syntax
    if (vim_strchr(*varp, '%') && check_stl_option(*varp) == NULL) {
      stl_syntax |= flagval;
    } else {
      stl_syntax &= ~flagval;
    }
    did_set_title();
  } else if (varp == &p_sel) {  // 'selection'
    if (*p_sel == NUL
        || check_opt_strings(p_sel, p_sel_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_slm) {  // 'selectmode'
    if (check_opt_strings(p_slm, p_slm_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_km) {  // 'keymodel'
    if (check_opt_strings(p_km, p_km_values, true) != OK) {
      errmsg = e_invarg;
    } else {
      km_stopsel = (vim_strchr(p_km, 'o') != NULL);
      km_startsel = (vim_strchr(p_km, 'a') != NULL);
    }
  } else if (varp == &p_mousem) {  // 'mousemodel'
    if (check_opt_strings(p_mousem, p_mousem_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_mousescroll) {  // 'mousescroll'
    errmsg = check_mousescroll(p_mousescroll);
  } else if (varp == &p_swb) {  // 'switchbuf'
    if (opt_strings_flags(p_swb, p_swb_values, &swb_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_debug) {  // 'debug'
    if (check_opt_strings(p_debug, p_debug_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_dy) {  // 'display'
    if (opt_strings_flags(p_dy, p_dy_values, &dy_flags, true) != OK) {
      errmsg = e_invarg;
    } else {
      (void)init_chartab();
      msg_grid_validate();
    }
  } else if (varp == &p_ead) {  // 'eadirection'
    if (check_opt_strings(p_ead, p_ead_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_cb) {  // 'clipboard'
    if (opt_strings_flags(p_cb, p_cb_values, &cb_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &(curwin->w_s->b_p_spl)  // 'spell'
             || varp == &(curwin->w_s->b_p_spf)) {
    // When 'spelllang' or 'spellfile' is set and there is a window for this
    // buffer in which 'spell' is set load the wordlists.
    const bool is_spellfile = varp == &(curwin->w_s->b_p_spf);

    if ((is_spellfile && !valid_spellfile(*varp))
        || (!is_spellfile && !valid_spelllang(*varp))) {
      errmsg = e_invarg;
    } else {
      errmsg = did_set_spell_option(is_spellfile);
    }
  } else if (varp == &(curwin->w_s->b_p_spc)) {
    // When 'spellcapcheck' is set compile the regexp program.
    errmsg = compile_cap_prog(curwin->w_s);
  } else if (varp == &(curwin->w_s->b_p_spo)) {  // 'spelloptions'
    if (opt_strings_flags(curwin->w_s->b_p_spo, p_spo_values, &(curwin->w_s->b_p_spo_flags),
                          true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_sps) {  // 'spellsuggest'
    if (spell_check_sps() != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_msm) {  // 'mkspellmem'
    if (spell_check_msm() != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_bh) {
    // When 'bufhidden' is set, check for valid value.
    if (check_opt_strings(curbuf->b_p_bh, p_bufhidden_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_bt) {
    // When 'buftype' is set, check for valid value.
    if ((curbuf->terminal && curbuf->b_p_bt[0] != 't')
        || (!curbuf->terminal && curbuf->b_p_bt[0] == 't')
        || check_opt_strings(curbuf->b_p_bt, p_buftype_values, false) != OK) {
      errmsg = e_invarg;
    } else {
      if (curwin->w_status_height || global_stl_height()) {
        curwin->w_redr_status = true;
        redraw_later(curwin, UPD_VALID);
      }
      curbuf->b_help = (curbuf->b_p_bt[0] == 'h');
      redraw_titles();
    }
  } else if (gvarp == &p_stl || gvarp == &p_wbr || varp == &p_tal
             || varp == &p_ruf) {
    // 'statusline', 'winbar', 'tabline' or 'rulerformat'
    int wid;

    if (varp == &p_ruf) {       // reset ru_wid first
      ru_wid = 0;
    }
    s = *varp;
    if (varp == &p_ruf && *s == '%') {
      // set ru_wid if 'ruf' starts with "%99("
      if (*++s == '-') {        // ignore a '-'
        s++;
      }
      wid = getdigits_int(&s, true, 0);
      if (wid && *s == '(' && (errmsg = check_stl_option(p_ruf)) == NULL) {
        ru_wid = wid;
      } else {
        errmsg = check_stl_option(p_ruf);
      }
    } else if (varp == &p_ruf || s[0] != '%' || s[1] != '!') {
      // check 'statusline', 'winbar' or 'tabline' only if it doesn't start with "%!"
      errmsg = check_stl_option(s);
    }
    if (varp == &p_ruf && errmsg == NULL) {
      comp_col();
    }
    // add / remove window bars for 'winbar'
    if (gvarp == &p_wbr) {
      set_winbar(true);
    }
  } else if (gvarp == &p_cpt) {
    // check if it is a valid value for 'complete' -- Acevedo
    for (s = *varp; *s;) {
      while (*s == ',' || *s == ' ') {
        s++;
      }
      if (!*s) {
        break;
      }
      if (vim_strchr(".wbuksid]tU", *s) == NULL) {
        errmsg = illegal_char(errbuf, errbuflen, *s);
        break;
      }
      if (*++s != NUL && *s != ',' && *s != ' ') {
        if (s[-1] == 'k' || s[-1] == 's') {
          // skip optional filename after 'k' and 's'
          while (*s && *s != ',' && *s != ' ') {
            if (*s == '\\' && s[1] != NUL) {
              s++;
            }
            s++;
          }
        } else {
          if (errbuf != NULL) {
            vim_snprintf(errbuf, errbuflen,
                         _("E535: Illegal character after <%c>"),
                         *--s);
            errmsg = errbuf;
          } else {
            errmsg = "";
          }
          break;
        }
      }
    }
  } else if (varp == &p_cot) {  // 'completeopt'
    if (check_opt_strings(p_cot, p_cot_values, true) != OK) {
      errmsg = e_invarg;
    } else {
      completeopt_was_set();
    }
#ifdef BACKSLASH_IN_FILENAME
  } else if (gvarp == &p_csl) {  // 'completeslash'
    if (check_opt_strings(p_csl, p_csl_values, false) != OK
        || check_opt_strings(curbuf->b_p_csl, p_csl_values, false) != OK) {
      errmsg = e_invarg;
    }
#endif
  } else if (varp == &curwin->w_p_scl) {  // 'signcolumn'
    if (check_signcolumn(*varp) != OK) {
      errmsg = e_invarg;
    }
    // When changing the 'signcolumn' to or from 'number', recompute the
    // width of the number column if 'number' or 'relativenumber' is set.
    if (((*oldval == 'n' && *(oldval + 1) == 'u')
         || (*curwin->w_p_scl == 'n' && *(curwin->w_p_scl + 1) == 'u'))
        && (curwin->w_p_nu || curwin->w_p_rnu)) {
      curwin->w_nrwidth_line_count = 0;
    }
  } else if (varp == &curwin->w_p_fdc
             || varp == &curwin->w_allbuf_opt.wo_fdc) {
    // 'foldcolumn'
    if (**varp == NUL || check_opt_strings(*varp, p_fdc_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_pt) {
    // 'pastetoggle': translate key codes like in a mapping
    if (*p_pt) {
      p = NULL;
      (void)replace_termcodes(p_pt,
                              strlen(p_pt),
                              &p, REPTERM_FROM_PART | REPTERM_DO_LT, NULL,
                              CPO_TO_CPO_FLAGS);
      if (p != NULL) {
        free_string_option(p_pt);
        p_pt = p;
      }
    }
  } else if (varp == &p_bs) {  // 'backspace'
    if (ascii_isdigit(*p_bs)) {
      if (*p_bs > '3' || p_bs[1] != NUL) {
        errmsg = e_invarg;
      }
    } else if (check_opt_strings(p_bs, p_bs_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_bo) {
    if (opt_strings_flags(p_bo, p_bo_values, &bo_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_tc) {  // 'tagcase'
    unsigned int *flags;

    if (opt_flags & OPT_LOCAL) {
      p = curbuf->b_p_tc;
      flags = &curbuf->b_tc_flags;
    } else {
      p = p_tc;
      flags = &tc_flags;
    }

    if ((opt_flags & OPT_LOCAL) && *p == NUL) {
      // make the local value empty: use the global value
      *flags = 0;
    } else if (*p == NUL
               || opt_strings_flags(p, p_tc_values, flags, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_cmp) {  // 'casemap'
    if (opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_dip) {  // 'diffopt'
    if (diffopt_changed() == FAIL) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &curwin->w_allbuf_opt.wo_fdm) {  // 'foldmethod'
    if (check_opt_strings(*varp, p_fdm_values, false) != OK
        || *curwin->w_p_fdm == NUL) {
      errmsg = e_invarg;
    } else {
      foldUpdateAll(curwin);
      if (foldmethodIsDiff(curwin)) {
        newFoldLevel();
      }
    }
  } else if (varp == &curwin->w_p_fde) {  // 'foldexpr'
    if (foldmethodIsExpr(curwin)) {
      foldUpdateAll(curwin);
    }
  } else if (gvarp == &curwin->w_allbuf_opt.wo_fmr) {  // 'foldmarker'
    p = vim_strchr(*varp, ',');
    if (p == NULL) {
      errmsg = N_("E536: comma required");
    } else if (p == *varp || p[1] == NUL) {
      errmsg = e_invarg;
    } else if (foldmethodIsMarker(curwin)) {
      foldUpdateAll(curwin);
    }
  } else if (gvarp == &p_cms) {  // 'commentstring'
    if (**varp != NUL && strstr(*varp, "%s") == NULL) {
      errmsg = N_("E537: 'commentstring' must be empty or contain %s");
    }
  } else if (varp == &p_fdo) {  // 'foldopen'
    if (opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_fcl) {  // 'foldclose'
    if (check_opt_strings(p_fcl, p_fcl_values, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &curwin->w_allbuf_opt.wo_fdi) {  // 'foldignore'
    if (foldmethodIsIndent(curwin)) {
      foldUpdateAll(curwin);
    }
  } else if (gvarp == &p_ve) {  // 'virtualedit'
    char *ve = p_ve;
    unsigned int *flags = &ve_flags;

    if (opt_flags & OPT_LOCAL) {
      ve = curwin->w_p_ve;
      flags = &curwin->w_ve_flags;
    }

    if ((opt_flags & OPT_LOCAL) && *ve == NUL) {
      // make the local value empty: use the global value
      *flags = 0;
    } else {
      if (opt_strings_flags(ve, p_ve_values, flags, true) != OK) {
        errmsg = e_invarg;
      } else if (strcmp(p_ve, oldval) != 0) {
        // Recompute cursor position in case the new 've' setting
        // changes something.
        validate_virtcol();
        coladvance(curwin->w_virtcol);
      }
    }
  } else if (varp == &p_csqf) {
    if (p_csqf != NULL) {
      p = p_csqf;
      while (*p != NUL) {
        if (vim_strchr(CSQF_CMDS, *p) == NULL
            || p[1] == NUL
            || vim_strchr(CSQF_FLAGS, p[1]) == NULL
            || (p[2] != NUL && p[2] != ',')) {
          errmsg = e_invarg;
          break;
        } else if (p[2] == NUL) {
          break;
        } else {
          p += 3;
        }
      }
    }
  } else if (gvarp == &p_cino) {  // 'cinoptions'
    // TODO(vim): recognize errors
    parse_cino(curbuf);
  } else if (varp == &p_icm) {  // 'inccommand'
    if (check_opt_strings(p_icm, p_icm_values, false) != OK) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_ft) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    } else {
      value_changed = strcmp(oldval, *varp) != 0;

      // Since we check the value, there is no need to set P_INSECURE,
      // even when the value comes from a modeline.
      *value_checked = true;
    }
  } else if (gvarp == &p_syn) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    } else {
      value_changed = strcmp(oldval, *varp) != 0;

      // Since we check the value, there is no need to set P_INSECURE,
      // even when the value comes from a modeline.
      *value_checked = true;
    }
  } else if (varp == &curwin->w_p_winhl) {
    if (!parse_winhl_opt(curwin)) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_tpf) {
    if (opt_strings_flags(p_tpf, p_tpf_values, &tpf_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &(curbuf->b_p_vsts)) {  // 'varsofttabstop'
    char *cp;

    if (!(*varp)[0] || ((*varp)[0] == '0' && !(*varp)[1])) {
      XFREE_CLEAR(curbuf->b_p_vsts_array);
    } else {
      for (cp = *varp; *cp; cp++) {
        if (ascii_isdigit(*cp)) {
          continue;
        }
        if (*cp == ',' && cp > *varp && *(cp - 1) != ',') {
          continue;
        }
        errmsg = e_invarg;
        break;
      }
      if (errmsg == NULL) {
        long *oldarray = curbuf->b_p_vsts_array;
        if (tabstop_set(*varp, &(curbuf->b_p_vsts_array))) {
          xfree(oldarray);
        } else {
          errmsg = e_invarg;
        }
      }
    }
  } else if (varp == &(curbuf->b_p_vts)) {  // 'vartabstop'
    char *cp;

    if (!(*varp)[0] || ((*varp)[0] == '0' && !(*varp)[1])) {
      XFREE_CLEAR(curbuf->b_p_vts_array);
    } else {
      for (cp = *varp; *cp; cp++) {
        if (ascii_isdigit(*cp)) {
          continue;
        }
        if (*cp == ',' && cp > *varp && *(cp - 1) != ',') {
          continue;
        }
        errmsg = e_invarg;
        break;
      }
      if (errmsg == NULL) {
        long *oldarray = curbuf->b_p_vts_array;
        if (tabstop_set(*varp, &(curbuf->b_p_vts_array))) {
          xfree(oldarray);
          if (foldmethodIsIndent(curwin)) {
            foldUpdateAll(curwin);
          }
        } else {
          errmsg = e_invarg;
        }
      }
    }
  } else if (varp == &p_opfunc) {  // 'operatorfunc'
    if (set_operatorfunc_option() == FAIL) {
      errmsg = e_invarg;
    }
  } else if (varp == &p_qftf) {  // 'quickfixtextfunc'
    if (qf_process_qftf_option() == FAIL) {
      errmsg = e_invarg;
    }
  } else {
    // Options that are a list of flags.
    p = NULL;
    if (varp == &p_ww) {  // 'whichwrap'
      p = WW_ALL;
    }
    if (varp == &p_shm) {  // 'shortmess'
      p = SHM_ALL;
    } else if (varp == &(p_cpo)) {  // 'cpoptions'
      p = CPO_VI;
    } else if (varp == &(curbuf->b_p_fo)) {  // 'formatoptions'
      p = FO_ALL;
    } else if (varp == &curwin->w_p_cocu) {  // 'concealcursor'
      p = COCU_ALL;
    } else if (varp == &p_mouse) {  // 'mouse'
      p = MOUSE_ALL;
    }
    if (p != NULL) {
      for (s = *varp; *s; s++) {
        if (vim_strchr(p, *s) == NULL) {
          errmsg = illegal_char(errbuf, errbuflen, *s);
          break;
        }
      }
    }
  }

  // If error detected, restore the previous value.
  if (errmsg != NULL) {
    free_string_option(*varp);
    *varp = oldval;
    // When resetting some values, need to act on it.
    if (did_chartab) {
      (void)init_chartab();
    }
  } else {
    // Remember where the option was set.
    set_option_sctx_idx(opt_idx, opt_flags, current_sctx);
    // Free string options that are in allocated memory.
    // Use "free_oldval", because recursiveness may change the flags under
    // our fingers (esp. init_highlight()).
    if (free_oldval) {
      free_string_option(oldval);
    }
    set_option_flag(opt_idx, P_ALLOCED);

    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
        && is_global_local_option(opt_idx)) {
      // global option with local value set to use global value; free
      // the local value and make it empty
      p = get_option_varp_scope(opt_idx, OPT_LOCAL);
      free_string_option(*(char **)p);
      *(char **)p = empty_option;
    } else if (!(opt_flags & OPT_LOCAL) && opt_flags != OPT_GLOBAL) {
      // May set global value for local option.
      set_string_option_global(opt_idx, varp);
    }

    // Trigger the autocommand only after setting the flags.
    // When 'syntax' is set, load the syntax of that name
    if (varp == &(curbuf->b_p_syn)) {
      static int syn_recursive = 0;

      syn_recursive++;
      // Only pass true for "force" when the value changed or not used
      // recursively, to avoid endless recurrence.
      apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn, curbuf->b_fname,
                     value_changed || syn_recursive == 1, curbuf);
      curbuf->b_flags |= BF_SYN_SET;
      syn_recursive--;
    } else if (varp == &(curbuf->b_p_ft)) {
      // 'filetype' is set, trigger the FileType autocommand
      // Skip this when called from a modeline and the filetype was
      // already set to this value.
      if (!(opt_flags & OPT_MODELINE) || value_changed) {
        static int ft_recursive = 0;
        int secure_save = secure;

        // Reset the secure flag, since the value of 'filetype' has
        // been checked to be safe.
        secure = 0;

        ft_recursive++;
        did_filetype = true;
        // Only pass true for "force" when the value changed or not
        // used recursively, to avoid endless recurrence.
        apply_autocmds(EVENT_FILETYPE, curbuf->b_p_ft, curbuf->b_fname,
                       value_changed || ft_recursive == 1, curbuf);
        ft_recursive--;
        // Just in case the old "curbuf" is now invalid
        if (varp != &(curbuf->b_p_ft)) {
          varp = NULL;
        }
        secure = secure_save;
      }
    }
    if (varp == &(curwin->w_s->b_p_spl)) {
      char fname[200];
      char *q = curwin->w_s->b_p_spl;

      // Skip the first name if it is "cjk".
      if (STRNCMP(q, "cjk,", 4) == 0) {
        q += 4;
      }

      // Source the spell/LANG.vim in 'runtimepath'.
      // They could set 'spellcapcheck' depending on the language.
      // Use the first name in 'spelllang' up to '_region' or
      // '.encoding'.
      for (p = q; *p != NUL; p++) {
        if (!ASCII_ISALNUM(*p) && *p != '-') {
          break;
        }
      }
      if (p > q) {
        vim_snprintf(fname, sizeof(fname), "spell/%.*s.vim", (int)(p - q), q);
        source_runtime(fname, DIP_ALL);
      }
    }
  }

  if (varp == &p_mouse) {
    setmouse();  // in case 'mouse' changed
  }

  if (curwin->w_curswant != MAXCOL
      && (get_option_flags(opt_idx) & (P_CURSWANT | P_RALL)) != 0) {
    curwin->w_set_curswant = true;
  }

  check_redraw(get_option_flags(opt_idx));

  return errmsg;
}

/// Check an option that can be a range of string values.
///
/// @param list  when true: accept a list of values
///
/// @return  OK for correct value, FAIL otherwise. Empty is always OK.
static int check_opt_strings(char *val, char **values, int list)
{
  return opt_strings_flags(val, values, NULL, list);
}

/// Handle an option that can be a range of string values.
/// Set a flag in "*flagp" for each string present.
///
/// @param val  new value
/// @param values  array of valid string values
/// @param list  when true: accept a list of values
///
/// @return  OK for correct value, FAIL otherwise. Empty is always OK.
static int opt_strings_flags(char *val, char **values, unsigned *flagp, bool list)
{
  unsigned int new_flags = 0;

  while (*val) {
    for (unsigned int i = 0;; i++) {
      if (values[i] == NULL) {          // val not found in values[]
        return FAIL;
      }

      size_t len = strlen(values[i]);
      if (STRNCMP(values[i], val, len) == 0
          && ((list && val[len] == ',') || val[len] == NUL)) {
        val += len + (val[len] == ',');
        assert(i < sizeof(1U) * 8);
        new_flags |= (1U << i);
        break;                  // check next item in val list
      }
    }
  }
  if (flagp != NULL) {
    *flagp = new_flags;
  }

  return OK;
}

/// @return  OK if "p" is a valid fileformat name, FAIL otherwise.
int check_ff_value(char *p)
{
  return check_opt_strings(p, p_ff_values, false);
}
