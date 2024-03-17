#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_getln.h"
#include "nvim/fold.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/os.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "optionstr.c.generated.h"
#endif

static const char e_unclosed_expression_sequence[]
  = N_("E540: Unclosed expression sequence");
static const char e_comma_required[]
  = N_("E536: Comma required");
static const char e_unbalanced_groups[]
  = N_("E542: Unbalanced groups");
static const char e_backupext_and_patchmode_are_equal[]
  = N_("E589: 'backupext' and 'patchmode' are equal");
static const char e_showbreak_contains_unprintable_or_wide_character[]
  = N_("E595: 'showbreak' contains unprintable or wide character");
static const char e_wrong_number_of_characters_for_field_str[]
  = N_("E1511: Wrong number of characters for field \"%s\"");
static const char e_wrong_character_width_for_field_str[]
  = N_("E1512: Wrong character width for field \"%s\"");

static char *(p_ambw_values[]) = { "single", "double", NULL };
static char *(p_bg_values[]) = { "light", "dark", NULL };
static char *(p_bkc_values[]) = { "yes", "auto", "no", "breaksymlink", "breakhardlink", NULL };
static char *(p_bo_values[]) = { "all", "backspace", "cursor", "complete", "copy", "ctrlg", "error",
                                 "esc", "ex", "hangul", "lang", "mess", "showmatch", "operator",
                                 "register", "shell", "spell", "wildmode", NULL };
// Note: Keep this in sync with briopt_check()
static char *(p_briopt_values[]) = { "shift:", "min:", "sbr", "list:", "column:", NULL };
// Note: Keep this in sync with diffopt_changed()
static char *(p_dip_values[]) = { "filler", "context:", "iblank", "icase",
                                  "iwhite", "iwhiteall", "iwhiteeol", "horizontal", "vertical",
                                  "closeoff", "hiddenoff", "foldcolumn:", "followwrap", "internal",
                                  "indent-heuristic", "linematch:", "algorithm:", NULL };
static char *(p_dip_algorithm_values[]) = { "myers", "minimal", "patience", "histogram", NULL };
static char *(p_nf_values[]) = { "bin", "octal", "hex", "alpha", "unsigned", NULL };
static char *(p_ff_values[]) = { FF_UNIX, FF_DOS, FF_MAC, NULL };
static char *(p_cb_values[]) = { "unnamed", "unnamedplus", NULL };
static char *(p_cmp_values[]) = { "internal", "keepascii", NULL };
// Note: Keep this in sync with fill_culopt_flags()
static char *(p_culopt_values[]) = { "line", "screenline", "number", "both", NULL };
static char *(p_dy_values[]) = { "lastline", "truncate", "uhex", "msgsep", NULL };
static char *(p_fdo_values[]) = { "all", "block", "hor", "mark", "percent", "quickfix", "search",
                                  "tag", "insert", "undo", "jump", NULL };
// Note: Keep this in sync with spell_check_sps()
static char *(p_sps_values[]) = { "best", "fast", "double", "expr:", "file:", "timeout:", NULL };
/// Also used for 'viewoptions'!  Keep in sync with SSOP_ flags.
static char *(p_ssop_values[]) = { "buffers", "winpos", "resize", "winsize", "localoptions",
                                   "options", "help", "blank", "globals", "slash", "unix", "sesdir",
                                   "curdir", "folds", "cursor", "tabpages", "terminal", "skiprtp",
                                   NULL };
// Keep in sync with SWB_ flags in option_defs.h
static char *(p_swb_values[]) = { "useopen", "usetab", "split", "newtab", "vsplit", "uselast",
                                  NULL };
static char *(p_spk_values[]) = { "cursor", "screen", "topline", NULL };
static char *(p_tc_values[]) = { "followic", "ignore", "match", "followscs", "smart", NULL };
static char *(p_ve_values[]) = { "block", "insert", "all", "onemore", "none", "NONE", NULL };
// Note: Keep this in sync with check_opt_wim()
static char *(p_wim_values[]) = { "full", "longest", "list", "lastused", NULL };
static char *(p_wop_values[]) = { "fuzzy", "tagfile", "pum", NULL };
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
                                  "popup", NULL };
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
static char *(p_spo_values[]) = { "camel", "noplainbuffer", NULL };
static char *(p_icm_values[]) = { "nosplit", "split", NULL };
static char *(p_jop_values[]) = { "stack", "view", NULL };
static char *(p_tpf_values[]) = { "BS", "HT", "FF", "ESC", "DEL", "C0", "C1", NULL };
static char *(p_rdb_values[]) = { "compositor", "nothrottle", "invalid", "nodelta", "line",
                                  "flush", NULL };
static char *(p_sloc_values[]) = { "last", "statusline", "tabline", NULL };

/// All possible flags for 'shm'.
/// the literal chars before 0 are removed flags. these are safely ignored
static char SHM_ALL[] = { SHM_RO, SHM_MOD, SHM_LINES,
                          SHM_WRI, SHM_ABBREVIATIONS, SHM_WRITE, SHM_TRUNC, SHM_TRUNCALL,
                          SHM_OVER, SHM_OVERALL, SHM_SEARCH, SHM_ATTENTION, SHM_INTRO,
                          SHM_COMPLETIONMENU, SHM_COMPLETIONSCAN, SHM_RECORDING, SHM_FILEINFO,
                          SHM_SEARCHCOUNT, 'n', 'f', 'x', 'i', 0, };

/// After setting various option values: recompute variables that depend on
/// option values.
void didset_string_options(void)
{
  opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, true);
  opt_strings_flags(p_bkc, p_bkc_values, &bkc_flags, true);
  opt_strings_flags(p_bo, p_bo_values, &bo_flags, true);
  opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true);
  opt_strings_flags(p_vop, p_ssop_values, &vop_flags, true);
  opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, true);
  opt_strings_flags(p_dy, p_dy_values, &dy_flags, true);
  opt_strings_flags(p_jop, p_jop_values, &jop_flags, true);
  opt_strings_flags(p_rdb, p_rdb_values, &rdb_flags, true);
  opt_strings_flags(p_tc, p_tc_values, &tc_flags, false);
  opt_strings_flags(p_tpf, p_tpf_values, &tpf_flags, true);
  opt_strings_flags(p_ve, p_ve_values, &ve_flags, true);
  opt_strings_flags(p_swb, p_swb_values, &swb_flags, true);
  opt_strings_flags(p_wop, p_wop_values, &wop_flags, true);
  opt_strings_flags(p_cb, p_cb_values, &cb_flags, true);
}

char *illegal_char(char *errbuf, size_t errbuflen, int c)
{
  if (errbuf == NULL) {
    return "";
  }
  vim_snprintf(errbuf, errbuflen, _("E539: Illegal character <%s>"),
               transchar(c));
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
  check_string_option(&buf->b_p_lop);
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
/// Checks for the string being empty_string_option. This may happen if we're out of memory,
/// xstrdup() returned NULL, which was replaced by empty_string_option by check_options().
/// Does NOT check for P_ALLOCED flag!
void free_string_option(char *p)
{
  if (p != empty_string_option) {
    xfree(p);
  }
}

void clear_string_option(char **pp)
{
  if (*pp != empty_string_option) {
    xfree(*pp);
  }
  *pp = empty_string_option;
}

void check_string_option(char **pp)
{
  if (*pp == NULL) {
    *pp = empty_string_option;
  }
}

/// Set global value for string option when it's a local option.
///
/// @param opt  option
/// @param varp  pointer to option variable
static void set_string_option_global(vimoption_T *opt, char **varp)
{
  char **p;

  // the global value is always allocated
  if (opt->var == VAR_WIN) {
    p = (char **)GLOBAL_WO(varp);
  } else {
    p = (char **)opt->var;
  }
  if (opt->indir != PV_NONE && p != varp) {
    char *s = xstrdup(*varp);
    free_string_option(*p);
    *p = s;
  }
}

/// Set a string option to a new value (without checking the effect).
/// The string is copied into allocated memory.
/// if ("opt_idx" == kOptInvalid) "name" is used, otherwise "opt_idx" is used.
/// When "set_sid" is zero set the scriptID to current_sctx.sc_sid.  When
/// "set_sid" is SID_NONE don't set the scriptID.  Otherwise set the scriptID to
/// "set_sid".
///
/// @param  opt_flags  Option flags.
///
/// TODO(famiu): Remove this and its win/buf variants.
void set_string_option_direct(OptIndex opt_idx, const char *val, int opt_flags, scid_T set_sid)
{
  vimoption_T *opt = get_option(opt_idx);

  if (opt->var == NULL) {  // can't set hidden option
    return;
  }

  assert(opt->var != &p_shada);

  bool both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  char *s = xstrdup(val);
  char **varp = (char **)get_varp_scope(opt, both ? OPT_LOCAL : opt_flags);

  if (opt->flags & P_ALLOCED) {
    free_string_option(*varp);
  }
  *varp = s;

  // For buffer/window local option may also set the global value.
  if (both) {
    set_string_option_global(opt, varp);
  }

  opt->flags |= P_ALLOCED;

  // When setting both values of a global option with a local value,
  // make the local value empty, so that the global value is used.
  if ((opt->indir & PV_BOTH) && both) {
    free_string_option(*varp);
    *varp = empty_string_option;
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
    set_option_sctx(opt_idx, opt_flags, script_ctx);
  }
}

/// Like set_string_option_direct(), but for a window-local option in "wp".
/// Blocks autocommands to avoid the old curwin becoming invalid.
void set_string_option_direct_in_win(win_T *wp, OptIndex opt_idx, const char *val, int opt_flags,
                                     int set_sid)
{
  win_T *save_curwin = curwin;

  block_autocmds();
  curwin = wp;
  curbuf = curwin->w_buffer;
  set_string_option_direct(opt_idx, val, opt_flags, set_sid);
  curwin = save_curwin;
  curbuf = curwin->w_buffer;
  unblock_autocmds();
}

/// Like set_string_option_direct(), but for a buffer-local option in "buf".
/// Blocks autocommands to avoid the old curwin becoming invalid.
void set_string_option_direct_in_buf(buf_T *buf, OptIndex opt_idx, const char *val, int opt_flags,
                                     int set_sid)
{
  buf_T *save_curbuf = curbuf;

  block_autocmds();
  curbuf = buf;
  set_string_option_direct(opt_idx, val, opt_flags, set_sid);
  curbuf = save_curbuf;
  unblock_autocmds();
}

/// Return true if "val" is a valid 'filetype' name.
/// Also used for 'syntax' and 'keymap'.
static bool valid_filetype(const char *val)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return valid_name(val, ".-_");
}

/// Handle setting 'signcolumn' for value 'val'. Store minimum and maximum width.
///
/// @return OK when the value is valid, FAIL otherwise
int check_signcolumn(win_T *wp)
{
  char *val = wp->w_p_scl;
  if (*val == NUL) {
    return FAIL;
  }

  if (check_opt_strings(val, p_scl_values, false) == OK) {
    if (!strncmp(val, "no", 2)) {  // no
      wp->w_minscwidth = wp->w_maxscwidth = SCL_NO;
    } else if (!strncmp(val, "nu", 2) && (wp->w_p_nu || wp->w_p_rnu)) {  // number
      wp->w_minscwidth = wp->w_maxscwidth = SCL_NUM;
    } else if (!strncmp(val, "yes:", 4)) {  // yes:<NUM>
      wp->w_minscwidth = wp->w_maxscwidth = val[4] - '0';
    } else if (*val == 'y') {  // yes
      wp->w_minscwidth = wp->w_maxscwidth = 1;
    } else if (!strncmp(val, "auto:", 5)) {  // auto:<NUM>
      wp->w_minscwidth = 0;
      wp->w_maxscwidth = val[5] - '0';
    } else {  // auto
      wp->w_minscwidth = 0;
      wp->w_maxscwidth = 1;
    }
    return OK;
  }

  if (strncmp(val, "auto:", 5) != 0
      || strlen(val) != 8
      || !ascii_isdigit(val[5])
      || val[6] != '-'
      || !ascii_isdigit(val[7])) {
    return FAIL;
  }

  // auto:<NUM>-<NUM>
  int min = val[5] - '0';
  int max = val[7] - '0';
  if (min < 1 || max < 2 || min > 8 || min >= max) {
    return FAIL;
  }

  wp->w_minscwidth = min;
  wp->w_maxscwidth = max;
  return OK;
}

/// Check validity of options with the 'statusline' format.
/// Return an untranslated error message or NULL.
const char *check_stl_option(char *s)
{
  int groupdepth = 0;
  static char errbuf[ERR_BUFLEN];

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
    if (vim_strchr(STL_ALL, (uint8_t)(*s)) == NULL) {
      return illegal_char(errbuf, sizeof(errbuf), (uint8_t)(*s));
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

/// Check for a "normal" directory or file name in some options.  Disallow a
/// path separator (slash and/or backslash), wildcards and characters that are
/// often illegal in a file name. Be more permissive if "secure" is off.
bool check_illegal_path_names(char *val, uint32_t flags)
{
  return (((flags & P_NFNAME)
           && strpbrk(val, (secure ? "/\\*?[|;&<>\r\n" : "/\\*?[<>\r\n")) != NULL)
          || ((flags & P_NDNAME)
              && strpbrk(val, "*?[|;&<>\r\n") != NULL));
}

/// An option that accepts a list of flags is changed.
/// e.g. 'viewoptions', 'switchbuf', 'casemap', etc.
static const char *did_set_opt_flags(char *val, char **values, unsigned *flagp, bool list)
{
  if (opt_strings_flags(val, values, flagp, list) != OK) {
    return e_invarg;
  }
  return NULL;
}

/// An option that accepts a list of string values is changed.
/// e.g. 'nrformats', 'scrollopt', 'wildoptions', etc.
static const char *did_set_opt_strings(char *val, char **values, bool list)
{
  return did_set_opt_flags(val, values, NULL, list);
}

/// An option which is a list of flags is set.  Valid values are in "flags".
static const char *did_set_option_listflag(char *val, char *flags, char *errbuf, size_t errbuflen)
{
  for (char *s = val; *s; s++) {
    if (vim_strchr(flags, (uint8_t)(*s)) == NULL) {
      return illegal_char(errbuf, errbuflen, (uint8_t)(*s));
    }
  }

  return NULL;
}

/// Expand an option that accepts a list of string values.
static int expand_set_opt_string(optexpand_T *args, char **values, size_t numValues,
                                 int *numMatches, char ***matches)
{
  regmatch_T *regmatch = args->oe_regmatch;
  bool include_orig_val = args->oe_include_orig_val;
  char *option_val = args->oe_opt_value;

  // Assume numValues is small since they are fixed enums, so just allocate
  // upfront instead of needing two passes to calculate output size.
  *matches = xmalloc(sizeof(char *) * (numValues + 1));

  int count = 0;

  if (include_orig_val && *option_val != NUL) {
    (*matches)[count++] = xstrdup(option_val);
  }

  for (char **val = values; *val != NULL; val++) {
    if (include_orig_val && *option_val != NUL) {
      if (strcmp(*val, option_val) == 0) {
        continue;
      }
    }
    if (vim_regexec(regmatch, *val, 0)) {
      (*matches)[count++] = xstrdup(*val);
    }
  }
  if (count == 0) {
    XFREE_CLEAR(*matches);
    return FAIL;
  }
  *numMatches = count;
  return OK;
}

static char *set_opt_callback_orig_option = NULL;
static char *((*set_opt_callback_func)(expand_T *, int));

/// Callback used by expand_set_opt_generic to also include the original value.
static char *expand_set_opt_callback(expand_T *xp, int idx)
{
  if (idx == 0) {
    if (set_opt_callback_orig_option != NULL) {
      return set_opt_callback_orig_option;
    } else {
      return "";  // empty strings are ignored
    }
  }
  return set_opt_callback_func(xp, idx - 1);
}

/// Expand an option with a callback that iterates through a list of possible names.
static int expand_set_opt_generic(optexpand_T *args, CompleteListItemGetter func, int *numMatches,
                                  char ***matches)
{
  set_opt_callback_orig_option = args->oe_include_orig_val ? args->oe_opt_value : NULL;
  set_opt_callback_func = func;

  // not using fuzzy as currently EXPAND_STRING_SETTING doesn't use it
  ExpandGeneric("", args->oe_xp, args->oe_regmatch, matches, numMatches,
                expand_set_opt_callback, false);

  set_opt_callback_orig_option = NULL;
  set_opt_callback_func = NULL;
  return OK;
}

/// Expand an option which is a list of flags.
static int expand_set_opt_listflag(optexpand_T *args, char *flags, int *numMatches, char ***matches)
{
  char *option_val = args->oe_opt_value;
  char *cmdline_val = args->oe_set_arg;
  bool append = args->oe_append;
  bool include_orig_val = args->oe_include_orig_val && (*option_val != NUL);

  size_t num_flags = strlen(flags);

  // Assume we only have small number of flags, so just allocate max size.
  *matches = xmalloc(sizeof(char *) * (num_flags + 1));

  int count = 0;

  if (include_orig_val) {
    (*matches)[count++] = xstrdup(option_val);
  }

  for (char *flag = flags; *flag != NUL; flag++) {
    if (append && vim_strchr(option_val, *flag) != NULL) {
      continue;
    }

    if (vim_strchr(cmdline_val, *flag) == NULL) {
      if (include_orig_val && option_val[1] == NUL && *flag == option_val[0]) {
        // This value is already used as the first choice as it's the
        // existing flag. Just skip it to avoid duplicate.
        continue;
      }
      (*matches)[count++] = xmemdupz(flag, 1);
    }
  }

  if (count == 0) {
    XFREE_CLEAR(*matches);
    return FAIL;
  }
  *numMatches = count;
  return OK;
}

/// The 'ambiwidth' option is changed.
const char *did_set_ambiwidth(optset_T *args FUNC_ATTR_UNUSED)
{
  if (check_opt_strings(p_ambw, p_ambw_values, false) != OK) {
    return e_invarg;
  }
  return check_chars_options();
}

int expand_set_ambiwidth(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_ambw_values,
                               ARRAY_SIZE(p_ambw_values) - 1,
                               numMatches,
                               matches);
}

/// The 'background' option is changed.
const char *did_set_background(optset_T *args)
{
  if (check_opt_strings(p_bg, p_bg_values, false) != OK) {
    return e_invarg;
  }

  if (args->os_oldval.string.data[0] == *p_bg) {
    // Value was not changed
    return NULL;
  }

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
  return NULL;
}

int expand_set_background(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_bg_values,
                               ARRAY_SIZE(p_bg_values) - 1,
                               numMatches,
                               matches);
}

/// The 'backspace' option is changed.
const char *did_set_backspace(optset_T *args FUNC_ATTR_UNUSED)
{
  if (ascii_isdigit(*p_bs)) {
    if (*p_bs != '2') {
      return e_invarg;
    }
  } else if (check_opt_strings(p_bs, p_bs_values, true) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_backspace(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_bs_values,
                               ARRAY_SIZE(p_bs_values) - 1,
                               numMatches,
                               matches);
}

/// The 'backupcopy' option is changed.
const char *did_set_backupcopy(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  const char *oldval = args->os_oldval.string.data;
  int opt_flags = args->os_flags;
  char *bkc = p_bkc;
  unsigned *flags = &bkc_flags;

  if (opt_flags & OPT_LOCAL) {
    bkc = buf->b_p_bkc;
    flags = &buf->b_bkc_flags;
  }

  if ((opt_flags & OPT_LOCAL) && *bkc == NUL) {
    // make the local value empty: use the global value
    *flags = 0;
  } else {
    if (opt_strings_flags(bkc, p_bkc_values, flags, true) != OK) {
      return e_invarg;
    }

    if (((*flags & BKC_AUTO) != 0)
        + ((*flags & BKC_YES) != 0)
        + ((*flags & BKC_NO) != 0) != 1) {
      // Must have exactly one of "auto", "yes"  and "no".
      opt_strings_flags(oldval, p_bkc_values, flags, true);
      return e_invarg;
    }
  }

  return NULL;
}

int expand_set_backupcopy(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_bkc_values,
                               ARRAY_SIZE(p_bkc_values) - 1,
                               numMatches,
                               matches);
}

/// The 'backupext' or the 'patchmode' option is changed.
const char *did_set_backupext_or_patchmode(optset_T *args FUNC_ATTR_UNUSED)
{
  if (strcmp(*p_bex == '.' ? p_bex + 1 : p_bex,
             *p_pm == '.' ? p_pm + 1 : p_pm) == 0) {
    return e_backupext_and_patchmode_are_equal;
  }

  return NULL;
}

/// The 'belloff' option is changed.
const char *did_set_belloff(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_bo, p_bo_values, &bo_flags, true);
}

int expand_set_belloff(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_bo_values,
                               ARRAY_SIZE(p_bo_values) - 1,
                               numMatches,
                               matches);
}

/// The 'breakat' option is changed.
const char *did_set_breakat(optset_T *args FUNC_ATTR_UNUSED)
{
  for (int i = 0; i < 256; i++) {
    breakat_flags[i] = false;
  }

  if (p_breakat != NULL) {
    for (char *p = p_breakat; *p; p++) {
      breakat_flags[(uint8_t)(*p)] = true;
    }
  }

  return NULL;
}

/// The 'breakindentopt' option is changed.
const char *did_set_breakindentopt(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (briopt_check(win) == FAIL) {
    return e_invarg;
  }
  // list setting requires a redraw
  if (win == curwin && win->w_briopt_list) {
    redraw_all_later(UPD_NOT_VALID);
  }

  return NULL;
}

int expand_set_breakindentopt(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_briopt_values,
                               ARRAY_SIZE(p_briopt_values) - 1,
                               numMatches,
                               matches);
}

/// The 'bufhidden' option is changed.
const char *did_set_bufhidden(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  return did_set_opt_strings(buf->b_p_bh, p_bufhidden_values, false);
}

int expand_set_bufhidden(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_bufhidden_values,
                               ARRAY_SIZE(p_bufhidden_values) - 1,
                               numMatches,
                               matches);
}

/// The 'buftype' option is changed.
const char *did_set_buftype(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  win_T *win = (win_T *)args->os_win;
  // When 'buftype' is set, check for valid value.
  if ((buf->terminal && buf->b_p_bt[0] != 't')
      || (!buf->terminal && buf->b_p_bt[0] == 't')
      || check_opt_strings(buf->b_p_bt, p_buftype_values, false) != OK) {
    return e_invarg;
  }
  if (win->w_status_height || global_stl_height()) {
    win->w_redr_status = true;
    redraw_later(win, UPD_VALID);
  }
  buf->b_help = (buf->b_p_bt[0] == 'h');
  redraw_titles();
  return NULL;
}

int expand_set_buftype(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_buftype_values,
                               ARRAY_SIZE(p_buftype_values) - 1,
                               numMatches,
                               matches);
}

/// The 'casemap' option is changed.
const char *did_set_casemap(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_cmp, p_cmp_values, &cmp_flags, true);
}

int expand_set_casemap(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_cmp_values,
                               ARRAY_SIZE(p_cmp_values) - 1,
                               numMatches,
                               matches);
}

/// The global 'listchars' or 'fillchars' option is changed.
static const char *did_set_global_chars_option(win_T *win, char *val, CharsOption what,
                                               int opt_flags, char *errbuf, size_t errbuflen)
{
  const char *errmsg = NULL;
  char **local_ptr = (what == kListchars) ? &win->w_p_lcs : &win->w_p_fcs;

  // only apply the global value to "win" when it does not have a
  // local value
  errmsg = set_chars_option(win, val, what,
                            **local_ptr == NUL || !(opt_flags & OPT_GLOBAL),
                            errbuf, errbuflen);
  if (errmsg != NULL) {
    return errmsg;
  }

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
    char *opt = (what == kListchars) ? wp->w_p_lcs : wp->w_p_fcs;
    if (*opt == NUL) {
      set_chars_option(wp, opt, what, true, errbuf, errbuflen);
    }
  }

  redraw_all_later(UPD_NOT_VALID);

  return NULL;
}

/// The 'fillchars' option or the 'listchars' option is changed.
const char *did_set_chars_option(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  const char *errmsg = NULL;

  if (varp == &p_lcs) {      // global 'listchars'
    errmsg = did_set_global_chars_option(win, *varp, kListchars, args->os_flags,
                                         args->os_errbuf, args->os_errbuflen);
  } else if (varp == &p_fcs) {  // global 'fillchars'
    errmsg = did_set_global_chars_option(win, *varp, kFillchars, args->os_flags,
                                         args->os_errbuf, args->os_errbuflen);
  } else if (varp == &win->w_p_lcs) {  // local 'listchars'
    errmsg = set_chars_option(win, *varp, kListchars, true,
                              args->os_errbuf, args->os_errbuflen);
  } else if (varp == &win->w_p_fcs) {  // local 'fillchars'
    errmsg = set_chars_option(win, *varp, kFillchars, true,
                              args->os_errbuf, args->os_errbuflen);
  }

  return errmsg;
}

/// Expand 'fillchars' or 'listchars' option value.
int expand_set_chars_option(optexpand_T *args, int *numMatches, char ***matches)
{
  char **varp = (char **)args->oe_varp;
  bool is_lcs = (varp == &p_lcs || varp == &curwin->w_p_lcs);
  return expand_set_opt_generic(args,
                                is_lcs ? get_listchars_name : get_fillchars_name,
                                numMatches,
                                matches);
}

/// The 'cinoptions' option is changed.
const char *did_set_cinoptions(optset_T *args FUNC_ATTR_UNUSED)
{
  // TODO(vim): recognize errors
  parse_cino(curbuf);

  return NULL;
}

/// The 'clipboard' option is changed.
const char *did_set_clipboard(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_cb, p_cb_values, &cb_flags, true);
}

int expand_set_clipboard(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_cb_values,
                               ARRAY_SIZE(p_cb_values) - 1,
                               numMatches,
                               matches);
}

/// The 'colorcolumn' option is changed.
const char *did_set_colorcolumn(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  return check_colorcolumn(win);
}

/// The 'comments' option is changed.
const char *did_set_comments(optset_T *args)
{
  char **varp = (char **)args->os_varp;
  char *errmsg = NULL;
  for (char *s = *varp; *s;) {
    while (*s && *s != ':') {
      if (vim_strchr(COM_ALL, (uint8_t)(*s)) == NULL
          && !ascii_isdigit(*s) && *s != '-') {
        errmsg = illegal_char(args->os_errbuf, args->os_errbuflen, (uint8_t)(*s));
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
  return errmsg;
}

/// The 'commentstring' option is changed.
const char *did_set_commentstring(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (**varp != NUL && strstr(*varp, "%s") == NULL) {
    return N_("E537: 'commentstring' must be empty or contain %s");
  }
  return NULL;
}

/// The 'complete' option is changed.
const char *did_set_complete(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // check if it is a valid value for 'complete' -- Acevedo
  for (char *s = *varp; *s;) {
    while (*s == ',' || *s == ' ') {
      s++;
    }
    if (!*s) {
      break;
    }
    if (vim_strchr(".wbuksid]tUf", (uint8_t)(*s)) == NULL) {
      return illegal_char(args->os_errbuf, args->os_errbuflen, (uint8_t)(*s));
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
        if (args->os_errbuf != NULL) {
          vim_snprintf(args->os_errbuf, args->os_errbuflen,
                       _("E535: Illegal character after <%c>"),
                       *--s);
          return args->os_errbuf;
        }
        return "";
      }
    }
  }
  return NULL;
}

int expand_set_complete(optexpand_T *args, int *numMatches, char ***matches)
{
  static char *(p_cpt_values[]) = {
    ".", "w", "b", "u", "k", "kspell", "s", "i", "d", "]", "t", "U", "f", NULL
  };
  return expand_set_opt_string(args,
                               p_cpt_values,
                               ARRAY_SIZE(p_cpt_values) - 1,
                               numMatches,
                               matches);
}

/// The 'completeopt' option is changed.
const char *did_set_completeopt(optset_T *args FUNC_ATTR_UNUSED)
{
  if (check_opt_strings(p_cot, p_cot_values, true) != OK) {
    return e_invarg;
  }
  completeopt_was_set();
  return NULL;
}

int expand_set_completeopt(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_cot_values,
                               ARRAY_SIZE(p_cot_values) - 1,
                               numMatches,
                               matches);
}

#ifdef BACKSLASH_IN_FILENAME
/// The 'completeslash' option is changed.
const char *did_set_completeslash(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  if (check_opt_strings(p_csl, p_csl_values, false) != OK
      || check_opt_strings(buf->b_p_csl, p_csl_values, false) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_completeslash(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_csl_values,
                               ARRAY_SIZE(p_csl_values) - 1,
                               numMatches,
                               matches);
}
#endif

/// The 'concealcursor' option is changed.
const char *did_set_concealcursor(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_option_listflag(*varp, COCU_ALL, args->os_errbuf, args->os_errbuflen);
}

int expand_set_concealcursor(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, COCU_ALL, numMatches, matches);
}

/// The 'cpoptions' option is changed.
const char *did_set_cpoptions(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_option_listflag(*varp, CPO_VI, args->os_errbuf, args->os_errbuflen);
}

int expand_set_cpoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, CPO_VI, numMatches, matches);
}

/// The 'cursorlineopt' option is changed.
const char *did_set_cursorlineopt(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;

  // This could be changed to use opt_strings_flags() instead.
  if (**varp == NUL || fill_culopt_flags(*varp, win) != OK) {
    return e_invarg;
  }

  return NULL;
}

int expand_set_cursorlineopt(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_culopt_values,
                               ARRAY_SIZE(p_culopt_values) - 1,
                               numMatches,
                               matches);
}

/// The 'debug' option is changed.
const char *did_set_debug(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_debug, p_debug_values, false);
}

int expand_set_debug(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_debug_values,
                               ARRAY_SIZE(p_debug_values) - 1,
                               numMatches,
                               matches);
}

/// The 'diffopt' option is changed.
const char *did_set_diffopt(optset_T *args FUNC_ATTR_UNUSED)
{
  if (diffopt_changed() == FAIL) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_diffopt(optexpand_T *args, int *numMatches, char ***matches)
{
  expand_T *xp = args->oe_xp;

  if (xp->xp_pattern > args->oe_set_arg && *(xp->xp_pattern - 1) == ':') {
    // Within "algorithm:", we have a subgroup of possible options.
    const size_t algo_len = strlen("algorithm:");
    if (xp->xp_pattern - args->oe_set_arg >= (int)algo_len
        && strncmp(xp->xp_pattern - algo_len, "algorithm:", algo_len) == 0) {
      return expand_set_opt_string(args,
                                   p_dip_algorithm_values,
                                   ARRAY_SIZE(p_dip_algorithm_values) - 1,
                                   numMatches,
                                   matches);
    }
    return FAIL;
  }

  return expand_set_opt_string(args,
                               p_dip_values,
                               ARRAY_SIZE(p_dip_values) - 1,
                               numMatches,
                               matches);
}

/// The 'display' option is changed.
const char *did_set_display(optset_T *args FUNC_ATTR_UNUSED)
{
  if (opt_strings_flags(p_dy, p_dy_values, &dy_flags, true) != OK) {
    return e_invarg;
  }
  init_chartab();
  msg_grid_validate();
  return NULL;
}

int expand_set_display(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_dy_values,
                               ARRAY_SIZE(p_dy_values) - 1,
                               numMatches,
                               matches);
}

/// The 'eadirection' option is changed.
const char *did_set_eadirection(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_ead, p_ead_values, false);
}

int expand_set_eadirection(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_ead_values,
                               ARRAY_SIZE(p_ead_values) - 1,
                               numMatches,
                               matches);
}

/// One of the 'encoding', 'fileencoding' or 'makeencoding'
/// options is changed.
const char *did_set_encoding(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  char **varp = (char **)args->os_varp;
  int opt_flags = args->os_flags;
  // Get the global option to compare with, otherwise we would have to check
  // two values for all local options.
  char **gvarp = (char **)get_option_varp_scope_from(args->os_idx, OPT_GLOBAL, buf, NULL);

  if (gvarp == &p_fenc) {
    if (!MODIFIABLE(buf) && opt_flags != OPT_GLOBAL) {
      return e_modifiable;
    }

    if (vim_strchr(*varp, ',') != NULL) {
      // No comma allowed in 'fileencoding'; catches confusing it
      // with 'fileencodings'.
      return e_invarg;
    }

    // May show a "+" in the title now.
    redraw_titles();
    // Add 'fileencoding' to the swap file.
    ml_setflags(buf);
  }

  // canonize the value, so that strcmp() can be used on it
  char *p = enc_canonize(*varp);
  xfree(*varp);
  *varp = p;
  if (varp == &p_enc) {
    // only encoding=utf-8 allowed
    if (strcmp(p_enc, "utf-8") != 0) {
      return e_unsupportedoption;
    }
    spell_reload();
  }
  return NULL;
}

int expand_set_encoding(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_generic(args, get_encoding_name, numMatches, matches);
}

/// The 'eventignore' option is changed.
const char *did_set_eventignore(optset_T *args FUNC_ATTR_UNUSED)
{
  if (check_ei() == FAIL) {
    return e_invarg;
  }
  return NULL;
}

static char *get_eventignore_name(expand_T *xp, int idx)
{
  // 'eventignore' allows special keyword "all" in addition to
  // all event names.
  if (idx == 0) {
    return "all";
  }
  return get_event_name_no_group(xp, idx - 1);
}

int expand_set_eventignore(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_generic(args, get_eventignore_name, numMatches, matches);
}

/// The 'fileformat' option is changed.
const char *did_set_fileformat(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  char **varp = (char **)args->os_varp;
  const char *oldval = args->os_oldval.string.data;
  int opt_flags = args->os_flags;
  if (!MODIFIABLE(buf) && !(opt_flags & OPT_GLOBAL)) {
    return e_modifiable;
  } else if (check_opt_strings(*varp, p_ff_values, false) != OK) {
    return e_invarg;
  }
  redraw_titles();
  // update flag in swap file
  ml_setflags(buf);
  // Redraw needed when switching to/from "mac": a CR in the text
  // will be displayed differently.
  if (get_fileformat(buf) == EOL_MAC || *oldval == 'm') {
    redraw_buf_later(buf, UPD_NOT_VALID);
  }
  return NULL;
}

int expand_set_fileformat(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_ff_values,
                               ARRAY_SIZE(p_ff_values) - 1,
                               numMatches,
                               matches);
}

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// fileformat options.
char *get_fileformat_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= (int)ARRAY_SIZE(p_ff_values)) {
    return NULL;
  }

  return p_ff_values[idx];
}

/// The 'fileformats' option is changed.
const char *did_set_fileformats(optset_T *args)
{
  return did_set_opt_strings(p_ffs, p_ff_values, true);
}

/// The 'filetype' or the 'syntax' option is changed.
const char *did_set_filetype_or_syntax(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (!valid_filetype(*varp)) {
    return e_invarg;
  }

  args->os_value_changed = strcmp(args->os_oldval.string.data, *varp) != 0;

  // Since we check the value, there is no need to set P_INSECURE,
  // even when the value comes from a modeline.
  args->os_value_checked = true;

  return NULL;
}

/// The 'foldclose' option is changed.
const char *did_set_foldclose(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_fcl, p_fcl_values, true);
}

int expand_set_foldclose(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_fcl_values,
                               ARRAY_SIZE(p_fcl_values) - 1,
                               numMatches,
                               matches);
}

/// The 'foldcolumn' option is changed.
const char *did_set_foldcolumn(optset_T *args)
{
  char **varp = (char **)args->os_varp;
  if (**varp == NUL || check_opt_strings(*varp, p_fdc_values, false) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_foldcolumn(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_fdc_values,
                               ARRAY_SIZE(p_fdc_values) - 1,
                               numMatches,
                               matches);
}

/// The 'foldexpr' option is changed.
const char *did_set_foldexpr(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  did_set_optexpr(args);
  if (foldmethodIsExpr(win)) {
    foldUpdateAll(win);
  }
  return NULL;
}

/// The 'foldignore' option is changed.
const char *did_set_foldignore(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (foldmethodIsIndent(win)) {
    foldUpdateAll(win);
  }
  return NULL;
}

/// The 'foldmarker' option is changed.
const char *did_set_foldmarker(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  char *p = vim_strchr(*varp, ',');

  if (p == NULL) {
    return e_comma_required;
  }

  if (p == *varp || p[1] == NUL) {
    return e_invarg;
  }

  if (foldmethodIsMarker(win)) {
    foldUpdateAll(win);
  }

  return NULL;
}

/// The 'foldmethod' option is changed.
const char *did_set_foldmethod(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  if (check_opt_strings(*varp, p_fdm_values, false) != OK
      || *win->w_p_fdm == NUL) {
    return e_invarg;
  }
  foldUpdateAll(win);
  if (foldmethodIsDiff(win)) {
    newFoldLevel();
  }
  return NULL;
}

int expand_set_foldmethod(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_fdm_values,
                               ARRAY_SIZE(p_fdm_values) - 1,
                               numMatches,
                               matches);
}

/// The 'foldopen' option is changed.
const char *did_set_foldopen(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_fdo, p_fdo_values, &fdo_flags, true);
}

int expand_set_foldopen(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_fdo_values,
                               ARRAY_SIZE(p_fdo_values) - 1,
                               numMatches,
                               matches);
}

/// The 'formatoptions' option is changed.
const char *did_set_formatoptions(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_option_listflag(*varp, FO_ALL, args->os_errbuf, args->os_errbuflen);
}

int expand_set_formatoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, FO_ALL, numMatches, matches);
}

/// The 'guicursor' option is changed.
const char *did_set_guicursor(optset_T *args FUNC_ATTR_UNUSED)
{
  const char *errmsg = parse_shape_opt(SHAPE_CURSOR);
  if (errmsg != NULL) {
    return errmsg;
  }
  if (VIsual_active) {
    // In Visual mode cursor may be drawn differently.
    redrawWinline(curwin, curwin->w_cursor.lnum);
  }
  return NULL;
}

/// The 'helpfile' option is changed.
const char *did_set_helpfile(optset_T *args FUNC_ATTR_UNUSED)
{
  // May compute new values for $VIM and $VIMRUNTIME
  if (didset_vim) {
    vim_unsetenv_ext("VIM");
  }
  if (didset_vimruntime) {
    vim_unsetenv_ext("VIMRUNTIME");
  }
  return NULL;
}

/// The 'helplang' option is changed.
const char *did_set_helplang(optset_T *args FUNC_ATTR_UNUSED)
{
  // Check for "", "ab", "ab,cd", etc.
  for (char *s = p_hlg; *s != NUL; s += 3) {
    if (s[1] == NUL || ((s[2] != ',' || s[3] == NUL) && s[2] != NUL)) {
      return e_invarg;
    }
    if (s[2] == NUL) {
      break;
    }
  }
  return NULL;
}

/// The 'highlight' option is changed.
const char *did_set_highlight(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (strcmp(*varp, HIGHLIGHT_INIT) != 0) {
    return e_unsupportedoption;
  }
  return NULL;
}

/// The 'iconstring' option is changed.
const char *did_set_iconstring(optset_T *args)
{
  return did_set_titleiconstring(args, STL_IN_ICON);
}

/// The 'inccommand' option is changed.
const char *did_set_inccommand(optset_T *args FUNC_ATTR_UNUSED)
{
  if (cmdpreview) {
    return e_invarg;
  }
  return did_set_opt_strings(p_icm, p_icm_values, false);
}

int expand_set_inccommand(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_icm_values,
                               ARRAY_SIZE(p_icm_values) - 1,
                               numMatches,
                               matches);
}

/// The 'isident' or the 'iskeyword' or the 'isprint' or the 'isfname' option is
/// changed.
const char *did_set_isopt(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // 'isident', 'iskeyword', 'isprint or 'isfname' option: refill g_chartab[]
  // If the new option is invalid, use old value.
  // 'lisp' option: refill g_chartab[] for '-' char
  if (buf_init_chartab(buf, true) == FAIL) {
    args->os_restore_chartab = true;  // need to restore it below
    return e_invarg;                  // error in value
  }
  return NULL;
}

/// The 'jumpoptions' option is changed.
const char *did_set_jumpoptions(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_jop, p_jop_values, &jop_flags, true);
}

int expand_set_jumpoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_jop_values,
                               ARRAY_SIZE(p_jop_values) - 1,
                               numMatches,
                               matches);
}

/// The 'keymap' option has changed.
const char *did_set_keymap(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  char **varp = (char **)args->os_varp;
  int opt_flags = args->os_flags;

  if (!valid_filetype(*varp)) {
    return e_invarg;
  }

  int secure_save = secure;

  // Reset the secure flag, since the value of 'keymap' has
  // been checked to be safe.
  secure = 0;

  // load or unload key mapping tables
  const char *errmsg = keymap_init();

  secure = secure_save;

  // Since we check the value, there is no need to set P_INSECURE,
  // even when the value comes from a modeline.
  args->os_value_checked = true;

  if (errmsg == NULL) {
    if (*buf->b_p_keymap != NUL) {
      // Installed a new keymap, switch on using it.
      buf->b_p_iminsert = B_IMODE_LMAP;
      if (buf->b_p_imsearch != B_IMODE_USE_INSERT) {
        buf->b_p_imsearch = B_IMODE_LMAP;
      }
    } else {
      // Cleared the keymap, may reset 'iminsert' and 'imsearch'.
      if (buf->b_p_iminsert == B_IMODE_LMAP) {
        buf->b_p_iminsert = B_IMODE_NONE;
      }
      if (buf->b_p_imsearch == B_IMODE_LMAP) {
        buf->b_p_imsearch = B_IMODE_USE_INSERT;
      }
    }
    if ((opt_flags & OPT_LOCAL) == 0) {
      set_iminsert_global(buf);
      set_imsearch_global(buf);
    }
    status_redraw_buf(buf);
  }

  return errmsg;
}

/// The 'keymodel' option is changed.
const char *did_set_keymodel(optset_T *args FUNC_ATTR_UNUSED)
{
  if (check_opt_strings(p_km, p_km_values, true) != OK) {
    return e_invarg;
  }
  km_stopsel = (vim_strchr(p_km, 'o') != NULL);
  km_startsel = (vim_strchr(p_km, 'a') != NULL);
  return NULL;
}

int expand_set_keymodel(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_km_values,
                               ARRAY_SIZE(p_km_values) - 1,
                               numMatches,
                               matches);
}

/// The 'lispoptions' option is changed.
const char *did_set_lispoptions(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (**varp != NUL && strcmp(*varp, "expr:0") != 0 && strcmp(*varp, "expr:1") != 0) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_lispoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  static char *(p_lop_values[]) = { "expr:0", "expr:1", NULL };
  return expand_set_opt_string(args,
                               p_lop_values,
                               ARRAY_SIZE(p_lop_values) - 1,
                               numMatches,
                               matches);
}

/// The 'matchpairs' option is changed.
const char *did_set_matchpairs(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  for (char *p = *varp; *p != NUL; p++) {
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
      return e_invarg;
    }
    if (*p == NUL) {
      break;
    }
  }
  return NULL;
}

/// The 'mkspellmem' option is changed.
const char *did_set_mkspellmem(optset_T *args FUNC_ATTR_UNUSED)
{
  if (spell_check_msm() != OK) {
    return e_invarg;
  }
  return NULL;
}

/// The 'mouse' option is changed.
const char *did_set_mouse(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_option_listflag(*varp, MOUSE_ALL, args->os_errbuf, args->os_errbuflen);
}

int expand_set_mouse(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, MOUSE_ALL, numMatches, matches);
}

/// The 'mousemodel' option is changed.
const char *did_set_mousemodel(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_mousem, p_mousem_values, false);
}

int expand_set_mousemodel(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_mousem_values,
                               ARRAY_SIZE(p_mousem_values) - 1,
                               numMatches,
                               matches);
}

/// Handle setting 'mousescroll'.
/// @return error message, NULL if it's OK.
const char *did_set_mousescroll(optset_T *args FUNC_ATTR_UNUSED)
{
  OptInt vertical = -1;
  OptInt horizontal = -1;

  char *string = p_mousescroll;

  while (true) {
    char *end = vim_strchr(string, ',');
    size_t length = end ? (size_t)(end - string) : strlen(string);

    // Both "ver:" and "hor:" are 4 bytes long.
    // They should be followed by at least one digit.
    if (length <= 4) {
      return e_invarg;
    }

    OptInt *direction;

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
        return N_("E5080: Digit expected");
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

int expand_set_mousescroll(optexpand_T *args, int *numMatches, char ***matches)
{
  static char *(p_mousescroll_values[]) = { "hor:", "ver:", NULL };
  return expand_set_opt_string(args,
                               p_mousescroll_values,
                               ARRAY_SIZE(p_mousescroll_values) - 1,
                               numMatches,
                               matches);
}

/// The 'nrformats' option is changed.
const char *did_set_nrformats(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_opt_strings(*varp, p_nf_values, true);
}

int expand_set_nrformats(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_nf_values,
                               ARRAY_SIZE(p_nf_values) - 1,
                               numMatches,
                               matches);
}

/// One of the '*expr' options is changed:, 'diffexpr', 'foldexpr', 'foldtext',
/// 'formatexpr', 'includeexpr', 'indentexpr', 'patchexpr' and 'charconvert'.
const char *did_set_optexpr(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // If the option value starts with <SID> or s:, then replace that with
  // the script identifier.
  char *name = get_scriptlocal_funcname(*varp);
  if (name != NULL) {
    free_string_option(*varp);
    *varp = name;
  }
  return NULL;
}

/// The 'redrawdebug' option is changed.
const char *did_set_redrawdebug(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_rdb, p_rdb_values, &rdb_flags, true);
}

/// The 'rightleftcmd' option is changed.
const char *did_set_rightleftcmd(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // Currently only "search" is a supported value.
  if (**varp != NUL && strcmp(*varp, "search") != 0) {
    return e_invarg;
  }

  return NULL;
}

int expand_set_rightleftcmd(optexpand_T *args, int *numMatches, char ***matches)
{
  static char *(p_rlc_values[]) = { "search", NULL };
  return expand_set_opt_string(args,
                               p_rlc_values,
                               ARRAY_SIZE(p_rlc_values) - 1,
                               numMatches,
                               matches);
}

/// The 'rulerformat' option is changed.
const char *did_set_rulerformat(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, true, false);
}

/// The 'scrollopt' option is changed.
const char *did_set_scrollopt(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_sbo, p_scbopt_values, true);
}

int expand_set_scrollopt(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_scbopt_values,
                               ARRAY_SIZE(p_scbopt_values) - 1,
                               numMatches,
                               matches);
}

/// The 'selection' option is changed.
const char *did_set_selection(optset_T *args FUNC_ATTR_UNUSED)
{
  if (*p_sel == NUL || check_opt_strings(p_sel, p_sel_values, false) != OK) {
    return e_invarg;
  }
  if (VIsual_active) {
    // Visual selection may be drawn differently.
    redraw_curbuf_later(UPD_INVERTED);
  }
  return NULL;
}

int expand_set_selection(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_sel_values,
                               ARRAY_SIZE(p_sel_values) - 1,
                               numMatches,
                               matches);
}

/// The 'selectmode' option is changed.
const char *did_set_selectmode(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_slm, p_slm_values, true);
}

int expand_set_selectmode(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_slm_values,
                               ARRAY_SIZE(p_slm_values) - 1,
                               numMatches,
                               matches);
}

/// The 'sessionoptions' option is changed.
const char *did_set_sessionoptions(optset_T *args)
{
  if (opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true) != OK) {
    return e_invarg;
  }
  if ((ssop_flags & SSOP_CURDIR) && (ssop_flags & SSOP_SESDIR)) {
    // Don't allow both "sesdir" and "curdir".
    const char *oldval = args->os_oldval.string.data;
    opt_strings_flags(oldval, p_ssop_values, &ssop_flags, true);
    return e_invarg;
  }
  return NULL;
}

int expand_set_sessionoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_ssop_values,
                               ARRAY_SIZE(p_ssop_values) - 1,
                               numMatches,
                               matches);
}

const char *did_set_shada(optset_T *args)
{
  char *errbuf = args->os_errbuf;
  size_t errbuflen = args->os_errbuflen;

  for (char *s = p_shada; *s;) {
    // Check it's a valid character
    if (vim_strchr("!\"%'/:<@cfhnrs", (uint8_t)(*s)) == NULL) {
      return illegal_char(errbuf, errbuflen, (uint8_t)(*s));
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
                       transchar_byte((uint8_t)(*(s - 1))));
          return errbuf;
        } else {
          return "";
        }
      }
    }
    if (*s == ',') {
      s++;
    } else if (*s) {
      if (errbuf != NULL) {
        return N_("E527: Missing comma");
      } else {
        return "";
      }
    }
  }
  if (*p_shada && get_shada_parameter('\'') < 0) {
    return N_("E528: Must specify a ' value");
  }
  return NULL;
}

/// The 'shortmess' option is changed.
const char *did_set_shortmess(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  return did_set_option_listflag(*varp, SHM_ALL, args->os_errbuf, args->os_errbuflen);
}

int expand_set_shortmess(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, SHM_ALL, numMatches, matches);
}

/// The 'showbreak' option is changed.
const char *did_set_showbreak(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  for (char *s = *varp; *s;) {
    if (ptr2cells(s) != 1) {
      return e_showbreak_contains_unprintable_or_wide_character;
    }
    MB_PTR_ADV(s);
  }
  return NULL;
}

/// The 'showcmdloc' option is changed.
const char *did_set_showcmdloc(optset_T *args FUNC_ATTR_UNUSED)
{
  const char *errmsg = did_set_opt_strings(p_sloc, p_sloc_values, false);

  if (errmsg == NULL) {
    comp_col();
  }

  return errmsg;
}

int expand_set_showcmdloc(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_sloc_values,
                               ARRAY_SIZE(p_sloc_values) - 1,
                               numMatches,
                               matches);
}

/// The 'signcolumn' option is changed.
const char *did_set_signcolumn(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  const char *oldval = args->os_oldval.string.data;
  if (check_signcolumn(win) != OK) {
    return e_invarg;
  }
  int scwidth = win->w_minscwidth <= 0 ? 0 : MIN(win->w_maxscwidth, win->w_scwidth);
  win->w_scwidth = MAX(win->w_minscwidth, scwidth);
  // When changing the 'signcolumn' to or from 'number', recompute the
  // width of the number column if 'number' or 'relativenumber' is set.
  if ((*oldval == 'n' && *(oldval + 1) == 'u') || win->w_minscwidth == SCL_NUM) {
    win->w_nrwidth_line_count = 0;
  }
  return NULL;
}

int expand_set_signcolumn(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_scl_values,
                               ARRAY_SIZE(p_scl_values) - 1,
                               numMatches,
                               matches);
}

/// The 'spellcapcheck' option is changed.
const char *did_set_spellcapcheck(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  // When 'spellcapcheck' is set compile the regexp program.
  return compile_cap_prog(win->w_s);
}

/// The 'spellfile' option is changed.
const char *did_set_spellfile(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // When there is a window for this buffer in which 'spell'
  // is set load the wordlists.
  if ((!valid_spellfile(*varp))) {
    return e_invarg;
  }
  return did_set_spell_option(true);
}

/// The 'spelllang' option is changed.
const char *did_set_spelllang(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // When there is a window for this buffer in which 'spell'
  // is set load the wordlists.
  if (!valid_spelllang(*varp)) {
    return e_invarg;
  }
  return did_set_spell_option(false);
}

/// The 'spelloptions' option is changed.
const char *did_set_spelloptions(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (opt_strings_flags(win->w_s->b_p_spo, p_spo_values, &(win->w_s->b_p_spo_flags),
                        true) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_spelloptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_spo_values,
                               ARRAY_SIZE(p_spo_values) - 1,
                               numMatches,
                               matches);
}

/// The 'spellsuggest' option is changed.
const char *did_set_spellsuggest(optset_T *args FUNC_ATTR_UNUSED)
{
  if (spell_check_sps() != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_spellsuggest(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_sps_values,
                               ARRAY_SIZE(p_sps_values) - 1,
                               numMatches,
                               matches);
}

/// The 'splitkeep' option is changed.
const char *did_set_splitkeep(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_strings(p_spk, p_spk_values, false);
}

int expand_set_splitkeep(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_spk_values,
                               ARRAY_SIZE(p_spk_values) - 1,
                               numMatches,
                               matches);
}

/// The 'statuscolumn' option is changed.
const char *did_set_statuscolumn(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, false, true);
}

/// The 'statusline' option is changed.
const char *did_set_statusline(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, false, false);
}

/// The 'statusline', 'winbar', 'tabline', 'rulerformat' or 'statuscolumn' option is changed.
///
/// @param rulerformat  true if the 'rulerformat' option is changed
/// @param statuscolumn  true if the 'statuscolumn' option is changed
static const char *did_set_statustabline_rulerformat(optset_T *args, bool rulerformat,
                                                     bool statuscolumn)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  if (rulerformat) {       // reset ru_wid first
    ru_wid = 0;
  } else if (statuscolumn) {
    // reset 'statuscolumn' width
    win->w_nrwidth_line_count = 0;
  }
  const char *errmsg = NULL;
  char *s = *varp;
  if (rulerformat && *s == '%') {
    // set ru_wid if 'ruf' starts with "%99("
    if (*++s == '-') {        // ignore a '-'
      s++;
    }
    int wid = getdigits_int(&s, true, 0);
    if (wid && *s == '(' && (errmsg = check_stl_option(p_ruf)) == NULL) {
      ru_wid = wid;
    } else {
      errmsg = check_stl_option(p_ruf);
    }
  } else if (rulerformat || s[0] != '%' || s[1] != '!') {
    // check 'statusline', 'winbar', 'tabline' or 'statuscolumn'
    // only if it doesn't start with "%!"
    errmsg = check_stl_option(s);
  }
  if (rulerformat && errmsg == NULL) {
    comp_col();
  }
  return errmsg;
}

/// The 'switchbuf' option is changed.
const char *did_set_switchbuf(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_swb, p_swb_values, &swb_flags, true);
}

int expand_set_switchbuf(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_swb_values,
                               ARRAY_SIZE(p_swb_values) - 1,
                               numMatches,
                               matches);
}

/// The 'tabline' option is changed.
const char *did_set_tabline(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, false, false);
}

/// The 'tagcase' option is changed.
const char *did_set_tagcase(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  int opt_flags = args->os_flags;

  unsigned *flags;
  char *p;

  if (opt_flags & OPT_LOCAL) {
    p = buf->b_p_tc;
    flags = &buf->b_tc_flags;
  } else {
    p = p_tc;
    flags = &tc_flags;
  }

  if ((opt_flags & OPT_LOCAL) && *p == NUL) {
    // make the local value empty: use the global value
    *flags = 0;
  } else if (*p == NUL
             || opt_strings_flags(p, p_tc_values, flags, false) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_tagcase(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_tc_values,
                               ARRAY_SIZE(p_tc_values) - 1,
                               numMatches,
                               matches);
}

/// The 'termpastefilter' option is changed.
const char *did_set_termpastefilter(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_tpf, p_tpf_values, &tpf_flags, true);
}

int expand_set_termpastefilter(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_tpf_values,
                               ARRAY_SIZE(p_tpf_values) - 1,
                               numMatches,
                               matches);
}

/// The 'titlestring' or the 'iconstring' option is changed.
static const char *did_set_titleiconstring(optset_T *args, int flagval)
{
  char **varp = (char **)args->os_varp;

  // NULL => statusline syntax
  if (vim_strchr(*varp, '%') && check_stl_option(*varp) == NULL) {
    stl_syntax |= flagval;
  } else {
    stl_syntax &= ~flagval;
  }
  did_set_title();

  return NULL;
}

/// The 'titlestring' option is changed.
const char *did_set_titlestring(optset_T *args)
{
  return did_set_titleiconstring(args, STL_IN_TITLE);
}

/// The 'varsofttabstop' option is changed.
const char *did_set_varsofttabstop(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  char **varp = (char **)args->os_varp;

  if (!(*varp)[0] || ((*varp)[0] == '0' && !(*varp)[1])) {
    XFREE_CLEAR(buf->b_p_vsts_array);
    return NULL;
  }

  for (char *cp = *varp; *cp; cp++) {
    if (ascii_isdigit(*cp)) {
      continue;
    }
    if (*cp == ',' && cp > *varp && *(cp - 1) != ',') {
      continue;
    }
    return e_invarg;
  }

  colnr_T *oldarray = buf->b_p_vsts_array;
  if (tabstop_set(*varp, &(buf->b_p_vsts_array))) {
    xfree(oldarray);
  } else {
    return e_invarg;
  }
  return NULL;
}

/// The 'varstabstop' option is changed.
const char *did_set_vartabstop(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;

  if (!(*varp)[0] || ((*varp)[0] == '0' && !(*varp)[1])) {
    XFREE_CLEAR(buf->b_p_vts_array);
    return NULL;
  }

  for (char *cp = *varp; *cp; cp++) {
    if (ascii_isdigit(*cp)) {
      continue;
    }
    if (*cp == ',' && cp > *varp && *(cp - 1) != ',') {
      continue;
    }
    return e_invarg;
  }

  colnr_T *oldarray = buf->b_p_vts_array;
  if (tabstop_set(*varp, &(buf->b_p_vts_array))) {
    xfree(oldarray);
    if (foldmethodIsIndent(win)) {
      foldUpdateAll(win);
    }
  } else {
    return e_invarg;
  }
  return NULL;
}

/// The 'verbosefile' option is changed.
const char *did_set_verbosefile(optset_T *args)
{
  verbose_stop();
  if (*p_vfile != NUL && verbose_open() == FAIL) {
    return (char *)e_invarg;
  }
  return NULL;
}

/// The 'viewoptions' option is changed.
const char *did_set_viewoptions(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_vop, p_ssop_values, &vop_flags, true);
}

/// The 'virtualedit' option is changed.
const char *did_set_virtualedit(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;

  char *ve = p_ve;
  unsigned *flags = &ve_flags;

  if (args->os_flags & OPT_LOCAL) {
    ve = win->w_p_ve;
    flags = &win->w_ve_flags;
  }

  if ((args->os_flags & OPT_LOCAL) && *ve == NUL) {
    // make the local value empty: use the global value
    *flags = 0;
  } else {
    if (opt_strings_flags(ve, p_ve_values, flags, true) != OK) {
      return e_invarg;
    } else if (strcmp(ve, args->os_oldval.string.data) != 0) {
      // Recompute cursor position in case the new 've' setting
      // changes something.
      validate_virtcol(win);
      coladvance(win, win->w_virtcol);
    }
  }
  return NULL;
}

int expand_set_virtualedit(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_ve_values,
                               ARRAY_SIZE(p_ve_values) - 1,
                               numMatches,
                               matches);
}

/// The 'whichwrap' option is changed.
const char *did_set_whichwrap(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  // Add ',' to the list flags because 'whichwrap' is a flag
  // list that is comma-separated.
  return did_set_option_listflag(*varp, WW_ALL ",", args->os_errbuf, args->os_errbuflen);
}

int expand_set_whichwrap(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_listflag(args, WW_ALL, numMatches, matches);
}

/// The 'wildmode' option is changed.
const char *did_set_wildmode(optset_T *args FUNC_ATTR_UNUSED)
{
  if (check_opt_wim() == FAIL) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_wildmode(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_wim_values,
                               ARRAY_SIZE(p_wim_values) - 1,
                               numMatches,
                               matches);
}

/// The 'wildoptions' option is changed.
const char *did_set_wildoptions(optset_T *args FUNC_ATTR_UNUSED)
{
  return did_set_opt_flags(p_wop, p_wop_values, &wop_flags, true);
}

int expand_set_wildoptions(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_wop_values,
                               ARRAY_SIZE(p_wop_values) - 1,
                               numMatches,
                               matches);
}

/// The 'winaltkeys' option is changed.
const char *did_set_winaltkeys(optset_T *args FUNC_ATTR_UNUSED)
{
  if (*p_wak == NUL || check_opt_strings(p_wak, p_wak_values, false) != OK) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_winaltkeys(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_string(args,
                               p_wak_values,
                               ARRAY_SIZE(p_wak_values) - 1,
                               numMatches,
                               matches);
}

/// The 'winbar' option is changed.
const char *did_set_winbar(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, false, false);
}

/// The 'winhighlight' option is changed.
const char *did_set_winhighlight(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (!parse_winhl_opt(win)) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_winhighlight(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_generic(args, get_highlight_name, numMatches, matches);
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
static int opt_strings_flags(const char *val, char **values, unsigned *flagp, bool list)
{
  unsigned new_flags = 0;

  while (*val) {
    for (unsigned i = 0;; i++) {
      if (values[i] == NULL) {          // val not found in values[]
        return FAIL;
      }

      size_t len = strlen(values[i]);
      if (strncmp(values[i], val, len) == 0
          && ((list && val[len] == ',') || val[len] == NUL)) {
        val += len + (val[len] == ',');
        assert(i < sizeof(new_flags) * 8);
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

static const char e_conflicts_with_value_of_listchars[]
  = N_("E834: Conflicts with value of 'listchars'");
static const char e_conflicts_with_value_of_fillchars[]
  = N_("E835: Conflicts with value of 'fillchars'");

/// Calls mb_cptr2char_adv(p) and returns the character.
/// If "p" starts with "\x", "\u" or "\U" the hex or unicode value is used.
/// Returns 0 for invalid hex or invalid UTF-8 byte.
static schar_T get_encoded_char_adv(const char **p)
{
  const char *s = *p;

  if (s[0] == '\\' && (s[1] == 'x' || s[1] == 'u' || s[1] == 'U')) {
    int64_t num = 0;
    for (int bytes = s[1] == 'x' ? 1 : s[1] == 'u' ? 2 : 4; bytes > 0; bytes--) {
      *p += 2;
      int n = hexhex2nr(*p);
      if (n < 0) {
        return 0;
      }
      num = num * 256 + n;
    }
    *p += 2;
    return (char2cells((int)num) > 1) ? 0 : schar_from_char((int)num);
  }

  int clen = utfc_ptr2len(s);
  int firstc;
  schar_T c = utfc_ptr2schar(s, &firstc);
  *p += clen;
  // Invalid UTF-8 byte or doublewidth not allowed
  return ((clen == 1 && firstc > 127) || char2cells(firstc) > 1) ? 0 : c;
}

struct chars_tab {
  schar_T *cp;       ///< char value
  const char *name;  ///< char id
  const char *def;   ///< default value
  const char *fallback;      ///< default value when "def" isn't single-width
};

static fcs_chars_T fcs_chars;
static const struct chars_tab fcs_tab[] = {
  { &fcs_chars.stl,        "stl",       " ", NULL },
  { &fcs_chars.stlnc,      "stlnc",     " ", NULL },
  { &fcs_chars.wbr,        "wbr",       " ", NULL },
  { &fcs_chars.horiz,      "horiz",     "─", "-" },
  { &fcs_chars.horizup,    "horizup",   "┴", "-" },
  { &fcs_chars.horizdown,  "horizdown", "┬", "-" },
  { &fcs_chars.vert,       "vert",      "│", "|" },
  { &fcs_chars.vertleft,   "vertleft",  "┤", "|" },
  { &fcs_chars.vertright,  "vertright", "├", "|" },
  { &fcs_chars.verthoriz,  "verthoriz", "┼", "+" },
  { &fcs_chars.fold,       "fold",      "·", "-" },
  { &fcs_chars.foldopen,   "foldopen",  "-", NULL },
  { &fcs_chars.foldclosed, "foldclose", "+", NULL },
  { &fcs_chars.foldsep,    "foldsep",   "│", "|" },
  { &fcs_chars.diff,       "diff",      "-", NULL },
  { &fcs_chars.msgsep,     "msgsep",    " ", NULL },
  { &fcs_chars.eob,        "eob",       "~", NULL },
  { &fcs_chars.lastline,   "lastline",  "@", NULL },
};

static lcs_chars_T lcs_chars;
static const struct chars_tab lcs_tab[] = {
  { &lcs_chars.eol,     "eol",            NULL, NULL },
  { &lcs_chars.ext,     "extends",        NULL, NULL },
  { &lcs_chars.nbsp,    "nbsp",           NULL, NULL },
  { &lcs_chars.prec,    "precedes",       NULL, NULL },
  { &lcs_chars.space,   "space",          NULL, NULL },
  { &lcs_chars.tab2,    "tab",            NULL, NULL },
  { &lcs_chars.lead,    "lead",           NULL, NULL },
  { &lcs_chars.trail,   "trail",          NULL, NULL },
  { &lcs_chars.conceal, "conceal",        NULL, NULL },
  { NULL,               "multispace",     NULL, NULL },
  { NULL,               "leadmultispace", NULL, NULL },
};

static char *field_value_err(char *errbuf, size_t errbuflen, const char *fmt, const char *field)
{
  if (errbuf == NULL) {
    return "";
  }
  vim_snprintf(errbuf, errbuflen, _(fmt), field);
  return errbuf;
}

/// Handle setting 'listchars' or 'fillchars'.
/// Assume monocell characters
///
/// @param value      points to either the global or the window-local value.
/// @param what       kListchars or kFillchars
/// @param apply      if false, do not store the flags, only check for errors.
/// @param errbuf     buffer for error message, can be NULL if it won't be used.
/// @param errbuflen  size of error buffer.
///
/// @return error message, NULL if it's OK.
const char *set_chars_option(win_T *wp, const char *value, CharsOption what, bool apply,
                             char *errbuf, size_t errbuflen)
{
  const char *last_multispace = NULL;   // Last occurrence of "multispace:"
  const char *last_lmultispace = NULL;  // Last occurrence of "leadmultispace:"
  int multispace_len = 0;           // Length of lcs-multispace string
  int lead_multispace_len = 0;      // Length of lcs-leadmultispace string

  const struct chars_tab *tab;
  int entries;
  if (what == kListchars) {
    tab = lcs_tab;
    entries = ARRAY_SIZE(lcs_tab);
    if (wp->w_p_lcs[0] == NUL) {
      value = p_lcs;  // local value is empty, use the global value
    }
  } else {
    tab = fcs_tab;
    entries = ARRAY_SIZE(fcs_tab);
    if (wp->w_p_fcs[0] == NUL) {
      value = p_fcs;  // local value is empty, use the global value
    }
  }

  // first round: check for valid value, second round: assign values
  for (int round = 0; round <= (apply ? 1 : 0); round++) {
    if (round > 0) {
      // After checking that the value is valid: set defaults
      for (int i = 0; i < entries; i++) {
        if (tab[i].cp != NULL) {
          // XXX: Characters taking 2 columns is forbidden (TUI limitation?).
          // Set old defaults in this case.
          *(tab[i].cp) = schar_from_str((tab[i].def && ptr2cells(tab[i].def) == 1)
                                        ? tab[i].def : tab[i].fallback);
        }
      }

      if (what == kListchars) {
        lcs_chars.tab1 = NUL;
        lcs_chars.tab3 = NUL;

        if (multispace_len > 0) {
          lcs_chars.multispace = xmalloc(((size_t)multispace_len + 1) * sizeof(schar_T));
          lcs_chars.multispace[multispace_len] = NUL;
        } else {
          lcs_chars.multispace = NULL;
        }

        if (lead_multispace_len > 0) {
          lcs_chars.leadmultispace = xmalloc(((size_t)lead_multispace_len + 1) * sizeof(schar_T));
          lcs_chars.leadmultispace[lead_multispace_len] = NUL;
        } else {
          lcs_chars.leadmultispace = NULL;
        }
      }
    }

    const char *p = value;
    while (*p) {
      int i;
      for (i = 0; i < entries; i++) {
        const size_t len = strlen(tab[i].name);
        if (!(strncmp(p, tab[i].name, len) == 0 && p[len] == ':')) {
          continue;
        }

        if (what == kListchars && strcmp(tab[i].name, "multispace") == 0) {
          const char *s = p + len + 1;
          if (round == 0) {
            // Get length of lcs-multispace string in the first round
            last_multispace = p;
            multispace_len = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (c1 == 0) {
                return field_value_err(errbuf, errbuflen,
                                       e_wrong_character_width_for_field_str,
                                       tab[i].name);
              }
              multispace_len++;
            }
            if (multispace_len == 0) {
              // lcs-multispace cannot be an empty string
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_number_of_characters_for_field_str,
                                     tab[i].name);
            }
            p = s;
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (p == last_multispace) {
                lcs_chars.multispace[multispace_pos++] = c1;
              }
            }
            p = s;
          }
          break;
        }

        if (what == kListchars && strcmp(tab[i].name, "leadmultispace") == 0) {
          const char *s = p + len + 1;
          if (round == 0) {
            // get length of lcs-leadmultispace string in first round
            last_lmultispace = p;
            lead_multispace_len = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (c1 == 0) {
                return field_value_err(errbuf, errbuflen,
                                       e_wrong_character_width_for_field_str,
                                       tab[i].name);
              }
              lead_multispace_len++;
            }
            if (lead_multispace_len == 0) {
              // lcs-leadmultispace cannot be an empty string
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_number_of_characters_for_field_str,
                                     tab[i].name);
            }
            p = s;
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (p == last_lmultispace) {
                lcs_chars.leadmultispace[multispace_pos++] = c1;
              }
            }
            p = s;
          }
          break;
        }

        const char *s = p + len + 1;
        if (*s == NUL) {
          return field_value_err(errbuf, errbuflen,
                                 e_wrong_number_of_characters_for_field_str,
                                 tab[i].name);
        }
        schar_T c1 = get_encoded_char_adv(&s);
        if (c1 == 0) {
          return field_value_err(errbuf, errbuflen,
                                 e_wrong_character_width_for_field_str,
                                 tab[i].name);
        }
        schar_T c2 = 0;
        schar_T c3 = 0;
        if (tab[i].cp == &lcs_chars.tab2) {
          if (*s == NUL) {
            return field_value_err(errbuf, errbuflen,
                                   e_wrong_number_of_characters_for_field_str,
                                   tab[i].name);
          }
          c2 = get_encoded_char_adv(&s);
          if (c2 == 0) {
            return field_value_err(errbuf, errbuflen,
                                   e_wrong_character_width_for_field_str,
                                   tab[i].name);
          }
          if (!(*s == ',' || *s == NUL)) {
            c3 = get_encoded_char_adv(&s);
            if (c3 == 0) {
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_character_width_for_field_str,
                                     tab[i].name);
            }
          }
        }

        if (*s == ',' || *s == NUL) {
          if (round > 0) {
            if (tab[i].cp == &lcs_chars.tab2) {
              lcs_chars.tab1 = c1;
              lcs_chars.tab2 = c2;
              lcs_chars.tab3 = c3;
            } else if (tab[i].cp != NULL) {
              *(tab[i].cp) = c1;
            }
          }
          p = s;
          break;
        } else {
          return field_value_err(errbuf, errbuflen,
                                 e_wrong_number_of_characters_for_field_str,
                                 tab[i].name);
        }
      }

      if (i == entries) {
        return e_invarg;
      }

      if (*p == ',') {
        p++;
      }
    }
  }

  if (apply) {
    if (what == kListchars) {
      xfree(wp->w_p_lcs_chars.multispace);
      xfree(wp->w_p_lcs_chars.leadmultispace);
      wp->w_p_lcs_chars = lcs_chars;
    } else {
      wp->w_p_fcs_chars = fcs_chars;
    }
  }

  return NULL;          // no error
}

/// Function given to ExpandGeneric() to obtain possible arguments of the
/// 'fillchars' option.
char *get_fillchars_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= (int)ARRAY_SIZE(fcs_tab)) {
    return NULL;
  }

  return (char *)fcs_tab[idx].name;
}

/// Function given to ExpandGeneric() to obtain possible arguments of the
/// 'listchars' option.
char *get_listchars_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= (int)ARRAY_SIZE(lcs_tab)) {
    return NULL;
  }

  return (char *)lcs_tab[idx].name;
}

/// Check all global and local values of 'listchars' and 'fillchars'.
/// May set different defaults in case character widths change.
///
/// @return  an untranslated error message if any of them is invalid, NULL otherwise.
const char *check_chars_options(void)
{
  if (set_chars_option(curwin, p_lcs, kListchars, false, NULL, 0) != NULL) {
    return e_conflicts_with_value_of_listchars;
  }
  if (set_chars_option(curwin, p_fcs, kFillchars, false, NULL, 0) != NULL) {
    return e_conflicts_with_value_of_fillchars;
  }
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (set_chars_option(wp, wp->w_p_lcs, kListchars, true, NULL, 0) != NULL) {
      return e_conflicts_with_value_of_listchars;
    }
    if (set_chars_option(wp, wp->w_p_fcs, kFillchars, true, NULL, 0) != NULL) {
      return e_conflicts_with_value_of_fillchars;
    }
  }
  return NULL;
}
