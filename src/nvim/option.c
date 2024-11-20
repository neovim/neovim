// User-settable options. Checklist for adding a new option:
// - Put it in options.lua
// - For a global option: Add a variable for it in option_vars.h.
// - For a buffer or window local option:
//   - Add a variable to the window or buffer struct in buffer_defs.h.
//   - For a window option, add some code to copy_winopt().
//   - For a window string option, add code to check_winopt()
//     and clear_winopt(). If setting the option needs parsing,
//     add some code to didset_window_options().
//   - For a buffer option, add some code to buf_copy_options().
//   - For a buffer string option, add code to check_buf_options().
// - If it's a numeric option, add any necessary bounds checks to check_num_option_bounds().
// - If it's a list of flags, add some code in do_set(), search for WW_ALL.
// - Add documentation! "desc" in options.lua, and any other related places.
// - Add an entry in runtime/optwin.vim.

#define IN_OPTION_C
#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/eval/window.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/math.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/input.h"
#include "nvim/os/lang.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef BACKSLASH_IN_FILENAME
# include "nvim/arglist.h"
#endif

static const char e_unknown_option[]
  = N_("E518: Unknown option");
static const char e_not_allowed_in_modeline[]
  = N_("E520: Not allowed in a modeline");
static const char e_not_allowed_in_modeline_when_modelineexpr_is_off[]
  = N_("E992: Not allowed in a modeline when 'modelineexpr' is off");
static const char e_number_required_after_equal[]
  = N_("E521: Number required after =");
static const char e_preview_window_already_exists[]
  = N_("E590: A preview window already exists");

static char *p_term = NULL;
static char *p_ttytype = NULL;

// Saved values for when 'bin' is set.
static int p_et_nobin;
static int p_ml_nobin;
static OptInt p_tw_nobin;
static OptInt p_wm_nobin;

// Saved values for when 'paste' is set.
static int p_ai_nopaste;
static int p_et_nopaste;
static OptInt p_sts_nopaste;
static OptInt p_tw_nopaste;
static OptInt p_wm_nopaste;
static char *p_vsts_nopaste;

#define OPTION_COUNT ARRAY_SIZE(options)

/// :set boolean option prefix
typedef enum {
  PREFIX_NO = 0,  ///< "no" prefix
  PREFIX_NONE,    ///< no prefix
  PREFIX_INV,     ///< "inv" prefix
} set_prefix_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.c.generated.h"
#endif

// options[] is initialized in options.generated.h.
// The options with a NULL variable are 'hidden': a set command for them is
// ignored and they are not printed.

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "options.generated.h"
# include "options_map.generated.h"
#endif

static int p_bin_dep_opts[] = {
  kOptTextwidth, kOptWrapmargin, kOptModeline, kOptExpandtab, kOptInvalid
};

static int p_paste_dep_opts[] = {
  kOptAutoindent, kOptExpandtab, kOptRuler, kOptShowmatch, kOptSmarttab, kOptSofttabstop,
  kOptTextwidth, kOptWrapmargin, kOptRevins, kOptVarsofttabstop, kOptInvalid
};

void set_init_tablocal(void)
{
  // susy baka: cmdheight calls itself OPT_GLOBAL but is really tablocal!
  p_ch = options[kOptCmdheight].def_val.data.number;
}

/// Initialize the 'shell' option to a default value.
static void set_init_default_shell(void)
{
  // Find default value for 'shell' option.
  // Don't use it if it is empty.
  const char *shell = os_getenv("SHELL");
  if (shell != NULL) {
    if (vim_strchr(shell, ' ') != NULL) {
      const size_t len = strlen(shell) + 3;  // two quotes and a trailing NUL
      char *const cmd = xmalloc(len);
      snprintf(cmd, len, "\"%s\"", shell);
      set_string_default(kOptShell, cmd, true);
    } else {
      set_string_default(kOptShell, (char *)shell, false);
    }
  }
}

/// Set the default for 'backupskip' to include environment variables for
/// temp files.
static void set_init_default_backupskip(void)
{
#ifdef UNIX
  static char *(names[4]) = { "", "TMPDIR", "TEMP", "TMP" };
#else
  static char *(names[3]) = { "TMPDIR", "TEMP", "TMP" };
#endif
  garray_T ga;
  OptIndex opt_idx = kOptBackupskip;

  ga_init(&ga, 1, 100);
  for (size_t i = 0; i < ARRAY_SIZE(names); i++) {
    bool mustfree = true;
    char *p;
    size_t plen;
#ifdef UNIX
    if (*names[i] == NUL) {
# ifdef __APPLE__
      p = "/private/tmp";
      plen = STRLEN_LITERAL("/private/tmp");
# else
      p = "/tmp";
      plen = STRLEN_LITERAL("/tmp");
# endif
      mustfree = false;
    } else
#endif
    {
      p = vim_getenv(names[i]);
      plen = 0;  // will be calculated below
    }
    if (p != NULL && *p != NUL) {
      bool has_trailing_path_sep = false;

      if (plen == 0) {
        // the value was retrieved from the environment
        plen = strlen(p);
        // does the value include a trailing path separator?
        if (after_pathsep(p, p + plen)) {
          has_trailing_path_sep = true;
        }
      }

      // item size needs to be large enough to include "/*" and a trailing NUL
      // note: the value (and therefore plen) may already include a path separator
      size_t itemsize = plen + (has_trailing_path_sep ? 0 : 1) + 2;
      char *item = xmalloc(itemsize);
      // add a preceding comma as a separator after the first item
      size_t itemseplen = (ga.ga_len == 0) ? 0 : 1;

      size_t itemlen = (size_t)vim_snprintf(item, itemsize, "%s%s*", p,
                                            has_trailing_path_sep ? "" : PATHSEPSTR);

      if (find_dup_item(ga.ga_data, item, itemlen, options[opt_idx].flags) == NULL) {
        ga_grow(&ga, (int)(itemseplen + itemlen + 1));
        ga.ga_len += vim_snprintf((char *)ga.ga_data + ga.ga_len,
                                  itemseplen + itemlen + 1,
                                  "%s%s", (itemseplen > 0) ? "," : "", item);
      }
      xfree(item);
    }
    if (mustfree) {
      xfree(p);
    }
  }
  if (ga.ga_data != NULL) {
    set_string_default(kOptBackupskip, ga.ga_data, true);
  }
}

/// Initialize the 'cdpath' option to a default value.
static void set_init_default_cdpath(void)
{
  char *cdpath = vim_getenv("CDPATH");
  if (cdpath == NULL) {
    return;
  }

  char *buf = xmalloc(2 * strlen(cdpath) + 2);
  buf[0] = ',';               // start with ",", current dir first
  int j = 1;
  for (int i = 0; cdpath[i] != NUL; i++) {
    if (vim_ispathlistsep(cdpath[i])) {
      buf[j++] = ',';
    } else {
      if (cdpath[i] == ' ' || cdpath[i] == ',') {
        buf[j++] = '\\';
      }
      buf[j++] = cdpath[i];
    }
  }
  buf[j] = NUL;
  change_option_default(kOptCdpath, CSTR_AS_OPTVAL(buf));

  xfree(cdpath);
}

/// Expand environment variables and things like "~" for the defaults.
/// If option_expand() returns non-NULL the variable is expanded.  This can
/// only happen for non-indirect options.
/// Also set the default to the expanded value, so ":set" does not list
/// them.
static void set_init_expand_env(void)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    vimoption_T *opt = &options[opt_idx];
    if (opt->flags & kOptFlagNoDefExp) {
      continue;
    }
    char *p;
    if ((opt->flags & kOptFlagGettext) && opt->var != NULL) {
      p = _(*(char **)opt->var);
    } else {
      p = option_expand(opt_idx, NULL);
    }
    if (p != NULL) {
      set_option_varp(opt_idx, opt->var, CSTR_TO_OPTVAL(p), true);
      change_option_default(opt_idx, CSTR_TO_OPTVAL(p));
    }
  }
}

/// Initialize the encoding used for "default" in 'fileencodings'.
static void set_init_fenc_default(void)
{
  // enc_locale() will try to find the encoding of the current locale.
  // This will be used when "default" is used as encoding specifier
  // in 'fileencodings'.
  char *p = enc_locale();
  if (p == NULL) {
    // Use utf-8 as "default" if locale encoding can't be detected.
    p = xmemdupz(S_LEN("utf-8"));
  }
  fenc_default = p;
}

/// Initialize the options, first part.
///
/// Called only once from main(), just after creating the first buffer.
/// If "clean_arg" is true, Nvim was started with --clean.
///
/// NOTE: ELOG() etc calls are not allowed here, as log location depends on
/// env var expansion which depends on expression evaluation and other
/// editor state initialized here. Do logging in set_init_2 or later.
void set_init_1(bool clean_arg)
{
  langmap_init();

  // Allocate the default option values.
  alloc_options_default();

  set_init_default_shell();
  set_init_default_backupskip();
  set_init_default_cdpath();

  char *backupdir = stdpaths_user_state_subpath("backup", 2, true);
  const size_t backupdir_len = strlen(backupdir);
  backupdir = xrealloc(backupdir, backupdir_len + 3);
  memmove(backupdir + 2, backupdir, backupdir_len + 1);
  memmove(backupdir, ".,", 2);
  set_string_default(kOptBackupdir, backupdir, true);
  set_string_default(kOptViewdir, stdpaths_user_state_subpath("view", 2, true),
                     true);
  set_string_default(kOptDirectory, stdpaths_user_state_subpath("swap", 2, true),
                     true);
  set_string_default(kOptUndodir, stdpaths_user_state_subpath("undo", 2, true),
                     true);
  // Set default for &runtimepath. All necessary expansions are performed in
  // this function.
  char *rtp = runtimepath_default(clean_arg);
  if (rtp) {
    set_string_default(kOptRuntimepath, rtp, true);
    // Make a copy of 'rtp' for 'packpath'
    set_string_default(kOptPackpath, rtp, false);
    rtp = NULL;  // ownership taken
  }

  // Set all the options (except the terminal options) to their default
  // value.  Also set the global value for local options.
  set_options_default(0);

  curbuf->b_p_initialized = true;
  curbuf->b_p_ar = -1;          // no local 'autoread' value
  curbuf->b_p_ul = NO_LOCAL_UNDOLEVEL;
  check_buf_options(curbuf);
  check_win_options(curwin);
  check_options();

  // set 'laststatus'
  last_status(false);

  // Must be before option_expand(), because that one needs vim_isIDc()
  didset_options();

  // Use the current chartab for the generic chartab. This is not in
  // didset_options() because it only depends on 'encoding'.
  init_spell_chartab();

  // Expand environment variables and things like "~" for the defaults.
  set_init_expand_env();

  save_file_ff(curbuf);         // Buffer is unchanged

  // Detect use of mlterm.
  // Mlterm is a terminal emulator akin to xterm that has some special
  // abilities (bidi namely).
  // NOTE: mlterm's author is being asked to 'set' a variable
  //       instead of an environment variable due to inheritance.
  if (os_env_exists("MLTERM")) {
    set_option_value_give_err(kOptTermbidi, BOOLEAN_OPTVAL(true), 0);
  }

  didset_options2();

  lang_init();
  set_init_fenc_default();

#ifdef HAVE_WORKING_LIBINTL
  // GNU gettext 0.10.37 supports this feature: set the codeset used for
  // translated messages independently from the current locale.
  (void)bind_textdomain_codeset(PROJECT_NAME, p_enc);
#endif

  // Set the default for 'helplang'.
  set_helplang_default(get_mess_lang());
}

/// Get default value for option, based on the option's type and scope.
///
/// @param  opt_idx    Option index in options[] table.
/// @param  opt_flags  Option flags.
///
/// @return Default value of option for the scope specified in opt_flags.
static OptVal get_option_default(const OptIndex opt_idx, int opt_flags)
{
  vimoption_T *opt = &options[opt_idx];
  bool is_global_local_option = option_is_global_local(opt_idx);

#ifdef UNIX
  if (opt_idx == kOptModeline && getuid() == ROOT_UID) {
    // 'modeline' defaults to off for root.
    return BOOLEAN_OPTVAL(false);
  }
#endif

  if ((opt_flags & OPT_LOCAL) && is_global_local_option) {
    // Use unset local value instead of default value for local scope of global-local options.
    return get_option_unset_value(opt_idx);
  } else if (option_has_type(opt_idx, kOptValTypeString) && !(opt->flags & kOptFlagNoDefExp)) {
    // For string options, expand environment variables and ~ since the default value was already
    // expanded, only required when an environment variable was set later.
    char *s = option_expand(opt_idx, opt->def_val.data.string.data);
    return s == NULL ? opt->def_val : CSTR_AS_OPTVAL(s);
  } else {
    return opt->def_val;
  }
}

/// Allocate the default values for all options by copying them from the stack.
/// This ensures that we don't need to always check if the option default is allocated or not.
static void alloc_options_default(void)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    options[opt_idx].def_val = optval_copy(options[opt_idx].def_val);
  }
}

/// Change the default value for an option.
///
/// @param  opt_idx  Option index in options[] table.
/// @param  value    New default value. Must be allocated.
static void change_option_default(const OptIndex opt_idx, OptVal value)
{
  optval_free(options[opt_idx].def_val);
  options[opt_idx].def_val = value;
}

/// Set an option to its default value.
/// This does not take care of side effects!
///
/// @param  opt_idx    Option index in options[] table.
/// @param  opt_flags  Option flags.
static void set_option_default(const OptIndex opt_idx, int opt_flags)
{
  OptVal def_val = get_option_default(opt_idx, opt_flags);
  set_option_direct(opt_idx, def_val, opt_flags, current_sctx.sc_sid);

  if (opt_idx == kOptScroll) {
    win_comp_scroll(curwin);
  }

  // The default value is not insecure.
  uint32_t *flagsp = insecure_flag(curwin, opt_idx, opt_flags);
  *flagsp = *flagsp & ~(unsigned)kOptFlagInsecure;
}

/// Set all options (except terminal options) to their default value.
///
/// @param  opt_flags  Option flags.
static void set_options_default(int opt_flags)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    if (!(options[opt_idx].flags & kOptFlagNoDefault)) {
      set_option_default(opt_idx, opt_flags);
    }
  }

  // The 'scroll' option must be computed for all windows.
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    win_comp_scroll(wp);
  }

  parse_cino(curbuf);
}

/// Set the Vi-default value of a string option.
/// Used for 'sh', 'backupskip' and 'term'.
///
/// @param  opt_idx    Option index in options[] table.
/// @param  val        The value of the option.
/// @param  allocated  If true, do not copy default as it was already allocated.
///
/// TODO(famiu): Remove this.
static void set_string_default(OptIndex opt_idx, char *val, bool allocated)
  FUNC_ATTR_NONNULL_ALL
{
  assert(opt_idx != kOptInvalid);
  change_option_default(opt_idx, CSTR_AS_OPTVAL(allocated ? val : xstrdup(val)));
}

/// For an option value that contains comma separated items, find "newval" in
/// "origval".  Return NULL if not found.
static char *find_dup_item(char *origval, const char *newval, const size_t newvallen,
                           uint32_t flags)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (origval == NULL) {
    return NULL;
  }

  int bs = 0;

  for (char *s = origval; *s != NUL; s++) {
    if ((!(flags & kOptFlagComma) || s == origval || (s[-1] == ',' && !(bs & 1)))
        && strncmp(s, newval, newvallen) == 0
        && (!(flags & kOptFlagComma) || s[newvallen] == ',' || s[newvallen] == NUL)) {
      return s;
    }
    // Count backslashes.  Only a comma with an even number of backslashes
    // or a single backslash preceded by a comma before it is recognized as
    // a separator.
    if ((s > origval + 1 && s[-1] == '\\' && s[-2] != ',')
        || (s == origval + 1 && s[-1] == '\\')) {
      bs++;
    } else {
      bs = 0;
    }
  }
  return NULL;
}

#if defined(EXITFREE)
/// Free all options.
void free_all_options(void)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    bool hidden = is_option_hidden(opt_idx);

    if (option_is_global_only(opt_idx) || hidden) {
      // global option: free value and default value.
      // hidden option: free default value only.
      if (!hidden) {
        optval_free(optval_from_varp(opt_idx, options[opt_idx].var));
      }
    } else if (!option_is_window_local(opt_idx)) {
      // buffer-local option: free global value.
      optval_free(optval_from_varp(opt_idx, options[opt_idx].var));
    }
    optval_free(options[opt_idx].def_val);
  }
  free_operatorfunc_option();
  free_tagfunc_option();
  free_findfunc_option();
  XFREE_CLEAR(fenc_default);
  XFREE_CLEAR(p_term);
  XFREE_CLEAR(p_ttytype);
}
#endif

/// Initialize the options, part two: After getting Rows and Columns.
void set_init_2(bool headless)
{
  // set in set_init_1 but logging is not allowed there
  ILOG("startup runtimepath/packpath value: %s", p_rtp);

  // 'scroll' defaults to half the window height. The stored default is zero,
  // which results in the actual value computed from the window height.
  if (!(options[kOptScroll].flags & kOptFlagWasSet)) {
    set_option_default(kOptScroll, OPT_LOCAL);
  }
  comp_col();

  // 'window' is only for backwards compatibility with Vi.
  // Default is Rows - 1.
  if (!option_was_set(kOptWindow)) {
    p_window = Rows - 1;
  }
  change_option_default(kOptWindow, NUMBER_OPTVAL(Rows - 1));
}

/// Initialize the options, part three: After reading the .vimrc
void set_init_3(void)
{
  parse_shape_opt(SHAPE_CURSOR);   // set cursor shapes from 'guicursor'

  // Set 'shellpipe' and 'shellredir', depending on the 'shell' option.
  // This is done after other initializations, where 'shell' might have been
  // set, but only if they have not been set before.
  bool do_srr = !(options[kOptShellredir].flags & kOptFlagWasSet);
  bool do_sp = !(options[kOptShellpipe].flags & kOptFlagWasSet);

  size_t len = 0;
  char *p = (char *)invocation_path_tail(p_sh, &len);
  p = xmemdupz(p, len);

  bool is_csh = path_fnamecmp(p, "csh") == 0 || path_fnamecmp(p, "tcsh") == 0;
  bool is_known_shell = path_fnamecmp(p, "sh") == 0 || path_fnamecmp(p, "ksh") == 0
                        || path_fnamecmp(p, "mksh") == 0 || path_fnamecmp(p, "pdksh") == 0
                        || path_fnamecmp(p, "zsh") == 0 || path_fnamecmp(p, "zsh-beta") == 0
                        || path_fnamecmp(p, "bash") == 0 || path_fnamecmp(p, "fish") == 0
                        || path_fnamecmp(p, "ash") == 0 || path_fnamecmp(p, "dash") == 0;

  // Default for p_sp is "| tee", for p_srr is ">".
  // For known shells it is changed here to include stderr.
  if (is_csh || is_known_shell) {
    if (do_sp) {
      const OptVal sp =
        is_csh ? STATIC_CSTR_AS_OPTVAL("|& tee") : STATIC_CSTR_AS_OPTVAL("2>&1| tee");
      set_option_direct(kOptShellpipe, sp, 0, SID_NONE);
      change_option_default(kOptShellpipe, optval_copy(sp));
    }
    if (do_srr) {
      const OptVal srr = is_csh ? STATIC_CSTR_AS_OPTVAL(">&") : STATIC_CSTR_AS_OPTVAL(">%s 2>&1");
      set_option_direct(kOptShellredir, srr, 0, SID_NONE);
      change_option_default(kOptShellredir, optval_copy(srr));
    }
  }
  xfree(p);

  if (buf_is_empty(curbuf)) {
    // Apply the first entry of 'fileformats' to the initial buffer.
    if (options[kOptFileformats].flags & kOptFlagWasSet) {
      set_fileformat(default_fileformat(), OPT_LOCAL);
    }
  }

  set_title_defaults();  // 'title', 'icon'
}

/// When 'helplang' is still at its default value, set it to "lang".
/// Only the first two characters of "lang" are used.
void set_helplang_default(const char *lang)
{
  if (lang == NULL) {
    return;
  }

  const size_t lang_len = strlen(lang);
  if (lang_len < 2) {  // safety check
    return;
  }
  if (options[kOptHelplang].flags & kOptFlagWasSet) {
    return;
  }

  free_string_option(p_hlg);
  p_hlg = xmemdupz(lang, lang_len);
  // zh_CN becomes "cn", zh_TW becomes "tw".
  if (STRNICMP(p_hlg, "zh_", 3) == 0 && lang_len >= 5) {
    p_hlg[0] = (char)TOLOWER_ASC(p_hlg[3]);
    p_hlg[1] = (char)TOLOWER_ASC(p_hlg[4]);
  } else if (lang_len && *p_hlg == 'C') {
    // any C like setting, such as C.UTF-8, becomes "en"
    p_hlg[0] = 'e';
    p_hlg[1] = 'n';
  }
  p_hlg[2] = NUL;
}

/// 'title' and 'icon' only default to true if they have not been set or reset
/// in .vimrc and we can read the old value.
/// When 'title' and 'icon' have been reset in .vimrc, we won't even check if
/// they can be reset.  This reduces startup time when using X on a remote
/// machine.
void set_title_defaults(void)
{
  // If GUI is (going to be) used, we can always set the window title and
  // icon name.  Saves a bit of time, because the X11 display server does
  // not need to be contacted.
  if (!(options[kOptTitle].flags & kOptFlagWasSet)) {
    change_option_default(kOptTitle, BOOLEAN_OPTVAL(false));
    p_title = 0;
  }
  if (!(options[kOptIcon].flags & kOptFlagWasSet)) {
    change_option_default(kOptIcon, BOOLEAN_OPTVAL(false));
    p_icon = 0;
  }
}

void ex_set(exarg_T *eap)
{
  int flags = 0;

  if (eap->cmdidx == CMD_setlocal) {
    flags = OPT_LOCAL;
  } else if (eap->cmdidx == CMD_setglobal) {
    flags = OPT_GLOBAL;
  }
  if (eap->forceit) {
    flags |= OPT_ONECOLUMN;
  }
  do_set(eap->arg, flags);
}

/// Copy the new string value into allocated memory for the option.
/// Can't use set_option_direct(), because we need to remove the backslashes.
static char *stropt_copy_value(char *origval, char **argp, set_op_T op,
                               uint32_t flags FUNC_ATTR_UNUSED)
{
  char *arg = *argp;

  // get a bit too much
  size_t newlen = strlen(arg) + 1;
  if (op != OP_NONE) {
    newlen += strlen(origval) + 1;
  }
  char *newval = xmalloc(newlen);
  char *s = newval;

  // Copy the string, skip over escaped chars.
  // For MS-Windows backslashes before normal file name characters
  // are not removed, and keep backslash at start, for "\\machine\path",
  // but do remove it for "\\\\machine\\path".
  // The reverse is found in escape_option_str_cmdline().
  while (*arg != NUL && !ascii_iswhite(*arg)) {
    if (*arg == '\\' && arg[1] != NUL
#ifdef BACKSLASH_IN_FILENAME
        && !((flags & kOptFlagExpand)
             && vim_isfilec((uint8_t)arg[1])
             && !ascii_iswhite(arg[1])
             && (arg[1] != '\\'
                 || (s == newval && arg[2] != '\\')))
#endif
        ) {
      arg++;  // remove backslash
    }
    int i = utfc_ptr2len(arg);
    if (i > 1) {
      // copy multibyte char
      memmove(s, arg, (size_t)i);
      arg += i;
      s += i;
    } else {
      *s++ = *arg++;
    }
  }
  *s = NUL;

  *argp = arg;
  return newval;
}

/// Expand environment variables and ~ in string option value 'newval'.
static char *stropt_expand_envvar(OptIndex opt_idx, char *origval, char *newval, set_op_T op)
{
  char *s = option_expand(opt_idx, newval);
  if (s == NULL) {
    return newval;
  }

  xfree(newval);
  uint32_t newlen = (unsigned)strlen(s) + 1;
  if (op != OP_NONE) {
    newlen += (unsigned)strlen(origval) + 1;
  }
  newval = xmalloc(newlen);
  STRCPY(newval, s);

  return newval;
}

/// Concatenate the original and new values of a string option, adding a "," if
/// needed.
static void stropt_concat_with_comma(char *origval, char *newval, set_op_T op, uint32_t flags)
{
  int len = 0;
  int comma = ((flags & kOptFlagComma) && *origval != NUL && *newval != NUL);
  if (op == OP_ADDING) {
    len = (int)strlen(origval);
    // Strip a trailing comma, would get 2.
    if (comma && len > 1
        && (flags & kOptFlagOneComma) == kOptFlagOneComma
        && origval[len - 1] == ','
        && origval[len - 2] != '\\') {
      len--;
    }
    memmove(newval + len + comma, newval, strlen(newval) + 1);
    memmove(newval, origval, (size_t)len);
  } else {
    len = (int)strlen(newval);
    STRMOVE(newval + len + comma, origval);
  }
  if (comma) {
    newval[len] = ',';
  }
}

/// Remove a value from a string option.  Copy string option value in "origval"
/// to "newval" and then remove the string "strval" of length "len".
static void stropt_remove_val(char *origval, char *newval, uint32_t flags, char *strval, int len)
{
  // Remove newval[] from origval[]. (Note: "len" has been set above
  // and is used here).
  STRCPY(newval, origval);
  if (*strval) {
    // may need to remove a comma
    if (flags & kOptFlagComma) {
      if (strval == origval) {
        // include comma after string
        if (strval[len] == ',') {
          len++;
        }
      } else {
        // include comma before string
        strval--;
        len++;
      }
    }
    STRMOVE(newval + (strval - origval), strval + len);
  }
}

/// Remove flags that appear twice in the string option value 'newval'.
static void stropt_remove_dupflags(char *newval, uint32_t flags)
{
  char *s = newval;
  // Remove flags that appear twice.
  for (s = newval; *s;) {
    // if options have kOptFlagFlagList and kOptFlagOneComma such as 'whichwrap'
    if (flags & kOptFlagOneComma) {
      if (*s != ',' && *(s + 1) == ','
          && vim_strchr(s + 2, (uint8_t)(*s)) != NULL) {
        // Remove the duplicated value and the next comma.
        STRMOVE(s, s + 2);
        continue;
      }
    } else {
      if ((!(flags & kOptFlagComma) || *s != ',')
          && vim_strchr(s + 1, (uint8_t)(*s)) != NULL) {
        STRMOVE(s, s + 1);
        continue;
      }
    }
    s++;
  }
}

/// Get the string value specified for a ":set" command.  The following set options are supported:
///     set {opt}={val}
///     set {opt}:{val}
static char *stropt_get_newval(int nextchar, OptIndex opt_idx, char **argp, void *varp,
                               char *origval, set_op_T *op_arg, uint32_t flags)
{
  char *arg = *argp;
  set_op_T op = *op_arg;
  char *save_arg = NULL;
  char *newval;
  char *s = NULL;

  arg++;  // jump to after the '=' or ':'

  // Set 'keywordprg' to ":help" if an empty
  // value was passed to :set by the user.
  if (varp == &p_kp && (*arg == NUL || *arg == ' ')) {
    save_arg = arg;
    arg = ":help";
  }

  // Copy the new string into allocated memory.
  newval = stropt_copy_value(origval, &arg, op, flags);

  // Expand environment variables and ~.
  // Don't do it when adding without inserting a comma.
  if (op == OP_NONE || (flags & kOptFlagComma)) {
    newval = stropt_expand_envvar(opt_idx, origval, newval, op);
  }

  // locate newval[] in origval[] when removing it
  // and when adding to avoid duplicates
  int len = 0;
  if (op == OP_REMOVING || (flags & kOptFlagNoDup)) {
    len = (int)strlen(newval);
    s = find_dup_item(origval, newval, (size_t)len, flags);

    // do not add if already there
    if ((op == OP_ADDING || op == OP_PREPENDING) && s != NULL) {
      op = OP_NONE;
      STRCPY(newval, origval);
    }

    // if no duplicate, move pointer to end of original value
    if (s == NULL) {
      s = origval + (int)strlen(origval);
    }
  }

  // concatenate the two strings; add a ',' if needed
  if (op == OP_ADDING || op == OP_PREPENDING) {
    stropt_concat_with_comma(origval, newval, op, flags);
  } else if (op == OP_REMOVING) {
    // Remove newval[] from origval[]. (Note: "len" has been set above
    // and is used here).
    stropt_remove_val(origval, newval, flags, s, len);
  }

  if (flags & kOptFlagFlagList) {
    // Remove flags that appear twice.
    stropt_remove_dupflags(newval, flags);
  }

  if (save_arg != NULL) {
    arg = save_arg;  // arg was temporarily changed, restore it
  }
  *argp = arg;
  *op_arg = op;

  return newval;
}

static set_op_T get_op(const char *arg)
{
  set_op_T op = OP_NONE;
  if (*arg != NUL && *(arg + 1) == '=') {
    if (*arg == '+') {
      op = OP_ADDING;          // "+="
    } else if (*arg == '^') {
      op = OP_PREPENDING;      // "^="
    } else if (*arg == '-') {
      op = OP_REMOVING;        // "-="
    }
  }
  return op;
}

static set_prefix_T get_option_prefix(char **argp)
{
  if (strncmp(*argp, "no", 2) == 0) {
    *argp += 2;
    return PREFIX_NO;
  } else if (strncmp(*argp, "inv", 3) == 0) {
    *argp += 3;
    return PREFIX_INV;
  }

  return PREFIX_NONE;
}

static int validate_opt_idx(win_T *win, OptIndex opt_idx, int opt_flags, uint32_t flags,
                            set_prefix_T prefix, const char **errmsg)
{
  // Only bools can have a prefix of 'inv' or 'no'
  if (!option_has_type(opt_idx, kOptValTypeBoolean) && prefix != PREFIX_NONE) {
    *errmsg = e_invarg;
    return FAIL;
  }

  // Skip all options that are not window-local (used when showing
  // an already loaded buffer in a window).
  if ((opt_flags & OPT_WINONLY) && (opt_idx == kOptInvalid || !option_is_window_local(opt_idx))) {
    return FAIL;
  }

  // Skip all options that are window-local (used for :vimgrep).
  if ((opt_flags & OPT_NOWIN) && opt_idx != kOptInvalid && option_is_window_local(opt_idx)) {
    return FAIL;
  }

  // Disallow changing some options from modelines.
  if (opt_flags & OPT_MODELINE) {
    if (flags & (kOptFlagSecure | kOptFlagNoML)) {
      *errmsg = e_not_allowed_in_modeline;
      return FAIL;
    }
    if ((flags & kOptFlagMLE) && !p_mle) {
      *errmsg = e_not_allowed_in_modeline_when_modelineexpr_is_off;
      return FAIL;
    }
    // In diff mode some options are overruled.  This avoids that
    // 'foldmethod' becomes "marker" instead of "diff" and that
    // "wrap" gets set.
    if (win->w_p_diff && (opt_idx == kOptFoldmethod || opt_idx == kOptWrap)) {
      return FAIL;
    }
  }

  // Disallow changing some options in the sandbox
  if (sandbox != 0 && (flags & kOptFlagSecure)) {
    *errmsg = e_sandbox;
    return FAIL;
  }

  return OK;
}

/// Skip over the name of a TTY option or keycode option.
///
/// @param[in]  arg  Start of TTY or keycode option name.
///
/// @return NULL when option isn't a TTY or keycode option. Otherwise pointer to the char after the
/// option name.
static const char *find_tty_option_end(const char *arg)
{
  if (strequal(arg, "term")) {
    return arg + sizeof("term") - 1;
  } else if (strequal(arg, "ttytype")) {
    return arg + sizeof("ttytype") - 1;
  }

  const char *p = arg;
  bool delimit = false;  // whether to delimit <

  if (arg[0] == '<') {
    // look out for <t_>;>
    delimit = true;
    p++;
  }
  if (p[0] == 't' && p[1] == '_' && p[2] && p[3]) {
    p += 4;
  } else if (delimit) {
    // Search for delimiting >.
    while (*p != NUL && *p != '>') {
      p++;
    }
  }
  // Return NULL when delimiting > is not found.
  if (delimit) {
    if (*p != '>') {
      return NULL;
    }
    p++;
  }

  return arg == p ? NULL : p;
}

/// Skip over the name of an option.
///
/// @param[in]   arg       Start of option name.
/// @param[out]  opt_idxp  Set to option index in options[] table.
///
/// @return NULL when no option name found. Otherwise pointer to the char after the option name.
const char *find_option_end(const char *arg, OptIndex *opt_idxp)
{
  const char *p;

  // Handle TTY and keycode options separately.
  if ((p = find_tty_option_end(arg)) != NULL) {
    *opt_idxp = kOptInvalid;
    return p;
  } else {
    p = arg;
  }

  if (!ASCII_ISALPHA(*p)) {
    *opt_idxp = kOptInvalid;
    return NULL;
  }
  while (ASCII_ISALPHA(*p)) {
    p++;
  }

  *opt_idxp = find_option_len(arg, (size_t)(p - arg));
  return p;
}

/// Get new option value from argp. Allocated OptVal must be freed by caller.
/// Can unset local value of an option when ":set {option}<" is used.
static OptVal get_option_newval(OptIndex opt_idx, int opt_flags, set_prefix_T prefix, char **argp,
                                int nextchar, set_op_T op, uint32_t flags, void *varp, char *errbuf,
                                const size_t errbuflen, const char **errmsg)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(varp != NULL);

  vimoption_T *opt = &options[opt_idx];
  char *arg = *argp;
  // When setting the local value of a global option, the old value may be the global value.
  const bool oldval_is_global = option_is_global_local(opt_idx) && (opt_flags & OPT_LOCAL);
  OptVal oldval = optval_from_varp(opt_idx, oldval_is_global ? get_varp(opt) : varp);
  OptVal newval = NIL_OPTVAL;

  if (nextchar == '&') {
    // ":set opt&": Reset to default value.
    // NOTE: Use OPT_GLOBAL instead of opt_flags to ensure we don't use the unset local value for
    // global-local options when OPT_LOCAL is used.
    return optval_copy(get_option_default(opt_idx, OPT_GLOBAL));
  } else if (nextchar == '<') {
    // ":set opt<": Reset to global value.
    // ":setlocal opt<": Copy global value to local value.
    if (option_is_global_local(opt_idx) && !(opt_flags & OPT_LOCAL)) {
      unset_option_local_value(opt_idx);
    }
    return get_option_value(opt_idx, OPT_GLOBAL);
  }

  switch (oldval.type) {
  case kOptValTypeNil:
    abort();
  case kOptValTypeBoolean: {
    TriState newval_bool;

    // ":set opt!": invert
    if (nextchar == '!') {
      switch (oldval.data.boolean) {
      case kNone:
        newval_bool = kNone;
        break;
      case kTrue:
        newval_bool = kFalse;
        break;
      case kFalse:
        newval_bool = kTrue;
        break;
      }
    } else {
      // ":set invopt": invert
      // ":set opt" or ":set noopt": set or reset
      if (prefix == PREFIX_INV) {
        newval_bool = *(int *)varp ^ 1;
      } else {
        newval_bool = prefix == PREFIX_NO ? 0 : 1;
      }
    }

    newval = BOOLEAN_OPTVAL(newval_bool);
    break;
  }
  case kOptValTypeNumber: {
    OptInt oldval_num = oldval.data.number;
    OptInt newval_num;

    // Different ways to set a number option:
    // <xx>         accept special key codes for 'wildchar' or 'wildcharm'
    // ^x           accept ctrl key codes for 'wildchar' or 'wildcharm'
    // c            accept any non-digit for 'wildchar' or 'wildcharm'
    // [-]0-9       set number
    // other        error
    arg++;
    if (((OptInt *)varp == &p_wc || (OptInt *)varp == &p_wcm)
        && (*arg == '<' || *arg == '^'
            || (*arg != NUL && (!arg[1] || ascii_iswhite(arg[1])) && !ascii_isdigit(*arg)))) {
      newval_num = string_to_key(arg);
      if (newval_num == 0) {
        *errmsg = e_invarg;
        return newval;
      }
    } else if (*arg == '-' || ascii_isdigit(*arg)) {
      int i;
      // Allow negative, octal and hex numbers.
      vim_str2nr(arg, NULL, &i, STR2NR_ALL, &newval_num, NULL, 0, true, NULL);
      if (i == 0 || (arg[i] != NUL && !ascii_iswhite(arg[i]))) {
        *errmsg = e_number_required_after_equal;
        return newval;
      }
    } else {
      *errmsg = e_number_required_after_equal;
      return newval;
    }

    if (op == OP_ADDING) {
      newval_num = oldval_num + newval_num;
    }
    if (op == OP_PREPENDING) {
      newval_num = oldval_num * newval_num;
    }
    if (op == OP_REMOVING) {
      newval_num = oldval_num - newval_num;
    }

    newval = NUMBER_OPTVAL(newval_num);
    break;
  }
  case kOptValTypeString: {
    char *oldval_str = oldval.data.string.data;
    // Get the new value for the option
    char *newval_str = stropt_get_newval(nextchar, opt_idx, argp, varp, oldval_str, &op, flags);
    newval = CSTR_AS_OPTVAL(newval_str);
    break;
  }
  }

  return newval;
}

static void do_one_set_option(int opt_flags, char **argp, bool *did_show, char *errbuf,
                              size_t errbuflen, const char **errmsg)
{
  // 1: nothing, 0: "no", 2: "inv" in front of name
  set_prefix_T prefix = get_option_prefix(argp);

  char *arg = *argp;

  // find end of name
  OptIndex opt_idx;
  const char *const option_end = find_option_end(arg, &opt_idx);

  if (opt_idx != kOptInvalid) {
    assert(option_end >= arg);
  } else if (is_tty_option(arg)) {  // Silently ignore TTY options.
    return;
  } else {                          // Invalid option name, skip.
    *errmsg = e_unknown_option;
    return;
  }

  // Remember character after option name.
  uint8_t afterchar = (uint8_t)(*option_end);
  char *p = (char *)option_end;

  // Skip white space, allow ":set ai  ?".
  while (ascii_iswhite(*p)) {
    p++;
  }

  set_op_T op = get_op(p);
  if (op != OP_NONE) {
    p++;
  }

  uint8_t nextchar = (uint8_t)(*p);  // next non-white char after option name
  // flags for current option
  uint32_t flags = options[opt_idx].flags;
  // pointer to variable for current option
  void *varp = get_varp_scope(&(options[opt_idx]), opt_flags);

  if (validate_opt_idx(curwin, opt_idx, opt_flags, flags, prefix, errmsg) == FAIL) {
    return;
  }

  if (vim_strchr("?=:!&<", nextchar) != NULL) {
    *argp = p;

    if (nextchar == '&' && (*argp)[1] == 'v' && (*argp)[2] == 'i') {
      if ((*argp)[3] == 'm') {  // "opt&vim": set to Vim default
        *argp += 3;
      } else {  // "opt&vi": set to Vi default
        *argp += 2;
      }
    }
    if (vim_strchr("?!&<", nextchar) != NULL
        && (*argp)[1] != NUL && !ascii_iswhite((*argp)[1])) {
      *errmsg = e_trailing;
      return;
    }
  }

  // Allow '=' and ':' as MS-DOS command.com allows only one '=' character per "set" command line.
  if (nextchar == '?'
      || (prefix == PREFIX_NONE && vim_strchr("=:&<", nextchar) == NULL
          && !option_has_type(opt_idx, kOptValTypeBoolean))) {
    // print value
    if (*did_show) {
      msg_putchar('\n');                // cursor below last one
    } else {
      gotocmdline(true);                // cursor at status line
      *did_show = true;                 // remember that we did a line
    }
    msg_ext_set_kind("list_cmd");
    showoneopt(&options[opt_idx], opt_flags);

    if (p_verbose > 0) {
      // Mention where the option was last set.
      if (varp == options[opt_idx].var) {
        option_last_set_msg(options[opt_idx].last_set);
      } else if (option_has_scope(opt_idx, kOptScopeWin)) {
        option_last_set_msg(curwin->w_p_script_ctx[option_scope_idx(opt_idx, kOptScopeWin)]);
      } else if (option_has_scope(opt_idx, kOptScopeBuf)) {
        option_last_set_msg(curbuf->b_p_script_ctx[option_scope_idx(opt_idx, kOptScopeBuf)]);
      }
    }

    if (nextchar != '?' && nextchar != NUL && !ascii_iswhite(afterchar)) {
      *errmsg = e_trailing;
    }
    return;
  }

  if (option_has_type(opt_idx, kOptValTypeBoolean)) {
    if (vim_strchr("=:", nextchar) != NULL) {
      *errmsg = e_invarg;
      return;
    }

    if (vim_strchr("!&<", nextchar) == NULL && nextchar != NUL && !ascii_iswhite(afterchar)) {
      *errmsg = e_trailing;
      return;
    }
  } else {
    if (vim_strchr("=:&<", nextchar) == NULL) {
      *errmsg = e_invarg;
      return;
    }
  }

  OptVal newval = get_option_newval(opt_idx, opt_flags, prefix, argp, nextchar, op, flags, varp,
                                    errbuf, errbuflen, errmsg);

  if (newval.type == kOptValTypeNil || *errmsg != NULL) {
    return;
  }

  *errmsg = set_option(opt_idx, newval, opt_flags, 0, false, op == OP_NONE, errbuf, errbuflen);
}

/// Parse 'arg' for option settings.
///
/// 'arg' may be IObuff, but only when no errors can be present and option
/// does not need to be expanded with option_expand().
/// "opt_flags":
/// 0 for ":set"
/// OPT_GLOBAL   for ":setglobal"
/// OPT_LOCAL    for ":setlocal" and a modeline
/// OPT_MODELINE for a modeline
/// OPT_WINONLY  to only set window-local options
/// OPT_NOWIN    to skip setting window-local options
///
/// @param arg  option string (may be written to!)
///
/// @return  FAIL if an error is detected, OK otherwise
int do_set(char *arg, int opt_flags)
{
  bool did_show = false;             // already showed one value

  if (*arg == NUL) {
    showoptions(false, opt_flags);
    did_show = true;
  } else {
    while (*arg != NUL) {         // loop to process all options
      if (strncmp(arg, "all", 3) == 0 && !ASCII_ISALPHA(arg[3])
          && !(opt_flags & OPT_MODELINE)) {
        // ":set all"  show all options.
        // ":set all&" set all options to their default value.
        arg += 3;
        if (*arg == '&') {
          arg++;
          // Only for :set command set global value of local options.
          set_options_default(opt_flags);
          didset_options();
          didset_options2();
          ui_refresh_options();
          redraw_all_later(UPD_CLEAR);
        } else {
          showoptions(true, opt_flags);
          did_show = true;
        }
      } else {
        char *startarg = arg;             // remember for error message
        const char *errmsg = NULL;
        char errbuf[ERR_BUFLEN];

        do_one_set_option(opt_flags, &arg, &did_show, errbuf, sizeof(errbuf), &errmsg);

        // Advance to next argument.
        // - skip until a blank found, taking care of backslashes
        // - skip blanks
        // - skip one "=val" argument (for hidden options ":set gfn =xx")
        for (int i = 0; i < 2; i++) {
          arg = skiptowhite_esc(arg);
          arg = skipwhite(arg);
          if (*arg != '=') {
            break;
          }
        }

        if (errmsg != NULL) {
          int i = vim_snprintf((char *)IObuff, IOSIZE, "%s", _(errmsg)) + 2;
          if (i + (arg - startarg) < IOSIZE) {
            // append the argument with the error
            xstrlcpy(IObuff + i - 2, ": ", (size_t)(IOSIZE - i + 2));
            assert(arg >= startarg);
            memmove(IObuff + i, startarg, (size_t)(arg - startarg));
            IObuff[i + (arg - startarg)] = NUL;
          }
          // make sure all characters are printable
          trans_characters(IObuff, IOSIZE);

          no_wait_return++;         // wait_return() done later
          emsg(IObuff);             // show error highlighted
          no_wait_return--;

          return FAIL;
        }
      }

      arg = skipwhite(arg);
    }
  }

  if (silent_mode && did_show) {
    // After displaying option values in silent mode.
    silent_mode = false;
    info_message = true;        // use stdout, not stderr
    msg_putchar('\n');
    silent_mode = true;
    info_message = false;       // use stdout, not stderr
  }

  return OK;
}

// Translate a string like "t_xx", "<t_xx>" or "<S-Tab>" to a key number.
// When "has_lt" is true there is a '<' before "*arg_arg".
// Returns 0 when the key is not recognized.
static int find_key_len(const char *arg_arg, size_t len, bool has_lt)
{
  int key = 0;
  const char *arg = arg_arg;

  // Don't use get_special_key_code() for t_xx, we don't want it to call
  // add_termcap_entry().
  if (len >= 4 && arg[0] == 't' && arg[1] == '_') {
    if (!has_lt || arg[4] == '>') {
      key = TERMCAP2KEY((uint8_t)arg[2], (uint8_t)arg[3]);
    }
  } else if (has_lt) {
    arg--;  // put arg at the '<'
    int modifiers = 0;
    key = find_special_key(&arg, len + 1, &modifiers, FSK_KEYCODE | FSK_KEEP_X_KEY | FSK_SIMPLIFY,
                           NULL);
    if (modifiers) {  // can't handle modifiers here
      key = 0;
    }
  }
  return key;
}

/// Convert a key name or string into a key value.
/// Used for 'cedit', 'wildchar' and 'wildcharm' options.
int string_to_key(char *arg)
{
  if (*arg == '<' && arg[1]) {
    return find_key_len(arg + 1, strlen(arg), true);
  }
  if (*arg == '^' && arg[1]) {
    int key = CTRL_CHR((uint8_t)arg[1]);
    if (key == 0) {  // ^@ is <Nul>
      key = K_ZERO;
    }
    return key;
  }
  return (uint8_t)(*arg);
}

// When changing 'title', 'titlestring', 'icon' or 'iconstring', call
// maketitle() to create and display it.
// When switching the title or icon off, call ui_set_{icon,title}(NULL) to get
// the old value back.
void did_set_title(void)
{
  if (starting != NO_SCREEN) {
    maketitle();
  }
}

/// set_options_bin -  called when 'bin' changes value.
///
/// @param opt_flags  OPT_LOCAL and/or OPT_GLOBAL
void set_options_bin(int oldval, int newval, int opt_flags)
{
  // The option values that are changed when 'bin' changes are
  // copied when 'bin is set and restored when 'bin' is reset.
  if (newval) {
    if (!oldval) {              // switched on
      if (!(opt_flags & OPT_GLOBAL)) {
        curbuf->b_p_tw_nobin = curbuf->b_p_tw;
        curbuf->b_p_wm_nobin = curbuf->b_p_wm;
        curbuf->b_p_ml_nobin = curbuf->b_p_ml;
        curbuf->b_p_et_nobin = curbuf->b_p_et;
      }
      if (!(opt_flags & OPT_LOCAL)) {
        p_tw_nobin = p_tw;
        p_wm_nobin = p_wm;
        p_ml_nobin = p_ml;
        p_et_nobin = p_et;
      }
    }

    if (!(opt_flags & OPT_GLOBAL)) {
      curbuf->b_p_tw = 0;       // no automatic line wrap
      curbuf->b_p_wm = 0;       // no automatic line wrap
      curbuf->b_p_ml = 0;       // no modelines
      curbuf->b_p_et = 0;       // no expandtab
    }
    if (!(opt_flags & OPT_LOCAL)) {
      p_tw = 0;
      p_wm = 0;
      p_ml = false;
      p_et = false;
      p_bin = true;             // needed when called for the "-b" argument
    }
  } else if (oldval) {        // switched off
    if (!(opt_flags & OPT_GLOBAL)) {
      curbuf->b_p_tw = curbuf->b_p_tw_nobin;
      curbuf->b_p_wm = curbuf->b_p_wm_nobin;
      curbuf->b_p_ml = curbuf->b_p_ml_nobin;
      curbuf->b_p_et = curbuf->b_p_et_nobin;
    }
    if (!(opt_flags & OPT_LOCAL)) {
      p_tw = p_tw_nobin;
      p_wm = p_wm_nobin;
      p_ml = p_ml_nobin;
      p_et = p_et_nobin;
    }
  }

  // Remember where the dependent option were reset
  didset_options_sctx(opt_flags, p_bin_dep_opts);
}

/// Find the parameter represented by the given character (eg ', :, ", or /),
/// and return its associated value in the 'shada' string.
/// Only works for number parameters, not for 'r' or 'n'.
/// If the parameter is not specified in the string or there is no following
/// number, return -1.
int get_shada_parameter(int type)
{
  char *p = find_shada_parameter(type);
  if (p != NULL && ascii_isdigit(*p)) {
    return atoi(p);
  }
  return -1;
}

/// Find the parameter represented by the given character (eg ''', ':', '"', or
/// '/') in the 'shada' option and return a pointer to the string after it.
/// Return NULL if the parameter is not specified in the string.
char *find_shada_parameter(int type)
{
  for (char *p = p_shada; *p; p++) {
    if (*p == type) {
      return p + 1;
    }
    if (*p == 'n') {                // 'n' is always the last one
      break;
    }
    p = vim_strchr(p, ',');         // skip until next ','
    if (p == NULL) {                // hit the end without finding parameter
      break;
    }
  }
  return NULL;
}

/// Expand environment variables for some string options.
/// These string options cannot be indirect!
/// If "val" is NULL expand the current value of the option.
/// Return pointer to NameBuff, or NULL when not expanded.
static char *option_expand(OptIndex opt_idx, char *val)
{
  // if option doesn't need expansion nothing to do
  if (!(options[opt_idx].flags & kOptFlagExpand) || is_option_hidden(opt_idx)) {
    return NULL;
  }

  if (val == NULL) {
    val = *(char **)options[opt_idx].var;
  }

  // If val is longer than MAXPATHL no meaningful expansion can be done,
  // expand_env() would truncate the string.
  if (val == NULL || strlen(val) > MAXPATHL) {
    return NULL;
  }

  // Expanding this with NameBuff, expand_env() must not be passed IObuff.
  // Escape spaces when expanding 'tags', they are used to separate file
  // names.
  // For 'spellsuggest' expand after "file:".
  expand_env_esc(val, NameBuff, MAXPATHL,
                 (char **)options[opt_idx].var == &p_tags, false,
                 (char **)options[opt_idx].var == &p_sps ? "file:"
                                                         : NULL);
  if (strcmp(NameBuff, val) == 0) {   // they are the same
    return NULL;
  }

  return NameBuff;
}

/// After setting various option values: recompute variables that depend on
/// option values.
static void didset_options(void)
{
  // initialize the table for 'iskeyword' et.al.
  init_chartab();

  didset_string_options();

  spell_check_msm();
  spell_check_sps();
  compile_cap_prog(curwin->w_s);
  did_set_spell_option();
  // set cedit_key
  did_set_cedit(NULL);
  // initialize the table for 'breakat'.
  did_set_breakat(NULL);
  didset_window_options(curwin, true);
}

// More side effects of setting options.
static void didset_options2(void)
{
  // Initialize the highlight_attr[] table.
  highlight_changed();

  // Parse default for 'fillchars'.
  set_chars_option(curwin, curwin->w_p_fcs, kFillchars, true, NULL, 0);

  // Parse default for 'listchars'.
  set_chars_option(curwin, curwin->w_p_lcs, kListchars, true, NULL, 0);

  // Parse default for 'wildmode'.
  check_opt_wim();
  xfree(curbuf->b_p_vsts_array);
  tabstop_set(curbuf->b_p_vsts, &curbuf->b_p_vsts_array);
  xfree(curbuf->b_p_vts_array);
  tabstop_set(curbuf->b_p_vts,  &curbuf->b_p_vts_array);
}

/// Check for string options that are NULL (normally only termcap options).
void check_options(void)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    if ((option_has_type(opt_idx, kOptValTypeString)) && options[opt_idx].var != NULL) {
      check_string_option((char **)get_varp(&(options[opt_idx])));
    }
  }
}

/// Check if option was set insecurely.
///
/// @param  wp         Window.
/// @param  opt_idx    Option index in options[] table.
/// @param  opt_flags  Option flags.
///
/// @return  True if option was set from a modeline or in secure mode, false if it wasn't.
int was_set_insecurely(win_T *const wp, OptIndex opt_idx, int opt_flags)
{
  assert(opt_idx != kOptInvalid);

  uint32_t *flagp = insecure_flag(wp, opt_idx, opt_flags);
  return (*flagp & kOptFlagInsecure) != 0;
}

/// Get a pointer to the flags used for the kOptFlagInsecure flag of option
/// "opt_idx".  For some local options a local flags field is used.
/// NOTE: Caller must make sure that "wp" is set to the window from which
/// the option is used.
uint32_t *insecure_flag(win_T *const wp, OptIndex opt_idx, int opt_flags)
{
  if (opt_flags & OPT_LOCAL) {
    assert(wp != NULL);
    switch (opt_idx) {
    case kOptStatusline:
      return &wp->w_p_stl_flags;
    case kOptWinbar:
      return &wp->w_p_wbr_flags;
    case kOptFoldexpr:
      return &wp->w_p_fde_flags;
    case kOptFoldtext:
      return &wp->w_p_fdt_flags;
    case kOptIndentexpr:
      return &wp->w_buffer->b_p_inde_flags;
    case kOptFormatexpr:
      return &wp->w_buffer->b_p_fex_flags;
    case kOptIncludeexpr:
      return &wp->w_buffer->b_p_inex_flags;
    default:
      break;
    }
  }
  // Nothing special, return global flags field.
  return &options[opt_idx].flags;
}

/// Redraw the window title and/or tab page text later.
void redraw_titles(void)
{
  need_maketitle = true;
  redraw_tabline = true;
}

/// Return true if "val" is a valid name: only consists of alphanumeric ASCII
/// characters or characters in "allowed".
bool valid_name(const char *val, const char *allowed)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (const char *s = val; *s != NUL; s++) {
    if (!ASCII_ISALNUM(*s)
        && vim_strchr(allowed, (uint8_t)(*s)) == NULL) {
      return false;
    }
  }
  return true;
}

void check_blending(win_T *wp)
{
  wp->w_grid_alloc.blending =
    wp->w_p_winbl > 0 || (wp->w_floating && wp->w_config.shadow);
}

/// Handle setting `winhighlight' in window "wp"
///
/// @param winhl  when NULL: use "wp->w_p_winhl"
/// @param wp     when NULL: only parse "winhl"
///
/// @return  whether the option value is valid.
bool parse_winhl_opt(const char *winhl, win_T *wp)
{
  const char *p = empty_string_option;
  if (winhl != NULL) {
    p = winhl;
  } else if (wp != NULL) {
    p = wp->w_p_winhl;
  }

  if (!*p) {
    if (wp != NULL && wp->w_ns_hl_winhl && wp->w_ns_hl == wp->w_ns_hl_winhl) {
      wp->w_ns_hl = 0;
      wp->w_hl_needs_update = true;
    }

    return true;
  }

  int ns_hl = 0;
  if (wp != NULL) {
    if (wp->w_ns_hl_winhl == 0) {
      wp->w_ns_hl_winhl = (int)nvim_create_namespace(NULL_STRING);
    } else {
      // Namespace already exists. Invalidate existing items.
      DecorProvider *dp = get_decor_provider(wp->w_ns_hl_winhl, true);
      dp->hl_valid++;
    }
    wp->w_ns_hl = wp->w_ns_hl_winhl;
    ns_hl = wp->w_ns_hl;
  }

  while (*p) {
    const char *colon = strchr(p, ':');
    if (!colon) {
      return false;
    }
    size_t nlen = (size_t)(colon - p);
    const char *hi = colon + 1;
    const char *commap = xstrchrnul(hi, ',');
    size_t len = (size_t)(commap - hi);
    int hl_id = len ? syn_check_group(hi, len) : -1;
    if (hl_id == 0) {
      return false;
    }
    int hl_id_link = nlen ? syn_check_group(p, nlen) : 0;
    if (hl_id_link == 0) {
      return false;
    }

    if (wp != NULL) {
      HlAttrs attrs = HLATTRS_INIT;
      attrs.rgb_ae_attr |= HL_GLOBAL;
      ns_hl_def(ns_hl, hl_id_link, attrs, hl_id, NULL);
    }

    p = *commap ? commap + 1 : "";
  }

  if (wp != NULL) {
    wp->w_hl_needs_update = true;
  }
  return true;
}

/// Get the script context of global option at index opt_idx.
sctx_T *get_option_sctx(OptIndex opt_idx)
{
  assert(opt_idx != kOptInvalid);
  return &options[opt_idx].last_set.script_ctx;
}

/// Set the script_ctx for an option, taking care of setting the buffer- or
/// window-local value.
void set_option_sctx(OptIndex opt_idx, int opt_flags, sctx_T script_ctx)
{
  bool both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  nlua_set_sctx(&script_ctx);
  LastSet last_set = {
    .script_ctx = script_ctx,
    .channel_id = current_channel_id,
  };

  // Modeline already has the line number set.
  if (!(opt_flags & OPT_MODELINE)) {
    last_set.script_ctx.sc_lnum += SOURCING_LNUM;
  }

  // Remember where the option was set.  For local options need to do that
  // in the buffer or window structure.
  if (both || (opt_flags & OPT_GLOBAL) || option_is_global_only(opt_idx)) {
    options[opt_idx].last_set = last_set;
  }
  if (both || (opt_flags & OPT_LOCAL)) {
    if (option_has_scope(opt_idx, kOptScopeBuf)) {
      curbuf->b_p_script_ctx[option_scope_idx(opt_idx, kOptScopeBuf)] = last_set;
    } else if ((option_has_scope(opt_idx, kOptScopeWin))) {
      curwin->w_p_script_ctx[option_scope_idx(opt_idx, kOptScopeWin)] = last_set;
      if (both) {
        // also setting the "all buffers" value
        curwin->w_allbuf_opt.wo_script_ctx[option_scope_idx(opt_idx, kOptScopeWin)] = last_set;
      }
    }
  }
}

/// Apply the OptionSet autocommand.
static void apply_optionset_autocmd(OptIndex opt_idx, int opt_flags, OptVal oldval, OptVal oldval_g,
                                    OptVal oldval_l, OptVal newval, const char *errmsg)
{
  // Don't do this while starting up, failure or recursively.
  if (starting || errmsg != NULL || *get_vim_var_str(VV_OPTION_TYPE) != NUL) {
    return;
  }

  char buf_type[7];
  typval_T oldval_tv = optval_as_tv(oldval, false);
  typval_T oldval_g_tv = optval_as_tv(oldval_g, false);
  typval_T oldval_l_tv = optval_as_tv(oldval_l, false);
  typval_T newval_tv = optval_as_tv(newval, false);

  vim_snprintf(buf_type, sizeof(buf_type), "%s", (opt_flags & OPT_LOCAL) ? "local" : "global");
  set_vim_var_tv(VV_OPTION_NEW, &newval_tv);
  set_vim_var_tv(VV_OPTION_OLD, &oldval_tv);
  set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
  if (opt_flags & OPT_LOCAL) {
    set_vim_var_string(VV_OPTION_COMMAND, "setlocal", -1);
    set_vim_var_tv(VV_OPTION_OLDLOCAL, &oldval_tv);
  }
  if (opt_flags & OPT_GLOBAL) {
    set_vim_var_string(VV_OPTION_COMMAND, "setglobal", -1);
    set_vim_var_tv(VV_OPTION_OLDGLOBAL, &oldval_tv);
  }
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    set_vim_var_string(VV_OPTION_COMMAND, "set", -1);
    set_vim_var_tv(VV_OPTION_OLDLOCAL, &oldval_l_tv);
    set_vim_var_tv(VV_OPTION_OLDGLOBAL, &oldval_g_tv);
  }
  if (opt_flags & OPT_MODELINE) {
    set_vim_var_string(VV_OPTION_COMMAND, "modeline", -1);
    set_vim_var_tv(VV_OPTION_OLDLOCAL, &oldval_tv);
  }
  apply_autocmds(EVENT_OPTIONSET, options[opt_idx].fullname, NULL, false, NULL);
  reset_v_option_vars();
}

/// Process the updated 'arabic' option value.
static const char *did_set_arabic(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  const char *errmsg = NULL;

  if (win->w_p_arab) {
    // 'arabic' is set, handle various sub-settings.
    if (!p_tbidi) {
      // set rightleft mode
      if (!win->w_p_rl) {
        win->w_p_rl = true;
        changed_window_setting(win);
      }

      // Enable Arabic shaping (major part of what Arabic requires)
      if (!p_arshape) {
        p_arshape = true;
        redraw_all_later(UPD_NOT_VALID);
      }
    }

    // Arabic requires a utf-8 encoding, inform the user if it's not
    // set.
    if (strcmp(p_enc, "utf-8") != 0) {
      static char *w_arabic = N_("W17: Arabic requires UTF-8, do ':set encoding=utf-8'");

      msg_source(HLF_W);
      msg(_(w_arabic), HLF_W);
      set_vim_var_string(VV_WARNINGMSG, _(w_arabic), -1);
    }

    // set 'delcombine'
    p_deco = true;

    // Force-set the necessary keymap for arabic.
    errmsg = set_option_value(kOptKeymap, STATIC_CSTR_AS_OPTVAL("arabic"), OPT_LOCAL);
  } else {
    // 'arabic' is reset, handle various sub-settings.
    if (!p_tbidi) {
      // reset rightleft mode
      if (win->w_p_rl) {
        win->w_p_rl = false;
        changed_window_setting(win);
      }

      // 'arabicshape' isn't reset, it is a global option and
      // another window may still need it "on".
    }

    // 'delcombine' isn't reset, it is a global option and another
    // window may still want it "on".

    // Revert to the default keymap
    win->w_buffer->b_p_iminsert = B_IMODE_NONE;
    win->w_buffer->b_p_imsearch = B_IMODE_USE_INSERT;
  }

  return errmsg;
}

/// Process the updated 'autochdir' option value.
static const char *did_set_autochdir(optset_T *args FUNC_ATTR_UNUSED)
{
  // Change directories when the 'acd' option is set now.
  do_autochdir();
  return NULL;
}

/// Process the updated 'binary' option value.
static const char *did_set_binary(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;

  // when 'bin' is set also set some other options
  set_options_bin((int)args->os_oldval.boolean, buf->b_p_bin, args->os_flags);
  redraw_titles();

  return NULL;
}

/// Process the updated 'buflisted' option value.
static const char *did_set_buflisted(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;

  // when 'buflisted' changes, trigger autocommands
  if (args->os_oldval.boolean != buf->b_p_bl) {
    apply_autocmds(buf->b_p_bl ? EVENT_BUFADD : EVENT_BUFDELETE,
                   NULL, NULL, true, buf);
  }
  return NULL;
}

/// Process the new 'cmdheight' option value.
static const char *did_set_cmdheight(optset_T *args)
{
  OptInt old_value = args->os_oldval.number;

  if (p_ch > Rows - min_rows() + 1) {
    p_ch = Rows - min_rows() + 1;
  }

  // if p_ch changed value, change the command line height
  // Only compute the new window layout when startup has been
  // completed. Otherwise the frame sizes may be wrong.
  if ((p_ch != old_value
       || tabline_height() + global_stl_height() + topframe->fr_height != Rows - p_ch)
      && full_screen) {
    command_height();
  }

  return NULL;
}

/// Process the updated 'diff' option value.
static const char *did_set_diff(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  // May add or remove the buffer from the list of diff buffers.
  diff_buf_adjust(win);
  if (foldmethodIsDiff(win)) {
    foldUpdateAll(win);
  }
  return NULL;
}

/// Process the updated 'endoffile' or 'endofline' or 'fixendofline' or 'bomb'
/// option value.
static const char *did_set_eof_eol_fixeol_bomb(optset_T *args FUNC_ATTR_UNUSED)
{
  // redraw the window title and tab page text
  redraw_titles();
  return NULL;
}

/// Process the updated 'equalalways' option value.
static const char *did_set_equalalways(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (p_ea && !args->os_oldval.boolean) {
    win_equal(win, false, 0);
  }

  return NULL;
}

/// Process the new 'foldlevel' option value.
static const char *did_set_foldlevel(optset_T *args FUNC_ATTR_UNUSED)
{
  newFoldLevel();
  return NULL;
}

/// Process the new 'foldminlines' option value.
static const char *did_set_foldminlines(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  foldUpdateAll(win);
  return NULL;
}

/// Process the new 'foldnestmax' option value.
static const char *did_set_foldnestmax(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (foldmethodIsSyntax(win) || foldmethodIsIndent(win)) {
    foldUpdateAll(win);
  }
  return NULL;
}

/// Process the new 'helpheight' option value.
static const char *did_set_helpheight(optset_T *args)
{
  // Change window height NOW
  if (!ONE_WINDOW) {
    if (curbuf->b_help && curwin->w_height < p_hh) {
      win_setheight((int)p_hh);
    }
  }

  return NULL;
}

/// Process the updated 'hlsearch' option value.
static const char *did_set_hlsearch(optset_T *args FUNC_ATTR_UNUSED)
{
  // when 'hlsearch' is set or reset: reset no_hlsearch
  set_no_hlsearch(false);
  return NULL;
}

/// Process the updated 'ignorecase' option value.
static const char *did_set_ignorecase(optset_T *args FUNC_ATTR_UNUSED)
{
  // when 'ignorecase' is set or reset and 'hlsearch' is set, redraw
  if (p_hls) {
    redraw_all_later(UPD_SOME_VALID);
  }
  return NULL;
}

/// Process the new 'iminset' option value.
static const char *did_set_iminsert(optset_T *args FUNC_ATTR_UNUSED)
{
  showmode();
  // Show/unshow value of 'keymap' in status lines.
  status_redraw_curbuf();

  return NULL;
}

/// Process the updated 'langnoremap' option value.
static const char *did_set_langnoremap(optset_T *args FUNC_ATTR_UNUSED)
{
  // 'langnoremap' -> !'langremap'
  p_lrm = !p_lnr;
  return NULL;
}

/// Process the updated 'langremap' option value.
static const char *did_set_langremap(optset_T *args FUNC_ATTR_UNUSED)
{
  // 'langremap' -> !'langnoremap'
  p_lnr = !p_lrm;
  return NULL;
}

/// Process the new 'laststatus' option value.
static const char *did_set_laststatus(optset_T *args)
{
  OptInt old_value = args->os_oldval.number;
  OptInt value = args->os_newval.number;

  // When switching to global statusline, decrease topframe height
  // Also clear the cmdline to remove the ruler if there is one
  if (value == 3 && old_value != 3) {
    frame_new_height(topframe, topframe->fr_height - STATUS_HEIGHT, false, false);
    win_comp_pos();
    clear_cmdline = true;
  }
  // When switching from global statusline, increase height of topframe by STATUS_HEIGHT
  // in order to to re-add the space that was previously taken by the global statusline
  if (old_value == 3 && value != 3) {
    frame_new_height(topframe, topframe->fr_height + STATUS_HEIGHT, false, false);
    win_comp_pos();
  }

  last_status(false);  // (re)set last window status line.
  return NULL;
}

/// Process the updated 'lines' or 'columns' option value.
static const char *did_set_lines_or_columns(optset_T *args)
{
  // If the screen (shell) height has been changed, assume it is the
  // physical screenheight.
  if (p_lines != Rows || p_columns != Columns) {
    // Changing the screen size is not allowed while updating the screen.
    if (updating_screen) {
      OptVal oldval = (OptVal){ .type = kOptValTypeNumber, .data = args->os_oldval };
      set_option_varp(args->os_idx, args->os_varp, oldval, false);
    } else if (full_screen) {
      screen_resize((int)p_columns, (int)p_lines);
    } else {
      // TODO(bfredl): is this branch ever needed?
      // Postpone the resizing; check the size and cmdline position for
      // messages.
      Rows = (int)p_lines;
      Columns = (int)p_columns;
      check_screensize();
      int new_row = (int)(Rows - MAX(p_ch, 1));
      if (cmdline_row > new_row && Rows > p_ch) {
        assert(p_ch >= 0 && new_row <= INT_MAX);
        cmdline_row = new_row;
      }
    }
    if (p_window >= Rows || !option_was_set(kOptWindow)) {
      p_window = Rows - 1;
    }
  }

  // Adjust 'scrolljump' if needed.
  if (p_sj >= Rows && full_screen) {
    p_sj = Rows / 2;
  }

  return NULL;
}

/// Process the updated 'lisp' option value.
static const char *did_set_lisp(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // When 'lisp' option changes include/exclude '-' in keyword characters.
  buf_init_chartab(buf, false);          // ignore errors
  return NULL;
}

/// Process the updated 'modifiable' option value.
static const char *did_set_modifiable(optset_T *args FUNC_ATTR_UNUSED)
{
  // when 'modifiable' is changed, redraw the window title
  redraw_titles();

  return NULL;
}

/// Process the updated 'modified' option value.
static const char *did_set_modified(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  if (!args->os_newval.boolean) {
    save_file_ff(buf);  // Buffer is unchanged
  }
  redraw_titles();
  buf->b_modified_was_set = (int)args->os_newval.boolean;
  return NULL;
}

/// Process the updated 'number' or 'relativenumber' option value.
static const char *did_set_number_relativenumber(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (*win->w_p_stc != NUL) {
    // When 'relativenumber'/'number' is changed and 'statuscolumn' is set, reset width.
    win->w_nrwidth_line_count = 0;
  }
  check_signcolumn(NULL, win);
  return NULL;
}

/// Process the new 'numberwidth' option value.
static const char *did_set_numberwidth(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  win->w_nrwidth_line_count = 0;  // trigger a redraw

  return NULL;
}

/// Process the updated 'paste' option value.
static const char *did_set_paste(optset_T *args FUNC_ATTR_UNUSED)
{
  static int old_p_paste = false;
  static int save_sm = 0;
  static int save_sta = 0;
  static int save_ru = 0;
  static int save_ri = 0;

  if (p_paste) {
    // Paste switched from off to on.
    // Save the current values, so they can be restored later.
    if (!old_p_paste) {
      // save options for each buffer
      FOR_ALL_BUFFERS(buf) {
        buf->b_p_tw_nopaste = buf->b_p_tw;
        buf->b_p_wm_nopaste = buf->b_p_wm;
        buf->b_p_sts_nopaste = buf->b_p_sts;
        buf->b_p_ai_nopaste = buf->b_p_ai;
        buf->b_p_et_nopaste = buf->b_p_et;
        if (buf->b_p_vsts_nopaste) {
          xfree(buf->b_p_vsts_nopaste);
        }
        buf->b_p_vsts_nopaste = buf->b_p_vsts && buf->b_p_vsts != empty_string_option
                                ? xstrdup(buf->b_p_vsts)
                                : NULL;
      }

      // save global options
      save_sm = p_sm;
      save_sta = p_sta;
      save_ru = p_ru;
      save_ri = p_ri;
      // save global values for local buffer options
      p_ai_nopaste = p_ai;
      p_et_nopaste = p_et;
      p_sts_nopaste = p_sts;
      p_tw_nopaste = p_tw;
      p_wm_nopaste = p_wm;
      if (p_vsts_nopaste) {
        xfree(p_vsts_nopaste);
      }
      p_vsts_nopaste = p_vsts && p_vsts != empty_string_option ? xstrdup(p_vsts) : NULL;
    }

    // Always set the option values, also when 'paste' is set when it is
    // already on.
    // set options for each buffer
    FOR_ALL_BUFFERS(buf) {
      buf->b_p_tw = 0;              // textwidth is 0
      buf->b_p_wm = 0;              // wrapmargin is 0
      buf->b_p_sts = 0;             // softtabstop is 0
      buf->b_p_ai = 0;              // no auto-indent
      buf->b_p_et = 0;              // no expandtab
      if (buf->b_p_vsts) {
        free_string_option(buf->b_p_vsts);
      }
      buf->b_p_vsts = empty_string_option;
      XFREE_CLEAR(buf->b_p_vsts_array);
    }

    // set global options
    p_sm = 0;                       // no showmatch
    p_sta = 0;                      // no smarttab
    if (p_ru) {
      status_redraw_all();          // redraw to remove the ruler
    }
    p_ru = 0;                       // no ruler
    p_ri = 0;                       // no reverse insert
    // set global values for local buffer options
    p_tw = 0;
    p_wm = 0;
    p_sts = 0;
    p_ai = 0;
    p_et = 0;
    if (p_vsts) {
      free_string_option(p_vsts);
    }
    p_vsts = empty_string_option;
  } else if (old_p_paste) {
    // Paste switched from on to off: Restore saved values.

    // restore options for each buffer
    FOR_ALL_BUFFERS(buf) {
      buf->b_p_tw = buf->b_p_tw_nopaste;
      buf->b_p_wm = buf->b_p_wm_nopaste;
      buf->b_p_sts = buf->b_p_sts_nopaste;
      buf->b_p_ai = buf->b_p_ai_nopaste;
      buf->b_p_et = buf->b_p_et_nopaste;
      if (buf->b_p_vsts) {
        free_string_option(buf->b_p_vsts);
      }
      buf->b_p_vsts = buf->b_p_vsts_nopaste ? xstrdup(buf->b_p_vsts_nopaste) : empty_string_option;
      xfree(buf->b_p_vsts_array);
      if (buf->b_p_vsts && buf->b_p_vsts != empty_string_option) {
        tabstop_set(buf->b_p_vsts, &buf->b_p_vsts_array);
      } else {
        buf->b_p_vsts_array = NULL;
      }
    }

    // restore global options
    p_sm = save_sm;
    p_sta = save_sta;
    if (p_ru != save_ru) {
      status_redraw_all();          // redraw to draw the ruler
    }
    p_ru = save_ru;
    p_ri = save_ri;
    // set global values for local buffer options
    p_ai = p_ai_nopaste;
    p_et = p_et_nopaste;
    p_sts = p_sts_nopaste;
    p_tw = p_tw_nopaste;
    p_wm = p_wm_nopaste;
    if (p_vsts) {
      free_string_option(p_vsts);
    }
    p_vsts = p_vsts_nopaste ? xstrdup(p_vsts_nopaste) : empty_string_option;
  }

  old_p_paste = p_paste;

  // Remember where the dependent options were reset
  didset_options_sctx((OPT_LOCAL | OPT_GLOBAL), p_paste_dep_opts);

  return NULL;
}

/// Process the updated 'previewwindow' option value.
static const char *did_set_previewwindow(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;

  if (!win->w_p_pvw) {
    return NULL;
  }

  // There can be only one window with 'previewwindow' set.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_p_pvw && wp != win) {
      win->w_p_pvw = false;
      return e_preview_window_already_exists;
    }
  }

  return NULL;
}

/// Process the new 'pumblend' option value.
static const char *did_set_pumblend(optset_T *args FUNC_ATTR_UNUSED)
{
  hl_invalidate_blends();
  pum_grid.blending = (p_pb > 0);
  if (pum_drawn()) {
    pum_redraw();
  }

  return NULL;
}

/// Process the updated 'readonly' option value.
static const char *did_set_readonly(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;

  // when 'readonly' is reset globally, also reset readonlymode
  if (!buf->b_p_ro && (args->os_flags & OPT_LOCAL) == 0) {
    readonlymode = false;
  }

  // when 'readonly' is set may give W10 again
  if (buf->b_p_ro) {
    buf->b_did_warn = false;
  }

  redraw_titles();

  return NULL;
}

/// Process the new 'scrollback' option value.
static const char *did_set_scrollback(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  OptInt old_value = args->os_oldval.number;
  OptInt value = args->os_newval.number;

  if (buf->terminal && value < old_value) {
    // Force the scrollback to take immediate effect only when decreasing it.
    on_scrollback_option_changed(buf->terminal);
  }
  return NULL;
}

/// Process the updated 'scrollbind' option value.
static const char *did_set_scrollbind(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;

  // when 'scrollbind' is set: snapshot the current position to avoid a jump
  // at the end of normal_cmd()
  if (!win->w_p_scb) {
    return NULL;
  }
  do_check_scrollbind(false);
  win->w_scbind_pos = get_vtopline(win);
  return NULL;
}

#ifdef BACKSLASH_IN_FILENAME
/// Process the updated 'shellslash' option value.
static const char *did_set_shellslash(optset_T *args FUNC_ATTR_UNUSED)
{
  if (p_ssl) {
    psepc = '/';
    psepcN = '\\';
    pseps[0] = '/';
  } else {
    psepc = '\\';
    psepcN = '/';
    pseps[0] = '\\';
  }

  // need to adjust the file name arguments and buffer names.
  buflist_slash_adjust();
  alist_slash_adjust();
  scriptnames_slash_adjust();
  return NULL;
}
#endif

/// Process the new 'shiftwidth' or the 'tabstop' option value.
static const char *did_set_shiftwidth_tabstop(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  win_T *win = (win_T *)args->os_win;
  OptInt *pp = (OptInt *)args->os_varp;

  if (foldmethodIsIndent(win)) {
    foldUpdateAll(win);
  }
  // When 'shiftwidth' changes, or it's zero and 'tabstop' changes:
  // parse 'cinoptions'.
  if (pp == &buf->b_p_sw || buf->b_p_sw == 0) {
    parse_cino(buf);
  }

  return NULL;
}

/// Process the new 'showtabline' option value.
static const char *did_set_showtabline(optset_T *args FUNC_ATTR_UNUSED)
{
  // (re)set tab page line
  win_new_screen_rows();  // recompute window positions and heights
  return NULL;
}

/// Process the updated 'smoothscroll' option value.
static const char *did_set_smoothscroll(optset_T *args FUNC_ATTR_UNUSED)
{
  win_T *win = (win_T *)args->os_win;
  if (!win->w_p_sms) {
    win->w_skipcol = 0;
  }

  return NULL;
}

/// Process the updated 'spell' option value.
static const char *did_set_spell(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  if (win->w_p_spell) {
    return parse_spelllang(win);
  }

  return NULL;
}

/// Process the updated 'swapfile' option value.
static const char *did_set_swapfile(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // when 'swf' is set, create swapfile, when reset remove swapfile
  if (buf->b_p_swf && p_uc) {
    ml_open_file(buf);                     // create the swap file
  } else {
    // no need to reset buf->b_may_swap, ml_open_file() will check buf->b_p_swf
    mf_close_file(buf, true);              // remove the swap file
  }
  return NULL;
}

/// Process the new 'textwidth' option value.
static const char *did_set_textwidth(optset_T *args FUNC_ATTR_UNUSED)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    check_colorcolumn(NULL, wp);
  }

  return NULL;
}

/// Process the updated 'title' or the 'icon' option value.
static const char *did_set_title_icon(optset_T *args FUNC_ATTR_UNUSED)
{
  // when 'title' changed, may need to change the title; same for 'icon'
  did_set_title();
  return NULL;
}

/// Process the new 'titlelen' option value.
static const char *did_set_titlelen(optset_T *args)
{
  OptInt old_value = args->os_oldval.number;

  // if 'titlelen' has changed, redraw the title
  if (starting != NO_SCREEN && old_value != p_titlelen) {
    need_maketitle = true;
  }

  return NULL;
}

/// Process the updated 'undofile' option value.
static const char *did_set_undofile(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;

  // Only take action when the option was set.
  if (!buf->b_p_udf && !p_udf) {
    return NULL;
  }

  // When reset we do not delete the undo file, the option may be set again
  // without making any changes in between.
  uint8_t hash[UNDO_HASH_SIZE];

  FOR_ALL_BUFFERS(bp) {
    // When 'undofile' is set globally: for every buffer, otherwise
    // only for the current buffer: Try to read in the undofile,
    // if one exists, the buffer wasn't changed and the buffer was
    // loaded
    if ((buf == bp
         || (args->os_flags & OPT_GLOBAL) || args->os_flags == 0)
        && !bufIsChanged(bp) && bp->b_ml.ml_mfp != NULL) {
      u_compute_hash(bp, hash);
      u_read_undo(NULL, hash, bp->b_fname);
    }
  }

  return NULL;
}

/// Process the new global 'undolevels' option value.
const char *did_set_global_undolevels(OptInt value, OptInt old_value)
{
  // sync undo before 'undolevels' changes
  // use the old value, otherwise u_sync() may not work properly
  p_ul = old_value;
  u_sync(true);
  p_ul = value;
  return NULL;
}

/// Process the new buffer local 'undolevels' option value.
const char *did_set_buflocal_undolevels(buf_T *buf, OptInt value, OptInt old_value)
{
  // use the old value, otherwise u_sync() may not work properly
  buf->b_p_ul = old_value;
  u_sync(true);
  buf->b_p_ul = value;
  return NULL;
}

/// Process the new 'undolevels' option value.
static const char *did_set_undolevels(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  OptInt *pp = (OptInt *)args->os_varp;

  if (pp == &p_ul) {                  // global 'undolevels'
    did_set_global_undolevels(args->os_newval.number, args->os_oldval.number);
  } else if (pp == &buf->b_p_ul) {      // buffer local 'undolevels'
    did_set_buflocal_undolevels(buf, args->os_newval.number, args->os_oldval.number);
  }

  return NULL;
}

/// Process the new 'updatecount' option value.
static const char *did_set_updatecount(optset_T *args)
{
  OptInt old_value = args->os_oldval.number;

  // when 'updatecount' changes from zero to non-zero, open swap files
  if (p_uc && !old_value) {
    ml_open_files();
  }

  return NULL;
}

/// Process the new 'wildchar' / 'wildcharm' option value.
static const char *did_set_wildchar(optset_T *args)
{
  OptInt c = *(OptInt *)args->os_varp;

  // Don't allow key values that wouldn't work as wildchar.
  if (c == Ctrl_C || c == '\n' || c == '\r' || c == K_KENTER) {
    return e_invarg;
  }

  return NULL;
}

/// Process the new 'winblend' option value.
static const char *did_set_winblend(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  OptInt old_value = args->os_oldval.number;
  OptInt value = args->os_newval.number;

  if (value != old_value) {
    win->w_p_winbl = MAX(MIN(win->w_p_winbl, 100), 0);
    win->w_hl_needs_update = true;
    check_blending(win);
  }

  return NULL;
}

/// Process the new 'window' option value.
static const char *did_set_window(optset_T *args FUNC_ATTR_UNUSED)
{
  if (p_window < 1) {
    p_window = Rows - 1;
  } else if (p_window >= Rows) {
    p_window = Rows - 1;
  }
  return NULL;
}

/// Process the new 'winheight' value.
static const char *did_set_winheight(optset_T *args)
{
  // Change window height NOW
  if (!ONE_WINDOW) {
    if (curwin->w_height < p_wh) {
      win_setheight((int)p_wh);
    }
  }

  return NULL;
}

/// Process the new 'winwidth' option value.
static const char *did_set_winwidth(optset_T *args)
{
  if (!ONE_WINDOW && curwin->w_width < p_wiw) {
    win_setwidth((int)p_wiw);
  }
  return NULL;
}

/// Process the updated 'wrap' option value.
static const char *did_set_wrap(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;
  // Set w_leftcol or w_skipcol to zero.
  if (win->w_p_wrap) {
    win->w_leftcol = 0;
  } else {
    win->w_skipcol = 0;
  }

  return NULL;
}

// When 'syntax' is set, load the syntax of that name
static void do_syntax_autocmd(buf_T *buf, bool value_changed)
{
  static int syn_recursive = 0;

  syn_recursive++;
  // Only pass true for "force" when the value changed or not used
  // recursively, to avoid endless recurrence.
  apply_autocmds(EVENT_SYNTAX, buf->b_p_syn, buf->b_fname,
                 value_changed || syn_recursive == 1, buf);
  buf->b_flags |= BF_SYN_SET;
  syn_recursive--;
}

static void do_spelllang_source(win_T *win)
{
  char fname[200];
  char *q = win->w_s->b_p_spl;

  // Skip the first name if it is "cjk".
  if (strncmp(q, "cjk,", 4) == 0) {
    q += 4;
  }

  // Source the spell/LANG.{vim,lua} in 'runtimepath'.
  // They could set 'spellcapcheck' depending on the language.
  // Use the first name in 'spelllang' up to '_region' or
  // '.encoding'.
  char *p;
  for (p = q; *p != NUL; p++) {
    if (!ASCII_ISALNUM(*p) && *p != '-') {
      break;
    }
  }
  if (p > q) {
    vim_snprintf(fname, sizeof(fname), "spell/%.*s.*", (int)(p - q), q);
    source_runtime_vim_lua(fname, DIP_ALL);
  }
}

/// Check the bounds of numeric options.
///
/// @param          opt_idx    Index in options[] table. Must not be kOptInvalid.
/// @param[in,out]  newval     Pointer to new option value. Will be set to bound checked value.
/// @param[out]     errbuf     Buffer for error message. Cannot be NULL.
/// @param          errbuflen  Length of error buffer.
///
/// @return Error message, if any.
static const char *check_num_option_bounds(OptIndex opt_idx, OptInt *newval, char *errbuf,
                                           size_t errbuflen)
  FUNC_ATTR_NONNULL_ARG(3)
{
  const char *errmsg = NULL;

  switch (opt_idx) {
  case kOptLines:
    if (*newval < min_rows() && full_screen) {
      vim_snprintf(errbuf, errbuflen, _("E593: Need at least %d lines"), min_rows());
      errmsg = errbuf;
      *newval = min_rows();
    }
    // True max size is defined by check_screensize().
    *newval = MIN(*newval, INT_MAX);
    break;
  case kOptColumns:
    if (*newval < MIN_COLUMNS && full_screen) {
      vim_snprintf(errbuf, errbuflen, _("E594: Need at least %d columns"), MIN_COLUMNS);
      errmsg = errbuf;
      *newval = MIN_COLUMNS;
    }
    // True max size is defined by check_screensize().
    *newval = MIN(*newval, INT_MAX);
    break;
  case kOptPumblend:
    *newval = MAX(MIN(*newval, 100), 0);
    break;
  case kOptScrolljump:
    if ((*newval < -100 || *newval >= Rows) && full_screen) {
      errmsg = e_scroll;
      *newval = 1;
    }
    break;
  case kOptScroll:
    if ((*newval <= 0 || (*newval > curwin->w_height_inner && curwin->w_height_inner > 0))
        && full_screen) {
      if (*newval != 0) {
        errmsg = e_scroll;
      }
      *newval = win_default_scroll(curwin);
    }
    break;
  default:
    break;
  }

  return errmsg;
}

/// Validate and bound check option value.
///
/// @param          opt_idx    Index in options[] table. Must not be kOptInvalid.
/// @param[in,out]  newval     Pointer to new option value. Will be set to bound checked value.
/// @param[out]     errbuf     Buffer for error message. Cannot be NULL.
/// @param          errbuflen  Length of error buffer.
///
/// @return Error message, if any.
static const char *validate_num_option(OptIndex opt_idx, OptInt *newval, char *errbuf,
                                       size_t errbuflen)
{
  OptInt value = *newval;

  // Many number options assume their value is in the signed int range.
  if (value < INT_MIN || value > INT_MAX) {
    return e_invarg;
  }

  switch (opt_idx) {
  case kOptHelpheight:
  case kOptTitlelen:
  case kOptUpdatecount:
  case kOptReport:
  case kOptUpdatetime:
  case kOptSidescroll:
  case kOptFoldlevel:
  case kOptShiftwidth:
  case kOptTextwidth:
  case kOptWritedelay:
  case kOptTimeoutlen:
    if (value < 0) {
      return e_positive;
    }
    break;
  case kOptWinheight:
    if (value < 1) {
      return e_positive;
    } else if (p_wmh > value) {
      return e_winheight;
    }
    break;
  case kOptWinminheight:
    if (value < 0) {
      return e_positive;
    } else if (value > p_wh) {
      return e_winheight;
    }
    break;
  case kOptWinwidth:
    if (value < 1) {
      return e_positive;
    } else if (p_wmw > value) {
      return e_winwidth;
    }
    break;
  case kOptWinminwidth:
    if (value < 0) {
      return e_positive;
    } else if (value > p_wiw) {
      return e_winwidth;
    }
    break;
  case kOptMaxcombine:
    *newval = MAX_MCO;
    break;
  case kOptCmdheight:
    if (value < 0) {
      return e_positive;
    } else {
      p_ch_was_zero = value == 0;
    }
    break;
  case kOptHistory:
    if (value < 0) {
      return e_positive;
    } else if (value > 10000) {
      return e_invarg;
    }
    break;
  case kOptMsghistory:
    if (value < 0) {
      return e_positive;
    } else if (value > 10000) {
      return e_invarg;
    }
    break;
  case kOptPyxversion:
    if (value == 0) {
      *newval = 3;
    } else if (value != 3) {
      return e_invarg;
    }
    break;
  case kOptRegexpengine:
    if (value < 0 || value > 2) {
      return e_invarg;
    }
    break;
  case kOptScrolloff:
    if (value < 0 && full_screen) {
      return e_positive;
    }
    break;
  case kOptSidescrolloff:
    if (value < 0 && full_screen) {
      return e_positive;
    }
    break;
  case kOptCmdwinheight:
    if (value < 1) {
      return e_positive;
    }
    break;
  case kOptConceallevel:
    if (value < 0) {
      return e_positive;
    } else if (value > 3) {
      return e_invarg;
    }
    break;
  case kOptNumberwidth:
    if (value < 1) {
      return e_positive;
    } else if (value > MAX_NUMBERWIDTH) {
      return e_invarg;
    }
    break;
  case kOptIminsert:
    if (value < 0 || value > B_IMODE_LAST) {
      return e_invarg;
    }
    break;
  case kOptImsearch:
    if (value < -1 || value > B_IMODE_LAST) {
      return e_invarg;
    }
    break;
  case kOptChannel:
    return e_invarg;
  case kOptScrollback:
    if (value < -1 || value > SB_MAX) {
      return e_invarg;
    }
    break;
  case kOptTabstop:
    if (value < 1) {
      return e_positive;
    } else if (value > TABSTOP_MAX) {
      return e_invarg;
    }
    break;
  default:
    break;
  }

  return check_num_option_bounds(opt_idx, newval, errbuf, errbuflen);
}

/// Called after an option changed: check if something needs to be redrawn.
void check_redraw_for(buf_T *buf, win_T *win, uint32_t flags)
{
  // Careful: kOptFlagRedrAll is a combination of other redraw flags
  bool all = (flags & kOptFlagRedrAll) == kOptFlagRedrAll;

  if ((flags & kOptFlagRedrStat) || all) {  // mark all status lines and window bars dirty
    status_redraw_all();
  }

  if ((flags & kOptFlagRedrTabl) || all) {  // mark tablines dirty
    redraw_tabline = true;
  }

  if ((flags & kOptFlagRedrBuf) || (flags & kOptFlagRedrWin) || all) {
    if (flags & kOptFlagHLOnly) {
      redraw_later(win, UPD_NOT_VALID);
    } else {
      changed_window_setting(win);
    }
  }
  if (flags & kOptFlagRedrBuf) {
    redraw_buf_later(buf, UPD_NOT_VALID);
  }
  if (all) {
    redraw_all_later(UPD_NOT_VALID);
  }
}

void check_redraw(uint32_t flags)
{
  check_redraw_for(curbuf, curwin, flags);
}

bool is_tty_option(const char *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return find_tty_option_end(name) != NULL;
}

#define TCO_BUFFER_SIZE 8

/// Get value of TTY option.
///
/// @param  name  Name of TTY option.
///
/// @return [allocated] TTY option value. Returns NIL_OPTVAL if option isn't a TTY option.
OptVal get_tty_option(const char *name)
{
  char *value = NULL;

  if (strequal(name, "t_Co")) {
    if (t_colors <= 1) {
      value = xstrdup("");
    } else {
      value = xmalloc(TCO_BUFFER_SIZE);
      snprintf(value, TCO_BUFFER_SIZE, "%d", t_colors);
    }
  } else if (strequal(name, "term")) {
    value = p_term ? xstrdup(p_term) : xstrdup("nvim");
  } else if (strequal(name, "ttytype")) {
    value = p_ttytype ? xstrdup(p_ttytype) : xstrdup("nvim");
  } else if (is_tty_option(name)) {
    // XXX: All other t_* options were removed in 3baba1e7.
    value = xstrdup("");
  }

  return value == NULL ? NIL_OPTVAL : CSTR_AS_OPTVAL(value);
}

bool set_tty_option(const char *name, char *value)
{
  if (strequal(name, "term")) {
    if (p_term) {
      xfree(p_term);
    }
    p_term = value;
    return true;
  }

  if (strequal(name, "ttytype")) {
    if (p_ttytype) {
      xfree(p_ttytype);
    }
    p_ttytype = value;
    return true;
  }

  return false;
}

/// Find index for an option. Don't go beyond `len` length.
///
/// @param[in]  name  Option name.
/// @param      len   Option name length.
///
/// @return Option index or kOptInvalid if option was not found.
OptIndex find_option_len(const char *const name, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  int index = find_option_hash(name, len);
  return index >= 0 ? option_hash_elems[index].opt_idx : kOptInvalid;
}

/// Find index for an option.
///
/// @param[in]  name  Option name.
///
/// @return Option index or kOptInvalid if option was not found.
OptIndex find_option(const char *const name)
  FUNC_ATTR_NONNULL_ALL
{
  return find_option_len(name, strlen(name));
}

/// Free an allocated OptVal.
void optval_free(OptVal o)
{
  switch (o.type) {
  case kOptValTypeNil:
  case kOptValTypeBoolean:
  case kOptValTypeNumber:
    break;
  case kOptValTypeString:
    // Don't free empty string option
    if (o.data.string.data != empty_string_option) {
      api_free_string(o.data.string);
    }
    break;
  }
}

/// Copy an OptVal.
OptVal optval_copy(OptVal o)
{
  switch (o.type) {
  case kOptValTypeNil:
  case kOptValTypeBoolean:
  case kOptValTypeNumber:
    return o;
  case kOptValTypeString:
    return STRING_OPTVAL(copy_string(o.data.string, NULL));
  }
  UNREACHABLE;
}

/// Check if two option values are equal.
bool optval_equal(OptVal o1, OptVal o2)
{
  if (o1.type != o2.type) {
    return false;
  }

  switch (o1.type) {
  case kOptValTypeNil:
    return true;
  case kOptValTypeBoolean:
    return o1.data.boolean == o2.data.boolean;
  case kOptValTypeNumber:
    return o1.data.number == o2.data.number;
  case kOptValTypeString:
    return o1.data.string.size == o2.data.string.size
           && (o1.data.string.data == o2.data.string.data
               || strnequal(o1.data.string.data, o2.data.string.data, o1.data.string.size));
  }
  UNREACHABLE;
}

/// Get type of option. Does not support multitype options.
static OptValType option_get_type(const OptIndex opt_idx)
{
  assert(!option_is_multitype(opt_idx));

  // If the option only supports a single type, it means that the index of the option's type flag
  // corresponds to the value of the type enum. So get the index of the type flag using xctz() and
  // use that as the option's type.
  OptValType type = xctz(options[opt_idx].type_flags);
  assert(type > kOptValTypeNil && type < kOptValTypeSize);
  return type;
}

/// Create OptVal from var pointer.
///
/// @param       opt_idx  Option index in options[] table.
/// @param[out]  varp     Pointer to option variable.
///
/// @return Option value stored in varp.
OptVal optval_from_varp(OptIndex opt_idx, void *varp)
  FUNC_ATTR_NONNULL_ARG(2)
{
  // Special case: 'modified' is b_changed, but we also want to consider it set when 'ff' or 'fenc'
  // changed.
  if ((int *)varp == &curbuf->b_changed) {
    return BOOLEAN_OPTVAL(curbufIsChanged());
  }

  if (option_is_multitype(opt_idx)) {
    // Multitype options are stored as OptVal.
    return *(OptVal *)varp;
  }

  OptValType type = option_get_type(opt_idx);

  switch (type) {
  case kOptValTypeNil:
    return NIL_OPTVAL;
  case kOptValTypeBoolean:
    return BOOLEAN_OPTVAL(TRISTATE_FROM_INT(*(int *)varp));
  case kOptValTypeNumber:
    return NUMBER_OPTVAL(*(OptInt *)varp);
  case kOptValTypeString:
    return STRING_OPTVAL(cstr_as_string(*(char **)varp));
  }
  UNREACHABLE;
}

/// Set option var pointer value from OptVal.
///
/// @param       opt_idx      Option index in options[] table.
/// @param[out]  varp         Pointer to option variable.
/// @param[in]   value        New option value.
/// @param       free_oldval  Free old value.
static void set_option_varp(OptIndex opt_idx, void *varp, OptVal value, bool free_oldval)
  FUNC_ATTR_NONNULL_ARG(2)
{
  assert(option_has_type(opt_idx, value.type));

  if (free_oldval) {
    optval_free(optval_from_varp(opt_idx, varp));
  }

  switch (value.type) {
  case kOptValTypeNil:
    abort();
  case kOptValTypeBoolean:
    *(int *)varp = value.data.boolean;
    return;
  case kOptValTypeNumber:
    *(OptInt *)varp = value.data.number;
    return;
  case kOptValTypeString:
    *(char **)varp = value.data.string.data;
    return;
  }
  UNREACHABLE;
}

/// Return C-string representation of OptVal. Caller must free the returned C-string.
static char *optval_to_cstr(OptVal o)
{
  switch (o.type) {
  case kOptValTypeNil:
    return xstrdup("");
  case kOptValTypeBoolean:
    return xstrdup(o.data.boolean ? "true" : "false");
  case kOptValTypeNumber: {
    char *buf = xmalloc(NUMBUFLEN);
    snprintf(buf, NUMBUFLEN, "%" PRId64, o.data.number);
    return buf;
  }
  case kOptValTypeString: {
    char *buf = xmalloc(o.data.string.size + 3);
    snprintf(buf, o.data.string.size + 3, "\"%s\"", o.data.string.data);
    return buf;
  }
  }
  UNREACHABLE;
}

/// Convert an OptVal to an API Object.
Object optval_as_object(OptVal o)
{
  switch (o.type) {
  case kOptValTypeNil:
    return NIL;
  case kOptValTypeBoolean:
    switch (o.data.boolean) {
    case kFalse:
    case kTrue:
      return BOOLEAN_OBJ(o.data.boolean);
    case kNone:
      return NIL;
    }
    UNREACHABLE;
  case kOptValTypeNumber:
    return INTEGER_OBJ(o.data.number);
  case kOptValTypeString:
    return STRING_OBJ(o.data.string);
  }
  UNREACHABLE;
}

/// Convert an API Object to an OptVal.
OptVal object_as_optval(Object o, bool *error)
{
  switch (o.type) {
  case kObjectTypeNil:
    return NIL_OPTVAL;
  case kObjectTypeBoolean:
    return BOOLEAN_OPTVAL(o.data.boolean);
  case kObjectTypeInteger:
    return NUMBER_OPTVAL((OptInt)o.data.integer);
  case kObjectTypeString:
    return STRING_OPTVAL(o.data.string);
  default:
    *error = true;
    return NIL_OPTVAL;
  }
  UNREACHABLE;
}

/// Get an allocated string containing a list of valid types for an option.
/// For options with a singular type, it returns the name of the type. For options with multiple
/// possible types, it returns a slash separated list of types. For example, if an option can be a
/// number, boolean or string, the function returns "number/boolean/string"
static char *option_get_valid_types(OptIndex opt_idx)
{
  StringBuilder str = KV_INITIAL_VALUE;
  kv_resize(str, 32);

  // Iterate through every valid option value type and check if the option supports that type
  for (OptValType type = 0; type < kOptValTypeSize; type++) {
    if (option_has_type(opt_idx, type)) {
      const char *typename = optval_type_get_name(type);

      if (str.size == 0) {
        kv_concat(str, typename);
      } else {
        kv_printf(str, "/%s", typename);
      }
    }
  }

  // Ensure that the string is NUL-terminated.
  kv_push(str, NUL);
  return str.items;
}

/// Check if option is hidden.
///
/// @param  opt_idx  Option index in options[] table.
///
/// @return  True if option is hidden, false otherwise. Returns false if option name is invalid.
bool is_option_hidden(OptIndex opt_idx)
{
  // Hidden options are always immutable and point to their default value
  return opt_idx != kOptInvalid && options[opt_idx].immutable
         && options[opt_idx].var == &options[opt_idx].def_val.data;
}

/// Check if option is multitype (supports multiple types).
static bool option_is_multitype(OptIndex opt_idx)
{
  const OptTypeFlags type_flags = get_option(opt_idx)->type_flags;
  assert(type_flags != 0);
  return !is_power_of_two(type_flags);
}

/// Check if option supports a specific type.
bool option_has_type(OptIndex opt_idx, OptValType type)
{
  // Ensure that type flags variable can hold all types.
  STATIC_ASSERT(kOptValTypeSize <= sizeof(OptTypeFlags) * 8,
                "Option type_flags cannot fit all option types");
  // Ensure that the type is valid before accessing type_flags.
  assert(type > kOptValTypeNil && type < kOptValTypeSize);
  // Bitshift 1 by the value of type to get the type's corresponding flag, and check if it's set in
  // the type_flags bit field.
  return get_option(opt_idx)->type_flags & (1 << type);
}

/// Check if option supports a specific scope.
bool option_has_scope(OptIndex opt_idx, OptScope scope)
{
  // Ensure that scope flags variable can hold all scopes.
  STATIC_ASSERT(kOptScopeSize <= sizeof(OptScopeFlags) * 8,
                "Option scope_flags cannot fit all option scopes");
  // Ensure that the scope is valid before accessing scope_flags.
  assert(scope >= kOptScopeGlobal && scope < kOptScopeSize);
  // Bitshift 1 by the value of scope to get the scope's corresponding flag, and check if it's set
  // in the scope_flags bit field.
  return get_option(opt_idx)->scope_flags & (1 << scope);
}

/// Check if option is global-local.
static inline bool option_is_global_local(OptIndex opt_idx)
{
  // Global-local options have at least two types, so their type flag cannot be a power of two.
  return opt_idx != kOptInvalid && !is_power_of_two(options[opt_idx].scope_flags);
}

/// Check if option only supports global scope.
static inline bool option_is_global_only(OptIndex opt_idx)
{
  // For an option to be global-only, it has to only have a single scope, which means the scope
  // flags must be a power of two, and it must have the global scope.
  return opt_idx != kOptInvalid && is_power_of_two(options[opt_idx].scope_flags)
         && option_has_scope(opt_idx, kOptScopeGlobal);
}

/// Check if option only supports window scope.
static inline bool option_is_window_local(OptIndex opt_idx)
{
  // For an option to be window-local it has to only have a single scope, which means the scope
  // flags must be a power of two, and it must have the window scope.
  return opt_idx != kOptInvalid && is_power_of_two(options[opt_idx].scope_flags)
         && option_has_scope(opt_idx, kOptScopeWin);
}

/// Get option index for scope.
ssize_t option_scope_idx(OptIndex opt_idx, OptScope scope)
{
  return options[opt_idx].scope_idx[scope];
}

/// Get option flags.
///
/// @param  opt_idx  Option index in options[] table.
///
/// @return  Option flags. Returns 0 for invalid option name.
uint32_t get_option_flags(OptIndex opt_idx)
{
  return opt_idx == kOptInvalid ? 0 : options[opt_idx].flags;
}

/// Gets the value for an option.
///
/// @param       opt_idx  Option index in options[] table.
/// @param[in]   scope    Option scope (can be OPT_LOCAL, OPT_GLOBAL or a combination).
///
/// @return [allocated] Option value. Returns NIL_OPTVAL for invalid option index.
OptVal get_option_value(OptIndex opt_idx, int scope)
{
  if (opt_idx == kOptInvalid) {  // option not in the options[] table.
    return NIL_OPTVAL;
  }

  vimoption_T *opt = &options[opt_idx];
  void *varp = get_varp_scope(opt, scope);

  return optval_copy(optval_from_varp(opt_idx, varp));
}

/// Return information for option at 'opt_idx'
vimoption_T *get_option(OptIndex opt_idx)
{
  assert(opt_idx != kOptInvalid);
  return &options[opt_idx];
}

/// Get option value that represents an unset local value for an option.
/// TODO(famiu): Remove this once we have a dedicated OptVal type for unset local options.
///
/// @param      opt_idx  Option index in options[] table.
/// @param[in]  varp  Pointer to option variable.
///
/// @return Option value equal to the unset value for the option.
static OptVal get_option_unset_value(OptIndex opt_idx)
{
  assert(opt_idx != kOptInvalid);
  vimoption_T *opt = &options[opt_idx];

  // For global-local options, use the unset value of the local value.
  if (option_is_global_local(opt_idx)) {
    // String global-local options always use an empty string for the unset value.
    if (option_has_type(opt_idx, kOptValTypeString)) {
      return STATIC_CSTR_AS_OPTVAL("");
    }

    switch (opt_idx) {
    case kOptAutoread:
      return BOOLEAN_OPTVAL(kNone);
    case kOptScrolloff:
    case kOptSidescrolloff:
      return NUMBER_OPTVAL(-1);
    case kOptUndolevels:
      return NUMBER_OPTVAL(NO_LOCAL_UNDOLEVEL);
    default:
      abort();
    }
  }

  // For options that aren't global-local, use the global value to represent an unset local value.
  return optval_from_varp(opt_idx, get_varp_scope(opt, OPT_GLOBAL));
}

/// Check if local value of global-local option is unset for current buffer / window.
/// Always returns false for options that aren't global-local.
///
/// TODO(famiu): Remove this once we have an OptVal type to indicate an unset local value.
static bool is_option_local_value_unset(OptIndex opt_idx)
{
  vimoption_T *opt = get_option(opt_idx);

  // Local value of option that isn't global-local is always considered set.
  if (!option_is_global_local(opt_idx)) {
    return false;
  }

  void *varp_local = get_varp_scope(opt, OPT_LOCAL);
  OptVal local_value = optval_from_varp(opt_idx, varp_local);
  OptVal unset_local_value = get_option_unset_value(opt_idx);

  return optval_equal(local_value, unset_local_value);
}

/// Handle side-effects of setting an option.
///
/// @param       opt_idx         Index in options[] table. Must not be kOptInvalid.
/// @param[in]   varp            Option variable pointer, cannot be NULL.
/// @param       old_value       Old option value.
/// @param       opt_flags       Option flags.
/// @param       set_sid         Script ID. Special values:
///                                0: Use current script ID.
///                                SID_NONE: Don't set script ID.
/// @param       direct          Don't process side-effects.
/// @param       value_replaced  Value was replaced completely.
/// @param[out]  errbuf          Buffer for error message.
/// @param       errbuflen       Length of error buffer.
///
/// @return  NULL on success, an untranslated error message on error.
static const char *did_set_option(OptIndex opt_idx, void *varp, OptVal old_value, OptVal new_value,
                                  int opt_flags, scid_T set_sid, const bool direct,
                                  const bool value_replaced, char *errbuf,  // NOLINT(readability-non-const-parameter)
                                  size_t errbuflen)
{
  vimoption_T *opt = &options[opt_idx];
  const char *errmsg = NULL;
  bool restore_chartab = false;
  bool value_changed = false;
  bool value_checked = false;

  optset_T did_set_cb_args = {
    .os_varp = varp,
    .os_idx = opt_idx,
    .os_flags = opt_flags,
    .os_oldval = old_value.data,
    .os_newval = new_value.data,
    .os_value_checked = false,
    .os_value_changed = false,
    .os_restore_chartab = false,
    .os_errbuf = errbuf,
    .os_errbuflen = errbuflen,
    .os_buf = curbuf,
    .os_win = curwin
  };

  if (direct) {
    // Don't do any extra processing if setting directly.
  }
  // Disallow changing immutable options.
  else if (opt->immutable && !optval_equal(old_value, new_value)) {
    errmsg = e_unsupportedoption;
  }
  // Disallow changing some options from secure mode.
  else if ((secure || sandbox != 0) && (opt->flags & kOptFlagSecure)) {
    errmsg = e_secure;
  }
  // Check for a "normal" directory or file name in some string options.
  else if (new_value.type == kOptValTypeString
           && check_illegal_path_names(*(char **)varp, opt->flags)) {
    errmsg = e_invarg;
  } else if (opt->opt_did_set_cb != NULL) {
    // Invoke the option specific callback function to validate and apply the new value.
    errmsg = opt->opt_did_set_cb(&did_set_cb_args);
    // The 'filetype' and 'syntax' option callback functions may change the os_value_changed field.
    value_changed = did_set_cb_args.os_value_changed;
    // The 'keymap', 'filetype' and 'syntax' option callback functions may change the
    // os_value_checked field.
    value_checked = did_set_cb_args.os_value_checked;
    // The 'isident', 'iskeyword', 'isprint' and 'isfname' options may change the character table.
    // On failure, this needs to be restored.
    restore_chartab = did_set_cb_args.os_restore_chartab;
  }

  // If option is hidden or if an error is detected, restore the previous value and don't do any
  // further processing.
  if (errmsg != NULL) {
    set_option_varp(opt_idx, varp, old_value, true);
    // When resetting some values, need to act on it.
    if (restore_chartab) {
      buf_init_chartab(curbuf, true);
    }

    return errmsg;
  }

  // Re-assign the new value as its value may get freed or modified by the option callback.
  new_value = optval_from_varp(opt_idx, varp);

  if (set_sid != SID_NONE) {
    sctx_T script_ctx;

    if (set_sid == 0) {
      script_ctx = current_sctx;
    } else {
      script_ctx.sc_sid = set_sid;
      script_ctx.sc_seq = 0;
      script_ctx.sc_lnum = 0;
    }
    // Remember where the option was set.
    set_option_sctx(opt_idx, opt_flags, script_ctx);
  }

  optval_free(old_value);

  const bool scope_both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;

  if (scope_both) {
    if (option_is_global_local(opt_idx)) {
      // Global option with local value set to use global value.
      // Free the local value and clear it.
      void *varp_local = get_varp_scope(opt, OPT_LOCAL);
      OptVal local_unset_value = get_option_unset_value(opt_idx);
      set_option_varp(opt_idx, varp_local, optval_copy(local_unset_value), true);
    } else {
      // May set global value for local option.
      void *varp_global = get_varp_scope(opt, OPT_GLOBAL);
      set_option_varp(opt_idx, varp_global, optval_copy(new_value), true);
    }
  }

  // Don't do anything else if setting the option directly.
  if (direct) {
    return errmsg;
  }

  // Trigger the autocommand only after setting the flags.
  if (varp == &curbuf->b_p_syn) {
    do_syntax_autocmd(curbuf, value_changed);
  } else if (varp == &curbuf->b_p_ft) {
    // 'filetype' is set, trigger the FileType autocommand
    // Skip this when called from a modeline
    // Force autocmd when the filetype was changed
    if (!(opt_flags & OPT_MODELINE) || value_changed) {
      do_filetype_autocmd(curbuf, value_changed);
    }
  } else if (varp == &curwin->w_s->b_p_spl) {
    do_spelllang_source(curwin);
  }

  // In case 'ruler' or 'showcmd' or 'columns' or 'ls' changed.
  comp_col();

  if (varp == &p_mouse) {
    setmouse();  // in case 'mouse' changed
  } else if ((varp == &p_flp || varp == &(curbuf->b_p_flp)) && curwin->w_briopt_list) {
    // Changing Formatlistpattern when briopt includes the list setting:
    // redraw
    redraw_all_later(UPD_NOT_VALID);
  } else if (varp == &p_wbr || varp == &(curwin->w_p_wbr)) {
    // add / remove window bars for 'winbar'
    set_winbar(true);
  }

  if (curwin->w_curswant != MAXCOL
      && (opt->flags & (kOptFlagCurswant | kOptFlagRedrAll)) != 0
      && (opt->flags & kOptFlagHLOnly) == 0) {
    curwin->w_set_curswant = true;
  }

  check_redraw(opt->flags);

  if (errmsg == NULL) {
    uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
    opt->flags |= kOptFlagWasSet;

    // When an option is set in the sandbox, from a modeline or in secure mode set the kOptFlagInsecure
    // flag.  Otherwise, if a new value is stored reset the flag.
    if (!value_checked && (secure || sandbox != 0 || (opt_flags & OPT_MODELINE))) {
      *p |= kOptFlagInsecure;
    } else if (value_replaced) {
      *p &= ~(unsigned)kOptFlagInsecure;
    }
  }

  return errmsg;
}

/// Validate the new value for an option.
///
/// @param  opt_idx         Index in options[] table. Must not be kOptInvalid.
/// @param  newval[in,out]  New option value. Might be modified.
static const char *validate_option_value(const OptIndex opt_idx, OptVal *newval, int opt_flags,
                                         char *errbuf, size_t errbuflen)
{
  const char *errmsg = NULL;
  vimoption_T *opt = &options[opt_idx];

  // Always allow unsetting local value of global-local option.
  if (option_is_global_local(opt_idx) && (opt_flags & OPT_LOCAL)
      && optval_equal(*newval, get_option_unset_value(opt_idx))) {
    return NULL;
  }

  if (newval->type == kOptValTypeNil) {
    // Don't try to unset local value if scope is global.
    // TODO(famiu): Change this to forbid changing all non-local scopes when the API scope bug is
    // fixed.
    if (opt_flags == OPT_GLOBAL) {
      errmsg = _("Cannot unset global option value");
    } else {
      *newval = optval_copy(get_option_unset_value(opt_idx));
    }
  } else if (!option_has_type(opt_idx, newval->type)) {
    char *rep = optval_to_cstr(*newval);
    char *valid_types = option_get_valid_types(opt_idx);
    snprintf(errbuf, IOSIZE, _("Invalid value for option '%s': expected %s, got %s %s"),
             opt->fullname, valid_types, optval_type_get_name(newval->type), rep);
    xfree(rep);
    xfree(valid_types);
    errmsg = errbuf;
  } else if (newval->type == kOptValTypeNumber) {
    // Validate and bound check num option values.
    errmsg = validate_num_option(opt_idx, &newval->data.number, errbuf, errbuflen);
  }

  return errmsg;
}

/// Set the value of an option using an OptVal.
///
/// @param       opt_idx         Index in options[] table. Must not be kOptInvalid.
/// @param       value           New option value. Might get freed.
/// @param       opt_flags       Option flags.
/// @param       set_sid         Script ID. Special values:
///                                0: Use current script ID.
///                                SID_NONE: Don't set script ID.
/// @param       direct          Don't process side-effects.
/// @param       value_replaced  Value was replaced completely.
/// @param[out]  errbuf          Buffer for error message.
/// @param       errbuflen       Length of error buffer.
///
/// @return  NULL on success, an untranslated error message on error.
static const char *set_option(const OptIndex opt_idx, OptVal value, int opt_flags, scid_T set_sid,
                              const bool direct, const bool value_replaced, char *errbuf,
                              size_t errbuflen)
{
  assert(opt_idx != kOptInvalid);

  const char *errmsg = NULL;

  if (!direct) {
    errmsg = validate_option_value(opt_idx, &value, opt_flags, errbuf, errbuflen);

    if (errmsg != NULL) {
      optval_free(value);
      return errmsg;
    }
  }

  vimoption_T *opt = &options[opt_idx];
  const bool scope_local = opt_flags & OPT_LOCAL;
  const bool scope_global = opt_flags & OPT_GLOBAL;
  const bool scope_both = !scope_local && !scope_global;
  // Whether local value of global-local option is unset.
  // NOTE: When this is true, it also implies that the option is global-local.
  const bool is_opt_local_unset = is_option_local_value_unset(opt_idx);

  // When using ":set opt=val" for a global option with a local value the local value will be reset,
  // use the global value in that case.
  void *varp
    = scope_both && option_is_global_local(opt_idx) ? opt->var : get_varp_scope(opt, opt_flags);
  void *varp_local = get_varp_scope(opt, OPT_LOCAL);
  void *varp_global = get_varp_scope(opt, OPT_GLOBAL);

  OptVal old_value = optval_from_varp(opt_idx, varp);
  OptVal old_global_value = optval_from_varp(opt_idx, varp_global);
  // If local value of global-local option is unset, use global value as local value.
  OptVal old_local_value = is_opt_local_unset
                           ? old_global_value
                           : optval_from_varp(opt_idx, varp_local);
  // Value that's actually being used.
  // For local scope of a global-local option, it's equal to the global value if the local value is
  // unset. In every other case, it is the same as old_value.
  // This value is used instead of old_value when triggering the OptionSet autocommand.
  OptVal used_old_value = (scope_local && is_opt_local_unset)
                          ? optval_from_varp(opt_idx, get_varp(opt))
                          : old_value;

  // Save the old values and the new value in case they get changed.
  OptVal saved_used_value = optval_copy(used_old_value);
  OptVal saved_old_global_value = optval_copy(old_global_value);
  OptVal saved_old_local_value = optval_copy(old_local_value);
  // New value (and varp) may become invalid if the buffer is closed by autocommands.
  OptVal saved_new_value = optval_copy(value);

  uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
  const int secure_saved = secure;

  // When an option is set in the sandbox, from a modeline or in secure mode, then deal with side
  // effects in secure mode. Also when the value was set with the kOptFlagInsecure flag and is not
  // completely replaced.
  if ((opt_flags & OPT_MODELINE) || sandbox != 0 || (!value_replaced && (*p & kOptFlagInsecure))) {
    secure = 1;
  }

  // Set option through its variable pointer.
  set_option_varp(opt_idx, varp, value, false);
  // Process any side effects.
  errmsg = did_set_option(opt_idx, varp, old_value, value, opt_flags, set_sid, direct,
                          value_replaced, errbuf, errbuflen);

  secure = secure_saved;

  if (errmsg == NULL && !direct) {
    if (!starting) {
      apply_optionset_autocmd(opt_idx, opt_flags, saved_used_value, saved_old_global_value,
                              saved_old_local_value, saved_new_value, errmsg);
    }
    if (opt->flags & kOptFlagUIOption) {
      ui_call_option_set(cstr_as_string(opt->fullname), optval_as_object(saved_new_value));
    }
  }

  // Free copied values as they are not needed anymore
  optval_free(saved_used_value);
  optval_free(saved_old_local_value);
  optval_free(saved_old_global_value);
  optval_free(saved_new_value);

  return errmsg;
}

/// Set option value directly, without processing any side effects.
///
/// @param  opt_idx    Option index in options[] table.
/// @param  value      Option value.
/// @param  opt_flags  Option flags.
/// @param  set_sid    Script ID. Special values:
///                      0: Use current script ID.
///                      SID_NONE: Don't set script ID.
void set_option_direct(OptIndex opt_idx, OptVal value, int opt_flags, scid_T set_sid)
{
  static char errbuf[IOSIZE];

  if (is_option_hidden(opt_idx)) {
    return;
  }

  const char *errmsg = set_option(opt_idx, optval_copy(value), opt_flags, set_sid, true, true,
                                  errbuf, sizeof(errbuf));
  assert(errmsg == NULL);
  (void)errmsg;  // ignore unused warning
}

/// Set option value directly for buffer / window, without processing any side effects.
///
/// @param      opt_idx    Option index in options[] table.
/// @param      value      Option value.
/// @param      opt_flags  Option flags.
/// @param      set_sid    Script ID. Special values:
///                          0: Use current script ID.
///                          SID_NONE: Don't set script ID.
/// @param      req_scope  Requested option scope. See OptScope in option.h.
/// @param[in]  from       Target buffer/window.
void set_option_direct_for(OptIndex opt_idx, OptVal value, int opt_flags, scid_T set_sid,
                           OptScope req_scope, void *const from)
{
  buf_T *save_curbuf = curbuf;
  win_T *save_curwin = curwin;

  // Don't use switch_option_context(), as that calls aucmd_prepbuf(), which may have unintended
  // side-effects when setting an option directly. Just change the values of curbuf and curwin if
  // needed, no need to properly switch the window / buffer.
  switch (req_scope) {
  case kOptScopeGlobal:
    break;
  case kOptScopeWin:
    curwin = (win_T *)from;
    curbuf = curwin->w_buffer;
    break;
  case kOptScopeBuf:
    curbuf = (buf_T *)from;
    break;
  }

  set_option_direct(opt_idx, value, opt_flags, set_sid);

  curwin = save_curwin;
  curbuf = save_curbuf;
}

/// Set the value of an option.
///
/// @param      opt_idx    Index in options[] table. Must not be kOptInvalid.
/// @param[in]  value      Option value. If NIL_OPTVAL, the option value is cleared.
/// @param[in]  opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///
/// @return  NULL on success, an untranslated error message on error.
const char *set_option_value(const OptIndex opt_idx, const OptVal value, int opt_flags)
{
  assert(opt_idx != kOptInvalid);

  static char errbuf[IOSIZE];
  uint32_t flags = options[opt_idx].flags;

  // Disallow changing some options in the sandbox
  if (sandbox > 0 && (flags & kOptFlagSecure)) {
    return _(e_sandbox);
  }

  return set_option(opt_idx, optval_copy(value), opt_flags, 0, false, true, errbuf, sizeof(errbuf));
}

/// Unset the local value of a global-local option.
///
/// @param      opt_idx    Index in options[] table. Must not be kOptInvalid.
///
/// @return  NULL on success, an untranslated error message on error.
static inline const char *unset_option_local_value(const OptIndex opt_idx)
{
  assert(option_is_global_local(opt_idx));
  return set_option_value(opt_idx, get_option_unset_value(opt_idx), OPT_LOCAL);
}

/// Set the value of an option. Supports TTY options, unlike set_option_value().
///
/// @param      name       Option name. Used for error messages and for setting TTY options.
/// @param      opt_idx    Option indx in options[] table. If kOptInvalid, `name` is used to
///                        check if the option is a TTY option, and an error is shown if it's not.
///                        If the option is a TTY option, the function fails silently.
/// @param      value      Option value. If NIL_OPTVAL, the option value is cleared.
/// @param[in]  opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///
/// @return  NULL on success, an untranslated error message on error.
const char *set_option_value_handle_tty(const char *name, OptIndex opt_idx, const OptVal value,
                                        int opt_flags)
  FUNC_ATTR_NONNULL_ARG(1)
{
  static char errbuf[IOSIZE];

  if (opt_idx == kOptInvalid) {
    if (is_tty_option(name)) {
      return NULL;  // Fail silently; many old vimrcs set t_xx options.
    }

    snprintf(errbuf, sizeof(errbuf), _(e_unknown_option2), name);
    return errbuf;
  }

  return set_option_value(opt_idx, value, opt_flags);
}

/// Call set_option_value() and when an error is returned, report it.
///
/// @param  opt_idx    Option index in options[] table.
/// @param  value      Option value. If NIL_OPTVAL, the option value is cleared.
/// @param  opt_flags  OPT_LOCAL or 0 (both)
void set_option_value_give_err(const OptIndex opt_idx, OptVal value, int opt_flags)
{
  const char *errmsg = set_option_value(opt_idx, value, opt_flags);

  if (errmsg != NULL) {
    emsg(_(errmsg));
  }
}

/// Switch current context to get/set option value for window/buffer.
///
/// @param[out]  ctx        Current context. switchwin_T for window and aco_save_T for buffer.
/// @param       req_scope  Requested option scope. See OptScope in option.h.
/// @param[in]   from       Target buffer/window.
/// @param[out]  err        Error message, if any.
///
/// @return  true if context was switched, false otherwise.
static bool switch_option_context(void *const ctx, OptScope req_scope, void *const from, Error *err)
{
  switch (req_scope) {
  case kOptScopeGlobal:
    return false;
  case kOptScopeWin: {
    win_T *const win = (win_T *)from;
    switchwin_T *const switchwin = (switchwin_T *)ctx;

    if (win == curwin) {
      return false;
    }

    if (switch_win_noblock(switchwin, win, win_find_tabpage(win), true)
        == FAIL) {
      restore_win_noblock(switchwin, true);

      if (try_end(err)) {
        return false;
      }
      api_set_error(err, kErrorTypeException, "Problem while switching windows");
      return false;
    }
    return true;
  }
  case kOptScopeBuf: {
    buf_T *const buf = (buf_T *)from;
    aco_save_T *const aco = (aco_save_T *)ctx;

    if (buf == curbuf) {
      return false;
    }
    aucmd_prepbuf(aco, buf);
    return true;
  }
  }
  UNREACHABLE;
}

/// Restore context after getting/setting option for window/buffer. See switch_option_context() for
/// params.
static void restore_option_context(void *const ctx, OptScope req_scope)
{
  switch (req_scope) {
  case kOptScopeGlobal:
    break;
  case kOptScopeWin:
    restore_win_noblock((switchwin_T *)ctx, true);
    break;
  case kOptScopeBuf:
    aucmd_restbuf((aco_save_T *)ctx);
    break;
  }
}

/// Get option value for buffer / window.
///
/// @param       opt_idx    Option index in options[] table.
/// @param[out]  flagsp     Set to the option flags (see OptFlags) (if not NULL).
/// @param[in]   scope      Option scope (can be OPT_LOCAL, OPT_GLOBAL or a combination).
/// @param[out]  hidden     Whether option is hidden.
/// @param       req_scope  Requested option scope. See OptScope in option.h.
/// @param[in]   from       Target buffer/window.
/// @param[out]  err        Error message, if any.
///
/// @return  Option value. Must be freed by caller.
OptVal get_option_value_for(OptIndex opt_idx, int scope, const OptScope req_scope, void *const from,
                            Error *err)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = req_scope == kOptScopeWin ? (void *)&switchwin
                                        : (req_scope == kOptScopeBuf ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, req_scope, from, err);
  if (ERROR_SET(err)) {
    return NIL_OPTVAL;
  }

  OptVal retv = get_option_value(opt_idx, scope);

  if (switched) {
    restore_option_context(ctx, req_scope);
  }

  return retv;
}

/// Set option value for buffer / window.
///
/// @param       name        Option name.
/// @param       opt_idx     Option index in options[] table.
/// @param[in]   value       Option value.
/// @param[in]   opt_flags   Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
/// @param       req_scope   Requested option scope. See OptScope in option.h.
/// @param[in]   from        Target buffer/window.
/// @param[out]  err         Error message, if any.
void set_option_value_for(const char *name, OptIndex opt_idx, OptVal value, const int opt_flags,
                          const OptScope req_scope, void *const from, Error *err)
  FUNC_ATTR_NONNULL_ARG(1)
{
  switchwin_T switchwin;
  aco_save_T aco;
  void *ctx = req_scope == kOptScopeWin ? (void *)&switchwin
                                        : (req_scope == kOptScopeBuf ? (void *)&aco : NULL);

  bool switched = switch_option_context(ctx, req_scope, from, err);
  if (ERROR_SET(err)) {
    return;
  }

  const char *const errmsg = set_option_value_handle_tty(name, opt_idx, value, opt_flags);
  if (errmsg) {
    api_set_error(err, kErrorTypeException, "%s", errmsg);
  }

  if (switched) {
    restore_option_context(ctx, req_scope);
  }
}

/// if 'all' == false: show changed options
/// if 'all' == true: show all normal options
///
/// @param opt_flags  OPT_LOCAL and/or OPT_GLOBAL
static void showoptions(bool all, int opt_flags)
{
#define INC 20
#define GAP 3

  vimoption_T **items = xmalloc(sizeof(vimoption_T *) * OPTION_COUNT);

  msg_ext_set_kind("list_cmd");
  // Highlight title
  if (opt_flags & OPT_GLOBAL) {
    msg_puts_title(_("\n--- Global option values ---"));
  } else if (opt_flags & OPT_LOCAL) {
    msg_puts_title(_("\n--- Local option values ---"));
  } else {
    msg_puts_title(_("\n--- Options ---"));
  }

  // Do the loop two times:
  // 1. display the short items
  // 2. display the long items (only strings and numbers)
  // When "opt_flags" has OPT_ONECOLUMN do everything in run 2.
  for (int run = 1; run <= 2 && !got_int; run++) {
    // collect the items in items[]
    int item_count = 0;
    vimoption_T *opt;
    for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
      opt = &options[opt_idx];
      // apply :filter /pat/
      if (message_filtered(opt->fullname)) {
        continue;
      }

      void *varp = NULL;
      if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) != 0) {
        if (!option_is_global_only(opt_idx)) {
          varp = get_varp_scope(opt, opt_flags);
        }
      } else {
        varp = get_varp(opt);
      }
      if (varp != NULL && (all || !optval_default(opt_idx, varp))) {
        int len;
        if (opt_flags & OPT_ONECOLUMN) {
          len = Columns;
        } else if (option_has_type(opt_idx, kOptValTypeBoolean)) {
          len = 1;                      // a toggle option fits always
        } else {
          option_value2string(opt, opt_flags);
          len = (int)strlen(opt->fullname) + vim_strsize(NameBuff) + 1;
        }
        if ((len <= INC - GAP && run == 1)
            || (len > INC - GAP && run == 2)) {
          items[item_count++] = opt;
        }
      }
    }

    int rows;

    // display the items
    if (run == 1) {
      assert(Columns <= INT_MAX - GAP
             && Columns + GAP >= INT_MIN + 3
             && (Columns + GAP - 3) / INC >= INT_MIN
             && (Columns + GAP - 3) / INC <= INT_MAX);
      int cols = (Columns + GAP - 3) / INC;
      if (cols == 0) {
        cols = 1;
      }
      rows = (item_count + cols - 1) / cols;
    } else {    // run == 2
      rows = item_count;
    }
    for (int row = 0; row < rows && !got_int; row++) {
      msg_putchar('\n');                        // go to next line
      if (got_int) {                            // 'q' typed in more
        break;
      }
      int col = 0;
      for (int i = row; i < item_count; i += rows) {
        msg_col = col;                          // make columns
        showoneopt(items[i], opt_flags);
        col += INC;
      }
      os_breakcheck();
    }
  }
  xfree(items);
}

/// Return true if option "p" has its default value.
static int optval_default(OptIndex opt_idx, void *varp)
{
  vimoption_T *opt = &options[opt_idx];

  // Hidden options always use their default value.
  if (is_option_hidden(opt_idx)) {
    return true;
  }

  OptVal current_val = optval_from_varp(opt_idx, varp);
  OptVal default_val = opt->def_val;

  return optval_equal(current_val, default_val);
}

/// Send update to UIs with values of UI relevant options
void ui_refresh_options(void)
{
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    uint32_t flags = options[opt_idx].flags;
    if (!(flags & kOptFlagUIOption)) {
      continue;
    }
    String name = cstr_as_string(options[opt_idx].fullname);
    Object value = optval_as_object(optval_from_varp(opt_idx, options[opt_idx].var));
    ui_call_option_set(name, value);
  }
  if (p_mouse != NULL) {
    setmouse();
  }
}

/// showoneopt: show the value of one option
/// must not be called with a hidden option!
///
/// @param opt_flags  OPT_LOCAL or OPT_GLOBAL
static void showoneopt(vimoption_T *opt, int opt_flags)
{
  int save_silent = silent_mode;

  silent_mode = false;
  info_message = true;          // use stdout, not stderr

  OptIndex opt_idx = get_opt_idx(opt);
  void *varp = get_varp_scope(opt, opt_flags);

  // for 'modified' we also need to check if 'ff' or 'fenc' changed.
  if (option_has_type(opt_idx, kOptValTypeBoolean)
      && ((int *)varp == &curbuf->b_changed ? !curbufIsChanged() : !*(int *)varp)) {
    msg_puts("no");
  } else if (option_has_type(opt_idx, kOptValTypeBoolean) && *(int *)varp < 0) {
    msg_puts("--");
  } else {
    msg_puts("  ");
  }
  msg_puts(opt->fullname);
  if (!(option_has_type(opt_idx, kOptValTypeBoolean))) {
    msg_putchar('=');
    // put value string in NameBuff
    option_value2string(opt, opt_flags);
    msg_outtrans(NameBuff, 0, false);
  }

  silent_mode = save_silent;
  info_message = false;
}

/// Write modified options as ":set" commands to a file.
///
/// There are three values for "opt_flags":
/// OPT_GLOBAL:         Write global option values and fresh values of
///             buffer-local options (used for start of a session
///             file).
/// OPT_GLOBAL + OPT_LOCAL: Idem, add fresh values of window-local options for
///             curwin (used for a vimrc file).
/// OPT_LOCAL:          Write buffer-local option values for curbuf, fresh
///             and local values for window-local options of
///             curwin.  Local values are also written when at the
///             default value, because a modeline or autocommand
///             may have set them when doing ":edit file" and the
///             user has set them back at the default or fresh
///             value.
///             When "local_only" is true, don't write fresh
///             values, only local values (for ":mkview").
/// (fresh value = value used for a new buffer or window for a local option).
///
/// Return FAIL on error, OK otherwise.
int makeset(FILE *fd, int opt_flags, int local_only)
{
  // Some options are never written:
  // - Options that don't have a default (terminal name, columns, lines).
  // - Terminal options.
  // - Hidden options.
  //
  // Do the loop over "options[]" twice: once for options with the
  // kOptFlagPriMkrc flag and once without.
  for (int pri = 1; pri >= 0; pri--) {
    vimoption_T *opt;
    for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
      opt = &options[opt_idx];

      if (!(opt->flags & kOptFlagNoMkrc)
          && ((pri == 1) == ((opt->flags & kOptFlagPriMkrc) != 0))) {
        // skip global option when only doing locals
        if (option_is_global_only(opt_idx) && !(opt_flags & OPT_GLOBAL)) {
          continue;
        }

        // Do not store options like 'bufhidden' and 'syntax' in a vimrc
        // file, they are always buffer-specific.
        if ((opt_flags & OPT_GLOBAL) && (opt->flags & kOptFlagNoGlob)) {
          continue;
        }

        void *varp = get_varp_scope(opt, opt_flags);  // currently used value
        // Hidden options are never written.
        if (!varp) {
          continue;
        }
        // Global values are only written when not at the default value.
        if ((opt_flags & OPT_GLOBAL) && optval_default(opt_idx, varp)) {
          continue;
        }

        if ((opt_flags & OPT_SKIPRTP)
            && (opt->var == &p_rtp || opt->var == &p_pp)) {
          continue;
        }

        int round = 2;
        void *varp_local = NULL;  // fresh value
        if (option_is_window_local(opt_idx)) {
          // skip window-local option when only doing globals
          if (!(opt_flags & OPT_LOCAL)) {
            continue;
          }
          // When fresh value of window-local option is not at the
          // default, need to write it too.
          if (!(opt_flags & OPT_GLOBAL) && !local_only) {
            void *varp_fresh = get_varp_scope(opt, OPT_GLOBAL);  // local value
            if (!optval_default(opt_idx, varp_fresh)) {
              round = 1;
              varp_local = varp;
              varp = varp_fresh;
            }
          }
        }

        // Round 1: fresh value for window-local options.
        // Round 2: other values
        for (; round <= 2; varp = varp_local, round++) {
          char *cmd;
          if (round == 1 || (opt_flags & OPT_GLOBAL)) {
            cmd = "set";
          } else {
            cmd = "setlocal";
          }

          bool do_endif = false;
          // Don't set 'syntax' and 'filetype' again if the value is already right, avoids reloading
          // the syntax file.
          if (opt_idx == kOptSyntax || opt_idx == kOptFiletype) {
            if (fprintf(fd, "if &%s != '%s'", opt->fullname,
                        *(char **)(varp)) < 0
                || put_eol(fd) < 0) {
              return FAIL;
            }
            do_endif = true;
          }
          if (put_set(fd, cmd, opt_idx, varp) == FAIL) {
            return FAIL;
          }
          if (do_endif) {
            if (put_line(fd, "endif") == FAIL) {
              return FAIL;
            }
          }
        }
      }
    }
  }
  return OK;
}

/// Generate set commands for the local fold options only.  Used when
/// 'sessionoptions' or 'viewoptions' contains "folds" but not "options".
int makefoldset(FILE *fd)
{
  if (put_set(fd, "setlocal", kOptFoldmethod, &curwin->w_p_fdm) == FAIL
      || put_set(fd, "setlocal", kOptFoldexpr, &curwin->w_p_fde) == FAIL
      || put_set(fd, "setlocal", kOptFoldmarker, &curwin->w_p_fmr) == FAIL
      || put_set(fd, "setlocal", kOptFoldignore, &curwin->w_p_fdi) == FAIL
      || put_set(fd, "setlocal", kOptFoldlevel, &curwin->w_p_fdl) == FAIL
      || put_set(fd, "setlocal", kOptFoldminlines, &curwin->w_p_fml) == FAIL
      || put_set(fd, "setlocal", kOptFoldnestmax, &curwin->w_p_fdn) == FAIL
      || put_set(fd, "setlocal", kOptFoldenable, &curwin->w_p_fen) == FAIL) {
    return FAIL;
  }

  return OK;
}

/// Print the ":set" command to set a single option to file.
///
/// @param  fd       File descriptor.
/// @param  cmd      Command name.
/// @param  opt_idx  Option index in options[] table.
/// @param  varp     Pointer to option variable.
///
/// @return FAIL on error, OK otherwise.
static int put_set(FILE *fd, char *cmd, OptIndex opt_idx, void *varp)
{
  OptVal value = optval_from_varp(opt_idx, varp);
  vimoption_T *opt = &options[opt_idx];
  char *name = opt->fullname;
  uint64_t flags = opt->flags;

  if (option_is_global_local(opt_idx) && varp != opt->var
      && optval_equal(value, get_option_unset_value(opt_idx))) {
    // Processing unset local value of global-local option. Do nothing.
    return OK;
  }

  switch (value.type) {
  case kOptValTypeNil:
    abort();
  case kOptValTypeBoolean: {
    assert(value.data.boolean != kNone);
    bool value_bool = TRISTATE_TO_BOOL(value.data.boolean, false);

    if (fprintf(fd, "%s %s%s", cmd, value_bool ? "" : "no", name) < 0) {
      return FAIL;
    }
    break;
  }
  case kOptValTypeNumber: {
    if (fprintf(fd, "%s %s=", cmd, name) < 0) {
      return FAIL;
    }

    OptInt value_num = value.data.number;

    OptInt wc;
    if (wc_use_keyname(varp, &wc)) {
      // print 'wildchar' and 'wildcharm' as a key name
      if (fputs(get_special_key_name((int)wc, 0), fd) < 0) {
        return FAIL;
      }
    } else if (fprintf(fd, "%" PRId64, value_num) < 0) {
      return FAIL;
    }
    break;
  }
  case kOptValTypeString: {
    if (fprintf(fd, "%s %s=", cmd, name) < 0) {
      return FAIL;
    }

    char *value_str = value.data.string.data;
    char *buf = NULL;
    char *part = NULL;

    if (value_str != NULL) {
      if ((flags & kOptFlagExpand) != 0) {
        size_t size = (size_t)strlen(value_str) + 1;

        // replace home directory in the whole option value into "buf"
        buf = xmalloc(size);
        home_replace(NULL, value_str, buf, size, false);

        // If the option value is longer than MAXPATHL, we need to append
        // each comma separated part of the option separately, so that it
        // can be expanded when read back.
        if (size >= MAXPATHL && (flags & kOptFlagComma) != 0
            && vim_strchr(value_str, ',') != NULL) {
          part = xmalloc(size);

          // write line break to clear the option, e.g. ':set rtp='
          if (put_eol(fd) == FAIL) {
            goto fail;
          }
          char *p = buf;
          while (*p != NUL) {
            // for each comma separated option part, append value to
            // the option, :set rtp+=value
            if (fprintf(fd, "%s %s+=", cmd, name) < 0) {
              goto fail;
            }
            copy_option_part(&p, part, size, ",");
            if (put_escstr(fd, part, 2) == FAIL || put_eol(fd) == FAIL) {
              goto fail;
            }
          }
          xfree(buf);
          xfree(part);
          return OK;
        }
        if (put_escstr(fd, buf, 2) == FAIL) {
          xfree(buf);
          return FAIL;
        }
        xfree(buf);
      } else if (put_escstr(fd, value_str, 2) == FAIL) {
        return FAIL;
      }
    }
    break;
  fail:
    xfree(buf);
    xfree(part);
    return FAIL;
  }
  }

  if (put_eol(fd) < 0) {
    return FAIL;
  }
  return OK;
}

void *get_varp_scope_from(vimoption_T *p, int scope, buf_T *buf, win_T *win)
{
  OptIndex opt_idx = get_opt_idx(p);

  if ((scope & OPT_GLOBAL) && !option_is_global_only(opt_idx)) {
    if (option_is_window_local(opt_idx)) {
      return GLOBAL_WO(get_varp_from(p, buf, win));
    }
    return p->var;
  }

  if ((scope & OPT_LOCAL) && option_is_global_local(opt_idx)) {
    switch (opt_idx) {
    case kOptFormatprg:
      return &(buf->b_p_fp);
    case kOptFindfunc:
      return &(buf->b_p_ffu);
    case kOptErrorformat:
      return &(buf->b_p_efm);
    case kOptGrepprg:
      return &(buf->b_p_gp);
    case kOptMakeprg:
      return &(buf->b_p_mp);
    case kOptEqualprg:
      return &(buf->b_p_ep);
    case kOptKeywordprg:
      return &(buf->b_p_kp);
    case kOptPath:
      return &(buf->b_p_path);
    case kOptAutoread:
      return &(buf->b_p_ar);
    case kOptTags:
      return &(buf->b_p_tags);
    case kOptTagcase:
      return &(buf->b_p_tc);
    case kOptSidescrolloff:
      return &(win->w_p_siso);
    case kOptScrolloff:
      return &(win->w_p_so);
    case kOptDefine:
      return &(buf->b_p_def);
    case kOptInclude:
      return &(buf->b_p_inc);
    case kOptCompleteopt:
      return &(buf->b_p_cot);
    case kOptDictionary:
      return &(buf->b_p_dict);
    case kOptThesaurus:
      return &(buf->b_p_tsr);
    case kOptThesaurusfunc:
      return &(buf->b_p_tsrfu);
    case kOptTagfunc:
      return &(buf->b_p_tfu);
    case kOptShowbreak:
      return &(win->w_p_sbr);
    case kOptStatusline:
      return &(win->w_p_stl);
    case kOptWinbar:
      return &(win->w_p_wbr);
    case kOptUndolevels:
      return &(buf->b_p_ul);
    case kOptLispwords:
      return &(buf->b_p_lw);
    case kOptBackupcopy:
      return &(buf->b_p_bkc);
    case kOptMakeencoding:
      return &(buf->b_p_menc);
    case kOptFillchars:
      return &(win->w_p_fcs);
    case kOptListchars:
      return &(win->w_p_lcs);
    case kOptVirtualedit:
      return &(win->w_p_ve);
    default:
      abort();
    }
  }
  return get_varp_from(p, buf, win);
}

/// Get pointer to option variable, depending on local or global scope.
///
/// @param scope  can be OPT_LOCAL, OPT_GLOBAL or a combination.
void *get_varp_scope(vimoption_T *p, int scope)
{
  return get_varp_scope_from(p, scope, curbuf, curwin);
}

/// Get pointer to option variable at 'opt_idx', depending on local or global
/// scope.
void *get_option_varp_scope_from(OptIndex opt_idx, int scope, buf_T *buf, win_T *win)
{
  return get_varp_scope_from(&(options[opt_idx]), scope, buf, win);
}

void *get_varp_from(vimoption_T *p, buf_T *buf, win_T *win)
{
  OptIndex opt_idx = get_opt_idx(p);

  // Hidden options and global-only options always use the same var pointer
  if (is_option_hidden(opt_idx) || option_is_global_only(opt_idx)) {
    return p->var;
  }

  switch (opt_idx) {
  // global option with local value: use local value if it's been set
  case kOptEqualprg:
    return *buf->b_p_ep != NUL ? &buf->b_p_ep : p->var;
  case kOptKeywordprg:
    return *buf->b_p_kp != NUL ? &buf->b_p_kp : p->var;
  case kOptPath:
    return *buf->b_p_path != NUL ? &(buf->b_p_path) : p->var;
  case kOptAutoread:
    return buf->b_p_ar >= 0 ? &(buf->b_p_ar) : p->var;
  case kOptTags:
    return *buf->b_p_tags != NUL ? &(buf->b_p_tags) : p->var;
  case kOptTagcase:
    return *buf->b_p_tc != NUL ? &(buf->b_p_tc) : p->var;
  case kOptSidescrolloff:
    return win->w_p_siso >= 0 ? &(win->w_p_siso) : p->var;
  case kOptScrolloff:
    return win->w_p_so >= 0 ? &(win->w_p_so) : p->var;
  case kOptBackupcopy:
    return *buf->b_p_bkc != NUL ? &(buf->b_p_bkc) : p->var;
  case kOptDefine:
    return *buf->b_p_def != NUL ? &(buf->b_p_def) : p->var;
  case kOptInclude:
    return *buf->b_p_inc != NUL ? &(buf->b_p_inc) : p->var;
  case kOptCompleteopt:
    return *buf->b_p_cot != NUL ? &(buf->b_p_cot) : p->var;
  case kOptDictionary:
    return *buf->b_p_dict != NUL ? &(buf->b_p_dict) : p->var;
  case kOptThesaurus:
    return *buf->b_p_tsr != NUL ? &(buf->b_p_tsr) : p->var;
  case kOptThesaurusfunc:
    return *buf->b_p_tsrfu != NUL ? &(buf->b_p_tsrfu) : p->var;
  case kOptFormatprg:
    return *buf->b_p_fp != NUL ? &(buf->b_p_fp) : p->var;
  case kOptFindfunc:
    return *buf->b_p_ffu != NUL ? &(buf->b_p_ffu) : p->var;
  case kOptErrorformat:
    return *buf->b_p_efm != NUL ? &(buf->b_p_efm) : p->var;
  case kOptGrepprg:
    return *buf->b_p_gp != NUL ? &(buf->b_p_gp) : p->var;
  case kOptMakeprg:
    return *buf->b_p_mp != NUL ? &(buf->b_p_mp) : p->var;
  case kOptShowbreak:
    return *win->w_p_sbr != NUL ? &(win->w_p_sbr) : p->var;
  case kOptStatusline:
    return *win->w_p_stl != NUL ? &(win->w_p_stl) : p->var;
  case kOptWinbar:
    return *win->w_p_wbr != NUL ? &(win->w_p_wbr) : p->var;
  case kOptUndolevels:
    return buf->b_p_ul != NO_LOCAL_UNDOLEVEL ? &(buf->b_p_ul) : p->var;
  case kOptLispwords:
    return *buf->b_p_lw != NUL ? &(buf->b_p_lw) : p->var;
  case kOptMakeencoding:
    return *buf->b_p_menc != NUL ? &(buf->b_p_menc) : p->var;
  case kOptFillchars:
    return *win->w_p_fcs != NUL ? &(win->w_p_fcs) : p->var;
  case kOptListchars:
    return *win->w_p_lcs != NUL ? &(win->w_p_lcs) : p->var;
  case kOptVirtualedit:
    return *win->w_p_ve != NUL ? &win->w_p_ve : p->var;

  case kOptArabic:
    return &(win->w_p_arab);
  case kOptList:
    return &(win->w_p_list);
  case kOptSpell:
    return &(win->w_p_spell);
  case kOptCursorcolumn:
    return &(win->w_p_cuc);
  case kOptCursorline:
    return &(win->w_p_cul);
  case kOptCursorlineopt:
    return &(win->w_p_culopt);
  case kOptColorcolumn:
    return &(win->w_p_cc);
  case kOptDiff:
    return &(win->w_p_diff);
  case kOptFoldcolumn:
    return &(win->w_p_fdc);
  case kOptFoldenable:
    return &(win->w_p_fen);
  case kOptFoldignore:
    return &(win->w_p_fdi);
  case kOptFoldlevel:
    return &(win->w_p_fdl);
  case kOptFoldmethod:
    return &(win->w_p_fdm);
  case kOptFoldminlines:
    return &(win->w_p_fml);
  case kOptFoldnestmax:
    return &(win->w_p_fdn);
  case kOptFoldexpr:
    return &(win->w_p_fde);
  case kOptFoldtext:
    return &(win->w_p_fdt);
  case kOptFoldmarker:
    return &(win->w_p_fmr);
  case kOptNumber:
    return &(win->w_p_nu);
  case kOptRelativenumber:
    return &(win->w_p_rnu);
  case kOptNumberwidth:
    return &(win->w_p_nuw);
  case kOptWinfixbuf:
    return &(win->w_p_wfb);
  case kOptWinfixheight:
    return &(win->w_p_wfh);
  case kOptWinfixwidth:
    return &(win->w_p_wfw);
  case kOptPreviewwindow:
    return &(win->w_p_pvw);
  case kOptRightleft:
    return &(win->w_p_rl);
  case kOptRightleftcmd:
    return &(win->w_p_rlc);
  case kOptScroll:
    return &(win->w_p_scr);
  case kOptSmoothscroll:
    return &(win->w_p_sms);
  case kOptWrap:
    return &(win->w_p_wrap);
  case kOptLinebreak:
    return &(win->w_p_lbr);
  case kOptBreakindent:
    return &(win->w_p_bri);
  case kOptBreakindentopt:
    return &(win->w_p_briopt);
  case kOptScrollbind:
    return &(win->w_p_scb);
  case kOptCursorbind:
    return &(win->w_p_crb);
  case kOptConcealcursor:
    return &(win->w_p_cocu);
  case kOptConceallevel:
    return &(win->w_p_cole);

  case kOptAutoindent:
    return &(buf->b_p_ai);
  case kOptBinary:
    return &(buf->b_p_bin);
  case kOptBomb:
    return &(buf->b_p_bomb);
  case kOptBufhidden:
    return &(buf->b_p_bh);
  case kOptBuftype:
    return &(buf->b_p_bt);
  case kOptBuflisted:
    return &(buf->b_p_bl);
  case kOptChannel:
    return &(buf->b_p_channel);
  case kOptCopyindent:
    return &(buf->b_p_ci);
  case kOptCindent:
    return &(buf->b_p_cin);
  case kOptCinkeys:
    return &(buf->b_p_cink);
  case kOptCinoptions:
    return &(buf->b_p_cino);
  case kOptCinscopedecls:
    return &(buf->b_p_cinsd);
  case kOptCinwords:
    return &(buf->b_p_cinw);
  case kOptComments:
    return &(buf->b_p_com);
  case kOptCommentstring:
    return &(buf->b_p_cms);
  case kOptComplete:
    return &(buf->b_p_cpt);
#ifdef BACKSLASH_IN_FILENAME
  case kOptCompleteslash:
    return &(buf->b_p_csl);
#endif
  case kOptCompletefunc:
    return &(buf->b_p_cfu);
  case kOptOmnifunc:
    return &(buf->b_p_ofu);
  case kOptEndoffile:
    return &(buf->b_p_eof);
  case kOptEndofline:
    return &(buf->b_p_eol);
  case kOptFixendofline:
    return &(buf->b_p_fixeol);
  case kOptExpandtab:
    return &(buf->b_p_et);
  case kOptFileencoding:
    return &(buf->b_p_fenc);
  case kOptFileformat:
    return &(buf->b_p_ff);
  case kOptFiletype:
    return &(buf->b_p_ft);
  case kOptFormatoptions:
    return &(buf->b_p_fo);
  case kOptFormatlistpat:
    return &(buf->b_p_flp);
  case kOptIminsert:
    return &(buf->b_p_iminsert);
  case kOptImsearch:
    return &(buf->b_p_imsearch);
  case kOptInfercase:
    return &(buf->b_p_inf);
  case kOptIskeyword:
    return &(buf->b_p_isk);
  case kOptIncludeexpr:
    return &(buf->b_p_inex);
  case kOptIndentexpr:
    return &(buf->b_p_inde);
  case kOptIndentkeys:
    return &(buf->b_p_indk);
  case kOptFormatexpr:
    return &(buf->b_p_fex);
  case kOptLisp:
    return &(buf->b_p_lisp);
  case kOptLispoptions:
    return &(buf->b_p_lop);
  case kOptModeline:
    return &(buf->b_p_ml);
  case kOptMatchpairs:
    return &(buf->b_p_mps);
  case kOptModifiable:
    return &(buf->b_p_ma);
  case kOptModified:
    return &(buf->b_changed);
  case kOptNrformats:
    return &(buf->b_p_nf);
  case kOptPreserveindent:
    return &(buf->b_p_pi);
  case kOptQuoteescape:
    return &(buf->b_p_qe);
  case kOptReadonly:
    return &(buf->b_p_ro);
  case kOptScrollback:
    return &(buf->b_p_scbk);
  case kOptSmartindent:
    return &(buf->b_p_si);
  case kOptSofttabstop:
    return &(buf->b_p_sts);
  case kOptSuffixesadd:
    return &(buf->b_p_sua);
  case kOptSwapfile:
    return &(buf->b_p_swf);
  case kOptSynmaxcol:
    return &(buf->b_p_smc);
  case kOptSyntax:
    return &(buf->b_p_syn);
  case kOptSpellcapcheck:
    return &(win->w_s->b_p_spc);
  case kOptSpellfile:
    return &(win->w_s->b_p_spf);
  case kOptSpelllang:
    return &(win->w_s->b_p_spl);
  case kOptSpelloptions:
    return &(win->w_s->b_p_spo);
  case kOptShiftwidth:
    return &(buf->b_p_sw);
  case kOptTagfunc:
    return &(buf->b_p_tfu);
  case kOptTabstop:
    return &(buf->b_p_ts);
  case kOptTextwidth:
    return &(buf->b_p_tw);
  case kOptUndofile:
    return &(buf->b_p_udf);
  case kOptWrapmargin:
    return &(buf->b_p_wm);
  case kOptVarsofttabstop:
    return &(buf->b_p_vsts);
  case kOptVartabstop:
    return &(buf->b_p_vts);
  case kOptKeymap:
    return &(buf->b_p_keymap);
  case kOptSigncolumn:
    return &(win->w_p_scl);
  case kOptWinhighlight:
    return &(win->w_p_winhl);
  case kOptWinblend:
    return &(win->w_p_winbl);
  case kOptStatuscolumn:
    return &(win->w_p_stc);
  default:
    iemsg(_("E356: get_varp ERROR"));
  }
  // always return a valid pointer to avoid a crash!
  return &(buf->b_p_wm);
}

/// Get option index from option pointer
static inline OptIndex get_opt_idx(vimoption_T *opt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return (OptIndex)(opt - options);
}

/// Get pointer to option variable.
static inline void *get_varp(vimoption_T *p)
{
  return get_varp_from(p, curbuf, curwin);
}

/// Get the value of 'equalprg', either the buffer-local one or the global one.
char *get_equalprg(void)
{
  if (*curbuf->b_p_ep == NUL) {
    return p_ep;
  }
  return curbuf->b_p_ep;
}

/// Get the value of 'findfunc', either the buffer-local one or the global one.
char *get_findfunc(void)
{
  if (*curbuf->b_p_ffu == NUL) {
    return p_ffu;
  }
  return curbuf->b_p_ffu;
}

/// Copy options from one window to another.
/// Used when splitting a window.
void win_copy_options(win_T *wp_from, win_T *wp_to)
{
  copy_winopt(&wp_from->w_onebuf_opt, &wp_to->w_onebuf_opt);
  copy_winopt(&wp_from->w_allbuf_opt, &wp_to->w_allbuf_opt);
  didset_window_options(wp_to, true);
}

static char *copy_option_val(const char *val)
{
  if (val == empty_string_option) {
    return empty_string_option;  // no need to allocate memory
  }
  return xstrdup(val);
}

/// Copy the options from one winopt_T to another.
/// Doesn't free the old option values in "to", use clear_winopt() for that.
/// The 'scroll' option is not copied, because it depends on the window height.
/// The 'previewwindow' option is reset, there can be only one preview window.
void copy_winopt(winopt_T *from, winopt_T *to)
{
  to->wo_arab = from->wo_arab;
  to->wo_list = from->wo_list;
  to->wo_lcs = copy_option_val(from->wo_lcs);
  to->wo_fcs = copy_option_val(from->wo_fcs);
  to->wo_nu = from->wo_nu;
  to->wo_rnu = from->wo_rnu;
  to->wo_ve = copy_option_val(from->wo_ve);
  to->wo_ve_flags = from->wo_ve_flags;
  to->wo_nuw = from->wo_nuw;
  to->wo_rl = from->wo_rl;
  to->wo_rlc = copy_option_val(from->wo_rlc);
  to->wo_sbr = copy_option_val(from->wo_sbr);
  to->wo_stl = copy_option_val(from->wo_stl);
  to->wo_wbr = copy_option_val(from->wo_wbr);
  to->wo_wrap = from->wo_wrap;
  to->wo_wrap_save = from->wo_wrap_save;
  to->wo_lbr = from->wo_lbr;
  to->wo_bri = from->wo_bri;
  to->wo_briopt = copy_option_val(from->wo_briopt);
  to->wo_scb = from->wo_scb;
  to->wo_scb_save = from->wo_scb_save;
  to->wo_sms = from->wo_sms;
  to->wo_crb = from->wo_crb;
  to->wo_crb_save = from->wo_crb_save;
  to->wo_siso = from->wo_siso;
  to->wo_so = from->wo_so;
  to->wo_spell = from->wo_spell;
  to->wo_cuc = from->wo_cuc;
  to->wo_cul = from->wo_cul;
  to->wo_culopt = copy_option_val(from->wo_culopt);
  to->wo_cc = copy_option_val(from->wo_cc);
  to->wo_diff = from->wo_diff;
  to->wo_diff_saved = from->wo_diff_saved;
  to->wo_cocu = copy_option_val(from->wo_cocu);
  to->wo_cole = from->wo_cole;
  to->wo_fdc = copy_option_val(from->wo_fdc);
  to->wo_fdc_save = from->wo_diff_saved ? xstrdup(from->wo_fdc_save) : empty_string_option;
  to->wo_fen = from->wo_fen;
  to->wo_fen_save = from->wo_fen_save;
  to->wo_fdi = copy_option_val(from->wo_fdi);
  to->wo_fml = from->wo_fml;
  to->wo_fdl = from->wo_fdl;
  to->wo_fdl_save = from->wo_fdl_save;
  to->wo_fdm = copy_option_val(from->wo_fdm);
  to->wo_fdm_save = from->wo_diff_saved ? xstrdup(from->wo_fdm_save) : empty_string_option;
  to->wo_fdn = from->wo_fdn;
  to->wo_fde = copy_option_val(from->wo_fde);
  to->wo_fdt = copy_option_val(from->wo_fdt);
  to->wo_fmr = copy_option_val(from->wo_fmr);
  to->wo_scl = copy_option_val(from->wo_scl);
  to->wo_winhl = copy_option_val(from->wo_winhl);
  to->wo_winbl = from->wo_winbl;
  to->wo_stc = copy_option_val(from->wo_stc);

  // Copy the script context so that we know were the value was last set.
  memmove(to->wo_script_ctx, from->wo_script_ctx, sizeof(to->wo_script_ctx));
  check_winopt(to);             // don't want NULL pointers
}

/// Check string options in a window for a NULL value.
void check_win_options(win_T *win)
{
  check_winopt(&win->w_onebuf_opt);
  check_winopt(&win->w_allbuf_opt);
}

/// Check for NULL pointers in a winopt_T and replace them with empty_string_option.
static void check_winopt(winopt_T *wop)
{
  check_string_option(&wop->wo_fdc);
  check_string_option(&wop->wo_fdc_save);
  check_string_option(&wop->wo_fdi);
  check_string_option(&wop->wo_fdm);
  check_string_option(&wop->wo_fdm_save);
  check_string_option(&wop->wo_fde);
  check_string_option(&wop->wo_fdt);
  check_string_option(&wop->wo_fmr);
  check_string_option(&wop->wo_scl);
  check_string_option(&wop->wo_rlc);
  check_string_option(&wop->wo_sbr);
  check_string_option(&wop->wo_stl);
  check_string_option(&wop->wo_culopt);
  check_string_option(&wop->wo_cc);
  check_string_option(&wop->wo_cocu);
  check_string_option(&wop->wo_briopt);
  check_string_option(&wop->wo_winhl);
  check_string_option(&wop->wo_lcs);
  check_string_option(&wop->wo_fcs);
  check_string_option(&wop->wo_ve);
  check_string_option(&wop->wo_wbr);
  check_string_option(&wop->wo_stc);
}

/// Free the allocated memory inside a winopt_T.
void clear_winopt(winopt_T *wop)
{
  clear_string_option(&wop->wo_fdc);
  clear_string_option(&wop->wo_fdc_save);
  clear_string_option(&wop->wo_fdi);
  clear_string_option(&wop->wo_fdm);
  clear_string_option(&wop->wo_fdm_save);
  clear_string_option(&wop->wo_fde);
  clear_string_option(&wop->wo_fdt);
  clear_string_option(&wop->wo_fmr);
  clear_string_option(&wop->wo_scl);
  clear_string_option(&wop->wo_rlc);
  clear_string_option(&wop->wo_sbr);
  clear_string_option(&wop->wo_stl);
  clear_string_option(&wop->wo_culopt);
  clear_string_option(&wop->wo_cc);
  clear_string_option(&wop->wo_cocu);
  clear_string_option(&wop->wo_briopt);
  clear_string_option(&wop->wo_winhl);
  clear_string_option(&wop->wo_lcs);
  clear_string_option(&wop->wo_fcs);
  clear_string_option(&wop->wo_ve);
  clear_string_option(&wop->wo_wbr);
  clear_string_option(&wop->wo_stc);
}

void didset_window_options(win_T *wp, bool valid_cursor)
{
  // Set w_leftcol or w_skipcol to zero.
  if (wp->w_p_wrap) {
    wp->w_leftcol = 0;
  } else {
    wp->w_skipcol = 0;
  }
  check_colorcolumn(NULL, wp);
  briopt_check(NULL, wp);
  fill_culopt_flags(NULL, wp);
  set_chars_option(wp, wp->w_p_fcs, kFillchars, true, NULL, 0);
  set_chars_option(wp, wp->w_p_lcs, kListchars, true, NULL, 0);
  parse_winhl_opt(NULL, wp);  // sets w_hl_needs_update also for w_p_winbl
  check_blending(wp);
  set_winbar_win(wp, false, valid_cursor);
  check_signcolumn(NULL, wp);
  wp->w_grid_alloc.blending = wp->w_p_winbl > 0;
}

#define COPY_OPT_SCTX(buf, bv) buf->b_p_script_ctx[bv] = options[buf_opt_idx[bv]].last_set

/// Copy global option values to local options for one buffer.
/// Used when creating a new buffer and sometimes when entering a buffer.
/// flags:
/// BCO_ENTER    We will enter the buffer "buf".
/// BCO_ALWAYS   Always copy the options, but only set b_p_initialized when
///      appropriate.
/// BCO_NOHELP   Don't copy the values to a help buffer.
void buf_copy_options(buf_T *buf, int flags)
{
  bool should_copy = true;
  char *save_p_isk = NULL;           // init for GCC
  bool did_isk = false;

  // Skip this when the option defaults have not been set yet.  Happens when
  // main() allocates the first buffer.
  if (p_cpo != NULL) {
    //
    // Always copy when entering and 'cpo' contains 'S'.
    // Don't copy when already initialized.
    // Don't copy when 'cpo' contains 's' and not entering.
    //    'S'      BCO_ENTER  initialized  's'  should_copy
    //    yes        yes          X         X      true
    //    yes        no          yes        X      false
    //    no          X          yes        X      false
    //     X         no          no        yes     false
    //     X         no          no        no      true
    //    no         yes         no         X      true
    ///
    if ((vim_strchr(p_cpo, CPO_BUFOPTGLOB) == NULL || !(flags & BCO_ENTER))
        && (buf->b_p_initialized
            || (!(flags & BCO_ENTER)
                && vim_strchr(p_cpo, CPO_BUFOPT) != NULL))) {
      should_copy = false;
    }

    if (should_copy || (flags & BCO_ALWAYS)) {
      CLEAR_FIELD(buf->b_p_script_ctx);
      // Don't copy the options specific to a help buffer when
      // BCO_NOHELP is given or the options were initialized already
      // (jumping back to a help file with CTRL-T or CTRL-O)
      bool dont_do_help = ((flags & BCO_NOHELP) && buf->b_help) || buf->b_p_initialized;
      if (dont_do_help) {               // don't free b_p_isk
        save_p_isk = buf->b_p_isk;
        buf->b_p_isk = NULL;
      }
      // Always free the allocated strings.  If not already initialized,
      // reset 'readonly' and copy 'fileformat'.
      if (!buf->b_p_initialized) {
        free_buf_options(buf, true);
        buf->b_p_ro = false;                    // don't copy readonly
        buf->b_p_fenc = xstrdup(p_fenc);
        switch (*p_ffs) {
        case 'm':
          buf->b_p_ff = xstrdup("mac");
          break;
        case 'd':
          buf->b_p_ff = xstrdup("dos");
          break;
        case 'u':
          buf->b_p_ff = xstrdup("unix");
          break;
        default:
          buf->b_p_ff = xstrdup(p_ff);
          break;
        }
        buf->b_p_bh = empty_string_option;
        buf->b_p_bt = empty_string_option;
      } else {
        free_buf_options(buf, false);
      }

      buf->b_p_ai = p_ai;
      COPY_OPT_SCTX(buf, kBufOptAutoindent);
      buf->b_p_ai_nopaste = p_ai_nopaste;
      buf->b_p_sw = p_sw;
      COPY_OPT_SCTX(buf, kBufOptShiftwidth);
      buf->b_p_scbk = p_scbk;
      COPY_OPT_SCTX(buf, kBufOptScrollback);
      buf->b_p_tw = p_tw;
      COPY_OPT_SCTX(buf, kBufOptTextwidth);
      buf->b_p_tw_nopaste = p_tw_nopaste;
      buf->b_p_tw_nobin = p_tw_nobin;
      buf->b_p_wm = p_wm;
      COPY_OPT_SCTX(buf, kBufOptWrapmargin);
      buf->b_p_wm_nopaste = p_wm_nopaste;
      buf->b_p_wm_nobin = p_wm_nobin;
      buf->b_p_bin = p_bin;
      COPY_OPT_SCTX(buf, kBufOptBinary);
      buf->b_p_bomb = p_bomb;
      COPY_OPT_SCTX(buf, kBufOptBomb);
      buf->b_p_et = p_et;
      COPY_OPT_SCTX(buf, kBufOptExpandtab);
      buf->b_p_fixeol = p_fixeol;
      COPY_OPT_SCTX(buf, kBufOptFixendofline);
      buf->b_p_et_nobin = p_et_nobin;
      buf->b_p_et_nopaste = p_et_nopaste;
      buf->b_p_ml = p_ml;
      COPY_OPT_SCTX(buf, kBufOptModeline);
      buf->b_p_ml_nobin = p_ml_nobin;
      buf->b_p_inf = p_inf;
      COPY_OPT_SCTX(buf, kBufOptInfercase);
      if (cmdmod.cmod_flags & CMOD_NOSWAPFILE) {
        buf->b_p_swf = false;
      } else {
        buf->b_p_swf = p_swf;
        COPY_OPT_SCTX(buf, kBufOptSwapfile);
      }
      buf->b_p_cpt = xstrdup(p_cpt);
      COPY_OPT_SCTX(buf, kBufOptComplete);
#ifdef BACKSLASH_IN_FILENAME
      buf->b_p_csl = xstrdup(p_csl);
      COPY_OPT_SCTX(buf, kBufOptCompleteslash);
#endif
      buf->b_p_cfu = xstrdup(p_cfu);
      COPY_OPT_SCTX(buf, kBufOptCompletefunc);
      set_buflocal_cfu_callback(buf);
      buf->b_p_ofu = xstrdup(p_ofu);
      COPY_OPT_SCTX(buf, kBufOptOmnifunc);
      set_buflocal_ofu_callback(buf);
      buf->b_p_tfu = xstrdup(p_tfu);
      COPY_OPT_SCTX(buf, kBufOptTagfunc);
      set_buflocal_tfu_callback(buf);
      buf->b_p_sts = p_sts;
      COPY_OPT_SCTX(buf, kBufOptSofttabstop);
      buf->b_p_sts_nopaste = p_sts_nopaste;
      buf->b_p_vsts = xstrdup(p_vsts);
      COPY_OPT_SCTX(buf, kBufOptVarsofttabstop);
      if (p_vsts && p_vsts != empty_string_option) {
        tabstop_set(p_vsts, &buf->b_p_vsts_array);
      } else {
        buf->b_p_vsts_array = NULL;
      }
      buf->b_p_vsts_nopaste = p_vsts_nopaste ? xstrdup(p_vsts_nopaste) : NULL;
      buf->b_p_com = xstrdup(p_com);
      COPY_OPT_SCTX(buf, kBufOptComments);
      buf->b_p_cms = xstrdup(p_cms);
      COPY_OPT_SCTX(buf, kBufOptCommentstring);
      buf->b_p_fo = xstrdup(p_fo);
      COPY_OPT_SCTX(buf, kBufOptFormatoptions);
      buf->b_p_flp = xstrdup(p_flp);
      COPY_OPT_SCTX(buf, kBufOptFormatlistpat);
      buf->b_p_nf = xstrdup(p_nf);
      COPY_OPT_SCTX(buf, kBufOptNrformats);
      buf->b_p_mps = xstrdup(p_mps);
      COPY_OPT_SCTX(buf, kBufOptMatchpairs);
      buf->b_p_si = p_si;
      COPY_OPT_SCTX(buf, kBufOptSmartindent);
      buf->b_p_channel = 0;
      buf->b_p_ci = p_ci;

      COPY_OPT_SCTX(buf, kBufOptCopyindent);
      buf->b_p_cin = p_cin;
      COPY_OPT_SCTX(buf, kBufOptCindent);
      buf->b_p_cink = xstrdup(p_cink);
      COPY_OPT_SCTX(buf, kBufOptCinkeys);
      buf->b_p_cino = xstrdup(p_cino);
      COPY_OPT_SCTX(buf, kBufOptCinoptions);
      buf->b_p_cinsd = xstrdup(p_cinsd);
      COPY_OPT_SCTX(buf, kBufOptCinscopedecls);
      buf->b_p_lop = xstrdup(p_lop);
      COPY_OPT_SCTX(buf, kBufOptLispoptions);

      // Don't copy 'filetype', it must be detected
      buf->b_p_ft = empty_string_option;
      buf->b_p_pi = p_pi;
      COPY_OPT_SCTX(buf, kBufOptPreserveindent);
      buf->b_p_cinw = xstrdup(p_cinw);
      COPY_OPT_SCTX(buf, kBufOptCinwords);
      buf->b_p_lisp = p_lisp;
      COPY_OPT_SCTX(buf, kBufOptLisp);
      // Don't copy 'syntax', it must be set
      buf->b_p_syn = empty_string_option;
      buf->b_p_smc = p_smc;
      COPY_OPT_SCTX(buf, kBufOptSynmaxcol);
      buf->b_s.b_syn_isk = empty_string_option;
      buf->b_s.b_p_spc = xstrdup(p_spc);
      COPY_OPT_SCTX(buf, kBufOptSpellcapcheck);
      compile_cap_prog(&buf->b_s);
      buf->b_s.b_p_spf = xstrdup(p_spf);
      COPY_OPT_SCTX(buf, kBufOptSpellfile);
      buf->b_s.b_p_spl = xstrdup(p_spl);
      COPY_OPT_SCTX(buf, kBufOptSpelllang);
      buf->b_s.b_p_spo = xstrdup(p_spo);
      COPY_OPT_SCTX(buf, kBufOptSpelloptions);
      buf->b_s.b_p_spo_flags = spo_flags;
      buf->b_p_inde = xstrdup(p_inde);
      COPY_OPT_SCTX(buf, kBufOptIndentexpr);
      buf->b_p_indk = xstrdup(p_indk);
      COPY_OPT_SCTX(buf, kBufOptIndentkeys);
      buf->b_p_fp = empty_string_option;
      buf->b_p_fex = xstrdup(p_fex);
      COPY_OPT_SCTX(buf, kBufOptFormatexpr);
      buf->b_p_sua = xstrdup(p_sua);
      COPY_OPT_SCTX(buf, kBufOptSuffixesadd);
      buf->b_p_keymap = xstrdup(p_keymap);
      COPY_OPT_SCTX(buf, kBufOptKeymap);
      buf->b_kmap_state |= KEYMAP_INIT;
      // This isn't really an option, but copying the langmap and IME
      // state from the current buffer is better than resetting it.
      buf->b_p_iminsert = p_iminsert;
      COPY_OPT_SCTX(buf, kBufOptIminsert);
      buf->b_p_imsearch = p_imsearch;
      COPY_OPT_SCTX(buf, kBufOptImsearch);

      // options that are normally global but also have a local value
      // are not copied, start using the global value
      buf->b_p_ar = -1;
      buf->b_p_ul = NO_LOCAL_UNDOLEVEL;
      buf->b_p_bkc = empty_string_option;
      buf->b_bkc_flags = 0;
      buf->b_p_gp = empty_string_option;
      buf->b_p_mp = empty_string_option;
      buf->b_p_efm = empty_string_option;
      buf->b_p_ep = empty_string_option;
      buf->b_p_ffu = empty_string_option;
      buf->b_p_kp = empty_string_option;
      buf->b_p_path = empty_string_option;
      buf->b_p_tags = empty_string_option;
      buf->b_p_tc = empty_string_option;
      buf->b_tc_flags = 0;
      buf->b_p_def = empty_string_option;
      buf->b_p_inc = empty_string_option;
      buf->b_p_inex = xstrdup(p_inex);
      COPY_OPT_SCTX(buf, kBufOptIncludeexpr);
      buf->b_p_cot = empty_string_option;
      buf->b_cot_flags = 0;
      buf->b_p_dict = empty_string_option;
      buf->b_p_tsr = empty_string_option;
      buf->b_p_tsrfu = empty_string_option;
      buf->b_p_qe = xstrdup(p_qe);
      COPY_OPT_SCTX(buf, kBufOptQuoteescape);
      buf->b_p_udf = p_udf;
      COPY_OPT_SCTX(buf, kBufOptUndofile);
      buf->b_p_lw = empty_string_option;
      buf->b_p_menc = empty_string_option;

      // Don't copy the options set by ex_help(), use the saved values,
      // when going from a help buffer to a non-help buffer.
      // Don't touch these at all when BCO_NOHELP is used and going from
      // or to a help buffer.
      if (dont_do_help) {
        buf->b_p_isk = save_p_isk;
        if (p_vts && p_vts != empty_string_option && !buf->b_p_vts_array) {
          tabstop_set(p_vts, &buf->b_p_vts_array);
        } else {
          buf->b_p_vts_array = NULL;
        }
      } else {
        buf->b_p_isk = xstrdup(p_isk);
        COPY_OPT_SCTX(buf, kBufOptIskeyword);
        did_isk = true;
        buf->b_p_ts = p_ts;
        COPY_OPT_SCTX(buf, kBufOptTabstop);
        buf->b_p_vts = xstrdup(p_vts);
        COPY_OPT_SCTX(buf, kBufOptVartabstop);
        if (p_vts && p_vts != empty_string_option && !buf->b_p_vts_array) {
          tabstop_set(p_vts, &buf->b_p_vts_array);
        } else {
          buf->b_p_vts_array = NULL;
        }
        buf->b_help = false;
        if (buf->b_p_bt[0] == 'h') {
          clear_string_option(&buf->b_p_bt);
        }
        buf->b_p_ma = p_ma;
        COPY_OPT_SCTX(buf, kBufOptModifiable);
      }
    }

    // When the options should be copied (ignoring BCO_ALWAYS), set the
    // flag that indicates that the options have been initialized.
    if (should_copy) {
      buf->b_p_initialized = true;
    }
  }

  check_buf_options(buf);           // make sure we don't have NULLs
  if (did_isk) {
    buf_init_chartab(buf, false);
  }
}

/// Reset the 'modifiable' option and its default value.
void reset_modifiable(void)
{
  curbuf->b_p_ma = false;
  p_ma = false;
  change_option_default(kOptModifiable, BOOLEAN_OPTVAL(false));
}

/// Set the global value for 'iminsert' to the local value.
void set_iminsert_global(buf_T *buf)
{
  p_iminsert = buf->b_p_iminsert;
}

/// Set the global value for 'imsearch' to the local value.
void set_imsearch_global(buf_T *buf)
{
  p_imsearch = buf->b_p_imsearch;
}

static OptIndex expand_option_idx = kOptInvalid;
static int expand_option_start_col = 0;
static char expand_option_name[5] = { 't', '_', NUL, NUL, NUL };
static int expand_option_flags = 0;
static bool expand_option_append = false;

/// @param opt_flags  OPT_GLOBAL and/or OPT_LOCAL
void set_context_in_set_cmd(expand_T *xp, char *arg, int opt_flags)
{
  expand_option_flags = opt_flags;

  xp->xp_context = EXPAND_SETTINGS;
  if (*arg == NUL) {
    xp->xp_pattern = arg;
    return;
  }
  char *const argend = arg + strlen(arg);
  char *p = argend - 1;
  if (*p == ' ' && *(p - 1) != '\\') {
    xp->xp_pattern = p + 1;
    return;
  }
  while (p > arg) {
    char *s = p;
    // count number of backslashes before ' ' or ','
    if (*p == ' ' || *p == ',') {
      while (s > arg && *(s - 1) == '\\') {
        s--;
      }
    }
    // break at a space with an even number of backslashes
    if (*p == ' ' && ((p - s) & 1) == 0) {
      p++;
      break;
    }
    p--;
  }
  if (strncmp(p, "no", 2) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    xp->xp_prefix = XP_PREFIX_NO;
    p += 2;
  } else if (strncmp(p, "inv", 3) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    xp->xp_prefix = XP_PREFIX_INV;
    p += 3;
  }
  xp->xp_pattern = p;
  arg = p;

  char nextchar;
  uint32_t flags = 0;
  OptIndex opt_idx = 0;
  bool is_term_option = false;

  if (*arg == '<') {
    while (*p != '>') {
      if (*p++ == NUL) {            // expand terminal option name
        return;
      }
    }
    int key = get_special_key_code(arg + 1);
    if (key == 0) {                 // unknown name
      xp->xp_context = EXPAND_NOTHING;
      return;
    }
    nextchar = *++p;
    is_term_option = true;
    expand_option_name[2] = (char)(uint8_t)KEY2TERMCAP0(key);
    expand_option_name[3] = (char)(uint8_t)KEY2TERMCAP1(key);
  } else {
    if (p[0] == 't' && p[1] == '_') {
      p += 2;
      if (*p != NUL) {
        p++;
      }
      if (*p == NUL) {
        return;                 // expand option name
      }
      nextchar = *++p;
      is_term_option = true;
      expand_option_name[2] = p[-2];
      expand_option_name[3] = p[-1];
    } else {
      // Allow * wildcard.
      while (ASCII_ISALNUM(*p) || *p == '_' || *p == '*') {
        p++;
      }
      if (*p == NUL) {
        return;
      }
      nextchar = *p;
      opt_idx = find_option_len(arg, (size_t)(p - arg));
      if (opt_idx == kOptInvalid || is_option_hidden(opt_idx)) {
        xp->xp_context = EXPAND_NOTHING;
        return;
      }
      flags = options[opt_idx].flags;
      if (option_has_type(opt_idx, kOptValTypeBoolean)) {
        xp->xp_context = EXPAND_NOTHING;
        return;
      }
    }
  }
  // handle "-=" and "+="
  expand_option_append = false;
  bool expand_option_subtract = false;
  if ((nextchar == '-' || nextchar == '+' || nextchar == '^') && p[1] == '=') {
    if (nextchar == '-') {
      expand_option_subtract = true;
    }
    if (nextchar == '+' || nextchar == '^') {
      expand_option_append = true;
    }
    p++;
    nextchar = '=';
  }
  if ((nextchar != '=' && nextchar != ':')
      || xp->xp_context == EXPAND_BOOL_SETTINGS) {
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return;
  }

  // Below are for handling expanding a specific option's value after the '=' or ':'

  if (is_term_option) {
    expand_option_idx = kOptInvalid;
  } else {
    expand_option_idx = opt_idx;
  }

  xp->xp_pattern = p + 1;
  expand_option_start_col = (int)(p + 1 - xp->xp_line);

  // Certain options currently have special case handling to reuse the
  // expansion logic with other commands.
  if (options[opt_idx].var == &p_syn) {
    xp->xp_context = EXPAND_OWNSYNTAX;
    return;
  }
  if (options[opt_idx].var == &p_ft) {
    xp->xp_context = EXPAND_FILETYPE;
    return;
  }
  if (options[opt_idx].var == &p_keymap) {
    xp->xp_context = EXPAND_KEYMAP;
    return;
  }

  // Now pick. If the option has a custom expander, use that. Otherwise, just
  // fill with the existing option value.
  if (expand_option_subtract) {
    xp->xp_context = EXPAND_SETTING_SUBTRACT;
    return;
  } else if (expand_option_idx != kOptInvalid && options[expand_option_idx].opt_expand_cb != NULL) {
    xp->xp_context = EXPAND_STRING_SETTING;
  } else if (*xp->xp_pattern == NUL) {
    xp->xp_context = EXPAND_OLD_SETTING;
    return;
  } else {
    xp->xp_context = EXPAND_NOTHING;
  }

  if (is_term_option || option_has_type(opt_idx, kOptValTypeNumber)) {
    return;
  }

  // Only string options below

  // Options that have kOptFlagExpand are considered to all use file/dir expansion.
  if (flags & kOptFlagExpand) {
    p = options[opt_idx].var;
    if (p == (char *)&p_bdir
        || p == (char *)&p_dir
        || p == (char *)&p_path
        || p == (char *)&p_pp
        || p == (char *)&p_rtp
        || p == (char *)&p_cdpath
        || p == (char *)&p_vdir) {
      xp->xp_context = EXPAND_DIRECTORIES;
      if (p == (char *)&p_path || p == (char *)&p_cdpath) {
        xp->xp_backslash = XP_BS_THREE;
      } else {
        xp->xp_backslash = XP_BS_ONE;
      }
    } else {
      xp->xp_context = EXPAND_FILES;
      // for 'tags' need three backslashes for a space
      if (p == (char *)&p_tags) {
        xp->xp_backslash = XP_BS_THREE;
      } else {
        xp->xp_backslash = XP_BS_ONE;
      }
    }
    if (flags & kOptFlagComma) {
      xp->xp_backslash |= XP_BS_COMMA;
    }
  }

  // For an option that is a list of file names, or comma/colon-separated
  // values, split it by the delimiter and find the start of the current
  // pattern, while accounting for backslash-escaped space/commas/colons.
  // Triple-backslashed escaped file names (e.g. 'path') can also be
  // delimited by space.
  if ((flags & kOptFlagExpand) || (flags & kOptFlagComma) || (flags & kOptFlagColon)) {
    for (p = argend - 1; p > xp->xp_pattern; p--) {
      // count number of backslashes before ' ' or ','
      if (*p == ' ' || *p == ',' || (*p == ':' && (flags & kOptFlagColon))) {
        char *s = p;
        while (s > xp->xp_pattern && *(s - 1) == '\\') {
          s--;
        }
        if ((*p == ' ' && ((xp->xp_backslash & XP_BS_THREE) && (p - s) < 3))
#if defined(BACKSLASH_IN_FILENAME)
            || (*p == ',' && (flags & kOptFlagComma) && (p - s) < 1)
#else
            || (*p == ',' && (flags & kOptFlagComma) && (p - s) < 2)
#endif
            || (*p == ':' && (flags & kOptFlagColon))) {
          xp->xp_pattern = p + 1;
          break;
        }
      }
    }
  }

  // An option that is a list of single-character flags should always start
  // at the end as we don't complete words.
  if (flags & kOptFlagFlagList) {
    xp->xp_pattern = argend;
  }

  // Some options can either be using file/dir expansions, or custom value
  // expansion depending on what the user typed. Unfortunately we have to
  // manually handle it here to make sure we have the correct xp_context set.
  // for 'spellsuggest' start at "file:"
  if (options[opt_idx].var == &p_sps) {
    if (strncmp(xp->xp_pattern, "file:", 5) == 0) {
      xp->xp_pattern += 5;
      return;
    } else if (options[expand_option_idx].opt_expand_cb != NULL) {
      xp->xp_context = EXPAND_STRING_SETTING;
    }
  }
}

/// Returns true if "str" either matches "regmatch" or fuzzy matches "pat".
///
/// If "test_only" is true and "fuzzy" is false and if "str" matches the regular
/// expression "regmatch", then returns true.  Otherwise returns false.
///
/// If "test_only" is false and "fuzzy" is false and if "str" matches the
/// regular expression "regmatch", then stores the match in matches[idx] and
/// returns true.
///
/// If "test_only" is true and "fuzzy" is true and if "str" fuzzy matches
/// "fuzzystr", then returns true. Otherwise returns false.
///
/// If "test_only" is false and "fuzzy" is true and if "str" fuzzy matches
/// "fuzzystr", then stores the match details in fuzmatch[idx] and returns true.
static bool match_str(char *const str, regmatch_T *const regmatch, char **const matches,
                      const int idx, const bool test_only, const bool fuzzy,
                      const char *const fuzzystr, fuzmatch_str_T *const fuzmatch)
{
  if (!fuzzy) {
    if (vim_regexec(regmatch, str, 0)) {
      if (!test_only) {
        matches[idx] = xstrdup(str);
      }
      return true;
    }
  } else {
    const int score = fuzzy_match_str(str, fuzzystr);
    if (score != 0) {
      if (!test_only) {
        fuzmatch[idx].idx = idx;
        fuzmatch[idx].str = xstrdup(str);
        fuzmatch[idx].score = score;
      }
      return true;
    }
  }
  return false;
}

int ExpandSettings(expand_T *xp, regmatch_T *regmatch, char *fuzzystr, int *numMatches,
                   char ***matches, const bool can_fuzzy)
{
  int num_normal = 0;  // Nr of matching non-term-code settings
  int count = 0;
  static char *(names[]) = { "all" };
  int ic = regmatch->rm_ic;  // remember the ignore-case flag

  fuzmatch_str_T *fuzmatch = NULL;
  const bool fuzzy = can_fuzzy && cmdline_fuzzy_complete(fuzzystr);

  // do this loop twice:
  // loop == 0: count the number of matching options
  // loop == 1: copy the matching options into allocated memory
  for (int loop = 0; loop <= 1; loop++) {
    regmatch->rm_ic = ic;
    if (xp->xp_context != EXPAND_BOOL_SETTINGS) {
      for (int match = 0; match < (int)ARRAY_SIZE(names);
           match++) {
        if (match_str(names[match], regmatch, *matches,
                      count, (loop == 0), fuzzy, fuzzystr, fuzmatch)) {
          if (loop == 0) {
            num_normal++;
          } else {
            count++;
          }
        }
      }
    }
    char *str;
    for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
      str = options[opt_idx].fullname;
      if (is_option_hidden(opt_idx)) {
        continue;
      }
      if (xp->xp_context == EXPAND_BOOL_SETTINGS
          && !(option_has_type(opt_idx, kOptValTypeBoolean))) {
        continue;
      }

      if (match_str(str, regmatch, *matches, count, (loop == 0),
                    fuzzy, fuzzystr, fuzmatch)) {
        if (loop == 0) {
          num_normal++;
        } else {
          count++;
        }
      } else if (!fuzzy && options[opt_idx].shortname != NULL
                 && vim_regexec(regmatch, options[opt_idx].shortname, 0)) {
        // Compare against the abbreviated option name (for regular
        // expression match). Fuzzy matching (previous if) already
        // matches against both the expanded and abbreviated names.
        if (loop == 0) {
          num_normal++;
        } else {
          (*matches)[count++] = xstrdup(str);
        }
      }
    }

    if (loop == 0) {
      if (num_normal > 0) {
        *numMatches = num_normal;
      } else {
        return OK;
      }
      if (!fuzzy) {
        *matches = xmalloc((size_t)(*numMatches) * sizeof(char *));
      } else {
        fuzmatch = xmalloc((size_t)(*numMatches) * sizeof(fuzmatch_str_T));
      }
    }
  }

  if (fuzzy) {
    fuzzymatches_to_strmatches(fuzmatch, matches, count, false);
  }

  return OK;
}

/// Escape an option value that can be used on the command-line with :set.
/// Caller needs to free the returned string, unless NULL is returned.
static char *escape_option_str_cmdline(char *var)
{
  // A backslash is required before some characters.  This is the reverse of
  // what happens in do_set().
  char *buf = vim_strsave_escaped(var, escape_chars);

#ifdef BACKSLASH_IN_FILENAME
  // For MS-Windows et al. we don't double backslashes at the start and
  // before a file name character.
  // The reverse is found at stropt_copy_value().
  for (var = buf; *var != NUL; MB_PTR_ADV(var)) {
    if (var[0] == '\\' && var[1] == '\\'
        && expand_option_idx != kOptInvalid
        && (options[expand_option_idx].flags & kOptFlagExpand)
        && vim_isfilec((uint8_t)var[2])
        && (var[2] != '\\' || (var == buf && var[4] != '\\'))) {
      STRMOVE(var, var + 1);
    }
  }
#endif
  return buf;
}

/// Expansion handler for :set= when we just want to fill in with the existing value.
int ExpandOldSetting(int *numMatches, char ***matches)
{
  char *var = NULL;

  *numMatches = 0;
  *matches = xmalloc(sizeof(char *));

  // For a terminal key code expand_option_idx is kOptInvalid.
  if (expand_option_idx == kOptInvalid) {
    expand_option_idx = find_option(expand_option_name);
  }

  if (expand_option_idx != kOptInvalid) {
    // Put string of option value in NameBuff.
    option_value2string(&options[expand_option_idx], expand_option_flags);
    var = NameBuff;
  } else {
    var = "";
  }

  char *buf = escape_option_str_cmdline(var);

  (*matches)[0] = buf;
  *numMatches = 1;
  return OK;
}

/// Expansion handler for :set=/:set+= when the option has a custom expansion handler.
int ExpandStringSetting(expand_T *xp, regmatch_T *regmatch, int *numMatches, char ***matches)
{
  if (expand_option_idx == kOptInvalid || options[expand_option_idx].opt_expand_cb == NULL) {
    // Not supposed to reach this. This function is only for options with
    // custom expansion callbacks.
    return FAIL;
  }

  optexpand_T args = {
    .oe_varp = get_varp_scope(&options[expand_option_idx], expand_option_flags),
    .oe_append = expand_option_append,
    .oe_regmatch = regmatch,
    .oe_xp = xp,
    .oe_set_arg = xp->xp_line + expand_option_start_col,
  };
  args.oe_include_orig_val = !expand_option_append && (*args.oe_set_arg == NUL);

  // Retrieve the existing value, but escape it as a reverse of setting it.
  // We technically only need to do this when oe_append or
  // oe_include_orig_val is true.
  option_value2string(&options[expand_option_idx], expand_option_flags);
  char *var = NameBuff;
  char *buf = escape_option_str_cmdline(var);
  args.oe_opt_value = buf;

  int num_ret = options[expand_option_idx].opt_expand_cb(&args, numMatches, matches);

  xfree(buf);
  return num_ret;
}

/// Expansion handler for :set-=
int ExpandSettingSubtract(expand_T *xp, regmatch_T *regmatch, int *numMatches, char ***matches)
{
  if (expand_option_idx == kOptInvalid) {
    // term option
    return ExpandOldSetting(numMatches, matches);
  }

  char *option_val = *(char **)get_option_varp_scope_from(expand_option_idx,
                                                          expand_option_flags,
                                                          curbuf, curwin);

  uint32_t option_flags = options[expand_option_idx].flags;

  if (option_has_type(expand_option_idx, kOptValTypeNumber)) {
    return ExpandOldSetting(numMatches, matches);
  } else if (option_flags & kOptFlagComma) {
    // Split the option by comma, then present each option to the user if
    // it matches the pattern.
    // This condition needs to go first, because 'whichwrap' has both
    // kOptFlagComma and kOptFlagFlagList.

    if (*option_val == NUL) {
      return FAIL;
    }

    // Make a copy as we need to inject null characters destructively.
    char *option_copy = xstrdup(option_val);
    char *next_val = option_copy;

    garray_T ga;
    ga_init(&ga, sizeof(char *), 10);

    do {
      char *item = next_val;
      char *comma = vim_strchr(next_val, ',');
      while (comma != NULL && comma != next_val && *(comma - 1) == '\\') {
        // "\," is interpreted as a literal comma rather than option
        // separator when reading options in copy_option_part(). Skip
        // it.
        comma = vim_strchr(comma + 1, ',');
      }
      if (comma != NULL) {
        *comma = NUL;  // null-terminate this value, required by later functions
        next_val = comma + 1;
      } else {
        next_val = NULL;
      }

      if (*item == NUL) {
        // empty value, don't add to list
        continue;
      }

      if (!vim_regexec(regmatch, item, 0)) {
        continue;
      }

      char *buf = escape_option_str_cmdline(item);
      GA_APPEND(char *, &ga, buf);
    } while (next_val != NULL);

    xfree(option_copy);

    *matches = ga.ga_data;
    *numMatches = ga.ga_len;
    return OK;
  } else if (option_flags & kOptFlagFlagList) {
    // Only present the flags that are set on the option as the other flags
    // are not meaningful to do set-= on.

    if (*xp->xp_pattern != NUL) {
      // Don't suggest anything if cmdline is non-empty. Vim's set-=
      // behavior requires consecutive strings and it's usually
      // unintuitive to users if they try to subtract multiple flags at
      // once.
      return FAIL;
    }

    size_t num_flags = strlen(option_val);
    if (num_flags == 0) {
      return FAIL;
    }

    *matches = xmalloc(sizeof(char *) * (num_flags + 1));

    int count = 0;

    (*matches)[count++] = xmemdupz(option_val, num_flags);

    if (num_flags > 1) {
      // If more than one flags, split the flags up and expose each
      // character as individual choice.
      for (char *flag = option_val; *flag != NUL; flag++) {
        (*matches)[count++] = xmemdupz(flag, 1);
      }
    }

    *numMatches = count;
    return OK;
  }

  return ExpandOldSetting(numMatches, matches);
}

/// Get the value for the numeric or string option///opp in a nice format into
/// NameBuff[].  Must not be called with a hidden option!
///
/// @param opt_flags  OPT_GLOBAL and/or OPT_LOCAL
///
/// TODO(famiu): Replace this with optval_to_cstr() if possible.
static void option_value2string(vimoption_T *opt, int scope)
{
  void *varp = get_varp_scope(opt, scope);
  assert(varp != NULL);

  if (option_has_type(get_opt_idx(opt), kOptValTypeNumber)) {
    OptInt wc = 0;

    if (wc_use_keyname(varp, &wc)) {
      xstrlcpy(NameBuff, get_special_key_name((int)wc, 0), sizeof(NameBuff));
    } else if (wc != 0) {
      xstrlcpy(NameBuff, transchar((int)wc), sizeof(NameBuff));
    } else {
      snprintf(NameBuff,
               sizeof(NameBuff),
               "%" PRId64,
               (int64_t)(*(OptInt *)varp));
    }
  } else {  // string
    varp = *(char **)(varp);

    if (opt->flags & kOptFlagExpand) {
      home_replace(NULL, varp, NameBuff, MAXPATHL, false);
    } else {
      xstrlcpy(NameBuff, varp, MAXPATHL);
    }
  }
}

/// Return true if "varp" points to 'wildchar' or 'wildcharm' and it can be
/// printed as a keyname.
/// "*wcp" is set to the value of the option if it's 'wildchar' or 'wildcharm'.
static int wc_use_keyname(const void *varp, OptInt *wcp)
{
  if (((OptInt *)varp == &p_wc) || ((OptInt *)varp == &p_wcm)) {
    *wcp = *(OptInt *)varp;
    if (IS_SPECIAL(*wcp) || find_special_key_in_table((int)(*wcp)) >= 0) {
      return true;
    }
  }
  return false;
}

/// @returns true if "x" is present in 'shortmess' option, or
/// 'shortmess' contains 'a' and "x" is present in SHM_ALL_ABBREVIATIONS.
bool shortmess(int x)
{
  return (p_shm != NULL
          && (vim_strchr(p_shm, x) != NULL
              || (vim_strchr(p_shm, 'a') != NULL
                  && vim_strchr(SHM_ALL_ABBREVIATIONS, x) != NULL)));
}

/// vimrc_found() - Called when a vimrc or "VIMINIT" has been found.
///
/// Set the values for options that didn't get set yet to the defaults.
/// When "fname" is not NULL, use it to set $"envname" when it wasn't set yet.
void vimrc_found(char *fname, char *envname)
{
  if (fname != NULL && envname != NULL) {
    char *p = vim_getenv(envname);
    if (p == NULL) {
      // Set $MYVIMRC to the first vimrc file found.
      p = FullName_save(fname, false);
      if (p != NULL) {
        os_setenv(envname, p, 1);
        xfree(p);
      }
    } else {
      xfree(p);
    }
  }
}

/// Check whether global option has been set.
///
/// @param[in]  name  Option name.
///
/// @return True if option was set.
bool option_was_set(OptIndex opt_idx)
{
  assert(opt_idx != kOptInvalid);
  return options[opt_idx].flags & kOptFlagWasSet;
}

/// Reset the flag indicating option "name" was set.
///
/// @param[in]  name  Option name.
void reset_option_was_set(OptIndex opt_idx)
{
  assert(opt_idx != kOptInvalid);
  options[opt_idx].flags &= ~(unsigned)kOptFlagWasSet;
}

/// fill_culopt_flags() -- called when 'culopt' changes value
int fill_culopt_flags(char *val, win_T *wp)
{
  char *p;
  uint8_t culopt_flags_new = 0;

  if (val == NULL) {
    p = wp->w_p_culopt;
  } else {
    p = val;
  }
  while (*p != NUL) {
    // Note: Keep this in sync with p_culopt_values.
    if (strncmp(p, "line", 4) == 0) {
      p += 4;
      culopt_flags_new |= CULOPT_LINE;
    } else if (strncmp(p, "both", 4) == 0) {
      p += 4;
      culopt_flags_new |= CULOPT_LINE | CULOPT_NBR;
    } else if (strncmp(p, "number", 6) == 0) {
      p += 6;
      culopt_flags_new |= CULOPT_NBR;
    } else if (strncmp(p, "screenline", 10) == 0) {
      p += 10;
      culopt_flags_new |= CULOPT_SCRLINE;
    }

    if (*p != ',' && *p != NUL) {
      return FAIL;
    }
    if (*p == ',') {
      p++;
    }
  }

  // Can't have both "line" and "screenline".
  if ((culopt_flags_new & CULOPT_LINE) && (culopt_flags_new & CULOPT_SCRLINE)) {
    return FAIL;
  }
  wp->w_p_culopt_flags = culopt_flags_new;

  return OK;
}

/// Get the value of 'magic' taking "magic_overruled" into account.
bool magic_isset(void)
{
  switch (magic_overruled) {
  case OPTION_MAGIC_ON:
    return true;
  case OPTION_MAGIC_OFF:
    return false;
  case OPTION_MAGIC_NOT_SET:
    break;
  }
  return p_magic;
}

/// Set the callback function value for an option that accepts a function name,
/// lambda, et al. (e.g. 'operatorfunc', 'tagfunc', etc.)
/// @return  OK if the option is successfully set to a function, otherwise FAIL
int option_set_callback_func(char *optval, Callback *optcb)
{
  if (optval == NULL || *optval == NUL) {
    callback_free(optcb);
    return OK;
  }

  typval_T *tv;
  if (*optval == '{'
      || (strncmp(optval, "function(", 9) == 0)
      || (strncmp(optval, "funcref(", 8) == 0)) {
    // Lambda expression or a funcref
    tv = eval_expr(optval, NULL);
    if (tv == NULL) {
      return FAIL;
    }
  } else {
    // treat everything else as a function name string
    tv = xcalloc(1, sizeof(*tv));
    tv->v_type = VAR_STRING;
    tv->vval.v_string = xstrdup(optval);
  }

  Callback cb;
  if (!callback_from_typval(&cb, tv) || cb.type == kCallbackNone) {
    tv_free(tv);
    return FAIL;
  }

  callback_free(optcb);
  *optcb = cb;
  tv_free(tv);
  return OK;
}

static void didset_options_sctx(int opt_flags, int *buf)
{
  for (int i = 0;; i++) {
    if (buf[i] == kOptInvalid) {
      break;
    }

    set_option_sctx(buf[i], opt_flags, current_sctx);
  }
}

/// Check if backspacing over something is allowed.
/// @param  what  BS_INDENT, BS_EOL, BS_START, or BS_NOSTOP
bool can_bs(int what)
{
  if (what == BS_START && bt_prompt(curbuf)) {
    return false;
  }

  // support for number values was removed but we keep '2' since it is used in
  // legacy tests
  if (*p_bs == '2') {
    return what != BS_NOSTOP;
  }

  return vim_strchr(p_bs, what) != NULL;
}

/// Get the local or global value of 'backupcopy' flags.
///
/// @param buf The buffer.
unsigned get_bkc_flags(buf_T *buf)
{
  return buf->b_bkc_flags ? buf->b_bkc_flags : bkc_flags;
}

/// Get the local or global value of 'formatlistpat'.
///
/// @param buf The buffer.
char *get_flp_value(buf_T *buf)
{
  if (buf->b_p_flp == NULL || *buf->b_p_flp == NUL) {
    return p_flp;
  }
  return buf->b_p_flp;
}

/// Get the local or global value of 'virtualedit' flags.
unsigned get_ve_flags(win_T *wp)
{
  return (wp->w_ve_flags ? wp->w_ve_flags : ve_flags) & ~(VE_NONE | VE_NONEU);
}

/// Get the local or global value of 'showbreak'.
///
/// @param win  If not NULL, the window to get the local option from; global
///             otherwise.
char *get_showbreak_value(win_T *const win)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win->w_p_sbr == NULL || *win->w_p_sbr == NUL) {
    return p_sbr;
  }
  if (strcmp(win->w_p_sbr, "NONE") == 0) {
    return empty_string_option;
  }
  return win->w_p_sbr;
}

/// Return the current end-of-line type: EOL_DOS, EOL_UNIX or EOL_MAC.
int get_fileformat(const buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  int c = (unsigned char)(*buf->b_p_ff);

  if (buf->b_p_bin || c == 'u') {
    return EOL_UNIX;
  }
  if (c == 'm') {
    return EOL_MAC;
  }
  return EOL_DOS;
}

/// Like get_fileformat(), but override 'fileformat' with "p" for "++opt=val"
/// argument.
///
/// @param eap  can be NULL!
int get_fileformat_force(const buf_T *buf, const exarg_T *eap)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int c;

  if (eap != NULL && eap->force_ff != 0) {
    c = eap->force_ff;
  } else {
    if ((eap != NULL && eap->force_bin != 0)
        ? (eap->force_bin == FORCE_BIN) : buf->b_p_bin) {
      return EOL_UNIX;
    }
    c = (unsigned char)(*buf->b_p_ff);
  }
  if (c == 'u') {
    return EOL_UNIX;
  }
  if (c == 'm') {
    return EOL_MAC;
  }
  return EOL_DOS;
}

/// Return the default fileformat from 'fileformats'.
int default_fileformat(void)
{
  switch (*p_ffs) {
  case 'm':
    return EOL_MAC;
  case 'd':
    return EOL_DOS;
  }
  return EOL_UNIX;
}

/// Set the current end-of-line type to EOL_UNIX, EOL_MAC, or EOL_DOS.
///
/// Sets 'fileformat'.
///
/// @param eol_style End-of-line style.
/// @param opt_flags OPT_LOCAL and/or OPT_GLOBAL
void set_fileformat(int eol_style, int opt_flags)
{
  char *p = NULL;

  switch (eol_style) {
  case EOL_UNIX:
    p = "unix";
    break;
  case EOL_MAC:
    p = "mac";
    break;
  case EOL_DOS:
    p = "dos";
    break;
  }

  // p is NULL if "eol_style" is EOL_UNKNOWN.
  if (p != NULL) {
    set_option_direct(kOptFileformat, CSTR_AS_OPTVAL(p), opt_flags, 0);
  }

  // This may cause the buffer to become (un)modified.
  redraw_buf_status_later(curbuf);
  redraw_tabline = true;
  need_maketitle = true;  // Set window title later.
}

/// Skip to next part of an option argument: skip space and comma
char *skip_to_option_part(const char *p)
{
  if (*p == ',') {
    p++;
  }
  while (*p == ' ') {
    p++;
  }
  return (char *)p;
}

/// Isolate one part of a string option separated by `sep_chars`.
///
/// @param[in,out]  option    advanced to the next part
/// @param[in,out]  buf       copy of the isolated part
/// @param[in]      maxlen    length of `buf`
/// @param[in]      sep_chars chars that separate the option parts
///
/// @return length of `*option`
size_t copy_option_part(char **option, char *buf, size_t maxlen, char *sep_chars)
{
  size_t len = 0;
  char *p = *option;

  // skip '.' at start of option part, for 'suffixes'
  if (*p == '.') {
    buf[len++] = *p++;
  }
  while (*p != NUL && vim_strchr(sep_chars, (uint8_t)(*p)) == NULL) {
    // Skip backslash before a separator character and space.
    if (p[0] == '\\' && vim_strchr(sep_chars, (uint8_t)p[1]) != NULL) {
      p++;
    }
    if (len < maxlen - 1) {
      buf[len++] = *p;
    }
    p++;
  }
  buf[len] = NUL;

  if (*p != NUL && *p != ',') {  // skip non-standard separator
    p++;
  }
  p = skip_to_option_part(p);    // p points to next file name

  *option = p;
  return len;
}

/// Return true when 'shell' has "csh" in the tail.
int csh_like_shell(void)
{
  return strstr(path_tail(p_sh), "csh") != NULL;
}

/// Return true when 'shell' has "fish" in the tail.
bool fish_like_shell(void)
{
  return strstr(path_tail(p_sh), "fish") != NULL;
}

/// Get window or buffer local options
dict_T *get_winbuf_options(const int bufopt)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  dict_T *const d = tv_dict_alloc();

  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    vimoption_T *opt = &options[opt_idx];

    if ((bufopt && (option_has_scope(opt_idx, kOptScopeBuf)))
        || (!bufopt && (option_has_scope(opt_idx, kOptScopeWin)))) {
      void *varp = get_varp(opt);

      if (varp != NULL) {
        typval_T opt_tv = optval_as_tv(optval_from_varp(opt_idx, varp), true);
        tv_dict_add_tv(d, opt->fullname, strlen(opt->fullname), &opt_tv);
      }
    }
  }

  return d;
}

/// Return the effective 'scrolloff' value for the current window, using the
/// global value when appropriate.
int get_scrolloff_value(win_T *wp)
{
  // Disallow scrolloff in terminal-mode. #11915
  if (State & MODE_TERMINAL) {
    return 0;
  }
  return (int)(wp->w_p_so < 0 ? p_so : wp->w_p_so);
}

/// Return the effective 'sidescrolloff' value for the current window, using the
/// global value when appropriate.
int get_sidescrolloff_value(win_T *wp)
{
  return (int)(wp->w_p_siso < 0 ? p_siso : wp->w_p_siso);
}

Dict get_vimoption(String name, int scope, buf_T *buf, win_T *win, Arena *arena, Error *err)
{
  OptIndex opt_idx = find_option_len(name.data, name.size);
  VALIDATE_S(opt_idx != kOptInvalid, "option (not found)", name.data, {
    return (Dict)ARRAY_DICT_INIT;
  });

  return vimoption2dict(&options[opt_idx], scope, buf, win, arena);
}

Dict get_all_vimoptions(Arena *arena)
{
  Dict retval = arena_dict(arena, kOptCount);
  for (OptIndex opt_idx = 0; opt_idx < kOptCount; opt_idx++) {
    Dict opt_dict = vimoption2dict(&options[opt_idx], OPT_GLOBAL, curbuf, curwin, arena);
    PUT_C(retval, options[opt_idx].fullname, DICT_OBJ(opt_dict));
  }
  return retval;
}

static Dict vimoption2dict(vimoption_T *opt, int req_scope, buf_T *buf, win_T *win, Arena *arena)
{
  OptIndex opt_idx = get_opt_idx(opt);
  Dict dict = arena_dict(arena, 13);

  PUT_C(dict, "name", CSTR_AS_OBJ(opt->fullname));
  PUT_C(dict, "shortname", CSTR_AS_OBJ(opt->shortname));

  const char *scope;
  if (option_has_scope(opt_idx, kOptScopeBuf)) {
    scope = "buf";
  } else if (option_has_scope(opt_idx, kOptScopeWin)) {
    scope = "win";
  } else {
    scope = "global";
  }

  PUT_C(dict, "scope", CSTR_AS_OBJ(scope));

  // welcome to the jungle
  PUT_C(dict, "global_local", BOOLEAN_OBJ(option_is_global_local(opt_idx)));
  PUT_C(dict, "commalist", BOOLEAN_OBJ(opt->flags & kOptFlagComma));
  PUT_C(dict, "flaglist", BOOLEAN_OBJ(opt->flags & kOptFlagFlagList));

  PUT_C(dict, "was_set", BOOLEAN_OBJ(opt->flags & kOptFlagWasSet));

  LastSet last_set = { .channel_id = 0 };
  if (req_scope == OPT_GLOBAL) {
    last_set = opt->last_set;
  } else {
    // Scope is either OPT_LOCAL or a fallback mode was requested.
    if (option_has_scope(opt_idx, kOptScopeBuf)) {
      last_set = buf->b_p_script_ctx[opt->scope_idx[kOptScopeBuf]];
    }
    if (option_has_scope(opt_idx, kOptScopeWin)) {
      last_set = win->w_p_script_ctx[opt->scope_idx[kOptScopeWin]];
    }
    if (req_scope != OPT_LOCAL && last_set.script_ctx.sc_sid == 0) {
      last_set = opt->last_set;
    }
  }

  PUT_C(dict, "last_set_sid", INTEGER_OBJ(last_set.script_ctx.sc_sid));
  PUT_C(dict, "last_set_linenr", INTEGER_OBJ(last_set.script_ctx.sc_lnum));
  PUT_C(dict, "last_set_chan", INTEGER_OBJ((int64_t)last_set.channel_id));

  PUT_C(dict, "type", CSTR_AS_OBJ(optval_type_get_name(option_get_type(get_opt_idx(opt)))));
  PUT_C(dict, "default", optval_as_object(opt->def_val));
  PUT_C(dict, "allows_duplicates", BOOLEAN_OBJ(!(opt->flags & kOptFlagNoDup)));

  return dict;
}
