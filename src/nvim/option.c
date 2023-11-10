// User-settable options. Checklist for adding a new option:
// - Put it in options.lua
// - For a global option: Add a variable for it in option_defs.h.
// - For a buffer or window local option:
//   - Add a BV_XX or WV_XX entry to option_defs.h
//   - Add a variable to the window or buffer struct in buffer_defs.h.
//   - For a window option, add some code to copy_winopt().
//   - For a window string option, add code to check_winopt()
//     and clear_winopt(). If setting the option needs parsing,
//     add some code to didset_window_options().
//   - For a buffer option, add some code to buf_copy_options().
//   - For a buffer string option, add code to check_buf_options().
// - If it's a numeric option, add any necessary bounds checks to check_num_option_bounds().
// - If it's a list of flags, add some code in do_set(), search for WW_ALL.
// - Add documentation! doc/options.txt, and any other related places.
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
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/macros.h"
#include "nvim/mapping.h"
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
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/sign_defs.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/terminal.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"
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
static const char e_key_code_not_set[]
  = N_("E846: Key code not set");
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

// options[] is initialized here.
// The order of the options MUST be alphabetic for ":set all" and findoption().
// All option names MUST start with a lowercase letter (for findoption()).
// Exception: "t_" options are at the end.
// The options with a NULL variable are 'hidden': a set command for them is
// ignored and they are not printed.

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "options.generated.h"
#endif

static char *(p_bin_dep_opts[]) = {
  "textwidth", "wrapmargin", "modeline", "expandtab", NULL
};
static char *(p_paste_dep_opts[]) = {
  "autoindent", "expandtab", "ruler", "showmatch", "smarttab",
  "softtabstop", "textwidth", "wrapmargin", "revins", "varsofttabstop", NULL
};

void set_init_tablocal(void)
{
  // susy baka: cmdheight calls itself OPT_GLOBAL but is really tablocal!
  int ch_idx = findoption("cmdheight");
  p_ch = (OptInt)(intptr_t)options[ch_idx].def_val;
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
      set_string_default("sh", cmd, true);
    } else {
      set_string_default("sh", (char *)shell, false);
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
  int opt_idx = findoption("backupskip");

  ga_init(&ga, 1, 100);
  for (size_t n = 0; n < ARRAY_SIZE(names); n++) {
    bool mustfree = true;
    char *p;
#ifdef UNIX
    if (*names[n] == NUL) {
# ifdef __APPLE__
      p = "/private/tmp";
# else
      p = "/tmp";
# endif
      mustfree = false;
    } else  // NOLINT(readability/braces)
#endif
    {
      p = vim_getenv(names[n]);
    }
    if (p != NULL && *p != NUL) {
      // First time count the NUL, otherwise count the ','.
      const size_t len = strlen(p) + 3;
      char *item = xmalloc(len);
      xstrlcpy(item, p, len);
      add_pathsep(item);
      xstrlcat(item, "*", len);
      if (find_dup_item(ga.ga_data, item, options[opt_idx].flags)
          == NULL) {
        ga_grow(&ga, (int)len);
        if (!GA_EMPTY(&ga)) {
          STRCAT(ga.ga_data, ",");
        }
        STRCAT(ga.ga_data, p);
        add_pathsep(ga.ga_data);
        STRCAT(ga.ga_data, "*");
        ga.ga_len += (int)len;
      }
      xfree(item);
    }
    if (mustfree) {
      xfree(p);
    }
  }
  if (ga.ga_data != NULL) {
    set_string_default("bsk", ga.ga_data, true);
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
  int opt_idx = findoption("cdpath");
  if (opt_idx >= 0) {
    options[opt_idx].def_val = buf;
    options[opt_idx].flags |= P_DEF_ALLOCED;
  } else {
    xfree(buf);           // cannot happen
  }
  xfree(cdpath);
}

/// Expand environment variables and things like "~" for the defaults.
/// If option_expand() returns non-NULL the variable is expanded.  This can
/// only happen for non-indirect options.
/// Also set the default to the expanded value, so ":set" does not list
/// them.
/// Don't set the P_ALLOCED flag, because we don't want to free the
/// default.
static void set_init_expand_env(void)
{
  for (int opt_idx = 0; options[opt_idx].fullname; opt_idx++) {
    vimoption_T *opt = &options[opt_idx];
    if (opt->flags & P_NO_DEF_EXP) {
      continue;
    }
    char *p;
    if ((opt->flags & P_GETTEXT) && opt->var != NULL) {
      p = _(*(char **)opt->var);
    } else {
      p = option_expand(opt_idx, NULL);
    }
    if (p != NULL) {
      p = xstrdup(p);
      *(char **)opt->var = p;
      if (opt->flags & P_DEF_ALLOCED) {
        xfree(opt->def_val);
      }
      opt->def_val = p;
      opt->flags |= P_DEF_ALLOCED;
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

  set_init_default_shell();
  set_init_default_backupskip();
  set_init_default_cdpath();

  char *backupdir = stdpaths_user_state_subpath("backup", 2, true);
  const size_t backupdir_len = strlen(backupdir);
  backupdir = xrealloc(backupdir, backupdir_len + 3);
  memmove(backupdir + 2, backupdir, backupdir_len + 1);
  memmove(backupdir, ".,", 2);
  set_string_default("backupdir", backupdir, true);
  set_string_default("viewdir", stdpaths_user_state_subpath("view", 2, true),
                     true);
  set_string_default("directory", stdpaths_user_state_subpath("swap", 2, true),
                     true);
  set_string_default("undodir", stdpaths_user_state_subpath("undo", 2, true),
                     true);
  // Set default for &runtimepath. All necessary expansions are performed in
  // this function.
  char *rtp = runtimepath_default(clean_arg);
  if (rtp) {
    set_string_default("runtimepath", rtp, true);
    // Make a copy of 'rtp' for 'packpath'
    set_string_default("packpath", rtp, false);
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

  // Set all options to their default value
  set_options_default(OPT_FREE);

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
    set_option_value_give_err("tbidi", BOOLEAN_OPTVAL(true), 0);
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

/// Set an option to its default value.
/// This does not take care of side effects!
///
/// @param opt_flags OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL
static void set_option_default(const int opt_idx, int opt_flags)
{
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;

  // pointer to variable for current option
  vimoption_T *opt = &options[opt_idx];
  void *varp = get_varp_scope(opt, both ? OPT_LOCAL : opt_flags);
  uint32_t flags = opt->flags;
  if (varp != NULL) {       // skip hidden option, nothing to do for it
    if (flags & P_STRING) {
      // Use set_string_option_direct() for local options to handle
      // freeing and allocating the value.
      if (opt->indir != PV_NONE) {
        set_string_option_direct(NULL, opt_idx, opt->def_val, opt_flags, 0);
      } else {
        if ((opt_flags & OPT_FREE) && (flags & P_ALLOCED)) {
          free_string_option(*(char **)(varp));
        }
        *(char **)varp = opt->def_val;
        opt->flags &= ~P_ALLOCED;
      }
    } else if (flags & P_NUM) {
      if (opt->indir == PV_SCROLL) {
        win_comp_scroll(curwin);
      } else {
        OptInt def_val = (OptInt)(intptr_t)opt->def_val;
        if ((OptInt *)varp == &curwin->w_p_so
            || (OptInt *)varp == &curwin->w_p_siso) {
          // 'scrolloff' and 'sidescrolloff' local values have a
          // different default value than the global default.
          *(OptInt *)varp = -1;
        } else {
          *(OptInt *)varp = def_val;
        }
        // May also set global value for local option.
        if (both) {
          *(OptInt *)get_varp_scope(opt, OPT_GLOBAL) = def_val;
        }
      }
    } else {  // P_BOOL
      *(int *)varp = (int)(intptr_t)opt->def_val;
#ifdef UNIX
      // 'modeline' defaults to off for root
      if (opt->indir == PV_ML && getuid() == ROOT_UID) {
        *(int *)varp = false;
      }
#endif
      // May also set global value for local option.
      if (both) {
        *(int *)get_varp_scope(opt, OPT_GLOBAL) =
          *(int *)varp;
      }
    }

    // The default value is not insecure.
    uint32_t *flagsp = insecure_flag(curwin, opt_idx, opt_flags);
    *flagsp = *flagsp & ~P_INSECURE;
  }

  set_option_sctx_idx(opt_idx, opt_flags, current_sctx);
}

/// Set all options (except terminal options) to their default value.
///
/// @param opt_flags  OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL
static void set_options_default(int opt_flags)
{
  for (int i = 0; options[i].fullname; i++) {
    if (!(options[i].flags & P_NODEFAULT)) {
      set_option_default(i, opt_flags);
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
/// @param name The name of the option
/// @param val The value of the option
/// @param allocated If true, do not copy default as it was already allocated.
static void set_string_default(const char *name, char *val, bool allocated)
  FUNC_ATTR_NONNULL_ALL
{
  int opt_idx = findoption(name);
  if (opt_idx >= 0) {
    vimoption_T *opt = &options[opt_idx];
    if (opt->flags & P_DEF_ALLOCED) {
      xfree(opt->def_val);
    }

    opt->def_val = allocated ? val : xstrdup(val);
    opt->flags |= P_DEF_ALLOCED;
  }
}

/// For an option value that contains comma separated items, find "newval" in
/// "origval".  Return NULL if not found.
static char *find_dup_item(char *origval, const char *newval, uint32_t flags)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (origval == NULL) {
    return NULL;
  }

  int bs = 0;

  const size_t newlen = strlen(newval);
  for (char *s = origval; *s != NUL; s++) {
    if ((!(flags & P_COMMA) || s == origval || (s[-1] == ',' && !(bs & 1)))
        && strncmp(s, newval, newlen) == 0
        && (!(flags & P_COMMA) || s[newlen] == ',' || s[newlen] == NUL)) {
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

/// Set the Vi-default value of a number option.
/// Used for 'lines' and 'columns'.
void set_number_default(char *name, OptInt val)
{
  int opt_idx = findoption(name);
  if (opt_idx >= 0) {
    options[opt_idx].def_val = (void *)(intptr_t)val;
  }
}

#if defined(EXITFREE)
/// Free all options.
void free_all_options(void)
{
  for (int i = 0; options[i].fullname; i++) {
    if (options[i].indir == PV_NONE) {
      // global option: free value and default value.
      if ((options[i].flags & P_ALLOCED) && options[i].var != NULL) {
        optval_free(optval_from_varp(i, options[i].var));
      }
      if (options[i].flags & P_DEF_ALLOCED) {
        optval_free(optval_from_varp(i, &options[i].def_val));
      }
    } else if (options[i].var != VAR_WIN) {
      // buffer-local option: free global value
      optval_free(optval_from_varp(i, options[i].var));
    }
  }
  free_operatorfunc_option();
  free_tagfunc_option();
}
#endif

/// Initialize the options, part two: After getting Rows and Columns.
void set_init_2(bool headless)
{
  // set in set_init_1 but logging is not allowed there
  ILOG("startup runtimepath/packpath value: %s", p_rtp);

  // 'scroll' defaults to half the window height. The stored default is zero,
  // which results in the actual value computed from the window height.
  int idx = findoption("scroll");
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET)) {
    set_option_default(idx, OPT_LOCAL);
  }
  comp_col();

  // 'window' is only for backwards compatibility with Vi.
  // Default is Rows - 1.
  if (!option_was_set("window")) {
    p_window = Rows - 1;
  }
  set_number_default("window", Rows - 1);
}

/// Initialize the options, part three: After reading the .vimrc
void set_init_3(void)
{
  parse_shape_opt(SHAPE_CURSOR);   // set cursor shapes from 'guicursor'

  // Set 'shellpipe' and 'shellredir', depending on the 'shell' option.
  // This is done after other initializations, where 'shell' might have been
  // set, but only if they have not been set before.
  int idx_srr = findoption("srr");
  int do_srr = (idx_srr < 0)
    ? false
    : !(options[idx_srr].flags & P_WAS_SET);
  int idx_sp = findoption("sp");
  int do_sp = (idx_sp < 0)
    ? false
    : !(options[idx_sp].flags & P_WAS_SET);

  size_t len = 0;
  char *p = (char *)invocation_path_tail(p_sh, &len);
  p = xmemdupz(p, len);

  {
    //
    // Default for p_sp is "| tee", for p_srr is ">".
    // For known shells it is changed here to include stderr.
    //
    if (path_fnamecmp(p, "csh") == 0
        || path_fnamecmp(p, "tcsh") == 0) {
      if (do_sp) {
        p_sp = "|& tee";
        options[idx_sp].def_val = p_sp;
      }
      if (do_srr) {
        p_srr = ">&";
        options[idx_srr].def_val = p_srr;
      }
    } else if (path_fnamecmp(p, "sh") == 0
               || path_fnamecmp(p, "ksh") == 0
               || path_fnamecmp(p, "mksh") == 0
               || path_fnamecmp(p, "pdksh") == 0
               || path_fnamecmp(p, "zsh") == 0
               || path_fnamecmp(p, "zsh-beta") == 0
               || path_fnamecmp(p, "bash") == 0
               || path_fnamecmp(p, "fish") == 0
               || path_fnamecmp(p, "ash") == 0
               || path_fnamecmp(p, "dash") == 0) {
      // Always use POSIX shell style redirection if we reach this
      if (do_sp) {
        p_sp = "2>&1| tee";
        options[idx_sp].def_val = p_sp;
      }
      if (do_srr) {
        p_srr = ">%s 2>&1";
        options[idx_srr].def_val = p_srr;
      }
    }
    xfree(p);
  }

  if (buf_is_empty(curbuf)) {
    int idx_ffs = findoption_len(S_LEN("ffs"));

    // Apply the first entry of 'fileformats' to the initial buffer.
    if (idx_ffs >= 0 && (options[idx_ffs].flags & P_WAS_SET)) {
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
  int idx = findoption("hlg");
  if (idx < 0 || (options[idx].flags & P_WAS_SET)) {
    return;
  }

  if (options[idx].flags & P_ALLOCED) {
    free_string_option(p_hlg);
  }
  p_hlg = xmemdupz(lang, lang_len);
  // zh_CN becomes "cn", zh_TW becomes "tw".
  if (STRNICMP(p_hlg, "zh_", 3) == 0 && strlen(p_hlg) >= 5) {
    p_hlg[0] = (char)TOLOWER_ASC(p_hlg[3]);
    p_hlg[1] = (char)TOLOWER_ASC(p_hlg[4]);
  } else if (strlen(p_hlg) >= 1 && *p_hlg == 'C') {
    // any C like setting, such as C.UTF-8, becomes "en"
    p_hlg[0] = 'e';
    p_hlg[1] = 'n';
  }
  p_hlg[2] = NUL;
  options[idx].flags |= P_ALLOCED;
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
  int idx1 = findoption("title");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val = 0;
    p_title = 0;
  }
  idx1 = findoption("icon");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val = 0;
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
  (void)do_set(eap->arg, flags);
}

/// Get the default value for a string option.
static char *stropt_get_default_val(int opt_idx, uint64_t flags)
{
  char *newval = options[opt_idx].def_val;
  // expand environment variables and ~ since the default value was
  // already expanded, only required when an environment variable was set
  // later
  if (newval == NULL) {
    newval = empty_string_option;
  } else if (!(options[opt_idx].flags & P_NO_DEF_EXP)) {
    char *s = option_expand(opt_idx, newval);
    if (s == NULL) {
      s = newval;
    }
    newval = xstrdup(s);
  } else {
    newval = xstrdup(newval);
  }
  return newval;
}

/// Copy the new string value into allocated memory for the option.
/// Can't use set_string_option_direct(), because we need to remove the
/// backslashes.
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
        && !((flags & P_EXPAND)
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
static char *stropt_expand_envvar(int opt_idx, char *origval, char *newval, set_op_T op)
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
  int comma = ((flags & P_COMMA) && *origval != NUL && *newval != NUL);
  if (op == OP_ADDING) {
    len = (int)strlen(origval);
    // Strip a trailing comma, would get 2.
    if (comma && len > 1
        && (flags & P_ONECOMMA) == P_ONECOMMA
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
    if (flags & P_COMMA) {
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
    // if options have P_FLAGLIST and P_ONECOMMA such as 'whichwrap'
    if (flags & P_ONECOMMA) {
      if (*s != ',' && *(s + 1) == ','
          && vim_strchr(s + 2, (uint8_t)(*s)) != NULL) {
        // Remove the duplicated value and the next comma.
        STRMOVE(s, s + 2);
        continue;
      }
    } else {
      if ((!(flags & P_COMMA) || *s != ',')
          && vim_strchr(s + 1, (uint8_t)(*s)) != NULL) {
        STRMOVE(s, s + 1);
        continue;
      }
    }
    s++;
  }
}

/// Get the string value specified for a ":set" command.  The following set
/// options are supported:
///     set {opt}&
///     set {opt}<
///     set {opt}={val}
///     set {opt}:{val}
static char *stropt_get_newval(int nextchar, int opt_idx, char **argp, void *varp, char *origval,
                               set_op_T *op_arg, uint32_t flags)
{
  char *arg = *argp;
  set_op_T op = *op_arg;
  char *save_arg = NULL;
  char *newval;
  char *s = NULL;
  if (nextchar == '&') {  // set to default val
    newval = stropt_get_default_val(opt_idx, flags);
  } else if (nextchar == '<') {  // set to global val
    newval = xstrdup(*(char **)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL));
  } else {
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
    if (op == OP_NONE || (flags & P_COMMA)) {
      newval = stropt_expand_envvar(opt_idx, origval, newval, op);
    }

    // locate newval[] in origval[] when removing it
    // and when adding to avoid duplicates
    int len = 0;
    if (op == OP_REMOVING || (flags & P_NODUP)) {
      len = (int)strlen(newval);
      s = find_dup_item(origval, newval, flags);

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

    if (flags & P_FLAGLIST) {
      // Remove flags that appear twice.
      stropt_remove_dupflags(newval, flags);
    }
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

/// @param[in]   arg       Pointer to start option name
/// @param[out]  opt_idxp  Option index in options[] table.
/// @param[out]  keyp
/// @param[out]  len       Length of option name
/// @return  FAIL if an error is detected, OK otherwise
static int parse_option_name(char *arg, int *keyp, int *lenp, int *opt_idxp)
{
  // find end of name
  int key = 0;
  int len;
  int opt_idx;

  if (*arg == '<') {
    opt_idx = -1;
    // look out for <t_>;>
    if (arg[1] == 't' && arg[2] == '_' && arg[3] && arg[4]) {
      len = 5;
    } else {
      len = 1;
      while (arg[len] != NUL && arg[len] != '>') {
        len++;
      }
    }
    if (arg[len] != '>') {
      return FAIL;
    }
    if (arg[1] == 't' && arg[2] == '_') {  // could be term code
      opt_idx = findoption_len(arg + 1, (size_t)(len - 1));
    }
    len++;
    if (opt_idx == -1) {
      key = find_key_option(arg + 1, true);
    }
  } else {
    // The two characters after "t_" may not be alphanumeric.
    if (arg[0] == 't' && arg[1] == '_' && arg[2] && arg[3]) {
      len = 4;
    } else {
      len = 0;
      while (ASCII_ISALNUM(arg[len]) || arg[len] == '_') {
        len++;
      }
    }
    opt_idx = findoption_len(arg, (size_t)len);
    if (opt_idx == -1) {
      key = find_key_option(arg, false);
    }
  }

  *keyp = key;
  *lenp = len;
  *opt_idxp = opt_idx;

  return OK;
}

static int validate_opt_idx(win_T *win, int opt_idx, int opt_flags, uint32_t flags,
                            set_prefix_T prefix, const char **errmsg)
{
  // Only bools can have a prefix of 'inv' or 'no'
  if (!(flags & P_BOOL) && prefix != PREFIX_NONE) {
    *errmsg = e_invarg;
    return FAIL;
  }

  // Skip all options that are not window-local (used when showing
  // an already loaded buffer in a window).
  if ((opt_flags & OPT_WINONLY)
      && (opt_idx < 0 || options[opt_idx].var != VAR_WIN)) {
    return FAIL;
  }

  // Skip all options that are window-local (used for :vimgrep).
  if ((opt_flags & OPT_NOWIN) && opt_idx >= 0
      && options[opt_idx].var == VAR_WIN) {
    return FAIL;
  }

  // Disallow changing some options from modelines.
  if (opt_flags & OPT_MODELINE) {
    if (flags & (P_SECURE | P_NO_ML)) {
      *errmsg = e_not_allowed_in_modeline;
      return FAIL;
    }
    if ((flags & P_MLE) && !p_mle) {
      *errmsg = e_not_allowed_in_modeline_when_modelineexpr_is_off;
      return FAIL;
    }
    // In diff mode some options are overruled.  This avoids that
    // 'foldmethod' becomes "marker" instead of "diff" and that
    // "wrap" gets set.
    if (win->w_p_diff
        && opt_idx >= 0              // shut up coverity warning
        && (options[opt_idx].indir == PV_FDM
            || options[opt_idx].indir == PV_WRAP)) {
      return FAIL;
    }
  }

  // Disallow changing some options in the sandbox
  if (sandbox != 0 && (flags & P_SECURE)) {
    *errmsg = e_sandbox;
    return FAIL;
  }

  return OK;
}

/// Get new option value from argp. Allocated OptVal must be freed by caller.
static OptVal get_option_newval(int opt_idx, int opt_flags, set_prefix_T prefix, char **argp,
                                int nextchar, set_op_T op, uint32_t flags, void *varp, char *errbuf,
                                const size_t errbuflen, const char **errmsg)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(varp != NULL);

  vimoption_T *opt = &options[opt_idx];
  char *arg = *argp;
  // When setting the local value of a global option, the old value may be the global value.
  const bool oldval_is_global = ((int)opt->indir & PV_BOTH) && (opt_flags & OPT_LOCAL);
  OptVal oldval = optval_from_varp(opt_idx, oldval_is_global ? get_varp(opt) : varp);
  OptVal newval = NIL_OPTVAL;

  switch (oldval.type) {
  case kOptValTypeNil:
    abort();
  case kOptValTypeBoolean: {
    TriState newval_bool;

    // ":set opt!": invert
    // ":set opt&": reset to default value
    // ":set opt<": reset to global value
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
    } else if (nextchar == '&') {
      newval_bool = TRISTATE_FROM_INT((int)(intptr_t)options[opt_idx].def_val);
    } else if (nextchar == '<') {
      // For 'autoread', kNone means to use global value.
      if ((int *)varp == &curbuf->b_p_ar && opt_flags == OPT_LOCAL) {
        newval_bool = kNone;
      } else {
        newval_bool = TRISTATE_FROM_INT(*(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL));
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
    // &            set to default value
    // <            set to global value
    // <xx>         accept special key codes for 'wildchar'
    // c            accept any non-digit for 'wildchar'
    // [-]0-9       set number
    // other        error
    arg++;
    if (nextchar == '&') {
      newval_num = (OptInt)(intptr_t)options[opt_idx].def_val;
    } else if (nextchar == '<') {
      if ((OptInt *)varp == &curbuf->b_p_ul && opt_flags == OPT_LOCAL) {
        // for 'undolevels' NO_LOCAL_UNDOLEVEL means using the global newval_num
        newval_num = NO_LOCAL_UNDOLEVEL;
      } else if (opt_flags == OPT_LOCAL
                 && ((OptInt *)varp == &curwin->w_p_siso || (OptInt *)varp == &curwin->w_p_so)) {
        // for 'scrolloff'/'sidescrolloff' -1 means using the global newval_num
        newval_num = -1;
      } else {
        newval_num = *(OptInt *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);
      }
    } else if (((OptInt *)varp == &p_wc || (OptInt *)varp == &p_wcm)
               && (*arg == '<' || *arg == '^'
                   || (*arg != NUL && (!arg[1] || ascii_iswhite(arg[1]))
                       && !ascii_isdigit(*arg)))) {
      newval_num = string_to_key(arg);
      if (newval_num == 0 && (OptInt *)varp != &p_wcm) {
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
  int key = 0;
  int len;
  int opt_idx;
  if (parse_option_name(arg, &key, &len, &opt_idx) == FAIL) {
    *errmsg = e_invarg;
    return;
  }

  // remember character after option name
  int afterchar = (uint8_t)arg[len];

  // skip white space, allow ":set ai  ?"
  while (ascii_iswhite(arg[len])) {
    len++;
  }

  set_op_T op = get_op(arg + len);
  if (op != OP_NONE) {
    len++;
  }

  uint8_t nextchar = (uint8_t)arg[len];  // next non-white char after option name

  if (opt_idx == -1 && key == 0) {          // found a mismatch: skip
    *errmsg = e_unknown_option;
    return;
  }

  uint32_t flags;  // flags for current option
  void *varp = NULL;  // pointer to variable for current option

  if (opt_idx >= 0) {
    if (options[opt_idx].var == NULL) {         // hidden option: skip
      // Only give an error message when requesting the value of
      // a hidden option, ignore setting it.
      if (vim_strchr("=:!&<", nextchar) == NULL
          && (!(options[opt_idx].flags & P_BOOL)
              || nextchar == '?')) {
        *errmsg = e_unsupportedoption;
      }
      return;
    }

    flags = options[opt_idx].flags;
    varp = get_varp_scope(&(options[opt_idx]), opt_flags);
  } else {
    flags = P_STRING;
  }

  if (validate_opt_idx(curwin, opt_idx, opt_flags, flags, prefix, errmsg) == FAIL) {
    return;
  }

  if (vim_strchr("?=:!&<", nextchar) != NULL) {
    *argp += len;
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

  //
  // allow '=' and ':' as MS-DOS command.com allows only one
  // '=' character per "set" command line. grrr. (jw)
  //
  if (nextchar == '?'
      || (prefix == PREFIX_NONE
          && vim_strchr("=:&<", nextchar) == NULL
          && !(flags & P_BOOL))) {
    // print value
    if (*did_show) {
      msg_putchar('\n');                // cursor below last one
    } else {
      gotocmdline(true);                // cursor at status line
      *did_show = true;                 // remember that we did a line
    }
    if (opt_idx >= 0) {
      showoneopt(&options[opt_idx], opt_flags);
      if (p_verbose > 0) {
        // Mention where the option was last set.
        if (varp == options[opt_idx].var) {
          option_last_set_msg(options[opt_idx].last_set);
        } else if ((int)options[opt_idx].indir & PV_WIN) {
          option_last_set_msg(curwin->w_p_script_ctx[(int)options[opt_idx].indir & PV_MASK]);
        } else if ((int)options[opt_idx].indir & PV_BUF) {
          option_last_set_msg(curbuf->b_p_script_ctx[(int)options[opt_idx].indir & PV_MASK]);
        }
      }
    } else {
      *errmsg = e_key_code_not_set;
      return;
    }
    if (nextchar != '?' && nextchar != NUL && !ascii_iswhite(afterchar)) {
      *errmsg = e_trailing;
    }
    return;
  }

  if (flags & P_BOOL) {
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

  // Don't try to change hidden option.
  if (varp == NULL) {
    return;
  }

  OptVal newval = get_option_newval(opt_idx, opt_flags, prefix, argp, nextchar, op, flags, varp,
                                    errbuf, errbuflen, errmsg);

  if (newval.type == kOptValTypeNil || *errmsg != NULL) {
    return;
  }

  *errmsg = set_option(opt_idx, varp, newval, opt_flags, op == OP_NONE, errbuf, errbuflen);
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
          set_options_default(OPT_FREE | opt_flags);
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
        char errbuf[80];

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
          xstrlcpy(IObuff, _(errmsg), IOSIZE);
          int i = (int)strlen(IObuff) + 2;
          if (i + (arg - startarg) < IOSIZE) {
            // append the argument with the error
            xstrlcat(IObuff, ": ", IOSIZE);
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
    info_message = true;        // use os_msg(), not os_errmsg()
    msg_putchar('\n');
    silent_mode = true;
    info_message = false;       // use os_msg(), not os_errmsg()
  }

  return OK;
}

/// Convert a key name or string into a key value.
/// Used for 'wildchar' and 'cedit' options.
int string_to_key(char *arg)
{
  if (*arg == '<') {
    return find_key_option(arg + 1, true);
  }
  if (*arg == '^') {
    return CTRL_CHR((uint8_t)arg[1]);
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
static char *option_expand(int opt_idx, char *val)
{
  // if option doesn't need expansion nothing to do
  if (!(options[opt_idx].flags & P_EXPAND) || options[opt_idx].var == NULL) {
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
                 (char **)options[opt_idx].var == &p_sps ? "file:" :
                 NULL);
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
  (void)init_chartab();

  didset_string_options();

  (void)spell_check_msm();
  (void)spell_check_sps();
  (void)compile_cap_prog(curwin->w_s);
  (void)did_set_spell_option(true);
  // set cedit_key
  (void)did_set_cedit(NULL);
  // initialize the table for 'breakat'.
  (void)did_set_breakat(NULL);
  didset_window_options(curwin, true);
}

// More side effects of setting options.
static void didset_options2(void)
{
  // Initialize the highlight_attr[] table.
  highlight_changed();

  // Parse default for 'fillchars'.
  (void)set_fillchars_option(curwin, curwin->w_p_fcs, true);

  // Parse default for 'listchars'.
  (void)set_listchars_option(curwin, curwin->w_p_lcs, true);

  // Parse default for 'wildmode'.
  check_opt_wim();
  xfree(curbuf->b_p_vsts_array);
  (void)tabstop_set(curbuf->b_p_vsts, &curbuf->b_p_vsts_array);
  xfree(curbuf->b_p_vts_array);
  (void)tabstop_set(curbuf->b_p_vts,  &curbuf->b_p_vts_array);
}

/// Check for string options that are NULL (normally only termcap options).
void check_options(void)
{
  for (int opt_idx = 0; options[opt_idx].fullname != NULL; opt_idx++) {
    if ((options[opt_idx].flags & P_STRING) && options[opt_idx].var != NULL) {
      check_string_option((char **)get_varp(&(options[opt_idx])));
    }
  }
}

/// Return true when option "opt" was set from a modeline or in secure mode.
/// Return false when it wasn't.
/// Return -1 for an unknown option.
int was_set_insecurely(win_T *const wp, char *opt, int opt_flags)
{
  int idx = findoption(opt);

  if (idx >= 0) {
    uint32_t *flagp = insecure_flag(wp, idx, opt_flags);
    return (*flagp & P_INSECURE) != 0;
  }
  internal_error("was_set_insecurely()");
  return -1;
}

/// Get a pointer to the flags used for the P_INSECURE flag of option
/// "opt_idx".  For some local options a local flags field is used.
/// NOTE: Caller must make sure that "wp" is set to the window from which
/// the option is used.
uint32_t *insecure_flag(win_T *const wp, int opt_idx, int opt_flags)
{
  if (opt_flags & OPT_LOCAL) {
    assert(wp != NULL);
    switch ((int)options[opt_idx].indir) {
    case PV_STL:
      return &wp->w_p_stl_flags;
    case PV_WBR:
      return &wp->w_p_wbr_flags;
    case PV_FDE:
      return &wp->w_p_fde_flags;
    case PV_FDT:
      return &wp->w_p_fdt_flags;
    case PV_INDE:
      return &wp->w_buffer->b_p_inde_flags;
    case PV_FEX:
      return &wp->w_buffer->b_p_fex_flags;
    case PV_INEX:
      return &wp->w_buffer->b_p_inex_flags;
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
    wp->w_p_winbl > 0 || (wp->w_floating && wp->w_float_config.shadow);
}

/// Handle setting `winhighlight' in window "wp"
bool parse_winhl_opt(win_T *wp)
{
  const char *p = wp->w_p_winhl;

  if (!*p) {
    if (wp->w_ns_hl_winhl && wp->w_ns_hl == wp->w_ns_hl_winhl) {
      wp->w_ns_hl = 0;
      wp->w_hl_needs_update = true;
    }

    return true;
  }

  if (wp->w_ns_hl_winhl == 0) {
    wp->w_ns_hl_winhl = (int)nvim_create_namespace(NULL_STRING);
  } else {
    // namespace already exist. invalidate existing items
    DecorProvider *dp = get_decor_provider(wp->w_ns_hl_winhl, true);
    dp->hl_valid++;
  }
  wp->w_ns_hl = wp->w_ns_hl_winhl;
  int ns_hl = wp->w_ns_hl;

  while (*p) {
    char *colon = strchr(p, ':');
    if (!colon) {
      return false;
    }
    size_t nlen = (size_t)(colon - p);
    char *hi = colon + 1;
    char *commap = xstrchrnul(hi, ',');
    size_t len = (size_t)(commap - hi);
    int hl_id = len ? syn_check_group(hi, len) : -1;
    if (hl_id == 0) {
      return false;
    }
    int hl_id_link = nlen ? syn_check_group(p, nlen) : 0;

    HlAttrs attrs = HLATTRS_INIT;
    attrs.rgb_ae_attr |= HL_GLOBAL;
    ns_hl_def(ns_hl, hl_id_link, attrs, hl_id, NULL);

    p = *commap ? commap + 1 : "";
  }

  wp->w_hl_needs_update = true;
  return true;
}

/// Get the script context of global option "name".
sctx_T *get_option_sctx(const char *const name)
{
  int idx = findoption(name);

  if (idx >= 0) {
    return &options[idx].last_set.script_ctx;
  }
  siemsg("no such option: %s", name);
  return NULL;
}

/// Set the script_ctx for an option, taking care of setting the buffer- or
/// window-local value.
void set_option_sctx_idx(int opt_idx, int opt_flags, sctx_T script_ctx)
{
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int indir = (int)options[opt_idx].indir;
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
  if (both || (opt_flags & OPT_GLOBAL) || (indir & (PV_BUF|PV_WIN)) == 0) {
    options[opt_idx].last_set = last_set;
  }
  if (both || (opt_flags & OPT_LOCAL)) {
    if (indir & PV_BUF) {
      curbuf->b_p_script_ctx[indir & PV_MASK] = last_set;
    } else if (indir & PV_WIN) {
      curwin->w_p_script_ctx[indir & PV_MASK] = last_set;
      if (both) {
        // also setting the "all buffers" value
        curwin->w_allbuf_opt.wo_script_ctx[indir & PV_MASK] = last_set;
      }
    }
  }
}

/// Apply the OptionSet autocommand.
static void apply_optionset_autocmd(int opt_idx, int opt_flags, OptVal oldval, OptVal oldval_g,
                                    OptVal oldval_l, OptVal newval, const char *errmsg)
{
  // Don't do this while starting up, failure or recursively.
  if (starting || errmsg != NULL || *get_vim_var_str(VV_OPTION_TYPE) != NUL) {
    return;
  }

  char buf_type[7];
  typval_T oldval_tv = optval_as_tv(oldval);
  typval_T oldval_g_tv = optval_as_tv(oldval_g);
  typval_T oldval_l_tv = optval_as_tv(oldval_l);
  typval_T newval_tv = optval_as_tv(newval);

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

/// Ensure that options set to p_force_on cannot be disabled.
static const char *did_set_force_on(optset_T *args FUNC_ATTR_UNUSED)
{
  if (p_force_on == false) {
    p_force_on = true;
    return e_unsupportedoption;
  }
  return NULL;
}

/// Ensure that options set to p_force_off cannot be enabled.
static const char *did_set_force_off(optset_T *args FUNC_ATTR_UNUSED)
{
  if (p_force_off == true) {
    p_force_off = false;
    return e_unsupportedoption;
  }
  return NULL;
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
        changed_window_setting();
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

      msg_source(HL_ATTR(HLF_W));
      msg(_(w_arabic), HL_ATTR(HLF_W));
      set_vim_var_string(VV_WARNINGMSG, _(w_arabic), -1);
    }

    // set 'delcombine'
    p_deco = true;

    // Force-set the necessary keymap for arabic.
    errmsg = set_option_value("keymap", STATIC_CSTR_AS_OPTVAL("arabic"), OPT_LOCAL);
  } else {
    // 'arabic' is reset, handle various sub-settings.
    if (!p_tbidi) {
      // reset rightleft mode
      if (win->w_p_rl) {
        win->w_p_rl = false;
        changed_window_setting();
      }

      // 'arabicshape' isn't reset, it is a global option and
      // another window may still need it "on".
    }

    // 'delcombine' isn't reset, it is a global option and another
    // window may still want it "on".

    // Revert to the default keymap
    curbuf->b_p_iminsert = B_IMODE_NONE;
    curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
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

/// Called when the 'breakat' option changes value.
static const char *did_set_breakat(optset_T *args FUNC_ATTR_UNUSED)
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

  if (ui_has(kUIMessages)) {
    p_ch = 0;
  }
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
    buf_T *buf = (buf_T *)args->os_buf;
    win_T *win = (win_T *)args->os_win;
    if (buf->b_help && win->w_height < p_hh) {
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
    (void)win_comp_pos();
    clear_cmdline = true;
  }
  // When switching from global statusline, increase height of topframe by STATUS_HEIGHT
  // in order to to re-add the space that was previously taken by the global statusline
  if (old_value == 3 && value != 3) {
    frame_new_height(topframe, topframe->fr_height + STATUS_HEIGHT, false, false);
    (void)win_comp_pos();
  }

  last_status(false);  // (re)set last window status line.
  return NULL;
}

/// Process the updated 'lisp' option value.
static const char *did_set_lisp(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  // When 'lisp' option changes include/exclude '-' in keyword characters.
  (void)buf_init_chartab(buf, false);          // ignore errors
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
  modified_was_set = (int)args->os_newval.boolean;
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
        (void)tabstop_set(buf->b_p_vsts, &buf->b_p_vsts_array);
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
  p_pb = MAX(MIN(p_pb, 100), 0);
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
  // when 'readonly' is reset globally, also reset readonlymode
  if (!curbuf->b_p_ro && (args->os_flags & OPT_LOCAL) == 0) {
    readonlymode = false;
  }

  // when 'readonly' is set may give W10 again
  if (curbuf->b_p_ro) {
    curbuf->b_did_warn = false;
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
  win->w_scbind_pos = win->w_topline;
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
    // no need to reset curbuf->b_may_swap, ml_open_file() will check
    // buf->b_p_swf
    mf_close_file(buf, true);              // remove the swap file
  }
  return NULL;
}

/// Process the new 'textwidth' option value.
static const char *did_set_textwidth(optset_T *args FUNC_ATTR_UNUSED)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    check_colorcolumn(wp);
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
  // Only take action when the option was set.
  if (!curbuf->b_p_udf && !p_udf) {
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
    if ((curbuf == bp
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
  } else if (pp == &curbuf->b_p_ul) {      // buffer local 'undolevels'
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
    win_T *win = (win_T *)args->os_win;
    if (win->w_height < p_wh) {
      win_setheight((int)p_wh);
    }
  }

  return NULL;
}

/// Process the new 'winwidth' option value.
static const char *did_set_winwidth(optset_T *args)
{
  win_T *win = (win_T *)args->os_win;

  if (!ONE_WINDOW && win->w_width < p_wiw) {
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
static const char *check_num_option_bounds(OptInt *pp, OptInt old_value, char *errbuf,
                                           size_t errbuflen, const char *errmsg)
{
  int old_Rows = Rows;  // remember old Rows
  // Check the (new) bounds for Rows and Columns here.
  if (p_lines < min_rows() && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf(errbuf, errbuflen, _("E593: Need at least %d lines"), min_rows());
      errmsg = errbuf;
    }
    p_lines = min_rows();
  }
  if (p_columns < MIN_COLUMNS && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf(errbuf, errbuflen, _("E594: Need at least %d columns"), MIN_COLUMNS);
      errmsg = errbuf;
    }
    p_columns = MIN_COLUMNS;
  }

  // True max size is defined by check_screensize()
  p_lines = MIN(p_lines, INT_MAX);
  p_columns = MIN(p_columns, INT_MAX);

  // If the screen (shell) height has been changed, assume it is the
  // physical screenheight.
  if (p_lines != Rows || p_columns != Columns) {
    // Changing the screen size is not allowed while updating the screen.
    if (updating_screen) {
      *pp = old_value;
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
    if (p_window >= Rows || !option_was_set("window")) {
      p_window = Rows - 1;
    }
  }

  if ((curwin->w_p_scr <= 0 || (curwin->w_p_scr > curwin->w_height && curwin->w_height > 0))
      && full_screen) {
    if (pp == &(curwin->w_p_scr)) {
      if (curwin->w_p_scr != 0) {
        errmsg = e_scroll;
      }
      win_comp_scroll(curwin);
    } else if (curwin->w_p_scr <= 0) {
      // If 'scroll' became invalid because of a side effect silently adjust it.
      curwin->w_p_scr = 1;
    } else {  // curwin->w_p_scr > curwin->w_height
      curwin->w_p_scr = curwin->w_height;
    }
  }
  if ((p_sj < -100 || p_sj >= Rows) && full_screen) {
    if (Rows != old_Rows) {  // Rows changed, just adjust p_sj
      p_sj = Rows / 2;
    } else {
      errmsg = e_scroll;
      p_sj = 1;
    }
  }

  return errmsg;
}

/// Options that need some validation.
static const char *validate_num_option(const OptInt *pp, OptInt *valuep)
{
  OptInt value = *valuep;

  // Many number options assume their value is in the signed int range.
  if (value < INT_MIN || value > INT_MAX) {
    return e_invarg;
  }

  if (pp == &p_wh) {
    if (value < 1) {
      return e_positive;
    } else if (p_wmh > value) {
      return e_winheight;
    }
  } else if (pp == &p_hh) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_wmh) {
    if (value < 0) {
      return e_positive;
    } else if (value > p_wh) {
      return e_winheight;
    }
  } else if (pp == &p_wiw) {
    if (value < 1) {
      return e_positive;
    } else if (p_wmw > value) {
      return e_winwidth;
    }
  } else if (pp == &p_wmw) {
    if (value < 0) {
      return e_positive;
    } else if (value > p_wiw) {
      return e_winwidth;
    }
  } else if (pp == &p_mco) {
    *valuep = MAX_MCO;
  } else if (pp == &p_titlelen) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_uc) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_ch) {
    if (value < 0) {
      return e_positive;
    } else {
      p_ch_was_zero = value == 0;
    }
  } else if (pp == &p_tm) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_hi) {
    if (value < 0) {
      return e_positive;
    } else if (value > 10000) {
      return e_invarg;
    }
  } else if (pp == &p_pyx) {
    if (value == 0) {
      *valuep = 3;
    } else if (value != 3) {
      return e_invarg;
    }
  } else if (pp == &p_re) {
    if (value < 0 || value > 2) {
      return e_invarg;
    }
  } else if (pp == &p_report) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_so) {
    if (value < 0 && full_screen) {
      return e_positive;
    }
  } else if (pp == &p_siso) {
    if (value < 0 && full_screen) {
      return e_positive;
    }
  } else if (pp == &p_cwh) {
    if (value < 1) {
      return e_positive;
    }
  } else if (pp == &p_ut) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_ss) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &curwin->w_p_fdl || pp == &curwin->w_allbuf_opt.wo_fdl) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &curwin->w_p_cole || pp == &curwin->w_allbuf_opt.wo_cole) {
    if (value < 0) {
      return e_positive;
    } else if (value > 3) {
      return e_invarg;
    }
  } else if (pp == &curwin->w_p_nuw || pp == &curwin->w_allbuf_opt.wo_nuw) {
    if (value < 1) {
      return e_positive;
    } else if (value > MAX_NUMBERWIDTH) {
      return e_invarg;
    }
  } else if (pp == &curbuf->b_p_iminsert || pp == &p_iminsert) {
    if (value < 0 || value > B_IMODE_LAST) {
      return e_invarg;
    }
  } else if (pp == &curbuf->b_p_imsearch || pp == &p_imsearch) {
    if (value < -1 || value > B_IMODE_LAST) {
      return e_invarg;
    }
  } else if (pp == &curbuf->b_p_channel || pp == &p_channel) {
    return e_invarg;
  } else if (pp == &curbuf->b_p_scbk || pp == &p_scbk) {
    if (value < -1 || value > SB_MAX) {
      return e_invarg;
    }
  } else if (pp == &curbuf->b_p_sw || pp == &p_sw) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &curbuf->b_p_ts || pp == &p_ts) {
    if (value < 1) {
      return e_positive;
    } else if (value > TABSTOP_MAX) {
      return e_invarg;
    }
  } else if (pp == &curbuf->b_p_tw || pp == &p_tw) {
    if (value < 0) {
      return e_positive;
    }
  } else if (pp == &p_wd) {
    if (value < 0) {
      return e_positive;
    }
  }

  return NULL;
}

/// Called after an option changed: check if something needs to be redrawn.
void check_redraw_for(buf_T *buf, win_T *win, uint32_t flags)
{
  // Careful: P_RALL is a combination of other P_ flags
  bool all = (flags & P_RALL) == P_RALL;

  if ((flags & P_RSTAT) || all) {  // mark all status lines and window bars dirty
    status_redraw_all();
  }

  if ((flags & P_RTABL) || all) {  // mark tablines dirty
    redraw_tabline = true;
  }

  if ((flags & P_RBUF) || (flags & P_RWIN) || all) {
    changed_window_setting_win(win);
  }
  if (flags & P_RBUF) {
    redraw_buf_later(buf, UPD_NOT_VALID);
  }
  if (flags & P_RWINONLY) {
    redraw_later(win, UPD_NOT_VALID);
  }
  if (all) {
    redraw_all_later(UPD_NOT_VALID);
  }
}

void check_redraw(uint32_t flags)
{
  check_redraw_for(curbuf, curwin, flags);
}

/// Find index for named option
///
/// @param[in]  arg  Option to find index for.
/// @param[in]  len  Length of the option.
///
/// @return Index of the option or -1 if option was not found.
int findoption_len(const char *const arg, const size_t len)
{
  const char *s;
  static int quick_tab[27] = { 0, 0 };  // quick access table

  // For first call: Initialize the quick-access table.
  // It contains the index for the first option that starts with a certain
  // letter.  There are 26 letters, plus the first "t_" option.
  if (quick_tab[1] == 0) {
    const char *p = options[0].fullname;
    for (uint16_t i = 1; (s = options[i].fullname) != NULL; i++) {
      if (s[0] != p[0]) {
        if (s[0] == 't' && s[1] == '_') {
          quick_tab[26] = i;
        } else {
          quick_tab[CHAR_ORD_LOW(s[0])] = i;
        }
      }
      p = s;
    }
  }

  // Check for name starting with an illegal character.
  if (len == 0 || arg[0] < 'a' || arg[0] > 'z') {
    return -1;
  }

  int opt_idx;
  const bool is_term_opt = (len > 2 && arg[0] == 't' && arg[1] == '_');
  if (is_term_opt) {
    opt_idx = quick_tab[26];
  } else {
    opt_idx = quick_tab[CHAR_ORD_LOW(arg[0])];
  }
  // Match full name
  for (; (s = options[opt_idx].fullname) != NULL; opt_idx++) {
    if (strncmp(arg, s, len) == 0 && s[len] == NUL) {
      break;
    }
  }
  if (s == NULL && !is_term_opt) {
    opt_idx = quick_tab[CHAR_ORD_LOW(arg[0])];
    // Match short name
    for (; options[opt_idx].fullname != NULL; opt_idx++) {
      s = options[opt_idx].shortname;
      if (s != NULL && strncmp(arg, s, len) == 0 && s[len] == NUL) {
        break;
      }
      s = NULL;
    }
  }
  if (s == NULL) {
    opt_idx = -1;
  } else {
    // Nvim: handle option aliases.
    if (strncmp(options[opt_idx].fullname, "viminfo", 7) == 0) {
      if (strlen(options[opt_idx].fullname) == 7) {
        return findoption_len("shada", 5);
      }
      assert(strcmp(options[opt_idx].fullname, "viminfofile") == 0);
      return findoption_len("shadafile", 9);
    }
  }
  return opt_idx;
}

bool is_tty_option(const char *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (name[0] == 't' && name[1] == '_')
         || strequal(name, "term")
         || strequal(name, "ttytype");
}

#define TCO_BUFFER_SIZE 8
/// @param name TUI-related option
/// @param[out,allocated] value option string value
bool get_tty_option(const char *name, char **value)
{
  if (strequal(name, "t_Co")) {
    if (value) {
      if (t_colors <= 1) {
        *value = xstrdup("");
      } else {
        *value = xmalloc(TCO_BUFFER_SIZE);
        snprintf(*value, TCO_BUFFER_SIZE, "%d", t_colors);
      }
    }
    return true;
  }

  if (strequal(name, "term")) {
    if (value) {
      *value = p_term ? xstrdup(p_term) : xstrdup("nvim");
    }
    return true;
  }

  if (strequal(name, "ttytype")) {
    if (value) {
      *value = p_ttytype ? xstrdup(p_ttytype) : xstrdup("nvim");
    }
    return true;
  }

  if (is_tty_option(name)) {
    if (value) {
      // XXX: All other t_* options were removed in 3baba1e7.
      *value = xstrdup("");
    }
    return true;
  }

  return false;
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

/// Find index for an option
///
/// @param[in]  arg  Option name.
///
/// @return Option index or -1 if option was not found.
int findoption(const char *const arg)
  FUNC_ATTR_NONNULL_ALL
{
  return findoption_len(arg, strlen(arg));
}

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

/// Match type of OptVal with the type of the target option. Returns true if the types match and
/// false otherwise.
static bool optval_match_type(OptVal o, int opt_idx)
{
  assert(opt_idx >= 0);
  uint32_t flags = options[opt_idx].flags;

  switch (o.type) {
  case kOptValTypeNil:
    return false;
  case kOptValTypeBoolean:
    return flags & P_BOOL;
  case kOptValTypeNumber:
    return flags & P_NUM;
  case kOptValTypeString:
    return flags & P_STRING;
  }
  UNREACHABLE;
}

/// Create OptVal from var pointer.
///
/// @param       opt_idx  Option index in options[] table.
/// @param[out]  varp     Pointer to option variable.
OptVal optval_from_varp(int opt_idx, void *varp)
{
  // Special case: 'modified' is b_changed, but we also want to consider it set when 'ff' or 'fenc'
  // changed.
  if ((int *)varp == &curbuf->b_changed) {
    return BOOLEAN_OPTVAL(curbufIsChanged());
  }

  uint32_t flags = options[opt_idx].flags;

  OptValType type = kOptValTypeNil;
  if (flags & P_BOOL) {
    type = kOptValTypeBoolean;
  } else if (flags & P_NUM) {
    type = kOptValTypeNumber;
  } else if (flags & P_STRING) {
    type = kOptValTypeString;
  } else {
    abort();
  }

  switch (type) {
  case kOptValTypeNil:
    return NIL_OPTVAL;
  case kOptValTypeBoolean:
    return BOOLEAN_OPTVAL(varp == NULL ? false : TRISTATE_FROM_INT(*(int *)varp));
  case kOptValTypeNumber:
    return NUMBER_OPTVAL(varp == NULL ? 0 : *(OptInt *)varp);
  case kOptValTypeString:
    return STRING_OPTVAL(varp == NULL ? (String)STRING_INIT : cstr_as_string(*(char **)varp));
  }
  UNREACHABLE;
}

/// Set option var pointer value from Optval.
///
/// @param       opt_idx      Option index in options[] table.
/// @param[out]  varp         Pointer to option variable.
/// @param[in]   value        New option value.
/// @param       free_oldval  Free old value.
static void set_option_varp(int opt_idx, void *varp, OptVal value, bool free_oldval)
  FUNC_ATTR_NONNULL_ARG(2)
{
  assert(optval_match_type(value, opt_idx));

  if (free_oldval) {
    optval_free(optval_from_varp(opt_idx, varp));
  }

  switch (value.type) {
  case kOptValTypeNil:
    return;
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

/// Unset the local value of an option. The exact semantics of this depend on the option.
/// TODO(famiu): Remove this once we have a dedicated OptVal type for unset local options.
///
/// @param      opt_idx  Option index in options[] table.
/// @param[in]  varp  Pointer to option variable.
///
/// @return [allocated] Option value equal to the unset value for the option.
static OptVal optval_unset_local(int opt_idx, void *varp)
{
  vimoption_T *opt = &options[opt_idx];
  // For global-local options, use the unset value of the local value.
  if (opt->indir & PV_BOTH) {
    // String global-local options always use an empty string for the unset value.
    if (opt->flags & P_STRING) {
      return STATIC_CSTR_TO_OPTVAL("");
    }

    if ((int *)varp == &curbuf->b_p_ar) {
      return BOOLEAN_OPTVAL(kNone);
    } else if ((OptInt *)varp == &curwin->w_p_so || (OptInt *)varp == &curwin->w_p_siso) {
      return NUMBER_OPTVAL(-1);
    } else if ((OptInt *)varp == &curbuf->b_p_ul) {
      return NUMBER_OPTVAL(NO_LOCAL_UNDOLEVEL);
    } else {
      // This should never happen.
      abort();
    }
  }
  // For options that aren't global-local, just set the local value to the global value.
  return get_option_value(opt->fullname, NULL, OPT_GLOBAL, NULL);
}

/// Get an allocated string containing a list of valid types for an option.
/// For options with a singular type, it returns the name of the type. For options with multiple
/// possible types, it returns a slash separated list of types. For example, if an option can be a
/// number, boolean or string, the function returns "Number/Boolean/String"
static char *option_get_valid_types(int opt_idx)
{
  uint32_t flags = options[opt_idx].flags;
  uint32_t type_count = 0;

  StringBuilder str = KV_INITIAL_VALUE;
  kv_resize(str, 32);

#define OPTION_ADD_TYPE(typename) \
  do { \
    if (type_count == 0) { \
      kv_concat(str, typename); \
    } else { \
      kv_printf(str, "/%s", typename); \
    } \
    type_count++; \
  } while (0);

  if (flags & P_NUM) {
    OPTION_ADD_TYPE("Number");
  }
  if (flags & P_BOOL) {
    OPTION_ADD_TYPE("Boolean");
  }
  if (flags & P_STRING) {
    OPTION_ADD_TYPE("String");
  }

  if (type_count == 0) {
    abort();
  }

  // Ensure that the string is NUL-terminated.
  kv_push(str, NUL);
  return str.items;

#undef OPTION_ADD_TYPE
}

/// Gets the value for an option.
///
/// @param[in]   name    Option name.
/// @param[out]  flagsp  Set to the option flags (P_xxxx) (if not NULL).
/// @param[in]   scope   Option scope (can be OPT_LOCAL, OPT_GLOBAL or a combination).
/// @param[out]  hidden  Whether option is hidden.
///
/// @return [allocated] Option value. Returns NIL_OPTVAL for invalid options.
OptVal get_option_value(const char *name, uint32_t *flagsp, int scope, bool *hidden)
{
  // Make sure that hidden and flagsp are never returned uninitialized
  if (hidden != NULL) {
    *hidden = false;
  }
  if (flagsp != NULL) {
    *flagsp = 0;
  }

  char *str;
  if (get_tty_option(name, &str)) {
    return CSTR_AS_OPTVAL(str);
  }

  int opt_idx = findoption(name);
  if (opt_idx < 0) {  // option not in the table
    return NIL_OPTVAL;
  }

  void *varp = get_varp_scope(&(options[opt_idx]), scope);
  if (hidden != NULL) {
    *hidden = varp == NULL;
  }

  if (flagsp != NULL) {
    // Return the P_xxxx option flags.
    *flagsp = options[opt_idx].flags;
  }

  return optval_copy(optval_from_varp(opt_idx, varp));
}

/// Return information for option at 'opt_idx'
vimoption_T *get_option(int opt_idx)
{
  return &options[opt_idx];
}

/// Check if local value of global-local option is unset for current buffer / window.
/// Always returns false for options that aren't global-local.
///
/// TODO(famiu): Remove this once we have an OptVal type to indicate an unset local value.
static bool is_option_local_value_unset(vimoption_T *opt, buf_T *buf, win_T *win)
{
  // Local value of option that isn't global-local is always considered set.
  if (!((int)opt->indir & PV_BOTH)) {
    return false;
  }

  // Get pointer to local value in varp_local, and a pointer to the currently used value in varp.
  // If the local value is the one currently being used, that indicates that it's set.
  // Otherwise it indicates the local value is unset.
  void *varp = get_varp_from(opt, buf, win);
  void *varp_local = get_varp_scope_from(opt, OPT_LOCAL, buf, win);

  return varp != varp_local;
}

/// Handle side-effects of setting an option.
///
/// @param       opt_idx         Index in options[] table. Must be >= 0.
/// @param[in]   varp            Option variable pointer, cannot be NULL.
/// @param       old_value       Old option value.
/// @param       new_value       New option value.
/// @param       opt_flags       Option flags.
/// @param[out]  value_checked   Value was checked to be safe, no need to set P_INSECURE.
/// @param       value_replaced  Value was replaced completely.
/// @param[out]  errbuf          Buffer for error message.
/// @param       errbuflen       Length of error buffer.
///
/// @return  NULL on success, an untranslated error message on error.
static const char *did_set_option(int opt_idx, void *varp, OptVal old_value, OptVal new_value,
                                  int opt_flags, bool *value_checked, bool value_replaced,
                                  char *errbuf, size_t errbuflen)
{
  vimoption_T *opt = &options[opt_idx];
  const char *errmsg = NULL;
  bool restore_chartab = false;
  bool free_oldval = (opt->flags & P_ALLOCED);
  bool value_changed = false;

  opt_did_set_cb_T did_set_cb;
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

  if ((int *)varp == &p_force_on) {
    did_set_cb = did_set_force_on;
  } else if ((int *)varp == &p_force_off) {
    did_set_cb = did_set_force_off;
  } else {
    did_set_cb = opt->opt_did_set_cb;
  }

  // Disallow changing some options from secure mode
  if ((secure || sandbox != 0) && (opt->flags & P_SECURE)) {
    errmsg = e_secure;
    // Check for a "normal" directory or file name in some string options.
  } else if (new_value.type == kOptValTypeString
             && check_illegal_path_names(*(char **)varp, opt->flags)) {
    errmsg = e_invarg;
  } else if (did_set_cb != NULL) {
    // Invoke the option specific callback function to validate and apply the new value.
    errmsg = did_set_cb(&did_set_cb_args);
    // The 'filetype' and 'syntax' option callback functions may change the os_value_changed field.
    value_changed = did_set_cb_args.os_value_changed;
    // The 'keymap', 'filetype' and 'syntax' option callback functions may change the
    // os_value_checked field.
    *value_checked = did_set_cb_args.os_value_checked;
    // The 'isident', 'iskeyword', 'isprint' and 'isfname' options may change the character table.
    // On failure, this needs to be restored.
    restore_chartab = did_set_cb_args.os_restore_chartab;
  }

  // If an error is detected, restore the previous value and don't do any further processing.
  if (errmsg != NULL) {
    set_option_varp(opt_idx, varp, old_value, true);
    // When resetting some values, need to act on it.
    if (restore_chartab) {
      (void)buf_init_chartab(curbuf, true);
    }

    // Unset new_value as it is no longer valid.
    new_value = NIL_OPTVAL;  // NOLINT(clang-analyzer-deadcode.DeadStores)
    return errmsg;
  }

  // Re-assign the new value as its value may get freed or modified by the option callback.
  new_value = optval_from_varp(opt_idx, varp);

  // Remember where the option was set.
  set_option_sctx_idx(opt_idx, opt_flags, current_sctx);
  // Free options that are in allocated memory.
  // Use "free_oldval", because recursiveness may change the flags (esp. init_highlight()).
  if (free_oldval) {
    optval_free(old_value);
  }
  opt->flags |= P_ALLOCED;

  // Check the bound for num options.
  if (new_value.type == kOptValTypeNumber) {
    errmsg = check_num_option_bounds((OptInt *)varp, old_value.data.number, errbuf, errbuflen,
                                     errmsg);
    // Re-assign new_value because the new value was modified by the bound check.
    new_value = optval_from_varp(opt_idx, varp);
  }

  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0 && (opt->indir & PV_BOTH)) {
    // Global option with local value set to use global value.
    // Free the local value and clear it.
    void *varp_local = get_varp_scope(opt, OPT_LOCAL);
    OptVal local_unset_value = optval_unset_local(opt_idx, varp_local);
    set_option_varp(opt_idx, varp_local, local_unset_value, true);
  } else if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    // May set global value for local option.
    void *varp_global = get_varp_scope(opt, OPT_GLOBAL);
    set_option_varp(opt_idx, varp_global, optval_copy(new_value), true);
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

  // In case 'columns' or 'ls' changed.
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

  if (curwin->w_curswant != MAXCOL && (opt->flags & (P_CURSWANT | P_RALL)) != 0) {
    curwin->w_set_curswant = true;
  }

  check_redraw(opt->flags);

  if (errmsg == NULL) {
    uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
    opt->flags |= P_WAS_SET;

    // When an option is set in the sandbox, from a modeline or in secure mode set the P_INSECURE
    // flag.  Otherwise, if a new value is stored reset the flag.
    if (!value_checked && (secure || sandbox != 0 || (opt_flags & OPT_MODELINE))) {
      *p |= P_INSECURE;
    } else if (value_replaced) {
      *p &= ~P_INSECURE;
    }
  }

  return errmsg;
}

/// Set the value of an option using an OptVal.
///
/// @param       opt_idx         Index in options[] table. Must be >= 0.
/// @param[in]   varp            Option variable pointer, cannot be NULL.
/// @param       value           New option value. Might get freed.
/// @param       opt_flags       Option flags.
/// @param       value_replaced  Value was replaced completely.
/// @param[out]  errbuf          Buffer for error message.
/// @param       errbuflen       Length of error buffer.
///
/// @return  NULL on success, an untranslated error message on error.
static const char *set_option(const int opt_idx, void *varp, OptVal value, int opt_flags,
                              const bool value_replaced, char *errbuf, size_t errbuflen)
{
  assert(opt_idx >= 0 && varp != NULL);

  const char *errmsg = NULL;
  bool value_checked = false;

  vimoption_T *opt = &options[opt_idx];

  static const char *optval_type_names[] = {
    [kOptValTypeNil] = "Nil",
    [kOptValTypeBoolean] = "Boolean",
    [kOptValTypeNumber] = "Number",
    [kOptValTypeString] = "String"
  };

  if (value.type == kOptValTypeNil) {
    // Don't try to unset local value if scope is global.
    // TODO(famiu): Change this to forbid changing all non-local scopes when the API scope bug is
    // fixed.
    if (opt_flags == OPT_GLOBAL) {
      errmsg = _("Cannot unset global option value");
    } else {
      optval_free(value);
      value = optval_unset_local(opt_idx, varp);
    }
  } else if (!optval_match_type(value, opt_idx)) {
    char *rep = optval_to_cstr(value);
    char *valid_types = option_get_valid_types(opt_idx);
    snprintf(errbuf, IOSIZE, _("Invalid value for option '%s': expected %s, got %s %s"),
             opt->fullname, valid_types, optval_type_names[value.type], rep);
    xfree(rep);
    xfree(valid_types);
    errmsg = errbuf;
  }

  if (errmsg != NULL) {
    goto err;
  }

  // When using ":set opt=val" for a global option with a local value the local value will be reset,
  // use the global value here.
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0 && ((int)opt->indir & PV_BOTH)) {
    varp = opt->var;
  }

  OptVal old_value = optval_from_varp(opt_idx, varp);
  OptVal old_global_value = NIL_OPTVAL;
  OptVal old_local_value = NIL_OPTVAL;

  // Save the local and global values before changing anything. This is needed as for a global-only
  // option setting the "local value" in fact sets the global value (since there is only one value).
  //
  // TODO(famiu): This needs to be changed to use the current type of the old value instead of
  // value.type, when multi-type options are added.
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    old_global_value = optval_from_varp(opt_idx, get_varp_scope(opt, OPT_GLOBAL));
    old_local_value = optval_from_varp(opt_idx, get_varp_scope(opt, OPT_LOCAL));

    // If local value of global-local option is unset, use global value as local value.
    if (is_option_local_value_unset(opt, curbuf, curwin)) {
      old_local_value = old_global_value;
    }
  }

  // Value that's actually being used.
  // For local scope of a global-local option, it is equal to the global value.
  // In every other case, it is the same as old_value.
  const bool oldval_is_global = ((int)opt->indir & PV_BOTH) && (opt_flags & OPT_LOCAL);
  OptVal used_old_value = oldval_is_global ? optval_from_varp(opt_idx, get_varp(opt)) : old_value;

  if (value.type == kOptValTypeNumber) {
    errmsg = validate_num_option((OptInt *)varp, &value.data.number);

    // Don't change the value and return early if validation failed.
    if (errmsg != NULL) {
      goto err;
    }
  }

  set_option_varp(opt_idx, varp, value, false);

  OptVal saved_used_value = optval_copy(used_old_value);
  OptVal saved_old_global_value = optval_copy(old_global_value);
  OptVal saved_old_local_value = optval_copy(old_local_value);
  // New value (and varp) may become invalid if the buffer is closed by autocommands.
  OptVal saved_new_value = optval_copy(value);

  uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
  const int secure_saved = secure;

  // When an option is set in the sandbox, from a modeline or in secure mode, then deal with side
  // effects in secure mode. Also when the value was set with the P_INSECURE flag and is not
  // completely replaced.
  if ((opt_flags & OPT_MODELINE) || sandbox != 0 || (!value_replaced && (*p & P_INSECURE))) {
    secure = 1;
  }

  errmsg = did_set_option(opt_idx, varp, old_value, value, opt_flags, &value_checked,
                          value_replaced, errbuf, errbuflen);

  secure = secure_saved;

  if (errmsg == NULL) {
    if (!starting) {
      apply_optionset_autocmd(opt_idx, opt_flags, saved_used_value, saved_old_global_value,
                              saved_old_local_value, saved_new_value, errmsg);
    }
    if (opt->flags & P_UI_OPTION) {
      // Calculate saved_new_value again as its value might be changed by bound checks.
      // NOTE: Currently there are no buffer/window local UI options, but if there ever are buffer
      // or window local UI options added in the future, varp might become invalid if the buffer or
      // window is closed during an autocommand, and a check would have to be added for it.
      optval_free(saved_new_value);
      saved_new_value = optval_copy(optval_from_varp(opt_idx, varp));
      ui_call_option_set(cstr_as_string(opt->fullname), optval_as_object(saved_new_value));
    }
  }

  // Free copied values as they are not needed anymore
  optval_free(saved_used_value);
  optval_free(saved_old_local_value);
  optval_free(saved_old_global_value);
  optval_free(saved_new_value);
  return errmsg;
err:
  optval_free(value);
  return errmsg;
}

/// Set the value of an option
///
/// @param[in]  name       Option name.
/// @param[in]  value      Option value. If NIL_OPTVAL, the option value is cleared.
/// @param[in]  opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///
/// @return  NULL on success, an untranslated error message on error.
const char *set_option_value(const char *const name, const OptVal value, int opt_flags)
  FUNC_ATTR_NONNULL_ARG(1)
{
  static char errbuf[IOSIZE];

  if (is_tty_option(name)) {
    return NULL;  // Fail silently; many old vimrcs set t_xx options.
  }

  int opt_idx = findoption(name);
  if (opt_idx < 0) {
    snprintf(errbuf, IOSIZE, _(e_unknown_option2), name);
    return errbuf;
  }

  uint32_t flags = options[opt_idx].flags;
  // Disallow changing some options in the sandbox
  if (sandbox > 0 && (flags & P_SECURE)) {
    return _(e_sandbox);
  }

  void *varp = get_varp_scope(&(options[opt_idx]), opt_flags);
  if (varp == NULL) {
    // hidden option is not changed
    return NULL;
  }

  const char *errmsg = NULL;

  errmsg = set_option(opt_idx, varp, optval_copy(value), opt_flags, true, errbuf, sizeof(errbuf));

  return errmsg;
}

/// Call set_option_value() and when an error is returned report it.
///
/// @param opt_flags  OPT_LOCAL or 0 (both)
void set_option_value_give_err(const char *name, OptVal value, int opt_flags)
{
  const char *errmsg = set_option_value(name, value, opt_flags);

  if (errmsg != NULL) {
    emsg(_(errmsg));
  }
}

bool is_option_allocated(const char *name)
{
  int idx = findoption(name);
  return idx >= 0 && (options[idx].flags & P_ALLOCED);
}

// Translate a string like "t_xx", "<t_xx>" or "<S-Tab>" to a key number.
// When "has_lt" is true there is a '<' before "*arg_arg".
// Returns 0 when the key is not recognized.
int find_key_option_len(const char *arg_arg, size_t len, bool has_lt)
{
  int key = 0;
  const char *arg = arg_arg;

  // Don't use get_special_key_code() for t_xx, we don't want it to call
  // add_termcap_entry().
  if (len >= 4 && arg[0] == 't' && arg[1] == '_') {
    key = TERMCAP2KEY((uint8_t)arg[2], (uint8_t)arg[3]);
  } else if (has_lt) {
    arg--;  // put arg at the '<'
    int modifiers = 0;
    key = find_special_key(&arg, len + 1, &modifiers,
                           FSK_KEYCODE | FSK_KEEP_X_KEY | FSK_SIMPLIFY, NULL);
    if (modifiers) {  // can't handle modifiers here
      key = 0;
    }
  }
  return key;
}

static int find_key_option(const char *arg, bool has_lt)
{
  return find_key_option_len(arg, strlen(arg), has_lt);
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
    for (vimoption_T *p = &options[0]; p->fullname != NULL; p++) {
      // apply :filter /pat/
      if (message_filtered(p->fullname)) {
        continue;
      }

      void *varp = NULL;
      if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) != 0) {
        if (p->indir != PV_NONE) {
          varp = get_varp_scope(p, opt_flags);
        }
      } else {
        varp = get_varp(p);
      }
      if (varp != NULL && (all || !optval_default(p, varp))) {
        int len;
        if (opt_flags & OPT_ONECOLUMN) {
          len = Columns;
        } else if (p->flags & P_BOOL) {
          len = 1;                      // a toggle option fits always
        } else {
          option_value2string(p, opt_flags);
          len = (int)strlen(p->fullname) + vim_strsize(NameBuff) + 1;
        }
        if ((len <= INC - GAP && run == 1)
            || (len > INC - GAP && run == 2)) {
          items[item_count++] = p;
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
static int optval_default(vimoption_T *p, const void *varp)
{
  if (varp == NULL) {
    return true;            // hidden option is always at default
  }
  if (p->flags & P_NUM) {
    return *(OptInt *)varp == (OptInt)(intptr_t)p->def_val;
  }
  if (p->flags & P_BOOL) {
    return *(int *)varp == (int)(intptr_t)p->def_val;
  }
  // P_STRING
  return strcmp(*(char **)varp, p->def_val) == 0;
}

/// Send update to UIs with values of UI relevant options
void ui_refresh_options(void)
{
  for (int opt_idx = 0; options[opt_idx].fullname; opt_idx++) {
    uint32_t flags = options[opt_idx].flags;
    if (!(flags & P_UI_OPTION)) {
      continue;
    }
    String name = cstr_as_string(options[opt_idx].fullname);
    void *varp = options[opt_idx].var;
    Object value = OBJECT_INIT;
    if (flags & P_BOOL) {
      value = BOOLEAN_OBJ(*(int *)varp);
    } else if (flags & P_NUM) {
      value = INTEGER_OBJ(*(OptInt *)varp);
    } else if (flags & P_STRING) {
      // cstr_as_string handles NULL string
      value = CSTR_AS_OBJ(*(char **)varp);
    }
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
static void showoneopt(vimoption_T *p, int opt_flags)
{
  int save_silent = silent_mode;

  silent_mode = false;
  info_message = true;          // use os_msg(), not os_errmsg()

  void *varp = get_varp_scope(p, opt_flags);

  // for 'modified' we also need to check if 'ff' or 'fenc' changed.
  if ((p->flags & P_BOOL) && ((int *)varp == &curbuf->b_changed
                              ? !curbufIsChanged() : !*(int *)varp)) {
    msg_puts("no");
  } else if ((p->flags & P_BOOL) && *(int *)varp < 0) {
    msg_puts("--");
  } else {
    msg_puts("  ");
  }
  msg_puts(p->fullname);
  if (!(p->flags & P_BOOL)) {
    msg_putchar('=');
    // put value string in NameBuff
    option_value2string(p, opt_flags);
    msg_outtrans(NameBuff, 0);
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
  // P_PRI_MKRC flag and once without.
  for (int pri = 1; pri >= 0; pri--) {
    for (vimoption_T *p = &options[0]; p->fullname; p++) {
      if (!(p->flags & P_NO_MKRC)
          && ((pri == 1) == ((p->flags & P_PRI_MKRC) != 0))) {
        // skip global option when only doing locals
        if (p->indir == PV_NONE && !(opt_flags & OPT_GLOBAL)) {
          continue;
        }

        // Do not store options like 'bufhidden' and 'syntax' in a vimrc
        // file, they are always buffer-specific.
        if ((opt_flags & OPT_GLOBAL) && (p->flags & P_NOGLOB)) {
          continue;
        }

        void *varp = get_varp_scope(p, opt_flags);  // currently used value
        // Hidden options are never written.
        if (!varp) {
          continue;
        }
        // Global values are only written when not at the default value.
        if ((opt_flags & OPT_GLOBAL) && optval_default(p, varp)) {
          continue;
        }

        if ((opt_flags & OPT_SKIPRTP)
            && (p->var == &p_rtp || p->var == &p_pp)) {
          continue;
        }

        int round = 2;
        void *varp_local = NULL;  // fresh value
        if (p->indir != PV_NONE) {
          if (p->var == VAR_WIN) {
            // skip window-local option when only doing globals
            if (!(opt_flags & OPT_LOCAL)) {
              continue;
            }
            // When fresh value of window-local option is not at the
            // default, need to write it too.
            if (!(opt_flags & OPT_GLOBAL) && !local_only) {
              void *varp_fresh = get_varp_scope(p, OPT_GLOBAL);  // local value
              if (!optval_default(p, varp_fresh)) {
                round = 1;
                varp_local = varp;
                varp = varp_fresh;
              }
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

          if (p->flags & P_BOOL) {
            if (put_setbool(fd, cmd, p->fullname, *(int *)varp) == FAIL) {
              return FAIL;
            }
          } else if (p->flags & P_NUM) {
            if (put_setnum(fd, cmd, p->fullname, (OptInt *)varp) == FAIL) {
              return FAIL;
            }
          } else {    // P_STRING
            int do_endif = false;

            // Don't set 'syntax' and 'filetype' again if the value is
            // already right, avoids reloading the syntax file.
            if (p->indir == PV_SYN || p->indir == PV_FT) {
              if (fprintf(fd, "if &%s != '%s'", p->fullname,
                          *(char **)(varp)) < 0
                  || put_eol(fd) < 0) {
                return FAIL;
              }
              do_endif = true;
            }
            if (put_setstring(fd, cmd, p->fullname, (char **)varp, p->flags) == FAIL) {
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
  }
  return OK;
}

/// Generate set commands for the local fold options only.  Used when
/// 'sessionoptions' or 'viewoptions' contains "folds" but not "options".
int makefoldset(FILE *fd)
{
  if (put_setstring(fd, "setlocal", "fdm", &curwin->w_p_fdm, 0) == FAIL
      || put_setstring(fd, "setlocal", "fde", &curwin->w_p_fde, 0) == FAIL
      || put_setstring(fd, "setlocal", "fmr", &curwin->w_p_fmr, 0) == FAIL
      || put_setstring(fd, "setlocal", "fdi", &curwin->w_p_fdi, 0) == FAIL
      || put_setnum(fd, "setlocal", "fdl", &curwin->w_p_fdl) == FAIL
      || put_setnum(fd, "setlocal", "fml", &curwin->w_p_fml) == FAIL
      || put_setnum(fd, "setlocal", "fdn", &curwin->w_p_fdn) == FAIL
      || put_setbool(fd, "setlocal", "fen", curwin->w_p_fen) == FAIL) {
    return FAIL;
  }

  return OK;
}

static int put_setstring(FILE *fd, char *cmd, char *name, char **valuep, uint64_t flags)
{
  if (fprintf(fd, "%s %s=", cmd, name) < 0) {
    return FAIL;
  }

  char *buf = NULL;
  char *part = NULL;

  if (*valuep != NULL) {
    if ((flags & P_EXPAND) != 0) {
      size_t size = (size_t)strlen(*valuep) + 1;

      // replace home directory in the whole option value into "buf"
      buf = xmalloc(size);
      home_replace(NULL, *valuep, buf, size, false);

      // If the option value is longer than MAXPATHL, we need to append
      // each comma separated part of the option separately, so that it
      // can be expanded when read back.
      if (size >= MAXPATHL && (flags & P_COMMA) != 0
          && vim_strchr(*valuep, ',') != NULL) {
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
          (void)copy_option_part(&p, part, size, ",");
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
    } else if (put_escstr(fd, *valuep, 2) == FAIL) {
      return FAIL;
    }
  }
  if (put_eol(fd) < 0) {
    return FAIL;
  }
  return OK;
fail:
  xfree(buf);
  xfree(part);
  return FAIL;
}

static int put_setnum(FILE *fd, char *cmd, char *name, OptInt *valuep)
{
  if (fprintf(fd, "%s %s=", cmd, name) < 0) {
    return FAIL;
  }
  OptInt wc;
  if (wc_use_keyname(valuep, &wc)) {
    // print 'wildchar' and 'wildcharm' as a key name
    if (fputs(get_special_key_name((int)wc, 0), fd) < 0) {
      return FAIL;
    }
  } else if (fprintf(fd, "%" PRId64, (int64_t)(*valuep)) < 0) {
    return FAIL;
  }
  if (put_eol(fd) < 0) {
    return FAIL;
  }
  return OK;
}

static int put_setbool(FILE *fd, char *cmd, char *name, int value)
{
  if (value < 0) {      // global/local option using global value
    return OK;
  }
  if (fprintf(fd, "%s %s%s", cmd, value ? "" : "no", name) < 0
      || put_eol(fd) < 0) {
    return FAIL;
  }
  return OK;
}

void *get_varp_scope_from(vimoption_T *p, int scope, buf_T *buf, win_T *win)
{
  if ((scope & OPT_GLOBAL) && p->indir != PV_NONE) {
    if (p->var == VAR_WIN) {
      return GLOBAL_WO(get_varp_from(p, buf, win));
    }
    return p->var;
  }
  if ((scope & OPT_LOCAL) && ((int)p->indir & PV_BOTH)) {
    switch ((int)p->indir) {
    case PV_FP:
      return &(buf->b_p_fp);
    case PV_EFM:
      return &(buf->b_p_efm);
    case PV_GP:
      return &(buf->b_p_gp);
    case PV_MP:
      return &(buf->b_p_mp);
    case PV_EP:
      return &(buf->b_p_ep);
    case PV_KP:
      return &(buf->b_p_kp);
    case PV_PATH:
      return &(buf->b_p_path);
    case PV_AR:
      return &(buf->b_p_ar);
    case PV_TAGS:
      return &(buf->b_p_tags);
    case PV_TC:
      return &(buf->b_p_tc);
    case PV_SISO:
      return &(win->w_p_siso);
    case PV_SO:
      return &(win->w_p_so);
    case PV_DEF:
      return &(buf->b_p_def);
    case PV_INC:
      return &(buf->b_p_inc);
    case PV_DICT:
      return &(buf->b_p_dict);
    case PV_TSR:
      return &(buf->b_p_tsr);
    case PV_TSRFU:
      return &(buf->b_p_tsrfu);
    case PV_TFU:
      return &(buf->b_p_tfu);
    case PV_SBR:
      return &(win->w_p_sbr);
    case PV_STL:
      return &(win->w_p_stl);
    case PV_WBR:
      return &(win->w_p_wbr);
    case PV_UL:
      return &(buf->b_p_ul);
    case PV_LW:
      return &(buf->b_p_lw);
    case PV_BKC:
      return &(buf->b_p_bkc);
    case PV_MENC:
      return &(buf->b_p_menc);
    case PV_FCS:
      return &(win->w_p_fcs);
    case PV_LCS:
      return &(win->w_p_lcs);
    case PV_VE:
      return &(win->w_p_ve);
    }
    return NULL;     // "cannot happen"
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
void *get_option_varp_scope_from(int opt_idx, int scope, buf_T *buf, win_T *win)
{
  return get_varp_scope_from(&(options[opt_idx]), scope, buf, win);
}

void *get_varp_from(vimoption_T *p, buf_T *buf, win_T *win)
{
  // hidden option, always return NULL
  if (p->var == NULL) {
    return NULL;
  }

  switch ((int)p->indir) {
  case PV_NONE:
    return p->var;

  // global option with local value: use local value if it's been set
  case PV_EP:
    return *buf->b_p_ep != NUL ? &buf->b_p_ep : p->var;
  case PV_KP:
    return *buf->b_p_kp != NUL ? &buf->b_p_kp : p->var;
  case PV_PATH:
    return *buf->b_p_path != NUL ? &(buf->b_p_path) : p->var;
  case PV_AR:
    return buf->b_p_ar >= 0 ? &(buf->b_p_ar) : p->var;
  case PV_TAGS:
    return *buf->b_p_tags != NUL ? &(buf->b_p_tags) : p->var;
  case PV_TC:
    return *buf->b_p_tc != NUL ? &(buf->b_p_tc) : p->var;
  case PV_SISO:
    return win->w_p_siso >= 0 ? &(win->w_p_siso) : p->var;
  case PV_SO:
    return win->w_p_so >= 0 ? &(win->w_p_so) : p->var;
  case PV_BKC:
    return *buf->b_p_bkc != NUL ? &(buf->b_p_bkc) : p->var;
  case PV_DEF:
    return *buf->b_p_def != NUL ? &(buf->b_p_def) : p->var;
  case PV_INC:
    return *buf->b_p_inc != NUL ? &(buf->b_p_inc) : p->var;
  case PV_DICT:
    return *buf->b_p_dict != NUL ? &(buf->b_p_dict) : p->var;
  case PV_TSR:
    return *buf->b_p_tsr != NUL ? &(buf->b_p_tsr) : p->var;
  case PV_TSRFU:
    return *buf->b_p_tsrfu != NUL ? &(buf->b_p_tsrfu) : p->var;
  case PV_FP:
    return *buf->b_p_fp != NUL ? &(buf->b_p_fp) : p->var;
  case PV_EFM:
    return *buf->b_p_efm != NUL ? &(buf->b_p_efm) : p->var;
  case PV_GP:
    return *buf->b_p_gp != NUL ? &(buf->b_p_gp) : p->var;
  case PV_MP:
    return *buf->b_p_mp != NUL ? &(buf->b_p_mp) : p->var;
  case PV_SBR:
    return *win->w_p_sbr != NUL ? &(win->w_p_sbr) : p->var;
  case PV_STL:
    return *win->w_p_stl != NUL ? &(win->w_p_stl) : p->var;
  case PV_WBR:
    return *win->w_p_wbr != NUL ? &(win->w_p_wbr) : p->var;
  case PV_UL:
    return buf->b_p_ul != NO_LOCAL_UNDOLEVEL ? &(buf->b_p_ul) : p->var;
  case PV_LW:
    return *buf->b_p_lw != NUL ? &(buf->b_p_lw) : p->var;
  case PV_MENC:
    return *buf->b_p_menc != NUL ? &(buf->b_p_menc) : p->var;
  case PV_FCS:
    return *win->w_p_fcs != NUL ? &(win->w_p_fcs) : p->var;
  case PV_LCS:
    return *win->w_p_lcs != NUL ? &(win->w_p_lcs) : p->var;
  case PV_VE:
    return *win->w_p_ve != NUL ? &win->w_p_ve : p->var;

  case PV_ARAB:
    return &(win->w_p_arab);
  case PV_LIST:
    return &(win->w_p_list);
  case PV_SPELL:
    return &(win->w_p_spell);
  case PV_CUC:
    return &(win->w_p_cuc);
  case PV_CUL:
    return &(win->w_p_cul);
  case PV_CULOPT:
    return &(win->w_p_culopt);
  case PV_CC:
    return &(win->w_p_cc);
  case PV_DIFF:
    return &(win->w_p_diff);
  case PV_FDC:
    return &(win->w_p_fdc);
  case PV_FEN:
    return &(win->w_p_fen);
  case PV_FDI:
    return &(win->w_p_fdi);
  case PV_FDL:
    return &(win->w_p_fdl);
  case PV_FDM:
    return &(win->w_p_fdm);
  case PV_FML:
    return &(win->w_p_fml);
  case PV_FDN:
    return &(win->w_p_fdn);
  case PV_FDE:
    return &(win->w_p_fde);
  case PV_FDT:
    return &(win->w_p_fdt);
  case PV_FMR:
    return &(win->w_p_fmr);
  case PV_NU:
    return &(win->w_p_nu);
  case PV_RNU:
    return &(win->w_p_rnu);
  case PV_NUW:
    return &(win->w_p_nuw);
  case PV_WFH:
    return &(win->w_p_wfh);
  case PV_WFW:
    return &(win->w_p_wfw);
  case PV_PVW:
    return &(win->w_p_pvw);
  case PV_RL:
    return &(win->w_p_rl);
  case PV_RLC:
    return &(win->w_p_rlc);
  case PV_SCROLL:
    return &(win->w_p_scr);
  case PV_SMS:
    return &(win->w_p_sms);
  case PV_WRAP:
    return &(win->w_p_wrap);
  case PV_LBR:
    return &(win->w_p_lbr);
  case PV_BRI:
    return &(win->w_p_bri);
  case PV_BRIOPT:
    return &(win->w_p_briopt);
  case PV_SCBIND:
    return &(win->w_p_scb);
  case PV_CRBIND:
    return &(win->w_p_crb);
  case PV_COCU:
    return &(win->w_p_cocu);
  case PV_COLE:
    return &(win->w_p_cole);

  case PV_AI:
    return &(buf->b_p_ai);
  case PV_BIN:
    return &(buf->b_p_bin);
  case PV_BOMB:
    return &(buf->b_p_bomb);
  case PV_BH:
    return &(buf->b_p_bh);
  case PV_BT:
    return &(buf->b_p_bt);
  case PV_BL:
    return &(buf->b_p_bl);
  case PV_CHANNEL:
    return &(buf->b_p_channel);
  case PV_CI:
    return &(buf->b_p_ci);
  case PV_CIN:
    return &(buf->b_p_cin);
  case PV_CINK:
    return &(buf->b_p_cink);
  case PV_CINO:
    return &(buf->b_p_cino);
  case PV_CINSD:
    return &(buf->b_p_cinsd);
  case PV_CINW:
    return &(buf->b_p_cinw);
  case PV_COM:
    return &(buf->b_p_com);
  case PV_CMS:
    return &(buf->b_p_cms);
  case PV_CPT:
    return &(buf->b_p_cpt);
#ifdef BACKSLASH_IN_FILENAME
  case PV_CSL:
    return &(buf->b_p_csl);
#endif
  case PV_CFU:
    return &(buf->b_p_cfu);
  case PV_OFU:
    return &(buf->b_p_ofu);
  case PV_EOF:
    return &(buf->b_p_eof);
  case PV_EOL:
    return &(buf->b_p_eol);
  case PV_FIXEOL:
    return &(buf->b_p_fixeol);
  case PV_ET:
    return &(buf->b_p_et);
  case PV_FENC:
    return &(buf->b_p_fenc);
  case PV_FF:
    return &(buf->b_p_ff);
  case PV_FT:
    return &(buf->b_p_ft);
  case PV_FO:
    return &(buf->b_p_fo);
  case PV_FLP:
    return &(buf->b_p_flp);
  case PV_IMI:
    return &(buf->b_p_iminsert);
  case PV_IMS:
    return &(buf->b_p_imsearch);
  case PV_INF:
    return &(buf->b_p_inf);
  case PV_ISK:
    return &(buf->b_p_isk);
  case PV_INEX:
    return &(buf->b_p_inex);
  case PV_INDE:
    return &(buf->b_p_inde);
  case PV_INDK:
    return &(buf->b_p_indk);
  case PV_FEX:
    return &(buf->b_p_fex);
  case PV_LISP:
    return &(buf->b_p_lisp);
  case PV_LOP:
    return &(buf->b_p_lop);
  case PV_ML:
    return &(buf->b_p_ml);
  case PV_MPS:
    return &(buf->b_p_mps);
  case PV_MA:
    return &(buf->b_p_ma);
  case PV_MOD:
    return &(buf->b_changed);
  case PV_NF:
    return &(buf->b_p_nf);
  case PV_PI:
    return &(buf->b_p_pi);
  case PV_QE:
    return &(buf->b_p_qe);
  case PV_RO:
    return &(buf->b_p_ro);
  case PV_SCBK:
    return &(buf->b_p_scbk);
  case PV_SI:
    return &(buf->b_p_si);
  case PV_STS:
    return &(buf->b_p_sts);
  case PV_SUA:
    return &(buf->b_p_sua);
  case PV_SWF:
    return &(buf->b_p_swf);
  case PV_SMC:
    return &(buf->b_p_smc);
  case PV_SYN:
    return &(buf->b_p_syn);
  case PV_SPC:
    return &(win->w_s->b_p_spc);
  case PV_SPF:
    return &(win->w_s->b_p_spf);
  case PV_SPL:
    return &(win->w_s->b_p_spl);
  case PV_SPO:
    return &(win->w_s->b_p_spo);
  case PV_SW:
    return &(buf->b_p_sw);
  case PV_TFU:
    return &(buf->b_p_tfu);
  case PV_TS:
    return &(buf->b_p_ts);
  case PV_TW:
    return &(buf->b_p_tw);
  case PV_UDF:
    return &(buf->b_p_udf);
  case PV_WM:
    return &(buf->b_p_wm);
  case PV_VSTS:
    return &(buf->b_p_vsts);
  case PV_VTS:
    return &(buf->b_p_vts);
  case PV_KMAP:
    return &(buf->b_p_keymap);
  case PV_SCL:
    return &(win->w_p_scl);
  case PV_WINHL:
    return &(win->w_p_winhl);
  case PV_WINBL:
    return &(win->w_p_winbl);
  case PV_STC:
    return &(win->w_p_stc);
  default:
    iemsg(_("E356: get_varp ERROR"));
  }
  // always return a valid pointer to avoid a crash!
  return &(buf->b_p_wm);
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
  check_colorcolumn(wp);
  briopt_check(wp);
  fill_culopt_flags(NULL, wp);
  set_fillchars_option(wp, wp->w_p_fcs, true);
  set_listchars_option(wp, wp->w_p_lcs, true);
  parse_winhl_opt(wp);  // sets w_hl_needs_update also for w_p_winbl
  check_blending(wp);
  set_winbar_win(wp, false, valid_cursor);
  wp->w_grid_alloc.blending = wp->w_p_winbl > 0;
}

/// Index into the options table for a buffer-local option enum.
static int buf_opt_idx[BV_COUNT];
#define COPY_OPT_SCTX(buf, bv) buf->b_p_script_ctx[bv] = options[buf_opt_idx[bv]].last_set

/// Initialize buf_opt_idx[] if not done already.
static void init_buf_opt_idx(void)
{
  static int did_init_buf_opt_idx = false;

  if (did_init_buf_opt_idx) {
    return;
  }
  did_init_buf_opt_idx = true;
  for (int i = 0; options[i].fullname != NULL; i++) {
    if (options[i].indir & PV_BUF) {
      buf_opt_idx[options[i].indir & PV_MASK] = i;
    }
  }
}

/// Copy global option values to local options for one buffer.
/// Used when creating a new buffer and sometimes when entering a buffer.
/// flags:
/// BCO_ENTER    We will enter the buffer "buf".
/// BCO_ALWAYS   Always copy the options, but only set b_p_initialized when
///      appropriate.
/// BCO_NOHELP   Don't copy the values to a help buffer.
void buf_copy_options(buf_T *buf, int flags)
{
  int should_copy = true;
  char *save_p_isk = NULL;           // init for GCC
  int did_isk = false;

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
      init_buf_opt_idx();
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
          buf->b_p_ff = xstrdup(FF_MAC);
          break;
        case 'd':
          buf->b_p_ff = xstrdup(FF_DOS);
          break;
        case 'u':
          buf->b_p_ff = xstrdup(FF_UNIX);
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
      COPY_OPT_SCTX(buf, BV_AI);
      buf->b_p_ai_nopaste = p_ai_nopaste;
      buf->b_p_sw = p_sw;
      COPY_OPT_SCTX(buf, BV_SW);
      buf->b_p_scbk = p_scbk;
      COPY_OPT_SCTX(buf, BV_SCBK);
      buf->b_p_tw = p_tw;
      COPY_OPT_SCTX(buf, BV_TW);
      buf->b_p_tw_nopaste = p_tw_nopaste;
      buf->b_p_tw_nobin = p_tw_nobin;
      buf->b_p_wm = p_wm;
      COPY_OPT_SCTX(buf, BV_WM);
      buf->b_p_wm_nopaste = p_wm_nopaste;
      buf->b_p_wm_nobin = p_wm_nobin;
      buf->b_p_bin = p_bin;
      COPY_OPT_SCTX(buf, BV_BIN);
      buf->b_p_bomb = p_bomb;
      COPY_OPT_SCTX(buf, BV_BOMB);
      buf->b_p_et = p_et;
      COPY_OPT_SCTX(buf, BV_ET);
      buf->b_p_fixeol = p_fixeol;
      COPY_OPT_SCTX(buf, BV_FIXEOL);
      buf->b_p_et_nobin = p_et_nobin;
      buf->b_p_et_nopaste = p_et_nopaste;
      buf->b_p_ml = p_ml;
      COPY_OPT_SCTX(buf, BV_ML);
      buf->b_p_ml_nobin = p_ml_nobin;
      buf->b_p_inf = p_inf;
      COPY_OPT_SCTX(buf, BV_INF);
      if (cmdmod.cmod_flags & CMOD_NOSWAPFILE) {
        buf->b_p_swf = false;
      } else {
        buf->b_p_swf = p_swf;
        COPY_OPT_SCTX(buf, BV_SWF);
      }
      buf->b_p_cpt = xstrdup(p_cpt);
      COPY_OPT_SCTX(buf, BV_CPT);
#ifdef BACKSLASH_IN_FILENAME
      buf->b_p_csl = xstrdup(p_csl);
      COPY_OPT_SCTX(buf, BV_CSL);
#endif
      buf->b_p_cfu = xstrdup(p_cfu);
      COPY_OPT_SCTX(buf, BV_CFU);
      set_buflocal_cfu_callback(buf);
      buf->b_p_ofu = xstrdup(p_ofu);
      COPY_OPT_SCTX(buf, BV_OFU);
      set_buflocal_ofu_callback(buf);
      buf->b_p_tfu = xstrdup(p_tfu);
      COPY_OPT_SCTX(buf, BV_TFU);
      set_buflocal_tfu_callback(buf);
      buf->b_p_sts = p_sts;
      COPY_OPT_SCTX(buf, BV_STS);
      buf->b_p_sts_nopaste = p_sts_nopaste;
      buf->b_p_vsts = xstrdup(p_vsts);
      COPY_OPT_SCTX(buf, BV_VSTS);
      if (p_vsts && p_vsts != empty_string_option) {
        (void)tabstop_set(p_vsts, &buf->b_p_vsts_array);
      } else {
        buf->b_p_vsts_array = NULL;
      }
      buf->b_p_vsts_nopaste = p_vsts_nopaste ? xstrdup(p_vsts_nopaste) : NULL;
      buf->b_p_com = xstrdup(p_com);
      COPY_OPT_SCTX(buf, BV_COM);
      buf->b_p_cms = xstrdup(p_cms);
      COPY_OPT_SCTX(buf, BV_CMS);
      buf->b_p_fo = xstrdup(p_fo);
      COPY_OPT_SCTX(buf, BV_FO);
      buf->b_p_flp = xstrdup(p_flp);
      COPY_OPT_SCTX(buf, BV_FLP);
      buf->b_p_nf = xstrdup(p_nf);
      COPY_OPT_SCTX(buf, BV_NF);
      buf->b_p_mps = xstrdup(p_mps);
      COPY_OPT_SCTX(buf, BV_MPS);
      buf->b_p_si = p_si;
      COPY_OPT_SCTX(buf, BV_SI);
      buf->b_p_channel = 0;
      buf->b_p_ci = p_ci;

      COPY_OPT_SCTX(buf, BV_CI);
      buf->b_p_cin = p_cin;
      COPY_OPT_SCTX(buf, BV_CIN);
      buf->b_p_cink = xstrdup(p_cink);
      COPY_OPT_SCTX(buf, BV_CINK);
      buf->b_p_cino = xstrdup(p_cino);
      COPY_OPT_SCTX(buf, BV_CINO);
      buf->b_p_cinsd = xstrdup(p_cinsd);
      COPY_OPT_SCTX(buf, BV_CINSD);
      buf->b_p_lop = xstrdup(p_lop);
      COPY_OPT_SCTX(buf, BV_LOP);

      // Don't copy 'filetype', it must be detected
      buf->b_p_ft = empty_string_option;
      buf->b_p_pi = p_pi;
      COPY_OPT_SCTX(buf, BV_PI);
      buf->b_p_cinw = xstrdup(p_cinw);
      COPY_OPT_SCTX(buf, BV_CINW);
      buf->b_p_lisp = p_lisp;
      COPY_OPT_SCTX(buf, BV_LISP);
      // Don't copy 'syntax', it must be set
      buf->b_p_syn = empty_string_option;
      buf->b_p_smc = p_smc;
      COPY_OPT_SCTX(buf, BV_SMC);
      buf->b_s.b_syn_isk = empty_string_option;
      buf->b_s.b_p_spc = xstrdup(p_spc);
      COPY_OPT_SCTX(buf, BV_SPC);
      (void)compile_cap_prog(&buf->b_s);
      buf->b_s.b_p_spf = xstrdup(p_spf);
      COPY_OPT_SCTX(buf, BV_SPF);
      buf->b_s.b_p_spl = xstrdup(p_spl);
      COPY_OPT_SCTX(buf, BV_SPL);
      buf->b_s.b_p_spo = xstrdup(p_spo);
      COPY_OPT_SCTX(buf, BV_SPO);
      buf->b_p_inde = xstrdup(p_inde);
      COPY_OPT_SCTX(buf, BV_INDE);
      buf->b_p_indk = xstrdup(p_indk);
      COPY_OPT_SCTX(buf, BV_INDK);
      buf->b_p_fp = empty_string_option;
      buf->b_p_fex = xstrdup(p_fex);
      COPY_OPT_SCTX(buf, BV_FEX);
      buf->b_p_sua = xstrdup(p_sua);
      COPY_OPT_SCTX(buf, BV_SUA);
      buf->b_p_keymap = xstrdup(p_keymap);
      COPY_OPT_SCTX(buf, BV_KMAP);
      buf->b_kmap_state |= KEYMAP_INIT;
      // This isn't really an option, but copying the langmap and IME
      // state from the current buffer is better than resetting it.
      buf->b_p_iminsert = p_iminsert;
      COPY_OPT_SCTX(buf, BV_IMI);
      buf->b_p_imsearch = p_imsearch;
      COPY_OPT_SCTX(buf, BV_IMS);

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
      buf->b_p_kp = empty_string_option;
      buf->b_p_path = empty_string_option;
      buf->b_p_tags = empty_string_option;
      buf->b_p_tc = empty_string_option;
      buf->b_tc_flags = 0;
      buf->b_p_def = empty_string_option;
      buf->b_p_inc = empty_string_option;
      buf->b_p_inex = xstrdup(p_inex);
      COPY_OPT_SCTX(buf, BV_INEX);
      buf->b_p_dict = empty_string_option;
      buf->b_p_tsr = empty_string_option;
      buf->b_p_tsrfu = empty_string_option;
      buf->b_p_qe = xstrdup(p_qe);
      COPY_OPT_SCTX(buf, BV_QE);
      buf->b_p_udf = p_udf;
      COPY_OPT_SCTX(buf, BV_UDF);
      buf->b_p_lw = empty_string_option;
      buf->b_p_menc = empty_string_option;

      // Don't copy the options set by ex_help(), use the saved values,
      // when going from a help buffer to a non-help buffer.
      // Don't touch these at all when BCO_NOHELP is used and going from
      // or to a help buffer.
      if (dont_do_help) {
        buf->b_p_isk = save_p_isk;
        if (p_vts && p_vts != empty_string_option && !buf->b_p_vts_array) {
          (void)tabstop_set(p_vts, &buf->b_p_vts_array);
        } else {
          buf->b_p_vts_array = NULL;
        }
      } else {
        buf->b_p_isk = xstrdup(p_isk);
        COPY_OPT_SCTX(buf, BV_ISK);
        did_isk = true;
        buf->b_p_ts = p_ts;
        COPY_OPT_SCTX(buf, BV_TS);
        buf->b_p_vts = xstrdup(p_vts);
        COPY_OPT_SCTX(buf, BV_VTS);
        if (p_vts && p_vts != empty_string_option && !buf->b_p_vts_array) {
          (void)tabstop_set(p_vts, &buf->b_p_vts_array);
        } else {
          buf->b_p_vts_array = NULL;
        }
        buf->b_help = false;
        if (buf->b_p_bt[0] == 'h') {
          clear_string_option(&buf->b_p_bt);
        }
        buf->b_p_ma = p_ma;
        COPY_OPT_SCTX(buf, BV_MA);
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
    (void)buf_init_chartab(buf, false);
  }
}

/// Reset the 'modifiable' option and its default value.
void reset_modifiable(void)
{
  int opt_idx;

  curbuf->b_p_ma = false;
  p_ma = false;
  opt_idx = findoption("ma");
  if (opt_idx >= 0) {
    options[opt_idx].def_val = false;
  }
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

static int expand_option_idx = -1;
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
  char *p = arg + strlen(arg) - 1;
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
  int opt_idx = 0;
  int is_term_option = false;

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
      opt_idx = findoption_len(arg, (size_t)(p - arg));
      if (opt_idx == -1 || options[opt_idx].var == NULL) {
        xp->xp_context = EXPAND_NOTHING;
        return;
      }
      flags = options[opt_idx].flags;
      if (flags & P_BOOL) {
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
    expand_option_idx = -1;
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

  // Now pick. If the option has a custom expander, use that. Otherwise, just
  // fill with the existing option value.
  if (expand_option_subtract) {
    xp->xp_context = EXPAND_SETTING_SUBTRACT;
    return;
  } else if (expand_option_idx >= 0
             && options[expand_option_idx].opt_expand_cb != NULL) {
    xp->xp_context = EXPAND_STRING_SETTING;
  } else if (*xp->xp_pattern == NUL) {
    xp->xp_context = EXPAND_OLD_SETTING;
    return;
  } else {
    xp->xp_context = EXPAND_NOTHING;
  }

  if (is_term_option || (flags & P_NUM)) {
    return;
  }

  // Only string options below

  // Options that have P_EXPAND are considered to all use file/dir expansion.
  if (flags & P_EXPAND) {
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
    if (flags & P_COMMA) {
      xp->xp_backslash |= XP_BS_COMMA;
    }
  }

  // For an option that is a list of file names, or comma/colon-separated
  // values, split it by the delimiter and find the start of the current
  // pattern, while accounting for backslash-escaped space/commas/colons.
  // Triple-backslashed escaped file names (e.g. 'path') can also be
  // delimited by space.
  if ((flags & P_EXPAND) || (flags & P_COMMA) || (flags & P_COLON)) {
    for (p = arg + strlen(arg) - 1; p > xp->xp_pattern; p--) {
      // count number of backslashes before ' ' or ','
      if (*p == ' ' || *p == ',' || (*p == ':' && (flags & P_COLON))) {
        char *s = p;
        while (s > xp->xp_pattern && *(s - 1) == '\\') {
          s--;
        }
        if ((*p == ' ' && ((xp->xp_backslash & XP_BS_THREE) && (p - s) < 3))
#if defined(BACKSLASH_IN_FILENAME)
            || (*p == ',' && (flags & P_COMMA) && (p - s) < 1)
#else
            || (*p == ',' && (flags & P_COMMA) && (p - s) < 2)
#endif
            || (*p == ':' && (flags & P_COLON))) {
          xp->xp_pattern = p + 1;
          break;
        }
      }
    }
  }

  // An option that is a list of single-character flags should always start
  // at the end as we don't complete words.
  if (flags & P_FLAGLIST) {
    xp->xp_pattern = arg + strlen(arg);
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
    for (size_t opt_idx = 0; (str = options[opt_idx].fullname) != NULL;
         opt_idx++) {
      if (options[opt_idx].var == NULL) {
        continue;
      }
      if (xp->xp_context == EXPAND_BOOL_SETTINGS
          && !(options[opt_idx].flags & P_BOOL)) {
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
        && expand_option_idx >= 0
        && (options[expand_option_idx].flags & P_EXPAND)
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

  // For a terminal key code expand_option_idx is < 0.
  if (expand_option_idx < 0) {
    expand_option_idx = findoption(expand_option_name);
  }

  if (expand_option_idx >= 0) {
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
  if (expand_option_idx < 0
      || options[expand_option_idx].opt_expand_cb == NULL) {
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
  if (expand_option_idx < 0) {
    // term option
    return ExpandOldSetting(numMatches, matches);
  }

  char *option_val = *(char **)get_option_varp_scope_from(expand_option_idx,
                                                          expand_option_flags,
                                                          curbuf, curwin);

  uint32_t option_flags = options[expand_option_idx].flags;

  if (option_flags & P_NUM) {
    return ExpandOldSetting(numMatches, matches);
  } else if (option_flags & P_COMMA) {
    // Split the option by comma, then present each option to the user if
    // it matches the pattern.
    // This condition needs to go first, because 'whichwrap' has both
    // P_COMMA and P_FLAGLIST.

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
  } else if (option_flags & P_FLAGLIST) {
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

    (*matches)[count++] = xstrdup(option_val);

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
static void option_value2string(vimoption_T *opp, int scope)
{
  void *varp = get_varp_scope(opp, scope);

  if (opp->flags & P_NUM) {
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
  } else {  // P_STRING
    varp = *(char **)(varp);
    if (varp == NULL) {  // Just in case.
      NameBuff[0] = NUL;
    } else if (opp->flags & P_EXPAND) {
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

/// Check whether global option has been set
///
/// @param[in]  name  Option name.
///
/// @return True if it was set.
bool option_was_set(const char *name)
{
  int idx;

  idx = findoption(name);
  if (idx < 0) {  // Unknown option.
    return false;
  } else if (options[idx].flags & P_WAS_SET) {
    return true;
  }
  return false;
}

/// Reset the flag indicating option "name" was set.
///
/// @param[in]  name  Option name.
void reset_option_was_set(const char *name)
{
  const int idx = findoption(name);
  if (idx < 0) {
    return;
  }

  options[idx].flags &= ~P_WAS_SET;
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

static void didset_options_sctx(int opt_flags, char **buf)
{
  for (int i = 0;; i++) {
    if (buf[i] == NULL) {
      break;
    }

    int idx = findoption(buf[i]);
    if (idx >= 0) {
      set_option_sctx_idx(idx, opt_flags, current_sctx);
    }
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

/// Get the local or global value of 'backupcopy'.
///
/// @param buf The buffer.
unsigned get_bkc_value(buf_T *buf)
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

/// Get the local or global value of the 'virtualedit' flags.
unsigned get_ve_flags(void)
{
  return (curwin->w_ve_flags ? curwin->w_ve_flags : ve_flags) & ~(VE_NONE | VE_NONEU);
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
    p = FF_UNIX;
    break;
  case EOL_MAC:
    p = FF_MAC;
    break;
  case EOL_DOS:
    p = FF_DOS;
    break;
  }

  // p is NULL if "eol_style" is EOL_UNKNOWN.
  if (p != NULL) {
    set_string_option_direct("ff", -1, p, OPT_FREE | opt_flags, 0);
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

/// Return the number of requested sign columns, based on current
/// buffer signs and on user configuration.
int win_signcol_count(win_T *wp)
{
  return win_signcol_configured(wp);
}

/// Return true when window "wp" has no sign column.
bool win_no_signcol(win_T *wp)
{
  const char *scl = wp->w_p_scl;
  return (*scl == 'n' && (*(scl + 1) == 'o' || (*(scl + 1) == 'u'
                                                && (wp->w_p_nu || wp->w_p_rnu))));
}

/// Return the number of requested sign columns, based on user / configuration.
int win_signcol_configured(win_T *wp)
{
  const char *scl = wp->w_p_scl;

  if (win_no_signcol(wp)) {
    return 0;
  }

  // yes or yes
  if (!strncmp(scl, "yes:", 4)) {
    // Fixed amount of columns
    return scl[4] - '0';
  }
  if (*scl == 'y') {
    return 1;
  }

  int minimum = 0, maximum = 1;

  if (!strncmp(scl, "auto:", 5)) {
    // Variable depending on a configuration
    maximum = scl[5] - '0';
    // auto:<NUM>-<NUM>
    if (strlen(scl) == 8 && *(scl + 6) == '-') {
      minimum = maximum;
      maximum = scl[7] - '0';
    }
  }

  int needed_signcols = buf_signcols(wp->w_buffer, maximum);
  int ret = MAX(minimum, MIN(maximum, needed_signcols));
  assert(ret <= SIGN_SHOW_MAX);
  return ret;
}

/// Get window or buffer local options
dict_T *get_winbuf_options(const int bufopt)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  dict_T *const d = tv_dict_alloc();

  for (int opt_idx = 0; options[opt_idx].fullname; opt_idx++) {
    struct vimoption *opt = &options[opt_idx];

    if ((bufopt && (opt->indir & PV_BUF))
        || (!bufopt && (opt->indir & PV_WIN))) {
      void *varp = get_varp(opt);

      if (varp != NULL) {
        if (opt->flags & P_STRING) {
          tv_dict_add_str(d, opt->fullname, strlen(opt->fullname),
                          *(const char **)varp);
        } else if (opt->flags & P_NUM) {
          tv_dict_add_nr(d, opt->fullname, strlen(opt->fullname),
                         *(OptInt *)varp);
        } else {
          tv_dict_add_nr(d, opt->fullname, strlen(opt->fullname), *(int *)varp);
        }
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

Dictionary get_vimoption(String name, int scope, buf_T *buf, win_T *win, Error *err)
{
  int opt_idx = findoption_len(name.data, name.size);
  VALIDATE_S(opt_idx >= 0, "option (not found)", name.data, {
    return (Dictionary)ARRAY_DICT_INIT;
  });

  return vimoption2dict(&options[opt_idx], scope, buf, win);
}

Dictionary get_all_vimoptions(void)
{
  Dictionary retval = ARRAY_DICT_INIT;
  for (size_t i = 0; options[i].fullname != NULL; i++) {
    Dictionary opt_dict = vimoption2dict(&options[i], OPT_GLOBAL, curbuf, curwin);
    PUT(retval, options[i].fullname, DICTIONARY_OBJ(opt_dict));
  }
  return retval;
}

static Dictionary vimoption2dict(vimoption_T *opt, int req_scope, buf_T *buf, win_T *win)
{
  Dictionary dict = ARRAY_DICT_INIT;

  PUT(dict, "name", CSTR_TO_OBJ(opt->fullname));
  PUT(dict, "shortname", CSTR_TO_OBJ(opt->shortname));

  const char *scope;
  if (opt->indir & PV_BUF) {
    scope = "buf";
  } else if (opt->indir & PV_WIN) {
    scope = "win";
  } else {
    scope = "global";
  }

  PUT(dict, "scope", CSTR_TO_OBJ(scope));

  // welcome to the jungle
  PUT(dict, "global_local", BOOLEAN_OBJ(opt->indir & PV_BOTH));
  PUT(dict, "commalist", BOOLEAN_OBJ(opt->flags & P_COMMA));
  PUT(dict, "flaglist", BOOLEAN_OBJ(opt->flags & P_FLAGLIST));

  PUT(dict, "was_set", BOOLEAN_OBJ(opt->flags & P_WAS_SET));

  LastSet last_set = { .channel_id = 0 };
  if (req_scope == OPT_GLOBAL) {
    last_set = opt->last_set;
  } else {
    // Scope is either OPT_LOCAL or a fallback mode was requested.
    if (opt->indir & PV_BUF) {
      last_set = buf->b_p_script_ctx[opt->indir & PV_MASK];
    }
    if (opt->indir & PV_WIN) {
      last_set = win->w_p_script_ctx[opt->indir & PV_MASK];
    }
    if (req_scope != OPT_LOCAL && last_set.script_ctx.sc_sid == 0) {
      last_set = opt->last_set;
    }
  }

  PUT(dict, "last_set_sid", INTEGER_OBJ(last_set.script_ctx.sc_sid));
  PUT(dict, "last_set_linenr", INTEGER_OBJ(last_set.script_ctx.sc_lnum));
  PUT(dict, "last_set_chan", INTEGER_OBJ((int64_t)last_set.channel_id));

  const char *type;
  Object def;
  // TODO(bfredl): do you even nocp?
  char *def_val = opt->def_val;
  if (opt->flags & P_STRING) {
    type = "string";
    def = CSTR_TO_OBJ(def_val ? def_val : "");
  } else if (opt->flags & P_NUM) {
    type = "number";
    def = INTEGER_OBJ((Integer)(intptr_t)def_val);
  } else if (opt->flags & P_BOOL) {
    type = "boolean";
    def = BOOLEAN_OBJ((intptr_t)def_val);
  } else {
    type = ""; def = NIL;
  }
  PUT(dict, "type", CSTR_TO_OBJ(type));
  PUT(dict, "default", def);
  PUT(dict, "allows_duplicates", BOOLEAN_OBJ(!(opt->flags & P_NODUP)));

  return dict;
}
