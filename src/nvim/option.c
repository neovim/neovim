// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
// - If it's a numeric option, add any necessary bounds checks to
//   set_num_option().
// - If it's a list of flags, add some code in do_set(), search for WW_ALL.
// - Add documentation! doc/options.txt, and any other related places.
// - Add an entry in runtime/optwin.vim.

#define IN_OPTION_C
#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/arglist.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor_shape.h"
#include "nvim/decoration_provider.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_session.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/hardcopy.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/keycodes.h"
#include "nvim/locale.h"
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
#include "nvim/optionstr.h"
#include "nvim/os/os.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/spellsuggest.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/undo.h"
#include "nvim/vim.h"
#include "nvim/window.h"
#ifdef WIN32
# include "nvim/os/pty_conpty_win.h"
#endif
#include "nvim/api/extmark.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/lua/executor.h"
#include "nvim/os/input.h"
#include "nvim/os/lang.h"

static char e_unknown_option[]
  = N_("E518: Unknown option");
static char e_not_allowed_in_modeline[]
  = N_("E520: Not allowed in a modeline");
static char e_not_allowed_in_modeline_when_modelineexpr_is_off[]
  = N_("E992: Not allowed in a modeline when 'modelineexpr' is off");
static char e_key_code_not_set[]
  = N_("E846: Key code not set");
static char e_number_required_after_equal[]
  = N_("E521: Number required after =");
static char e_preview_window_already_exists[]
  = N_("E590: A preview window already exists");

// The options that are local to a window or buffer have "indir" set to one of
// these values.  Special values:
// PV_NONE: global option.
// PV_WIN is added: window-local option
// PV_BUF is added: buffer-local option
// PV_BOTH is added: global option which also has a local value.
#define PV_BOTH 0x1000
#define PV_WIN  0x2000
#define PV_BUF  0x4000
#define PV_MASK 0x0fff
#define OPT_WIN(x)  (idopt_T)(PV_WIN + (int)(x))
#define OPT_BUF(x)  (idopt_T)(PV_BUF + (int)(x))
#define OPT_BOTH(x) (idopt_T)(PV_BOTH + (int)(x))

// WV_ and BV_ values get typecasted to this for the "indir" field
typedef enum {
  PV_NONE = 0,
  PV_MAXVAL = 0xffff,  // to avoid warnings for value out of range
} idopt_T;

// Options local to a window have a value local to a buffer and global to all
// buffers.  Indicate this by setting "var" to VAR_WIN.
#define VAR_WIN ((char_u *)-1)

static char *p_term = NULL;
static char *p_ttytype = NULL;

// Saved values for when 'bin' is set.
static int p_et_nobin;
static int p_ml_nobin;
static long p_tw_nobin;
static long p_wm_nobin;

// Saved values for when 'paste' is set.
static int p_ai_nopaste;
static int p_et_nopaste;
static long p_sts_nopaste;
static long p_tw_nopaste;
static long p_wm_nopaste;
static char *p_vsts_nopaste;

typedef struct vimoption {
  char *fullname;        // full option name
  char *shortname;       // permissible abbreviation
  uint32_t flags;               // see below
  char_u *var;             // global option: pointer to variable;
                           // window-local option: VAR_WIN;
                           // buffer-local option: global value
  idopt_T indir;                // global option: PV_NONE;
                                // local option: indirect option index
  char_u *def_val;         // default values for variable (neovim!!)
  LastSet last_set;             // script in which the option was last set
} vimoption_T;

// options[] is initialized here.
// The order of the options MUST be alphabetic for ":set all" and findoption().
// All option names MUST start with a lowercase letter (for findoption()).
// Exception: "t_" options are at the end.
// The options with a NULL variable are 'hidden': a set command for them is
// ignored and they are not printed.

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "options.generated.h"
#endif

#define OPTION_COUNT ARRAY_SIZE(options)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.c.generated.h"
#endif

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
  int opt_idx;

  langmap_init();

  // Find default value for 'shell' option.
  // Don't use it if it is empty.
  {
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

  // Set the default for 'backupskip' to include environment variables for
  // temp files.
  {
#ifdef UNIX
    static char *(names[4]) = { "", "TMPDIR", "TEMP", "TMP" };
#else
    static char *(names[3]) = { "TMPDIR", "TEMP", "TMP" };
#endif
    garray_T ga;
    opt_idx = findoption("backupskip");

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
      } else
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
        if (find_dup_item(ga.ga_data, (char_u *)item, options[opt_idx].flags)
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

  {
    char_u *cdpath;
    char_u *buf;
    int i;
    int j;

    // Initialize the 'cdpath' option's default value.
    cdpath = (char_u *)vim_getenv("CDPATH");
    if (cdpath != NULL) {
      buf = xmalloc(2 * STRLEN(cdpath) + 2);
      {
        buf[0] = ',';               // start with ",", current dir first
        j = 1;
        for (i = 0; cdpath[i] != NUL; i++) {
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
        opt_idx = findoption("cdpath");
        if (opt_idx >= 0) {
          options[opt_idx].def_val = buf;
          options[opt_idx].flags |= P_DEF_ALLOCED;
        } else {
          xfree(buf);           // cannot happen
        }
      }
      xfree(cdpath);
    }
  }

#if defined(MSWIN) || defined(MAC)
  // Set print encoding on platforms that don't default to latin1
  set_string_default("printencoding", "hp-roman8", false);
#endif

  // 'printexpr' must be allocated to be able to evaluate it.
  set_string_default("printexpr",
#ifdef UNIX
                     "system(['lpr'] "
                     "+ (empty(&printdevice)?[]:['-P', &printdevice]) "
                     "+ [v:fname_in])"
                     ". delete(v:fname_in)"
                     "+ v:shell_error",
#elif defined(MSWIN)
                     "system(['copy', v:fname_in, "
                     "empty(&printdevice)?'LPT1':&printdevice])"
                     ". delete(v:fname_in)",
#else
                     "",
#endif
                     false);

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
  // If option_expand() returns non-NULL the variable is expanded.  This can
  // only happen for non-indirect options.
  // Also set the default to the expanded value, so ":set" does not list
  // them.
  // Don't set the P_ALLOCED flag, because we don't want to free the
  // default.
  for (opt_idx = 0; options[opt_idx].fullname; opt_idx++) {
    if (options[opt_idx].flags & P_NO_DEF_EXP) {
      continue;
    }
    char *p;
    if ((options[opt_idx].flags & P_GETTEXT)
        && options[opt_idx].var != NULL) {
      p = _(*(char **)options[opt_idx].var);
    } else {
      p = (char *)option_expand(opt_idx, NULL);
    }
    if (p != NULL) {
      p = xstrdup(p);
      *(char **)options[opt_idx].var = p;
      if (options[opt_idx].flags & P_DEF_ALLOCED) {
        xfree(options[opt_idx].def_val);
      }
      options[opt_idx].def_val = (char_u *)p;
      options[opt_idx].flags |= P_DEF_ALLOCED;
    }
  }

  save_file_ff(curbuf);         // Buffer is unchanged

  // Detect use of mlterm.
  // Mlterm is a terminal emulator akin to xterm that has some special
  // abilities (bidi namely).
  // NOTE: mlterm's author is being asked to 'set' a variable
  //       instead of an environment variable due to inheritance.
  if (os_env_exists("MLTERM")) {
    set_option_value_give_err("tbidi", 1L, NULL, 0);
  }

  didset_options2();

  lang_init();

  // enc_locale() will try to find the encoding of the current locale.
  // This will be used when 'default' is used as encoding specifier
  // in 'fileencodings'
  char_u *p = enc_locale();
  if (p == NULL) {
    // use utf-8 as 'default' if locale encoding can't be detected.
    p = (char_u *)xmemdupz(S_LEN("utf-8"));
  }
  fenc_default = p;

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
static void set_option_default(int opt_idx, int opt_flags)
{
  char_u *varp;            // pointer to variable for current option
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;

  varp = (char_u *)get_varp_scope(&(options[opt_idx]), both ? OPT_LOCAL : opt_flags);
  uint32_t flags = options[opt_idx].flags;
  if (varp != NULL) {       // skip hidden option, nothing to do for it
    if (flags & P_STRING) {
      // Use set_string_option_direct() for local options to handle
      // freeing and allocating the value.
      if (options[opt_idx].indir != PV_NONE) {
        set_string_option_direct(NULL, opt_idx,
                                 (char *)options[opt_idx].def_val, opt_flags, 0);
      } else {
        if ((opt_flags & OPT_FREE) && (flags & P_ALLOCED)) {
          free_string_option(*(char **)(varp));
        }
        *(char_u **)varp = options[opt_idx].def_val;
        options[opt_idx].flags &= ~P_ALLOCED;
      }
    } else if (flags & P_NUM) {
      if (options[opt_idx].indir == PV_SCROLL) {
        win_comp_scroll(curwin);
      } else {
        long def_val = (long)options[opt_idx].def_val;
        if ((long *)varp == &curwin->w_p_so
            || (long *)varp == &curwin->w_p_siso) {
          // 'scrolloff' and 'sidescrolloff' local values have a
          // different default value than the global default.
          *(long *)varp = -1;
        } else {
          *(long *)varp = def_val;
        }
        // May also set global value for local option.
        if (both) {
          *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
            def_val;
        }
      }
    } else {  // P_BOOL
      *(int *)varp = (int)(intptr_t)options[opt_idx].def_val;
#ifdef UNIX
      // 'modeline' defaults to off for root
      if (options[opt_idx].indir == PV_ML && getuid() == ROOT_UID) {
        *(int *)varp = false;
      }
#endif
      // May also set global value for local option.
      if (both) {
        *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
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
    if (options[opt_idx].flags & P_DEF_ALLOCED) {
      xfree(options[opt_idx].def_val);
    }

    options[opt_idx].def_val = allocated
        ? (char_u *)val
        : (char_u *)xstrdup(val);
    options[opt_idx].flags |= P_DEF_ALLOCED;
  }
}

// For an option value that contains comma separated items, find "newval" in
// "origval".  Return NULL if not found.
static char_u *find_dup_item(char_u *origval, const char_u *newval, uint32_t flags)
  FUNC_ATTR_NONNULL_ARG(2)
{
  int bs = 0;

  if (origval == NULL) {
    return NULL;
  }

  const size_t newlen = STRLEN(newval);
  for (char_u *s = origval; *s != NUL; s++) {
    if ((!(flags & P_COMMA) || s == origval || (s[-1] == ',' && !(bs & 1)))
        && STRNCMP(s, newval, newlen) == 0
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
void set_number_default(char *name, long val)
{
  int opt_idx;

  opt_idx = findoption(name);
  if (opt_idx >= 0) {
    options[opt_idx].def_val = (char_u *)(intptr_t)val;
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
        free_string_option(*(char **)options[i].var);
      }
      if (options[i].flags & P_DEF_ALLOCED) {
        free_string_option((char *)options[i].def_val);
      }
    } else if (options[i].var != VAR_WIN && (options[i].flags & P_STRING)) {
      // buffer-local option: free global value
      clear_string_option((char **)options[i].var);
    }
  }
  free_operatorfunc_option();
}
#endif

/// Initialize the options, part two: After getting Rows and Columns.
void set_init_2(bool headless)
{
  // set in set_init_1 but logging is not allowed there
  ILOG("startup runtimepath/packpath value: %s", p_rtp);

  int idx;

  // 'scroll' defaults to half the window height. The stored default is zero,
  // which results in the actual value computed from the window height.
  idx = findoption("scroll");
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
  (void)parse_printoptions();      // parse 'printoptions' default value
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
  p = xstrnsave(p, len);

  {
    //
    // Default for p_sp is "| tee", for p_srr is ">".
    // For known shells it is changed here to include stderr.
    //
    if (FNAMECMP(p, "csh") == 0
        || FNAMECMP(p, "tcsh") == 0) {
      if (do_sp) {
        p_sp = "|& tee";
        options[idx_sp].def_val = (char_u *)p_sp;
      }
      if (do_srr) {
        p_srr = ">&";
        options[idx_srr].def_val = (char_u *)p_srr;
      }
    } else if (FNAMECMP(p, "sh") == 0
               || FNAMECMP(p, "ksh") == 0
               || FNAMECMP(p, "mksh") == 0
               || FNAMECMP(p, "pdksh") == 0
               || FNAMECMP(p, "zsh") == 0
               || FNAMECMP(p, "zsh-beta") == 0
               || FNAMECMP(p, "bash") == 0
               || FNAMECMP(p, "fish") == 0
               || FNAMECMP(p, "ash") == 0
               || FNAMECMP(p, "dash") == 0) {
      // Always use POSIX shell style redirection if we reach this
      if (do_sp) {
        p_sp = "2>&1| tee";
        options[idx_sp].def_val = (char_u *)p_sp;
      }
      if (do_srr) {
        p_srr = ">%s 2>&1";
        options[idx_srr].def_val = (char_u *)p_srr;
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
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET)) {
    if (options[idx].flags & P_ALLOCED) {
      free_string_option((char *)p_hlg);
    }
    p_hlg = (char_u *)xmemdupz(lang, lang_len);
    // zh_CN becomes "cn", zh_TW becomes "tw".
    if (STRNICMP(p_hlg, "zh_", 3) == 0 && STRLEN(p_hlg) >= 5) {
      p_hlg[0] = (char_u)TOLOWER_ASC(p_hlg[3]);
      p_hlg[1] = (char_u)TOLOWER_ASC(p_hlg[4]);
    } else if (STRLEN(p_hlg) >= 1 && *p_hlg == 'C') {
      // any C like setting, such as C.UTF-8, becomes "en"
      p_hlg[0] = 'e';
      p_hlg[1] = 'n';
    }
    p_hlg[2] = NUL;
    options[idx].flags |= P_ALLOCED;
  }
}

/// 'title' and 'icon' only default to true if they have not been set or reset
/// in .vimrc and we can read the old value.
/// When 'title' and 'icon' have been reset in .vimrc, we won't even check if
/// they can be reset.  This reduces startup time when using X on a remote
/// machine.
void set_title_defaults(void)
{
  int idx1;

  // If GUI is (going to be) used, we can always set the window title and
  // icon name.  Saves a bit of time, because the X11 display server does
  // not need to be contacted.
  idx1 = findoption("title");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val = (char_u *)(intptr_t)0;
    p_title = 0;
  }
  idx1 = findoption("icon");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val = (char_u *)(intptr_t)0;
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
  int opt_idx;
  char *errmsg;
  char errbuf[80];
  char *startarg;
  int prefix;           // 1: nothing, 0: "no", 2: "inv" in front of name
  char_u nextchar;                  // next non-white char after option name
  int afterchar;                    // character just after option name
  int len;
  int i;
  varnumber_T value;
  int key;
  uint32_t flags;                   // flags for current option
  char *varp = NULL;                // pointer to variable for current option
  int did_show = false;             // already showed one value
  int adding;                       // "opt+=arg"
  int prepending;                   // "opt^=arg"
  int removing;                     // "opt-=arg"

  if (*arg == NUL) {
    showoptions(0, opt_flags);
    did_show = true;
    goto theend;
  }

  while (*arg != NUL) {         // loop to process all options
    errmsg = NULL;
    startarg = arg;             // remember for error message

    if (STRNCMP(arg, "all", 3) == 0 && !isalpha(arg[3])
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
        showoptions(1, opt_flags);
        did_show = true;
      }
    } else {
      prefix = 1;
      if (STRNCMP(arg, "no", 2) == 0) {
        prefix = 0;
        arg += 2;
      } else if (STRNCMP(arg, "inv", 3) == 0) {
        prefix = 2;
        arg += 3;
      }

      // find end of name
      key = 0;
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
          errmsg = e_invarg;
          goto skip;
        }
        if (arg[1] == 't' && arg[2] == '_') {  // could be term code
          opt_idx = findoption_len((const char *)arg + 1, (size_t)(len - 1));
        }
        len++;
        if (opt_idx == -1) {
          key = find_key_option((char_u *)arg + 1, true);
        }
      } else {
        len = 0;
        // The two characters after "t_" may not be alphanumeric.
        if (arg[0] == 't' && arg[1] == '_' && arg[2] && arg[3]) {
          len = 4;
        } else {
          while (ASCII_ISALNUM(arg[len]) || arg[len] == '_') {
            len++;
          }
        }
        opt_idx = findoption_len((const char *)arg, (size_t)len);
        if (opt_idx == -1) {
          key = find_key_option((char_u *)arg, false);
        }
      }

      // remember character after option name
      afterchar = (uint8_t)arg[len];

      // skip white space, allow ":set ai  ?"
      while (ascii_iswhite(arg[len])) {
        len++;
      }

      adding = false;
      prepending = false;
      removing = false;
      if (arg[len] != NUL && arg[len + 1] == '=') {
        if (arg[len] == '+') {
          adding = true;                        // "+="
          len++;
        } else if (arg[len] == '^') {
          prepending = true;                    // "^="
          len++;
        } else if (arg[len] == '-') {
          removing = true;                      // "-="
          len++;
        }
      }
      nextchar = (uint8_t)arg[len];

      if (opt_idx == -1 && key == 0) {          // found a mismatch: skip
        errmsg = e_unknown_option;
        goto skip;
      }

      if (opt_idx >= 0) {
        if (options[opt_idx].var == NULL) {         // hidden option: skip
          // Only give an error message when requesting the value of
          // a hidden option, ignore setting it.
          if (vim_strchr("=:!&<", nextchar) == NULL
              && (!(options[opt_idx].flags & P_BOOL)
                  || nextchar == '?')) {
            errmsg = e_unsupportedoption;
          }
          goto skip;
        }

        flags = options[opt_idx].flags;
        varp = get_varp_scope(&(options[opt_idx]), opt_flags);
      } else {
        flags = P_STRING;
      }

      // Skip all options that are not window-local (used when showing
      // an already loaded buffer in a window).
      if ((opt_flags & OPT_WINONLY)
          && (opt_idx < 0 || options[opt_idx].var != VAR_WIN)) {
        goto skip;
      }

      // Skip all options that are window-local (used for :vimgrep).
      if ((opt_flags & OPT_NOWIN) && opt_idx >= 0
          && options[opt_idx].var == VAR_WIN) {
        goto skip;
      }

      // Disallow changing some options from modelines.
      if (opt_flags & OPT_MODELINE) {
        if (flags & (P_SECURE | P_NO_ML)) {
          errmsg = e_not_allowed_in_modeline;
          goto skip;
        }
        if ((flags & P_MLE) && !p_mle) {
          errmsg = e_not_allowed_in_modeline_when_modelineexpr_is_off;
          goto skip;
        }
        // In diff mode some options are overruled.  This avoids that
        // 'foldmethod' becomes "marker" instead of "diff" and that
        // "wrap" gets set.
        if (curwin->w_p_diff
            && opt_idx >= 0              // shut up coverity warning
            && (options[opt_idx].indir == PV_FDM
                || options[opt_idx].indir == PV_WRAP)) {
          goto skip;
        }
      }

      // Disallow changing some options in the sandbox
      if (sandbox != 0 && (flags & P_SECURE)) {
        errmsg = e_sandbox;
        goto skip;
      }

      if (vim_strchr("?=:!&<", nextchar) != NULL) {
        arg += len;
        if (nextchar == '&' && arg[1] == 'v' && arg[2] == 'i') {
          if (arg[3] == 'm') {  // "opt&vim": set to Vim default
            arg += 3;
          } else {  // "opt&vi": set to Vi default
            arg += 2;
          }
        }
        if (vim_strchr("?!&<", nextchar) != NULL
            && arg[1] != NUL && !ascii_iswhite(arg[1])) {
          errmsg = e_trailing;
          goto skip;
        }
      }

      //
      // allow '=' and ':' as MS-DOS command.com allows only one
      // '=' character per "set" command line. grrr. (jw)
      //
      if (nextchar == '?'
          || (prefix == 1
              && vim_strchr("=:&<", nextchar) == NULL
              && !(flags & P_BOOL))) {
        // print value
        if (did_show) {
          msg_putchar('\n');                // cursor below last one
        } else {
          gotocmdline(true);                // cursor at status line
          did_show = true;                  // remember that we did a line
        }
        if (opt_idx >= 0) {
          showoneopt(&options[opt_idx], opt_flags);
          if (p_verbose > 0) {
            // Mention where the option was last set.
            if (varp == (char *)options[opt_idx].var) {
              option_last_set_msg(options[opt_idx].last_set);
            } else if ((int)options[opt_idx].indir & PV_WIN) {
              option_last_set_msg(curwin->w_p_script_ctx[
                                                         (int)options[opt_idx].indir & PV_MASK]);
            } else if ((int)options[opt_idx].indir & PV_BUF) {
              option_last_set_msg(curbuf->b_p_script_ctx[
                                                         (int)options[opt_idx].indir & PV_MASK]);
            }
          }
        } else {
          errmsg = e_key_code_not_set;
          goto skip;
        }
        if (nextchar != '?'
            && nextchar != NUL && !ascii_iswhite(afterchar)) {
          errmsg = e_trailing;
        }
      } else {
        int value_is_replaced = !prepending && !adding && !removing;
        int value_checked = false;

        if (flags & P_BOOL) {                       // boolean
          if (nextchar == '=' || nextchar == ':') {
            errmsg = e_invarg;
            goto skip;
          }

          // ":set opt!": invert
          // ":set opt&": reset to default value
          // ":set opt<": reset to global value
          if (nextchar == '!') {
            value = *(int *)(varp) ^ 1;
          } else if (nextchar == '&') {
            value = (int)(intptr_t)options[opt_idx].def_val;
          } else if (nextchar == '<') {
            // For 'autoread' -1 means to use global value.
            if ((int *)varp == &curbuf->b_p_ar
                && opt_flags == OPT_LOCAL) {
              value = -1;
            } else {
              value = *(int *)get_varp_scope(&(options[opt_idx]),
                                             OPT_GLOBAL);
            }
          } else {
            // ":set invopt": invert
            // ":set opt" or ":set noopt": set or reset
            if (nextchar != NUL && !ascii_iswhite(afterchar)) {
              errmsg = e_trailing;
              goto skip;
            }
            if (prefix == 2) {                  // inv
              value = *(int *)(varp) ^ 1;
            } else {
              value = prefix;
            }
          }

          errmsg = set_bool_option(opt_idx, (char_u *)varp, (int)value, opt_flags);
        } else {  // Numeric or string.
          if (vim_strchr("=:&<", nextchar) == NULL
              || prefix != 1) {
            errmsg = e_invarg;
            goto skip;
          }

          if (flags & P_NUM) {                      // numeric
            // Different ways to set a number option:
            // &            set to default value
            // <            set to global value
            // <xx>         accept special key codes for 'wildchar'
            // c            accept any non-digit for 'wildchar'
            // [-]0-9       set number
            // other        error
            arg++;
            if (nextchar == '&') {
              value = (long)(intptr_t)options[opt_idx].def_val;
            } else if (nextchar == '<') {
              // For 'undolevels' NO_LOCAL_UNDOLEVEL means to
              // use the global value.
              if ((long *)varp == &curbuf->b_p_ul && opt_flags == OPT_LOCAL) {
                value = NO_LOCAL_UNDOLEVEL;
              } else {
                value = *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);
              }
            } else if (((long *)varp == &p_wc
                        || (long *)varp == &p_wcm)
                       && (*arg == '<'
                           || *arg == '^'
                           || (*arg != NUL && (!arg[1] || ascii_iswhite(arg[1]))
                               && !ascii_isdigit(*arg)))) {
              value = string_to_key((char_u *)arg);
              if (value == 0 && (long *)varp != &p_wcm) {
                errmsg = e_invarg;
                goto skip;
              }
            } else if (*arg == '-' || ascii_isdigit(*arg)) {
              // Allow negative, octal and hex numbers.
              vim_str2nr(arg, NULL, &i, STR2NR_ALL, &value, NULL, 0, true);
              if (i == 0 || (arg[i] != NUL && !ascii_iswhite(arg[i]))) {
                errmsg = e_number_required_after_equal;
                goto skip;
              }
            } else {
              errmsg = e_number_required_after_equal;
              goto skip;
            }

            if (adding) {
              value = *(long *)varp + value;
            }
            if (prepending) {
              value = *(long *)varp * value;
            }
            if (removing) {
              value = *(long *)varp - value;
            }
            errmsg = set_num_option(opt_idx, (char_u *)varp, (long)value,
                                    errbuf, sizeof(errbuf),
                                    opt_flags);
          } else if (opt_idx >= 0) {  // String.
            char_u *save_arg = NULL;
            char_u *s = NULL;
            char_u *oldval = NULL;         // previous value if *varp
            char_u *newval;
            char_u *origval = NULL;
            char_u *origval_l = NULL;
            char_u *origval_g = NULL;
            char *saved_origval = NULL;
            char *saved_origval_l = NULL;
            char *saved_origval_g = NULL;
            char *saved_newval = NULL;
            unsigned newlen;
            int comma;

            // When using ":set opt=val" for a global option
            // with a local value the local value will be
            // reset, use the global value here.
            if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
                && ((int)options[opt_idx].indir & PV_BOTH)) {
              varp = (char *)options[opt_idx].var;
            }

            // The old value is kept until we are sure that the
            // new value is valid.
            oldval = *(char_u **)varp;

            if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
              origval_l = *(char_u **)get_varp_scope(&(options[opt_idx]), OPT_LOCAL);
              origval_g = *(char_u **)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);

              // A global-local string option might have an empty
              // option as value to indicate that the global
              // value should be used.
              if (((int)options[opt_idx].indir & PV_BOTH) && origval_l == (char_u *)empty_option) {
                origval_l = origval_g;
              }
            }

            // When setting the local value of a global
            // option, the old value may be the global value.
            if (((int)options[opt_idx].indir & PV_BOTH) && (opt_flags & OPT_LOCAL)) {
              origval = *(char_u **)get_varp(&options[opt_idx]);
            } else {
              origval = oldval;
            }

            if (nextchar == '&') {  // set to default val
              newval = options[opt_idx].def_val;
              // expand environment variables and ~ since the
              // default value was already expanded, only
              // required when an environment variable was set
              // later
              if (newval == NULL) {
                newval = (char_u *)empty_option;
              } else if (!(options[opt_idx].flags & P_NO_DEF_EXP)) {
                s = option_expand(opt_idx, newval);
                if (s == NULL) {
                  s = newval;
                }
                newval = vim_strsave(s);
              } else {
                newval = (char_u *)xstrdup((char *)newval);
              }
            } else if (nextchar == '<') {  // set to global val
              newval = vim_strsave(*(char_u **)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL));
            } else {
              arg++;                    // jump to after the '=' or ':'

              // Set 'keywordprg' to ":help" if an empty
              // value was passed to :set by the user.
              // Misuse errbuf[] for the resulting string.
              if (varp == (char *)&p_kp && (*arg == NUL || *arg == ' ')) {
                STRCPY(errbuf, ":help");
                save_arg = (char_u *)arg;
                arg = errbuf;
              } else if (varp == (char *)&p_bs && ascii_isdigit(**(char_u **)varp)) {
                // Convert 'backspace' number to string, for
                // adding, prepending and removing string.
                i = getdigits_int((char **)varp, true, 0);
                switch (i) {
                case 0:
                  *(char **)varp = empty_option;
                  break;
                case 1:
                  *(char_u **)varp = vim_strsave((char_u *)"indent,eol");
                  break;
                case 2:
                  *(char_u **)varp = vim_strsave((char_u *)"indent,eol,start");
                  break;
                case 3:
                  *(char_u **)varp = vim_strsave((char_u *)"indent,eol,nostop");
                  break;
                }
                xfree(oldval);
                if (origval == oldval) {
                  origval = *(char_u **)varp;
                }
                if (origval_l == oldval) {
                  origval_l = *(char_u **)varp;
                }
                if (origval_g == oldval) {
                  origval_g = *(char_u **)varp;
                }
                oldval = *(char_u **)varp;
              } else if (varp == (char *)&p_ww && ascii_isdigit(*arg)) {
                // Convert 'whichwrap' number to string, for
                // backwards compatibility with Vim 3.0.
                // Misuse errbuf[] for the resulting string.
                *errbuf = NUL;
                i = getdigits_int(&arg, true, 0);
                if (i & 1) {
                  STRLCAT(errbuf, "b,", sizeof(errbuf));
                }
                if (i & 2) {
                  STRLCAT(errbuf, "s,", sizeof(errbuf));
                }
                if (i & 4) {
                  STRLCAT(errbuf, "h,l,", sizeof(errbuf));
                }
                if (i & 8) {
                  STRLCAT(errbuf, "<,>,", sizeof(errbuf));
                }
                if (i & 16) {
                  STRLCAT(errbuf, "[,],", sizeof(errbuf));
                }
                save_arg = (char_u *)arg;
                arg = errbuf;
              } else if (*arg == '>'
                         && (varp == (char *)&p_dir
                             || varp == (char *)&p_bdir)) {
                // Remove '>' before 'dir' and 'bdir', for
                // backwards compatibility with version 3.0
                arg++;
              }

              // Copy the new string into allocated memory.
              // Can't use set_string_option_direct(), because
              // we need to remove the backslashes.

              // get a bit too much
              newlen = (unsigned)STRLEN(arg) + 1;
              if (adding || prepending || removing) {
                newlen += (unsigned)STRLEN(origval) + 1;
              }
              newval = xmalloc(newlen);
              s = newval;

              // Copy the string, skip over escaped chars.
              // For WIN32 backslashes before normal
              // file name characters are not removed, and keep
              // backslash at start, for "\\machine\path", but
              // do remove it for "\\\\machine\\path".
              // The reverse is found in ExpandOldSetting().
              while (*arg && !ascii_iswhite(*arg)) {
                if (*arg == '\\' && arg[1] != NUL
#ifdef BACKSLASH_IN_FILENAME
                    && !((flags & P_EXPAND)
                         && vim_isfilec(arg[1])
                         && !ascii_iswhite(arg[1])
                         && (arg[1] != '\\'
                             || (s == newval
                                 && arg[2] != '\\')))
#endif
                    ) {
                  arg++;                        // remove backslash
                }
                i = utfc_ptr2len(arg);
                if (i > 1) {
                  // copy multibyte char
                  memmove(s, arg, (size_t)i);
                  arg += i;
                  s += i;
                } else {
                  *s++ = (uint8_t)(*arg++);
                }
              }
              *s = NUL;

              // Expand environment variables and ~.
              // Don't do it when adding without inserting a
              // comma.
              if (!(adding || prepending || removing)
                  || (flags & P_COMMA)) {
                s = option_expand(opt_idx, newval);
                if (s != NULL) {
                  xfree(newval);
                  newlen = (unsigned)STRLEN(s) + 1;
                  if (adding || prepending || removing) {
                    newlen += (unsigned)STRLEN(origval) + 1;
                  }
                  newval = xmalloc(newlen);
                  STRCPY(newval, s);
                }
              }

              // locate newval[] in origval[] when removing it
              // and when adding to avoid duplicates
              i = 0;                    // init for GCC
              if (removing || (flags & P_NODUP)) {
                i = (int)STRLEN(newval);
                s = find_dup_item(origval, newval, flags);

                // do not add if already there
                if ((adding || prepending) && s != NULL) {
                  prepending = false;
                  adding = false;
                  STRCPY(newval, origval);
                }

                // if no duplicate, move pointer to end of
                // original value
                if (s == NULL) {
                  s = origval + (int)STRLEN(origval);
                }
              }

              // concatenate the two strings; add a ',' if
              // needed
              if (adding || prepending) {
                comma = ((flags & P_COMMA) && *origval != NUL
                         && *newval != NUL);
                if (adding) {
                  i = (int)STRLEN(origval);
                  // Strip a trailing comma, would get 2.
                  if (comma && i > 1
                      && (flags & P_ONECOMMA) == P_ONECOMMA
                      && origval[i - 1] == ','
                      && origval[i - 2] != '\\') {
                    i--;
                  }
                  memmove(newval + i + comma, newval,
                          STRLEN(newval) + 1);
                  memmove(newval, origval, (size_t)i);
                } else {
                  i = (int)STRLEN(newval);
                  STRMOVE(newval + i + comma, origval);
                }
                if (comma) {
                  newval[i] = ',';
                }
              }

              // Remove newval[] from origval[]. (Note: "i" has
              // been set above and is used here).
              if (removing) {
                STRCPY(newval, origval);
                if (*s) {
                  // may need to remove a comma
                  if (flags & P_COMMA) {
                    if (s == origval) {
                      // include comma after string
                      if (s[i] == ',') {
                        i++;
                      }
                    } else {
                      // include comma before string
                      s--;
                      i++;
                    }
                  }
                  STRMOVE(newval + (s - origval), s + i);
                }
              }

              if (flags & P_FLAGLIST) {
                // Remove flags that appear twice.
                for (s = newval; *s;) {
                  // if options have P_FLAGLIST and P_ONECOMMA such as
                  // 'whichwrap'
                  if (flags & P_ONECOMMA) {
                    if (*s != ',' && *(s + 1) == ','
                        && vim_strchr((char *)s + 2, *s) != NULL) {
                      // Remove the duplicated value and the next comma.
                      STRMOVE(s, s + 2);
                      continue;
                    }
                  } else {
                    if ((!(flags & P_COMMA) || *s != ',')
                        && vim_strchr((char *)s + 1, *s) != NULL) {
                      STRMOVE(s, s + 1);
                      continue;
                    }
                  }
                  s++;
                }
              }

              if (save_arg != NULL) {               // number for 'whichwrap'
                arg = (char *)save_arg;
              }
            }

            // Set the new value.
            *(char_u **)(varp) = newval;

            // origval may be freed by
            // did_set_string_option(), make a copy.
            saved_origval = (origval != NULL) ? xstrdup((char *)origval) : 0;
            saved_origval_l = (origval_l != NULL) ? xstrdup((char *)origval_l) : 0;
            saved_origval_g = (origval_g != NULL) ? xstrdup((char *)origval_g) : 0;

            // newval (and varp) may become invalid if the
            // buffer is closed by autocommands.
            saved_newval = (newval != NULL) ? xstrdup((char *)newval) : 0;

            {
              uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
              const int secure_saved = secure;

              // When an option is set in the sandbox, from a
              // modeline or in secure mode, then deal with side
              // effects in secure mode.  Also when the value was
              // set with the P_INSECURE flag and is not
              // completely replaced.
              if ((opt_flags & OPT_MODELINE)
                  || sandbox != 0
                  || (!value_is_replaced && (*p & P_INSECURE))) {
                secure = 1;
              }

              // Handle side effects, and set the global value
              // for ":set" on local options. Note: when setting
              // 'syntax' or 'filetype' autocommands may be
              // triggered that can cause havoc.
              errmsg = did_set_string_option(opt_idx, (char **)varp, (char *)oldval,
                                             errbuf, sizeof(errbuf),
                                             opt_flags, &value_checked);

              secure = secure_saved;
            }

            if (errmsg == NULL) {
              if (!starting) {
                trigger_optionsset_string(opt_idx, opt_flags, saved_origval, saved_origval_l,
                                          saved_origval_g, saved_newval);
              }
              if (options[opt_idx].flags & P_UI_OPTION) {
                ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                                   STRING_OBJ(cstr_as_string(saved_newval)));
              }
            }
            xfree(saved_origval);
            xfree(saved_origval_l);
            xfree(saved_origval_g);
            xfree(saved_newval);

            // If error detected, print the error message.
            if (errmsg != NULL) {
              goto skip;
            }
          } else {
            // key code option(FIXME(tarruda): Show a warning or something
            // similar)
          }
        }

        if (opt_idx >= 0) {
          did_set_option(opt_idx, opt_flags, value_is_replaced, value_checked);
        }
      }

skip:
      // Advance to next argument.
      // - skip until a blank found, taking care of backslashes
      // - skip blanks
      // - skip one "=val" argument (for hidden options ":set gfn =xx")
      for (i = 0; i < 2; i++) {
        while (*arg != NUL && !ascii_iswhite(*arg)) {
          if (*arg++ == '\\' && *arg != NUL) {
            arg++;
          }
        }
        arg = skipwhite(arg);
        if (*arg != '=') {
          break;
        }
      }
    }

    if (errmsg != NULL) {
      STRLCPY(IObuff, _(errmsg), IOSIZE);
      i = (int)STRLEN(IObuff) + 2;
      if (i + (arg - startarg) < IOSIZE) {
        // append the argument with the error
        STRCAT(IObuff, ": ");
        assert(arg >= startarg);
        memmove(IObuff + i, startarg, (size_t)(arg - startarg));
        IObuff[i + (arg - startarg)] = NUL;
      }
      // make sure all characters are printable
      trans_characters((char *)IObuff, IOSIZE);

      no_wait_return++;         // wait_return() done later
      emsg((char *)IObuff);     // show error highlighted
      no_wait_return--;

      return FAIL;
    }

    arg = skipwhite(arg);
  }

theend:
  if (silent_mode && did_show) {
    // After displaying option values in silent mode.
    silent_mode = false;
    info_message = true;        // use mch_msg(), not mch_errmsg()
    msg_putchar('\n');
    ui_flush();
    silent_mode = true;
    info_message = false;       // use mch_msg(), not mch_errmsg()
  }

  return OK;
}

/// Call this when an option has been given a new value through a user command.
/// Sets the P_WAS_SET flag and takes care of the P_INSECURE flag.
///
/// @param opt_flags  possibly with OPT_MODELINE
/// @param new_value  value was replaced completely
/// @param value_checked  value was checked to be safe, no need to set P_INSECURE
void did_set_option(int opt_idx, int opt_flags, int new_value, int value_checked)
{
  options[opt_idx].flags |= P_WAS_SET;

  // When an option is set in the sandbox, from a modeline or in secure mode
  // set the P_INSECURE flag.  Otherwise, if a new value is stored reset the
  // flag.
  uint32_t *p = insecure_flag(curwin, opt_idx, opt_flags);
  if (!value_checked && (secure
                         || sandbox != 0
                         || (opt_flags & OPT_MODELINE))) {
    *p = *p | P_INSECURE;
  } else if (new_value) {
    *p = *p & ~P_INSECURE;
  }
}

/// Convert a key name or string into a key value.
/// Used for 'wildchar' and 'cedit' options.
int string_to_key(char_u *arg)
{
  if (*arg == '<') {
    return find_key_option(arg + 1, true);
  }
  if (*arg == '^') {
    return CTRL_CHR(arg[1]);
  }
  return *arg;
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
}

/// Find the parameter represented by the given character (eg ', :, ", or /),
/// and return its associated value in the 'shada' string.
/// Only works for number parameters, not for 'r' or 'n'.
/// If the parameter is not specified in the string or there is no following
/// number, return -1.
int get_shada_parameter(int type)
{
  char_u *p;

  p = find_shada_parameter(type);
  if (p != NULL && ascii_isdigit(*p)) {
    return atoi((char *)p);
  }
  return -1;
}

/// Find the parameter represented by the given character (eg ''', ':', '"', or
/// '/') in the 'shada' option and return a pointer to the string after it.
/// Return NULL if the parameter is not specified in the string.
char_u *find_shada_parameter(int type)
{
  for (char *p = p_shada; *p; p++) {
    if (*p == type) {
      return (char_u *)p + 1;
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
static char_u *option_expand(int opt_idx, char_u *val)
{
  // if option doesn't need expansion nothing to do
  if (!(options[opt_idx].flags & P_EXPAND) || options[opt_idx].var == NULL) {
    return NULL;
  }

  if (val == NULL) {
    val = *(char_u **)options[opt_idx].var;
  }

  // If val is longer than MAXPATHL no meaningful expansion can be done,
  // expand_env() would truncate the string.
  if (val == NULL || STRLEN(val) > MAXPATHL) {
    return NULL;
  }

  // Expanding this with NameBuff, expand_env() must not be passed IObuff.
  // Escape spaces when expanding 'tags', they are used to separate file
  // names.
  // For 'spellsuggest' expand after "file:".
  expand_env_esc(val, (char_u *)NameBuff, MAXPATHL,
                 (char_u **)options[opt_idx].var == &p_tags, false,
                 (char_u **)options[opt_idx].var == (char_u **)&p_sps ? (char_u *)"file:" :
                 NULL);
  if (STRCMP(NameBuff, val) == 0) {   // they are the same
    return NULL;
  }

  return (char_u *)NameBuff;
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
  (void)check_cedit();
  // initialize the table for 'breakat'.
  fill_breakat_flags();
  didset_window_options(curwin, true);
}

// More side effects of setting options.
static void didset_options2(void)
{
  // Initialize the highlight_attr[] table.
  highlight_changed();

  // Parse default for 'fillchars'.
  (void)set_chars_option(curwin, &curwin->w_p_fcs, true);

  // Parse default for 'listchars'.
  (void)set_chars_option(curwin, &curwin->w_p_lcs, true);

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
  int opt_idx;

  for (opt_idx = 0; options[opt_idx].fullname != NULL; opt_idx++) {
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
static uint32_t *insecure_flag(win_T *const wp, int opt_idx, int opt_flags)
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
  for (const char_u *s = (char_u *)val; *s != NUL; s++) {
    if (!ASCII_ISALNUM(*s)
        && vim_strchr(allowed, *s) == NULL) {
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
  const char *p = (const char *)wp->w_p_winhl;

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
    int hl_id_link = nlen ? syn_check_group(p, nlen) : 0;

    HlAttrs attrs = HLATTRS_INIT;
    attrs.rgb_ae_attr |= HL_GLOBAL;
    ns_hl_def(ns_hl, hl_id_link, attrs, hl_id, NULL);

    p = *commap ? commap + 1 : "";
  }

  wp->w_hl_needs_update = true;
  return true;
}

/// Set the script_ctx for an option, taking care of setting the buffer- or
/// window-local value.
void set_option_sctx_idx(int opt_idx, int opt_flags, sctx_T script_ctx)
{
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int indir = (int)options[opt_idx].indir;
  nlua_set_sctx(&script_ctx);
  const LastSet last_set = {
    .script_ctx = {
      script_ctx.sc_sid,
      script_ctx.sc_seq,
      script_ctx.sc_lnum + SOURCING_LNUM
    },
    current_channel_id
  };

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
    }
  }
}

/// Set the value of a boolean option, taking care of side effects
///
/// @param[in]  opt_idx  Option index in options[] table.
/// @param[out]  varp  Pointer to the option variable.
/// @param[in]  value  New value.
/// @param[in]  opt_flags  OPT_LOCAL and/or OPT_GLOBAL.
///
/// @return NULL on success, error message on error.
static char *set_bool_option(const int opt_idx, char_u *const varp, const int value,
                             const int opt_flags)
{
  int old_value = *(int *)varp;
  int old_global_value = 0;
  char *errmsg = NULL;

  // Disallow changing some options from secure mode
  if ((secure || sandbox != 0)
      && (options[opt_idx].flags & P_SECURE)) {
    return (char *)e_secure;
  }

  // Save the global value before changing anything. This is needed as for
  // a global-only option setting the "local value" in fact sets the global
  // value (since there is only one value).
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    old_global_value = *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);
  }

  *(int *)varp = value;             // set the new value
  // Remember where the option was set.
  set_option_sctx_idx(opt_idx, opt_flags, current_sctx);

  // May set global value for local option.
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = value;
  }

  // Ensure that options set to p_force_on cannot be disabled.
  if ((int *)varp == &p_force_on && p_force_on == false) {
    p_force_on = true;
    return e_unsupportedoption;
    // Ensure that options set to p_force_off cannot be enabled.
  } else if ((int *)varp == &p_force_off && p_force_off == true) {
    p_force_off = false;
    return (char *)e_unsupportedoption;
  } else if ((int *)varp == &p_lrm) {
    // 'langremap' -> !'langnoremap'
    p_lnr = !p_lrm;
  } else if ((int *)varp == &p_lnr) {
    // 'langnoremap' -> !'langremap'
    p_lrm = !p_lnr;
  } else if ((int *)varp == &curbuf->b_p_udf || (int *)varp == &p_udf) {
    // 'undofile'
    // Only take action when the option was set. When reset we do not
    // delete the undo file, the option may be set again without making
    // any changes in between.
    if (curbuf->b_p_udf || p_udf) {
      char_u hash[UNDO_HASH_SIZE];

      FOR_ALL_BUFFERS(bp) {
        // When 'undofile' is set globally: for every buffer, otherwise
        // only for the current buffer: Try to read in the undofile,
        // if one exists, the buffer wasn't changed and the buffer was
        // loaded
        if ((curbuf == bp
             || (opt_flags & OPT_GLOBAL) || opt_flags == 0)
            && !bufIsChanged(bp) && bp->b_ml.ml_mfp != NULL) {
          u_compute_hash(bp, hash);
          u_read_undo(NULL, hash, (char_u *)bp->b_fname);
        }
      }
    }
  } else if ((int *)varp == &curbuf->b_p_ro) {
    // when 'readonly' is reset globally, also reset readonlymode
    if (!curbuf->b_p_ro && (opt_flags & OPT_LOCAL) == 0) {
      readonlymode = false;
    }

    // when 'readonly' is set may give W10 again
    if (curbuf->b_p_ro) {
      curbuf->b_did_warn = false;
    }

    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_ma) {
    // when 'modifiable' is changed, redraw the window title
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_eol) {
    // when 'endofline' is changed, redraw the window title
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_fixeol) {
    // when 'fixeol' is changed, redraw the window title
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_bomb) {
    // when 'bomb' is changed, redraw the window title and tab page text
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_bin) {
    // when 'bin' is set also set some other options
    set_options_bin(old_value, curbuf->b_p_bin, opt_flags);
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_bl && old_value != curbuf->b_p_bl) {
    // when 'buflisted' changes, trigger autocommands
    apply_autocmds(curbuf->b_p_bl ? EVENT_BUFADD : EVENT_BUFDELETE,
                   NULL, NULL, true, curbuf);
  } else if ((int *)varp == &curbuf->b_p_swf) {
    // when 'swf' is set, create swapfile, when reset remove swapfile
    if (curbuf->b_p_swf && p_uc) {
      ml_open_file(curbuf);                     // create the swap file
    } else {
      // no need to reset curbuf->b_may_swap, ml_open_file() will check
      // buf->b_p_swf
      mf_close_file(curbuf, true);              // remove the swap file
    }
  } else if ((int *)varp == &p_paste) {
    // when 'paste' is set or reset also change other options
    paste_option_changed();
  } else if ((int *)varp == &p_ic && p_hls) {
    // when 'ignorecase' is set or reset and 'hlsearch' is set, redraw
    redraw_all_later(UPD_SOME_VALID);
  } else if ((int *)varp == &p_hls) {
    // when 'hlsearch' is set or reset: reset no_hlsearch
    set_no_hlsearch(false);
  } else if ((int *)varp == &curwin->w_p_scb) {
    // when 'scrollbind' is set: snapshot the current position to avoid a jump
    // at the end of normal_cmd()
    if (curwin->w_p_scb) {
      do_check_scrollbind(false);
      curwin->w_scbind_pos = curwin->w_topline;
    }
  } else if ((int *)varp == &curwin->w_p_pvw) {
    // There can be only one window with 'previewwindow' set.
    if (curwin->w_p_pvw) {
      FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
        if (win->w_p_pvw && win != curwin) {
          curwin->w_p_pvw = false;
          return e_preview_window_already_exists;
        }
      }
    }
  } else if (varp == (char_u *)&(curbuf->b_p_lisp)) {
    // When 'lisp' option changes include/exclude '-' in
    // keyword characters.
    (void)buf_init_chartab(curbuf, false);          // ignore errors
  } else if ((int *)varp == &p_title) {
    // when 'title' changed, may need to change the title; same for 'icon'
    did_set_title();
  } else if ((int *)varp == &p_icon) {
    did_set_title();
  } else if ((int *)varp == &curbuf->b_changed) {
    if (!value) {
      save_file_ff(curbuf);             // Buffer is unchanged
    }
    redraw_titles();
    modified_was_set = value;
  }

#ifdef BACKSLASH_IN_FILENAME
  else if ((int *)varp == &p_ssl) {
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
  }
#endif
  else if ((int *)varp == &curwin->w_p_wrap) {
    // If 'wrap' is set, set w_leftcol to zero.
    if (curwin->w_p_wrap) {
      curwin->w_leftcol = 0;
    }
  } else if ((int *)varp == &p_ea) {
    if (p_ea && !old_value) {
      win_equal(curwin, false, 0);
    }
  } else if ((int *)varp == &p_acd) {
    // Change directories when the 'acd' option is set now.
    do_autochdir();
  } else if ((int *)varp == &curwin->w_p_diff) {  // 'diff'
    // May add or remove the buffer from the list of diff buffers.
    diff_buf_adjust(curwin);
    if (foldmethodIsDiff(curwin)) {
      foldUpdateAll(curwin);
    }
  } else if ((int *)varp == &curwin->w_p_spell) {  // 'spell'
    if (curwin->w_p_spell) {
      errmsg = did_set_spelllang(curwin);
    }
  }

  if ((int *)varp == &curwin->w_p_arab) {
    if (curwin->w_p_arab) {
      // 'arabic' is set, handle various sub-settings.
      if (!p_tbidi) {
        // set rightleft mode
        if (!curwin->w_p_rl) {
          curwin->w_p_rl = true;
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
      if (STRCMP(p_enc, "utf-8") != 0) {
        static char *w_arabic = N_("W17: Arabic requires UTF-8, do ':set encoding=utf-8'");

        msg_source(HL_ATTR(HLF_W));
        msg_attr(_(w_arabic), HL_ATTR(HLF_W));
        set_vim_var_string(VV_WARNINGMSG, _(w_arabic), -1);
      }

      // set 'delcombine'
      p_deco = true;

      // Force-set the necessary keymap for arabic.
      errmsg = set_option_value("keymap", 0L, "arabic", OPT_LOCAL);
    } else {
      // 'arabic' is reset, handle various sub-settings.
      if (!p_tbidi) {
        // reset rightleft mode
        if (curwin->w_p_rl) {
          curwin->w_p_rl = false;
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
  }

  // End of handling side effects for bool options.

  // after handling side effects, call autocommand

  options[opt_idx].flags |= P_WAS_SET;

  // Don't do this while starting up or recursively.
  if (!starting && *get_vim_var_str(VV_OPTION_TYPE) == NUL) {
    char buf_old[2];
    char buf_old_global[2];
    char buf_new[2];
    char buf_type[7];
    vim_snprintf(buf_old, ARRAY_SIZE(buf_old), "%d", old_value ? true : false);
    vim_snprintf(buf_old_global, ARRAY_SIZE(buf_old_global), "%d", old_global_value ? true : false);
    vim_snprintf(buf_new, ARRAY_SIZE(buf_new), "%d", value ? true : false);
    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_NEW, buf_new, -1);
    set_vim_var_string(VV_OPTION_OLD, buf_old, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    if (opt_flags & OPT_LOCAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setlocal", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
    }
    if (opt_flags & OPT_GLOBAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setglobal", -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, buf_old, -1);
    }
    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
      set_vim_var_string(VV_OPTION_COMMAND, "set", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, buf_old_global, -1);
    }
    if (opt_flags & OPT_MODELINE) {
      set_vim_var_string(VV_OPTION_COMMAND, "modeline", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
    }
    apply_autocmds(EVENT_OPTIONSET, options[opt_idx].fullname, NULL, false, NULL);
    reset_v_option_vars();
  }

  if (options[opt_idx].flags & P_UI_OPTION) {
    ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                       BOOLEAN_OBJ(*varp));
  }

  comp_col();                       // in case 'ruler' or 'showcmd' changed
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RALL)) != 0) {
    curwin->w_set_curswant = true;
  }
  check_redraw(options[opt_idx].flags);

  return errmsg;
}

/// Set the value of a number option, taking care of side effects
///
/// @param[in]  opt_idx  Option index in options[] table.
/// @param[out]  varp  Pointer to the option variable.
/// @param[in]  value  New value.
/// @param  errbuf  Buffer for error messages.
/// @param[in]  errbuflen  Length of `errbuf`.
/// @param[in]  opt_flags  OPT_LOCAL, OPT_GLOBAL or OPT_MODELINE.
///
/// @return NULL on success, error message on error.
static char *set_num_option(int opt_idx, char_u *varp, long value, char *errbuf, size_t errbuflen,
                            int opt_flags)
{
  char *errmsg = NULL;
  long old_value = *(long *)varp;
  long old_global_value = 0;  // only used when setting a local and global option
  long old_Rows = Rows;       // remember old Rows
  long *pp = (long *)varp;

  // Disallow changing some options from secure mode.
  if ((secure || sandbox != 0)
      && (options[opt_idx].flags & P_SECURE)) {
    return e_secure;
  }

  // Save the global value before changing anything. This is needed as for
  // a global-only option setting the "local value" in fact sets the global
  // value (since there is only one value).
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    old_global_value = *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);
  }

  // Many number options assume their value is in the signed int range.
  if (value < INT_MIN || value > INT_MAX) {
    return e_invarg;
  }

  // Options that need some validation.
  if (pp == &p_wh) {
    if (value < 1) {
      errmsg = e_positive;
    } else if (p_wmh > value) {
      errmsg = e_winheight;
    }
  } else if (pp == &p_hh) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_wmh) {
    if (value < 0) {
      errmsg = e_positive;
    } else if (value > p_wh) {
      errmsg = e_winheight;
    }
  } else if (pp == &p_wiw) {
    if (value < 1) {
      errmsg = e_positive;
    } else if (p_wmw > value) {
      errmsg = e_winwidth;
    }
  } else if (pp == &p_wmw) {
    if (value < 0) {
      errmsg = e_positive;
    } else if (value > p_wiw) {
      errmsg = e_winwidth;
    }
  } else if (pp == &p_mco) {
    value = MAX_MCO;
  } else if (pp == &p_titlelen) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_uc) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_ch) {
    int minval = 0;
    if (value < minval) {
      errmsg = e_positive;
    }
  } else if (pp == &p_tm) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_hi) {
    if (value < 0) {
      errmsg = e_positive;
    } else if (value > 10000) {
      errmsg = e_invarg;
    }
  } else if (pp == &p_pyx) {
    if (value == 0) {
      value = 3;
    } else if (value != 3) {
      errmsg = e_invarg;
    }
  } else if (pp == &p_re) {
    if (value < 0 || value > 2) {
      errmsg = e_invarg;
    }
  } else if (pp == &p_report) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_so) {
    if (value < 0 && full_screen) {
      errmsg = e_positive;
    }
  } else if (pp == &p_siso) {
    if (value < 0 && full_screen) {
      errmsg = e_positive;
    }
  } else if (pp == &p_cwh) {
    if (value < 1) {
      errmsg = e_positive;
    }
  } else if (pp == &p_ut) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_ss) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &curwin->w_p_fdl || pp == &curwin->w_allbuf_opt.wo_fdl) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &curwin->w_p_cole || pp == &curwin->w_allbuf_opt.wo_cole) {
    if (value < 0) {
      errmsg = e_positive;
    } else if (value > 3) {
      errmsg = e_invarg;
    }
  } else if (pp == &curwin->w_p_nuw || pp == &curwin->w_allbuf_opt.wo_nuw) {
    if (value < 1) {
      errmsg = e_positive;
    } else if (value > 20) {
      errmsg = e_invarg;
    }
  } else if (pp == &curbuf->b_p_iminsert || pp == &p_iminsert) {
    if (value < 0 || value > B_IMODE_LAST) {
      errmsg = e_invarg;
    }
  } else if (pp == &curbuf->b_p_imsearch || pp == &p_imsearch) {
    if (value < -1 || value > B_IMODE_LAST) {
      errmsg = e_invarg;
    }
  } else if (pp == &curbuf->b_p_channel || pp == &p_channel) {
    errmsg = e_invarg;
  } else if (pp == &curbuf->b_p_scbk || pp == &p_scbk) {
    if (value < -1 || value > SB_MAX) {
      errmsg = e_invarg;
    }
  } else if (pp == &curbuf->b_p_sw || pp == &p_sw) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &curbuf->b_p_ts || pp == &p_ts) {
    if (value < 1) {
      errmsg = e_positive;
    } else if (value > TABSTOP_MAX) {
      errmsg = e_invarg;
    }
  } else if (pp == &curbuf->b_p_tw || pp == &p_tw) {
    if (value < 0) {
      errmsg = e_positive;
    }
  } else if (pp == &p_wd) {
    if (value < 0) {
      errmsg = e_positive;
    }
  }

  // Don't change the value and return early if validation failed.
  if (errmsg != NULL) {
    return errmsg;
  }

  *pp = value;
  // Remember where the option was set.
  set_option_sctx_idx(opt_idx, opt_flags, current_sctx);

  // For these options we want to fix some invalid values.
  if (pp == &p_window) {
    if (p_window < 1) {
      p_window = Rows - 1;
    } else if (p_window >= Rows) {
      p_window = Rows - 1;
    }
  } else if (pp == &p_ch) {
    if (ui_has(kUIMessages)) {
      p_ch = 0;
    }
    if (p_ch > Rows - min_rows() + 1) {
      p_ch = Rows - min_rows() + 1;
    }
  }

  // Number options that need some action when changed
  if (pp == &p_wh) {
    // 'winheight'
    if (!ONE_WINDOW && curwin->w_height < p_wh) {
      win_setheight((int)p_wh);
    }
  } else if (pp == &p_hh) {
    // 'helpheight'
    if (!ONE_WINDOW && curbuf->b_help && curwin->w_height < p_hh) {
      win_setheight((int)p_hh);
    }
  } else if (pp == &p_wmh) {
    // 'winminheight'
    win_setminheight();
  } else if (pp == &p_wiw) {
    // 'winwidth'
    if (!ONE_WINDOW && curwin->w_width < p_wiw) {
      win_setwidth((int)p_wiw);
    }
  } else if (pp == &p_wmw) {
    // 'winminwidth'
    win_setminwidth();
  } else if (pp == &p_ls) {
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
  } else if (pp == &p_stal) {
    // (re)set tab page line
    win_new_screen_rows();   // recompute window positions and heights
  } else if (pp == &curwin->w_p_fdl) {
    newFoldLevel();
  } else if (pp == &curwin->w_p_fml) {
    foldUpdateAll(curwin);
  } else if (pp == &curwin->w_p_fdn) {
    if (foldmethodIsSyntax(curwin) || foldmethodIsIndent(curwin)) {
      foldUpdateAll(curwin);
    }
  } else if (pp == &curbuf->b_p_sw || pp == &curbuf->b_p_ts) {
    // 'shiftwidth' or 'tabstop'
    if (foldmethodIsIndent(curwin)) {
      foldUpdateAll(curwin);
    }
    // When 'shiftwidth' changes, or it's zero and 'tabstop' changes:
    // parse 'cinoptions'.
    if (pp == &curbuf->b_p_sw || curbuf->b_p_sw == 0) {
      parse_cino(curbuf);
    }
  } else if (pp == &curbuf->b_p_iminsert) {
    showmode();
    // Show/unshow value of 'keymap' in status lines.
    status_redraw_curbuf();
  } else if (pp == &p_titlelen) {
    // if 'titlelen' has changed, redraw the title
    if (starting != NO_SCREEN && old_value != p_titlelen) {
      need_maketitle = true;
    }
  } else if (pp == &p_ch) {
    // if p_ch changed value, change the command line height
    // Only compute the new window layout when startup has been
    // completed. Otherwise the frame sizes may be wrong.
    if (p_ch != old_value && full_screen) {
      command_height();
    }
  } else if (pp == &p_uc) {
    // when 'updatecount' changes from zero to non-zero, open swap files
    if (p_uc && !old_value) {
      ml_open_files();
    }
  } else if (pp == &p_pb) {
    p_pb = MAX(MIN(p_pb, 100), 0);
    hl_invalidate_blends();
    pum_grid.blending = (p_pb > 0);
    if (pum_drawn()) {
      pum_redraw();
    }
  } else if (pp == &p_ul || pp == &curbuf->b_p_ul) {
    // sync undo before 'undolevels' changes
    // use the old value, otherwise u_sync() may not work properly
    *pp = old_value;
    u_sync(true);
    *pp = value;
  } else if (pp == &curbuf->b_p_tw) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      check_colorcolumn(wp);
    }
  } else if (pp == &curbuf->b_p_scbk || pp == &p_scbk) {
    if (curbuf->terminal && value < old_value) {
      // Force the scrollback to take immediate effect only when decreasing it.
      on_scrollback_option_changed(curbuf->terminal);
    }
  } else if (pp == &curwin->w_p_nuw) {
    curwin->w_nrwidth_line_count = 0;
  } else if (pp == &curwin->w_p_winbl && value != old_value) {
    // 'winblend'
    curwin->w_p_winbl = MAX(MIN(curwin->w_p_winbl, 100), 0);
    curwin->w_hl_needs_update = true;
    check_blending(curwin);
  }

  // Check the (new) bounds for Rows and Columns here.
  if (p_lines < min_rows() && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf(errbuf, errbuflen,
                   _("E593: Need at least %d lines"), min_rows());
      errmsg = errbuf;
    }
    p_lines = min_rows();
  }
  if (p_columns < MIN_COLUMNS && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf(errbuf, errbuflen,
                   _("E594: Need at least %d columns"), MIN_COLUMNS);
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
      if (cmdline_row > Rows - p_ch && Rows > p_ch) {
        assert(p_ch >= 0 && Rows - p_ch <= INT_MAX);
        cmdline_row = (int)(Rows - p_ch);
      }
    }
    if (p_window >= Rows || !option_was_set("window")) {
      p_window = Rows - 1;
    }
  }

  if ((curwin->w_p_scr <= 0
       || (curwin->w_p_scr > curwin->w_height
           && curwin->w_height > 0))
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
    if (Rows != old_Rows) {     // Rows changed, just adjust p_sj
      p_sj = Rows / 2;
    } else {
      errmsg = e_scroll;
      p_sj = 1;
    }
  }

  // May set global value for local option.
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
    *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = *pp;
  }

  options[opt_idx].flags |= P_WAS_SET;

  // Don't do this while starting up, failure or recursively.
  if (!starting && errmsg == NULL && *get_vim_var_str(VV_OPTION_TYPE) == NUL) {
    char buf_old[NUMBUFLEN];
    char buf_old_global[NUMBUFLEN];
    char buf_new[NUMBUFLEN];
    char buf_type[7];

    vim_snprintf(buf_old, ARRAY_SIZE(buf_old), "%ld", old_value);
    vim_snprintf(buf_old_global, ARRAY_SIZE(buf_old_global), "%ld", old_global_value);
    vim_snprintf(buf_new, ARRAY_SIZE(buf_new), "%ld", value);
    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_NEW, buf_new, -1);
    set_vim_var_string(VV_OPTION_OLD, buf_old, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    if (opt_flags & OPT_LOCAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setlocal", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
    }
    if (opt_flags & OPT_GLOBAL) {
      set_vim_var_string(VV_OPTION_COMMAND, "setglobal", -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, buf_old, -1);
    }
    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0) {
      set_vim_var_string(VV_OPTION_COMMAND, "set", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
      set_vim_var_string(VV_OPTION_OLDGLOBAL, buf_old_global, -1);
    }
    if (opt_flags & OPT_MODELINE) {
      set_vim_var_string(VV_OPTION_COMMAND, "modeline", -1);
      set_vim_var_string(VV_OPTION_OLDLOCAL, buf_old, -1);
    }
    apply_autocmds(EVENT_OPTIONSET, options[opt_idx].fullname, NULL, false, NULL);
    reset_v_option_vars();
  }

  if (errmsg == NULL && options[opt_idx].flags & P_UI_OPTION) {
    ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                       INTEGER_OBJ(*pp));
  }

  comp_col();                       // in case 'columns' or 'ls' changed
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RALL)) != 0) {
    curwin->w_set_curswant = true;
  }
  check_redraw(options[opt_idx].flags);

  return errmsg;
}

/// Called after an option changed: check if something needs to be redrawn.
void check_redraw(uint32_t flags)
{
  // Careful: P_RCLR and P_RALL are a combination of other P_ flags
  bool doclear = (flags & P_RCLR) == P_RCLR;
  bool all = ((flags & P_RALL) == P_RALL || doclear);

  if ((flags & P_RSTAT) || all) {  // mark all status lines and window bars dirty
    status_redraw_all();
  }

  if ((flags & P_RBUF) || (flags & P_RWIN) || all) {
    changed_window_setting();
  }
  if (flags & P_RBUF) {
    redraw_curbuf_later(UPD_NOT_VALID);
  }
  if (flags & P_RWINONLY) {
    redraw_later(curwin, UPD_NOT_VALID);
  }
  if (doclear) {
    redraw_all_later(UPD_CLEAR);
  } else if (all) {
    redraw_all_later(UPD_NOT_VALID);
  }
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
  const char *p;
  static int quick_tab[27] = { 0, 0 };  // quick access table

  // For first call: Initialize the quick-access table.
  // It contains the index for the first option that starts with a certain
  // letter.  There are 26 letters, plus the first "t_" option.
  if (quick_tab[1] == 0) {
    p = options[0].fullname;
    for (short int i = 1; (s = options[i].fullname) != NULL; i++) {
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
    if (STRNCMP(options[opt_idx].fullname, "viminfo", 7) == 0) {
      if (STRLEN(options[opt_idx].fullname) == 7) {
        return findoption_len("shada", 5);
      }
      assert(STRCMP(options[opt_idx].fullname, "viminfofile") == 0);
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

void set_tty_background(const char *value)
{
  if (option_was_set("bg") || strequal(p_bg, value)) {
    // background is already set... ignore
    return;
  }
  if (starting) {
    // Wait until after startup, so OptionSet is triggered.
    do_cmdline_cmd((value[0] == 'l')
                   ? "autocmd VimEnter * ++once ++nested set bg=light"
                   : "autocmd VimEnter * ++once ++nested set bg=dark");
  } else {
    set_option_value_give_err("bg", 0L, value, 0);
    reset_option_was_set("bg");
  }
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

/// Gets the value for an option.
///
/// @param stringval  NULL when only checking existence
///
/// @returns:
///           Number option: gov_number, *numval gets value.
///           Tottle option: gov_bool,   *numval gets value.
///           String option: gov_string, *stringval gets allocated string.
///           Hidden Number option: gov_hidden_number.
///           Hidden Toggle option: gov_hidden_bool.
///           Hidden String option: gov_hidden_string.
///           Unknown option: gov_unknown.
getoption_T get_option_value(const char *name, long *numval, char **stringval, int opt_flags)
{
  if (get_tty_option(name, stringval)) {
    return gov_string;
  }

  int opt_idx = findoption(name);
  if (opt_idx < 0) {  // option not in the table
    return gov_unknown;
  }

  char_u *varp = (char_u *)get_varp_scope(&(options[opt_idx]), opt_flags);

  if (options[opt_idx].flags & P_STRING) {
    if (varp == NULL) {  // hidden option
      return gov_hidden_string;
    }
    if (stringval != NULL) {
      if ((char **)varp == &p_pt) {  // 'pastetoggle'
        *stringval = str2special_save(*(char **)(varp), false, false);
      } else {
        *stringval = xstrdup(*(char **)(varp));
      }
    }
    return gov_string;
  }

  if (varp == NULL) {  // hidden option
    return (options[opt_idx].flags & P_NUM) ? gov_hidden_number : gov_hidden_bool;
  }
  if (options[opt_idx].flags & P_NUM) {
    *numval = *(long *)varp;
  } else {
    // Special case: 'modified' is b_changed, but we also want to consider
    // it set when 'ff' or 'fenc' changed.
    if ((int *)varp == &curbuf->b_changed) {
      *numval = curbufIsChanged();
    } else {
      *numval = (long)(*(int *)varp);
    }
  }
  return (options[opt_idx].flags & P_NUM) ? gov_number : gov_bool;
}

// Returns the option attributes and its value. Unlike the above function it
// will return either global value or local value of the option depending on
// what was requested, but it will never return global value if it was
// requested to return local one and vice versa. Neither it will return
// buffer-local value if it was requested to return window-local one.
//
// Pretends that option is absent if it is not present in the requested scope
// (i.e. has no global, window-local or buffer-local value depending on
// opt_type).
//
// Returned flags:
//       0 hidden or unknown option, also option that does not have requested
//         type (see SREQ_* in option_defs.h)
//  see SOPT_* in option_defs.h for other flags
//
// Possible opt_type values: see SREQ_* in option_defs.h
int get_option_value_strict(char *name, int64_t *numval, char **stringval, int opt_type, void *from)
{
  if (get_tty_option(name, stringval)) {
    return SOPT_STRING | SOPT_GLOBAL;
  }

  char_u *varp = NULL;
  int rv = 0;
  int opt_idx = findoption(name);
  if (opt_idx < 0) {
    return 0;
  }

  vimoption_T *p = &options[opt_idx];

  // Hidden option
  if (p->var == NULL) {
    return 0;
  }

  if (p->flags & P_BOOL) {
    rv |= SOPT_BOOL;
  } else if (p->flags & P_NUM) {
    rv |= SOPT_NUM;
  } else if (p->flags & P_STRING) {
    rv |= SOPT_STRING;
  }

  if (p->indir == PV_NONE) {
    if (opt_type == SREQ_GLOBAL) {
      rv |= SOPT_GLOBAL;
    } else {
      return 0;  // Did not request global-only option
    }
  } else {
    if (p->indir & PV_BOTH) {
      rv |= SOPT_GLOBAL;
    }

    if (p->indir & PV_WIN) {
      if (opt_type == SREQ_BUF) {
        return 0;  // Requested buffer-local, not window-local option
      } else {
        rv |= SOPT_WIN;
      }
    } else if (p->indir & PV_BUF) {
      if (opt_type == SREQ_WIN) {
        return 0;  // Requested window-local, not buffer-local option
      } else {
        rv |= SOPT_BUF;
      }
    }
  }

  if (stringval == NULL) {
    return rv;
  }

  if (opt_type == SREQ_GLOBAL) {
    if (p->var == VAR_WIN) {
      return 0;
    } else {
      varp = p->var;
    }
  } else {
    if (opt_type == SREQ_BUF) {
      // Special case: 'modified' is b_changed, but we also want to
      // consider it set when 'ff' or 'fenc' changed.
      if (p->indir == PV_MOD) {
        *numval = bufIsChanged((buf_T *)from);
        varp = NULL;
      } else {
        buf_T *save_curbuf = curbuf;

        // only getting a pointer, no need to use aucmd_prepbuf()
        curbuf = (buf_T *)from;
        curwin->w_buffer = curbuf;
        varp = (char_u *)get_varp_scope(p, OPT_LOCAL);
        curbuf = save_curbuf;
        curwin->w_buffer = curbuf;
      }
    } else if (opt_type == SREQ_WIN) {
      win_T *save_curwin = curwin;
      curwin = (win_T *)from;
      curbuf = curwin->w_buffer;
      varp = (char_u *)get_varp_scope(p, OPT_LOCAL);
      curwin = save_curwin;
      curbuf = curwin->w_buffer;
    }

    if (varp == p->var) {
      return (rv | SOPT_UNSET);
    }
  }

  if (varp != NULL) {
    if (p->flags & P_STRING) {
      *stringval = xstrdup(*(char **)(varp));
    } else if (p->flags & P_NUM) {
      *numval = *(long *)varp;
    } else {
      *numval = *(int *)varp;
    }
  }

  return rv;
}

/// Return the flags for the option at 'opt_idx'.
uint32_t get_option_flags(int opt_idx)
{
  return options[opt_idx].flags;
}

/// Set a flag for the option at 'opt_idx'.
void set_option_flag(int opt_idx, uint32_t flag)
{
  options[opt_idx].flags |= flag;
}

/// Clear a flag for the option at 'opt_idx'.
void clear_option_flag(int opt_idx, uint32_t flag)
{
  options[opt_idx].flags &= ~flag;
}

/// Returns true if the option at 'opt_idx' is a global option
bool is_global_option(int opt_idx)
{
  return options[opt_idx].indir == PV_NONE;
}

/// Returns true if the option at 'opt_idx' is a global option which also has a
/// local value.
int is_global_local_option(int opt_idx)
{
  return options[opt_idx].indir & PV_BOTH;
}

/// Returns true if the option at 'opt_idx' is a window-local option
bool is_window_local_option(int opt_idx)
{
  return options[opt_idx].var == VAR_WIN;
}

/// Returns true if the option at 'opt_idx' is a hidden option
bool is_hidden_option(int opt_idx)
{
  return options[opt_idx].var == NULL;
}

/// Set the value of an option
///
/// @param[in]  name  Option name.
/// @param[in]  number  New value for the number or boolean option.
/// @param[in]  string  New value for string option.
/// @param[in]  opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///                        If OPT_CLEAR is set, the value of the option
///                        is cleared  (the exact semantics of this depend
///                        on the option).
///
/// @return NULL on success, an untranslated error message on error.
char *set_option_value(const char *const name, const long number, const char *const string,
                       const int opt_flags)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (is_tty_option(name)) {
    return NULL;  // Fail silently; many old vimrcs set t_xx options.
  }

  int opt_idx;
  char_u *varp;

  opt_idx = findoption(name);
  if (opt_idx < 0) {
    semsg(_("E355: Unknown option: %s"), name);
  } else {
    uint32_t flags = options[opt_idx].flags;
    // Disallow changing some options in the sandbox
    if (sandbox > 0 && (flags & P_SECURE)) {
      emsg(_(e_sandbox));
      return NULL;
    }
    if (flags & P_STRING) {
      const char *s = string;
      if (s == NULL || opt_flags & OPT_CLEAR) {
        s = "";
      }
      return set_string_option(opt_idx, s, opt_flags);
    }

    varp = (char_u *)get_varp_scope(&(options[opt_idx]), opt_flags);
    if (varp != NULL) {       // hidden option is not changed
      if (number == 0 && string != NULL) {
        int idx;

        // Either we are given a string or we are setting option
        // to zero.
        for (idx = 0; string[idx] == '0'; idx++) {}
        if (string[idx] != NUL || idx == 0) {
          // There's another character after zeros or the string
          // is empty.  In both cases, we are trying to set a
          // num option using a string.
          semsg(_("E521: Number required: &%s = '%s'"),
                name, string);
          return NULL;  // do nothing as we hit an error
        }
      }
      long numval = number;
      if (opt_flags & OPT_CLEAR) {
        if ((int *)varp == &curbuf->b_p_ar) {
          numval = -1;
        } else if ((long *)varp == &curbuf->b_p_ul) {
          numval = NO_LOCAL_UNDOLEVEL;
        } else if ((long *)varp == &curwin->w_p_so || (long *)varp == &curwin->w_p_siso) {
          numval = -1;
        } else {
          char *s = NULL;
          (void)get_option_value(name, &numval, &s, OPT_GLOBAL);
        }
      }
      if (flags & P_NUM) {
        return set_num_option(opt_idx, varp, numval, NULL, 0, opt_flags);
      } else {
        return set_bool_option(opt_idx, varp, (int)numval, opt_flags);
      }
    }
  }
  return NULL;
}

/// Call set_option_value() and when an error is returned report it.
///
/// @param opt_flags  OPT_LOCAL or 0 (both)
void set_option_value_give_err(const char *name, long number, const char *string, int opt_flags)
{
  char *errmsg = set_option_value(name, number, string, opt_flags);

  if (errmsg != NULL) {
    emsg(_(errmsg));
  }
}

/// Return true if "name" is a string option.
/// Returns false if option "name" does not exist.
bool is_string_option(const char *name)
{
  int idx = findoption(name);
  return idx >= 0 && (options[idx].flags & P_STRING);
}

// Translate a string like "t_xx", "<t_xx>" or "<S-Tab>" to a key number.
// When "has_lt" is true there is a '<' before "*arg_arg".
// Returns 0 when the key is not recognized.
int find_key_option_len(const char_u *arg_arg, size_t len, bool has_lt)
{
  int key = 0;
  int modifiers;
  const char_u *arg = arg_arg;

  // Don't use get_special_key_code() for t_xx, we don't want it to call
  // add_termcap_entry().
  if (len >= 4 && arg[0] == 't' && arg[1] == '_') {
    key = TERMCAP2KEY(arg[2], arg[3]);
  } else if (has_lt) {
    arg--;  // put arg at the '<'
    modifiers = 0;
    key = find_special_key(&arg, len + 1, &modifiers,
                           FSK_KEYCODE | FSK_KEEP_X_KEY | FSK_SIMPLIFY, NULL);
    if (modifiers) {  // can't handle modifiers here
      key = 0;
    }
  }
  return key;
}

static int find_key_option(const char_u *arg, bool has_lt)
{
  return find_key_option_len(arg, STRLEN(arg), has_lt);
}

/// if 'all' == 0: show changed options
/// if 'all' == 1: show all normal options
///
/// @param opt_flags  OPT_LOCAL and/or OPT_GLOBAL
static void showoptions(int all, int opt_flags)
{
  vimoption_T *p;
  int col;
  char_u *varp;
  int item_count;
  int run;
  int row, rows;
  int cols;
  int i;
  int len;

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
  for (run = 1; run <= 2 && !got_int; run++) {
    // collect the items in items[]
    item_count = 0;
    for (p = &options[0]; p->fullname != NULL; p++) {
      // apply :filter /pat/
      if (message_filtered(p->fullname)) {
        continue;
      }

      varp = NULL;
      if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) != 0) {
        if (p->indir != PV_NONE) {
          varp = (char_u *)get_varp_scope(p, opt_flags);
        }
      } else {
        varp = get_varp(p);
      }
      if (varp != NULL
          && (all == 1 || (all == 0 && !optval_default(p, varp)))) {
        if (opt_flags & OPT_ONECOLUMN) {
          len = Columns;
        } else if (p->flags & P_BOOL) {
          len = 1;                      // a toggle option fits always
        } else {
          option_value2string(p, opt_flags);
          len = (int)STRLEN(p->fullname) + vim_strsize((char *)NameBuff) + 1;
        }
        if ((len <= INC - GAP && run == 1)
            || (len > INC - GAP && run == 2)) {
          items[item_count++] = p;
        }
      }
    }

    // display the items
    if (run == 1) {
      assert(Columns <= INT_MAX - GAP
             && Columns + GAP >= INT_MIN + 3
             && (Columns + GAP - 3) / INC >= INT_MIN
             && (Columns + GAP - 3) / INC <= INT_MAX);
      cols = (Columns + GAP - 3) / INC;
      if (cols == 0) {
        cols = 1;
      }
      rows = (item_count + cols - 1) / cols;
    } else {    // run == 2
      rows = item_count;
    }
    for (row = 0; row < rows && !got_int; row++) {
      msg_putchar('\n');                        // go to next line
      if (got_int) {                            // 'q' typed in more
        break;
      }
      col = 0;
      for (i = row; i < item_count; i += rows) {
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
static int optval_default(vimoption_T *p, char_u *varp)
{
  if (varp == NULL) {
    return true;            // hidden option is always at default
  }
  if (p->flags & P_NUM) {
    return *(long *)varp == (long)(intptr_t)p->def_val;
  }
  if (p->flags & P_BOOL) {
    return *(int *)varp == (int)(intptr_t)p->def_val;
  }
  // P_STRING
  return STRCMP(*(char_u **)varp, p->def_val) == 0;
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
      value = INTEGER_OBJ(*(long *)varp);
    } else if (flags & P_STRING) {
      // cstr_as_string handles NULL string
      value = STRING_OBJ(cstr_as_string(*(char **)varp));
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
  info_message = true;          // use mch_msg(), not mch_errmsg()

  char_u *varp = (char_u *)get_varp_scope(p, opt_flags);

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
    msg_outtrans((char *)NameBuff);
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
  vimoption_T *p;
  char *varp;                      // currently used value
  char_u *varp_fresh;              // local value
  char_u *varp_local = NULL;       // fresh value
  char *cmd;
  int round;
  int pri;

  // Some options are never written:
  // - Options that don't have a default (terminal name, columns, lines).
  // - Terminal options.
  // - Hidden options.
  //
  // Do the loop over "options[]" twice: once for options with the
  // P_PRI_MKRC flag and once without.
  for (pri = 1; pri >= 0; pri--) {
    for (p = &options[0]; p->fullname; p++) {
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

        varp = get_varp_scope(p, opt_flags);
        // Hidden options are never written.
        if (!varp) {
          continue;
        }
        // Global values are only written when not at the default value.
        if ((opt_flags & OPT_GLOBAL) && optval_default(p, (char_u *)varp)) {
          continue;
        }

        if ((opt_flags & OPT_SKIPRTP)
            && (p->var == (char_u *)&p_rtp || p->var == (char_u *)&p_pp)) {
          continue;
        }

        round = 2;
        if (p->indir != PV_NONE) {
          if (p->var == VAR_WIN) {
            // skip window-local option when only doing globals
            if (!(opt_flags & OPT_LOCAL)) {
              continue;
            }
            // When fresh value of window-local option is not at the
            // default, need to write it too.
            if (!(opt_flags & OPT_GLOBAL) && !local_only) {
              varp_fresh = (char_u *)get_varp_scope(p, OPT_GLOBAL);
              if (!optval_default(p, varp_fresh)) {
                round = 1;
                varp_local = (char_u *)varp;
                varp = (char *)varp_fresh;
              }
            }
          }
        }

        // Round 1: fresh value for window-local options.
        // Round 2: other values
        for (; round <= 2; varp = (char *)varp_local, round++) {
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
            if (put_setnum(fd, cmd, p->fullname, (long *)varp) == FAIL) {
              return FAIL;
            }
          } else {    // P_STRING
            int do_endif = false;

            // Don't set 'syntax' and 'filetype' again if the value is
            // already right, avoids reloading the syntax file.
            if (p->indir == PV_SYN || p->indir == PV_FT) {
              if (fprintf(fd, "if &%s != '%s'", p->fullname,
                          *(char_u **)(varp)) < 0
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
  char_u *s;
  char_u *buf = NULL;
  char_u *part = NULL;
  char *p;

  if (fprintf(fd, "%s %s=", cmd, name) < 0) {
    return FAIL;
  }
  if (*valuep != NULL) {
    // Output 'pastetoggle' as key names.  For other
    // options some characters have to be escaped with
    // CTRL-V or backslash
    if (valuep == &p_pt) {
      s = (char_u *)(*valuep);
      while (*s != NUL) {
        if (put_escstr(fd, (char_u *)str2special((const char **)&s, false,
                                                 false), 2)
            == FAIL) {
          return FAIL;
        }
      }
    } else if ((flags & P_EXPAND) != 0) {
      size_t size = (size_t)STRLEN(*valuep) + 1;

      // replace home directory in the whole option value into "buf"
      buf = xmalloc(size);
      home_replace(NULL, *valuep, (char *)buf, size, false);

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
        p = (char *)buf;
        while (*p != NUL) {
          // for each comma separated option part, append value to
          // the option, :set rtp+=value
          if (fprintf(fd, "%s %s+=", cmd, name) < 0) {
            goto fail;
          }
          (void)copy_option_part(&p, (char *)part, size, ",");
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
    } else if (put_escstr(fd, (char_u *)(*valuep), 2) == FAIL) {
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

static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep)
{
  long wc;

  if (fprintf(fd, "%s %s=", cmd, name) < 0) {
    return FAIL;
  }
  if (wc_use_keyname((char_u *)valuep, &wc)) {
    // print 'wildchar' and 'wildcharm' as a key name
    if (fputs((char *)get_special_key_name((int)wc, 0), fd) < 0) {
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

// Unset local option value, similar to ":set opt<".
void unset_global_local_option(char *name, void *from)
{
  vimoption_T *p;
  buf_T *buf = (buf_T *)from;

  int opt_idx = findoption(name);
  if (opt_idx < 0) {
    semsg(_("E355: Unknown option: %s"), name);
    return;
  }
  p = &(options[opt_idx]);

  switch ((int)p->indir)
  {
  // global option with local value: use local value if it's been set
  case PV_EP:
    clear_string_option(&buf->b_p_ep);
    break;
  case PV_KP:
    clear_string_option(&buf->b_p_kp);
    break;
  case PV_PATH:
    clear_string_option(&buf->b_p_path);
    break;
  case PV_AR:
    buf->b_p_ar = -1;
    break;
  case PV_BKC:
    clear_string_option(&buf->b_p_bkc);
    buf->b_bkc_flags = 0;
    break;
  case PV_TAGS:
    clear_string_option(&buf->b_p_tags);
    break;
  case PV_TC:
    clear_string_option(&buf->b_p_tc);
    buf->b_tc_flags = 0;
    break;
  case PV_SISO:
    curwin->w_p_siso = -1;
    break;
  case PV_SO:
    curwin->w_p_so = -1;
    break;
  case PV_DEF:
    clear_string_option(&buf->b_p_def);
    break;
  case PV_INC:
    clear_string_option(&buf->b_p_inc);
    break;
  case PV_DICT:
    clear_string_option(&buf->b_p_dict);
    break;
  case PV_TSR:
    clear_string_option(&buf->b_p_tsr);
    break;
  case PV_TSRFU:
    clear_string_option(&buf->b_p_tsrfu);
    break;
  case PV_FP:
    clear_string_option(&buf->b_p_fp);
    break;
  case PV_EFM:
    clear_string_option(&buf->b_p_efm);
    break;
  case PV_GP:
    clear_string_option(&buf->b_p_gp);
    break;
  case PV_MP:
    clear_string_option(&buf->b_p_mp);
    break;
  case PV_SBR:
    clear_string_option(&((win_T *)from)->w_p_sbr);
    break;
  case PV_STL:
    clear_string_option(&((win_T *)from)->w_p_stl);
    break;
  case PV_WBR:
    clear_string_option(&((win_T *)from)->w_p_wbr);
    break;
  case PV_UL:
    buf->b_p_ul = NO_LOCAL_UNDOLEVEL;
    break;
  case PV_LW:
    clear_string_option(&buf->b_p_lw);
    break;
  case PV_MENC:
    clear_string_option(&buf->b_p_menc);
    break;
  case PV_LCS:
    clear_string_option(&((win_T *)from)->w_p_lcs);
    set_chars_option((win_T *)from, &((win_T *)from)->w_p_lcs, true);
    redraw_later((win_T *)from, UPD_NOT_VALID);
    break;
  case PV_FCS:
    clear_string_option(&((win_T *)from)->w_p_fcs);
    set_chars_option((win_T *)from, &((win_T *)from)->w_p_fcs, true);
    redraw_later((win_T *)from, UPD_NOT_VALID);
    break;
  case PV_VE:
    clear_string_option(&((win_T *)from)->w_p_ve);
    ((win_T *)from)->w_ve_flags = 0;
    break;
  }
}

/// Get pointer to option variable, depending on local or global scope.
static char *get_varp_scope(vimoption_T *p, int opt_flags)
{
  if ((opt_flags & OPT_GLOBAL) && p->indir != PV_NONE) {
    if (p->var == VAR_WIN) {
      return GLOBAL_WO(get_varp(p));
    }
    return (char *)p->var;
  }
  if ((opt_flags & OPT_LOCAL) && ((int)p->indir & PV_BOTH)) {
    switch ((int)p->indir) {
    case PV_FP:
      return (char *)&(curbuf->b_p_fp);
    case PV_EFM:
      return (char *)&(curbuf->b_p_efm);
    case PV_GP:
      return (char *)&(curbuf->b_p_gp);
    case PV_MP:
      return (char *)&(curbuf->b_p_mp);
    case PV_EP:
      return (char *)&(curbuf->b_p_ep);
    case PV_KP:
      return (char *)&(curbuf->b_p_kp);
    case PV_PATH:
      return (char *)&(curbuf->b_p_path);
    case PV_AR:
      return (char *)&(curbuf->b_p_ar);
    case PV_TAGS:
      return (char *)&(curbuf->b_p_tags);
    case PV_TC:
      return (char *)&(curbuf->b_p_tc);
    case PV_SISO:
      return (char *)&(curwin->w_p_siso);
    case PV_SO:
      return (char *)&(curwin->w_p_so);
    case PV_DEF:
      return (char *)&(curbuf->b_p_def);
    case PV_INC:
      return (char *)&(curbuf->b_p_inc);
    case PV_DICT:
      return (char *)&(curbuf->b_p_dict);
    case PV_TSR:
      return (char *)&(curbuf->b_p_tsr);
    case PV_TSRFU:
      return (char *)&(curbuf->b_p_tsrfu);
    case PV_TFU:
      return (char *)&(curbuf->b_p_tfu);
    case PV_SBR:
      return (char *)&(curwin->w_p_sbr);
    case PV_STL:
      return (char *)&(curwin->w_p_stl);
    case PV_WBR:
      return (char *)&(curwin->w_p_wbr);
    case PV_UL:
      return (char *)&(curbuf->b_p_ul);
    case PV_LW:
      return (char *)&(curbuf->b_p_lw);
    case PV_BKC:
      return (char *)&(curbuf->b_p_bkc);
    case PV_MENC:
      return (char *)&(curbuf->b_p_menc);
    case PV_FCS:
      return (char *)&(curwin->w_p_fcs);
    case PV_LCS:
      return (char *)&(curwin->w_p_lcs);
    case PV_VE:
      return (char *)&(curwin->w_p_ve);
    }
    return NULL;     // "cannot happen"
  }
  return (char *)get_varp(p);
}

/// Get pointer to option variable at 'opt_idx', depending on local or global
/// scope.
char *get_option_varp_scope(int opt_idx, int opt_flags)
{
  return get_varp_scope(&(options[opt_idx]), opt_flags);
}

/// Get pointer to option variable.
static char_u *get_varp(vimoption_T *p)
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
    return *curbuf->b_p_ep != NUL
           ? (char_u *)&curbuf->b_p_ep : p->var;
  case PV_KP:
    return *curbuf->b_p_kp != NUL
           ? (char_u *)&curbuf->b_p_kp : p->var;
  case PV_PATH:
    return *curbuf->b_p_path != NUL
           ? (char_u *)&(curbuf->b_p_path) : p->var;
  case PV_AR:
    return curbuf->b_p_ar >= 0
           ? (char_u *)&(curbuf->b_p_ar) : p->var;
  case PV_TAGS:
    return *curbuf->b_p_tags != NUL
           ? (char_u *)&(curbuf->b_p_tags) : p->var;
  case PV_TC:
    return *curbuf->b_p_tc != NUL
           ? (char_u *)&(curbuf->b_p_tc) : p->var;
  case PV_SISO:
    return curwin->w_p_siso >= 0
           ? (char_u *)&(curwin->w_p_siso) : p->var;
  case PV_SO:
    return curwin->w_p_so >= 0
           ? (char_u *)&(curwin->w_p_so) : p->var;
  case PV_BKC:
    return *curbuf->b_p_bkc != NUL
           ? (char_u *)&(curbuf->b_p_bkc) : p->var;
  case PV_DEF:
    return *curbuf->b_p_def != NUL
           ? (char_u *)&(curbuf->b_p_def) : p->var;
  case PV_INC:
    return *curbuf->b_p_inc != NUL
           ? (char_u *)&(curbuf->b_p_inc) : p->var;
  case PV_DICT:
    return *curbuf->b_p_dict != NUL
           ? (char_u *)&(curbuf->b_p_dict) : p->var;
  case PV_TSR:
    return *curbuf->b_p_tsr != NUL
           ? (char_u *)&(curbuf->b_p_tsr) : p->var;
  case PV_TSRFU:
    return *curbuf->b_p_tsrfu != NUL
           ? (char_u *)&(curbuf->b_p_tsrfu) : p->var;
  case PV_FP:
    return *curbuf->b_p_fp != NUL
           ? (char_u *)&(curbuf->b_p_fp) : p->var;
  case PV_EFM:
    return *curbuf->b_p_efm != NUL
           ? (char_u *)&(curbuf->b_p_efm) : p->var;
  case PV_GP:
    return *curbuf->b_p_gp != NUL
           ? (char_u *)&(curbuf->b_p_gp) : p->var;
  case PV_MP:
    return *curbuf->b_p_mp != NUL
           ? (char_u *)&(curbuf->b_p_mp) : p->var;
  case PV_SBR:
    return *curwin->w_p_sbr != NUL
           ? (char_u *)&(curwin->w_p_sbr) : p->var;
  case PV_STL:
    return *curwin->w_p_stl != NUL
           ? (char_u *)&(curwin->w_p_stl) : p->var;
  case PV_WBR:
    return *curwin->w_p_wbr != NUL
           ? (char_u *)&(curwin->w_p_wbr) : p->var;
  case PV_UL:
    return curbuf->b_p_ul != NO_LOCAL_UNDOLEVEL
           ? (char_u *)&(curbuf->b_p_ul) : p->var;
  case PV_LW:
    return *curbuf->b_p_lw != NUL
           ? (char_u *)&(curbuf->b_p_lw) : p->var;
  case PV_MENC:
    return *curbuf->b_p_menc != NUL
           ? (char_u *)&(curbuf->b_p_menc) : p->var;
  case PV_FCS:
    return *curwin->w_p_fcs != NUL
           ? (char_u *)&(curwin->w_p_fcs) : p->var;
  case PV_LCS:
    return *curwin->w_p_lcs != NUL
           ? (char_u *)&(curwin->w_p_lcs) : p->var;
  case PV_VE:
    return *curwin->w_p_ve != NUL
           ? (char_u *)&curwin->w_p_ve : p->var;

  case PV_ARAB:
    return (char_u *)&(curwin->w_p_arab);
  case PV_LIST:
    return (char_u *)&(curwin->w_p_list);
  case PV_SPELL:
    return (char_u *)&(curwin->w_p_spell);
  case PV_CUC:
    return (char_u *)&(curwin->w_p_cuc);
  case PV_CUL:
    return (char_u *)&(curwin->w_p_cul);
  case PV_CULOPT:
    return (char_u *)&(curwin->w_p_culopt);
  case PV_CC:
    return (char_u *)&(curwin->w_p_cc);
  case PV_DIFF:
    return (char_u *)&(curwin->w_p_diff);
  case PV_FDC:
    return (char_u *)&(curwin->w_p_fdc);
  case PV_FEN:
    return (char_u *)&(curwin->w_p_fen);
  case PV_FDI:
    return (char_u *)&(curwin->w_p_fdi);
  case PV_FDL:
    return (char_u *)&(curwin->w_p_fdl);
  case PV_FDM:
    return (char_u *)&(curwin->w_p_fdm);
  case PV_FML:
    return (char_u *)&(curwin->w_p_fml);
  case PV_FDN:
    return (char_u *)&(curwin->w_p_fdn);
  case PV_FDE:
    return (char_u *)&(curwin->w_p_fde);
  case PV_FDT:
    return (char_u *)&(curwin->w_p_fdt);
  case PV_FMR:
    return (char_u *)&(curwin->w_p_fmr);
  case PV_NU:
    return (char_u *)&(curwin->w_p_nu);
  case PV_RNU:
    return (char_u *)&(curwin->w_p_rnu);
  case PV_NUW:
    return (char_u *)&(curwin->w_p_nuw);
  case PV_WFH:
    return (char_u *)&(curwin->w_p_wfh);
  case PV_WFW:
    return (char_u *)&(curwin->w_p_wfw);
  case PV_PVW:
    return (char_u *)&(curwin->w_p_pvw);
  case PV_RL:
    return (char_u *)&(curwin->w_p_rl);
  case PV_RLC:
    return (char_u *)&(curwin->w_p_rlc);
  case PV_SCROLL:
    return (char_u *)&(curwin->w_p_scr);
  case PV_WRAP:
    return (char_u *)&(curwin->w_p_wrap);
  case PV_LBR:
    return (char_u *)&(curwin->w_p_lbr);
  case PV_BRI:
    return (char_u *)&(curwin->w_p_bri);
  case PV_BRIOPT:
    return (char_u *)&(curwin->w_p_briopt);
  case PV_SCBIND:
    return (char_u *)&(curwin->w_p_scb);
  case PV_CRBIND:
    return (char_u *)&(curwin->w_p_crb);
  case PV_COCU:
    return (char_u *)&(curwin->w_p_cocu);
  case PV_COLE:
    return (char_u *)&(curwin->w_p_cole);

  case PV_AI:
    return (char_u *)&(curbuf->b_p_ai);
  case PV_BIN:
    return (char_u *)&(curbuf->b_p_bin);
  case PV_BOMB:
    return (char_u *)&(curbuf->b_p_bomb);
  case PV_BH:
    return (char_u *)&(curbuf->b_p_bh);
  case PV_BT:
    return (char_u *)&(curbuf->b_p_bt);
  case PV_BL:
    return (char_u *)&(curbuf->b_p_bl);
  case PV_CHANNEL:
    return (char_u *)&(curbuf->b_p_channel);
  case PV_CI:
    return (char_u *)&(curbuf->b_p_ci);
  case PV_CIN:
    return (char_u *)&(curbuf->b_p_cin);
  case PV_CINK:
    return (char_u *)&(curbuf->b_p_cink);
  case PV_CINO:
    return (char_u *)&(curbuf->b_p_cino);
  case PV_CINSD:
    return (char_u *)&(curbuf->b_p_cinsd);
  case PV_CINW:
    return (char_u *)&(curbuf->b_p_cinw);
  case PV_COM:
    return (char_u *)&(curbuf->b_p_com);
  case PV_CMS:
    return (char_u *)&(curbuf->b_p_cms);
  case PV_CPT:
    return (char_u *)&(curbuf->b_p_cpt);
#ifdef BACKSLASH_IN_FILENAME
  case PV_CSL:
    return (char_u *)&(curbuf->b_p_csl);
#endif
  case PV_CFU:
    return (char_u *)&(curbuf->b_p_cfu);
  case PV_OFU:
    return (char_u *)&(curbuf->b_p_ofu);
  case PV_EOL:
    return (char_u *)&(curbuf->b_p_eol);
  case PV_FIXEOL:
    return (char_u *)&(curbuf->b_p_fixeol);
  case PV_ET:
    return (char_u *)&(curbuf->b_p_et);
  case PV_FENC:
    return (char_u *)&(curbuf->b_p_fenc);
  case PV_FF:
    return (char_u *)&(curbuf->b_p_ff);
  case PV_FT:
    return (char_u *)&(curbuf->b_p_ft);
  case PV_FO:
    return (char_u *)&(curbuf->b_p_fo);
  case PV_FLP:
    return (char_u *)&(curbuf->b_p_flp);
  case PV_IMI:
    return (char_u *)&(curbuf->b_p_iminsert);
  case PV_IMS:
    return (char_u *)&(curbuf->b_p_imsearch);
  case PV_INF:
    return (char_u *)&(curbuf->b_p_inf);
  case PV_ISK:
    return (char_u *)&(curbuf->b_p_isk);
  case PV_INEX:
    return (char_u *)&(curbuf->b_p_inex);
  case PV_INDE:
    return (char_u *)&(curbuf->b_p_inde);
  case PV_INDK:
    return (char_u *)&(curbuf->b_p_indk);
  case PV_FEX:
    return (char_u *)&(curbuf->b_p_fex);
  case PV_LISP:
    return (char_u *)&(curbuf->b_p_lisp);
  case PV_ML:
    return (char_u *)&(curbuf->b_p_ml);
  case PV_MPS:
    return (char_u *)&(curbuf->b_p_mps);
  case PV_MA:
    return (char_u *)&(curbuf->b_p_ma);
  case PV_MOD:
    return (char_u *)&(curbuf->b_changed);
  case PV_NF:
    return (char_u *)&(curbuf->b_p_nf);
  case PV_PI:
    return (char_u *)&(curbuf->b_p_pi);
  case PV_QE:
    return (char_u *)&(curbuf->b_p_qe);
  case PV_RO:
    return (char_u *)&(curbuf->b_p_ro);
  case PV_SCBK:
    return (char_u *)&(curbuf->b_p_scbk);
  case PV_SI:
    return (char_u *)&(curbuf->b_p_si);
  case PV_STS:
    return (char_u *)&(curbuf->b_p_sts);
  case PV_SUA:
    return (char_u *)&(curbuf->b_p_sua);
  case PV_SWF:
    return (char_u *)&(curbuf->b_p_swf);
  case PV_SMC:
    return (char_u *)&(curbuf->b_p_smc);
  case PV_SYN:
    return (char_u *)&(curbuf->b_p_syn);
  case PV_SPC:
    return (char_u *)&(curwin->w_s->b_p_spc);
  case PV_SPF:
    return (char_u *)&(curwin->w_s->b_p_spf);
  case PV_SPL:
    return (char_u *)&(curwin->w_s->b_p_spl);
  case PV_SPO:
    return (char_u *)&(curwin->w_s->b_p_spo);
  case PV_SW:
    return (char_u *)&(curbuf->b_p_sw);
  case PV_TFU:
    return (char_u *)&(curbuf->b_p_tfu);
  case PV_TS:
    return (char_u *)&(curbuf->b_p_ts);
  case PV_TW:
    return (char_u *)&(curbuf->b_p_tw);
  case PV_UDF:
    return (char_u *)&(curbuf->b_p_udf);
  case PV_WM:
    return (char_u *)&(curbuf->b_p_wm);
  case PV_VSTS:
    return (char_u *)&(curbuf->b_p_vsts);
  case PV_VTS:
    return (char_u *)&(curbuf->b_p_vts);
  case PV_KMAP:
    return (char_u *)&(curbuf->b_p_keymap);
  case PV_SCL:
    return (char_u *)&(curwin->w_p_scl);
  case PV_WINHL:
    return (char_u *)&(curwin->w_p_winhl);
  case PV_WINBL:
    return (char_u *)&(curwin->w_p_winbl);
  default:
    iemsg(_("E356: get_varp ERROR"));
  }
  // always return a valid pointer to avoid a crash!
  return (char_u *)&(curbuf->b_p_wm);
}

/// Return a pointer to the variable for option at 'opt_idx'
char_u *get_option_var(int opt_idx)
{
  return options[opt_idx].var;
}

/// Return the full name of the option at 'opt_idx'
char *get_option_fullname(int opt_idx)
{
  return options[opt_idx].fullname;
}

/// Get the value of 'equalprg', either the buffer-local one or the global one.
char_u *get_equalprg(void)
{
  if (*curbuf->b_p_ep == NUL) {
    return p_ep;
  }
  return (char_u *)curbuf->b_p_ep;
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
  if (val == empty_option) {
    return empty_option;  // no need to allocate memory
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
  to->wo_rl  = from->wo_rl;
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
  to->wo_crb = from->wo_crb;
  to->wo_crb_save = from->wo_crb_save;
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
  to->wo_fdc_save = from->wo_diff_saved ? xstrdup(from->wo_fdc_save) : empty_option;
  to->wo_fen = from->wo_fen;
  to->wo_fen_save = from->wo_fen_save;
  to->wo_fdi = copy_option_val(from->wo_fdi);
  to->wo_fml = from->wo_fml;
  to->wo_fdl = from->wo_fdl;
  to->wo_fdl_save = from->wo_fdl_save;
  to->wo_fdm = copy_option_val(from->wo_fdm);
  to->wo_fdm_save = from->wo_diff_saved ? xstrdup(from->wo_fdm_save) : empty_option;
  to->wo_fdn = from->wo_fdn;
  to->wo_fde = copy_option_val(from->wo_fde);
  to->wo_fdt = copy_option_val(from->wo_fdt);
  to->wo_fmr = copy_option_val(from->wo_fmr);
  to->wo_scl = copy_option_val(from->wo_scl);
  to->wo_winhl = copy_option_val(from->wo_winhl);
  to->wo_winbl = from->wo_winbl;

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

/// Check for NULL pointers in a winopt_T and replace them with empty_option.
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
}

void didset_window_options(win_T *wp, bool valid_cursor)
{
  check_colorcolumn(wp);
  briopt_check(wp);
  fill_culopt_flags(NULL, wp);
  set_chars_option(wp, &wp->w_p_fcs, true);
  set_chars_option(wp, &wp->w_p_lcs, true);
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
  char_u *save_p_isk = NULL;           // init for GCC
  int dont_do_help;
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
      dont_do_help = ((flags & BCO_NOHELP) && buf->b_help) || buf->b_p_initialized;
      if (dont_do_help) {               // don't free b_p_isk
        save_p_isk = (char_u *)buf->b_p_isk;
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
        buf->b_p_bh = empty_option;
        buf->b_p_bt = empty_option;
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
      buf->b_p_csl = vim_strsave(p_csl);
      COPY_OPT_SCTX(buf, BV_CSL);
#endif
      buf->b_p_cfu = xstrdup(p_cfu);
      COPY_OPT_SCTX(buf, BV_CFU);
      buf->b_p_ofu = xstrdup(p_ofu);
      COPY_OPT_SCTX(buf, BV_OFU);
      buf->b_p_tfu = xstrdup(p_tfu);
      COPY_OPT_SCTX(buf, BV_TFU);
      buf->b_p_sts = p_sts;
      COPY_OPT_SCTX(buf, BV_STS);
      buf->b_p_sts_nopaste = p_sts_nopaste;
      buf->b_p_vsts = xstrdup(p_vsts);
      COPY_OPT_SCTX(buf, BV_VSTS);
      if (p_vsts && p_vsts != empty_option) {
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

      // Don't copy 'filetype', it must be detected
      buf->b_p_ft = empty_option;
      buf->b_p_pi = p_pi;
      COPY_OPT_SCTX(buf, BV_PI);
      buf->b_p_cinw = xstrdup(p_cinw);
      COPY_OPT_SCTX(buf, BV_CINW);
      buf->b_p_lisp = p_lisp;
      COPY_OPT_SCTX(buf, BV_LISP);
      // Don't copy 'syntax', it must be set
      buf->b_p_syn = empty_option;
      buf->b_p_smc = p_smc;
      COPY_OPT_SCTX(buf, BV_SMC);
      buf->b_s.b_syn_isk = empty_option;
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
      buf->b_p_fp = empty_option;
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
      buf->b_p_bkc = empty_option;
      buf->b_bkc_flags = 0;
      buf->b_p_gp = empty_option;
      buf->b_p_mp = empty_option;
      buf->b_p_efm = empty_option;
      buf->b_p_ep = empty_option;
      buf->b_p_kp = empty_option;
      buf->b_p_path = empty_option;
      buf->b_p_tags = empty_option;
      buf->b_p_tc = empty_option;
      buf->b_tc_flags = 0;
      buf->b_p_def = empty_option;
      buf->b_p_inc = empty_option;
      buf->b_p_inex = xstrdup(p_inex);
      COPY_OPT_SCTX(buf, BV_INEX);
      buf->b_p_dict = empty_option;
      buf->b_p_tsr = empty_option;
      buf->b_p_tsrfu = empty_option;
      buf->b_p_qe = xstrdup(p_qe);
      COPY_OPT_SCTX(buf, BV_QE);
      buf->b_p_udf = p_udf;
      COPY_OPT_SCTX(buf, BV_UDF);
      buf->b_p_lw = empty_option;
      buf->b_p_menc = empty_option;

      // Don't copy the options set by ex_help(), use the saved values,
      // when going from a help buffer to a non-help buffer.
      // Don't touch these at all when BCO_NOHELP is used and going from
      // or to a help buffer.
      if (dont_do_help) {
        buf->b_p_isk = (char *)save_p_isk;
        if (p_vts && p_vts != empty_option && !buf->b_p_vts_array) {
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
        if (p_vts && p_vts != empty_option && !buf->b_p_vts_array) {
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
void set_iminsert_global(void)
{
  p_iminsert = curbuf->b_p_iminsert;
}

/// Set the global value for 'imsearch' to the local value.
void set_imsearch_global(void)
{
  p_imsearch = curbuf->b_p_imsearch;
}

static int expand_option_idx = -1;
static char_u expand_option_name[5] = { 't', '_', NUL, NUL, NUL };
static int expand_option_flags = 0;

/// @param opt_flags  OPT_GLOBAL and/or OPT_LOCAL
void set_context_in_set_cmd(expand_T *xp, char_u *arg, int opt_flags)
{
  char_u nextchar;
  uint32_t flags = 0;           // init for GCC
  int opt_idx = 0;              // init for GCC
  char_u *p;
  char_u *s;
  int is_term_option = false;
  int key;

  expand_option_flags = opt_flags;

  xp->xp_context = EXPAND_SETTINGS;
  if (*arg == NUL) {
    xp->xp_pattern = (char *)arg;
    return;
  }
  p = arg + STRLEN(arg) - 1;
  if (*p == ' ' && *(p - 1) != '\\') {
    xp->xp_pattern = (char *)p + 1;
    return;
  }
  while (p > arg) {
    s = p;
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
  if (STRNCMP(p, "no", 2) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 2;
  }
  if (STRNCMP(p, "inv", 3) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 3;
  }
  xp->xp_pattern = (char *)p;
  arg = p;
  if (*arg == '<') {
    while (*p != '>') {
      if (*p++ == NUL) {            // expand terminal option name
        return;
      }
    }
    key = get_special_key_code(arg + 1);
    if (key == 0) {                 // unknown name
      xp->xp_context = EXPAND_NOTHING;
      return;
    }
    nextchar = *++p;
    is_term_option = true;
    expand_option_name[2] = (char_u)KEY2TERMCAP0(key);
    expand_option_name[3] = KEY2TERMCAP1(key);
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
      opt_idx = findoption_len((const char *)arg, (size_t)(p - arg));
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
  if ((nextchar == '-' || nextchar == '+' || nextchar == '^') && p[1] == '=') {
    p++;
    nextchar = '=';
  }
  if ((nextchar != '=' && nextchar != ':')
      || xp->xp_context == EXPAND_BOOL_SETTINGS) {
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return;
  }
  if (p[1] == NUL) {
    xp->xp_context = EXPAND_OLD_SETTING;
    if (is_term_option) {
      expand_option_idx = -1;
    } else {
      expand_option_idx = opt_idx;
    }
    xp->xp_pattern = (char *)p + 1;
    return;
  }
  xp->xp_context = EXPAND_NOTHING;
  if (is_term_option || (flags & P_NUM)) {
    return;
  }

  xp->xp_pattern = (char *)p + 1;

  if (flags & P_EXPAND) {
    p = options[opt_idx].var;
    if (p == (char_u *)&p_bdir
        || p == (char_u *)&p_dir
        || p == (char_u *)&p_path
        || p == (char_u *)&p_pp
        || p == (char_u *)&p_rtp
        || p == (char_u *)&p_cdpath
        || p == (char_u *)&p_vdir) {
      xp->xp_context = EXPAND_DIRECTORIES;
      if (p == (char_u *)&p_path
          || p == (char_u *)&p_cdpath) {
        xp->xp_backslash = XP_BS_THREE;
      } else {
        xp->xp_backslash = XP_BS_ONE;
      }
    } else if (p == (char_u *)&p_ft) {
      xp->xp_context = EXPAND_FILETYPE;
    } else {
      xp->xp_context = EXPAND_FILES;
      // for 'tags' need three backslashes for a space
      if (p == (char_u *)&p_tags) {
        xp->xp_backslash = XP_BS_THREE;
      } else {
        xp->xp_backslash = XP_BS_ONE;
      }
    }
  }

  // For an option that is a list of file names, find the start of the
  // last file name.
  for (p = arg + STRLEN(arg) - 1; p > (char_u *)xp->xp_pattern; p--) {
    // count number of backslashes before ' ' or ','
    if (*p == ' ' || *p == ',') {
      s = p;
      while (s > (char_u *)xp->xp_pattern && *(s - 1) == '\\') {
        s--;
      }
      if ((*p == ' ' && (xp->xp_backslash == XP_BS_THREE && (p - s) < 3))
          || (*p == ',' && (flags & P_COMMA) && ((p - s) & 1) == 0)) {
        xp->xp_pattern = (char *)p + 1;
        break;
      }
    }

    // for 'spellsuggest' start at "file:"
    if (options[opt_idx].var == (char_u *)&p_sps
        && STRNCMP(p, "file:", 5) == 0) {
      xp->xp_pattern = (char *)p + 5;
      break;
    }
  }
}

int ExpandSettings(expand_T *xp, regmatch_T *regmatch, int *num_file, char ***file)
{
  int num_normal = 0;  // Nr of matching non-term-code settings
  int match;
  int count = 0;
  char_u *str;
  int loop;
  static char *(names[]) = { "all" };
  int ic = regmatch->rm_ic;  // remember the ignore-case flag

  // do this loop twice:
  // loop == 0: count the number of matching options
  // loop == 1: copy the matching options into allocated memory
  for (loop = 0; loop <= 1; loop++) {
    regmatch->rm_ic = ic;
    if (xp->xp_context != EXPAND_BOOL_SETTINGS) {
      for (match = 0; match < (int)ARRAY_SIZE(names);
           match++) {
        if (vim_regexec(regmatch, names[match], (colnr_T)0)) {
          if (loop == 0) {
            num_normal++;
          } else {
            (*file)[count++] = xstrdup(names[match]);
          }
        }
      }
    }
    for (size_t opt_idx = 0; (str = (char_u *)options[opt_idx].fullname) != NULL;
         opt_idx++) {
      if (options[opt_idx].var == NULL) {
        continue;
      }
      if (xp->xp_context == EXPAND_BOOL_SETTINGS
          && !(options[opt_idx].flags & P_BOOL)) {
        continue;
      }
      match = false;
      if (vim_regexec(regmatch, (char *)str, (colnr_T)0)
          || (options[opt_idx].shortname != NULL
              && vim_regexec(regmatch,
                             options[opt_idx].shortname,
                             (colnr_T)0))) {
        match = true;
      }

      if (match) {
        if (loop == 0) {
          num_normal++;
        } else {
          (*file)[count++] = (char *)vim_strsave(str);
        }
      }
    }

    if (loop == 0) {
      if (num_normal > 0) {
        *num_file = num_normal;
      } else {
        return OK;
      }
      *file = xmalloc((size_t)(*num_file) * sizeof(char_u *));
    }
  }
  return OK;
}

void ExpandOldSetting(int *num_file, char ***file)
{
  char_u *var = NULL;

  *num_file = 0;
  *file = xmalloc(sizeof(char_u *));

  // For a terminal key code expand_option_idx is < 0.
  if (expand_option_idx < 0) {
    expand_option_idx = findoption((const char *)expand_option_name);
  }

  if (expand_option_idx >= 0) {
    // Put string of option value in NameBuff.
    option_value2string(&options[expand_option_idx], expand_option_flags);
    var = (char_u *)NameBuff;
  } else {
    var = (char_u *)"";
  }

  // A backslash is required before some characters.  This is the reverse of
  // what happens in do_set().
  char_u *buf = vim_strsave_escaped(var, escape_chars);

#ifdef BACKSLASH_IN_FILENAME
  // For MS-Windows et al. we don't double backslashes at the start and
  // before a file name character.
  for (var = buf; *var != NUL; MB_PTR_ADV(var)) {
    if (var[0] == '\\' && var[1] == '\\'
        && expand_option_idx >= 0
        && (options[expand_option_idx].flags & P_EXPAND)
        && vim_isfilec(var[2])
        && (var[2] != '\\' || (var == buf && var[4] != '\\'))) {
      STRMOVE(var, var + 1);
    }
  }
#endif

  *file[0] = (char *)buf;
  *num_file = 1;
}

/// Get the value for the numeric or string option///opp in a nice format into
/// NameBuff[].  Must not be called with a hidden option!
///
/// @param opt_flags  OPT_GLOBAL and/or OPT_LOCAL
static void option_value2string(vimoption_T *opp, int opt_flags)
{
  char_u *varp = (char_u *)get_varp_scope(opp, opt_flags);

  if (opp->flags & P_NUM) {
    long wc = 0;

    if (wc_use_keyname(varp, &wc)) {
      STRLCPY(NameBuff, get_special_key_name((int)wc, 0), sizeof(NameBuff));
    } else if (wc != 0) {
      STRLCPY(NameBuff, transchar((int)wc), sizeof(NameBuff));
    } else {
      snprintf((char *)NameBuff,
               sizeof(NameBuff),
               "%" PRId64,
               (int64_t)*(long *)varp);
    }
  } else {  // P_STRING
    varp = *(char_u **)(varp);
    if (varp == NULL) {  // Just in case.
      NameBuff[0] = NUL;
    } else if (opp->flags & P_EXPAND) {
      home_replace(NULL, (char *)varp, (char *)NameBuff, MAXPATHL, false);
      // Translate 'pastetoggle' into special key names.
    } else if ((char **)opp->var == &p_pt) {
      str2specialbuf((const char *)p_pt, (char *)NameBuff, MAXPATHL);
    } else {
      STRLCPY(NameBuff, varp, MAXPATHL);
    }
  }
}

/// Return true if "varp" points to 'wildchar' or 'wildcharm' and it can be
/// printed as a keyname.
/// "*wcp" is set to the value of the option if it's 'wildchar' or 'wildcharm'.
static int wc_use_keyname(char_u *varp, long *wcp)
{
  if (((long *)varp == &p_wc) || ((long *)varp == &p_wcm)) {
    *wcp = *(long *)varp;
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

/// paste_option_changed() - Called after p_paste was set or reset.
static void paste_option_changed(void)
{
  static int old_p_paste = false;
  static int save_sm = 0;
  static int save_sta = 0;
  static int save_ru = 0;
  static int save_ri = 0;
  static int save_hkmap = 0;

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
        buf->b_p_vsts_nopaste = buf->b_p_vsts && buf->b_p_vsts != empty_option
                                    ? xstrdup(buf->b_p_vsts)
                                    : NULL;
      }

      // save global options
      save_sm = p_sm;
      save_sta = p_sta;
      save_ru = p_ru;
      save_ri = p_ri;
      save_hkmap = p_hkmap;
      // save global values for local buffer options
      p_ai_nopaste = p_ai;
      p_et_nopaste = p_et;
      p_sts_nopaste = p_sts;
      p_tw_nopaste = p_tw;
      p_wm_nopaste = p_wm;
      if (p_vsts_nopaste) {
        xfree(p_vsts_nopaste);
      }
      p_vsts_nopaste = p_vsts && p_vsts != empty_option ? xstrdup(p_vsts) : NULL;
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
      buf->b_p_vsts = empty_option;
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
    p_hkmap = 0;                    // no Hebrew keyboard
    // set global values for local buffer options
    p_tw = 0;
    p_wm = 0;
    p_sts = 0;
    p_ai = 0;
    if (p_vsts) {
      free_string_option(p_vsts);
    }
    p_vsts = empty_option;
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
      buf->b_p_vsts = buf->b_p_vsts_nopaste ? xstrdup(buf->b_p_vsts_nopaste) : empty_option;
      xfree(buf->b_p_vsts_array);
      if (buf->b_p_vsts && buf->b_p_vsts != empty_option) {
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
    p_hkmap = save_hkmap;
    // set global values for local buffer options
    p_ai = p_ai_nopaste;
    p_et = p_et_nopaste;
    p_sts = p_sts_nopaste;
    p_tw = p_tw_nopaste;
    p_wm = p_wm_nopaste;
    if (p_vsts) {
      free_string_option(p_vsts);
    }
    p_vsts = p_vsts_nopaste ? xstrdup(p_vsts_nopaste) : empty_option;
  }

  old_p_paste = p_paste;
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

  if (idx >= 0) {
    options[idx].flags &= ~P_WAS_SET;
  }
}

/// fill_breakat_flags() -- called when 'breakat' changes value.
void fill_breakat_flags(void)
{
  char_u *p;
  int i;

  for (i = 0; i < 256; i++) {
    breakat_flags[i] = false;
  }

  if (p_breakat != NULL) {
    for (p = (char_u *)p_breakat; *p; p++) {
      breakat_flags[*p] = true;
    }
  }
}

/// fill_culopt_flags() -- called when 'culopt' changes value
int fill_culopt_flags(char *val, win_T *wp)
{
  char *p;
  char_u culopt_flags_new = 0;

  if (val == NULL) {
    p = wp->w_p_culopt;
  } else {
    p = val;
  }
  while (*p != NUL) {
    if (STRNCMP(p, "line", 4) == 0) {
      p += 4;
      culopt_flags_new |= CULOPT_LINE;
    } else if (STRNCMP(p, "both", 4) == 0) {
      p += 4;
      culopt_flags_new |= CULOPT_LINE | CULOPT_NBR;
    } else if (STRNCMP(p, "number", 6) == 0) {
      p += 6;
      culopt_flags_new |= CULOPT_NBR;
    } else if (STRNCMP(p, "screenline", 10) == 0) {
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

/// Set the callback function value for an option that accepts a function name,
/// lambda, et al. (e.g. 'operatorfunc', 'tagfunc', etc.)
/// @return  OK if the option is successfully set to a function, otherwise FAIL
int option_set_callback_func(char_u *optval, Callback *optcb)
{
  if (optval == NULL || *optval == NUL) {
    callback_free(optcb);
    return OK;
  }

  typval_T *tv;
  if (*optval == '{'
      || (STRNCMP(optval, "function(", 9) == 0)
      || (STRNCMP(optval, "funcref(", 8) == 0)) {
    // Lambda expression or a funcref
    tv = eval_expr((char *)optval);
    if (tv == NULL) {
      return FAIL;
    }
  } else {
    // treat everything else as a function name string
    tv = xcalloc(1, sizeof(*tv));
    tv->v_type = VAR_STRING;
    tv->vval.v_string = (char *)vim_strsave(optval);
  }

  Callback cb;
  if (!callback_from_typval(&cb, tv)) {
    tv_free(tv);
    return FAIL;
  }

  callback_free(optcb);
  *optcb = cb;
  tv_free(tv);
  return OK;
}

/// Check if backspacing over something is allowed.
/// @param  what  BS_INDENT, BS_EOL, BS_START, or BS_NOSTOP
bool can_bs(int what)
{
  if (what == BS_START && bt_prompt(curbuf)) {
    return false;
  }
  switch (*p_bs) {
  case '3':
    return true;
  case '2':
    return what != BS_NOSTOP;
  case '1':
    return what != BS_START;
  case '0':
    return false;
  }
  return vim_strchr(p_bs, what) != NULL;
}

/// Get the local or global value of 'backupcopy'.
///
/// @param buf The buffer.
unsigned int get_bkc_value(buf_T *buf)
{
  return buf->b_bkc_flags ? buf->b_bkc_flags : bkc_flags;
}

/// Get the local or global value of the 'virtualedit' flags.
unsigned int get_ve_flags(void)
{
  return (curwin->w_ve_flags ? curwin->w_ve_flags : ve_flags) & ~(VE_NONE | VE_NONEU);
}

/// Get the local or global value of 'showbreak'.
///
/// @param win  If not NULL, the window to get the local option from; global
///             otherwise.
char_u *get_showbreak_value(win_T *const win)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win->w_p_sbr == NULL || *win->w_p_sbr == NUL) {
    return (char_u *)p_sbr;
  }
  if (STRCMP(win->w_p_sbr, "NONE") == 0) {
    return (char_u *)empty_option;
  }
  return (char_u *)win->w_p_sbr;
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
  while (*p != NUL && vim_strchr(sep_chars, *p) == NULL) {
    // Skip backslash before a separator character and space.
    if (p[0] == '\\' && vim_strchr(sep_chars, p[1]) != NULL) {
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
  return strstr(path_tail((char *)p_sh), "csh") != NULL;
}

/// Return true when 'shell' has "fish" in the tail.
bool fish_like_shell(void)
{
  return strstr(path_tail((char *)p_sh), "fish") != NULL;
}

/// Return the number of requested sign columns, based on current
/// buffer signs and on user configuration.
int win_signcol_count(win_T *wp)
{
  return win_signcol_configured(wp, NULL);
}

/// Return the number of requested sign columns, based on user / configuration.
int win_signcol_configured(win_T *wp, int *is_fixed)
{
  const char *scl = (const char *)wp->w_p_scl;

  if (is_fixed) {
    *is_fixed = 1;
  }

  // Note: It checks "no" or "number" in 'signcolumn' option
  if (*scl == 'n'
      && (*(scl + 1) == 'o' || (*(scl + 1) == 'u'
                                && (wp->w_p_nu || wp->w_p_rnu)))) {
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

  if (is_fixed) {
    // auto or auto:<NUM>
    *is_fixed = 0;
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
      char_u *varp = get_varp(opt);

      if (varp != NULL) {
        if (opt->flags & P_STRING) {
          tv_dict_add_str(d, opt->fullname, strlen(opt->fullname),
                          *(const char **)varp);
        } else if (opt->flags & P_NUM) {
          tv_dict_add_nr(d, opt->fullname, strlen(opt->fullname),
                         *(long *)varp);
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
long get_scrolloff_value(win_T *wp)
{
  // Disallow scrolloff in terminal-mode. #11915
  if (State & MODE_TERMINAL) {
    return 0;
  }
  return wp->w_p_so < 0 ? p_so : wp->w_p_so;
}

/// Return the effective 'sidescrolloff' value for the current window, using the
/// global value when appropriate.
long get_sidescrolloff_value(win_T *wp)
{
  return wp->w_p_siso < 0 ? p_siso : wp->w_p_siso;
}

Dictionary get_vimoption(String name, Error *err)
{
  int opt_idx = findoption_len((const char *)name.data, name.size);
  if (opt_idx < 0) {
    api_set_error(err, kErrorTypeValidation, "no such option: '%s'", name.data);
    return (Dictionary)ARRAY_DICT_INIT;
  }
  return vimoption2dict(&options[opt_idx]);
}

Dictionary get_all_vimoptions(void)
{
  Dictionary retval = ARRAY_DICT_INIT;
  for (size_t i = 0; options[i].fullname != NULL; i++) {
    Dictionary opt_dict = vimoption2dict(&options[i]);
    PUT(retval, options[i].fullname, DICTIONARY_OBJ(opt_dict));
  }
  return retval;
}

static Dictionary vimoption2dict(vimoption_T *opt)
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
  PUT(dict, "global_local", BOOL(opt->indir & PV_BOTH));
  PUT(dict, "commalist", BOOL(opt->flags & P_COMMA));
  PUT(dict, "flaglist", BOOL(opt->flags & P_FLAGLIST));

  PUT(dict, "was_set", BOOL(opt->flags & P_WAS_SET));

  PUT(dict, "last_set_sid", INTEGER_OBJ(opt->last_set.script_ctx.sc_sid));
  PUT(dict, "last_set_linenr", INTEGER_OBJ(opt->last_set.script_ctx.sc_lnum));
  PUT(dict, "last_set_chan", INTEGER_OBJ((int64_t)opt->last_set.channel_id));

  const char *type;
  Object def;
  // TODO(bfredl): do you even nocp?
  char_u *def_val = opt->def_val;
  if (opt->flags & P_STRING) {
    type = "string";
    def = CSTR_TO_OBJ(def_val ? (char *)def_val : "");
  } else if (opt->flags & P_NUM) {
    type = "number";
    def = INTEGER_OBJ((Integer)(intptr_t)def_val);
  } else if (opt->flags & P_BOOL) {
    type = "boolean";
    def = BOOL((intptr_t)def_val);
  } else {
    type = ""; def = NIL;
  }
  PUT(dict, "type", CSTR_TO_OBJ(type));
  PUT(dict, "default", def);
  PUT(dict, "allows_duplicates", BOOL(!(opt->flags & P_NODUP)));

  return dict;
}
