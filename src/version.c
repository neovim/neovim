/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#include "vim.h"
#include "version.h"
#include "charset.h"
#include "memline.h"
#include "message.h"
#include "misc2.h"
#include "screen.h"

/*
 * Vim originated from Stevie version 3.6 (Fish disk 217) by GRWalter (Fred)
 * It has been changed beyond recognition since then.
 *
 * Differences between version 6.x and 7.x can be found with ":help version7".
 * Differences between version 5.x and 6.x can be found with ":help version6".
 * Differences between version 4.x and 5.x can be found with ":help version5".
 * Differences between version 3.0 and 4.x can be found with ":help version4".
 * All the remarks about older versions have been removed, they are not very
 * interesting.
 */

#include "version_defs.h"

char            *Version = VIM_VERSION_SHORT;
static char     *mediumVersion = VIM_VERSION_MEDIUM;

#if defined(HAVE_DATE_TIME) || defined(PROTO)
char    *longVersion = VIM_VERSION_LONG_DATE __DATE__ " " __TIME__ ")";
#else
char    *longVersion = VIM_VERSION_LONG;
#endif

static void list_features(void);
static void version_msg(char *s);

static char *(features[]) =
{
#ifdef HAVE_ACL
  "+acl",
#else
  "-acl",
#endif
  "+arabic",
  "+autocmd",
  "-balloon_eval",
  "-browse",
#ifdef NO_BUILTIN_TCAPS
  "-builtin_terms",
#endif
#ifdef SOME_BUILTIN_TCAPS
  "+builtin_terms",
#endif
#ifdef ALL_BUILTIN_TCAPS
  "++builtin_terms",
#endif
  "+byte_offset",
  "+cindent",
  "-clientserver",
  "-clipboard",
  "+cmdline_compl",
  "+cmdline_hist",
  "+cmdline_info",
  "+comments",
  "+conceal",
  "+cryptv",
  "+cscope",
  "+cursorbind",
#ifdef CURSOR_SHAPE
  "+cursorshape",
#else
  "-cursorshape",
#endif
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
  /* only interesting on Unix systems */
#if defined(UNIX)
  "+fork()",
#endif
  "+gettext",
  "+hangul_input",
#if (defined(HAVE_ICONV_H) && defined(USE_ICONV)) || defined(DYNAMIC_ICONV)
# ifdef DYNAMIC_ICONV
  "+iconv/dyn",
# else
  "+iconv",
# endif
#else
  "-iconv",
#endif
  "+insert_expand",
  "+jumplist",
  "+keymap",
  "+langmap",
#ifdef FEAT_LIBCALL
  "+libcall",
#else
  "-libcall",
#endif
  "+linebreak",
  "+lispindent",
  "+listcmds",
  "+localmap",
  "-lua",
  "+menu",
  "+mksession",
  "+modify_fname",
  "+mouse",
  "-mouseshape",

#if defined(UNIX) || defined(VMS)
  "+mouse_dec",
  "-mouse_gpm",
# ifdef FEAT_MOUSE_JSB
  "+mouse_jsbterm",
# else
  "-mouse_jsbterm",
# endif
  "+mouse_netterm",
#endif


#if defined(UNIX) || defined(VMS)
  "+mouse_sgr",
  "-mouse_sysmouse",
  "+mouse_urxvt",
  "+mouse_xterm",
#endif

  "+multi_byte",
  "+multi_lang",
  "-mzscheme",
  "-netbeans_intg",
  "+path_extra",
  "-perl",
  "+persistent_undo",
  "+postscript",
  "+printer",
  "+profile",
  "-python",
  "-python3",
  "+quickfix",
  "+reltime",
  "+rightleft",
  "-ruby",
  "+scrollbind",
  "-signs",
  "+smartindent",
  "-sniff",
#ifdef STARTUPTIME
  "+startuptime",
#else
  "-startuptime",
#endif
  "+statusline",
  "-sun_workshop",
  "+syntax",
  "+tag_binary",
  "+tag_old_static",
#ifdef FEAT_TAG_ANYWHITE
  "+tag_any_white",
#else
  "-tag_any_white",
#endif
  "-tcl",
#if defined(UNIX) || defined(__EMX__)
  /* only Unix (or OS/2 with EMX!) can have terminfo instead of termcap */
# ifdef TERMINFO
  "+terminfo",
# else
  "-terminfo",
# endif
#else               /* unix always includes termcap support */
# ifdef HAVE_TGETENT
  "+tgetent",
# else
  "-tgetent",
# endif
#endif
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
#if defined(UNIX) || defined(VMS)
  "-X11",
#endif
  "-xfontset",
  "-xim",
#if defined(UNIX) || defined(VMS)
  "-xsmp",
  "-xterm_clipboard",
#endif
#ifdef FEAT_XTERM_SAVE
  "+xterm_save",
#else
  "-xterm_save",
#endif
  "-xpm",
  NULL
};

static int included_patches[] =
{   /* Add new patch number below this line */
  /**/
  160,
  /**/
  159,
  /**/
  158,
  /**/
  157,
  /**/
  156,
  /**/
  155,
  /**/
  154,
  /**/
  153,
  /**/
  152,
  /**/
  151,
  /**/
  150,
  /**/
  149,
  /**/
  148,
  /**/
  147,
  /**/
  146,
  /**/
  145,
  /**/
  144,
  /**/
  143,
  /**/
  142,
  /**/
  141,
  /**/
  140,
  /**/
  139,
  /**/
  138,
  /**/
  137,
  /**/
  136,
  /**/
  135,
  /**/
  134,
  /**/
  133,
  /**/
  132,
  /**/
  131,
  /**/
  130,
  /**/
  129,
  /**/
  128,
  /**/
  127,
  /**/
  126,
  /**/
  125,
  /**/
  124,
  /**/
  123,
  /**/
  122,
  /**/
  121,
  /**/
  120,
  /**/
  119,
  /**/
  118,
  /**/
  117,
  /**/
  116,
  /**/
  115,
  /**/
  114,
  /**/
  113,
  /**/
  112,
  /**/
  111,
  /**/
  110,
  /**/
  109,
  /**/
  108,
  /**/
  107,
  /**/
  106,
  /**/
  105,
  /**/
  104,
  /**/
  103,
  /**/
  102,
  /**/
  101,
  /**/
  100,
  /**/
  99,
  /**/
  98,
  /**/
  97,
  /**/
  96,
  /**/
  95,
  /**/
  94,
  /**/
  93,
  /**/
  92,
  /**/
  91,
  /**/
  90,
  /**/
  89,
  /**/
  88,
  /**/
  87,
  /**/
  86,
  /**/
  85,
  /**/
  84,
  /**/
  83,
  /**/
  82,
  /**/
  81,
  /**/
  80,
  /**/
  79,
  /**/
  78,
  /**/
  77,
  /**/
  76,
  /**/
  75,
  /**/
  74,
  /**/
  73,
  /**/
  72,
  /**/
  71,
  /**/
  70,
  /**/
  69,
  /**/
  68,
  /**/
  67,
  /**/
  66,
  /**/
  65,
  /**/
  64,
  /**/
  63,
  /**/
  62,
  /**/
  61,
  /**/
  60,
  /**/
  59,
  /**/
  58,
  /**/
  57,
  /**/
  56,
  /**/
  55,
  /**/
  54,
  /**/
  53,
  /**/
  52,
  /**/
  51,
  /**/
  50,
  /**/
  49,
  /**/
  48,
  /**/
  47,
  /**/
  46,
  /**/
  45,
  /**/
  44,
  /**/
  43,
  /**/
  42,
  /**/
  41,
  /**/
  40,
  /**/
  39,
  /**/
  38,
  /**/
  37,
  /**/
  36,
  /**/
  35,
  /**/
  34,
  /**/
  33,
  /**/
  32,
  /**/
  31,
  /**/
  30,
  /**/
  29,
  /**/
  28,
  /**/
  27,
  /**/
  26,
  /**/
  25,
  /**/
  24,
  /**/
  23,
  /**/
  22,
  /**/
  21,
  /**/
  20,
  /**/
  19,
  /**/
  18,
  /**/
  17,
  /**/
  16,
  /**/
  15,
  /**/
  14,
  /**/
  13,
  /**/
  12,
  /**/
  11,
  /**/
  10,
  /**/
  9,
  /**/
  8,
  /**/
  7,
  /**/
  6,
  /**/
  5,
  /**/
  4,
  /**/
  3,
  /**/
  2,
  /**/
  1,
  /**/
  0
};

/*
 * Place to put a short description when adding a feature with a patch.
 * Keep it short, e.g.,: "relative numbers", "persistent undo".
 * Also add a comment marker to separate the lines.
 * See the official Vim patches for the diff format: It must use a context of
 * one line only.  Create it by hand or use "diff -C2" and edit the patch.
 */
static char *(extra_patches[]) =
{   /* Add your patch description below this line */
  /**/
  NULL
};

int highest_patch(void)         {
  int i;
  int h = 0;

  for (i = 0; included_patches[i] != 0; ++i)
    if (included_patches[i] > h)
      h = included_patches[i];
  return h;
}

/*
 * Return TRUE if patch "n" has been included.
 */
int has_patch(int n)
{
  int i;

  for (i = 0; included_patches[i] != 0; ++i)
    if (included_patches[i] == n)
      return TRUE;
  return FALSE;
}

void ex_version(exarg_T *eap)
{
  /*
   * Ignore a ":version 9.99" command.
   */
  if (*eap->arg == NUL) {
    msg_putchar('\n');
    list_version();
  }
}

/*
 * List all features aligned in columns, dictionary style.
 */
static void list_features(void)                 {
  int i;
  int ncol;
  int nrow;
  int nfeat = 0;
  int width = 0;

  /* Find the length of the longest feature name, use that + 1 as the column
   * width */
  for (i = 0; features[i] != NULL; ++i) {
    int l = (int)STRLEN(features[i]);

    if (l > width)
      width = l;
    ++nfeat;
  }
  width += 1;

  if (Columns < width) {
    /* Not enough screen columns - show one per line */
    for (i = 0; features[i] != NULL; ++i) {
      version_msg(features[i]);
      if (msg_col > 0)
        msg_putchar('\n');
    }
    return;
  }

  /* The rightmost column doesn't need a separator.
   * Sacrifice it to fit in one more column if possible. */
  ncol = (int) (Columns + 1) / width;
  nrow = nfeat / ncol + (nfeat % ncol ? 1 : 0);

  /* i counts columns then rows.  idx counts rows then columns. */
  for (i = 0; !got_int && i < nrow * ncol; ++i) {
    int idx = (i / ncol) + (i % ncol) * nrow;

    if (idx < nfeat) {
      int last_col = (i + 1) % ncol == 0;

      msg_puts((char_u *)features[idx]);
      if (last_col) {
        if (msg_col > 0)
          msg_putchar('\n');
      } else   {
        while (msg_col % width)
          msg_putchar(' ');
      }
    } else   {
      if (msg_col > 0)
        msg_putchar('\n');
    }
  }
}

void list_version(void)          {
  int i;
  int first;
  char        *s = "";

  /*
   * When adding features here, don't forget to update the list of
   * internal variables in eval.c!
   */
  MSG(longVersion);


  /* Print the list of patch numbers if there is at least one. */
  /* Print a range when patches are consecutive: "1-10, 12, 15-40, 42-45" */
  if (included_patches[0] != 0) {
    MSG_PUTS(_("\nIncluded patches: "));
    first = -1;
    /* find last one */
    for (i = 0; included_patches[i] != 0; ++i)
      ;
    while (--i >= 0) {
      if (first < 0)
        first = included_patches[i];
      if (i == 0 || included_patches[i - 1] != included_patches[i] + 1) {
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

  /* Print the list of extra patch descriptions if there is at least one. */
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
#endif

#ifdef HAVE_PATHDEF
  if (*compiled_user != NUL || *compiled_sys != NUL) {
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
#endif

  MSG_PUTS(_("\nHuge version "));
  MSG_PUTS(_("without GUI."));
  version_msg(_("  Features included (+) or not (-):\n"));

  list_features();

#ifdef SYS_VIMRC_FILE
  version_msg(_("   system vimrc file: \""));
  version_msg(SYS_VIMRC_FILE);
  version_msg("\"\n");
#endif
#ifdef USR_VIMRC_FILE
  version_msg(_("     user vimrc file: \""));
  version_msg(USR_VIMRC_FILE);
  version_msg("\"\n");
#endif
#ifdef USR_VIMRC_FILE2
  version_msg(_(" 2nd user vimrc file: \""));
  version_msg(USR_VIMRC_FILE2);
  version_msg("\"\n");
#endif
#ifdef USR_VIMRC_FILE3
  version_msg(_(" 3rd user vimrc file: \""));
  version_msg(USR_VIMRC_FILE3);
  version_msg("\"\n");
#endif
#ifdef USR_EXRC_FILE
  version_msg(_("      user exrc file: \""));
  version_msg(USR_EXRC_FILE);
  version_msg("\"\n");
#endif
#ifdef USR_EXRC_FILE2
  version_msg(_("  2nd user exrc file: \""));
  version_msg(USR_EXRC_FILE2);
  version_msg("\"\n");
#endif
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
#endif
#ifdef DEBUG
  version_msg("\n");
  version_msg(_("  DEBUG BUILD"));
#endif
}

/*
 * Output a string for the version message.  If it's going to wrap, output a
 * newline, unless the message is too long to fit on the screen anyway.
 */
static void version_msg(char *s)
{
  int len = (int)STRLEN(s);

  if (!got_int && len < (int)Columns && msg_col + len >= (int)Columns
      && *s != '\n')
    msg_putchar('\n');
  if (!got_int)
    MSG_PUTS(s);
}

static void do_intro_line(int row, char_u *mesg, int add_version,
                          int attr);

/*
 * Show the intro message when not editing a file.
 */
void maybe_intro_message(void)          {
  if (bufempty()
      && curbuf->b_fname == NULL
      && firstwin->w_next == NULL
      && vim_strchr(p_shm, SHM_INTRO) == NULL)
    intro_message(FALSE);
}

/*
 * Give an introductory message about Vim.
 * Only used when starting Vim on an empty file, without a file name.
 * Or with the ":intro" command (for Sven :-).
 */
void 
intro_message (
    int colon                      /* TRUE for ":intro" */
)
{
  int i;
  int row;
  int blanklines;
  int sponsor;
  char        *p;
  static char *(lines[]) =
  {
    N_("VIM - Vi IMproved"),
    "",
    N_("version "),
    N_("by Bram Moolenaar et al."),
#ifdef MODIFIED_BY
    " ",
#endif
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

  /* blanklines = screen height - # message lines */
  blanklines = (int)Rows - ((sizeof(lines) / sizeof(char *)) - 1);
  if (!p_cp)
    blanklines += 4;      /* add 4 for not showing "Vi compatible" message */

  /* Don't overwrite a statusline.  Depends on 'cmdheight'. */
  if (p_ls > 1)
    blanklines -= Rows - topframe->fr_height;
  if (blanklines < 0)
    blanklines = 0;

  /* Show the sponsor and register message one out of four times, the Uganda
   * message two out of four times. */
  sponsor = (int)time(NULL);
  sponsor = ((sponsor & 2) == 0) - ((sponsor & 4) == 0);

  /* start displaying the message lines after half of the blank lines */
  row = blanklines / 2;
  if ((row >= 2 && Columns >= 50) || colon) {
    for (i = 0; i < (int)(sizeof(lines) / sizeof(char *)); ++i) {
      p = lines[i];
      if (p == NULL) {
        if (!p_cp)
          break;
        continue;
      }
      if (sponsor != 0) {
        if (strstr(p, "children") != NULL)
          p = sponsor < 0
              ? N_("Sponsor Vim development!")
              : N_("Become a registered Vim user!");
        else if (strstr(p, "iccf") != NULL)
          p = sponsor < 0
              ? N_("type  :help sponsor<Enter>    for information ")
              : N_("type  :help register<Enter>   for information ");
        else if (strstr(p, "Orphans") != NULL)
          p = N_("menu  Help->Sponsor/Register  for information    ");
      }
      if (*p != NUL)
        do_intro_line(row, (char_u *)_(p), i == 2, 0);
      ++row;
    }
  }

  /* Make the wait-return message appear just below the text. */
  if (colon)
    msg_row = row;
}

static void do_intro_line(int row, char_u *mesg, int add_version, int attr)
{
  char_u vers[20];
  int col;
  char_u      *p;
  int l;
  int clen;
#ifdef MODIFIED_BY
# define MODBY_LEN 150
  char_u modby[MODBY_LEN];

  if (*mesg == ' ') {
    vim_strncpy(modby, (char_u *)_("Modified by "), MODBY_LEN - 1);
    l = STRLEN(modby);
    vim_strncpy(modby + l, (char_u *)MODIFIED_BY, MODBY_LEN - l - 1);
    mesg = modby;
  }
#endif

  /* Center the message horizontally. */
  col = vim_strsize(mesg);
  if (add_version) {
    STRCPY(vers, mediumVersion);
    if (highest_patch()) {
      /* Check for 9.9x or 9.9xx, alpha/beta version */
      if (isalpha((int)vers[3])) {
        int len = (isalpha((int)vers[4])) ? 5 : 4;
        sprintf((char *)vers + len, ".%d%s", highest_patch(),
            mediumVersion + len);
      } else
        sprintf((char *)vers + 3, ".%d", highest_patch());
    }
    col += (int)STRLEN(vers);
  }
  col = (Columns - col) / 2;
  if (col < 0)
    col = 0;

  /* Split up in parts to highlight <> items differently. */
  for (p = mesg; *p != NUL; p += l) {
    clen = 0;
    for (l = 0; p[l] != NUL
         && (l == 0 || (p[l] != '<' && p[l - 1] != '>')); ++l) {
      if (has_mbyte) {
        clen += ptr2cells(p + l);
        l += (*mb_ptr2len)(p + l) - 1;
      } else
        clen += byte2cells(p[l]);
    }
    screen_puts_len(p, l, row, col, *p == '<' ? hl_attr(HLF_8) : attr);
    col += clen;
  }

  /* Add the version number to the version line. */
  if (add_version)
    screen_puts(vers, row, col, 0);
}

/*
 * ":intro": clear screen, display intro screen and wait for return.
 */
void ex_intro(exarg_T *eap)
{
  screenclear();
  intro_message(TRUE);
  wait_return(TRUE);
}
