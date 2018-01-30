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
// - If it's a numeric option, add any necessary bounds checks to do_set().
// - If it's a list of flags, add some code in do_set(), search for WW_ALL.
// - When adding an option with expansion (P_EXPAND), but with a different
//   default for Vi and Vim (no P_VI_DEF), add some code at VIMEXP.
// - Add documentation! doc/options.txt, and any other related places.
// - Add an entry in runtime/optwin.vim.

#define IN_OPTION_C
#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/macros.h"
#include "nvim/ascii.h"
#include "nvim/edit.h"
#include "nvim/option.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/hardcopy.h"
#include "nvim/indent_c.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/cursor_shape.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/normal.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/api/private/helpers.h"
#include "nvim/os/input.h"
#include "nvim/os/lang.h"

/*
 * The options that are local to a window or buffer have "indir" set to one of
 * these values.  Special values:
 * PV_NONE: global option.
 * PV_WIN is added: window-local option
 * PV_BUF is added: buffer-local option
 * PV_BOTH is added: global option which also has a local value.
 */
#define PV_BOTH 0x1000
#define PV_WIN  0x2000
#define PV_BUF  0x4000
#define PV_MASK 0x0fff
#define OPT_WIN(x)  (idopt_T)(PV_WIN + (int)(x))
#define OPT_BUF(x)  (idopt_T)(PV_BUF + (int)(x))
#define OPT_BOTH(x) (idopt_T)(PV_BOTH + (int)(x))


/* WV_ and BV_ values get typecasted to this for the "indir" field */
typedef enum {
  PV_NONE = 0,
  PV_MAXVAL = 0xffff      /* to avoid warnings for value out of range */
} idopt_T;

/*
 * Options local to a window have a value local to a buffer and global to all
 * buffers.  Indicate this by setting "var" to VAR_WIN.
 */
#define VAR_WIN ((char_u *)-1)

static char *p_term = NULL;
static char *p_ttytype = NULL;

/*
 * These are the global values for options which are also local to a buffer.
 * Only to be used in option.c!
 */
static int p_ai;
static int p_bin;
static int p_bomb;
static char_u   *p_bh;
static char_u   *p_bt;
static int p_bl;
static long p_channel;
static int p_ci;
static int p_cin;
static char_u   *p_cink;
static char_u   *p_cino;
static char_u   *p_cinw;
static char_u   *p_com;
static char_u   *p_cms;
static char_u   *p_cpt;
static char_u   *p_cfu;
static char_u   *p_ofu;
static int p_eol;
static int p_fixeol;
static int p_et;
static char_u   *p_fenc;
static char_u   *p_ff;
static char_u   *p_fo;
static char_u   *p_flp;
static char_u   *p_ft;
static long p_iminsert;
static long p_imsearch;
static char_u   *p_inex;
static char_u   *p_inde;
static char_u   *p_indk;
static char_u   *p_fex;
static int p_inf;
static char_u   *p_isk;
static int p_lisp;
static int p_ml;
static int p_ma;
static int p_mod;
static char_u   *p_mps;
static char_u   *p_nf;
static int p_pi;
static char_u   *p_qe;
static int p_ro;
static int p_si;
static long p_sts;
static char_u   *p_sua;
static long p_sw;
static int p_swf;
static long p_smc;
static char_u   *p_syn;
static char_u   *p_spc;
static char_u   *p_spf;
static char_u   *p_spl;
static long p_ts;
static long p_tw;
static int p_udf;
static long p_wm;
static char_u   *p_keymap;

/* Saved values for when 'bin' is set. */
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

typedef struct vimoption {
  char        *fullname;        /* full option name */
  char        *shortname;       /* permissible abbreviation */
  uint32_t flags;               /* see below */
  char_u      *var;             /* global option: pointer to variable;
                                * window-local option: VAR_WIN;
                                * buffer-local option: global value */
  idopt_T indir;                /* global option: PV_NONE;
                                 * local option: indirect option index */
  char_u      *def_val[2];      /* default values for variable (vi and vim) */
  scid_T scriptID;              /* script in which the option was last set */
# define SCRIPTID_INIT , 0
} vimoption_T;

#define VI_DEFAULT  0       /* def_val[VI_DEFAULT] is Vi default value */
#define VIM_DEFAULT 1       /* def_val[VIM_DEFAULT] is Vim default value */

/*
 * Flags
 */
#define P_BOOL          0x01U    /* the option is boolean */
#define P_NUM           0x02U    /* the option is numeric */
#define P_STRING        0x04U    /* the option is a string */
#define P_ALLOCED       0x08U    /* the string option is in allocated memory,
                                    must use free_string_option() when
                                    assigning new value. Not set if default is
                                    the same. */
#define P_EXPAND        0x10U    /* environment expansion.  NOTE: P_EXPAND can
                                    never be used for local or hidden options */
#define P_NODEFAULT     0x40U    /* don't set to default value */
#define P_DEF_ALLOCED   0x80U    /* default value is in allocated memory, must
                                    use free() when assigning new value */
#define P_WAS_SET       0x100U   /* option has been set/reset */
#define P_NO_MKRC       0x200U   /* don't include in :mkvimrc output */
#define P_VI_DEF        0x400U   /* Use Vi default for Vim */
#define P_VIM           0x800U   /* Vim option */

// when option changed, what to display:
#define P_RSTAT         0x1000U  ///< redraw status lines
#define P_RWIN          0x2000U  ///< redraw current window and recompute text
#define P_RBUF          0x4000U  ///< redraw current buffer and recompute text
#define P_RALL          0x6000U  ///< redraw all windows
#define P_RCLR          0x7000U  ///< clear and redraw all

#define P_COMMA         0x8000U    ///< comma separated list
#define P_ONECOMMA      0x18000U   ///< P_COMMA and cannot have two consecutive
                                   ///< commas
#define P_NODUP         0x20000U   ///< don't allow duplicate strings
#define P_FLAGLIST      0x40000U   ///< list of single-char flags

#define P_SECURE        0x80000U   ///< cannot change in modeline or secure mode
#define P_GETTEXT       0x100000U  ///< expand default value with _()
#define P_NOGLOB        0x200000U  ///< do not use local value for global vimrc
#define P_NFNAME        0x400000U  ///< only normal file name chars allowed
#define P_INSECURE      0x800000U  ///< option was set from a modeline
#define P_PRI_MKRC     0x1000000U  ///< priority for :mkvimrc (setting option
                                   ///< has side effects)
#define P_NO_ML        0x2000000U  ///< not allowed in modeline
#define P_CURSWANT     0x4000000U  ///< update curswant required; not needed
                                   ///< when there is a redraw flag
#define P_NO_DEF_EXP   0x8000000U  ///< Do not expand default value.

#define P_RWINONLY     0x10000000U  ///< only redraw current window
#define P_NDNAME       0x20000000U  ///< only normal dir name chars allowed
#define P_UI_OPTION    0x40000000U  ///< send option to remote ui

#define HIGHLIGHT_INIT \
  "8:SpecialKey,~:EndOfBuffer,z:TermCursor,Z:TermCursorNC,@:NonText," \
  "d:Directory,e:ErrorMsg,i:IncSearch,l:Search,m:MoreMsg,M:ModeMsg,n:LineNr," \
  "N:CursorLineNr,r:Question,s:StatusLine,S:StatusLineNC,c:VertSplit,t:Title," \
  "v:Visual,V:VisualNOS,w:WarningMsg,W:WildMenu,f:Folded,F:FoldColumn," \
  "A:DiffAdd,C:DiffChange,D:DiffDelete,T:DiffText,>:SignColumn,-:Conceal," \
  "B:SpellBad,P:SpellCap,R:SpellRare,L:SpellLocal,+:Pmenu,=:PmenuSel," \
  "x:PmenuSbar,X:PmenuThumb,*:TabLine,#:TabLineSel,_:TabLineFill," \
  "!:CursorColumn,.:CursorLine,o:ColorColumn,q:QuickFixLine," \
  "0:Whitespace,I:NormalNC"

/*
 * options[] is initialized here.
 * The order of the options MUST be alphabetic for ":set all" and findoption().
 * All option names MUST start with a lowercase letter (for findoption()).
 * Exception: "t_" options are at the end.
 * The options with a NULL variable are 'hidden': a set command for them is
 * ignored and they are not printed.
 */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "options.generated.h"
#endif

#define PARAM_COUNT ARRAY_SIZE(options)

static char *(p_ambw_values[]) =      { "single", "double", NULL };
static char *(p_bg_values[]) =        { "light", "dark", NULL };
static char *(p_nf_values[]) =        { "bin", "octal", "hex", "alpha", NULL };
static char *(p_ff_values[]) =        { FF_UNIX, FF_DOS, FF_MAC, NULL };
static char *(p_wop_values[]) =       { "tagfile", NULL };
static char *(p_wak_values[]) =       { "yes", "menu", "no", NULL };
static char *(p_mousem_values[]) =    { "extend", "popup", "popup_setpos",
                                        "mac", NULL };
static char *(p_sel_values[]) =       { "inclusive", "exclusive", "old", NULL };
static char *(p_slm_values[]) =       { "mouse", "key", "cmd", NULL };
static char *(p_km_values[]) =        { "startsel", "stopsel", NULL };
static char *(p_scbopt_values[]) =    { "ver", "hor", "jump", NULL };
static char *(p_debug_values[]) =     { "msg", "throw", "beep", NULL };
static char *(p_ead_values[]) =       { "both", "ver", "hor", NULL };
static char *(p_buftype_values[]) =   { "nofile", "nowrite", "quickfix",
                                        "help", "acwrite", "terminal", NULL };

static char *(p_bufhidden_values[]) = { "hide", "unload", "delete",
                                        "wipe", NULL };
static char *(p_bs_values[]) =        { "indent", "eol", "start", NULL };
static char *(p_fdm_values[]) =       { "manual", "expr", "marker", "indent",
                                        "syntax",  "diff", NULL };
static char *(p_fcl_values[]) =       { "all", NULL };
static char *(p_cot_values[]) =       { "menu", "menuone", "longest", "preview",
                                        "noinsert", "noselect", NULL };
static char *(p_icm_values[]) =       { "nosplit", "split", NULL };
static char *(p_scl_values[]) =       { "yes", "no", "auto", NULL };

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.c.generated.h"
#endif

/// Append string with escaped commas
static char *strcpy_comma_escaped(char *dest, const char *src, const size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t shift = 0;
  for (size_t i = 0; i < len; i++) {
    if (src[i] == ',') {
      dest[i + shift++] = '\\';
    }
    dest[i + shift] = src[i];
  }
  return &dest[len + shift];
}

/// Compute length of a colon-separated value, doubled and with some suffixes
///
/// @param[in]  val  Colon-separated array value.
/// @param[in]  common_suf_len  Length of the common suffix which is appended to
///                             each item in the array, twice.
/// @param[in]  single_suf_len  Length of the suffix which is appended to each
///                             item in the array once.
///
/// @return Length of the comma-separated string array that contains each item
///         in the original array twice with suffixes with given length
///         (common_suf is present after each new item, single_suf is present
///         after half of the new items) and with commas after each item, commas
///         inside the values are escaped.
static inline size_t compute_double_colon_len(const char *const val,
                                              const size_t common_suf_len,
                                              const size_t single_suf_len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (val == NULL || *val == NUL) {
    return 0;
  }
  size_t ret = 0;
  const void *iter = NULL;
  do {
    size_t dir_len;
    const char *dir;
    iter = vim_env_iter(':', val, iter, &dir, &dir_len);
    if (dir != NULL && dir_len > 0) {
      ret += ((dir_len + memcnt(dir, ',', dir_len) + common_suf_len
               + !after_pathsep(dir, dir + dir_len)) * 2
              + single_suf_len);
    }
  } while (iter != NULL);
  return ret;
}

#define NVIM_SIZE (sizeof("nvim") - 1)

/// Add directories to a comma-separated array from a colon-separated one
///
/// Commas are escaped in process. To each item PATHSEP "nvim" is appended in
/// addition to suf1 and suf2.
///
/// @param[in,out]  dest  Destination comma-separated array.
/// @param[in]  val  Source colon-separated array.
/// @param[in]  suf1  If not NULL, suffix appended to destination. Prior to it
///                   directory separator is appended. Suffix must not contain
///                   commas.
/// @param[in]  len1  Length of the suf1.
/// @param[in]  suf2  If not NULL, another suffix appended to destination. Again
///                   with directory separator behind. Suffix must not contain
///                   commas.
/// @param[in]  len2  Length of the suf2.
/// @param[in]  forward  If true, iterate over val in forward direction.
///                      Otherwise in reverse.
///
/// @return (dest + appended_characters_length)
static inline char *add_colon_dirs(char *dest, const char *const val,
                                   const char *const suf1, const size_t len1,
                                   const char *const suf2, const size_t len2,
                                   const bool forward)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1)
{
  if (val == NULL || *val == NUL) {
    return dest;
  }
  const void *iter = NULL;
  do {
    size_t dir_len;
    const char *dir;
    iter = (forward ? vim_env_iter : vim_env_iter_rev)(':', val, iter, &dir,
                                                       &dir_len);
    if (dir != NULL && dir_len > 0) {
      dest = strcpy_comma_escaped(dest, dir, dir_len);
      if (!after_pathsep(dest - 1, dest)) {
        *dest++ = PATHSEP;
      }
      memmove(dest, "nvim", NVIM_SIZE);
      dest += NVIM_SIZE;
      if (suf1 != NULL) {
        *dest++ = PATHSEP;
        memmove(dest, suf1, len1);
        dest += len1;
        if (suf2 != NULL) {
          *dest++ = PATHSEP;
          memmove(dest, suf2, len2);
          dest += len2;
        }
      }
      *dest++ = ',';
    }
  } while (iter != NULL);
  return dest;
}

/// Add directory to a comma-separated list of directories
///
/// In the added directory comma is escaped.
///
/// @param[in,out]  dest  Destination comma-separated array.
/// @param[in]  dir  Directory to append.
/// @param[in]  append_nvim  If true, append "nvim" as the very first suffix.
/// @param[in]  suf1  If not NULL, suffix appended to destination. Prior to it
///                   directory separator is appended. Suffix must not contain
///                   commas.
/// @param[in]  len1  Length of the suf1.
/// @param[in]  suf2  If not NULL, another suffix appended to destination. Again
///                   with directory separator behind. Suffix must not contain
///                   commas.
/// @param[in]  len2  Length of the suf2.
/// @param[in]  forward  If true, iterate over val in forward direction.
///                      Otherwise in reverse.
///
/// @return (dest + appended_characters_length)
static inline char *add_dir(char *dest, const char *const dir,
                            const size_t dir_len, const bool append_nvim,
                            const char *const suf1, const size_t len1,
                            const char *const suf2, const size_t len2)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (dir == NULL || dir_len == 0) {
    return dest;
  }
  dest = strcpy_comma_escaped(dest, dir, dir_len);
  if (append_nvim) {
    if (!after_pathsep(dest - 1, dest)) {
      *dest++ = PATHSEP;
    }
    memmove(dest, "nvim", NVIM_SIZE);
    dest += NVIM_SIZE;
    if (suf1 != NULL) {
      *dest++ = PATHSEP;
      memmove(dest, suf1, len1);
      dest += len1;
      if (suf2 != NULL) {
        *dest++ = PATHSEP;
        memmove(dest, suf2, len2);
        dest += len2;
      }
    }
  }
  *dest++ = ',';
  return dest;
}

/// Set &runtimepath to default value
static void set_runtimepath_default(void)
{
  size_t rtp_size = 0;
  char *const data_home = stdpaths_get_xdg_var(kXDGDataHome);
  char *const config_home = stdpaths_get_xdg_var(kXDGConfigHome);
  char *const vimruntime = vim_getenv("VIMRUNTIME");
  char *const data_dirs = stdpaths_get_xdg_var(kXDGDataDirs);
  char *const config_dirs = stdpaths_get_xdg_var(kXDGConfigDirs);
#define SITE_SIZE (sizeof("site") - 1)
#define AFTER_SIZE (sizeof("after") - 1)
  size_t data_len = 0;
  size_t config_len = 0;
  size_t vimruntime_len = 0;
  if (data_home != NULL) {
    data_len = strlen(data_home);
    if (data_len != 0) {
      rtp_size += ((data_len + memcnt(data_home, ',', data_len)
                    + NVIM_SIZE + 1 + SITE_SIZE + 1
                    + !after_pathsep(data_home, data_home + data_len)) * 2
                   + AFTER_SIZE + 1);
    }
  }
  if (config_home != NULL) {
    config_len = strlen(config_home);
    if (config_len != 0) {
      rtp_size += ((config_len + memcnt(config_home, ',', config_len)
                    + NVIM_SIZE + 1
                    + !after_pathsep(config_home, config_home + config_len)) * 2
                   + AFTER_SIZE + 1);
    }
  }
  if (vimruntime != NULL) {
    vimruntime_len = strlen(vimruntime);
    if (vimruntime_len != 0) {
      rtp_size += vimruntime_len + memcnt(vimruntime, ',', vimruntime_len) + 1;
    }
  }
  rtp_size += compute_double_colon_len(data_dirs, NVIM_SIZE + 1 + SITE_SIZE + 1,
                                       AFTER_SIZE + 1);
  rtp_size += compute_double_colon_len(config_dirs, NVIM_SIZE + 1,
                                       AFTER_SIZE + 1);
  if (rtp_size == 0) {
    return;
  }
  char *const rtp = xmalloc(rtp_size);
  char *rtp_cur = rtp;
  rtp_cur = add_dir(rtp_cur, config_home, config_len, true, NULL, 0, NULL, 0);
  rtp_cur = add_colon_dirs(rtp_cur, config_dirs, NULL, 0, NULL, 0, true);
  rtp_cur = add_dir(rtp_cur, data_home, data_len, true, "site", SITE_SIZE,
                    NULL, 0);
  rtp_cur = add_colon_dirs(rtp_cur, data_dirs, "site", SITE_SIZE, NULL, 0,
                           true);
  rtp_cur = add_dir(rtp_cur, vimruntime, vimruntime_len, false, NULL, 0,
                    NULL, 0);
  rtp_cur = add_colon_dirs(rtp_cur, data_dirs, "site", SITE_SIZE,
                           "after", AFTER_SIZE, false);
  rtp_cur = add_dir(rtp_cur, data_home, data_len, true, "site", SITE_SIZE,
                    "after", AFTER_SIZE);
  rtp_cur = add_colon_dirs(rtp_cur, config_dirs, "after", AFTER_SIZE, NULL, 0,
                           false);
  rtp_cur = add_dir(rtp_cur, config_home, config_len, true,
                    "after", AFTER_SIZE, NULL, 0);
  // Strip trailing comma.
  rtp_cur[-1] = NUL;
  assert((size_t) (rtp_cur - rtp) == rtp_size);
#undef SITE_SIZE
#undef AFTER_SIZE
  set_string_default("runtimepath", rtp, true);
  // Make a copy of 'rtp' for 'packpath'
  set_string_default("packpath", rtp, false);
  xfree(data_dirs);
  xfree(config_dirs);
  xfree(data_home);
  xfree(config_home);
  xfree(vimruntime);
}

#undef NVIM_SIZE

/*
 * Initialize the options, first part.
 *
 * Called only once from main(), just after creating the first buffer.
 */
void set_init_1(void)
{
  int opt_idx;

  langmap_init();

  /* Be nocompatible */
  p_cp = FALSE;

  /*
   * Find default value for 'shell' option.
   * Don't use it if it is empty.
   */
  {
    const char *shell = os_getenv("SHELL");
    if (shell != NULL) {
      set_string_default("sh", (char *) shell, false);
    }
  }

  /*
   * Set the default for 'backupskip' to include environment variables for
   * temp files.
   */
  {
# ifdef UNIX
    static char     *(names[4]) = {"", "TMPDIR", "TEMP", "TMP"};
# else
    static char     *(names[3]) = {"TMPDIR", "TEMP", "TMP"};
# endif
    int len;
    garray_T ga;

    ga_init(&ga, 1, 100);
    for (size_t n = 0; n < ARRAY_SIZE(names); ++n) {
      bool mustfree = true;
      char *p;
# ifdef UNIX
      if (*names[n] == NUL) {
        p = "/tmp";
        mustfree = false;
      }
      else
# endif
      p = vim_getenv(names[n]);
      if (p != NULL && *p != NUL) {
        // First time count the NUL, otherwise count the ','.
        len = (int)strlen(p) + 3;
        ga_grow(&ga, len);
        if (!GA_EMPTY(&ga))
          STRCAT(ga.ga_data, ",");
        STRCAT(ga.ga_data, p);
        add_pathsep(ga.ga_data);
        STRCAT(ga.ga_data, "*");
        ga.ga_len += len;
      }
      if(mustfree) {
        xfree(p);
      }
    }
    if (ga.ga_data != NULL) {
      set_string_default("bsk", ga.ga_data, true);
    }
  }

  /*
   * 'maxmemtot' and 'maxmem' may have to be adjusted for available memory
   */
  opt_idx = findoption("maxmemtot");
  if (opt_idx >= 0) {
    {
      /* Use half of amount of memory available to Vim. */
      /* If too much to fit in uintptr_t, get uintptr_t max */
      uint64_t available_kib = os_get_total_mem_kib();
      uintptr_t n = available_kib / 2 > UINTPTR_MAX
                    ? UINTPTR_MAX
                    : (uintptr_t)(available_kib /2);
      options[opt_idx].def_val[VI_DEFAULT] = (char_u *)n;
      opt_idx = findoption("maxmem");
      if (opt_idx >= 0) {
        options[opt_idx].def_val[VI_DEFAULT] = (char_u *)n;
      }
    }
  }


  {
    char_u  *cdpath;
    char_u  *buf;
    int i;
    int j;

    /* Initialize the 'cdpath' option's default value. */
    cdpath = (char_u *)vim_getenv("CDPATH");
    if (cdpath != NULL) {
      buf = xmalloc(2 * STRLEN(cdpath) + 2);
      {
        buf[0] = ',';               /* start with ",", current dir first */
        j = 1;
        for (i = 0; cdpath[i] != NUL; ++i) {
          if (vim_ispathlistsep(cdpath[i]))
            buf[j++] = ',';
          else {
            if (cdpath[i] == ' ' || cdpath[i] == ',')
              buf[j++] = '\\';
            buf[j++] = cdpath[i];
          }
        }
        buf[j] = NUL;
        opt_idx = findoption("cdpath");
        if (opt_idx >= 0) {
          options[opt_idx].def_val[VI_DEFAULT] = buf;
          options[opt_idx].flags |= P_DEF_ALLOCED;
        } else
          xfree(buf);           /* cannot happen */
      }
      xfree(cdpath);
    }
  }

#if defined(MSWIN) || defined(MAC)
  /* Set print encoding on platforms that don't default to latin1 */
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

  char *backupdir = stdpaths_user_data_subpath("backup", 0, true);
  const size_t backupdir_len = strlen(backupdir);
  backupdir = xrealloc(backupdir, backupdir_len + 3);
  memmove(backupdir + 2, backupdir, backupdir_len + 1);
  memmove(backupdir, ".,", 2);
  set_string_default("viewdir", stdpaths_user_data_subpath("view", 0, true),
                     true);
  set_string_default("backupdir", backupdir, true);
  set_string_default("directory", stdpaths_user_data_subpath("swap", 2, true),
                     true);
  set_string_default("undodir", stdpaths_user_data_subpath("undo", 0, true),
                     true);
  // Set default for &runtimepath. All necessary expansions are performed in
  // this function.
  set_runtimepath_default();

  /*
   * Set all the options (except the terminal options) to their default
   * value.  Also set the global value for local options.
   */
  set_options_default(0);


  curbuf->b_p_initialized = true;
  curbuf->b_p_ar = -1;          /* no local 'autoread' value */
  curbuf->b_p_ul = NO_LOCAL_UNDOLEVEL;
  check_buf_options(curbuf);
  check_win_options(curwin);
  check_options();

  /* Set all options to their Vim default */
  set_options_default(OPT_FREE);

  // set 'laststatus'
  last_status(false);

  /* Must be before option_expand(), because that one needs vim_isIDc() */
  didset_options();

  // Use the current chartab for the generic chartab. This is not in
  // didset_options() because it only depends on 'encoding'.
  init_spell_chartab();

  /*
   * Expand environment variables and things like "~" for the defaults.
   * If option_expand() returns non-NULL the variable is expanded.  This can
   * only happen for non-indirect options.
   * Also set the default to the expanded value, so ":set" does not list
   * them.
   * Don't set the P_ALLOCED flag, because we don't want to free the
   * default.
   */
  for (opt_idx = 0; options[opt_idx].fullname; opt_idx++) {
    if (options[opt_idx].flags & P_NO_DEF_EXP) {
      continue;
    }
    char *p;
    if ((options[opt_idx].flags & P_GETTEXT)
        && options[opt_idx].var != NULL) {
      p = _(*(char **)options[opt_idx].var);
    } else {
      p = (char *) option_expand(opt_idx, NULL);
    }
    if (p != NULL) {
      p = xstrdup(p);
      *(char **)options[opt_idx].var = p;
      /* VIMEXP
       * Defaults for all expanded options are currently the same for Vi
       * and Vim.  When this changes, add some code here!  Also need to
       * split P_DEF_ALLOCED in two.
       */
      if (options[opt_idx].flags & P_DEF_ALLOCED)
        xfree(options[opt_idx].def_val[VI_DEFAULT]);
      options[opt_idx].def_val[VI_DEFAULT] = (char_u *) p;
      options[opt_idx].flags |= P_DEF_ALLOCED;
    }
  }

  save_file_ff(curbuf);         /* Buffer is unchanged */

  /* Detect use of mlterm.
   * Mlterm is a terminal emulator akin to xterm that has some special
   * abilities (bidi namely).
   * NOTE: mlterm's author is being asked to 'set' a variable
   *       instead of an environment variable due to inheritance.
   */
  if (os_env_exists("MLTERM")) {
    set_option_value("tbidi", 1L, NULL, 0);
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
  (void)bind_textdomain_codeset(PROJECT_NAME, (char *)p_enc);
#endif

  /* Set the default for 'helplang'. */
  set_helplang_default(get_mess_lang());
}

/*
 * Set an option to its default value.
 * This does not take care of side effects!
 */
static void 
set_option_default (
    int opt_idx,
    int opt_flags,                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
    int compatible                 /* use Vi default value */
)
{
  char_u      *varp;            /* pointer to variable for current option */
  int dvi;                      /* index in def_val[] */
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;

  varp = get_varp_scope(&(options[opt_idx]), both ? OPT_LOCAL : opt_flags);
  uint32_t flags = options[opt_idx].flags;
  if (varp != NULL) {       /* skip hidden option, nothing to do for it */
    dvi = ((flags & P_VI_DEF) || compatible) ? VI_DEFAULT : VIM_DEFAULT;
    if (flags & P_STRING) {
      /* Use set_string_option_direct() for local options to handle
       * freeing and allocating the value. */
      if (options[opt_idx].indir != PV_NONE) {
        set_string_option_direct(NULL, opt_idx,
                                 options[opt_idx].def_val[dvi], opt_flags, 0);
      } else {
        if ((opt_flags & OPT_FREE) && (flags & P_ALLOCED)) {
          free_string_option(*(char_u **)(varp));
        }
        *(char_u **)varp = options[opt_idx].def_val[dvi];
        options[opt_idx].flags &= ~P_ALLOCED;
      }
    } else if (flags & P_NUM)   {
      if (options[opt_idx].indir == PV_SCROLL) {
        win_comp_scroll(curwin);
      } else {
        *(long *)varp = (long)(intptr_t)options[opt_idx].def_val[dvi];
        // May also set global value for local option.
        if (both) {
          *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
            *(long *)varp;
        }
      }
    } else {  /* P_BOOL */
      *(int *)varp = (int)(intptr_t)options[opt_idx].def_val[dvi];
#ifdef UNIX
      /* 'modeline' defaults to off for root */
      if (options[opt_idx].indir == PV_ML && getuid() == ROOT_UID)
        *(int *)varp = FALSE;
#endif
      /* May also set global value for local option. */
      if (both)
        *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) =
          *(int *)varp;
    }

    /* The default value is not insecure. */
    uint32_t *flagsp = insecure_flag(opt_idx, opt_flags);
    *flagsp = *flagsp & ~P_INSECURE;
  }

  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);
}

/*
 * Set all options (except terminal options) to their default value.
 */
static void 
set_options_default (
    int opt_flags                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
)
{
  for (int i = 0; options[i].fullname; i++) {
    if (!(options[i].flags & P_NODEFAULT)) {
      set_option_default(i, opt_flags, p_cp);
    }
  }

  /* The 'scroll' option must be computed for all windows. */
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
      xfree(options[opt_idx].def_val[VI_DEFAULT]);
    }

    options[opt_idx].def_val[VI_DEFAULT] = (char_u *) (
        allocated
        ? (char_u *) val
        : (char_u *) xstrdup(val));
    options[opt_idx].flags |= P_DEF_ALLOCED;
  }
}

/*
 * Set the Vi-default value of a number option.
 * Used for 'lines' and 'columns'.
 */
void set_number_default(char *name, long val)
{
  int opt_idx;

  opt_idx = findoption(name);
  if (opt_idx >= 0) {
    options[opt_idx].def_val[VI_DEFAULT] = (char_u *)(intptr_t)val;
  }
}

#if defined(EXITFREE)
/*
 * Free all options.
 */
void free_all_options(void)
{
  int i;

  for (i = 0; options[i].fullname; i++) {
    if (options[i].indir == PV_NONE) {
      /* global option: free value and default value. */
      if (options[i].flags & P_ALLOCED && options[i].var != NULL)
        free_string_option(*(char_u **)options[i].var);
      if (options[i].flags & P_DEF_ALLOCED)
        free_string_option(options[i].def_val[VI_DEFAULT]);
    } else if (options[i].var != VAR_WIN
               && (options[i].flags & P_STRING))
      /* buffer-local option: free global value */
      free_string_option(*(char_u **)options[i].var);
  }
}

#endif


/// Initialize the options, part two: After getting Rows and Columns.
void set_init_2(bool headless)
{
  int idx;

  /*
   * 'scroll' defaults to half the window height. Note that this default is
   * wrong when the window height changes.
   */
  set_number_default("scroll", Rows / 2);
  idx = findoption("scroll");
  if (idx >= 0 && !(options[idx].flags & P_WAS_SET)) {
    set_option_default(idx, OPT_LOCAL, p_cp);
  }
  comp_col();

  /*
   * 'window' is only for backwards compatibility with Vi.
   * Default is Rows - 1.
   */
  if (!option_was_set("window")) {
    p_window = Rows - 1;
  }
  set_number_default("window", Rows - 1);
#if 0
  // This bodges around problems that should be fixed in the TUI layer.
  if (!headless && !os_term_is_nice()) {
    set_string_option_direct((char_u *)"guicursor", -1, (char_u *)"",
                             OPT_GLOBAL, SID_NONE);
  }
#endif
  parse_shape_opt(SHAPE_CURSOR);   // set cursor shapes from 'guicursor'
  (void)parse_printoptions();      // parse 'printoptions' default value
}

/*
 * Initialize the options, part three: After reading the .vimrc
 */
void set_init_3(void)
{
  // Set 'shellpipe' and 'shellredir', depending on the 'shell' option.
  // This is done after other initializations, where 'shell' might have been
  // set, but only if they have not been set before.
  int idx_srr;
  int do_srr;
  int idx_sp;
  int do_sp;

  idx_srr = findoption("srr");
  if (idx_srr < 0) {
    do_srr = false;
  } else {
    do_srr = !(options[idx_srr].flags & P_WAS_SET);
  }
  idx_sp = findoption("sp");
  if (idx_sp < 0) {
    do_sp = false;
  } else {
    do_sp = !(options[idx_sp].flags & P_WAS_SET);
  }

  size_t len = 0;
  char_u *p = (char_u *)invocation_path_tail(p_sh, &len);
  p = vim_strnsave(p, len);

  {
    /*
     * Default for p_sp is "| tee", for p_srr is ">".
     * For known shells it is changed here to include stderr.
     */
    if (       fnamecmp(p, "csh") == 0
               || fnamecmp(p, "tcsh") == 0
               ) {
      if (do_sp) {
        p_sp = (char_u *)"|& tee";
        options[idx_sp].def_val[VI_DEFAULT] = p_sp;
      }
      if (do_srr) {
        p_srr = (char_u *)">&";
        options[idx_srr].def_val[VI_DEFAULT] = p_srr;
      }
    } else if (       fnamecmp(p, "sh") == 0
                      || fnamecmp(p, "ksh") == 0
                      || fnamecmp(p, "mksh") == 0
                      || fnamecmp(p, "pdksh") == 0
                      || fnamecmp(p, "zsh") == 0
                      || fnamecmp(p, "zsh-beta") == 0
                      || fnamecmp(p, "bash") == 0
                      || fnamecmp(p, "fish") == 0
                      ) {
      if (do_sp) {
        p_sp = (char_u *)"2>&1| tee";
        options[idx_sp].def_val[VI_DEFAULT] = p_sp;
      }
      if (do_srr) {
        p_srr = (char_u *)">%s 2>&1";
        options[idx_srr].def_val[VI_DEFAULT] = p_srr;
      }
    }
    xfree(p);
  }

  if (BUFEMPTY()) {
    int idx_ffs = findoption_len(S_LEN("ffs"));

    // Apply the first entry of 'fileformats' to the initial buffer.
    if (idx_ffs >= 0 && (options[idx_ffs].flags & P_WAS_SET)) {
      set_fileformat(default_fileformat(), OPT_LOCAL);
    }
  }

  set_title_defaults();
}

/*
 * When 'helplang' is still at its default value, set it to "lang".
 * Only the first two characters of "lang" are used.
 */
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
    if (options[idx].flags & P_ALLOCED)
      free_string_option(p_hlg);
    p_hlg = (char_u *)xmemdupz(lang, lang_len);
    // zh_CN becomes "cn", zh_TW becomes "tw".
    if (STRNICMP(p_hlg, "zh_", 3) == 0 && STRLEN(p_hlg) >= 5) {
      p_hlg[0] = (char_u)TOLOWER_ASC(p_hlg[3]);
      p_hlg[1] = (char_u)TOLOWER_ASC(p_hlg[4]);
    }
    p_hlg[2] = NUL;
    options[idx].flags |= P_ALLOCED;
  }
}


/*
 * 'title' and 'icon' only default to true if they have not been set or reset
 * in .vimrc and we can read the old value.
 * When 'title' and 'icon' have been reset in .vimrc, we won't even check if
 * they can be reset.  This reduces startup time when using X on a remote
 * machine.
 */
void set_title_defaults(void)
{
  int idx1;

  /*
   * If GUI is (going to be) used, we can always set the window title and
   * icon name.  Saves a bit of time, because the X11 display server does
   * not need to be contacted.
   */
  idx1 = findoption("title");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val[VI_DEFAULT] = (char_u *)(intptr_t)0;
    p_title = 0;
  }
  idx1 = findoption("icon");
  if (idx1 >= 0 && !(options[idx1].flags & P_WAS_SET)) {
    options[idx1].def_val[VI_DEFAULT] = (char_u *)(intptr_t)0;
    p_icon = 0;
  }
}

/*
 * Parse 'arg' for option settings.
 *
 * 'arg' may be IObuff, but only when no errors can be present and option
 * does not need to be expanded with option_expand().
 * "opt_flags":
 * 0 for ":set"
 * OPT_GLOBAL   for ":setglobal"
 * OPT_LOCAL    for ":setlocal" and a modeline
 * OPT_MODELINE for a modeline
 * OPT_WINONLY  to only set window-local options
 * OPT_NOWIN	to skip setting window-local options
 *
 * returns FAIL if an error is detected, OK otherwise
 */
int 
do_set (
    char_u *arg,               /* option string (may be written to!) */
    int opt_flags
)
{
  int opt_idx;
  char_u      *errmsg;
  char_u errbuf[80];
  char_u      *startarg;
  int prefix;           /* 1: nothing, 0: "no", 2: "inv" in front of name */
  char_u nextchar;                  /* next non-white char after option name */
  int afterchar;                    /* character just after option name */
  int len;
  int i;
  varnumber_T value;
  int key;
  uint32_t flags;                   /* flags for current option */
  char_u      *varp = NULL;         /* pointer to variable for current option */
  int did_show = FALSE;             /* already showed one value */
  int adding;                       /* "opt+=arg" */
  int prepending;                   /* "opt^=arg" */
  int removing;                     /* "opt-=arg" */
  int cp_val = 0;

  if (*arg == NUL) {
    showoptions(0, opt_flags);
    did_show = TRUE;
    goto theend;
  }

  while (*arg != NUL) {         /* loop to process all options */
    errmsg = NULL;
    startarg = arg;             /* remember for error message */

    if (STRNCMP(arg, "all", 3) == 0 && !isalpha(arg[3])
        && !(opt_flags & OPT_MODELINE)) {
      /*
       * ":set all"  show all options.
       * ":set all&" set all options to their default value.
       */
      arg += 3;
      if (*arg == '&') {
        arg++;
        // Only for :set command set global value of local options.
        set_options_default(OPT_FREE | opt_flags);
        didset_options();
        didset_options2();
        ui_refresh_options();
        redraw_all_later(CLEAR);
      } else {
        showoptions(1, opt_flags);
        did_show = TRUE;
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

      /* find end of name */
      key = 0;
      if (*arg == '<') {
        opt_idx = -1;
        /* look out for <t_>;> */
        if (arg[1] == 't' && arg[2] == '_' && arg[3] && arg[4])
          len = 5;
        else {
          len = 1;
          while (arg[len] != NUL && arg[len] != '>')
            ++len;
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
          key = find_key_option(arg + 1);
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
          key = find_key_option(arg);
        }
      }

      /* remember character after option name */
      afterchar = arg[len];

      /* skip white space, allow ":set ai  ?" */
      while (ascii_iswhite(arg[len]))
        ++len;

      adding = FALSE;
      prepending = FALSE;
      removing = FALSE;
      if (arg[len] != NUL && arg[len + 1] == '=') {
        if (arg[len] == '+') {
          adding = TRUE;                        /* "+=" */
          ++len;
        } else if (arg[len] == '^') {
          prepending = TRUE;                    /* "^=" */
          ++len;
        } else if (arg[len] == '-') {
          removing = TRUE;                      /* "-=" */
          ++len;
        }
      }
      nextchar = arg[len];

      if (opt_idx == -1 && key == 0) {          /* found a mismatch: skip */
        errmsg = (char_u *)N_("E518: Unknown option");
        goto skip;
      }

      if (opt_idx >= 0) {
        if (options[opt_idx].var == NULL) {         /* hidden option: skip */
          /* Only give an error message when requesting the value of
           * a hidden option, ignore setting it. */
          if (vim_strchr((char_u *)"=:!&<", nextchar) == NULL
              && (!(options[opt_idx].flags & P_BOOL)
                  || nextchar == '?'))
            errmsg = (char_u *)_(e_unsupportedoption);
          goto skip;
        }

        flags = options[opt_idx].flags;
        varp = get_varp_scope(&(options[opt_idx]), opt_flags);
      } else {
        flags = P_STRING;
      }

      /* Skip all options that are not window-local (used when showing
       * an already loaded buffer in a window). */
      if ((opt_flags & OPT_WINONLY)
          && (opt_idx < 0 || options[opt_idx].var != VAR_WIN))
        goto skip;

      /* Skip all options that are window-local (used for :vimgrep). */
      if ((opt_flags & OPT_NOWIN) && opt_idx >= 0
          && options[opt_idx].var == VAR_WIN)
        goto skip;

      /* Disallow changing some options from modelines. */
      if (opt_flags & OPT_MODELINE) {
        if (flags & (P_SECURE | P_NO_ML)) {
          errmsg = (char_u *)_("E520: Not allowed in a modeline");
          goto skip;
        }
        /* In diff mode some options are overruled.  This avoids that
         * 'foldmethod' becomes "marker" instead of "diff" and that
         * "wrap" gets set. */
        if (curwin->w_p_diff
            && opt_idx >= 0              /* shut up coverity warning */
            && (options[opt_idx].indir == PV_FDM
                || options[opt_idx].indir == PV_WRAP))
          goto skip;
      }

      /* Disallow changing some options in the sandbox */
      if (sandbox != 0 && (flags & P_SECURE)) {
        errmsg = (char_u *)_(e_sandbox);
        goto skip;
      }

      if (vim_strchr((char_u *)"?=:!&<", nextchar) != NULL) {
        arg += len;
        cp_val = p_cp;
        if (nextchar == '&' && arg[1] == 'v' && arg[2] == 'i') {
          if (arg[3] == 'm') {          /* "opt&vim": set to Vim default */
            cp_val = FALSE;
            arg += 3;
          } else {                    /* "opt&vi": set to Vi default */
            cp_val = TRUE;
            arg += 2;
          }
        }
        if (vim_strchr((char_u *)"?!&<", nextchar) != NULL
            && arg[1] != NUL && !ascii_iswhite(arg[1])) {
          errmsg = e_trailing;
          goto skip;
        }
      }

      /*
       * allow '=' and ':' as MSDOS command.com allows only one
       * '=' character per "set" command line. grrr. (jw)
       */
      if (nextchar == '?'
          || (prefix == 1
              && vim_strchr((char_u *)"=:&<", nextchar) == NULL
              && !(flags & P_BOOL))) {
        /*
         * print value
         */
        if (did_show)
          msg_putchar('\n');                /* cursor below last one */
        else {
          gotocmdline(TRUE);                /* cursor at status line */
          did_show = TRUE;                  /* remember that we did a line */
        }
        if (opt_idx >= 0) {
          showoneopt(&options[opt_idx], opt_flags);
          if (p_verbose > 0) {
            /* Mention where the option was last set. */
            if (varp == options[opt_idx].var)
              last_set_msg(options[opt_idx].scriptID);
            else if ((int)options[opt_idx].indir & PV_WIN)
              last_set_msg(curwin->w_p_scriptID[
                    (int)options[opt_idx].indir & PV_MASK]);
            else if ((int)options[opt_idx].indir & PV_BUF)
              last_set_msg(curbuf->b_p_scriptID[
                    (int)options[opt_idx].indir & PV_MASK]);
          }
        } else {
          errmsg = (char_u *)N_("E846: Key code not set");
          goto skip;
        }
        if (nextchar != '?'
            && nextchar != NUL && !ascii_iswhite(afterchar))
          errmsg = e_trailing;
      } else {
        if (flags & P_BOOL) {                       /* boolean */
          if (nextchar == '=' || nextchar == ':') {
            errmsg = e_invarg;
            goto skip;
          }

          /*
           * ":set opt!": invert
           * ":set opt&": reset to default value
           * ":set opt<": reset to global value
           */
          if (nextchar == '!')
            value = *(int *)(varp) ^ 1;
          else if (nextchar == '&')
            value = (int)(intptr_t)options[opt_idx].def_val[
              ((flags & P_VI_DEF) || cp_val)
              ?  VI_DEFAULT : VIM_DEFAULT];
          else if (nextchar == '<') {
            /* For 'autoread' -1 means to use global value. */
            if ((int *)varp == &curbuf->b_p_ar
                && opt_flags == OPT_LOCAL)
              value = -1;
            else
              value = *(int *)get_varp_scope(&(options[opt_idx]),
                  OPT_GLOBAL);
          } else {
            /*
             * ":set invopt": invert
             * ":set opt" or ":set noopt": set or reset
             */
            if (nextchar != NUL && !ascii_iswhite(afterchar)) {
              errmsg = e_trailing;
              goto skip;
            }
            if (prefix == 2)                    /* inv */
              value = *(int *)(varp) ^ 1;
            else
              value = prefix;
          }

          errmsg = (char_u *)set_bool_option(opt_idx, varp, (int)value,
                                             opt_flags);
        } else {  // Numeric or string.
          if (vim_strchr((const char_u *)"=:&<", nextchar) == NULL
              || prefix != 1) {
            errmsg = e_invarg;
            goto skip;
          }

          if (flags & P_NUM) {                      /* numeric */
            /*
             * Different ways to set a number option:
             * &	    set to default value
             * <	    set to global value
             * <xx>	    accept special key codes for 'wildchar'
             * c	    accept any non-digit for 'wildchar'
             * [-]0-9   set number
             * other    error
             */
            arg++;
            if (nextchar == '&') {
              value = (long)(intptr_t)options[opt_idx].def_val[
                  ((flags & P_VI_DEF) || cp_val) ? VI_DEFAULT : VIM_DEFAULT];
            } else if (nextchar == '<') {
              // For 'undolevels' NO_LOCAL_UNDOLEVEL means to
              // use the global value.
              if ((long *)varp == &curbuf->b_p_ul && opt_flags == OPT_LOCAL) {
                value = NO_LOCAL_UNDOLEVEL;
              } else {
                value = *(long *)get_varp_scope(
                    &(options[opt_idx]), OPT_GLOBAL);
              }
            } else if (((long *)varp == &p_wc
                        || (long *)varp == &p_wcm)
                       && (*arg == '<'
                           || *arg == '^'
                           || ((!arg[1] || ascii_iswhite(arg[1]))
                               && !ascii_isdigit(*arg)))) {
              value = string_to_key(arg);
              if (value == 0 && (long *)varp != &p_wcm) {
                errmsg = e_invarg;
                goto skip;
              }
            } else if (*arg == '-' || ascii_isdigit(*arg)) {
              // Allow negative (for 'undolevels'), octal and
              // hex numbers.
              vim_str2nr(arg, NULL, &i, STR2NR_ALL, &value, NULL, 0);
              if (arg[i] != NUL && !ascii_iswhite(arg[i])) {
                errmsg = e_invarg;
                goto skip;
              }
            } else {
              errmsg = (char_u *)N_("E521: Number required after =");
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
            errmsg = (char_u *)set_num_option(opt_idx, varp, (long)value,
                                              errbuf, sizeof(errbuf),
                                              opt_flags);
          } else if (opt_idx >= 0) {  // String.
            char_u      *save_arg = NULL;
            char_u      *s = NULL;
            char_u      *oldval = NULL;         // previous value if *varp
            char_u      *newval;
            char_u      *origval = NULL;
            char *saved_origval = NULL;
            unsigned newlen;
            int comma;
            int bs;
            int new_value_alloced;                      /* new string option
                                                           was allocated */

            /* When using ":set opt=val" for a global option
             * with a local value the local value will be
             * reset, use the global value here. */
            if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
                && ((int)options[opt_idx].indir & PV_BOTH))
              varp = options[opt_idx].var;

            /* The old value is kept until we are sure that the
             * new value is valid. */
            oldval = *(char_u **)varp;
            if (nextchar == '&') {              /* set to default val */
              newval = options[opt_idx].def_val[
                ((flags & P_VI_DEF) || cp_val)
                ?  VI_DEFAULT : VIM_DEFAULT];
              /* expand environment variables and ~ (since the
               * default value was already expanded, only
               * required when an environment variable was set
               * later */
              new_value_alloced = true;
              if (newval == NULL) {
                newval = empty_option;
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
              newval = vim_strsave(*(char_u **)get_varp_scope(
                      &(options[opt_idx]), OPT_GLOBAL));
              new_value_alloced = TRUE;
            } else {
              ++arg;                    /* jump to after the '=' or ':' */

              /*
               * Set 'keywordprg' to ":help" if an empty
               * value was passed to :set by the user.
               * Misuse errbuf[] for the resulting string.
               */
              if (varp == (char_u *)&p_kp
                  && (*arg == NUL || *arg == ' ')) {
                STRCPY(errbuf, ":help");
                save_arg = arg;
                arg = errbuf;
              }
              /*
               * Convert 'backspace' number to string, for
               * adding, prepending and removing string.
               */
              else if (varp == (char_u *)&p_bs
                       && ascii_isdigit(**(char_u **)varp)) {
                i = getdigits_int((char_u **)varp);
                switch (i) {
                case 0:
                  *(char_u **)varp = empty_option;
                  break;
                case 1:
                  *(char_u **)varp = vim_strsave(
                      (char_u *)"indent,eol");
                  break;
                case 2:
                  *(char_u **)varp = vim_strsave(
                      (char_u *)"indent,eol,start");
                  break;
                }
                xfree(oldval);
                oldval = *(char_u **)varp;
              }
              /*
               * Convert 'whichwrap' number to string, for
               * backwards compatibility with Vim 3.0.
               * Misuse errbuf[] for the resulting string.
               */
              else if (varp == (char_u *)&p_ww
                       && ascii_isdigit(*arg)) {
                *errbuf = NUL;
                i = getdigits_int(&arg);
                if (i & 1)
                  STRCAT(errbuf, "b,");
                if (i & 2)
                  STRCAT(errbuf, "s,");
                if (i & 4)
                  STRCAT(errbuf, "h,l,");
                if (i & 8)
                  STRCAT(errbuf, "<,>,");
                if (i & 16)
                  STRCAT(errbuf, "[,],");
                if (*errbuf != NUL)                     /* remove trailing , */
                  errbuf[STRLEN(errbuf) - 1] = NUL;
                save_arg = arg;
                arg = errbuf;
              }
              /*
               * Remove '>' before 'dir' and 'bdir', for
               * backwards compatibility with version 3.0
               */
              else if (  *arg == '>'
                         && (varp == (char_u *)&p_dir
                             || varp == (char_u *)&p_bdir)) {
                ++arg;
              }

              /* When setting the local value of a global
               * option, the old value may be the global value. */
              if (((int)options[opt_idx].indir & PV_BOTH)
                  && (opt_flags & OPT_LOCAL))
                origval = *(char_u **)get_varp(
                    &options[opt_idx]);
              else
                origval = oldval;

              /*
               * Copy the new string into allocated memory.
               * Can't use set_string_option_direct(), because
               * we need to remove the backslashes.
               */
              /* get a bit too much */
              newlen = (unsigned)STRLEN(arg) + 1;
              if (adding || prepending || removing)
                newlen += (unsigned)STRLEN(origval) + 1;
              newval = xmalloc(newlen);
              s = newval;

              /*
               * Copy the string, skip over escaped chars.
               * For WIN32 backslashes before normal
               * file name characters are not removed, and keep
               * backslash at start, for "\\machine\path", but
               * do remove it for "\\\\machine\\path".
               * The reverse is found in ExpandOldSetting().
               */
              while (*arg && !ascii_iswhite(*arg)) {
                if (*arg == '\\' && arg[1] != NUL
#ifdef BACKSLASH_IN_FILENAME
                    && !((flags & P_EXPAND)
                         && vim_isfilec(arg[1])
                         && (arg[1] != '\\'
                             || (s == newval
                                 && arg[2] != '\\')))
#endif
                    )
                  ++arg;                        /* remove backslash */
                if (has_mbyte
                    && (i = (*mb_ptr2len)(arg)) > 1) {
                  /* copy multibyte char */
                  memmove(s, arg, (size_t)i);
                  arg += i;
                  s += i;
                } else
                  *s++ = *arg++;
              }
              *s = NUL;

              /*
               * Expand environment variables and ~.
               * Don't do it when adding without inserting a
               * comma.
               */
              if (!(adding || prepending || removing)
                  || (flags & P_COMMA)) {
                s = option_expand(opt_idx, newval);
                if (s != NULL) {
                  xfree(newval);
                  newlen = (unsigned)STRLEN(s) + 1;
                  if (adding || prepending || removing)
                    newlen += (unsigned)STRLEN(origval) + 1;
                  newval = xmalloc(newlen);
                  STRCPY(newval, s);
                }
              }

              /* locate newval[] in origval[] when removing it
               * and when adding to avoid duplicates */
              i = 0;                    /* init for GCC */
              if (removing || (flags & P_NODUP)) {
                i = (int)STRLEN(newval);
                bs = 0;
                for (s = origval; *s; ++s) {
                  if ((!(flags & P_COMMA)
                       || s == origval
                       || (s[-1] == ',' && !(bs & 1)))
                      && STRNCMP(s, newval, i) == 0
                      && (!(flags & P_COMMA)
                          || s[i] == ','
                          || s[i] == NUL)) {
                    break;
                  }
                  // Count backslashes.  Only a comma with an even number of
                  // backslashes or a single backslash preceded by a comma
                  // before it is recognized as a separator
                  if ((s > origval + 1 && s[-1] == '\\' && s[-2] != ',')
                      || (s == origval + 1 && s[-1] == '\\')) {
                    bs++;
                  } else {
                    bs = 0;
                  }
                }

                // do not add if already there
                if ((adding || prepending) && *s) {
                  prepending = FALSE;
                  adding = FALSE;
                  STRCPY(newval, origval);
                }
              }

              /* concatenate the two strings; add a ',' if
               * needed */
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
                if (comma)
                  newval[i] = ',';
              }

              /* Remove newval[] from origval[]. (Note: "i" has
               * been set above and is used here). */
              if (removing) {
                STRCPY(newval, origval);
                if (*s) {
                  /* may need to remove a comma */
                  if (flags & P_COMMA) {
                    if (s == origval) {
                      /* include comma after string */
                      if (s[i] == ',')
                        ++i;
                    } else {
                      /* include comma before string */
                      --s;
                      ++i;
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
                        && vim_strchr(s + 2, *s) != NULL) {
                      // Remove the duplicated value and the next comma.
                      STRMOVE(s, s + 2);
                      continue;
                    }
                  } else {
                    if ((!(flags & P_COMMA) || *s != ',')
                        && vim_strchr(s + 1, *s) != NULL) {
                      STRMOVE(s, s + 1);
                      continue;
                    }
                  }
                  s++;
                }
              }

              if (save_arg != NULL)                 /* number for 'whichwrap' */
                arg = save_arg;
              new_value_alloced = TRUE;
            }

            /* Set the new value. */
            *(char_u **)(varp) = newval;

            if (!starting && origval != NULL) {
              // origval may be freed by
              // did_set_string_option(), make a copy.
              saved_origval = xstrdup((char *) origval);
            }

            /* Handle side effects, and set the global value for
             * ":set" on local options. */
            errmsg = did_set_string_option(opt_idx, (char_u **)varp,
                new_value_alloced, oldval, errbuf, opt_flags);

            // If error detected, print the error message.
            if (errmsg != NULL) {
              xfree(saved_origval);
              goto skip;
            }

            if (saved_origval != NULL) {
              char buf_type[7];
              vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                           (opt_flags & OPT_LOCAL) ? "local" : "global");
              set_vim_var_string(VV_OPTION_NEW, *(char **) varp, -1);
              set_vim_var_string(VV_OPTION_OLD, saved_origval, -1);
              set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
              apply_autocmds(EVENT_OPTIONSET,
                             (char_u *)options[opt_idx].fullname,
                             NULL, false, NULL);
              reset_v_option_vars();
              xfree(saved_origval);
              if (options[opt_idx].flags & P_UI_OPTION) {
                ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                                   STRING_OBJ(cstr_as_string(*(char **)varp)));
              }
            }
          } else {
            // key code option(FIXME(tarruda): Show a warning or something
            // similar)
          }
        }

        if (opt_idx >= 0)
          did_set_option(opt_idx, opt_flags,
              !prepending && !adding && !removing);
      }

skip:
      /*
       * Advance to next argument.
       * - skip until a blank found, taking care of backslashes
       * - skip blanks
       * - skip one "=val" argument (for hidden options ":set gfn =xx")
       */
      for (i = 0; i < 2; ++i) {
        while (*arg != NUL && !ascii_iswhite(*arg))
          if (*arg++ == '\\' && *arg != NUL)
            ++arg;
        arg = skipwhite(arg);
        if (*arg != '=')
          break;
      }
    }

    if (errmsg != NULL) {
      STRLCPY(IObuff, _(errmsg), IOSIZE);
      i = (int)STRLEN(IObuff) + 2;
      if (i + (arg - startarg) < IOSIZE) {
        /* append the argument with the error */
        STRCAT(IObuff, ": ");
        assert(arg >= startarg);
        memmove(IObuff + i, startarg, (size_t)(arg - startarg));
        IObuff[i + (arg - startarg)] = NUL;
      }
      /* make sure all characters are printable */
      trans_characters(IObuff, IOSIZE);

      ++no_wait_return;         /* wait_return done later */
      emsg(IObuff);             /* show error highlighted */
      --no_wait_return;

      return FAIL;
    }

    arg = skipwhite(arg);
  }

theend:
  if (silent_mode && did_show) {
    /* After displaying option values in silent mode. */
    silent_mode = FALSE;
    info_message = TRUE;        /* use mch_msg(), not mch_errmsg() */
    msg_putchar('\n');
    ui_flush();
    silent_mode = TRUE;
    info_message = FALSE;       /* use mch_msg(), not mch_errmsg() */
  }

  return OK;
}

/*
 * Call this when an option has been given a new value through a user command.
 * Sets the P_WAS_SET flag and takes care of the P_INSECURE flag.
 */
static void 
did_set_option (
    int opt_idx,
    int opt_flags,              /* possibly with OPT_MODELINE */
    int new_value              /* value was replaced completely */
)
{
  options[opt_idx].flags |= P_WAS_SET;

  /* When an option is set in the sandbox, from a modeline or in secure mode
   * set the P_INSECURE flag.  Otherwise, if a new value is stored reset the
   * flag. */
  uint32_t *p = insecure_flag(opt_idx, opt_flags);
  if (secure
      || sandbox != 0
      || (opt_flags & OPT_MODELINE))
    *p = *p | P_INSECURE;
  else if (new_value)
    *p = *p & ~P_INSECURE;
}

static char_u *illegal_char(char_u *errbuf, int c)
{
  if (errbuf == NULL)
    return (char_u *)"";
  sprintf((char *)errbuf, _("E539: Illegal character <%s>"),
      (char *)transchar(c));
  return errbuf;
}

/*
 * Convert a key name or string into a key value.
 * Used for 'wildchar' and 'cedit' options.
 */
static int string_to_key(char_u *arg)
{
  if (*arg == '<')
    return find_key_option(arg + 1);
  if (*arg == '^')
    return Ctrl_chr(arg[1]);
  return *arg;
}

/*
 * Check value of 'cedit' and set cedit_key.
 * Returns NULL if value is OK, error message otherwise.
 */
static char_u *check_cedit(void)
{
  int n;

  if (*p_cedit == NUL)
    cedit_key = -1;
  else {
    n = string_to_key(p_cedit);
    if (vim_isprintc(n))
      return e_invarg;
    cedit_key = n;
  }
  return NULL;
}

/*
 * When changing 'title', 'titlestring', 'icon' or 'iconstring', call
 * maketitle() to create and display it.
 * When switching the title or icon off, call ui_set_{icon,title}(NULL) to get
 * the old value back.
 */
static void 
did_set_title (
    int icon                   /* Did set icon instead of title */
)
{
  if (starting != NO_SCREEN) {
    maketitle();
    resettitle();
  }
}

/*
 * set_options_bin -  called when 'bin' changes value.
 */
void 
set_options_bin (
    int oldval,
    int newval,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  /*
   * The option values that are changed when 'bin' changes are
   * copied when 'bin is set and restored when 'bin' is reset.
   */
  if (newval) {
    if (!oldval) {              /* switched on */
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
      curbuf->b_p_tw = 0;       /* no automatic line wrap */
      curbuf->b_p_wm = 0;       /* no automatic line wrap */
      curbuf->b_p_ml = 0;       /* no modelines */
      curbuf->b_p_et = 0;       /* no expandtab */
    }
    if (!(opt_flags & OPT_LOCAL)) {
      p_tw = 0;
      p_wm = 0;
      p_ml = FALSE;
      p_et = FALSE;
      p_bin = TRUE;             /* needed when called for the "-b" argument */
    }
  } else if (oldval) {        /* switched off */
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

/*
 * Find the parameter represented by the given character (eg ', :, ", or /),
 * and return its associated value in the 'shada' string.
 * Only works for number parameters, not for 'r' or 'n'.
 * If the parameter is not specified in the string or there is no following
 * number, return -1.
 */
int get_shada_parameter(int type)
{
  char_u  *p;

  p = find_shada_parameter(type);
  if (p != NULL && ascii_isdigit(*p))
    return atoi((char *)p);
  return -1;
}

/*
 * Find the parameter represented by the given character (eg ''', ':', '"', or
 * '/') in the 'shada' option and return a pointer to the string after it.
 * Return NULL if the parameter is not specified in the string.
 */
char_u *find_shada_parameter(int type)
{
  char_u  *p;

  for (p = p_shada; *p; ++p) {
    if (*p == type)
      return p + 1;
    if (*p == 'n')                  /* 'n' is always the last one */
      break;
    p = vim_strchr(p, ',');         /* skip until next ',' */
    if (p == NULL)                  /* hit the end without finding parameter */
      break;
  }
  return NULL;
}

/*
 * Expand environment variables for some string options.
 * These string options cannot be indirect!
 * If "val" is NULL expand the current value of the option.
 * Return pointer to NameBuff, or NULL when not expanded.
 */
static char_u *option_expand(int opt_idx, char_u *val)
{
  /* if option doesn't need expansion nothing to do */
  if (!(options[opt_idx].flags & P_EXPAND) || options[opt_idx].var == NULL)
    return NULL;

  if (val == NULL) {
    val = *(char_u **)options[opt_idx].var;
  }

  // If val is longer than MAXPATHL no meaningful expansion can be done,
  // expand_env() would truncate the string.
  if (val == NULL || STRLEN(val) > MAXPATHL) {
    return NULL;
  }

  /*
   * Expanding this with NameBuff, expand_env() must not be passed IObuff.
   * Escape spaces when expanding 'tags', they are used to separate file
   * names.
   * For 'spellsuggest' expand after "file:".
   */
  expand_env_esc(val, NameBuff, MAXPATHL,
      (char_u **)options[opt_idx].var == &p_tags, FALSE,
      (char_u **)options[opt_idx].var == &p_sps ? (char_u *)"file:" :
      NULL);
  if (STRCMP(NameBuff, val) == 0)     /* they are the same */
    return NULL;

  return NameBuff;
}

/*
 * After setting various option values: recompute variables that depend on
 * option values.
 */
static void didset_options(void)
{
  /* initialize the table for 'iskeyword' et.al. */
  (void)init_chartab();

  (void)opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, true);
  (void)opt_strings_flags(p_bkc, p_bkc_values, &bkc_flags, true);
  (void)opt_strings_flags(p_bo, p_bo_values, &bo_flags, true);
  (void)opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true);
  (void)opt_strings_flags(p_vop, p_ssop_values, &vop_flags, true);
  (void)opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, true);
  (void)opt_strings_flags(p_dy, p_dy_values, &dy_flags, true);
  (void)opt_strings_flags(p_tc, p_tc_values, &tc_flags, false);
  (void)opt_strings_flags(p_ve, p_ve_values, &ve_flags, true);
  (void)spell_check_msm();
  (void)spell_check_sps();
  (void)compile_cap_prog(curwin->w_s);
  (void)did_set_spell_option(true);
  // set cedit_key
  (void)check_cedit();
  briopt_check(curwin);
  // initialize the table for 'breakat'.
  fill_breakat_flags();
}

// More side effects of setting options.
static void didset_options2(void)
{
  // Initialize the highlight_attr[] table.
  highlight_changed();

  // Parse default for 'clipboard'.
  (void)opt_strings_flags(p_cb, p_cb_values, &cb_flags, true);

  // Parse default for 'fillchars'.
  (void)set_chars_option(&p_fcs);

  // Parse default for 'listchars'.
  (void)set_chars_option(&p_lcs);

  // Parse default for 'wildmode'.
  check_opt_wim();
}

/*
 * Check for string options that are NULL (normally only termcap options).
 */
void check_options(void)
{
  int opt_idx;

  for (opt_idx = 0; options[opt_idx].fullname != NULL; opt_idx++)
    if ((options[opt_idx].flags & P_STRING) && options[opt_idx].var != NULL)
      check_string_option((char_u **)get_varp(&(options[opt_idx])));
}

/*
 * Check string options in a buffer for NULL value.
 */
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
  check_string_option(&buf->b_p_sua);
  check_string_option(&buf->b_p_cink);
  check_string_option(&buf->b_p_cino);
  parse_cino(buf);
  check_string_option(&buf->b_p_ft);
  check_string_option(&buf->b_p_cinw);
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
  check_string_option(&buf->b_p_tc);
  check_string_option(&buf->b_p_dict);
  check_string_option(&buf->b_p_tsr);
  check_string_option(&buf->b_p_lw);
  check_string_option(&buf->b_p_bkc);
  check_string_option(&buf->b_p_menc);
}

/*
 * Free the string allocated for an option.
 * Checks for the string being empty_option. This may happen if we're out of
 * memory, vim_strsave() returned NULL, which was replaced by empty_option by
 * check_options().
 * Does NOT check for P_ALLOCED flag!
 */
void free_string_option(char_u *p)
{
  if (p != empty_option)
    xfree(p);
}

void clear_string_option(char_u **pp)
{
  if (*pp != empty_option)
    xfree(*pp);
  *pp = empty_option;
}

static void check_string_option(char_u **pp)
{
  if (*pp == NULL)
    *pp = empty_option;
}

/*
 * Return TRUE when option "opt" was set from a modeline or in secure mode.
 * Return FALSE when it wasn't.
 * Return -1 for an unknown option.
 */
int was_set_insecurely(char_u *opt, int opt_flags)
{
  int idx = findoption((const char *)opt);

  if (idx >= 0) {
    uint32_t *flagp = insecure_flag(idx, opt_flags);
    return (*flagp & P_INSECURE) != 0;
  }
  internal_error("was_set_insecurely()");
  return -1;
}

/*
 * Get a pointer to the flags used for the P_INSECURE flag of option
 * "opt_idx".  For some local options a local flags field is used.
 */
static uint32_t *insecure_flag(int opt_idx, int opt_flags)
{
  if (opt_flags & OPT_LOCAL)
    switch ((int)options[opt_idx].indir) {
    case PV_STL:        return &curwin->w_p_stl_flags;
    case PV_FDE:        return &curwin->w_p_fde_flags;
    case PV_FDT:        return &curwin->w_p_fdt_flags;
    case PV_INDE:       return &curbuf->b_p_inde_flags;
    case PV_FEX:        return &curbuf->b_p_fex_flags;
    case PV_INEX:       return &curbuf->b_p_inex_flags;
    }

  /* Nothing special, return global flags field. */
  return &options[opt_idx].flags;
}


/*
 * Redraw the window title and/or tab page text later.
 */
static void redraw_titles(void) {
  need_maketitle = TRUE;
  redraw_tabline = TRUE;
}

static int shada_idx = -1;

/*
 * Set a string option to a new value (without checking the effect).
 * The string is copied into allocated memory.
 * if ("opt_idx" == -1) "name" is used, otherwise "opt_idx" is used.
 * When "set_sid" is zero set the scriptID to current_SID.  When "set_sid" is
 * SID_NONE don't set the scriptID.  Otherwise set the scriptID to "set_sid".
 */
void 
set_string_option_direct (
    char_u *name,
    int opt_idx,
    char_u *val,
    int opt_flags,                  /* OPT_FREE, OPT_LOCAL and/or OPT_GLOBAL */
    int set_sid
)
{
  char_u      *s;
  char_u      **varp;
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int idx = opt_idx;

  if (idx == -1) {  // Use name.
    idx = findoption((const char *)name);
    if (idx < 0) {  // Not found (should not happen).
      internal_error("set_string_option_direct()");
      IEMSG2(_("For option %s"), name);
      return;
    }
  }

  if (options[idx].var == NULL)         /* can't set hidden option */
    return;

  assert((void *) options[idx].var != (void *) &p_shada);

  s = vim_strsave(val);
  {
    varp = (char_u **)get_varp_scope(&(options[idx]),
        both ? OPT_LOCAL : opt_flags);
    if ((opt_flags & OPT_FREE) && (options[idx].flags & P_ALLOCED))
      free_string_option(*varp);
    *varp = s;

    /* For buffer/window local option may also set the global value. */
    if (both)
      set_string_option_global(idx, varp);

    options[idx].flags |= P_ALLOCED;

    /* When setting both values of a global option with a local value,
    * make the local value empty, so that the global value is used. */
    if (((int)options[idx].indir & PV_BOTH) && both) {
      free_string_option(*varp);
      *varp = empty_option;
    }
    if (set_sid != SID_NONE)
      set_option_scriptID_idx(idx, opt_flags,
          set_sid == 0 ? current_SID : set_sid);
  }
}

/*
 * Set global value for string option when it's a local option.
 */
static void 
set_string_option_global (
    int opt_idx,                    /* option index */
    char_u **varp             /* pointer to option variable */
)
{
  char_u      **p, *s;

  /* the global value is always allocated */
  if (options[opt_idx].var == VAR_WIN)
    p = (char_u **)GLOBAL_WO(varp);
  else
    p = (char_u **)options[opt_idx].var;
  if (options[opt_idx].indir != PV_NONE && p != varp) {
    s = vim_strsave(*varp);
    free_string_option(*p);
    *p = s;
  }
}

/// Set a string option to a new value, handling the effects
///
/// @param[in]  opt_idx  Option to set.
/// @param[in]  value  New value.
/// @param[in]  opt_flags  Option flags: expected to contain #OPT_LOCAL and/or
///                        #OPT_GLOBAL.
///
/// @return NULL on success, error message on error.
static char *set_string_option(const int opt_idx, const char *const value,
                               const int opt_flags)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (options[opt_idx].var == NULL) {  // don't set hidden option
    return NULL;
  }

  char *const s = xstrdup(value);
  char **const varp = (char **)get_varp_scope(
      &(options[opt_idx]),
      ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
       ? (((int)options[opt_idx].indir & PV_BOTH)
          ? OPT_GLOBAL : OPT_LOCAL)
       : opt_flags));
  char *const oldval = *varp;
  *varp = s;

  char *const saved_oldval = (starting ? NULL : xstrdup(oldval));

  char *const r = (char *)did_set_string_option(
      opt_idx, (char_u **)varp, (int)true, (char_u *)oldval, NULL, opt_flags);
  if (r == NULL) {
    did_set_option(opt_idx, opt_flags, true);
  }

  // call autocommand after handling side effects
  if (saved_oldval != NULL) {
    char buf_type[7];
    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_NEW, (char *)(*varp), -1);
    set_vim_var_string(VV_OPTION_OLD, saved_oldval, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    apply_autocmds(EVENT_OPTIONSET,
                   (char_u *)options[opt_idx].fullname,
                   NULL, false, NULL);
    reset_v_option_vars();
    xfree(saved_oldval);
    if (options[opt_idx].flags & P_UI_OPTION) {
      ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                         STRING_OBJ(cstr_as_string((char *)(*varp))));
    }
  }

  return r;
}

/// Return true if "val" is a valid 'filetype' name.
/// Also used for 'syntax' and 'keymap'.
static bool valid_filetype(char_u *val)
{
  for (char_u *s = val; *s != NUL; s++) {
    if (!ASCII_ISALNUM(*s) && vim_strchr((char_u *)".-_", *s) == NULL) {
      return false;
    }
  }
  return true;
}

/*
 * Handle string options that need some action to perform when changed.
 * Returns NULL for success, or an error message for an error.
 */
static char_u *
did_set_string_option (
    int opt_idx,                            /* index in options[] table */
    char_u **varp,                     /* pointer to the option variable */
    int new_value_alloced,                  /* new value was allocated */
    char_u *oldval,                    /* previous value of the option */
    char_u *errbuf,                    /* buffer for errors, or NULL */
    int opt_flags                          /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  char_u      *errmsg = NULL;
  char_u      *s, *p;
  int did_chartab = FALSE;
  char_u      **gvarp;
  bool free_oldval = (options[opt_idx].flags & P_ALLOCED);

  /* Get the global option to compare with, otherwise we would have to check
   * two values for all local options. */
  gvarp = (char_u **)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL);

  /* Disallow changing some options from secure mode */
  if ((secure || sandbox != 0)
      && (options[opt_idx].flags & P_SECURE)) {
    errmsg = e_secure;
  } else if (((options[opt_idx].flags & P_NFNAME)
              && vim_strpbrk(*varp, (char_u *)(secure ? "/\\*?[|;&<>\r\n"
                                               : "/\\*?[<>\r\n")) != NULL)
             || ((options[opt_idx].flags & P_NDNAME)
                 && vim_strpbrk(*varp, (char_u *)"*?[|;&<>\r\n") != NULL)) {
    // Check for a "normal" directory or file name in some options.  Disallow a
    // path separator (slash and/or backslash), wildcards and characters that
    // are often illegal in a file name. Be more permissive if "secure" is off.
    errmsg = e_invarg;
  }
  /* 'backupcopy' */
  else if (gvarp == &p_bkc) {
    char_u       *bkc   = p_bkc;
    unsigned int *flags = &bkc_flags;

    if (opt_flags & OPT_LOCAL) {
      bkc   = curbuf->b_p_bkc;
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
  }
  /* 'backupext' and 'patchmode' */
  else if (varp == &p_bex || varp == &p_pm) {
    if (STRCMP(*p_bex == '.' ? p_bex + 1 : p_bex,
            *p_pm == '.' ? p_pm + 1 : p_pm) == 0)
      errmsg = (char_u *)N_("E589: 'backupext' and 'patchmode' are equal");
  }
  /* 'breakindentopt' */
  else if (varp == &curwin->w_p_briopt) {
    if (briopt_check(curwin) == FAIL)
      errmsg = e_invarg;
  } else if (varp == &p_isi
             || varp == &(curbuf->b_p_isk)
             || varp == &p_isp
             || varp == &p_isf) {
    // 'isident', 'iskeyword', 'isprint or 'isfname' option: refill g_chartab[]
    // If the new option is invalid, use old value.  'lisp' option: refill
    // g_chartab[] for '-' char
    if (init_chartab() == FAIL) {
      did_chartab = TRUE;           /* need to restore it below */
      errmsg = e_invarg;            /* error in value */
    }
  }
  /* 'helpfile' */
  else if (varp == &p_hf) {
    /* May compute new values for $VIM and $VIMRUNTIME */
    if (didset_vim) {
      vim_setenv("VIM", "");
      didset_vim = FALSE;
    }
    if (didset_vimruntime) {
      vim_setenv("VIMRUNTIME", "");
      didset_vimruntime = FALSE;
    }
  }
  /* 'colorcolumn' */
  else if (varp == &curwin->w_p_cc)
    errmsg = check_colorcolumn(curwin);

  /* 'helplang' */
  else if (varp == &p_hlg) {
    /* Check for "", "ab", "ab,cd", etc. */
    for (s = p_hlg; *s != NUL; s += 3) {
      if (s[1] == NUL || ((s[2] != ',' || s[3] == NUL) && s[2] != NUL)) {
        errmsg = e_invarg;
        break;
      }
      if (s[2] == NUL)
        break;
    }
  } else if (varp == &p_hl) {
    // 'highlight'
    if (strcmp((char *)(*varp), HIGHLIGHT_INIT) != 0) {
      errmsg = e_unsupportedoption;
    }
  }
  /* 'nrformats' */
  else if (gvarp == &p_nf) {
    if (check_opt_strings(*varp, p_nf_values, TRUE) != OK)
      errmsg = e_invarg;
  } else if (varp == &p_ssop) {  // 'sessionoptions'
    if (opt_strings_flags(p_ssop, p_ssop_values, &ssop_flags, true) != OK)
      errmsg = e_invarg;
    if ((ssop_flags & SSOP_CURDIR) && (ssop_flags & SSOP_SESDIR)) {
      /* Don't allow both "sesdir" and "curdir". */
      (void)opt_strings_flags(oldval, p_ssop_values, &ssop_flags, true);
      errmsg = e_invarg;
    }
  } else if (varp == &p_vop) {  // 'viewoptions'
    if (opt_strings_flags(p_vop, p_ssop_values, &vop_flags, true) != OK)
      errmsg = e_invarg;
  }
  /* 'scrollopt' */
  else if (varp == &p_sbo) {
    if (check_opt_strings(p_sbo, p_scbopt_values, TRUE) != OK)
      errmsg = e_invarg;
  } else if (varp == &p_ambw || (int *)varp == &p_emoji) {
    // 'ambiwidth'
    if (check_opt_strings(p_ambw, p_ambw_values, false) != OK) {
      errmsg = e_invarg;
    } else if (set_chars_option(&p_lcs) != NULL) {
      errmsg = (char_u *)_("E834: Conflicts with value of 'listchars'");
    } else if (set_chars_option(&p_fcs) != NULL) {
      errmsg = (char_u *)_("E835: Conflicts with value of 'fillchars'");
    }
  }
  /* 'background' */
  else if (varp == &p_bg) {
    if (check_opt_strings(p_bg, p_bg_values, FALSE) == OK) {
      int dark = (*p_bg == 'd');

      init_highlight(FALSE, FALSE);

      if (dark != (*p_bg == 'd') && get_var_value("g:colors_name") != NULL) {
        // The color scheme must have set 'background' back to another
        // value, that's not what we want here.  Disable the color
        // scheme and set the colors again.
        do_unlet(S_LEN("g:colors_name"), true);
        free_string_option(p_bg);
        p_bg = vim_strsave((char_u *)(dark ? "dark" : "light"));
        check_string_option(&p_bg);
        init_highlight(FALSE, FALSE);
      }
    } else
      errmsg = e_invarg;
  }
  /* 'wildmode' */
  else if (varp == &p_wim) {
    if (check_opt_wim() == FAIL)
      errmsg = e_invarg;
  }
  /* 'wildoptions' */
  else if (varp == &p_wop) {
    if (check_opt_strings(p_wop, p_wop_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'winaltkeys' */
  else if (varp == &p_wak) {
    if (*p_wak == NUL
        || check_opt_strings(p_wak, p_wak_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* 'eventignore' */
  else if (varp == &p_ei) {
    if (check_ei() == FAIL)
      errmsg = e_invarg;
  // 'encoding', 'fileencoding' and 'makeencoding'
  } else if (varp == &p_enc || gvarp == &p_fenc || gvarp == &p_menc) {
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
      /* canonize the value, so that STRCMP() can be used on it */
      p = enc_canonize(*varp);
      xfree(*varp);
      *varp = p;
      if (varp == &p_enc) {
        // only encoding=utf-8 allowed
        if (STRCMP(p_enc, "utf-8") != 0) {
          errmsg = e_unsupportedoption;
        }
      }
    }
  } else if (varp == &p_penc) {
    /* Canonize printencoding if VIM standard one */
    p = enc_canonize(p_penc);
    xfree(p_penc);
    p_penc = p;
  } else if (varp == &curbuf->b_p_keymap) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    } else {
      // load or unload key mapping tables
      errmsg = keymap_init();
    }

    if (errmsg == NULL) {
      if (*curbuf->b_p_keymap != NUL) {
        /* Installed a new keymap, switch on using it. */
        curbuf->b_p_iminsert = B_IMODE_LMAP;
        if (curbuf->b_p_imsearch != B_IMODE_USE_INSERT)
          curbuf->b_p_imsearch = B_IMODE_LMAP;
      } else {
        /* Cleared the keymap, may reset 'iminsert' and 'imsearch'. */
        if (curbuf->b_p_iminsert == B_IMODE_LMAP)
          curbuf->b_p_iminsert = B_IMODE_NONE;
        if (curbuf->b_p_imsearch == B_IMODE_LMAP)
          curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
      }
      if ((opt_flags & OPT_LOCAL) == 0) {
        set_iminsert_global();
        set_imsearch_global();
      }
      status_redraw_curbuf();
    }
  }
  /* 'fileformat' */
  else if (gvarp == &p_ff) {
    if (!MODIFIABLE(curbuf) && !(opt_flags & OPT_GLOBAL))
      errmsg = e_modifiable;
    else if (check_opt_strings(*varp, p_ff_values, FALSE) != OK)
      errmsg = e_invarg;
    else {
      redraw_titles();
      /* update flag in swap file */
      ml_setflags(curbuf);
      /* Redraw needed when switching to/from "mac": a CR in the text
       * will be displayed differently. */
      if (get_fileformat(curbuf) == EOL_MAC || *oldval == 'm')
        redraw_curbuf_later(NOT_VALID);
    }
  }
  /* 'fileformats' */
  else if (varp == &p_ffs) {
    if (check_opt_strings(p_ffs, p_ff_values, TRUE) != OK) {
      errmsg = e_invarg;
    }
  }

  /* 'matchpairs' */
  else if (gvarp == &p_mps) {
    if (has_mbyte) {
      for (p = *varp; *p != NUL; ++p) {
        int x2 = -1;
        int x3 = -1;

        if (*p != NUL)
          p += mb_ptr2len(p);
        if (*p != NUL)
          x2 = *p++;
        if (*p != NUL) {
          x3 = mb_ptr2char(p);
          p += mb_ptr2len(p);
        }
        if (x2 != ':' || x3 == -1 || (*p != NUL && *p != ',')) {
          errmsg = e_invarg;
          break;
        }
        if (*p == NUL)
          break;
      }
    } else {
      /* Check for "x:y,x:y" */
      for (p = *varp; *p != NUL; p += 4) {
        if (p[1] != ':' || p[2] == NUL || (p[3] != NUL && p[3] != ',')) {
          errmsg = e_invarg;
          break;
        }
        if (p[3] == NUL)
          break;
      }
    }
  }
  /* 'comments' */
  else if (gvarp == &p_com) {
    for (s = *varp; *s; ) {
      while (*s && *s != ':') {
        if (vim_strchr((char_u *)COM_ALL, *s) == NULL
            && !ascii_isdigit(*s) && *s != '-') {
          errmsg = illegal_char(errbuf, *s);
          break;
        }
        ++s;
      }
      if (*s++ == NUL)
        errmsg = (char_u *)N_("E524: Missing colon");
      else if (*s == ',' || *s == NUL)
        errmsg = (char_u *)N_("E525: Zero length string");
      if (errmsg != NULL)
        break;
      while (*s && *s != ',') {
        if (*s == '\\' && s[1] != NUL)
          ++s;
        ++s;
      }
      s = skip_to_option_part(s);
    }
  }
  /* 'listchars' */
  else if (varp == &p_lcs) {
    errmsg = set_chars_option(varp);
  }
  /* 'fillchars' */
  else if (varp == &p_fcs) {
    errmsg = set_chars_option(varp);
  }
  /* 'cedit' */
  else if (varp == &p_cedit) {
    errmsg = check_cedit();
  }
  /* 'verbosefile' */
  else if (varp == &p_vfile) {
    verbose_stop();
    if (*p_vfile != NUL && verbose_open() == FAIL)
      errmsg = e_invarg;
  /* 'shada' */
  } else if (varp == &p_shada) {
    // TODO(ZyX-I): Remove this code in the future, alongside with &viminfo
    //              option.
    opt_idx = ((options[opt_idx].fullname[0] == 'v')
               ? (shada_idx == -1
                  ? ((shada_idx = findoption("shada")))
                  : shada_idx)
               : opt_idx);
    // Update free_oldval now that we have the opt_idx for 'shada', otherwise
    // there would be a disconnect between the check for P_ALLOCED at the start
    // of the function and the set of P_ALLOCED at the end of the fuction.
    free_oldval = (options[opt_idx].flags & P_ALLOCED);
    for (s = p_shada; *s; ) {
      /* Check it's a valid character */
      if (vim_strchr((char_u *)"!\"%'/:<@cfhnrs", *s) == NULL) {
        errmsg = illegal_char(errbuf, *s);
        break;
      }
      if (*s == 'n') {          /* name is always last one */
        break;
      } else if (*s == 'r') { /* skip until next ',' */
        while (*++s && *s != ',')
          ;
      } else if (*s == '%') {
        /* optional number */
        while (ascii_isdigit(*++s))
          ;
      } else if (*s == '!' || *s == 'h' || *s == 'c')
        ++s;                    /* no extra chars */
      else {                    /* must have a number */
        while (ascii_isdigit(*++s))
          ;

        if (!ascii_isdigit(*(s - 1))) {
          if (errbuf != NULL) {
            sprintf((char *)errbuf,
                _("E526: Missing number after <%s>"),
                transchar_byte(*(s - 1)));
            errmsg = errbuf;
          } else
            errmsg = (char_u *)"";
          break;
        }
      }
      if (*s == ',')
        ++s;
      else if (*s) {
        if (errbuf != NULL)
          errmsg = (char_u *)N_("E527: Missing comma");
        else
          errmsg = (char_u *)"";
        break;
      }
    }
    if (*p_shada && errmsg == NULL && get_shada_parameter('\'') < 0)
      errmsg = (char_u *)N_("E528: Must specify a ' value");
  }
  /* 'showbreak' */
  else if (varp == &p_sbr) {
    for (s = p_sbr; *s; ) {
      if (ptr2cells(s) != 1)
        errmsg = (char_u *)N_("E595: contains unprintable or wide character");
      mb_ptr_adv(s);
    }
  }

  // 'guicursor'
  else if (varp == &p_guicursor) {
    errmsg = parse_shape_opt(SHAPE_CURSOR);
  }

  else if (varp == &p_popt)
    errmsg = parse_printoptions();
  else if (varp == &p_pmfn)
    errmsg = parse_printmbfont();

  /* 'langmap' */
  else if (varp == &p_langmap)
    langmap_set();

  /* 'breakat' */
  else if (varp == &p_breakat)
    fill_breakat_flags();

  /* 'titlestring' and 'iconstring' */
  else if (varp == &p_titlestring || varp == &p_iconstring) {
    int flagval = (varp == &p_titlestring) ? STL_IN_TITLE : STL_IN_ICON;

    /* NULL => statusline syntax */
    if (vim_strchr(*varp, '%') && check_stl_option(*varp) == NULL)
      stl_syntax |= flagval;
    else
      stl_syntax &= ~flagval;
    did_set_title(varp == &p_iconstring);

  }

  /* 'selection' */
  else if (varp == &p_sel) {
    if (*p_sel == NUL
        || check_opt_strings(p_sel, p_sel_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* 'selectmode' */
  else if (varp == &p_slm) {
    if (check_opt_strings(p_slm, p_slm_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'keymodel' */
  else if (varp == &p_km) {
    if (check_opt_strings(p_km, p_km_values, TRUE) != OK)
      errmsg = e_invarg;
    else {
      km_stopsel = (vim_strchr(p_km, 'o') != NULL);
      km_startsel = (vim_strchr(p_km, 'a') != NULL);
    }
  }
  /* 'mousemodel' */
  else if (varp == &p_mousem) {
    if (check_opt_strings(p_mousem, p_mousem_values, FALSE) != OK)
      errmsg = e_invarg;
  } else if (varp == &p_swb) {  // 'switchbuf'
    if (opt_strings_flags(p_swb, p_swb_values, &swb_flags, true) != OK)
      errmsg = e_invarg;
  }
  /* 'debug' */
  else if (varp == &p_debug) {
    if (check_opt_strings(p_debug, p_debug_values, TRUE) != OK)
      errmsg = e_invarg;
  } else if (varp == &p_dy) {  // 'display'
    if (opt_strings_flags(p_dy, p_dy_values, &dy_flags, true) != OK)
      errmsg = e_invarg;
    else
      (void)init_chartab();

  }
  /* 'eadirection' */
  else if (varp == &p_ead) {
    if (check_opt_strings(p_ead, p_ead_values, FALSE) != OK)
      errmsg = e_invarg;
  } else if (varp == &p_cb) {  // 'clipboard'
    if (opt_strings_flags(p_cb, p_cb_values, &cb_flags, true) != OK) {
      errmsg = e_invarg;
    }
  } else if (varp == &(curwin->w_s->b_p_spl)  // 'spell'
             || varp == &(curwin->w_s->b_p_spf)) {
    // When 'spelllang' or 'spellfile' is set and there is a window for this
    // buffer in which 'spell' is set load the wordlists.
    errmsg = did_set_spell_option(varp == &(curwin->w_s->b_p_spf));
  }
  /* When 'spellcapcheck' is set compile the regexp program. */
  else if (varp == &(curwin->w_s->b_p_spc)) {
    errmsg = compile_cap_prog(curwin->w_s);
  }
  /* 'spellsuggest' */
  else if (varp == &p_sps) {
    if (spell_check_sps() != OK)
      errmsg = e_invarg;
  }
  /* 'mkspellmem' */
  else if (varp == &p_msm) {
    if (spell_check_msm() != OK)
      errmsg = e_invarg;
  }
  /* When 'bufhidden' is set, check for valid value. */
  else if (gvarp == &p_bh) {
    if (check_opt_strings(curbuf->b_p_bh, p_bufhidden_values, FALSE) != OK)
      errmsg = e_invarg;
  }
  /* When 'buftype' is set, check for valid value. */
  else if (gvarp == &p_bt) {
    if ((curbuf->terminal && curbuf->b_p_bt[0] != 't')
        || (!curbuf->terminal && curbuf->b_p_bt[0] == 't')
        || check_opt_strings(curbuf->b_p_bt, p_buftype_values, FALSE) != OK) {
      errmsg = e_invarg;
    } else {
      if (curwin->w_status_height) {
        curwin->w_redr_status = TRUE;
        redraw_later(VALID);
      }
      curbuf->b_help = (curbuf->b_p_bt[0] == 'h');
      redraw_titles();
    }
  }
  /* 'statusline' or 'rulerformat' */
  else if (gvarp == &p_stl || varp == &p_ruf) {
    int wid;

    if (varp == &p_ruf)         /* reset ru_wid first */
      ru_wid = 0;
    s = *varp;
    if (varp == &p_ruf && *s == '%') {
      /* set ru_wid if 'ruf' starts with "%99(" */
      if (*++s == '-')          /* ignore a '-' */
        s++;
      wid = getdigits_int(&s);
      if (wid && *s == '(' && (errmsg = check_stl_option(p_ruf)) == NULL)
        ru_wid = wid;
      else
        errmsg = check_stl_option(p_ruf);
    }
    /* check 'statusline' only if it doesn't start with "%!" */
    else if (varp == &p_ruf || s[0] != '%' || s[1] != '!')
      errmsg = check_stl_option(s);
    if (varp == &p_ruf && errmsg == NULL)
      comp_col();
  }
  /* check if it is a valid value for 'complete' -- Acevedo */
  else if (gvarp == &p_cpt) {
    for (s = *varp; *s; ) {
      while (*s == ',' || *s == ' ')
        s++;
      if (!*s)
        break;
      if (vim_strchr((char_u *)".wbuksid]tU", *s) == NULL) {
        errmsg = illegal_char(errbuf, *s);
        break;
      }
      if (*++s != NUL && *s != ',' && *s != ' ') {
        if (s[-1] == 'k' || s[-1] == 's') {
          /* skip optional filename after 'k' and 's' */
          while (*s && *s != ',' && *s != ' ') {
            if (*s == '\\' && s[1] != NUL) {
              s++;
            }
            s++;
          }
        } else {
          if (errbuf != NULL) {
            sprintf((char *)errbuf,
                _("E535: Illegal character after <%c>"),
                *--s);
            errmsg = errbuf;
          } else
            errmsg = (char_u *)"";
          break;
        }
      }
    }
  }
  /* 'completeopt' */
  else if (varp == &p_cot) {
    if (check_opt_strings(p_cot, p_cot_values, true) != OK) {
      errmsg = e_invarg;
    } else {
      completeopt_was_set();
    }
  } else if (varp == &curwin->w_p_scl) {
    // 'signcolumn'
    if (check_opt_strings(*varp, p_scl_values, false) != OK) {
      errmsg = e_invarg;
    }
  }
  /* 'pastetoggle': translate key codes like in a mapping */
  else if (varp == &p_pt) {
    if (*p_pt) {
      (void)replace_termcodes(p_pt, STRLEN(p_pt), &p, true, true, true,
                              CPO_TO_CPO_FLAGS);
      if (p != NULL) {
        if (new_value_alloced)
          free_string_option(p_pt);
        p_pt = p;
        new_value_alloced = TRUE;
      }
    }
  }
  /* 'backspace' */
  else if (varp == &p_bs) {
    if (ascii_isdigit(*p_bs)) {
      if (*p_bs >'2' || p_bs[1] != NUL)
        errmsg = e_invarg;
    } else if (check_opt_strings(p_bs, p_bs_values, TRUE) != OK)
      errmsg = e_invarg;
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
    if (opt_strings_flags(p_cmp, p_cmp_values, &cmp_flags, true) != OK)
      errmsg = e_invarg;
  }
  /* 'diffopt' */
  else if (varp == &p_dip) {
    if (diffopt_changed() == FAIL)
      errmsg = e_invarg;
  }
  /* 'foldmethod' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fdm) {
    if (check_opt_strings(*varp, p_fdm_values, FALSE) != OK
        || *curwin->w_p_fdm == NUL)
      errmsg = e_invarg;
    else {
      foldUpdateAll(curwin);
      if (foldmethodIsDiff(curwin))
        newFoldLevel();
    }
  }
  /* 'foldexpr' */
  else if (varp == &curwin->w_p_fde) {
    if (foldmethodIsExpr(curwin))
      foldUpdateAll(curwin);
  }
  /* 'foldmarker' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fmr) {
    p = vim_strchr(*varp, ',');
    if (p == NULL)
      errmsg = (char_u *)N_("E536: comma required");
    else if (p == *varp || p[1] == NUL)
      errmsg = e_invarg;
    else if (foldmethodIsMarker(curwin))
      foldUpdateAll(curwin);
  }
  /* 'commentstring' */
  else if (gvarp == &p_cms) {
    if (**varp != NUL && strstr((char *)*varp, "%s") == NULL)
      errmsg = (char_u *)N_(
                "E537: 'commentstring' must be empty or contain %s");
  } else if (varp == &p_fdo) {  // 'foldopen'
    if (opt_strings_flags(p_fdo, p_fdo_values, &fdo_flags, true) != OK)
      errmsg = e_invarg;
  }
  /* 'foldclose' */
  else if (varp == &p_fcl) {
    if (check_opt_strings(p_fcl, p_fcl_values, TRUE) != OK)
      errmsg = e_invarg;
  }
  /* 'foldignore' */
  else if (gvarp == &curwin->w_allbuf_opt.wo_fdi) {
    if (foldmethodIsIndent(curwin))
      foldUpdateAll(curwin);
  } else if (varp == &p_ve) {  // 'virtualedit'
    if (opt_strings_flags(p_ve, p_ve_values, &ve_flags, true) != OK)
      errmsg = e_invarg;
    else if (STRCMP(p_ve, oldval) != 0) {
      /* Recompute cursor position in case the new 've' setting
       * changes something. */
      validate_virtcol();
      coladvance(curwin->w_virtcol);
    }
  } else if (varp == &p_csqf) {
    if (p_csqf != NULL) {
      p = p_csqf;
      while (*p != NUL) {
        if (vim_strchr((char_u *)CSQF_CMDS, *p) == NULL
            || p[1] == NUL
            || vim_strchr((char_u *)CSQF_FLAGS, p[1]) == NULL
            || (p[2] != NUL && p[2] != ',')) {
          errmsg = e_invarg;
          break;
        } else if (p[2] == NUL)
          break;
        else
          p += 3;
      }
    }
  }
  /* 'cinoptions' */
  else if (gvarp == &p_cino) {
    /* TODO: recognize errors */
    parse_cino(curbuf);
  // inccommand
  } else if (varp == &p_icm) {
      if (check_opt_strings(p_icm, p_icm_values, false) != OK) {
        errmsg = e_invarg;
      }
  } else if (gvarp == &p_ft) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    }
  } else if (gvarp == &p_syn) {
    if (!valid_filetype(*varp)) {
      errmsg = e_invarg;
    }
  } else if (varp == &curwin->w_p_winhl) {
    if (!parse_winhl_opt(curwin)) {
      errmsg = e_invarg;
    }
  } else {
    // Options that are a list of flags.
    p = NULL;
    if (varp == &p_ww) {  // 'whichwrap'
      p = (char_u *)WW_ALL;
    }
    if (varp == &p_shm) {  // 'shortmess'
      p = (char_u *)SHM_ALL;
    } else if (varp == &(p_cpo)) {  // 'cpoptions'
      p = (char_u *)CPO_VI;
    } else if (varp == &(curbuf->b_p_fo)) {  // 'formatoptions'
      p = (char_u *)FO_ALL;
    } else if (varp == &curwin->w_p_cocu) {  // 'concealcursor'
      p = (char_u *)COCU_ALL;
    } else if (varp == &p_mouse) {  // 'mouse'
      p = (char_u *)MOUSE_ALL;
    }
    if (p != NULL) {
      for (s = *varp; *s; ++s)
        if (vim_strchr(p, *s) == NULL) {
          errmsg = illegal_char(errbuf, *s);
          break;
        }
    }
  }

  /*
   * If error detected, restore the previous value.
   */
  if (errmsg != NULL) {
    if (new_value_alloced)
      free_string_option(*varp);
    *varp = oldval;
    /*
     * When resetting some values, need to act on it.
     */
    if (did_chartab)
      (void)init_chartab();
  } else {
    /* Remember where the option was set. */
    set_option_scriptID_idx(opt_idx, opt_flags, current_SID);
    /*
     * Free string options that are in allocated memory.
     * Use "free_oldval", because recursiveness may change the flags under
     * our fingers (esp. init_highlight()).
     */
    if (free_oldval)
      free_string_option(oldval);
    if (new_value_alloced)
      options[opt_idx].flags |= P_ALLOCED;
    else
      options[opt_idx].flags &= ~P_ALLOCED;

    if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0
        && ((int)options[opt_idx].indir & PV_BOTH)) {
      /* global option with local value set to use global value; free
       * the local value and make it empty */
      p = get_varp_scope(&(options[opt_idx]), OPT_LOCAL);
      free_string_option(*(char_u **)p);
      *(char_u **)p = empty_option;
    }
    /* May set global value for local option. */
    else if (!(opt_flags & OPT_LOCAL) && opt_flags != OPT_GLOBAL)
      set_string_option_global(opt_idx, varp);

    /*
     * Trigger the autocommand only after setting the flags.
     */
    /* When 'syntax' is set, load the syntax of that name */
    if (varp == &(curbuf->b_p_syn)) {
      apply_autocmds(EVENT_SYNTAX, curbuf->b_p_syn,
          curbuf->b_fname, TRUE, curbuf);
    } else if (varp == &(curbuf->b_p_ft)) {
      /* 'filetype' is set, trigger the FileType autocommand */
      did_filetype = TRUE;
      apply_autocmds(EVENT_FILETYPE, curbuf->b_p_ft,
          curbuf->b_fname, TRUE, curbuf);
    }
    if (varp == &(curwin->w_s->b_p_spl)) {
      char_u fname[200];
      char_u      *q = curwin->w_s->b_p_spl;

      /* Skip the first name if it is "cjk". */
      if (STRNCMP(q, "cjk,", 4) == 0)
        q += 4;

      /*
       * Source the spell/LANG.vim in 'runtimepath'.
       * They could set 'spellcapcheck' depending on the language.
       * Use the first name in 'spelllang' up to '_region' or
       * '.encoding'.
       */
      for (p = q; *p != NUL; ++p)
        if (vim_strchr((char_u *)"_.,", *p) != NULL)
          break;
      vim_snprintf((char *)fname, sizeof(fname), "spell/%.*s.vim",
                   (int)(p - q), q);
      source_runtime(fname, DIP_ALL);
    }
  }

  if (varp == &p_mouse) {
    if (*p_mouse == NUL) {
      ui_call_mouse_off();
    } else {
      setmouse();  // in case 'mouse' changed
    }
  }

  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RALL)) != 0)
    curwin->w_set_curswant = TRUE;

  check_redraw(options[opt_idx].flags);

  return errmsg;
}

/*
 * Simple int comparison function for use with qsort()
 */
static int int_cmp(const void *a, const void *b)
{
  return *(const int *)a - *(const int *)b;
}

/*
 * Handle setting 'colorcolumn' or 'textwidth' in window "wp".
 * Returns error message, NULL if it's OK.
 */
char_u *check_colorcolumn(win_T *wp)
{
  char_u      *s;
  int col;
  unsigned int count = 0;
  int color_cols[256];
  int j = 0;

  if (wp->w_buffer == NULL)
    return NULL;      /* buffer was closed */

  for (s = wp->w_p_cc; *s != NUL && count < 255; ) {
    if (*s == '-' || *s == '+') {
      /* -N and +N: add to 'textwidth' */
      col = (*s == '-') ? -1 : 1;
      ++s;
      if (!ascii_isdigit(*s))
        return e_invarg;
      col = col * getdigits_int(&s);
      if (wp->w_buffer->b_p_tw == 0)
        goto skip;          /* 'textwidth' not set, skip this item */
      assert((col >= 0
              && wp->w_buffer->b_p_tw <= INT_MAX - col
              && wp->w_buffer->b_p_tw + col >= INT_MIN)
             || (col < 0
                 && wp->w_buffer->b_p_tw >= INT_MIN - col
                 && wp->w_buffer->b_p_tw + col <= INT_MAX));
      col += (int)wp->w_buffer->b_p_tw;
      if (col < 0)
        goto skip;
    } else if (ascii_isdigit(*s))
      col = getdigits_int(&s);
    else
      return e_invarg;
    color_cols[count++] = col - 1;      /* 1-based to 0-based */
skip:
    if (*s == NUL)
      break;
    if (*s != ',')
      return e_invarg;
    if (*++s == NUL)
      return e_invarg;        /* illegal trailing comma as in "set cc=80," */
  }

  xfree(wp->w_p_cc_cols);
  if (count == 0)
    wp->w_p_cc_cols = NULL;
  else {
    wp->w_p_cc_cols = xmalloc(sizeof(int) * (count + 1));
    /* sort the columns for faster usage on screen redraw inside
     * win_line() */
    qsort(color_cols, count, sizeof(int), int_cmp);

    for (unsigned int i = 0; i < count; ++i)
      /* skip duplicates */
      if (j == 0 || wp->w_p_cc_cols[j - 1] != color_cols[i])
        wp->w_p_cc_cols[j++] = color_cols[i];
    wp->w_p_cc_cols[j] = -1;        /* end marker */
  }

  return NULL;    /* no error */
}

/*
 * Handle setting 'listchars' or 'fillchars'.
 * Returns error message, NULL if it's OK.
 */
static char_u *set_chars_option(char_u **varp)
{
  int round, i, len, entries;
  char_u      *p, *s;
  int c1, c2 = 0;
  struct charstab {
    int     *cp;
    char    *name;
  };
  static struct charstab filltab[] =
  {
    {&fill_stl,     "stl"},
    {&fill_stlnc,   "stlnc"},
    {&fill_vert,    "vert"},
    {&fill_fold,    "fold"},
    {&fill_diff,    "diff"},
  };
  static struct charstab lcstab[] =
  {
    {&lcs_eol,      "eol"},
    {&lcs_ext,      "extends"},
    {&lcs_nbsp,     "nbsp"},
    {&lcs_prec,     "precedes"},
    {&lcs_space,    "space"},
    {&lcs_tab2,     "tab"},
    {&lcs_trail,    "trail"},
    {&lcs_conceal,  "conceal"},
  };
  struct charstab *tab;

  if (varp == &p_lcs) {
    tab = lcstab;
    entries = ARRAY_SIZE(lcstab);
  } else {
    tab = filltab;
    entries = ARRAY_SIZE(filltab);
  }

  /* first round: check for valid value, second round: assign values */
  for (round = 0; round <= 1; ++round) {
    if (round > 0) {
      /* After checking that the value is valid: set defaults: space for
       * 'fillchars', NUL for 'listchars' */
      for (i = 0; i < entries; ++i)
        if (tab[i].cp != NULL)
          *(tab[i].cp) = (varp == &p_lcs ? NUL : ' ');
      if (varp == &p_lcs)
        lcs_tab1 = NUL;
      else
        fill_diff = '-';
    }
    p = *varp;
    while (*p) {
      for (i = 0; i < entries; ++i) {
        len = (int)STRLEN(tab[i].name);
        if (STRNCMP(p, tab[i].name, len) == 0
            && p[len] == ':'
            && p[len + 1] != NUL) {
          s = p + len + 1;
          c1 = mb_ptr2char_adv((const char_u **)&s);
          if (mb_char2cells(c1) > 1) {
            continue;
          }
          if (tab[i].cp == &lcs_tab2) {
            if (*s == NUL) {
              continue;
            }
            c2 = mb_ptr2char_adv((const char_u **)&s);
            if (mb_char2cells(c2) > 1) {
              continue;
            }
          }
          if (*s == ',' || *s == NUL) {
            if (round) {
              if (tab[i].cp == &lcs_tab2) {
                lcs_tab1 = c1;
                lcs_tab2 = c2;
              } else if (tab[i].cp != NULL)
                *(tab[i].cp) = c1;

            }
            p = s;
            break;
          }
        }
      }

      if (i == entries)
        return e_invarg;
      if (*p == ',')
        ++p;
    }
  }

  return NULL;          /* no error */
}

/*
 * Check validity of options with the 'statusline' format.
 * Return error message or NULL.
 */
char_u *check_stl_option(char_u *s)
{
  int itemcnt = 0;
  int groupdepth = 0;
  static char_u errbuf[80];

  while (*s && itemcnt < STL_MAX_ITEM) {
    /* Check for valid keys after % sequences */
    while (*s && *s != '%')
      s++;
    if (!*s)
      break;
    s++;
    if (*s != '%' && *s != ')') {
      itemcnt++;
    }
    if (*s == '%' || *s == STL_TRUNCMARK || *s == STL_SEPARATE) {
      s++;
      continue;
    }
    if (*s == ')') {
      s++;
      if (--groupdepth < 0)
        break;
      continue;
    }
    if (*s == '-')
      s++;
    while (ascii_isdigit(*s))
      s++;
    if (*s == STL_USER_HL)
      continue;
    if (*s == '.') {
      s++;
      while (*s && ascii_isdigit(*s))
        s++;
    }
    if (*s == '(') {
      groupdepth++;
      continue;
    }
    if (vim_strchr(STL_ALL, *s) == NULL) {
      return illegal_char(errbuf, *s);
    }
    if (*s == '{') {
      s++;
      while (*s != '}' && *s)
        s++;
      if (*s != '}')
        return (char_u *)N_("E540: Unclosed expression sequence");
    }
  }
  if (itemcnt >= STL_MAX_ITEM)
    return (char_u *)N_("E541: too many items");
  if (groupdepth != 0)
    return (char_u *)N_("E542: unbalanced groups");
  return NULL;
}

static char_u *did_set_spell_option(bool is_spellfile)
{
  char_u  *errmsg = NULL;

  if (is_spellfile) {
    int l = (int)STRLEN(curwin->w_s->b_p_spf);
    if (l > 0
        && (l < 4 || STRCMP(curwin->w_s->b_p_spf + l - 4, ".add") != 0)) {
      errmsg = e_invarg;
    }
  }

  if (errmsg == NULL) {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == curbuf && wp->w_p_spell) {
        errmsg = did_set_spelllang(wp);
        break;
      }
    }
  }

  return errmsg;
}

/*
 * Set curbuf->b_cap_prog to the regexp program for 'spellcapcheck'.
 * Return error message when failed, NULL when OK.
 */
static char_u *compile_cap_prog(synblock_T *synblock)
{
  regprog_T   *rp = synblock->b_cap_prog;
  char_u      *re;

  if (*synblock->b_p_spc == NUL)
    synblock->b_cap_prog = NULL;
  else {
    /* Prepend a ^ so that we only match at one column */
    re = concat_str((char_u *)"^", synblock->b_p_spc);
    synblock->b_cap_prog = vim_regcomp(re, RE_MAGIC);
    xfree(re);
    if (synblock->b_cap_prog == NULL) {
      synblock->b_cap_prog = rp;         /* restore the previous program */
      return e_invarg;
    }
  }

  vim_regfree(rp);
  return NULL;
}

/// Handle setting `winhighlight' in window "wp"
static bool parse_winhl_opt(win_T *wp)
{
  int w_hl_id_normal = 0;
  int w_hl_ids[HLF_COUNT] = { 0 };
  int hlf;

  const char *p = (const char *)wp->w_p_winhl;
  while (*p) {
    char *colon = strchr(p, ':');
    if (!colon) {
      return false;
    }
    size_t nlen = (size_t)(colon-p);
    char *hi = colon+1;
    char *commap = xstrchrnul(hi, ',');
    int hl_id = syn_check_group((char_u *)hi, (int)(commap-hi));

    if (strncmp("Normal", p, nlen) == 0) {
      w_hl_id_normal = hl_id;
    } else {
      for (hlf = 0; hlf < (int)HLF_COUNT; hlf++) {
        if (strncmp(hlf_names[hlf], p, nlen) == 0) {
          w_hl_ids[hlf] = hl_id;
          break;
        }
      }
      if (hlf == HLF_COUNT) {
        return false;
      }
    }

    p = *commap ? commap+1 : "";
  }

  wp->w_hl_id_normal = w_hl_id_normal;
  memcpy(wp->w_hl_ids, w_hl_ids, sizeof(w_hl_ids));
  wp->w_hl_needs_update = true;
  return true;
}

/*
 * Set the scriptID for an option, taking care of setting the buffer- or
 * window-local value.
 */
static void set_option_scriptID_idx(int opt_idx, int opt_flags, int id)
{
  int both = (opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0;
  int indir = (int)options[opt_idx].indir;

  /* Remember where the option was set.  For local options need to do that
   * in the buffer or window structure. */
  if (both || (opt_flags & OPT_GLOBAL) || (indir & (PV_BUF|PV_WIN)) == 0)
    options[opt_idx].scriptID = id;
  if (both || (opt_flags & OPT_LOCAL)) {
    if (indir & PV_BUF)
      curbuf->b_p_scriptID[indir & PV_MASK] = id;
    else if (indir & PV_WIN)
      curwin->w_p_scriptID[indir & PV_MASK] = id;
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
static char *set_bool_option(const int opt_idx, char_u *const varp,
                             const int value,
                             const int opt_flags)
{
  int old_value = *(int *)varp;

  /* Disallow changing some options from secure mode */
  if ((secure || sandbox != 0)
      && (options[opt_idx].flags & P_SECURE)) {
    return (char *)e_secure;
  }

  *(int *)varp = value;             /* set the new value */
  /* Remember where the option was set. */
  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);


  /* May set global value for local option. */
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0)
    *(int *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = value;

  // Ensure that options set to p_force_on cannot be disabled.
  if ((int *)varp == &p_force_on && p_force_on == false) {
    p_force_on = true;
    return (char *)e_unsupportedoption;
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
  // 'undofile'
  } else if ((int *)varp == &curbuf->b_p_udf || (int *)varp == &p_udf) {
    // Only take action when the option was set. When reset we do not
    // delete the undo file, the option may be set again without making
    // any changes in between.
    if (curbuf->b_p_udf || p_udf) {
      char_u hash[UNDO_HASH_SIZE];
      buf_T       *save_curbuf = curbuf;

      FOR_ALL_BUFFERS(bp) {
        curbuf = bp;
        // When 'undofile' is set globally: for every buffer, otherwise
        // only for the current buffer: Try to read in the undofile,
        // if one exists, the buffer wasn't changed and the buffer was
        // loaded
        if ((curbuf == save_curbuf
             || (opt_flags & OPT_GLOBAL) || opt_flags == 0)
            && !curbufIsChanged() && curbuf->b_ml.ml_mfp != NULL) {
          u_compute_hash(hash);
          u_read_undo(NULL, hash, curbuf->b_fname);
        }
      }
      curbuf = save_curbuf;
    }
  } else if ((int *)varp == &curbuf->b_p_ro) {
    /* when 'readonly' is reset globally, also reset readonlymode */
    if (!curbuf->b_p_ro && (opt_flags & OPT_LOCAL) == 0)
      readonlymode = FALSE;

    /* when 'readonly' is set may give W10 again */
    if (curbuf->b_p_ro)
      curbuf->b_did_warn = false;

    redraw_titles();
  }
  /* when 'modifiable' is changed, redraw the window title */
  else if ((int *)varp == &curbuf->b_p_ma) {
    redraw_titles();
  }
  /* when 'endofline' is changed, redraw the window title */
  else if ((int *)varp == &curbuf->b_p_eol) {
    redraw_titles();
  } else if ((int *)varp == &curbuf->b_p_fixeol) {
    // when 'fixeol' is changed, redraw the window title
    redraw_titles();
  }
  /* when 'bomb' is changed, redraw the window title and tab page text */
  else if ((int *)varp == &curbuf->b_p_bomb) {
    redraw_titles();
  }
  /* when 'bin' is set also set some other options */
  else if ((int *)varp == &curbuf->b_p_bin) {
    set_options_bin(old_value, curbuf->b_p_bin, opt_flags);
    redraw_titles();
  }
  /* when 'buflisted' changes, trigger autocommands */
  else if ((int *)varp == &curbuf->b_p_bl && old_value != curbuf->b_p_bl) {
    apply_autocmds(curbuf->b_p_bl ? EVENT_BUFADD : EVENT_BUFDELETE,
        NULL, NULL, TRUE, curbuf);
  }
  /* when 'swf' is set, create swapfile, when reset remove swapfile */
  else if ((int *)varp == (int *)&curbuf->b_p_swf) {
    if (curbuf->b_p_swf && p_uc)
      ml_open_file(curbuf);                     /* create the swap file */
    else
      /* no need to reset curbuf->b_may_swap, ml_open_file() will check
       * buf->b_p_swf */
      mf_close_file(curbuf, true);              /* remove the swap file */
  }
  /* when 'terse' is set change 'shortmess' */
  else if ((int *)varp == &p_terse) {
    char_u  *p;

    p = vim_strchr(p_shm, SHM_SEARCH);

    /* insert 's' in p_shm */
    if (p_terse && p == NULL) {
      STRCPY(IObuff, p_shm);
      STRCAT(IObuff, "s");
      set_string_option_direct((char_u *)"shm", -1, IObuff, OPT_FREE, 0);
    }
    /* remove 's' from p_shm */
    else if (!p_terse && p != NULL)
      STRMOVE(p, p + 1);
  }
  /* when 'paste' is set or reset also change other options */
  else if ((int *)varp == &p_paste) {
    paste_option_changed();
  }
  /* when 'insertmode' is set from an autocommand need to do work here */
  else if ((int *)varp == &p_im) {
    if (p_im) {
      if ((State & INSERT) == 0) {
        need_start_insertmode = true;
      }
      stop_insert_mode = false;
    } else if (old_value) {  // only reset if it was set previously
      need_start_insertmode = false;
      stop_insert_mode = true;
      if (restart_edit != 0 && mode_displayed) {
        clear_cmdline = true;  // remove "(insert)"
      }
      restart_edit = 0;
    }
  }
  /* when 'ignorecase' is set or reset and 'hlsearch' is set, redraw */
  else if ((int *)varp == &p_ic && p_hls) {
    redraw_all_later(SOME_VALID);
  }
  /* when 'hlsearch' is set or reset: reset no_hlsearch */
  else if ((int *)varp == &p_hls) {
    SET_NO_HLSEARCH(FALSE);
  }
  /* when 'scrollbind' is set: snapshot the current position to avoid a jump
   * at the end of normal_cmd() */
  else if ((int *)varp == &curwin->w_p_scb) {
    if (curwin->w_p_scb) {
      do_check_scrollbind(FALSE);
      curwin->w_scbind_pos = curwin->w_topline;
    }
  }
  /* There can be only one window with 'previewwindow' set. */
  else if ((int *)varp == &curwin->w_p_pvw) {
    if (curwin->w_p_pvw) {
      FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
        if (win->w_p_pvw && win != curwin) {
          curwin->w_p_pvw = false;
          return N_("E590: A preview window already exists");
        }
      }
    }
  } else if (varp == (char_u *)&(curbuf->b_p_lisp)) {
    // When 'lisp' option changes include/exclude '-' in
    // keyword characters.
    (void)buf_init_chartab(curbuf, false);          // ignore errors
  } else if ((int *)varp == &p_title) {
    // when 'title' changed, may need to change the title; same for 'icon'
    did_set_title(false);
  } else if ((int *)varp == &p_icon) {
    did_set_title(true);
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

    /* need to adjust the file name arguments and buffer names. */
    buflist_slash_adjust();
    alist_slash_adjust();
    scriptnames_slash_adjust();
  }
#endif

  /* If 'wrap' is set, set w_leftcol to zero. */
  else if ((int *)varp == &curwin->w_p_wrap) {
    if (curwin->w_p_wrap)
      curwin->w_leftcol = 0;
  } else if ((int *)varp == &p_ea) {
    if (p_ea && !old_value) {
      win_equal(curwin, false, 0);
    }
  } else if ((int *)varp == &p_acd) {
    // Change directories when the 'acd' option is set now.
    do_autochdir();
  }
  /* 'diff' */
  else if ((int *)varp == &curwin->w_p_diff) {
    /* May add or remove the buffer from the list of diff buffers. */
    diff_buf_adjust(curwin);
    if (foldmethodIsDiff(curwin))
      foldUpdateAll(curwin);
  }


  /* 'spell' */
  else if ((int *)varp == &curwin->w_p_spell) {
    if (curwin->w_p_spell) {
      char_u      *errmsg = did_set_spelllang(curwin);
      if (errmsg != NULL)
        EMSG(_(errmsg));
    }
  } else if ((int *)varp == &p_altkeymap) {
    if (old_value != p_altkeymap) {
      if (!p_altkeymap) {
        p_hkmap = p_fkmap;
        p_fkmap = 0;
      } else {
        p_fkmap = p_hkmap;
        p_hkmap = 0;
      }
      (void)init_chartab();
    }
  }

  /*
   * In case some second language keymapping options have changed, check
   * and correct the setting in a consistent way.
   */

  /*
   * If hkmap or fkmap are set, reset Arabic keymapping.
   */
  if ((p_hkmap || p_fkmap) && p_altkeymap) {
    p_altkeymap = p_fkmap;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  /*
   * If hkmap set, reset Farsi keymapping.
   */
  if (p_hkmap && p_altkeymap) {
    p_altkeymap = 0;
    p_fkmap = 0;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  /*
   * If fkmap set, reset Hebrew keymapping.
   */
  if (p_fkmap && !p_altkeymap) {
    p_altkeymap = 1;
    p_hkmap = 0;
    curwin->w_p_arab = FALSE;
    (void)init_chartab();
  }

  if ((int *)varp == &curwin->w_p_arab) {
    if (curwin->w_p_arab) {
      /*
       * 'arabic' is set, handle various sub-settings.
       */
      if (!p_tbidi) {
        /* set rightleft mode */
        if (!curwin->w_p_rl) {
          curwin->w_p_rl = TRUE;
          changed_window_setting();
        }

        /* Enable Arabic shaping (major part of what Arabic requires) */
        if (!p_arshape) {
          p_arshape = TRUE;
          redraw_later_clear();
        }
      }

      /* Arabic requires a utf-8 encoding, inform the user if its not
       * set. */
      if (STRCMP(p_enc, "utf-8") != 0) {
        static char *w_arabic = N_(
            "W17: Arabic requires UTF-8, do ':set encoding=utf-8'");

        msg_source(hl_attr(HLF_W));
        msg_attr(_(w_arabic), hl_attr(HLF_W));
        set_vim_var_string(VV_WARNINGMSG, _(w_arabic), -1);
      }

      /* set 'delcombine' */
      p_deco = TRUE;

      // Force-set the necessary keymap for arabic.
      set_option_value("keymap", 0L, "arabic", OPT_LOCAL);
      p_altkeymap = 0;
      p_hkmap = 0;
      p_fkmap = 0;
      (void)init_chartab();
    } else {
      /*
       * 'arabic' is reset, handle various sub-settings.
       */
      if (!p_tbidi) {
        /* reset rightleft mode */
        if (curwin->w_p_rl) {
          curwin->w_p_rl = FALSE;
          changed_window_setting();
        }

        /* 'arabicshape' isn't reset, it is a global option and
         * another window may still need it "on". */
      }

      /* 'delcombine' isn't reset, it is a global option and another
       * window may still want it "on". */

      /* Revert to the default keymap */
      curbuf->b_p_iminsert = B_IMODE_NONE;
      curbuf->b_p_imsearch = B_IMODE_USE_INSERT;
    }
  }


  /*
   * End of handling side effects for bool options.
   */

  // after handling side effects, call autocommand

  options[opt_idx].flags |= P_WAS_SET;

  if (!starting) {
    char buf_old[2];
    char buf_new[2];
    char buf_type[7];
    vim_snprintf(buf_old, ARRAY_SIZE(buf_old), "%d",
                 old_value ? true: false);
    vim_snprintf(buf_new, ARRAY_SIZE(buf_new), "%d",
                 value ? true: false);
    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_NEW, buf_new, -1);
    set_vim_var_string(VV_OPTION_OLD, buf_old, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    apply_autocmds(EVENT_OPTIONSET,
                   (char_u *) options[opt_idx].fullname,
                   NULL, false, NULL);
    reset_v_option_vars();
    if (options[opt_idx].flags & P_UI_OPTION) {
      ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                         BOOLEAN_OBJ(value));
    }
  }

  comp_col();                       /* in case 'ruler' or 'showcmd' changed */
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RALL)) != 0)
    curwin->w_set_curswant = TRUE;
  check_redraw(options[opt_idx].flags);

  return NULL;
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
static char *set_num_option(int opt_idx, char_u *varp, long value,
                            char_u *errbuf, size_t errbuflen, int opt_flags)
{
  char_u      *errmsg = NULL;
  long old_value = *(long *)varp;
  long old_Rows = Rows;                 /* remember old Rows */
  long old_Columns = Columns;           /* remember old Columns */
  long        *pp = (long *)varp;

  /* Disallow changing some options from secure mode. */
  if ((secure || sandbox != 0)
      && (options[opt_idx].flags & P_SECURE)) {
    return (char *)e_secure;
  }

  *pp = value;
  /* Remember where the option was set. */
  set_option_scriptID_idx(opt_idx, opt_flags, current_SID);

  if (curbuf->b_p_sw < 0) {
    errmsg = e_positive;
    curbuf->b_p_sw = curbuf->b_p_ts;
  }

  /*
   * Number options that need some action when changed
   */
  if (pp == &p_wh || pp == &p_hh) {
    if (p_wh < 1) {
      errmsg = e_positive;
      p_wh = 1;
    }
    if (p_wmh > p_wh) {
      errmsg = e_winheight;
      p_wh = p_wmh;
    }
    if (p_hh < 0) {
      errmsg = e_positive;
      p_hh = 0;
    }

    /* Change window height NOW */
    if (!ONE_WINDOW) {
      if (pp == &p_wh && curwin->w_height < p_wh)
        win_setheight((int)p_wh);
      if (pp == &p_hh && curbuf->b_help && curwin->w_height < p_hh)
        win_setheight((int)p_hh);
    }
  }
  /* 'winminheight' */
  else if (pp == &p_wmh) {
    if (p_wmh < 0) {
      errmsg = e_positive;
      p_wmh = 0;
    }
    if (p_wmh > p_wh) {
      errmsg = e_winheight;
      p_wmh = p_wh;
    }
    win_setminheight();
  } else if (pp == &p_wiw) {
    if (p_wiw < 1) {
      errmsg = e_positive;
      p_wiw = 1;
    }
    if (p_wmw > p_wiw) {
      errmsg = e_winwidth;
      p_wiw = p_wmw;
    }

    /* Change window width NOW */
    if (!ONE_WINDOW && curwin->w_width < p_wiw)
      win_setwidth((int)p_wiw);
  }
  /* 'winminwidth' */
  else if (pp == &p_wmw) {
    if (p_wmw < 0) {
      errmsg = e_positive;
      p_wmw = 0;
    }
    if (p_wmw > p_wiw) {
      errmsg = e_winwidth;
      p_wmw = p_wiw;
    }
    win_setminheight();
  } else if (pp == &p_ls) {
    /* (re)set last window status line */
    last_status(false);
  }
  /* (re)set tab page line */
  else if (pp == &p_stal) {
    shell_new_rows();           /* recompute window positions and heights */
  }
  /* 'foldlevel' */
  else if (pp == &curwin->w_p_fdl) {
    if (curwin->w_p_fdl < 0)
      curwin->w_p_fdl = 0;
    newFoldLevel();
  }
  /* 'foldminlines' */
  else if (pp == &curwin->w_p_fml) {
    foldUpdateAll(curwin);
  }
  /* 'foldnestmax' */
  else if (pp == &curwin->w_p_fdn) {
    if (foldmethodIsSyntax(curwin) || foldmethodIsIndent(curwin))
      foldUpdateAll(curwin);
  }
  /* 'foldcolumn' */
  else if (pp == &curwin->w_p_fdc) {
    if (curwin->w_p_fdc < 0) {
      errmsg = e_positive;
      curwin->w_p_fdc = 0;
    } else if (curwin->w_p_fdc > 12) {
      errmsg = e_invarg;
      curwin->w_p_fdc = 12;
    }
  // 'shiftwidth' or 'tabstop'
  } else if (pp == &curbuf->b_p_sw || pp == (long *)&curbuf->b_p_ts) {
    if (foldmethodIsIndent(curwin)) {
      foldUpdateAll(curwin);
    }
    // When 'shiftwidth' changes, or it's zero and 'tabstop' changes:
    // parse 'cinoptions'.
    if (pp == &curbuf->b_p_sw || curbuf->b_p_sw == 0) {
      parse_cino(curbuf);
    }
  }
  /* 'maxcombine' */
  else if (pp == &p_mco) {
    if (p_mco > MAX_MCO)
      p_mco = MAX_MCO;
    else if (p_mco < 0)
      p_mco = 0;
    screenclear();          /* will re-allocate the screen */
  } else if (pp == &curbuf->b_p_iminsert) {
    if (curbuf->b_p_iminsert < 0 || curbuf->b_p_iminsert > B_IMODE_LAST) {
      errmsg = e_invarg;
      curbuf->b_p_iminsert = B_IMODE_NONE;
    }
    p_iminsert = curbuf->b_p_iminsert;
    showmode();
    /* Show/unshow value of 'keymap' in status lines. */
    status_redraw_curbuf();
  } else if (pp == &p_window) {
    if (p_window < 1)
      p_window = 1;
    else if (p_window >= Rows)
      p_window = Rows - 1;
  } else if (pp == &curbuf->b_p_imsearch) {
    if (curbuf->b_p_imsearch < -1 || curbuf->b_p_imsearch > B_IMODE_LAST) {
      errmsg = e_invarg;
      curbuf->b_p_imsearch = B_IMODE_NONE;
    }
    p_imsearch = curbuf->b_p_imsearch;
  } else if (pp == &p_channel || pp == &curbuf->b_p_channel) {
    errmsg = e_invarg;
    *pp = old_value;
  }
  /* if 'titlelen' has changed, redraw the title */
  else if (pp == &p_titlelen) {
    if (p_titlelen < 0) {
      errmsg = e_positive;
      p_titlelen = 85;
    }
    if (starting != NO_SCREEN && old_value != p_titlelen)
      need_maketitle = TRUE;
  }
  /* if p_ch changed value, change the command line height */
  else if (pp == &p_ch) {
    if (p_ch < 1) {
      errmsg = e_positive;
      p_ch = 1;
    }
    if (p_ch > Rows - min_rows() + 1)
      p_ch = Rows - min_rows() + 1;

    /* Only compute the new window layout when startup has been
     * completed. Otherwise the frame sizes may be wrong. */
    if (p_ch != old_value && full_screen
        )
      command_height();
  }
  /* when 'updatecount' changes from zero to non-zero, open swap files */
  else if (pp == &p_uc) {
    if (p_uc < 0) {
      errmsg = e_positive;
      p_uc = 100;
    }
    if (p_uc && !old_value)
      ml_open_files();
  } else if (pp == &curwin->w_p_cole) {
    if (curwin->w_p_cole < 0) {
      errmsg = e_positive;
      curwin->w_p_cole = 0;
    } else if (curwin->w_p_cole > 3) {
      errmsg = e_invarg;
      curwin->w_p_cole = 3;
    }
  }
  /* sync undo before 'undolevels' changes */
  else if (pp == &p_ul) {
    /* use the old value, otherwise u_sync() may not work properly */
    p_ul = old_value;
    u_sync(TRUE);
    p_ul = value;
  } else if (pp == &curbuf->b_p_ul) {
    /* use the old value, otherwise u_sync() may not work properly */
    curbuf->b_p_ul = old_value;
    u_sync(TRUE);
    curbuf->b_p_ul = value;
  }
  /* 'numberwidth' must be positive */
  else if (pp == &curwin->w_p_nuw) {
    if (curwin->w_p_nuw < 1) {
      errmsg = e_positive;
      curwin->w_p_nuw = 1;
    }
    if (curwin->w_p_nuw > 10) {
      errmsg = e_invarg;
      curwin->w_p_nuw = 10;
    }
    curwin->w_nrwidth_line_count = 0;
  } else if (pp == &curbuf->b_p_tw) {
    if (curbuf->b_p_tw < 0) {
      errmsg = e_positive;
      curbuf->b_p_tw = 0;
    }

    FOR_ALL_TAB_WINDOWS(tp, wp) {
      check_colorcolumn(wp);
    }
  } else if (pp == &curbuf->b_p_scbk || pp == &p_scbk) {
    // 'scrollback'
    if (*pp < -1 || *pp > SB_MAX
        || (*pp != -1 && opt_flags == OPT_LOCAL && !curbuf->terminal)) {
      errmsg = e_invarg;
      *pp = old_value;
    } else if (curbuf->terminal) {
      // Force the scrollback to take effect.
      terminal_resize(curbuf->terminal, UINT16_MAX, UINT16_MAX);
    }
  }

  /*
   * Check the bounds for numeric options here
   */
  if (Rows < min_rows() && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf((char *)errbuf, errbuflen,
          _("E593: Need at least %d lines"), min_rows());
      errmsg = errbuf;
    }
    Rows = min_rows();
  }
  if (Columns < MIN_COLUMNS && full_screen) {
    if (errbuf != NULL) {
      vim_snprintf((char *)errbuf, errbuflen,
          _("E594: Need at least %d columns"), MIN_COLUMNS);
      errmsg = errbuf;
    }
    Columns = MIN_COLUMNS;
  }
  limit_screen_size();


  /*
   * If the screen (shell) height has been changed, assume it is the
   * physical screenheight.
   */
  if (old_Rows != Rows || old_Columns != Columns) {
    /* Changing the screen size is not allowed while updating the screen. */
    if (updating_screen) {
      *pp = old_value;
    } else if (full_screen) {
      screen_resize((int)Columns, (int)Rows);
    } else {
      /* Postpone the resizing; check the size and cmdline position for
       * messages. */
      check_shellsize();
      if (cmdline_row > Rows - p_ch && Rows > p_ch) {
        assert(p_ch >= 0 && Rows - p_ch <= INT_MAX);
        cmdline_row = (int)(Rows - p_ch);
      }
    }
    if (p_window >= Rows || !option_was_set("window")) {
      p_window = Rows - 1;
    }
  }

  if (curbuf->b_p_ts <= 0) {
    errmsg = e_positive;
    curbuf->b_p_ts = 8;
  }
  if (p_tm < 0) {
    errmsg = e_positive;
    p_tm = 0;
  }
  if ((curwin->w_p_scr <= 0
       || (curwin->w_p_scr > curwin->w_height
           && curwin->w_height > 0))
      && full_screen) {
    if (pp == &(curwin->w_p_scr)) {
      if (curwin->w_p_scr != 0)
        errmsg = e_scroll;
      win_comp_scroll(curwin);
    }
    /* If 'scroll' became invalid because of a side effect silently adjust
     * it. */
    else if (curwin->w_p_scr <= 0)
      curwin->w_p_scr = 1;
    else     /* curwin->w_p_scr > curwin->w_height */
      curwin->w_p_scr = curwin->w_height;
  }
  if (p_hi < 0) {
    errmsg = e_positive;
    p_hi = 0;
  } else if (p_hi > 10000) {
    errmsg = e_invarg;
    p_hi = 10000;
  }
  if (p_re < 0 || p_re > 2) {
    errmsg = e_invarg;
    p_re = 0;
  }
  if (p_report < 0) {
    errmsg = e_positive;
    p_report = 1;
  }
  if ((p_sj < -100 || p_sj >= Rows) && full_screen) {
    if (Rows != old_Rows)       /* Rows changed, just adjust p_sj */
      p_sj = Rows / 2;
    else {
      errmsg = e_scroll;
      p_sj = 1;
    }
  }
  if (p_so < 0 && full_screen) {
    errmsg = e_scroll;
    p_so = 0;
  }
  if (p_siso < 0 && full_screen) {
    errmsg = e_positive;
    p_siso = 0;
  }
  if (p_cwh < 1) {
    errmsg = e_positive;
    p_cwh = 1;
  }
  if (p_ut < 0) {
    errmsg = e_positive;
    p_ut = 2000;
  }
  if (p_ss < 0) {
    errmsg = e_positive;
    p_ss = 0;
  }

  /* May set global value for local option. */
  if ((opt_flags & (OPT_LOCAL | OPT_GLOBAL)) == 0)
    *(long *)get_varp_scope(&(options[opt_idx]), OPT_GLOBAL) = *pp;

  if (pp == &curbuf->b_p_scbk && !curbuf->terminal) {
    // Normal buffer: reset local 'scrollback' after updating the global value.
    curbuf->b_p_scbk = -1;
  }

  options[opt_idx].flags |= P_WAS_SET;

  if (!starting && errmsg == NULL) {
    char buf_old[NUMBUFLEN];
    char buf_new[NUMBUFLEN];
    char buf_type[7];
    vim_snprintf(buf_old, ARRAY_SIZE(buf_old), "%ld", old_value);
    vim_snprintf(buf_new, ARRAY_SIZE(buf_new), "%ld", value);
    vim_snprintf(buf_type, ARRAY_SIZE(buf_type), "%s",
                 (opt_flags & OPT_LOCAL) ? "local" : "global");
    set_vim_var_string(VV_OPTION_NEW, buf_new, -1);
    set_vim_var_string(VV_OPTION_OLD, buf_old, -1);
    set_vim_var_string(VV_OPTION_TYPE, buf_type, -1);
    apply_autocmds(EVENT_OPTIONSET,
                   (char_u *) options[opt_idx].fullname,
                   NULL, false, NULL);
    reset_v_option_vars();
    if (options[opt_idx].flags & P_UI_OPTION) {
      ui_call_option_set(cstr_as_string(options[opt_idx].fullname),
                         INTEGER_OBJ(value));
    }
  }

  comp_col();                       /* in case 'columns' or 'ls' changed */
  if (curwin->w_curswant != MAXCOL
      && (options[opt_idx].flags & (P_CURSWANT | P_RALL)) != 0)
    curwin->w_set_curswant = TRUE;
  check_redraw(options[opt_idx].flags);

  return (char *)errmsg;
}

/*
 * Called after an option changed: check if something needs to be redrawn.
 */
static void check_redraw(uint32_t flags)
{
  /* Careful: P_RCLR and P_RALL are a combination of other P_ flags */
  bool doclear = (flags & P_RCLR) == P_RCLR;
  bool all = ((flags & P_RALL) == P_RALL || doclear);

  if ((flags & P_RSTAT) || all) {  // mark all status lines dirty
    status_redraw_all();
  }

  if ((flags & P_RBUF) || (flags & P_RWIN) || all) {
    changed_window_setting();
  }
  if (flags & P_RBUF) {
    redraw_curbuf_later(NOT_VALID);
  }
  if (flags & P_RWINONLY) {
    redraw_later(NOT_VALID);
  }
  if (doclear) {
    redraw_all_later(CLEAR);
  } else if (all) {
    redraw_all_later(NOT_VALID);
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
          quick_tab[CharOrdLow(s[0])] = i;
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
    opt_idx = quick_tab[CharOrdLow(arg[0])];
  }
  // Match full name
  for (; (s = options[opt_idx].fullname) != NULL; opt_idx++) {
    if (strncmp(arg, s, len) == 0 && s[len] == NUL) {
      break;
    }
  }
  if (s == NULL && !is_term_opt) {
    opt_idx = quick_tab[CharOrdLow(arg[0])];
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
bool get_tty_option(char *name, char **value)
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
static int findoption(const char *const arg)
{
  return findoption_len(arg, strlen(arg));
}

/// Gets the value for an option.
///
/// @returns:
/// Number or Toggle option: 1, *numval gets value.
///           String option: 0, *stringval gets allocated string.
/// Hidden Number or Toggle option: -1.
///           hidden String option: -2.
///                 unknown option: -3.
int get_option_value(
    char_u *name,
    long *numval,
    char_u **stringval,            ///< NULL when only checking existence
    int opt_flags
)
{
  if (get_tty_option((char *)name, (char **)stringval)) {
    return 0;
  }

  int opt_idx = findoption((const char *)name);
  if (opt_idx < 0) {  // Unknown option.
    return -3;
  }

  char_u *varp = get_varp_scope(&(options[opt_idx]), opt_flags);

  if (options[opt_idx].flags & P_STRING) {
    if (varp == NULL) {  // hidden option
      return -2;
    }
    if (stringval != NULL) {
      *stringval = vim_strsave(*(char_u **)(varp));
    }
    return 0;
  }

  if (varp == NULL) {  // hidden option
    return -1;
  }
  if (options[opt_idx].flags & P_NUM) {
    *numval = *(long *)varp;
  } else {
    // Special case: 'modified' is b_changed, but we also want to consider
    // it set when 'ff' or 'fenc' changed.
    if ((int *)varp == &curbuf->b_changed) {
      *numval = curbufIsChanged();
    } else {
      *numval = (long) *(int *)varp;  // NOLINT(whitespace/cast)
    }
  }
  return 1;
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
int get_option_value_strict(char *name,
                            int64_t *numval,
                            char **stringval,
                            int opt_type,
                            void *from)
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
        *numval = bufIsChanged((buf_T *) from);
        varp = NULL;
      } else {
        aco_save_T	aco;
        aucmd_prepbuf(&aco, (buf_T *) from);
        varp = get_varp(p);
        aucmd_restbuf(&aco);
      }
    } else if (opt_type == SREQ_WIN) {
      win_T	*save_curwin;
      save_curwin = curwin;
      curwin = (win_T *) from;
      curbuf = curwin->w_buffer;
      varp = get_varp(p);
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
      *numval = *(long *) varp;
    } else {
      *numval = *(int *)varp;
    }
  }

  return rv;
}

/// Set the value of an option
///
/// @param[in]  name  Option name.
/// @param[in]  number  New value for the number or boolean option.
/// @param[in]  string  New value for string option.
/// @param[in]  opt_flags  Flags: OPT_LOCAL, OPT_GLOBAL, or 0 (both).
///
/// @return NULL on success, error message on error.
char *set_option_value(const char *const name, const long number,
                       const char *const string, const int opt_flags)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (is_tty_option(name)) {
    return NULL;  // Fail silently; many old vimrcs set t_xx options.
  }

  int opt_idx;
  char_u      *varp;

  opt_idx = findoption(name);
  if (opt_idx < 0) {
    EMSG2(_("E355: Unknown option: %s"), name);
  } else {
    uint32_t flags = options[opt_idx].flags;
    // Disallow changing some options in the sandbox
    if (sandbox > 0 && (flags & P_SECURE)) {
      EMSG(_(e_sandbox));
      return NULL;
    }
    if (flags & P_STRING) {
      const char *s = string;
      if (s == NULL) {
        s = "";
      }
      return set_string_option(opt_idx, s, opt_flags);
    } else {
      varp = get_varp_scope(&(options[opt_idx]), opt_flags);
      if (varp != NULL) {       /* hidden option is not changed */
        if (number == 0 && string != NULL) {
          int idx;

          // Either we are given a string or we are setting option
          // to zero.
          for (idx = 0; string[idx] == '0'; idx++) {}
          if (string[idx] != NUL || idx == 0) {
            // There's another character after zeros or the string
            // is empty.  In both cases, we are trying to set a
            // num option using a string.
            EMSG3(_("E521: Number required: &%s = '%s'"),
                  name, string);
            return NULL;  // do nothing as we hit an error
          }
        }
        if (flags & P_NUM) {
          return set_num_option(opt_idx, varp, number, NULL, 0, opt_flags);
        } else {
          return set_bool_option(opt_idx, varp, (int)number, opt_flags);
        }
      }
    }
  }
  return NULL;
}

/*
 * Translate a string like "t_xx", "<t_xx>" or "<S-Tab>" to a key number.
 */
int find_key_option_len(const char_u *arg, size_t len)
{
  int key;
  int modifiers;

  // Don't use get_special_key_code() for t_xx, we don't want it to call
  // add_termcap_entry().
  if (len >= 4 && arg[0] == 't' && arg[1] == '_') {
    key = TERMCAP2KEY(arg[2], arg[3]);
  } else {
    arg--;  // put arg at the '<'
    modifiers = 0;
    key = find_special_key(&arg, len + 1, &modifiers, true, true, false);
    if (modifiers) {  // can't handle modifiers here
      key = 0;
    }
  }
  return key;
}

static int find_key_option(const char_u *arg)
{
  return find_key_option_len(arg, STRLEN(arg));
}

/*
 * if 'all' == 0: show changed options
 * if 'all' == 1: show all normal options
 */
static void 
showoptions (
    int all,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  vimoption_T    *p;
  int col;
  char_u              *varp;
  int item_count;
  int run;
  int row, rows;
  int cols;
  int i;
  int len;

#define INC 20
#define GAP 3

  vimoption_T **items = xmalloc(sizeof(vimoption_T *) * PARAM_COUNT);

  // Highlight title
  if (opt_flags & OPT_GLOBAL) {
    MSG_PUTS_TITLE(_("\n--- Global option values ---"));
  } else if (opt_flags & OPT_LOCAL) {
    MSG_PUTS_TITLE(_("\n--- Local option values ---"));
  } else {
    MSG_PUTS_TITLE(_("\n--- Options ---"));
  }

  /*
   * do the loop two times:
   * 1. display the short items
   * 2. display the long items (only strings and numbers)
   */
  for (run = 1; run <= 2 && !got_int; ++run) {
    /*
     * collect the items in items[]
     */
    item_count = 0;
    for (p = &options[0]; p->fullname != NULL; p++) {
      varp = NULL;
      if (opt_flags != 0) {
        if (p->indir != PV_NONE)
          varp = get_varp_scope(p, opt_flags);
      } else
        varp = get_varp(p);
      if (varp != NULL
          && (all == 1 || (all == 0 && !optval_default(p, varp)))) {
        if (p->flags & P_BOOL)
          len = 1;                      /* a toggle option fits always */
        else {
          option_value2string(p, opt_flags);
          len = (int)STRLEN(p->fullname) + vim_strsize(NameBuff) + 1;
        }
        if ((len <= INC - GAP && run == 1)
            || (len > INC - GAP && run == 2)) {
          items[item_count++] = p;
        }
      }
    }

    /*
     * display the items
     */
    if (run == 1) {
      assert(Columns <= LONG_MAX - GAP
             && Columns + GAP >= LONG_MIN + 3
             && (Columns + GAP - 3) / INC >= INT_MIN
             && (Columns + GAP - 3) / INC <= INT_MAX);
      cols = (int)((Columns + GAP - 3) / INC);
      if (cols == 0)
        cols = 1;
      rows = (item_count + cols - 1) / cols;
    } else      /* run == 2 */
      rows = item_count;
    for (row = 0; row < rows && !got_int; ++row) {
      msg_putchar('\n');                        /* go to next line */
      if (got_int)                              /* 'q' typed in more */
        break;
      col = 0;
      for (i = row; i < item_count; i += rows) {
        msg_col = col;                          /* make columns */
        showoneopt(items[i], opt_flags);
        col += INC;
      }
      ui_flush();
      os_breakcheck();
    }
  }
  xfree(items);
}

/*
 * Return TRUE if option "p" has its default value.
 */
static int optval_default(vimoption_T *p, char_u *varp)
{
  int dvi;

  if (varp == NULL)
    return TRUE;            /* hidden option is always at default */
  dvi = ((p->flags & P_VI_DEF) || p_cp) ? VI_DEFAULT : VIM_DEFAULT;
  if (p->flags & P_NUM) {
    return *(long *)varp == (long)(intptr_t)p->def_val[dvi];
  }
  if (p->flags & P_BOOL) {
    return *(int *)varp == (int)(intptr_t)p->def_val[dvi];
  }
  // P_STRING
  return STRCMP(*(char_u **)varp, p->def_val[dvi]) == 0;
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
}

/*
 * showoneopt: show the value of one option
 * must not be called with a hidden option!
 */
static void 
showoneopt (
    vimoption_T *p,
    int opt_flags                          /* OPT_LOCAL or OPT_GLOBAL */
)
{
  char_u      *varp;
  int save_silent = silent_mode;

  silent_mode = FALSE;
  info_message = TRUE;          /* use mch_msg(), not mch_errmsg() */

  varp = get_varp_scope(p, opt_flags);

  // for 'modified' we also need to check if 'ff' or 'fenc' changed.
  if ((p->flags & P_BOOL) && ((int *)varp == &curbuf->b_changed
                              ? !curbufIsChanged() : !*(int *)varp)) {
    MSG_PUTS("no");
  } else if ((p->flags & P_BOOL) && *(int *)varp < 0) {
    MSG_PUTS("--");
  } else {
    MSG_PUTS("  ");
  }
  MSG_PUTS(p->fullname);
  if (!(p->flags & P_BOOL)) {
    msg_putchar('=');
    /* put value string in NameBuff */
    option_value2string(p, opt_flags);
    msg_outtrans(NameBuff);
  }

  silent_mode = save_silent;
  info_message = FALSE;
}

/*
 * Write modified options as ":set" commands to a file.
 *
 * There are three values for "opt_flags":
 * OPT_GLOBAL:		   Write global option values and fresh values of
 *			   buffer-local options (used for start of a session
 *			   file).
 * OPT_GLOBAL + OPT_LOCAL: Idem, add fresh values of window-local options for
 *			   curwin (used for a vimrc file).
 * OPT_LOCAL:		   Write buffer-local option values for curbuf, fresh
 *			   and local values for window-local options of
 *			   curwin.  Local values are also written when at the
 *			   default value, because a modeline or autocommand
 *			   may have set them when doing ":edit file" and the
 *			   user has set them back at the default or fresh
 *			   value.
 *			   When "local_only" is TRUE, don't write fresh
 *			   values, only local values (for ":mkview").
 * (fresh value = value used for a new buffer or window for a local option).
 *
 * Return FAIL on error, OK otherwise.
 */
int makeset(FILE *fd, int opt_flags, int local_only)
{
  vimoption_T    *p;
  char_u              *varp;                    /* currently used value */
  char_u              *varp_fresh;              /* local value */
  char_u              *varp_local = NULL;       /* fresh value */
  char                *cmd;
  int round;
  int pri;

  /*
   * Some options are never written:
   * - Options that don't have a default (terminal name, columns, lines).
   * - Terminal options.
   * - Hidden options.
   *
   * Do the loop over "options[]" twice: once for options with the
   * P_PRI_MKRC flag and once without.
   */
  for (pri = 1; pri >= 0; --pri) {
    for (p = &options[0]; p->fullname; p++)
      if (!(p->flags & P_NO_MKRC)
          && ((pri == 1) == ((p->flags & P_PRI_MKRC) != 0))) {
        /* skip global option when only doing locals */
        if (p->indir == PV_NONE && !(opt_flags & OPT_GLOBAL))
          continue;

        /* Do not store options like 'bufhidden' and 'syntax' in a vimrc
         * file, they are always buffer-specific. */
        if ((opt_flags & OPT_GLOBAL) && (p->flags & P_NOGLOB))
          continue;

        varp = get_varp_scope(p, opt_flags);
        /* Hidden options are never written. */
        if (!varp)
          continue;
        /* Global values are only written when not at the default value. */
        if ((opt_flags & OPT_GLOBAL) && optval_default(p, varp))
          continue;

        round = 2;
        if (p->indir != PV_NONE) {
          if (p->var == VAR_WIN) {
            /* skip window-local option when only doing globals */
            if (!(opt_flags & OPT_LOCAL))
              continue;
            /* When fresh value of window-local option is not at the
             * default, need to write it too. */
            if (!(opt_flags & OPT_GLOBAL) && !local_only) {
              varp_fresh = get_varp_scope(p, OPT_GLOBAL);
              if (!optval_default(p, varp_fresh)) {
                round = 1;
                varp_local = varp;
                varp = varp_fresh;
              }
            }
          }
        }

        /* Round 1: fresh value for window-local options.
         * Round 2: other values */
        for (; round <= 2; varp = varp_local, ++round) {
          if (round == 1 || (opt_flags & OPT_GLOBAL))
            cmd = "set";
          else
            cmd = "setlocal";

          if (p->flags & P_BOOL) {
            if (put_setbool(fd, cmd, p->fullname, *(int *)varp) == FAIL)
              return FAIL;
          } else if (p->flags & P_NUM) {
            if (put_setnum(fd, cmd, p->fullname, (long *)varp) == FAIL)
              return FAIL;
          } else {    /* P_STRING */
            int do_endif = FALSE;

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
            if (put_setstring(fd, cmd, p->fullname, (char_u **)varp,
                    (p->flags & P_EXPAND) != 0) == FAIL)
              return FAIL;
            if (do_endif) {
              if (put_line(fd, "endif") == FAIL)
                return FAIL;
            }
          }
        }
      }
  }
  return OK;
}

/*
 * Generate set commands for the local fold options only.  Used when
 * 'sessionoptions' or 'viewoptions' contains "folds" but not "options".
 */
int makefoldset(FILE *fd)
{
  if (put_setstring(fd, "setlocal", "fdm", &curwin->w_p_fdm, FALSE) == FAIL
      || put_setstring(fd, "setlocal", "fde", &curwin->w_p_fde, FALSE)
      == FAIL
      || put_setstring(fd, "setlocal", "fmr", &curwin->w_p_fmr, FALSE)
      == FAIL
      || put_setstring(fd, "setlocal", "fdi", &curwin->w_p_fdi, FALSE)
      == FAIL
      || put_setnum(fd, "setlocal", "fdl", &curwin->w_p_fdl) == FAIL
      || put_setnum(fd, "setlocal", "fml", &curwin->w_p_fml) == FAIL
      || put_setnum(fd, "setlocal", "fdn", &curwin->w_p_fdn) == FAIL
      || put_setbool(fd, "setlocal", "fen", curwin->w_p_fen) == FAIL
      )
    return FAIL;

  return OK;
}

static int put_setstring(FILE *fd, char *cmd, char *name, char_u **valuep, int expand)
{
  char_u      *s;
  char_u      *buf;

  if (fprintf(fd, "%s %s=", cmd, name) < 0)
    return FAIL;
  if (*valuep != NULL) {
    /* Output 'pastetoggle' as key names.  For other
     * options some characters have to be escaped with
     * CTRL-V or backslash */
    if (valuep == &p_pt) {
      s = *valuep;
      while (*s != NUL) {
        if (put_escstr(fd, (char_u *)str2special((const char **)&s, false,
                                                 false), 2)
            == FAIL) {
          return FAIL;
        }
      }
    } else if (expand) {
      buf = xmalloc(MAXPATHL);
      home_replace(NULL, *valuep, buf, MAXPATHL, FALSE);
      if (put_escstr(fd, buf, 2) == FAIL) {
        xfree(buf);
        return FAIL;
      }
      xfree(buf);
    } else if (put_escstr(fd, *valuep, 2) == FAIL)
      return FAIL;
  }
  if (put_eol(fd) < 0)
    return FAIL;
  return OK;
}

static int put_setnum(FILE *fd, char *cmd, char *name, long *valuep)
{
  long wc;

  if (fprintf(fd, "%s %s=", cmd, name) < 0)
    return FAIL;
  if (wc_use_keyname((char_u *)valuep, &wc)) {
    /* print 'wildchar' and 'wildcharm' as a key name */
    if (fputs((char *)get_special_key_name((int)wc, 0), fd) < 0)
      return FAIL;
  } else if (fprintf(fd, "%" PRId64, (int64_t)*valuep) < 0)
    return FAIL;
  if (put_eol(fd) < 0)
    return FAIL;
  return OK;
}

static int put_setbool(FILE *fd, char *cmd, char *name, int value)
{
  if (value < 0)        /* global/local option using global value */
    return OK;
  if (fprintf(fd, "%s %s%s", cmd, value ? "" : "no", name) < 0
      || put_eol(fd) < 0)
    return FAIL;
  return OK;
}

/*
 * Compute columns for ruler and shown command. 'sc_col' is also used to
 * decide what the maximum length of a message on the status line can be.
 * If there is a status line for the last window, 'sc_col' is independent
 * of 'ru_col'.
 */

#define COL_RULER 17        /* columns needed by standard ruler */

void comp_col(void)
{
  int last_has_status = (p_ls == 2 || (p_ls == 1 && !ONE_WINDOW));

  sc_col = 0;
  ru_col = 0;
  if (p_ru) {
    ru_col = (ru_wid ? ru_wid : COL_RULER) + 1;
    /* no last status line, adjust sc_col */
    if (!last_has_status)
      sc_col = ru_col;
  }
  if (p_sc) {
    sc_col += SHOWCMD_COLS;
    if (!p_ru || last_has_status)           /* no need for separating space */
      ++sc_col;
  }
  assert(sc_col >= 0
         && INT_MIN + sc_col <= Columns
         && Columns - sc_col <= INT_MAX);
  sc_col = (int)(Columns - sc_col);
  assert(ru_col >= 0
         && INT_MIN + ru_col <= Columns
         && Columns - ru_col <= INT_MAX);
  ru_col = (int)(Columns - ru_col);
  if (sc_col <= 0)              /* screen too narrow, will become a mess */
    sc_col = 1;
  if (ru_col <= 0)
    ru_col = 1;
}

// Unset local option value, similar to ":set opt<".
void unset_global_local_option(char *name, void *from)
{
  vimoption_T *p;
  buf_T *buf = (buf_T *)from;

  int opt_idx = findoption(name);
  if (opt_idx < 0) {
    EMSG2(_("E355: Unknown option: %s"), name);
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
    case PV_STL:
      clear_string_option(&((win_T *)from)->w_p_stl);
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
  }
}

/*
 * Get pointer to option variable, depending on local or global scope.
 */
static char_u *get_varp_scope(vimoption_T *p, int opt_flags)
{
  if ((opt_flags & OPT_GLOBAL) && p->indir != PV_NONE) {
    if (p->var == VAR_WIN)
      return (char_u *)GLOBAL_WO(get_varp(p));
    return p->var;
  }
  if ((opt_flags & OPT_LOCAL) && ((int)p->indir & PV_BOTH)) {
    switch ((int)p->indir) {
    case PV_FP:   return (char_u *)&(curbuf->b_p_fp);
    case PV_EFM:  return (char_u *)&(curbuf->b_p_efm);
    case PV_GP:   return (char_u *)&(curbuf->b_p_gp);
    case PV_MP:   return (char_u *)&(curbuf->b_p_mp);
    case PV_EP:   return (char_u *)&(curbuf->b_p_ep);
    case PV_KP:   return (char_u *)&(curbuf->b_p_kp);
    case PV_PATH: return (char_u *)&(curbuf->b_p_path);
    case PV_AR:   return (char_u *)&(curbuf->b_p_ar);
    case PV_TAGS: return (char_u *)&(curbuf->b_p_tags);
    case PV_TC:   return (char_u *)&(curbuf->b_p_tc);
    case PV_DEF:  return (char_u *)&(curbuf->b_p_def);
    case PV_INC:  return (char_u *)&(curbuf->b_p_inc);
    case PV_DICT: return (char_u *)&(curbuf->b_p_dict);
    case PV_TSR:  return (char_u *)&(curbuf->b_p_tsr);
    case PV_STL:  return (char_u *)&(curwin->w_p_stl);
    case PV_UL:   return (char_u *)&(curbuf->b_p_ul);
    case PV_LW:   return (char_u *)&(curbuf->b_p_lw);
    case PV_BKC:  return (char_u *)&(curbuf->b_p_bkc);
    case PV_MENC: return (char_u *)&(curbuf->b_p_menc);
    }
    return NULL;     /* "cannot happen" */
  }
  return get_varp(p);
}

/*
 * Get pointer to option variable.
 */
static char_u *get_varp(vimoption_T *p)
{
  /* hidden option, always return NULL */
  if (p->var == NULL)
    return NULL;

  switch ((int)p->indir) {
  case PV_NONE:   return p->var;

  /* global option with local value: use local value if it's been set */
  case PV_EP:     return *curbuf->b_p_ep != NUL
           ? (char_u *)&curbuf->b_p_ep : p->var;
  case PV_KP:     return *curbuf->b_p_kp != NUL
           ? (char_u *)&curbuf->b_p_kp : p->var;
  case PV_PATH:   return *curbuf->b_p_path != NUL
           ? (char_u *)&(curbuf->b_p_path) : p->var;
  case PV_AR:     return curbuf->b_p_ar >= 0
           ? (char_u *)&(curbuf->b_p_ar) : p->var;
  case PV_TAGS:   return *curbuf->b_p_tags != NUL
           ? (char_u *)&(curbuf->b_p_tags) : p->var;
  case PV_TC:     return *curbuf->b_p_tc != NUL
           ? (char_u *)&(curbuf->b_p_tc) : p->var;
  case PV_BKC:    return *curbuf->b_p_bkc != NUL
           ? (char_u *)&(curbuf->b_p_bkc) : p->var;
  case PV_DEF:    return *curbuf->b_p_def != NUL
           ? (char_u *)&(curbuf->b_p_def) : p->var;
  case PV_INC:    return *curbuf->b_p_inc != NUL
           ? (char_u *)&(curbuf->b_p_inc) : p->var;
  case PV_DICT:   return *curbuf->b_p_dict != NUL
           ? (char_u *)&(curbuf->b_p_dict) : p->var;
  case PV_TSR:    return *curbuf->b_p_tsr != NUL
           ? (char_u *)&(curbuf->b_p_tsr) : p->var;
  case PV_FP: return *curbuf->b_p_fp != NUL
           ? (char_u *)&(curbuf->b_p_fp) : p->var;
  case PV_EFM:    return *curbuf->b_p_efm != NUL
           ? (char_u *)&(curbuf->b_p_efm) : p->var;
  case PV_GP:     return *curbuf->b_p_gp != NUL
           ? (char_u *)&(curbuf->b_p_gp) : p->var;
  case PV_MP:     return *curbuf->b_p_mp != NUL
           ? (char_u *)&(curbuf->b_p_mp) : p->var;
  case PV_STL:    return *curwin->w_p_stl != NUL
           ? (char_u *)&(curwin->w_p_stl) : p->var;
  case PV_UL:     return curbuf->b_p_ul != NO_LOCAL_UNDOLEVEL
           ? (char_u *)&(curbuf->b_p_ul) : p->var;
  case PV_LW:   return *curbuf->b_p_lw != NUL
           ? (char_u *)&(curbuf->b_p_lw) : p->var;
  case PV_MENC: return *curbuf->b_p_menc != NUL
           ? (char_u *)&(curbuf->b_p_menc) : p->var;

  case PV_ARAB:   return (char_u *)&(curwin->w_p_arab);
  case PV_LIST:   return (char_u *)&(curwin->w_p_list);
  case PV_SPELL:  return (char_u *)&(curwin->w_p_spell);
  case PV_CUC:    return (char_u *)&(curwin->w_p_cuc);
  case PV_CUL:    return (char_u *)&(curwin->w_p_cul);
  case PV_CC:     return (char_u *)&(curwin->w_p_cc);
  case PV_DIFF:   return (char_u *)&(curwin->w_p_diff);
  case PV_FDC:    return (char_u *)&(curwin->w_p_fdc);
  case PV_FEN:    return (char_u *)&(curwin->w_p_fen);
  case PV_FDI:    return (char_u *)&(curwin->w_p_fdi);
  case PV_FDL:    return (char_u *)&(curwin->w_p_fdl);
  case PV_FDM:    return (char_u *)&(curwin->w_p_fdm);
  case PV_FML:    return (char_u *)&(curwin->w_p_fml);
  case PV_FDN:    return (char_u *)&(curwin->w_p_fdn);
  case PV_FDE:    return (char_u *)&(curwin->w_p_fde);
  case PV_FDT:    return (char_u *)&(curwin->w_p_fdt);
  case PV_FMR:    return (char_u *)&(curwin->w_p_fmr);
  case PV_NU:     return (char_u *)&(curwin->w_p_nu);
  case PV_RNU:    return (char_u *)&(curwin->w_p_rnu);
  case PV_NUW:    return (char_u *)&(curwin->w_p_nuw);
  case PV_WFH:    return (char_u *)&(curwin->w_p_wfh);
  case PV_WFW:    return (char_u *)&(curwin->w_p_wfw);
  case PV_PVW:    return (char_u *)&(curwin->w_p_pvw);
  case PV_RL:     return (char_u *)&(curwin->w_p_rl);
  case PV_RLC:    return (char_u *)&(curwin->w_p_rlc);
  case PV_SCROLL: return (char_u *)&(curwin->w_p_scr);
  case PV_WRAP:   return (char_u *)&(curwin->w_p_wrap);
  case PV_LBR:    return (char_u *)&(curwin->w_p_lbr);
  case PV_BRI:    return (char_u *)&(curwin->w_p_bri);
  case PV_BRIOPT: return (char_u *)&(curwin->w_p_briopt);
  case PV_SCBIND: return (char_u *)&(curwin->w_p_scb);
  case PV_CRBIND: return (char_u *)&(curwin->w_p_crb);
  case PV_COCU:    return (char_u *)&(curwin->w_p_cocu);
  case PV_COLE:    return (char_u *)&(curwin->w_p_cole);

  case PV_AI:     return (char_u *)&(curbuf->b_p_ai);
  case PV_BIN:    return (char_u *)&(curbuf->b_p_bin);
  case PV_BOMB:   return (char_u *)&(curbuf->b_p_bomb);
  case PV_BH:     return (char_u *)&(curbuf->b_p_bh);
  case PV_BT:     return (char_u *)&(curbuf->b_p_bt);
  case PV_BL:     return (char_u *)&(curbuf->b_p_bl);
  case PV_CHANNEL:return (char_u *)&(curbuf->b_p_channel);
  case PV_CI:     return (char_u *)&(curbuf->b_p_ci);
  case PV_CIN:    return (char_u *)&(curbuf->b_p_cin);
  case PV_CINK:   return (char_u *)&(curbuf->b_p_cink);
  case PV_CINO:   return (char_u *)&(curbuf->b_p_cino);
  case PV_CINW:   return (char_u *)&(curbuf->b_p_cinw);
  case PV_COM:    return (char_u *)&(curbuf->b_p_com);
  case PV_CMS:    return (char_u *)&(curbuf->b_p_cms);
  case PV_CPT:    return (char_u *)&(curbuf->b_p_cpt);
  case PV_CFU:    return (char_u *)&(curbuf->b_p_cfu);
  case PV_OFU:    return (char_u *)&(curbuf->b_p_ofu);
  case PV_EOL:    return (char_u *)&(curbuf->b_p_eol);
  case PV_FIXEOL: return (char_u *)&(curbuf->b_p_fixeol);
  case PV_ET:     return (char_u *)&(curbuf->b_p_et);
  case PV_FENC:   return (char_u *)&(curbuf->b_p_fenc);
  case PV_FF:     return (char_u *)&(curbuf->b_p_ff);
  case PV_FT:     return (char_u *)&(curbuf->b_p_ft);
  case PV_FO:     return (char_u *)&(curbuf->b_p_fo);
  case PV_FLP:    return (char_u *)&(curbuf->b_p_flp);
  case PV_IMI:    return (char_u *)&(curbuf->b_p_iminsert);
  case PV_IMS:    return (char_u *)&(curbuf->b_p_imsearch);
  case PV_INF:    return (char_u *)&(curbuf->b_p_inf);
  case PV_ISK:    return (char_u *)&(curbuf->b_p_isk);
  case PV_INEX:   return (char_u *)&(curbuf->b_p_inex);
  case PV_INDE:   return (char_u *)&(curbuf->b_p_inde);
  case PV_INDK:   return (char_u *)&(curbuf->b_p_indk);
  case PV_FEX:    return (char_u *)&(curbuf->b_p_fex);
  case PV_LISP:   return (char_u *)&(curbuf->b_p_lisp);
  case PV_ML:     return (char_u *)&(curbuf->b_p_ml);
  case PV_MPS:    return (char_u *)&(curbuf->b_p_mps);
  case PV_MA:     return (char_u *)&(curbuf->b_p_ma);
  case PV_MOD:    return (char_u *)&(curbuf->b_changed);
  case PV_NF:     return (char_u *)&(curbuf->b_p_nf);
  case PV_PI:     return (char_u *)&(curbuf->b_p_pi);
  case PV_QE:     return (char_u *)&(curbuf->b_p_qe);
  case PV_RO:     return (char_u *)&(curbuf->b_p_ro);
  case PV_SCBK:   return (char_u *)&(curbuf->b_p_scbk);
  case PV_SI:     return (char_u *)&(curbuf->b_p_si);
  case PV_STS:    return (char_u *)&(curbuf->b_p_sts);
  case PV_SUA:    return (char_u *)&(curbuf->b_p_sua);
  case PV_SWF:    return (char_u *)&(curbuf->b_p_swf);
  case PV_SMC:    return (char_u *)&(curbuf->b_p_smc);
  case PV_SYN:    return (char_u *)&(curbuf->b_p_syn);
  case PV_SPC:    return (char_u *)&(curwin->w_s->b_p_spc);
  case PV_SPF:    return (char_u *)&(curwin->w_s->b_p_spf);
  case PV_SPL:    return (char_u *)&(curwin->w_s->b_p_spl);
  case PV_SW:     return (char_u *)&(curbuf->b_p_sw);
  case PV_TS:     return (char_u *)&(curbuf->b_p_ts);
  case PV_TW:     return (char_u *)&(curbuf->b_p_tw);
  case PV_UDF:    return (char_u *)&(curbuf->b_p_udf);
  case PV_WM:     return (char_u *)&(curbuf->b_p_wm);
  case PV_KMAP:   return (char_u *)&(curbuf->b_p_keymap);
  case PV_SCL:    return (char_u *)&(curwin->w_p_scl);
  case PV_WINHL:  return (char_u *)&(curwin->w_p_winhl);
  default:        IEMSG(_("E356: get_varp ERROR"));
  }
  /* always return a valid pointer to avoid a crash! */
  return (char_u *)&(curbuf->b_p_wm);
}

/*
 * Get the value of 'equalprg', either the buffer-local one or the global one.
 */
char_u *get_equalprg(void)
{
  if (*curbuf->b_p_ep == NUL)
    return p_ep;
  return curbuf->b_p_ep;
}

/*
 * Copy options from one window to another.
 * Used when splitting a window.
 */
void win_copy_options(win_T *wp_from, win_T *wp_to)
{
  copy_winopt(&wp_from->w_onebuf_opt, &wp_to->w_onebuf_opt);
  copy_winopt(&wp_from->w_allbuf_opt, &wp_to->w_allbuf_opt);
  /* Is this right? */
  wp_to->w_farsi = wp_from->w_farsi;
}

/*
 * Copy the options from one winopt_T to another.
 * Doesn't free the old option values in "to", use clear_winopt() for that.
 * The 'scroll' option is not copied, because it depends on the window height.
 * The 'previewwindow' option is reset, there can be only one preview window.
 */
void copy_winopt(winopt_T *from, winopt_T *to)
{
  to->wo_arab = from->wo_arab;
  to->wo_list = from->wo_list;
  to->wo_nu = from->wo_nu;
  to->wo_rnu = from->wo_rnu;
  to->wo_nuw = from->wo_nuw;
  to->wo_rl  = from->wo_rl;
  to->wo_rlc = vim_strsave(from->wo_rlc);
  to->wo_stl = vim_strsave(from->wo_stl);
  to->wo_wrap = from->wo_wrap;
  to->wo_wrap_save = from->wo_wrap_save;
  to->wo_lbr = from->wo_lbr;
  to->wo_bri = from->wo_bri;
  to->wo_briopt = vim_strsave(from->wo_briopt);
  to->wo_scb = from->wo_scb;
  to->wo_scb_save = from->wo_scb_save;
  to->wo_crb = from->wo_crb;
  to->wo_crb_save = from->wo_crb_save;
  to->wo_spell = from->wo_spell;
  to->wo_cuc = from->wo_cuc;
  to->wo_cul = from->wo_cul;
  to->wo_cc = vim_strsave(from->wo_cc);
  to->wo_diff = from->wo_diff;
  to->wo_diff_saved = from->wo_diff_saved;
  to->wo_cocu = vim_strsave(from->wo_cocu);
  to->wo_cole = from->wo_cole;
  to->wo_fdc = from->wo_fdc;
  to->wo_fdc_save = from->wo_fdc_save;
  to->wo_fen = from->wo_fen;
  to->wo_fen_save = from->wo_fen_save;
  to->wo_fdi = vim_strsave(from->wo_fdi);
  to->wo_fml = from->wo_fml;
  to->wo_fdl = from->wo_fdl;
  to->wo_fdl_save = from->wo_fdl_save;
  to->wo_fdm = vim_strsave(from->wo_fdm);
  to->wo_fdm_save = from->wo_diff_saved
                    ? vim_strsave(from->wo_fdm_save) : empty_option;
  to->wo_fdn = from->wo_fdn;
  to->wo_fde = vim_strsave(from->wo_fde);
  to->wo_fdt = vim_strsave(from->wo_fdt);
  to->wo_fmr = vim_strsave(from->wo_fmr);
  to->wo_scl = vim_strsave(from->wo_scl);
  to->wo_winhl = vim_strsave(from->wo_winhl);
  check_winopt(to);             // don't want NULL pointers
}

/*
 * Check string options in a window for a NULL value.
 */
void check_win_options(win_T *win)
{
  check_winopt(&win->w_onebuf_opt);
  check_winopt(&win->w_allbuf_opt);
}

/*
 * Check for NULL pointers in a winopt_T and replace them with empty_option.
 */
static void check_winopt(winopt_T *wop)
{
  check_string_option(&wop->wo_fdi);
  check_string_option(&wop->wo_fdm);
  check_string_option(&wop->wo_fdm_save);
  check_string_option(&wop->wo_fde);
  check_string_option(&wop->wo_fdt);
  check_string_option(&wop->wo_fmr);
  check_string_option(&wop->wo_scl);
  check_string_option(&wop->wo_rlc);
  check_string_option(&wop->wo_stl);
  check_string_option(&wop->wo_cc);
  check_string_option(&wop->wo_cocu);
  check_string_option(&wop->wo_briopt);
  check_string_option(&wop->wo_winhl);
}

/*
 * Free the allocated memory inside a winopt_T.
 */
void clear_winopt(winopt_T *wop)
{
  clear_string_option(&wop->wo_fdi);
  clear_string_option(&wop->wo_fdm);
  clear_string_option(&wop->wo_fdm_save);
  clear_string_option(&wop->wo_fde);
  clear_string_option(&wop->wo_fdt);
  clear_string_option(&wop->wo_fmr);
  clear_string_option(&wop->wo_scl);
  clear_string_option(&wop->wo_rlc);
  clear_string_option(&wop->wo_stl);
  clear_string_option(&wop->wo_cc);
  clear_string_option(&wop->wo_cocu);
  clear_string_option(&wop->wo_briopt);
  clear_string_option(&wop->wo_winhl);
}

void didset_window_options(win_T *wp)
{
  check_colorcolumn(wp);
  briopt_check(wp);
  parse_winhl_opt(wp);
}


/*
 * Copy global option values to local options for one buffer.
 * Used when creating a new buffer and sometimes when entering a buffer.
 * flags:
 * BCO_ENTER	We will enter the buf buffer.
 * BCO_ALWAYS	Always copy the options, but only set b_p_initialized when
 *		appropriate.
 * BCO_NOHELP	Don't copy the values to a help buffer.
 */
void buf_copy_options(buf_T *buf, int flags)
{
  int should_copy = TRUE;
  char_u      *save_p_isk = NULL;           /* init for GCC */
  int dont_do_help;
  int did_isk = FALSE;

  /*
   * Skip this when the option defaults have not been set yet.  Happens when
   * main() allocates the first buffer.
   */
  if (p_cpo != NULL) {
    /*
     * Always copy when entering and 'cpo' contains 'S'.
     * Don't copy when already initialized.
     * Don't copy when 'cpo' contains 's' and not entering.
     * 'S'	BCO_ENTER  initialized	's'  should_copy
     * yes	  yes	       X	 X	TRUE
     * yes	  no	      yes	 X	FALSE
     * no	   X	      yes	 X	FALSE
     *  X	  no	      no	yes	FALSE
     *  X	  no	      no	no	TRUE
     * no	  yes	      no	 X	TRUE
     */
    if ((vim_strchr(p_cpo, CPO_BUFOPTGLOB) == NULL || !(flags & BCO_ENTER))
        && (buf->b_p_initialized
            || (!(flags & BCO_ENTER)
                && vim_strchr(p_cpo, CPO_BUFOPT) != NULL)))
      should_copy = FALSE;

    if (should_copy || (flags & BCO_ALWAYS)) {
      /* Don't copy the options specific to a help buffer when
      * BCO_NOHELP is given or the options were initialized already
      * (jumping back to a help file with CTRL-T or CTRL-O) */
      dont_do_help = ((flags & BCO_NOHELP) && buf->b_help)
                     || buf->b_p_initialized;
      if (dont_do_help) {               /* don't free b_p_isk */
        save_p_isk = buf->b_p_isk;
        buf->b_p_isk = NULL;
      }
      /*
       * Always free the allocated strings.
       * If not already initialized, set 'readonly' and copy 'fileformat'.
       */
      if (!buf->b_p_initialized) {
        free_buf_options(buf, TRUE);
        buf->b_p_ro = FALSE;                    /* don't copy readonly */
        buf->b_p_fenc = vim_strsave(p_fenc);
        switch (*p_ffs) {
        case 'm':
          buf->b_p_ff = vim_strsave((char_u *)FF_MAC);
          break;
        case 'd':
          buf->b_p_ff = vim_strsave((char_u *)FF_DOS);
          break;
        case 'u':
          buf->b_p_ff = vim_strsave((char_u *)FF_UNIX);
          break;
        default:
          buf->b_p_ff = vim_strsave(p_ff);
        }
        if (buf->b_p_ff != NULL) {
          buf->b_start_ffc = *buf->b_p_ff;
        }
        buf->b_p_bh = empty_option;
        buf->b_p_bt = empty_option;
      } else
        free_buf_options(buf, FALSE);

      buf->b_p_ai = p_ai;
      buf->b_p_ai_nopaste = p_ai_nopaste;
      buf->b_p_sw = p_sw;
      buf->b_p_scbk = -1;
      buf->b_p_tw = p_tw;
      buf->b_p_tw_nopaste = p_tw_nopaste;
      buf->b_p_tw_nobin = p_tw_nobin;
      buf->b_p_wm = p_wm;
      buf->b_p_wm_nopaste = p_wm_nopaste;
      buf->b_p_wm_nobin = p_wm_nobin;
      buf->b_p_bin = p_bin;
      buf->b_p_bomb = p_bomb;
      buf->b_p_et = p_et;
      buf->b_p_fixeol = p_fixeol;
      buf->b_p_et_nobin = p_et_nobin;
      buf->b_p_et_nopaste = p_et_nopaste;
      buf->b_p_ml = p_ml;
      buf->b_p_ml_nobin = p_ml_nobin;
      buf->b_p_inf = p_inf;
      buf->b_p_swf = p_swf;
      buf->b_p_cpt = vim_strsave(p_cpt);
      buf->b_p_cfu = vim_strsave(p_cfu);
      buf->b_p_ofu = vim_strsave(p_ofu);
      buf->b_p_sts = p_sts;
      buf->b_p_sts_nopaste = p_sts_nopaste;
      buf->b_p_com = vim_strsave(p_com);
      buf->b_p_cms = vim_strsave(p_cms);
      buf->b_p_fo = vim_strsave(p_fo);
      buf->b_p_flp = vim_strsave(p_flp);
      buf->b_p_nf = vim_strsave(p_nf);
      buf->b_p_mps = vim_strsave(p_mps);
      buf->b_p_si = p_si;
      buf->b_p_channel = 0;
      buf->b_p_ci = p_ci;
      buf->b_p_cin = p_cin;
      buf->b_p_cink = vim_strsave(p_cink);
      buf->b_p_cino = vim_strsave(p_cino);
      /* Don't copy 'filetype', it must be detected */
      buf->b_p_ft = empty_option;
      buf->b_p_pi = p_pi;
      buf->b_p_cinw = vim_strsave(p_cinw);
      buf->b_p_lisp = p_lisp;
      /* Don't copy 'syntax', it must be set */
      buf->b_p_syn = empty_option;
      buf->b_p_smc = p_smc;
      buf->b_s.b_syn_isk = empty_option;
      buf->b_s.b_p_spc = vim_strsave(p_spc);
      (void)compile_cap_prog(&buf->b_s);
      buf->b_s.b_p_spf = vim_strsave(p_spf);
      buf->b_s.b_p_spl = vim_strsave(p_spl);
      buf->b_p_inde = vim_strsave(p_inde);
      buf->b_p_indk = vim_strsave(p_indk);
      buf->b_p_fp = empty_option;
      buf->b_p_fex = vim_strsave(p_fex);
      buf->b_p_sua = vim_strsave(p_sua);
      buf->b_p_keymap = vim_strsave(p_keymap);
      buf->b_kmap_state |= KEYMAP_INIT;
      /* This isn't really an option, but copying the langmap and IME
      * state from the current buffer is better than resetting it. */
      buf->b_p_iminsert = p_iminsert;
      buf->b_p_imsearch = p_imsearch;

      /* options that are normally global but also have a local value
       * are not copied, start using the global value */
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
      buf->b_p_inex = vim_strsave(p_inex);
      buf->b_p_dict = empty_option;
      buf->b_p_tsr = empty_option;
      buf->b_p_qe = vim_strsave(p_qe);
      buf->b_p_udf = p_udf;
      buf->b_p_lw = empty_option;
      buf->b_p_menc = empty_option;

      /*
       * Don't copy the options set by ex_help(), use the saved values,
       * when going from a help buffer to a non-help buffer.
       * Don't touch these at all when BCO_NOHELP is used and going from
       * or to a help buffer.
       */
      if (dont_do_help)
        buf->b_p_isk = save_p_isk;
      else {
        buf->b_p_isk = vim_strsave(p_isk);
        did_isk = true;
        buf->b_p_ts = p_ts;
        buf->b_help = false;
        if (buf->b_p_bt[0] == 'h')
          clear_string_option(&buf->b_p_bt);
        buf->b_p_ma = p_ma;
      }
    }

    /*
     * When the options should be copied (ignoring BCO_ALWAYS), set the
     * flag that indicates that the options have been initialized.
     */
    if (should_copy)
      buf->b_p_initialized = true;
  }

  check_buf_options(buf);           /* make sure we don't have NULLs */
  if (did_isk)
    (void)buf_init_chartab(buf, FALSE);
}

/*
 * Reset the 'modifiable' option and its default value.
 */
void reset_modifiable(void)
{
  int opt_idx;

  curbuf->b_p_ma = false;
  p_ma = false;
  opt_idx = findoption("ma");
  if (opt_idx >= 0) {
    options[opt_idx].def_val[VI_DEFAULT] = false;
  }
}

/*
 * Set the global value for 'iminsert' to the local value.
 */
void set_iminsert_global(void)
{
  p_iminsert = curbuf->b_p_iminsert;
}

/*
 * Set the global value for 'imsearch' to the local value.
 */
void set_imsearch_global(void)
{
  p_imsearch = curbuf->b_p_imsearch;
}

static int expand_option_idx = -1;
static char_u expand_option_name[5] = {'t', '_', NUL, NUL, NUL};
static int expand_option_flags = 0;

void 
set_context_in_set_cmd (
    expand_T *xp,
    char_u *arg,
    int opt_flags                  /* OPT_GLOBAL and/or OPT_LOCAL */
)
{
  char_u nextchar;
  uint32_t flags = 0;           /* init for GCC */
  int opt_idx = 0;              /* init for GCC */
  char_u      *p;
  char_u      *s;
  int is_term_option = FALSE;
  int key;

  expand_option_flags = opt_flags;

  xp->xp_context = EXPAND_SETTINGS;
  if (*arg == NUL) {
    xp->xp_pattern = arg;
    return;
  }
  p = arg + STRLEN(arg) - 1;
  if (*p == ' ' && *(p - 1) != '\\') {
    xp->xp_pattern = p + 1;
    return;
  }
  while (p > arg) {
    s = p;
    /* count number of backslashes before ' ' or ',' */
    if (*p == ' ' || *p == ',') {
      while (s > arg && *(s - 1) == '\\')
        --s;
    }
    /* break at a space with an even number of backslashes */
    if (*p == ' ' && ((p - s) & 1) == 0) {
      ++p;
      break;
    }
    --p;
  }
  if (STRNCMP(p, "no", 2) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 2;
  }
  if (STRNCMP(p, "inv", 3) == 0) {
    xp->xp_context = EXPAND_BOOL_SETTINGS;
    p += 3;
  }
  xp->xp_pattern = arg = p;
  if (*arg == '<') {
    while (*p != '>')
      if (*p++ == NUL)              /* expand terminal option name */
        return;
    key = get_special_key_code(arg + 1);
    if (key == 0) {                 /* unknown name */
      xp->xp_context = EXPAND_NOTHING;
      return;
    }
    nextchar = *++p;
    is_term_option = TRUE;
    expand_option_name[2] = (char_u)KEY2TERMCAP0(key);
    expand_option_name[3] = KEY2TERMCAP1(key);
  } else {
    if (p[0] == 't' && p[1] == '_') {
      p += 2;
      if (*p != NUL)
        ++p;
      if (*p == NUL)
        return;                 /* expand option name */
      nextchar = *++p;
      is_term_option = TRUE;
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
  /* handle "-=" and "+=" */
  if ((nextchar == '-' || nextchar == '+' || nextchar == '^') && p[1] == '=') {
    ++p;
    nextchar = '=';
  }
  if ((nextchar != '=' && nextchar != ':')
      || xp->xp_context == EXPAND_BOOL_SETTINGS) {
    xp->xp_context = EXPAND_UNSUCCESSFUL;
    return;
  }
  if (xp->xp_context != EXPAND_BOOL_SETTINGS && p[1] == NUL) {
    xp->xp_context = EXPAND_OLD_SETTING;
    if (is_term_option)
      expand_option_idx = -1;
    else
      expand_option_idx = opt_idx;
    xp->xp_pattern = p + 1;
    return;
  }
  xp->xp_context = EXPAND_NOTHING;
  if (is_term_option || (flags & P_NUM))
    return;

  xp->xp_pattern = p + 1;

  if (flags & P_EXPAND) {
    p = options[opt_idx].var;
    if (p == (char_u *)&p_bdir
        || p == (char_u *)&p_dir
        || p == (char_u *)&p_path
        || p == (char_u *)&p_pp
        || p == (char_u *)&p_rtp
        || p == (char_u *)&p_cdpath
        || p == (char_u *)&p_vdir
        ) {
      xp->xp_context = EXPAND_DIRECTORIES;
      if (p == (char_u *)&p_path
          || p == (char_u *)&p_cdpath
          )
        xp->xp_backslash = XP_BS_THREE;
      else
        xp->xp_backslash = XP_BS_ONE;
    } else {
      xp->xp_context = EXPAND_FILES;
      /* for 'tags' need three backslashes for a space */
      if (p == (char_u *)&p_tags)
        xp->xp_backslash = XP_BS_THREE;
      else
        xp->xp_backslash = XP_BS_ONE;
    }
  }

  /* For an option that is a list of file names, find the start of the
   * last file name. */
  for (p = arg + STRLEN(arg) - 1; p > xp->xp_pattern; --p) {
    /* count number of backslashes before ' ' or ',' */
    if (*p == ' ' || *p == ',') {
      s = p;
      while (s > xp->xp_pattern && *(s - 1) == '\\')
        --s;
      if ((*p == ' ' && (xp->xp_backslash == XP_BS_THREE && (p - s) < 3))
          || (*p == ',' && (flags & P_COMMA) && ((p - s) & 1) == 0)) {
        xp->xp_pattern = p + 1;
        break;
      }
    }

    /* for 'spellsuggest' start at "file:" */
    if (options[opt_idx].var == (char_u *)&p_sps
        && STRNCMP(p, "file:", 5) == 0) {
      xp->xp_pattern = p + 5;
      break;
    }
  }

  return;
}

int ExpandSettings(expand_T *xp, regmatch_T *regmatch, int *num_file, char_u ***file)
{
  int num_normal = 0;  // Nr of matching non-term-code settings
  int match;
  int count = 0;
  char_u      *str;
  int loop;
  static char *(names[]) = { "all" };
  int ic = regmatch->rm_ic;  // remember the ignore-case flag

  /* do this loop twice:
   * loop == 0: count the number of matching options
   * loop == 1: copy the matching options into allocated memory
   */
  for (loop = 0; loop <= 1; ++loop) {
    regmatch->rm_ic = ic;
    if (xp->xp_context != EXPAND_BOOL_SETTINGS) {
      for (match = 0; match < (int)ARRAY_SIZE(names);
           ++match)
        if (vim_regexec(regmatch, (char_u *)names[match], (colnr_T)0)) {
          if (loop == 0)
            num_normal++;
          else
            (*file)[count++] = vim_strsave((char_u *)names[match]);
        }
    }
    for (size_t opt_idx = 0; (str = (char_u *)options[opt_idx].fullname) != NULL;
         opt_idx++) {
      if (options[opt_idx].var == NULL)
        continue;
      if (xp->xp_context == EXPAND_BOOL_SETTINGS
          && !(options[opt_idx].flags & P_BOOL))
        continue;
      match = FALSE;
      if (vim_regexec(regmatch, str, (colnr_T)0)
          || (options[opt_idx].shortname != NULL
              && vim_regexec(regmatch,
                  (char_u *)options[opt_idx].shortname, (colnr_T)0))){
        match = TRUE;
      }

      if (match) {
        if (loop == 0) {
          num_normal++;
        } else
          (*file)[count++] = vim_strsave(str);
      }
    }

    if (loop == 0) {
      if (num_normal > 0) {
        *num_file = num_normal;
      } else {
        return OK;
      }
      *file = (char_u **)xmalloc((size_t)(*num_file) * sizeof(char_u *));
    }
  }
  return OK;
}

void ExpandOldSetting(int *num_file, char_u ***file)
{
  char_u *var = NULL;

  *num_file = 0;
  *file = (char_u **)xmalloc(sizeof(char_u *));

  /*
   * For a terminal key code expand_option_idx is < 0.
   */
  if (expand_option_idx < 0) {
    expand_option_idx = findoption((const char *)expand_option_name);
  }

  if (expand_option_idx >= 0) {
    /* put string of option value in NameBuff */
    option_value2string(&options[expand_option_idx], expand_option_flags);
    var = NameBuff;
  } else if (var == NULL)
    var = (char_u *)"";

  /* A backslash is required before some characters.  This is the reverse of
   * what happens in do_set(). */
  char_u *buf = vim_strsave_escaped(var, escape_chars);

#ifdef BACKSLASH_IN_FILENAME
  /* For MS-Windows et al. we don't double backslashes at the start and
   * before a file name character. */
  for (var = buf; *var != NUL; mb_ptr_adv(var))
    if (var[0] == '\\' && var[1] == '\\'
        && expand_option_idx >= 0
        && (options[expand_option_idx].flags & P_EXPAND)
        && vim_isfilec(var[2])
        && (var[2] != '\\' || (var == buf && var[4] != '\\')))
      STRMOVE(var, var + 1);
#endif

  *file[0] = buf;
  *num_file = 1;
}

/*
 * Get the value for the numeric or string option *opp in a nice format into
 * NameBuff[].  Must not be called with a hidden option!
 */
static void 
option_value2string (
    vimoption_T *opp,
    int opt_flags                          /* OPT_GLOBAL and/or OPT_LOCAL */
)
{
  char_u      *varp;

  varp = get_varp_scope(opp, opt_flags);

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
      home_replace(NULL, varp, NameBuff, MAXPATHL, false);
    // Translate 'pastetoggle' into special key names.
    } else if ((char_u **)opp->var == &p_pt) {
      str2specialbuf((const char *)p_pt, (char *)NameBuff, MAXPATHL);
    } else {
      STRLCPY(NameBuff, varp, MAXPATHL);
    }
  }
}

/*
 * Return TRUE if "varp" points to 'wildchar' or 'wildcharm' and it can be
 * printed as a keyname.
 * "*wcp" is set to the value of the option if it's 'wildchar' or 'wildcharm'.
 */
static int wc_use_keyname(char_u *varp, long *wcp)
{
  if (((long *)varp == &p_wc) || ((long *)varp == &p_wcm)) {
    *wcp = *(long *)varp;
    if (IS_SPECIAL(*wcp) || find_special_key_in_table((int)*wcp) >= 0)
      return TRUE;
  }
  return FALSE;
}

/*
 * Any character has an equivalent 'langmap' character.  This is used for
 * keyboards that have a special language mode that sends characters above
 * 128 (although other characters can be translated too).  The "to" field is a
 * Vim command character.  This avoids having to switch the keyboard back to
 * ASCII mode when leaving Insert mode.
 *
 * langmap_mapchar[] maps any of 256 chars to an ASCII char used for Vim
 * commands.
 * langmap_mapga.ga_data is a sorted table of langmap_entry_T. 
 * This does the same as langmap_mapchar[] for characters >= 256.
 */
/*
 * With multi-byte support use growarray for 'langmap' chars >= 256
 */
typedef struct {
  int from;
  int to;
} langmap_entry_T;

static garray_T langmap_mapga = GA_EMPTY_INIT_VALUE;

/*
 * Search for an entry in "langmap_mapga" for "from".  If found set the "to"
 * field.  If not found insert a new entry at the appropriate location.
 */
static void langmap_set_entry(int from, int to)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  unsigned int a = 0;
  assert(langmap_mapga.ga_len >= 0);
  unsigned int b = (unsigned int)langmap_mapga.ga_len;

  /* Do a binary search for an existing entry. */
  while (a != b) {
    unsigned int i = (a + b) / 2;
    int d = entries[i].from - from;

    if (d == 0) {
      entries[i].to = to;
      return;
    }
    if (d < 0)
      a = i + 1;
    else
      b = i;
  }

  ga_grow(&langmap_mapga, 1);

  /* insert new entry at position "a" */
  entries = (langmap_entry_T *)(langmap_mapga.ga_data) + a;
  memmove(entries + 1, entries,
          ((unsigned int)langmap_mapga.ga_len - a) * sizeof(langmap_entry_T));
  ++langmap_mapga.ga_len;
  entries[0].from = from;
  entries[0].to = to;
}

/*
 * Apply 'langmap' to multi-byte character "c" and return the result.
 */
int langmap_adjust_mb(int c)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  int a = 0;
  int b = langmap_mapga.ga_len;

  while (a != b) {
    int i = (a + b) / 2;
    int d = entries[i].from - c;

    if (d == 0)
      return entries[i].to;        /* found matching entry */
    if (d < 0)
      a = i + 1;
    else
      b = i;
  }
  return c;    /* no entry found, return "c" unmodified */
}

static void langmap_init(void)
{
  for (int i = 0; i < 256; i++)
    langmap_mapchar[i] = (char_u)i;      /* we init with a one-to-one map */
  ga_init(&langmap_mapga, sizeof(langmap_entry_T), 8);
}

/*
 * Called when langmap option is set; the language map can be
 * changed at any time!
 */
static void langmap_set(void)
{
  char_u  *p;
  char_u  *p2;
  int from, to;

  ga_clear(&langmap_mapga);                 /* clear the previous map first */
  langmap_init();                           /* back to one-to-one map */

  for (p = p_langmap; p[0] != NUL; ) {
    for (p2 = p; p2[0] != NUL && p2[0] != ',' && p2[0] != ';';
         mb_ptr_adv(p2)) {
      if (p2[0] == '\\' && p2[1] != NUL)
        ++p2;
    }
    if (p2[0] == ';')
      ++p2;                 /* abcd;ABCD form, p2 points to A */
    else
      p2 = NULL;            /* aAbBcCdD form, p2 is NULL */
    while (p[0]) {
      if (p[0] == ',') {
        ++p;
        break;
      }
      if (p[0] == '\\' && p[1] != NUL)
        ++p;
      from = (*mb_ptr2char)(p);
      to = NUL;
      if (p2 == NULL) {
        mb_ptr_adv(p);
        if (p[0] != ',') {
          if (p[0] == '\\')
            ++p;
          to = (*mb_ptr2char)(p);
        }
      } else {
        if (p2[0] != ',') {
          if (p2[0] == '\\')
            ++p2;
          to = (*mb_ptr2char)(p2);
        }
      }
      if (to == NUL) {
        EMSG2(_("E357: 'langmap': Matching character missing for %s"),
            transchar(from));
        return;
      }

      if (from >= 256)
        langmap_set_entry(from, to);
      else {
        assert(to <= UCHAR_MAX);
        langmap_mapchar[from & 255] = (char_u)to;
      }

      /* Advance to next pair */
      mb_ptr_adv(p);
      if (p2 != NULL) {
        mb_ptr_adv(p2);
        if (*p == ';') {
          p = p2;
          if (p[0] != NUL) {
            if (p[0] != ',') {
              EMSG2(_(
                      "E358: 'langmap': Extra characters after semicolon: %s"),
                  p);
              return;
            }
            ++p;
          }
          break;
        }
      }
    }
  }
}

/*
 * Return TRUE if format option 'x' is in effect.
 * Take care of no formatting when 'paste' is set.
 */
int has_format_option(int x)
{
  if (p_paste)
    return FALSE;
  return vim_strchr(curbuf->b_p_fo, x) != NULL;
}

/// @returns true if "x" is present in 'shortmess' option, or
/// 'shortmess' contains 'a' and "x" is present in SHM_ALL_ABBREVIATIONS.
bool shortmess(int x)
{
  return (p_shm != NULL
          && (vim_strchr(p_shm, x) != NULL
              || (vim_strchr(p_shm, 'a') != NULL
                  && vim_strchr((char_u *)SHM_ALL_ABBREVIATIONS, x) != NULL)));
}

/*
 * paste_option_changed() - Called after p_paste was set or reset.
 */
static void paste_option_changed(void)
{
  static int old_p_paste = FALSE;
  static int save_sm = 0;
  static int save_sta = 0;
  static int save_ru = 0;
  static int save_ri = 0;
  static int save_hkmap = 0;

  if (p_paste) {
    /*
     * Paste switched from off to on.
     * Save the current values, so they can be restored later.
     */
    if (!old_p_paste) {
      /* save options for each buffer */
      FOR_ALL_BUFFERS(buf) {
        buf->b_p_tw_nopaste = buf->b_p_tw;
        buf->b_p_wm_nopaste = buf->b_p_wm;
        buf->b_p_sts_nopaste = buf->b_p_sts;
        buf->b_p_ai_nopaste = buf->b_p_ai;
        buf->b_p_et_nopaste = buf->b_p_et;
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
  }
  /*
   * Paste switched from on to off: Restore saved values.
   */
  else if (old_p_paste) {
    /* restore options for each buffer */
    FOR_ALL_BUFFERS(buf) {
      buf->b_p_tw = buf->b_p_tw_nopaste;
      buf->b_p_wm = buf->b_p_wm_nopaste;
      buf->b_p_sts = buf->b_p_sts_nopaste;
      buf->b_p_ai = buf->b_p_ai_nopaste;
      buf->b_p_et = buf->b_p_et_nopaste;
    }

    /* restore global options */
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
  }

  old_p_paste = p_paste;
}

/// vimrc_found() - Called when a vimrc or "VIMINIT" has been found.
///
/// Set the values for options that didn't get set yet to the Vim defaults.
/// When "fname" is not NULL, use it to set $"envname" when it wasn't set yet.
void vimrc_found(char_u *fname, char_u *envname)
{
  char_u      *p;

  if (fname != NULL) {
    p = (char_u *)vim_getenv((char *)envname);
    if (p == NULL) {
      /* Set $MYVIMRC to the first vimrc file found. */
      p = (char_u *)FullName_save((char *)fname, FALSE);
      if (p != NULL) {
        vim_setenv((char *)envname, (char *)p);
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
static bool option_was_set(const char *name)
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

/*
 * fill_breakat_flags() -- called when 'breakat' changes value.
 */
static void fill_breakat_flags(void)
{
  char_u      *p;
  int i;

  for (i = 0; i < 256; i++)
    breakat_flags[i] = FALSE;

  if (p_breakat != NULL)
    for (p = p_breakat; *p; p++)
      breakat_flags[*p] = TRUE;
}

/*
 * Check an option that can be a range of string values.
 *
 * Return OK for correct value, FAIL otherwise.
 * Empty is always OK.
 */
static int check_opt_strings(
    char_u *val,
    char **values,
    int list                   /* when TRUE: accept a list of values */
)
{
  return opt_strings_flags(val, values, NULL, list);
}

/*
 * Handle an option that can be a range of string values.
 * Set a flag in "*flagp" for each string present.
 *
 * Return OK for correct value, FAIL otherwise.
 * Empty is always OK.
 */
static int opt_strings_flags(
    char_u *val,             /* new value */
    char **values,           /* array of valid string values */
    unsigned *flagp,
    bool list                /* when TRUE: accept a list of values */
)
{
  unsigned int new_flags = 0;

  while (*val) {
    for (unsigned int i = 0;; ++i) {
      if (values[i] == NULL)            /* val not found in values[] */
        return FAIL;

      size_t len = STRLEN(values[i]);
      if (STRNCMP(values[i], val, len) == 0
          && ((list && val[len] == ',') || val[len] == NUL)) {
        val += len + (val[len] == ',');
        assert(i < sizeof(1U) * 8);
        new_flags |= (1U << i);
        break;                  /* check next item in val list */
      }
    }
  }
  if (flagp != NULL)
    *flagp = new_flags;

  return OK;
}

/*
 * Read the 'wildmode' option, fill wim_flags[].
 */
static int check_opt_wim(void)
{
  char_u new_wim_flags[4];
  char_u      *p;
  int i;
  int idx = 0;

  for (i = 0; i < 4; ++i)
    new_wim_flags[i] = 0;

  for (p = p_wim; *p; ++p) {
    for (i = 0; ASCII_ISALPHA(p[i]); ++i)
      ;
    if (p[i] != NUL && p[i] != ',' && p[i] != ':')
      return FAIL;
    if (i == 7 && STRNCMP(p, "longest", 7) == 0)
      new_wim_flags[idx] |= WIM_LONGEST;
    else if (i == 4 && STRNCMP(p, "full", 4) == 0)
      new_wim_flags[idx] |= WIM_FULL;
    else if (i == 4 && STRNCMP(p, "list", 4) == 0)
      new_wim_flags[idx] |= WIM_LIST;
    else
      return FAIL;
    p += i;
    if (*p == NUL)
      break;
    if (*p == ',') {
      if (idx == 3)
        return FAIL;
      ++idx;
    }
  }

  /* fill remaining entries with last flag */
  while (idx < 3) {
    new_wim_flags[idx + 1] = new_wim_flags[idx];
    ++idx;
  }

  /* only when there are no errors, wim_flags[] is changed */
  for (i = 0; i < 4; ++i)
    wim_flags[i] = new_wim_flags[i];
  return OK;
}

/*
 * Check if backspacing over something is allowed.
 * The parameter what is one of the following: whatBS_INDENT, BS_EOL 
 * or BS_START
 */
bool can_bs(int what)
{
  switch (*p_bs) {
  case '2':       return TRUE;
  case '1':       return what != BS_START;
  case '0':       return FALSE;
  }
  return vim_strchr(p_bs, what) != NULL;
}

/*
 * Save the current values of 'fileformat' and 'fileencoding', so that we know
 * the file must be considered changed when the value is different.
 */
void save_file_ff(buf_T *buf)
{
  buf->b_start_ffc = *buf->b_p_ff;
  buf->b_start_eol = buf->b_p_eol;
  buf->b_start_bomb = buf->b_p_bomb;

  /* Only use free/alloc when necessary, they take time. */
  if (buf->b_start_fenc == NULL
      || STRCMP(buf->b_start_fenc, buf->b_p_fenc) != 0) {
    xfree(buf->b_start_fenc);
    buf->b_start_fenc = vim_strsave(buf->b_p_fenc);
  }
}

/*
 * Return TRUE if 'fileformat' and/or 'fileencoding' has a different value
 * from when editing started (save_file_ff() called).
 * Also when 'endofline' was changed and 'binary' is set, or when 'bomb' was
 * changed and 'binary' is not set.
 * Also when 'endofline' was changed and 'fixeol' is not set.
 * When "ignore_empty" is true don't consider a new, empty buffer to be
 * changed.
 */
bool file_ff_differs(buf_T *buf, bool ignore_empty)
{
  /* In a buffer that was never loaded the options are not valid. */
  if (buf->b_flags & BF_NEVERLOADED)
    return FALSE;
  if (ignore_empty
      && (buf->b_flags & BF_NEW)
      && buf->b_ml.ml_line_count == 1
      && *ml_get_buf(buf, (linenr_T)1, FALSE) == NUL)
    return FALSE;
  if (buf->b_start_ffc != *buf->b_p_ff)
    return true;
  if ((buf->b_p_bin || !buf->b_p_fixeol) && buf->b_start_eol != buf->b_p_eol)
    return true;
  if (!buf->b_p_bin && buf->b_start_bomb != buf->b_p_bomb)
    return TRUE;
  if (buf->b_start_fenc == NULL)
    return *buf->b_p_fenc != NUL;
  return STRCMP(buf->b_start_fenc, buf->b_p_fenc) != 0;
}

/*
 * return OK if "p" is a valid fileformat name, FAIL otherwise.
 */
int check_ff_value(char_u *p)
{
  return check_opt_strings(p, p_ff_values, FALSE);
}

/*
 * Return the effective shiftwidth value for current buffer, using the
 * 'tabstop' value when 'shiftwidth' is zero.
 */
int get_sw_value(buf_T *buf)
{
  long result = buf->b_p_sw ? buf->b_p_sw : buf->b_p_ts;
  assert(result >= 0 && result <= INT_MAX);
  return (int)result;
}

// Return the effective softtabstop value for the current buffer,
// using the effective shiftwidth  value when 'softtabstop' is negative.
int get_sts_value(void)
{
  long result = curbuf->b_p_sts < 0 ? get_sw_value(curbuf) : curbuf->b_p_sts;
  assert(result >= 0 && result <= INT_MAX);
  return (int)result;
}

/*
 * Check matchpairs option for "*initc".
 * If there is a match set "*initc" to the matching character and "*findc" to
 * the opposite character.  Set "*backwards" to the direction.
 * When "switchit" is TRUE swap the direction.
 */
void find_mps_values(int *initc, int *findc, int *backwards, int switchit)
{
  char_u      *ptr;

  ptr = curbuf->b_p_mps;
  while (*ptr != NUL) {
    if (has_mbyte) {
      char_u *prev;

      if (mb_ptr2char(ptr) == *initc) {
        if (switchit) {
          *findc = *initc;
          *initc = mb_ptr2char(ptr + mb_ptr2len(ptr) + 1);
          *backwards = TRUE;
        } else {
          *findc = mb_ptr2char(ptr + mb_ptr2len(ptr) + 1);
          *backwards = FALSE;
        }
        return;
      }
      prev = ptr;
      ptr += mb_ptr2len(ptr) + 1;
      if (mb_ptr2char(ptr) == *initc) {
        if (switchit) {
          *findc = *initc;
          *initc = mb_ptr2char(prev);
          *backwards = FALSE;
        } else {
          *findc = mb_ptr2char(prev);
          *backwards = TRUE;
        }
        return;
      }
      ptr += mb_ptr2len(ptr);
    } else {
      if (*ptr == *initc) {
        if (switchit) {
          *backwards = TRUE;
          *findc = *initc;
          *initc = ptr[2];
        } else {
          *backwards = FALSE;
          *findc = ptr[2];
        }
        return;
      }
      ptr += 2;
      if (*ptr == *initc) {
        if (switchit) {
          *backwards = FALSE;
          *findc = *initc;
          *initc = ptr[-2];
        } else {
          *backwards = TRUE;
          *findc =  ptr[-2];
        }
        return;
      }
      ++ptr;
    }
    if (*ptr == ',')
      ++ptr;
  }
}

/// This is called when 'breakindentopt' is changed and when a window is
/// initialized
static bool briopt_check(win_T *wp)
{
  int bri_shift = 0;
  int bri_min = 20;
  bool bri_sbr = false;

  char_u *p = wp->w_p_briopt;
  while (*p != NUL)
  {
    if (STRNCMP(p, "shift:", 6) == 0
        && ((p[6] == '-' && ascii_isdigit(p[7])) || ascii_isdigit(p[6])))
    {
      p += 6;
      bri_shift = getdigits_int(&p);
    }
    else if (STRNCMP(p, "min:", 4) == 0 && ascii_isdigit(p[4]))
    {
      p += 4;
      bri_min = getdigits_int(&p);
    }
    else if (STRNCMP(p, "sbr", 3) == 0)
    {
      p += 3;
      bri_sbr = true;
    }
    if (*p != ',' && *p != NUL)
      return false;
    if (*p == ',')
      ++p;
  }

  wp->w_p_brishift = bri_shift;
  wp->w_p_brimin   = bri_min;
  wp->w_p_brisbr   = bri_sbr;

  return true;
}

/// Get the local or global value of 'backupcopy'.
///
/// @param buf The buffer.
unsigned int get_bkc_value(buf_T *buf)
{
  return buf->b_bkc_flags ? buf->b_bkc_flags : bkc_flags;
}

/// Return the current end-of-line type: EOL_DOS, EOL_UNIX or EOL_MAC.
int get_fileformat(buf_T *buf)
{
  int c = *buf->b_p_ff;

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
int get_fileformat_force(buf_T *buf, exarg_T *eap)
{
  int c;

  if (eap != NULL && eap->force_ff != 0) {
    c = eap->cmd[eap->force_ff];
  } else {
    if ((eap != NULL && eap->force_bin != 0)
        ? (eap->force_bin == FORCE_BIN) : buf->b_p_bin) {
      return EOL_UNIX;
    }
    c = *buf->b_p_ff;
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
  case 'm':   return EOL_MAC;
  case 'd':   return EOL_DOS;
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
    set_string_option_direct((char_u *)"ff",
                             -1,
                             (char_u *)p,
                             OPT_FREE | opt_flags,
                             0);
  }

  // This may cause the buffer to become (un)modified.
  check_status(curbuf);
  redraw_tabline = true;
  need_maketitle = true;  // Set window title later.
}

/// Skip to next part of an option argument: skip space and comma
char_u *skip_to_option_part(const char_u *p)
{
  if (*p == ',') {
    p++;
  }
  while (*p == ' ') {
    p++;
  }
  return (char_u *)p;
}

/// Isolate one part of a string option separated by `sep_chars`.
///
/// @param[in,out]  option    advanced to the next part
/// @param[in,out]  buf       copy of the isolated part
/// @param[in]      maxlen    length of `buf`
/// @param[in]      sep_chars chars that separate the option parts
///
/// @return length of `*option`
size_t copy_option_part(char_u **option, char_u *buf, size_t maxlen,
                        char *sep_chars)
{
  size_t len = 0;
  char_u  *p = *option;

  // skip '.' at start of option part, for 'suffixes'
  if (*p == '.') {
    buf[len++] = *p++;
  }
  while (*p != NUL && vim_strchr((char_u *)sep_chars, *p) == NULL) {
    // Skip backslash before a separator character and space.
    if (p[0] == '\\' && vim_strchr((char_u *)sep_chars, p[1]) != NULL) {
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

/// Return TRUE when 'shell' has "csh" in the tail.
int csh_like_shell(void)
{
  return strstr((char *)path_tail(p_sh), "csh") != NULL;
}

/// Return true when window "wp" has a column to draw signs in.
bool signcolumn_on(win_T *wp)
{
    if (*wp->w_p_scl == 'n') {
      return false;
    }
    if (*wp->w_p_scl == 'y') {
      return true;
    }
    return wp->w_buffer->b_signlist != NULL;
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
