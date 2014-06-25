/// @file version.c
///
/// Vim originated from Stevie version 3.6 (Fish disk 217) by GRWalter (Fred)
/// It has been changed beyond recognition since then.
///
/// Differences between version 6.x and 7.x can be found with ":help version7".
/// Differences between version 5.x and 6.x can be found with ":help version6".
/// Differences between version 4.x and 5.x can be found with ":help version5".
/// Differences between version 3.0 and 4.x can be found with ":help version4".
/// All the remarks about older versions have been removed, they are not very
/// interesting.

#include "nvim/vim.h"
#include "nvim/version.h"
#include "nvim/charset.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc2.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/version_defs.h"

char *Version = VIM_VERSION_SHORT;
static char *mediumVersion = VIM_VERSION_MEDIUM;

char *longVersion = VIM_VERSION_LONG_DATE __DATE__ " " __TIME__ ")";


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "version.c.generated.h"
#endif
static char *(features[]) = {
#ifdef HAVE_ACL
  "+acl",
#else  // ifdef HAVE_ACL
  "-acl",
#endif  // ifdef HAVE_ACL
  "+arabic",
  "+autocmd",
  "-browse",
#ifdef NO_BUILTIN_TCAPS
  "-builtin_terms",
#endif  // ifdef NO_BUILTIN_TCAPS
#ifdef SOME_BUILTIN_TCAPS
  "+builtin_terms",
#endif  // ifdef SOME_BUILTIN_TCAPS
#ifdef ALL_BUILTIN_TCAPS
  "++builtin_terms",
#endif  // ifdef ALL_BUILTIN_TCAPS
  "+byte_offset",
  "+cindent",
  "-clipboard",
  "+cmdline_compl",
  "+cmdline_hist",
  "+cmdline_info",
  "+comments",
  "+conceal",
  "+cscope",
  "+cursorbind",
#ifdef CURSOR_SHAPE
  "+cursorshape",
#else  // ifdef CURSOR_SHAPE
  "-cursorshape",
#endif  // ifdef CURSOR_SHAPE
  "+dialog_con",
  "+diff",
  "+digraphs",
  "-dnd",
  "-ebcdic",
  "-emacs_tags",
  "+eval",
  "+ex_extra",
  "+extra_search",
  "+farsi",
  "+file_in_path",
  "+find_in_path",
  "+float",
  "+folding",
  "-footer",

  // only interesting on Unix systems
#if defined(UNIX)
  "+fork()",
#endif  // if defined(UNIX)
  "+gettext",
#if (defined(HAVE_ICONV_H) && defined(USE_ICONV)) || defined(DYNAMIC_ICONV)
# ifdef DYNAMIC_ICONV
  "+iconv/dyn",
# else  // ifdef DYNAMIC_ICONV
  "+iconv",
# endif  // ifdef DYNAMIC_ICONV
#else  // if (defined(HAVE_ICONV_H) && defined(USE_ICONV))
       //    ||defined(DYNAMIC_ICONV)
  "-iconv",
#endif  // if (defined(HAVE_ICONV_H) && defined(USE_ICONV))
        //    || defined(DYNAMIC_ICONV)
  "+insert_expand",
  "+jumplist",
  "+keymap",
  "+langmap",
#ifdef FEAT_LIBCALL
  "+libcall",
#else   // ifdef FEAT_LIBCALL
  "-libcall",
#endif  // ifdef FEAT_LIBCALL
  "+linebreak",
  "+lispindent",
  "+listcmds",
  "+localmap",
  "+menu",
  "+mksession",
  "+modify_fname",
  "+mouse",
  "-mouseshape",

#if defined(UNIX)
  "+mouse_dec",
  "-mouse_gpm",
# ifdef FEAT_MOUSE_JSB
  "+mouse_jsbterm",
# else  // ifdef FEAT_MOUSE_JSB
  "-mouse_jsbterm",
# endif  // ifdef FEAT_MOUSE_JSB
  "+mouse_netterm",
#endif  // if defined(UNIX)


#if defined(UNIX)
  "+mouse_sgr",
  "-mouse_sysmouse",
  "+mouse_urxvt",
  "+mouse_xterm",
#endif  // if defined(UNIX)

  "+multi_byte",
  "+multi_lang",
  "+path_extra",
  "+persistent_undo",
  "+postscript",
  "+printer",
  "+profile",
  "+quickfix",
  "+reltime",
  "+rightleft",
  "+scrollbind",
  "+signs",
  "+smartindent",
#ifdef STARTUPTIME
  "+startuptime",
#else  // ifdef STARTUPTIME
  "-startuptime",
#endif  // ifdef STARTUPTIME
  "+statusline",
  "+syntax",
  "+tag_binary",
  "+tag_old_static",
#ifdef FEAT_TAG_ANYWHITE
  "+tag_any_white",
#else  // ifdef FEAT_TAG_ANYWHITE
  "-tag_any_white",
#endif  // ifdef FEAT_TAG_ANYWHITE
#if defined(UNIX)

  // only Unix can have terminfo instead of termcap
# ifdef TERMINFO
  "+terminfo",
# else // ifdef TERMINFO
  "-terminfo",
# endif // ifdef TERMINFO
#else   // unix always includes termcap support
# ifdef HAVE_TGETENT
  "+tgetent",
# else  // ifdef HAVE_TGETENT
  "-tgetent",
# endif  // ifdef HAVE_TGETENT
#endif  // if defined(UNIX)
  "+termresponse",
  "+textobjects",
  "+title",
  "-toolbar",
  "+user_commands",
  "+vertsplit",
  "+virtualedit",
  "+visual",
  "+visualextra",
  "+viminfo",
  "+vreplace",
  "+wildignore",
  "+wildmenu",
  "+windows",
  "+writebackup",
#if defined(UNIX)
  "-X11",
#endif  // if defined(UNIX)
  "-xfontset",
#if defined(UNIX)
  "-xsmp",
  "-xterm_clipboard",
#endif  // if defined(UNIX)
  NULL
};

static int included_patches[] = {
  // Add new patch number below this line
  //316,
  //315,
  //314,
  //313,
  //312,
  //311,
  //310,
  //309,
  //308,
  //307,
  //306,
  //305,
  //304,
  //303,
  //302,
  //301,
  //300,
  //299,
  //298,
  //297,
  //296,
  //295,
  //294,
  //293,
  292,
  //291,
  290,
  289,
  288,
  //287,
  286,
  285,
  284,
  //283,
  282,
  281,
  280,
  //279,
  //278,
  277,
  //276,
  275,
  274,
  //273,
  272,
  //271,
  //270,
  269,
  268,
  267,
  266,
  265,
  264,
  //263,
  262,
  261,
  260,
  //259,
  //258,
  //257,
  //256,
  //255,
  //254,
  253,
  //252,
  251,
  //250,
  //249,
  //248,
  //247,
  //246,
  245,
  //244,
  //243,
  //242,
  241,
  240,
  239,
  //238,
  237,
  236,
  //235,
  234,
  233,
  232,
  //231,
  //230,
  229,
  //228,
  //227,
  226,
  //225,
  //224,
  //223,
  //222,
  221,
  //220,
  219,
  218,
  //217,
  //216,
  215,
  //214,
  213,
  //212,
  //211,
  210,
  209,
  //208,
  207,
  //206,
  205,
  204,
  203,
  //202,
  //201,
  //200,
  199,
  //198,
  //197,
  //196,
  //195,
  //194,
  193,
  192,
  191,
  //190,
  //189,
  //188,
  187,
  186,
  //185,
  184,
  //183,
  //182,
  181,
  //180,
  //179,
  178,
  //177,
  //176,
  //175,
  //174,
  173,
  172,
  171,
  170,
  169,
  //168,
  167,
  166,
  //165,
  //164,
  //163,
  //162,
  //161,
  160,
  159,
  158,
  157,
  156,
  155,
  154,
  153,
  152,
  151,
  150,
  149,
  148,
  147,
  146,
  145,
  144,
  143,
  142,
  141,
  140,
  139,
  138,
  137,
  136,
  135,
  134,
  133,
  132,
  131,
  130,
  129,
  128,
  127,
  126,
  125,
  124,
  123,
  122,
  121,
  120,
  119,
  118,
  117,
  116,
  115,
  114,
  113,
  112,
  111,
  110,
  109,
  108,
  107,
  106,
  105,
  104,
  103,
  102,
  101,
  100,
  99,
  98,
  97,
  96,
  95,
  94,
  93,
  92,
  91,
  90,
  89,
  88,
  87,
  86,
  85,
  84,
  83,
  82,
  81,
  80,
  79,
  78,
  77,
  76,
  75,
  74,
  73,
  72,
  71,
  70,
  69,
  68,
  67,
  66,
  65,
  64,
  63,
  62,
  61,
  60,
  59,
  58,
  57,
  56,
  55,
  54,
  53,
  52,
  51,
  50,
  49,
  48,
  47,
  46,
  45,
  44,
  43,
  42,
  41,
  40,
  39,
  38,
  37,
  36,
  35,
  34,
  33,
  32,
  31,
  30,
  29,
  28,
  27,
  26,
  25,
  24,
  23,
  22,
  21,
  20,
  19,
  18,
  17,
  16,
  15,
  14,
  13,
  12,
  11,
  10,
  9,
  8,
  7,
  6,
  5,
  4,
  3,
  2,
  1,
  0
};

/// Place to put a short description when adding a feature with a patch.
/// Keep it short, e.g.,: "relative numbers", "persistent undo".
/// Also add a comment marker to separate the lines.
/// See the official Vim patches for the diff format: It must use a context of
/// one line only.  Create it by hand or use "diff -C2" and edit the patch.
static char *(extra_patches[]) = {
  // Add your patch description below this line
  NULL
};

int highest_patch(void)
{
  int i;
  int h = 0;

  for (i = 0; included_patches[i] != 0; ++i) {
    if (included_patches[i] > h) {
      h = included_patches[i];
    }
  }
  return h;
}

/// Checks whether patch `n` has been included.
///
/// @param n The patch number.
///
/// @return TRUE if patch "n" has been included.
int has_patch(int n)
{
  int i;
  for (i = 0; included_patches[i] != 0; ++i) {
    if (included_patches[i] == n) {
      return TRUE;
    }
  }
  return FALSE;
}

void ex_version(exarg_T *eap)
{
  // Ignore a ":version 9.99" command.
  if (*eap->arg == NUL) {
    msg_putchar('\n');
    list_version();
  }
}

/// List all features aligned in columns, dictionary style.
static void list_features(void)
{
  int nfeat = 0;
  int width = 0;

  // Find the length of the longest feature name, use that + 1 as the column
  // width
  int i;
  for (i = 0; features[i] != NULL; ++i) {
    int l = (int)STRLEN(features[i]);

    if (l > width) {
      width = l;
    }
    nfeat++;
  }
  width += 1;

  if (Columns < width) {
    // Not enough screen columns - show one per line
    for (i = 0; features[i] != NULL; ++i) {
      version_msg(features[i]);
      if (msg_col > 0) {
        msg_putchar('\n');
      }
    }
    return;
  }

  // The rightmost column doesn't need a separator.
  // Sacrifice it to fit in one more column if possible.
  int ncol = (int)(Columns + 1) / width;
  int nrow = nfeat / ncol + (nfeat % ncol ? 1 : 0);

  // i counts columns then rows.  idx counts rows then columns.
  for (i = 0; !got_int && i < nrow * ncol; ++i) {
    int idx = (i / ncol) + (i % ncol) * nrow;
    if (idx < nfeat) {
      int last_col = (i + 1) % ncol == 0;
      msg_puts((char_u *)features[idx]);
      if (last_col) {
        if (msg_col > 0) {
          msg_putchar('\n');
        }
      } else {
        while (msg_col % width) {
          msg_putchar(' ');
        }
      }
    } else {
      if (msg_col > 0) {
        msg_putchar('\n');
      }
    }
  }
}

void list_version(void)
{
  int i;
  int first;
  char *s = "";

  // When adding features here, don't forget to update the list of
  // internal variables in eval.c!
  MSG(longVersion);

  // Print the list of patch numbers if there is at least one.
  // Print a range when patches are consecutive: "1-10, 12, 15-40, 42-45"
  if (included_patches[0] != 0) {
    MSG_PUTS(_("\nIncluded patches: "));
    first = -1;

    // find last one
    for (i = 0; included_patches[i] != 0; ++i) {}

    while (--i >= 0) {
      if (first < 0) {
        first = included_patches[i];
      }

      if ((i == 0) || (included_patches[i - 1] != included_patches[i] + 1)) {
        MSG_PUTS(s);
        s = ", ";
        msg_outnum((long)first);

        if (first != included_patches[i]) {
          MSG_PUTS("-");
          msg_outnum((long)included_patches[i]);
        }
        first = -1;
      }
    }
  }

  // Print the list of extra patch descriptions if there is at least one.
  if (extra_patches[0] != NULL) {
    MSG_PUTS(_("\nExtra patches: "));
    s = "";

    for (i = 0; extra_patches[i] != NULL; ++i) {
      MSG_PUTS(s);
      s = ", ";
      MSG_PUTS(extra_patches[i]);
    }
  }

#ifdef MODIFIED_BY
  MSG_PUTS("\n");
  MSG_PUTS(_("Modified by "));
  MSG_PUTS(MODIFIED_BY);
#endif  // ifdef MODIFIED_BY

#ifdef HAVE_PATHDEF

  if ((*compiled_user != NUL) || (*compiled_sys != NUL)) {
    MSG_PUTS(_("\nCompiled "));

    if (*compiled_user != NUL) {
      MSG_PUTS(_("by "));
      MSG_PUTS(compiled_user);
    }

    if (*compiled_sys != NUL) {
      MSG_PUTS("@");
      MSG_PUTS(compiled_sys);
    }
  }
#endif  // ifdef HAVE_PATHDEF

  MSG_PUTS(_("\nHuge version "));
  MSG_PUTS(_("without GUI."));
  version_msg(_("  Features included (+) or not (-):\n"));

  list_features();

#ifdef SYS_VIMRC_FILE
  version_msg(_("   system vimrc file: \""));
  version_msg(SYS_VIMRC_FILE);
  version_msg("\"\n");
#endif  // ifdef SYS_VIMRC_FILE
#ifdef USR_VIMRC_FILE
  version_msg(_("     user vimrc file: \""));
  version_msg(USR_VIMRC_FILE);
  version_msg("\"\n");
#endif  // ifdef USR_VIMRC_FILE
#ifdef USR_VIMRC_FILE2
  version_msg(_(" 2nd user vimrc file: \""));
  version_msg(USR_VIMRC_FILE2);
  version_msg("\"\n");
#endif  // ifdef USR_VIMRC_FILE2
#ifdef USR_VIMRC_FILE3
  version_msg(_(" 3rd user vimrc file: \""));
  version_msg(USR_VIMRC_FILE3);
  version_msg("\"\n");
#endif  // ifdef USR_VIMRC_FILE3
#ifdef USR_EXRC_FILE
  version_msg(_("      user exrc file: \""));
  version_msg(USR_EXRC_FILE);
  version_msg("\"\n");
#endif  // ifdef USR_EXRC_FILE
#ifdef USR_EXRC_FILE2
  version_msg(_("  2nd user exrc file: \""));
  version_msg(USR_EXRC_FILE2);
  version_msg("\"\n");
#endif  // ifdef USR_EXRC_FILE2
#ifdef HAVE_PATHDEF

  if (*default_vim_dir != NUL) {
    version_msg(_("  fall-back for $VIM: \""));
    version_msg((char *)default_vim_dir);
    version_msg("\"\n");
  }

  if (*default_vimruntime_dir != NUL) {
    version_msg(_(" f-b for $VIMRUNTIME: \""));
    version_msg((char *)default_vimruntime_dir);
    version_msg("\"\n");
  }
  version_msg(_("Compilation: "));
  version_msg((char *)all_cflags);
  version_msg("\n");
  version_msg(_("Linking: "));
  version_msg((char *)all_lflags);
#endif  // ifdef HAVE_PATHDEF
#ifdef DEBUG
  version_msg("\n");
  version_msg(_("  DEBUG BUILD"));
#endif  // ifdef DEBUG
}

/// Output a string for the version message.  If it's going to wrap, output a
/// newline, unless the message is too long to fit on the screen anyway.
///
/// @param s
static void version_msg(char *s)
{
  int len = (int)STRLEN(s);

  if (!got_int
      && (len < (int)Columns)
      && (msg_col + len >= (int)Columns)
      && (*s != '\n')) {
    msg_putchar('\n');
  }

  if (!got_int) {
    MSG_PUTS(s);
  }
}


/// Show the intro message when not editing a file.
void maybe_intro_message(void)
{
  if (bufempty()
      && (curbuf->b_fname == NULL)
      && (firstwin->w_next == NULL)
      && (vim_strchr(p_shm, SHM_INTRO) == NULL)) {
    intro_message(FALSE);
  }
}

/// Give an introductory message about Vim.
/// Only used when starting Vim on an empty file, without a file name.
/// Or with the ":intro" command (for Sven :-).
///
/// @param colon TRUE for ":intro"
void intro_message(int colon)
{
  int i;
  int row;
  int blanklines;
  int sponsor;
  char *p;
  static char *(lines[]) = {
    N_("VIM - Vi IMproved"),
    "",
    N_("version "),
    N_("by Bram Moolenaar et al."),
#ifdef MODIFIED_BY
    " ",
#endif  // ifdef MODIFIED_BY
    N_("Vim is open source and freely distributable"),
    "",
    N_("Help poor children in Uganda!"),
    N_("type  :help iccf<Enter>       for information "),
    "",
    N_("type  :q<Enter>               to exit         "),
    N_("type  :help<Enter>  or  <F1>  for on-line help"),
    N_("type  :help version7<Enter>   for version info"),
    NULL,
    "",
    N_("Running in Vi compatible mode"),
    N_("type  :set nocp<Enter>        for Vim defaults"),
    N_("type  :help cp-default<Enter> for info on this"),
  };

  // blanklines = screen height - # message lines
  blanklines = (int)Rows - ((sizeof(lines) / sizeof(char *)) - 1);

  if (!p_cp) {
    // add 4 for not showing "Vi compatible" message
    blanklines += 4;
  }

  // Don't overwrite a statusline.  Depends on 'cmdheight'.
  if (p_ls > 1) {
    blanklines -= Rows - topframe->fr_height;
  }

  if (blanklines < 0) {
    blanklines = 0;
  }

  // Show the sponsor and register message one out of four times, the Uganda
  // message two out of four times.
  sponsor = (int)time(NULL);
  sponsor = ((sponsor & 2) == 0) - ((sponsor & 4) == 0);

  // start displaying the message lines after half of the blank lines
  row = blanklines / 2;

  if (((row >= 2) && (Columns >= 50)) || colon) {
    for (i = 0; i < (int)(sizeof(lines) / sizeof(char *)); ++i) {
      p = lines[i];
      if (p == NULL) {
        if (!p_cp) {
          break;
        }
        continue;
      }

      if (sponsor != 0) {
        if (strstr(p, "children") != NULL) {
          p = sponsor < 0
              ? N_("Sponsor Vim development!")
              : N_("Become a registered Vim user!");
        } else if (strstr(p, "iccf") != NULL) {
          p = sponsor < 0
              ? N_("type  :help sponsor<Enter>    for information ")
              : N_("type  :help register<Enter>   for information ");
        } else if (strstr(p, "Orphans") != NULL) {
          p = N_("menu  Help->Sponsor/Register  for information    ");
        }
      }

      if (*p != NUL) {
        do_intro_line(row, (char_u *)_(p), i == 2, 0);
      }
      row++;
    }
  }

  // Make the wait-return message appear just below the text.
  if (colon) {
    msg_row = row;
  }
}

static void do_intro_line(int row, char_u *mesg, int add_version, int attr)
{
  char_u vers[20];
  int col;
  char_u *p;
  int l;
  int clen;

#ifdef MODIFIED_BY
# define MODBY_LEN 150
  char_u modby[MODBY_LEN];

  if (*mesg == ' ') {
    l = STRLCPY(modby, _("Modified by "), MODBY_LEN);
    if (l < MODBY_LEN - 1) {
      STRLCPY(modby + l, MODIFIED_BY, MODBY_LEN - l);
    }
    mesg = modby;
  }
#endif  // ifdef MODIFIED_BY

  // Center the message horizontally.
  col = vim_strsize(mesg);

  if (add_version) {
    STRCPY(vers, mediumVersion);

    if (highest_patch()) {
      // Check for 9.9x or 9.9xx, alpha/beta version
      if (isalpha((int)vers[3])) {
        int len = (isalpha((int)vers[4])) ? 5 : 4;
        sprintf((char *)vers + len, ".%d%s", highest_patch(),
                mediumVersion + len);
      } else {
        sprintf((char *)vers + 3,   ".%d",   highest_patch());
      }
    }
    col += (int)STRLEN(vers);
  }
  col = (Columns - col) / 2;

  if (col < 0) {
    col = 0;
  }

  // Split up in parts to highlight <> items differently.
  for (p = mesg; *p != NUL; p += l) {
    clen = 0;

    for (l = 0; p[l] != NUL
         && (l == 0 || (p[l] != '<' && p[l - 1] != '>')); ++l) {
      if (has_mbyte) {
        clen += ptr2cells(p + l);
        l += (*mb_ptr2len)(p + l) - 1;
      } else {
        clen += byte2cells(p[l]);
      }
    }
    screen_puts_len(p, l, row, col, *p == '<' ? hl_attr(HLF_8) : attr);
    col += clen;
  }

  // Add the version number to the version line.
  if (add_version) {
    screen_puts(vers, row, col, 0);
  }
}

/// ":intro": clear screen, display intro screen and wait for return.
///
/// @param eap
void ex_intro(exarg_T *eap)
{
  screenclear();
  intro_message(TRUE);
  wait_return(TRUE);
}
