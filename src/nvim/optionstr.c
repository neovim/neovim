#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/api/private/defs.h"
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
#include "nvim/errors.h"
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
#include "nvim/tag.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "optionstr.c.generated.h"
#endif

static const char e_illegal_character_after_chr[]
  = N_("E535: Illegal character after <%c>");
static const char e_comma_required[]
  = N_("E536: Comma required");
static const char e_unclosed_expression_sequence[]
  = N_("E540: Unclosed expression sequence");
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
  check_str_opt(kOptCasemap, NULL);
  check_str_opt(kOptBackupcopy, NULL);
  check_str_opt(kOptBelloff, NULL);
  check_str_opt(kOptCompletefuzzycollect, NULL);
  check_str_opt(kOptIsexpand, NULL);
  check_str_opt(kOptCompleteopt, NULL);
  check_str_opt(kOptSessionoptions, NULL);
  check_str_opt(kOptViewoptions, NULL);
  check_str_opt(kOptFoldopen, NULL);
  check_str_opt(kOptDisplay, NULL);
  check_str_opt(kOptJumpoptions, NULL);
  check_str_opt(kOptRedrawdebug, NULL);
  check_str_opt(kOptTagcase, NULL);
  check_str_opt(kOptTermpastefilter, NULL);
  check_str_opt(kOptVirtualedit, NULL);
  check_str_opt(kOptSwitchbuf, NULL);
  check_str_opt(kOptTabclose, NULL);
  check_str_opt(kOptWildoptions, NULL);
  check_str_opt(kOptClipboard, NULL);
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
  check_string_option(&buf->b_p_cot);
  check_string_option(&buf->b_p_cpt);
  check_string_option(&buf->b_p_cfu);
  check_string_option(&buf->b_p_ofu);
  check_string_option(&buf->b_p_keymap);
  check_string_option(&buf->b_p_gefm);
  check_string_option(&buf->b_p_gp);
  check_string_option(&buf->b_p_mp);
  check_string_option(&buf->b_p_efm);
  check_string_option(&buf->b_p_ep);
  check_string_option(&buf->b_p_path);
  check_string_option(&buf->b_p_tags);
  check_string_option(&buf->b_p_ffu);
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

/// Return true if "val" is a valid 'filetype' name.
/// Also used for 'syntax' and 'keymap'.
static bool valid_filetype(const char *val)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return valid_name(val, ".-_");
}

/// Handle setting 'signcolumn' for value 'val'. Store minimum and maximum width.
///
/// @param wcl  when NULL: use "wp->w_p_scl"
/// @param wp   when NULL: only parse "scl"
///
/// @return OK when the value is valid, FAIL otherwise
int check_signcolumn(char *scl, win_T *wp)
{
  char *val = empty_string_option;
  if (scl != NULL) {
    val = scl;
  } else if (wp != NULL) {
    val = wp->w_p_scl;
  }

  if (*val == NUL) {
    return FAIL;
  }

  if (opt_strings_flags(val, opt_scl_values, NULL, false) == OK) {
    if (wp == NULL) {
      return OK;
    }
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
  } else {
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
    if (wp == NULL) {
      return OK;
    }
    wp->w_minscwidth = min;
    wp->w_maxscwidth = max;
  }

  int scwidth = wp->w_minscwidth <= 0 ? 0 : MIN(wp->w_maxscwidth, wp->w_scwidth);
  wp->w_scwidth = MAX(wp->w_minscwidth, scwidth);
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
  return (((flags & kOptFlagNFname)
           && strpbrk(val, (secure ? "/\\*?[|;&<>\r\n" : "/\\*?[<>\r\n")) != NULL)
          || ((flags & kOptFlagNDname)
              && strpbrk(val, "*?[|;&<>\r\n") != NULL));
}

/// An option that accepts a list of flags is changed.
/// e.g. 'viewoptions', 'switchbuf', 'casemap', etc.
static const char *did_set_opt_flags(char *val, const char **values, unsigned *flagp, bool list)
{
  if (opt_strings_flags(val, values, flagp, list) != OK) {
    return e_invarg;
  }
  return NULL;
}

static const char **opt_values(OptIndex idx, size_t *values_len)
{
  OptIndex idx1 = idx == kOptViewoptions ? kOptSessionoptions
                                         : idx == kOptFileformats ? kOptFileformat
                                                                  : idx;

  vimoption_T *opt = get_option(idx1);
  if (values_len != NULL) {
    *values_len = opt->values_len;
  }
  return opt->values;
}

static int check_str_opt(OptIndex idx, char **varp)
{
  vimoption_T *opt = get_option(idx);
  if (varp == NULL) {
    varp = opt->var;
  }
  bool list = opt->flags & (kOptFlagComma | kOptFlagOneComma);
  const char **values = opt_values(idx, NULL);
  return opt_strings_flags(*varp, values, opt->flags_var, list);
}

int expand_set_str_generic(optexpand_T *args, int *numMatches, char ***matches)
{
  size_t values_len;
  const char **values = opt_values(args->oe_idx, &values_len);
  return expand_set_opt_string(args, values, values_len, numMatches, matches);
}

const char *did_set_str_generic(optset_T *args)
{
  return check_str_opt(args->os_idx, args->os_varp) != OK ? e_invarg : NULL;
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
static int expand_set_opt_string(optexpand_T *args, const char **values, size_t numValues,
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

  for (const char **val = values; *val != NULL; val++) {
    if (**val == NUL) {
      continue;  // Ignore empty
    } else if (include_orig_val && *option_val != NUL) {
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
const char *did_set_ambiwidth(optset_T *args)
{
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  return check_chars_options();
}

/// The 'emoji' option is changed.
const char *did_set_emoji(optset_T *args)
{
  if (check_str_opt(kOptAmbiwidth, NULL) != OK) {
    return e_invarg;
  }
  return check_chars_options();
}

/// The 'background' option is changed.
const char *did_set_background(optset_T *args)
{
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
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

  // Notify all terminal buffers that the background color changed so they can
  // send a theme update notification
  FOR_ALL_BUFFERS(buf) {
    if (buf->terminal) {
      terminal_notify_theme(buf->terminal, dark);
    }
  }

  return NULL;
}

/// The 'backspace' option is changed.
const char *did_set_backspace(optset_T *args FUNC_ATTR_UNUSED)
{
  if (ascii_isdigit(*p_bs)) {
    if (*p_bs != '2') {
      return e_invarg;
    }
    return NULL;
  }
  return did_set_str_generic(args);
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
  } else if (!(opt_flags & OPT_GLOBAL)) {
    // When using :set, clear the local flags.
    buf->b_bkc_flags = 0;
  }

  if ((opt_flags & OPT_LOCAL) && *bkc == NUL) {
    // make the local value empty: use the global value
    *flags = 0;
  } else {
    if (opt_strings_flags(bkc, opt_bkc_values, flags, true) != OK) {
      return e_invarg;
    }

    if (((*flags & kOptBkcFlagAuto) != 0)
        + ((*flags & kOptBkcFlagYes) != 0)
        + ((*flags & kOptBkcFlagNo) != 0) != 1) {
      // Must have exactly one of "auto", "yes"  and "no".
      opt_strings_flags(oldval, opt_bkc_values, flags, true);
      return e_invarg;
    }
  }

  return NULL;
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
  char **varp = (char **)args->os_varp;

  if (briopt_check(*varp, varp == &win->w_p_briopt ? win : NULL) == FAIL) {
    return e_invarg;
  }

  // list setting requires a redraw
  if (varp == &win->w_p_briopt && win->w_briopt_list) {
    redraw_all_later(UPD_NOT_VALID);
  }

  return NULL;
}

/// The 'bufhidden' option is changed.
const char *did_set_bufhidden(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  return did_set_opt_flags(buf->b_p_bh, opt_bh_values, NULL, false);
}

/// The 'buftype' option is changed.
const char *did_set_buftype(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  win_T *win = (win_T *)args->os_win;
  // When 'buftype' is set, check for valid value.
  if ((buf->terminal && buf->b_p_bt[0] != 't')
      || (!buf->terminal && buf->b_p_bt[0] == 't')
      || opt_strings_flags(buf->b_p_bt, opt_bt_values, NULL, false) != OK) {
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
const char *did_set_cinoptions(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // TODO(vim): recognize errors
  parse_cino(buf);

  return NULL;
}

/// The 'colorcolumn' option is changed.
const char *did_set_colorcolumn(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  return check_colorcolumn(*varp, varp == &win->w_p_cc ? win : NULL);
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

/// Check if value for 'complete' is valid when 'complete' option is changed.
const char *did_set_complete(optset_T *args)
{
  char **varp = (char **)args->os_varp;
  char buffer[LSIZE];
  uint8_t char_before = NUL;

  for (char *p = *varp; *p;) {
    memset(buffer, 0, LSIZE);
    char *buf_ptr = buffer;
    int escape = 0;

    // Extract substring while handling escaped commas
    while (*p && (*p != ',' || escape) && buf_ptr < (buffer + LSIZE - 1)) {
      if (*p == '\\' && *(p + 1) == ',') {
        escape = 1;  // Mark escape mode
        p++;         // Skip '\'
      } else {
        escape = 0;
        *buf_ptr++ = *p;
      }
      p++;
    }
    *buf_ptr = NUL;

    if (vim_strchr(".wbuksid]tUfFo", (uint8_t)(*buffer)) == NULL) {
      return illegal_char(args->os_errbuf, args->os_errbuflen, (uint8_t)(*buffer));
    }

    if (vim_strchr("ksF", (uint8_t)(*buffer)) == NULL && *(buffer + 1) != NUL
        && *(buffer + 1) != '^') {
      char_before = (uint8_t)(*buffer);
    } else {
      char *t;
      // Test for a number after '^'
      if ((t = vim_strchr(buffer, '^')) != NULL) {
        *t++ = NUL;
        if (!*t) {
          char_before = '^';
        } else {
          for (; *t; t++) {
            if (!ascii_isdigit(*t)) {
              char_before = '^';
              break;
            }
          }
        }
      }
    }
    if (char_before != NUL) {
      if (args->os_errbuf != NULL) {
        vim_snprintf(args->os_errbuf, args->os_errbuflen,
                     _(e_illegal_character_after_chr), char_before);
        return args->os_errbuf;
      }
      return NULL;
    }
    // Skip comma and spaces
    while (*p == ',' || *p == ' ') {
      p++;
    }
  }
  return NULL;
}

/// The 'completeitemalign' option is changed.
const char *did_set_completeitemalign(optset_T *args)
{
  char *p = p_cia;
  unsigned new_cia_flags = 0;
  bool seen[3] = { false, false, false };
  int count = 0;
  char buf[10];
  while (*p) {
    copy_option_part(&p, buf, sizeof(buf), ",");
    if (count >= 3) {
      return e_invarg;
    }
    if (strequal(buf, "abbr")) {
      if (seen[CPT_ABBR]) {
        return e_invarg;
      }
      new_cia_flags = new_cia_flags * 10 + CPT_ABBR;
      seen[CPT_ABBR] = true;
      count++;
    } else if (strequal(buf, "kind")) {
      if (seen[CPT_KIND]) {
        return e_invarg;
      }
      new_cia_flags = new_cia_flags * 10 + CPT_KIND;
      seen[CPT_KIND] = true;
      count++;
    } else if (strequal(buf, "menu")) {
      if (seen[CPT_MENU]) {
        return e_invarg;
      }
      new_cia_flags = new_cia_flags * 10 + CPT_MENU;
      seen[CPT_MENU] = true;
      count++;
    } else {
      return e_invarg;
    }
  }
  if (new_cia_flags == 0 || count != 3) {
    return e_invarg;
  }
  cia_flags = new_cia_flags;
  return NULL;
}

/// The 'completeopt' option is changed.
const char *did_set_completeopt(optset_T *args FUNC_ATTR_UNUSED)
{
  buf_T *buf = (buf_T *)args->os_buf;
  char *cot = p_cot;
  unsigned *flags = &cot_flags;

  if (args->os_flags & OPT_LOCAL) {
    cot = buf->b_p_cot;
    flags = &buf->b_cot_flags;
  } else if (!(args->os_flags & OPT_GLOBAL)) {
    // When using :set, clear the local flags.
    buf->b_cot_flags = 0;
  }

  if (opt_strings_flags(cot, opt_cot_values, NULL, true) != OK) {
    return e_invarg;
  }

  if (opt_strings_flags(cot, opt_cot_values, flags, true) != OK) {
    return e_invarg;
  }

  return NULL;
}

#ifdef BACKSLASH_IN_FILENAME
/// The 'completeslash' option is changed.
const char *did_set_completeslash(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  if (opt_strings_flags(p_csl, opt_csl_values, NULL, false) != OK
      || opt_strings_flags(buf->b_p_csl, opt_csl_values, NULL, false) != OK) {
    return e_invarg;
  }
  return NULL;
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

/// The 'diffopt' option is changed.
const char *did_set_diffopt(optset_T *args FUNC_ATTR_UNUSED)
{
  return diffopt_changed() == FAIL ? e_invarg : NULL;
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
                                   opt_dip_algorithm_values,
                                   ARRAY_SIZE(opt_dip_algorithm_values) - 1,
                                   numMatches,
                                   matches);
    }
    // Within "inline:", we have a subgroup of possible options.
    const size_t inline_len = strlen("inline:");
    if (xp->xp_pattern - args->oe_set_arg >= (int)inline_len
        && strncmp(xp->xp_pattern - inline_len, "inline:", inline_len) == 0) {
      return expand_set_opt_string(args,
                                   opt_dip_inline_values,
                                   ARRAY_SIZE(opt_dip_inline_values) - 1,
                                   numMatches,
                                   matches);
    }
    return FAIL;
  }

  return expand_set_str_generic(args, numMatches, matches);
}

/// The 'display' option is changed.
const char *did_set_display(optset_T *args)
{
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  init_chartab();
  msg_grid_validate();
  return NULL;
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

/// The 'eventignore(win)' option is changed.
const char *did_set_eventignore(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (check_ei(*varp) == FAIL) {
    return e_invarg;
  }
  return NULL;
}

static bool expand_eiw = false;

static char *get_eventignore_name(expand_T *xp, int idx)
{
  bool subtract = *xp->xp_pattern == '-';
  // 'eventignore(win)' allows special keyword "all" in addition to
  // all event names.
  if (!subtract && idx == 0) {
    return "all";
  }

  char *name = get_event_name_no_group(xp, idx - 1 + subtract, expand_eiw);
  if (name == NULL) {
    return NULL;
  }

  snprintf(IObuff, IOSIZE, "%s%s", subtract ? "-" : "", name);
  return IObuff;
}

int expand_set_eventignore(optexpand_T *args, int *numMatches, char ***matches)
{
  expand_eiw = args->oe_varp != (char *)&p_ei;
  return expand_set_opt_generic(args, get_eventignore_name, numMatches, matches);
}

/// The 'fileformat' option is changed.
const char *did_set_fileformat(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  const char *oldval = args->os_oldval.string.data;
  int opt_flags = args->os_flags;
  if (!MODIFIABLE(buf) && !(opt_flags & OPT_GLOBAL)) {
    return e_modifiable;
  }

  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
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

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// fileformat options.
char *get_fileformat_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= (int)ARRAY_SIZE(opt_ff_values)) {
    return NULL;
  }

  return (char *)opt_ff_values[idx];
}

/// The 'filetype' or the 'syntax' option is changed.
const char *did_set_filetype_or_syntax(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (!valid_filetype(*varp)) {
    return e_invarg;
  }

  args->os_value_changed = strcmp(args->os_oldval.string.data, *varp) != 0;

  // Since we check the value, there is no need to set kOptFlagInsecure,
  // even when the value comes from a modeline.
  args->os_value_checked = true;

  return NULL;
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
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  win_T *win = (win_T *)args->os_win;
  foldUpdateAll(win);
  if (foldmethodIsDiff(win)) {
    newFoldLevel();
  }
  return NULL;
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
  return did_set_str_generic(args);
}

/// The 'isexpand' option is changed.
const char *did_set_isexpand(optset_T *args)
{
  char *ise = p_ise;
  char *p;
  bool last_was_comma = false;

  if (args->os_flags & OPT_LOCAL) {
    ise = curbuf->b_p_ise;
  }

  for (p = ise; *p != NUL;) {
    if (*p == '\\' && p[1] == ',') {
      p += 2;
      last_was_comma = false;
      continue;
    }

    if (*p == ',') {
      if (last_was_comma) {
        return e_invarg;
      }
      last_was_comma = true;
      p++;
      continue;
    }

    last_was_comma = false;
    MB_PTR_ADV(p);
  }

  if (last_was_comma) {
    return e_invarg;
  }

  return NULL;
}

/// The 'iskeyword' option is changed.
const char *did_set_iskeyword(optset_T *args)
{
  char **varp = (char **)args->os_varp;

  if (varp == &p_isk) {       // only check for global-value
    if (check_isopt(*varp) == FAIL) {
      return e_invarg;
    }
  } else {                    // fallthrough for local-value
    return did_set_isopt(args);
  }

  return NULL;
}

/// The 'isident' or the 'iskeyword' or the 'isprint' or the 'isfname' option is
/// changed.
const char *did_set_isopt(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // 'isident', 'iskeyword', 'isprint' or 'isfname' option: refill g_chartab[]
  // If the new option is invalid, use old value.
  // 'lisp' option: refill g_chartab[] for '-' char
  if (buf_init_chartab(buf, true) == FAIL) {
    args->os_restore_chartab = true;  // need to restore it below
    return e_invarg;                  // error in value
  }
  return NULL;
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

  // Since we check the value, there is no need to set kOptFlagInsecure,
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
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  km_stopsel = (vim_strchr(p_km, 'o') != NULL);
  km_startsel = (vim_strchr(p_km, 'a') != NULL);
  return NULL;
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

/// Process the updated 'messagesopt' option value.
const char *did_set_messagesopt(optset_T *args FUNC_ATTR_UNUSED)
{
  if (messagesopt_changed() == FAIL) {
    return e_invarg;
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

/// The 'rulerformat' option is changed.
const char *did_set_rulerformat(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, true, false);
}

/// The 'selection' option is changed.
const char *did_set_selection(optset_T *args FUNC_ATTR_UNUSED)
{
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  if (VIsual_active) {
    // Visual selection may be drawn differently.
    redraw_curbuf_later(UPD_INVERTED);
  }
  return NULL;
}

/// The 'sessionoptions' option is changed.
const char *did_set_sessionoptions(optset_T *args)
{
  const char *errmsg = did_set_str_generic(args);
  if (errmsg != NULL) {
    return errmsg;
  }
  if ((ssop_flags & kOptSsopFlagCurdir) && (ssop_flags & kOptSsopFlagSesdir)) {
    // Don't allow both "sesdir" and "curdir".
    const char *oldval = args->os_oldval.string.data;
    opt_strings_flags(oldval, opt_ssop_values, &ssop_flags, true);
    return e_invarg;
  }
  return NULL;
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
  const char *errmsg = did_set_str_generic(args);

  if (errmsg == NULL) {
    comp_col();
  }

  return errmsg;
}

/// The 'signcolumn' option is changed.
const char *did_set_signcolumn(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  const char *oldval = args->os_oldval.string.data;
  if (check_signcolumn(*varp, varp == &win->w_p_scl ? win : NULL) != OK) {
    return e_invarg;
  }
  // When changing the 'signcolumn' to or from 'number', recompute the
  // width of the number column if 'number' or 'relativenumber' is set.
  if ((*oldval == 'n' && *(oldval + 1) == 'u') || win->w_minscwidth == SCL_NUM) {
    win->w_nrwidth_line_count = 0;
  }
  return NULL;
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
  if (!valid_spellfile(*varp)) {
    return e_invarg;
  }
  return did_set_spell_option();
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
  return did_set_spell_option();
}

/// The 'spelloptions' option is changed.
const char *did_set_spelloptions(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  int opt_flags = args->os_flags;
  const char *val = args->os_newval.string.data;

  if (!(opt_flags & OPT_LOCAL)
      && opt_strings_flags(val, opt_spo_values, &spo_flags, true) != OK) {
    return e_invarg;
  }
  if (!(opt_flags & OPT_GLOBAL)
      && opt_strings_flags(val, opt_spo_values, &win->w_s->b_p_spo_flags, true) != OK) {
    return e_invarg;
  }
  return NULL;
}

/// The 'spellsuggest' option is changed.
const char *did_set_spellsuggest(optset_T *args FUNC_ATTR_UNUSED)
{
  if (spell_check_sps() != OK) {
    return e_invarg;
  }
  return NULL;
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

  // reset statusline to default when setting global option and empty string is being set
  if (args->os_idx == kOptStatusline
      && ((args->os_flags & OPT_GLOBAL) || !(args->os_flags & OPT_LOCAL))
      && s[0] == NUL) {
    xfree(*varp);
    *varp = xstrdup(get_option_default(args->os_idx, args->os_flags).data.string.data);
    s = *varp;
  }

  if (rulerformat && *s == '%') {
    // set ru_wid if 'ruf' starts with "%99("
    if (*++s == '-') {        // ignore a '-'
      s++;
    }
    int wid = getdigits_int(&s, true, 0);
    if (wid && *s == '(' && (errmsg = check_stl_option(p_ruf)) == NULL) {
      ru_wid = wid;
    } else {
      // Validate the flags in 'rulerformat' only if it doesn't point to
      // a custom function ("%!" flag).
      if ((*varp)[1] != '!') {
        errmsg = check_stl_option(p_ruf);
      }
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
  } else if (opt_strings_flags(p, opt_tc_values, flags, false) != OK) {
    return e_invarg;
  }
  return NULL;
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
    if (opt_strings_flags(ve, opt_ve_values, flags, true) != OK) {
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

/// The 'winbar' option is changed.
const char *did_set_winbar(optset_T *args)
{
  return did_set_statustabline_rulerformat(args, false, false);
}

/// The 'winhighlight' option is changed.
const char *did_set_winhighlight(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  char **varp = (char **)args->os_varp;
  if (!parse_winhl_opt(*varp, varp == &win->w_p_winhl ? win : NULL)) {
    return e_invarg;
  }
  return NULL;
}

int expand_set_winhighlight(optexpand_T *args, int *numMatches, char ***matches)
{
  return expand_set_opt_generic(args, get_highlight_name, numMatches, matches);
}

/// Handle an option that can be a range of string values.
/// Set a flag in "*flagp" for each string present.
///
/// @param val  new value
/// @param values  array of valid string values
/// @param list  when true: accept a list of values
///
/// @return  OK for correct value, FAIL otherwise. Empty is always OK.
static int opt_strings_flags(const char *val, const char **values, unsigned *flagp, bool list)
{
  unsigned new_flags = 0;

  // If not list and val is empty, then force one iteration of the while loop
  bool iter_one = (*val == NUL) && !list;

  while (*val || iter_one) {
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
    if (iter_one) {
      break;
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
  return opt_strings_flags(p, opt_ff_values, NULL, false);
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
  schar_T *cp;           ///< char value
  String name;           ///< char id
  const char *def;       ///< default value
  const char *fallback;  ///< default value when "def" isn't single-width
};

#define CHARSTAB_ENTRY(cp, name, def, fallback) \
  { (cp), { name, STRLEN_LITERAL(name) }, def, fallback }

static fcs_chars_T fcs_chars;
static const struct chars_tab fcs_tab[] = {
  CHARSTAB_ENTRY(&fcs_chars.stl,        "stl",       " ", NULL),
  CHARSTAB_ENTRY(&fcs_chars.stlnc,      "stlnc",     " ", NULL),
  CHARSTAB_ENTRY(&fcs_chars.wbr,        "wbr",       " ", NULL),
  CHARSTAB_ENTRY(&fcs_chars.horiz,      "horiz",     "─", "-"),
  CHARSTAB_ENTRY(&fcs_chars.horizup,    "horizup",   "┴", "-"),
  CHARSTAB_ENTRY(&fcs_chars.horizdown,  "horizdown", "┬", "-"),
  CHARSTAB_ENTRY(&fcs_chars.vert,       "vert",      "│", "|"),
  CHARSTAB_ENTRY(&fcs_chars.vertleft,   "vertleft",  "┤", "|"),
  CHARSTAB_ENTRY(&fcs_chars.vertright,  "vertright", "├", "|"),
  CHARSTAB_ENTRY(&fcs_chars.verthoriz,  "verthoriz", "┼", "+"),
  CHARSTAB_ENTRY(&fcs_chars.fold,       "fold",      "·", "-"),
  CHARSTAB_ENTRY(&fcs_chars.foldopen,   "foldopen",  "-", NULL),
  CHARSTAB_ENTRY(&fcs_chars.foldclosed, "foldclose", "+", NULL),
  CHARSTAB_ENTRY(&fcs_chars.foldsep,    "foldsep",   "│", "|"),
  CHARSTAB_ENTRY(&fcs_chars.diff,       "diff",      "-", NULL),
  CHARSTAB_ENTRY(&fcs_chars.msgsep,     "msgsep",    " ", NULL),
  CHARSTAB_ENTRY(&fcs_chars.eob,        "eob",       "~", NULL),
  CHARSTAB_ENTRY(&fcs_chars.lastline,   "lastline",  "@", NULL),
  CHARSTAB_ENTRY(&fcs_chars.trunc,      "trunc",     ">", NULL),
  CHARSTAB_ENTRY(&fcs_chars.truncrl,    "truncrl",   "<", NULL),
};

static lcs_chars_T lcs_chars;
static const struct chars_tab lcs_tab[] = {
  CHARSTAB_ENTRY(&lcs_chars.eol,     "eol",            NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.ext,     "extends",        NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.nbsp,    "nbsp",           NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.prec,    "precedes",       NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.space,   "space",          NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.tab2,    "tab",            NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.lead,    "lead",           NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.trail,   "trail",          NULL, NULL),
  CHARSTAB_ENTRY(&lcs_chars.conceal, "conceal",        NULL, NULL),
  CHARSTAB_ENTRY(NULL,               "multispace",     NULL, NULL),
  CHARSTAB_ENTRY(NULL,               "leadmultispace", NULL, NULL),
};

#undef CHARSTAB_ENTRY

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
        if (!(strncmp(p, tab[i].name.data,
                      tab[i].name.size) == 0 && p[tab[i].name.size] == ':')) {
          continue;
        }

        const char *s = p + tab[i].name.size + 1;

        if (what == kListchars && strcmp(tab[i].name.data, "multispace") == 0) {
          if (round == 0) {
            // Get length of lcs-multispace string in the first round
            last_multispace = p;
            multispace_len = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (c1 == 0) {
                return field_value_err(errbuf, errbuflen,
                                       e_wrong_character_width_for_field_str,
                                       tab[i].name.data);
              }
              multispace_len++;
            }
            if (multispace_len == 0) {
              // lcs-multispace cannot be an empty string
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_number_of_characters_for_field_str,
                                     tab[i].name.data);
            }
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (p == last_multispace) {
                lcs_chars.multispace[multispace_pos++] = c1;
              }
            }
          }
          p = s;
          break;
        }

        if (what == kListchars && strcmp(tab[i].name.data, "leadmultispace") == 0) {
          if (round == 0) {
            // Get length of lcs-leadmultispace string in first round
            last_lmultispace = p;
            lead_multispace_len = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (c1 == 0) {
                return field_value_err(errbuf, errbuflen,
                                       e_wrong_character_width_for_field_str,
                                       tab[i].name.data);
              }
              lead_multispace_len++;
            }
            if (lead_multispace_len == 0) {
              // lcs-leadmultispace cannot be an empty string
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_number_of_characters_for_field_str,
                                     tab[i].name.data);
            }
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              schar_T c1 = get_encoded_char_adv(&s);
              if (p == last_lmultispace) {
                lcs_chars.leadmultispace[multispace_pos++] = c1;
              }
            }
          }
          p = s;
          break;
        }

        if (*s == NUL) {
          return field_value_err(errbuf, errbuflen,
                                 e_wrong_number_of_characters_for_field_str,
                                 tab[i].name.data);
        }
        schar_T c1 = get_encoded_char_adv(&s);
        if (c1 == 0) {
          return field_value_err(errbuf, errbuflen,
                                 e_wrong_character_width_for_field_str,
                                 tab[i].name.data);
        }
        schar_T c2 = 0;
        schar_T c3 = 0;
        if (tab[i].cp == &lcs_chars.tab2) {
          if (*s == NUL) {
            return field_value_err(errbuf, errbuflen,
                                   e_wrong_number_of_characters_for_field_str,
                                   tab[i].name.data);
          }
          c2 = get_encoded_char_adv(&s);
          if (c2 == 0) {
            return field_value_err(errbuf, errbuflen,
                                   e_wrong_character_width_for_field_str,
                                   tab[i].name.data);
          }
          if (!(*s == ',' || *s == NUL)) {
            c3 = get_encoded_char_adv(&s);
            if (c3 == 0) {
              return field_value_err(errbuf, errbuflen,
                                     e_wrong_character_width_for_field_str,
                                     tab[i].name.data);
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
                                 tab[i].name.data);
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
  if (idx < 0 || idx >= (int)ARRAY_SIZE(fcs_tab)) {
    return NULL;
  }

  return fcs_tab[idx].name.data;
}

/// Function given to ExpandGeneric() to obtain possible arguments of the
/// 'listchars' option.
char *get_listchars_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx < 0 || idx >= (int)ARRAY_SIZE(lcs_tab)) {
    return NULL;
  }

  return lcs_tab[idx].name.data;
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
