/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * highlight.c: code for text highlighting
 */

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

//TODO: cleanup
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/hashtab.h"
#include "nvim/highlight.h"
#include "nvim/indent_c.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/keymap.h"
#include "nvim/garray.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax_defs.h"
#include "nvim/term.h"
#include "nvim/ui.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"

//FIXME: see highlight.h
garray_T highlight_ga = GA_EMPTY_INIT_VALUE;

#define SG_TERM         1       /* term has been set */
#define SG_CTERM        2       /* cterm has been set */
#define SG_GUI          4       /* gui has been set */
#define SG_LINK         8       /* link has been set */


/* Flags to indicate an additional string for highlight name completion. */
static int include_none = 0;    /* when 1 include "nvim/None" */
static int include_default = 0; /* when 1 include "nvim/default" */
static int include_link = 0;    /* when 2 include "nvim/link" and "clear" */

/*
 * The "term", "cterm" and "gui" arguments can be any combination of the
 * following names, separated by commas (but no spaces!).
 */
static char *(hl_name_table[]) =
{"bold", "standout", "underline", "undercurl",
 "italic", "reverse", "inverse", "NONE"};
static int hl_attr_table[] =
{HL_BOLD, HL_STANDOUT, HL_UNDERLINE, HL_UNDERCURL, HL_ITALIC, HL_INVERSE,
 HL_INVERSE, 0};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.c.generated.h"
#endif

/*
 * The default highlight groups.  These are compiled-in for fast startup and
 * they still work when the runtime files can't be found.
 * When making changes here, also change runtime/colors/default.vim!
 * The #ifdefs are needed to reduce the amount of static data.  Helps to make
 * the 16 bit DOS (museum) version compile.
 */
# define CENT(a, b) b
static char *(highlight_init_both[]) =
{
  CENT(
      "ErrorMsg term=standout ctermbg=DarkRed ctermfg=White",
      "ErrorMsg term=standout ctermbg=DarkRed ctermfg=White guibg=Red guifg=White"),
  CENT("IncSearch term=reverse cterm=reverse",
      "IncSearch term=reverse cterm=reverse gui=reverse"),
  CENT("ModeMsg term=bold cterm=bold",
      "ModeMsg term=bold cterm=bold gui=bold"),
  CENT("NonText term=bold ctermfg=Blue",
      "NonText term=bold ctermfg=Blue gui=bold guifg=Blue"),
  CENT("StatusLine term=reverse,bold cterm=reverse,bold",
      "StatusLine term=reverse,bold cterm=reverse,bold gui=reverse,bold"),
  CENT("StatusLineNC term=reverse cterm=reverse",
      "StatusLineNC term=reverse cterm=reverse gui=reverse"),
  "default link EndOfBuffer NonText",
  CENT("VertSplit term=reverse cterm=reverse",
      "VertSplit term=reverse cterm=reverse gui=reverse"),
  CENT("DiffText term=reverse cterm=bold ctermbg=Red",
      "DiffText term=reverse cterm=bold ctermbg=Red gui=bold guibg=Red"),
  CENT("PmenuSbar ctermbg=Grey",
      "PmenuSbar ctermbg=Grey guibg=Grey"),
  CENT("TabLineSel term=bold cterm=bold",
      "TabLineSel term=bold cterm=bold gui=bold"),
  CENT("TabLineFill term=reverse cterm=reverse",
      "TabLineFill term=reverse cterm=reverse gui=reverse"),
  NULL
};

static char *(highlight_init_light[]) =
{
  CENT("Directory term=bold ctermfg=DarkBlue",
      "Directory term=bold ctermfg=DarkBlue guifg=Blue"),
  CENT("LineNr term=underline ctermfg=Brown",
      "LineNr term=underline ctermfg=Brown guifg=Brown"),
  CENT("CursorLineNr term=bold ctermfg=Brown",
      "CursorLineNr term=bold ctermfg=Brown gui=bold guifg=Brown"),
  CENT("MoreMsg term=bold ctermfg=DarkGreen",
      "MoreMsg term=bold ctermfg=DarkGreen gui=bold guifg=SeaGreen"),
  CENT("Question term=standout ctermfg=DarkGreen",
      "Question term=standout ctermfg=DarkGreen gui=bold guifg=SeaGreen"),
  CENT("Search term=reverse ctermbg=Yellow ctermfg=NONE",
      "Search term=reverse ctermbg=Yellow ctermfg=NONE guibg=Yellow guifg=NONE"),
  CENT("SpellBad term=reverse ctermbg=LightRed",
      "SpellBad term=reverse ctermbg=LightRed guisp=Red gui=undercurl"),
  CENT("SpellCap term=reverse ctermbg=LightBlue",
      "SpellCap term=reverse ctermbg=LightBlue guisp=Blue gui=undercurl"),
  CENT("SpellRare term=reverse ctermbg=LightMagenta",
      "SpellRare term=reverse ctermbg=LightMagenta guisp=Magenta gui=undercurl"),
  CENT("SpellLocal term=underline ctermbg=Cyan",
      "SpellLocal term=underline ctermbg=Cyan guisp=DarkCyan gui=undercurl"),
  CENT("PmenuThumb ctermbg=Black",
      "PmenuThumb ctermbg=Black guibg=Black"),
  CENT("Pmenu ctermbg=LightMagenta ctermfg=Black",
      "Pmenu ctermbg=LightMagenta ctermfg=Black guibg=LightMagenta"),
  CENT("PmenuSel ctermbg=LightGrey ctermfg=Black",
      "PmenuSel ctermbg=LightGrey ctermfg=Black guibg=Grey"),
  CENT("SpecialKey term=bold ctermfg=DarkBlue",
      "SpecialKey term=bold ctermfg=DarkBlue guifg=Blue"),
  CENT("Title term=bold ctermfg=DarkMagenta",
      "Title term=bold ctermfg=DarkMagenta gui=bold guifg=Magenta"),
  CENT("WarningMsg term=standout ctermfg=DarkRed",
      "WarningMsg term=standout ctermfg=DarkRed guifg=Red"),
  CENT(
      "WildMenu term=standout ctermbg=Yellow ctermfg=Black",
      "WildMenu term=standout ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black"),
  CENT(
      "Folded term=standout ctermbg=Grey ctermfg=DarkBlue",
      "Folded term=standout ctermbg=Grey ctermfg=DarkBlue guibg=LightGrey guifg=DarkBlue"),
  CENT(
      "FoldColumn term=standout ctermbg=Grey ctermfg=DarkBlue",
      "FoldColumn term=standout ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue"),
  CENT("SignColumn term=standout ctermbg=Grey ctermfg=DarkBlue",
       "SignColumn term=standout ctermbg=Grey ctermfg=DarkBlue guibg=Grey guifg=DarkBlue"),
  CENT("Visual term=reverse",
      "Visual term=reverse guibg=LightGrey"),
  CENT("DiffAdd term=bold ctermbg=LightBlue",
      "DiffAdd term=bold ctermbg=LightBlue guibg=LightBlue"),
  CENT("DiffChange term=bold ctermbg=LightMagenta",
      "DiffChange term=bold ctermbg=LightMagenta guibg=LightMagenta"),
  CENT(
      "DiffDelete term=bold ctermfg=Blue ctermbg=LightCyan",
      "DiffDelete term=bold ctermfg=Blue ctermbg=LightCyan gui=bold guifg=Blue guibg=LightCyan"),
  CENT(
      "TabLine term=underline cterm=underline ctermfg=black ctermbg=LightGrey",
      "TabLine term=underline cterm=underline ctermfg=black ctermbg=LightGrey gui=underline guibg=LightGrey"),
  CENT("CursorColumn term=reverse ctermbg=LightGrey",
      "CursorColumn term=reverse ctermbg=LightGrey guibg=Grey90"),
  CENT("CursorLine term=underline cterm=underline",
      "CursorLine term=underline cterm=underline guibg=Grey90"),
  CENT("ColorColumn term=reverse ctermbg=LightRed",
      "ColorColumn term=reverse ctermbg=LightRed guibg=LightRed"),
  CENT(
      "Conceal ctermbg=DarkGrey ctermfg=LightGrey",
      "Conceal ctermbg=DarkGrey ctermfg=LightGrey guibg=DarkGrey guifg=LightGrey"),
  CENT("MatchParen term=reverse ctermbg=Cyan",
      "MatchParen term=reverse ctermbg=Cyan guibg=Cyan"),
  NULL
};

static char *(highlight_init_dark[]) =
{
  CENT("Directory term=bold ctermfg=LightCyan",
      "Directory term=bold ctermfg=LightCyan guifg=Cyan"),
  CENT("LineNr term=underline ctermfg=Yellow",
      "LineNr term=underline ctermfg=Yellow guifg=Yellow"),
  CENT("CursorLineNr term=bold ctermfg=Yellow",
      "CursorLineNr term=bold ctermfg=Yellow gui=bold guifg=Yellow"),
  CENT("MoreMsg term=bold ctermfg=LightGreen",
      "MoreMsg term=bold ctermfg=LightGreen gui=bold guifg=SeaGreen"),
  CENT("Question term=standout ctermfg=LightGreen",
      "Question term=standout ctermfg=LightGreen gui=bold guifg=Green"),
  CENT(
      "Search term=reverse ctermbg=Yellow ctermfg=Black",
      "Search term=reverse ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black"),
  CENT("SpecialKey term=bold ctermfg=LightBlue",
      "SpecialKey term=bold ctermfg=LightBlue guifg=Cyan"),
  CENT("SpellBad term=reverse ctermbg=Red",
      "SpellBad term=reverse ctermbg=Red guisp=Red gui=undercurl"),
  CENT("SpellCap term=reverse ctermbg=Blue",
      "SpellCap term=reverse ctermbg=Blue guisp=Blue gui=undercurl"),
  CENT("SpellRare term=reverse ctermbg=Magenta",
      "SpellRare term=reverse ctermbg=Magenta guisp=Magenta gui=undercurl"),
  CENT("SpellLocal term=underline ctermbg=Cyan",
      "SpellLocal term=underline ctermbg=Cyan guisp=Cyan gui=undercurl"),
  CENT("PmenuThumb ctermbg=White",
      "PmenuThumb ctermbg=White guibg=White"),
  CENT("Pmenu ctermbg=Magenta ctermfg=Black",
      "Pmenu ctermbg=Magenta ctermfg=Black guibg=Magenta"),
  CENT("PmenuSel ctermbg=Black ctermfg=DarkGrey",
      "PmenuSel ctermbg=Black ctermfg=DarkGrey guibg=DarkGrey"),
  CENT("Title term=bold ctermfg=LightMagenta",
      "Title term=bold ctermfg=LightMagenta gui=bold guifg=Magenta"),
  CENT("WarningMsg term=standout ctermfg=LightRed",
      "WarningMsg term=standout ctermfg=LightRed guifg=Red"),
  CENT(
      "WildMenu term=standout ctermbg=Yellow ctermfg=Black",
      "WildMenu term=standout ctermbg=Yellow ctermfg=Black guibg=Yellow guifg=Black"),
  CENT(
      "Folded term=standout ctermbg=DarkGrey ctermfg=Cyan",
      "Folded term=standout ctermbg=DarkGrey ctermfg=Cyan guibg=DarkGrey guifg=Cyan"),
  CENT(
      "FoldColumn term=standout ctermbg=DarkGrey ctermfg=Cyan",
      "FoldColumn term=standout ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan"),
  CENT("SignColumn term=standout ctermbg=DarkGrey ctermfg=Cyan",
      "SignColumn term=standout ctermbg=DarkGrey ctermfg=Cyan guibg=Grey guifg=Cyan"),
  CENT("Visual term=reverse",
      "Visual term=reverse guibg=DarkGrey"),
  CENT("DiffAdd term=bold ctermbg=DarkBlue",
      "DiffAdd term=bold ctermbg=DarkBlue guibg=DarkBlue"),
  CENT("DiffChange term=bold ctermbg=DarkMagenta",
      "DiffChange term=bold ctermbg=DarkMagenta guibg=DarkMagenta"),
  CENT(
      "DiffDelete term=bold ctermfg=Blue ctermbg=DarkCyan",
      "DiffDelete term=bold ctermfg=Blue ctermbg=DarkCyan gui=bold guifg=Blue guibg=DarkCyan"),
  CENT(
      "TabLine term=underline cterm=underline ctermfg=white ctermbg=DarkGrey",
      "TabLine term=underline cterm=underline ctermfg=white ctermbg=DarkGrey gui=underline guibg=DarkGrey"),
  CENT("CursorColumn term=reverse ctermbg=DarkGrey",
      "CursorColumn term=reverse ctermbg=DarkGrey guibg=Grey40"),
  CENT("CursorLine term=underline cterm=underline",
      "CursorLine term=underline cterm=underline guibg=Grey40"),
  CENT("ColorColumn term=reverse ctermbg=DarkRed",
      "ColorColumn term=reverse ctermbg=DarkRed guibg=DarkRed"),
  CENT("MatchParen term=reverse ctermbg=DarkCyan",
      "MatchParen term=reverse ctermbg=DarkCyan guibg=DarkCyan"),
  CENT(
      "Conceal ctermbg=DarkGrey ctermfg=LightGrey",
      "Conceal ctermbg=DarkGrey ctermfg=LightGrey guibg=DarkGrey guifg=LightGrey"),
  NULL
};

void 
init_highlight (
    int both,                   /* include groups where 'bg' doesn't matter */
    int reset                  /* clear group first */
)
{
  int i;
  char        **pp;
  static int had_both = FALSE;
  char_u      *p;

  /*
   * Try finding the color scheme file.  Used when a color file was loaded
   * and 'background' or 't_Co' is changed.
   */
  p = get_var_value((char_u *)"g:colors_name");
  if (p != NULL && load_colors(p) == OK)
    return;

  /*
   * Didn't use a color file, use the compiled-in colors.
   */
  if (both) {
    had_both = TRUE;
    pp = highlight_init_both;
    for (i = 0; pp[i] != NULL; ++i)
      do_highlight((char_u *)pp[i], reset, TRUE);
  } else if (!had_both)
    /* Don't do anything before the call with both == TRUE from main().
     * Not everything has been setup then, and that call will overrule
     * everything anyway. */
    return;

  if (*p_bg == 'l')
    pp = highlight_init_light;
  else
    pp = highlight_init_dark;
  for (i = 0; pp[i] != NULL; ++i)
    do_highlight((char_u *)pp[i], reset, TRUE);

  /* Reverse looks ugly, but grey may not work for 8 colors.  Thus let it
   * depend on the number of colors available.
   * With 8 colors brown is equal to yellow, need to use black for Search fg
   * to avoid Statement highlighted text disappears.
   * Clear the attributes, needed when changing the t_Co value. */
  if (t_colors > 8)
    do_highlight(
        (char_u *)(*p_bg == 'l'
                   ? "Visual cterm=NONE ctermbg=LightGrey"
                   : "Visual cterm=NONE ctermbg=DarkGrey"), FALSE,
        TRUE);
  else {
    do_highlight((char_u *)"Visual cterm=reverse ctermbg=NONE",
        FALSE, TRUE);
    if (*p_bg == 'l')
      do_highlight((char_u *)"Search ctermfg=black", FALSE, TRUE);
  }

  /*
   * If syntax highlighting is enabled load the highlighting for it.
   */
  if (get_var_value((char_u *)"g:syntax_on") != NULL) {
    static int recursive = 0;

    if (recursive >= 5)
      EMSG(_("E679: recursive loop loading syncolor.vim"));
    else {
      ++recursive;
      (void)source_runtime((char_u *)"syntax/syncolor.vim", TRUE);
      --recursive;
    }
  }
}

/*
 * Load color file "name".
 * Return OK for success, FAIL for failure.
 */
int load_colors(char_u *name)
{
  char_u      *buf;
  int retval = FAIL;
  static int recursive = FALSE;

  /* When being called recursively, this is probably because setting
   * 'background' caused the highlighting to be reloaded.  This means it is
   * working, thus we should return OK. */
  if (recursive)
    return OK;

  recursive = TRUE;
  buf = xmalloc(STRLEN(name) + 12);
  sprintf((char *)buf, "colors/%s.vim", name);
  retval = source_runtime(buf, FALSE);
  free(buf);
  apply_autocmds(EVENT_COLORSCHEME, name, curbuf->b_fname, FALSE, curbuf);

  recursive = FALSE;
  ui_refresh();

  return retval;
}

/*
 * Handle the ":highlight .." command.
 * When using ":hi clear" this is called recursively for each group with
 * "forceit" and "init" both TRUE.
 */
void 
do_highlight (
    char_u *line,
    int forceit,
    int init                   /* TRUE when called for initializing */
)
{
  char_u      *name_end;
  char_u      *p;
  char_u      *linep;
  char_u      *key_start;
  char_u      *arg_start;
  char_u      *key = NULL, *arg = NULL;
  long i;
  int off;
  int len;
  int attr;
  int id;
  int idx;
  int dodefault = FALSE;
  int doclear = FALSE;
  int dolink = FALSE;
  int error = FALSE;
  int color;
  int is_normal_group = FALSE;                  /* "Normal" group */

  /*
   * If no argument, list current highlighting.
   */
  if (ends_excmd(*line)) {
    for (int i = 1; i <= highlight_ga.ga_len && !got_int; ++i)
      /* TODO: only call when the group has attributes set */
      highlight_list_one((int)i);
    return;
  }

  /*
   * Isolate the name.
   */
  name_end = skiptowhite(line);
  linep = skipwhite(name_end);

  /*
   * Check for "default" argument.
   */
  if (STRNCMP(line, "default", name_end - line) == 0) {
    dodefault = TRUE;
    line = linep;
    name_end = skiptowhite(line);
    linep = skipwhite(name_end);
  }

  /*
   * Check for "clear" or "link" argument.
   */
  if (STRNCMP(line, "clear", name_end - line) == 0)
    doclear = TRUE;
  if (STRNCMP(line, "link", name_end - line) == 0)
    dolink = TRUE;

  /*
   * ":highlight {group-name}": list highlighting for one group.
   */
  if (!doclear && !dolink && ends_excmd(*linep)) {
    id = syn_namen2id(line, (int)(name_end - line));
    if (id == 0)
      EMSG2(_("E411: highlight group not found: %s"), line);
    else
      highlight_list_one(id);
    return;
  }

  /*
   * Handle ":highlight link {from} {to}" command.
   */
  if (dolink) {
    char_u      *from_start = linep;
    char_u      *from_end;
    char_u      *to_start;
    char_u      *to_end;
    int from_id;
    int to_id;

    from_end = skiptowhite(from_start);
    to_start = skipwhite(from_end);
    to_end   = skiptowhite(to_start);

    if (ends_excmd(*from_start) || ends_excmd(*to_start)) {
      EMSG2(_("E412: Not enough arguments: \":highlight link %s\""),
          from_start);
      return;
    }

    if (!ends_excmd(*skipwhite(to_end))) {
      EMSG2(_("E413: Too many arguments: \":highlight link %s\""), from_start);
      return;
    }

    from_id = syn_check_group(from_start, (int)(from_end - from_start));
    if (STRNCMP(to_start, "NONE", 4) == 0)
      to_id = 0;
    else
      to_id = syn_check_group(to_start, (int)(to_end - to_start));

    if (from_id > 0 && (!init || HL_TABLE()[from_id - 1].sg_set == 0)) {
      /*
       * Don't allow a link when there already is some highlighting
       * for the group, unless '!' is used
       */
      if (to_id > 0 && !forceit && !init
          && hl_has_settings(from_id - 1, dodefault)) {
        if (sourcing_name == NULL && !dodefault)
          EMSG(_("E414: group has settings, highlight link ignored"));
      } else {
        if (!init)
          HL_TABLE()[from_id - 1].sg_set |= SG_LINK;
        HL_TABLE()[from_id - 1].sg_link = to_id;
        HL_TABLE()[from_id - 1].sg_scriptID = current_SID;
        redraw_all_later(SOME_VALID);
      }
    }

    /* Only call highlight_changed() once, after sourcing a syntax file */
    need_highlight_changed = TRUE;

    return;
  }

  if (doclear) {
    /*
     * ":highlight clear [group]" command.
     */
    line = linep;
    if (ends_excmd(*line)) {
      do_unlet((char_u *)"colors_name", TRUE);
      restore_cterm_colors();

      /*
       * Clear all default highlight groups and load the defaults.
       */
      for (int idx = 0; idx < highlight_ga.ga_len; ++idx) {
        highlight_clear(idx);
      }
      init_highlight(TRUE, TRUE);
      highlight_changed();
      redraw_later_clear();
      return;
    }
    name_end = skiptowhite(line);
    linep = skipwhite(name_end);
  }

  /*
   * Find the group name in the table.  If it does not exist yet, add it.
   */
  id = syn_check_group(line, (int)(name_end - line));
  if (id == 0)                          /* failed (out of memory) */
    return;
  idx = id - 1;                         /* index is ID minus one */

  /* Return if "default" was used and the group already has settings. */
  if (dodefault && hl_has_settings(idx, TRUE))
    return;

  if (STRCMP(HL_TABLE()[idx].sg_name_u, "NORMAL") == 0)
    is_normal_group = TRUE;

  /* Clear the highlighting for ":hi clear {group}" and ":hi clear". */
  if (doclear || (forceit && init)) {
    highlight_clear(idx);
    if (!doclear)
      HL_TABLE()[idx].sg_set = 0;
  }

  if (!doclear)
    while (!ends_excmd(*linep)) {
      key_start = linep;
      if (*linep == '=') {
        EMSG2(_("E415: unexpected equal sign: %s"), key_start);
        error = TRUE;
        break;
      }

      /*
       * Isolate the key ("term", "ctermfg", "ctermbg", "font", "guifg" or
       * "guibg").
       */
      while (*linep && !vim_iswhite(*linep) && *linep != '=')
        ++linep;
      free(key);
      key = vim_strnsave_up(key_start, (int)(linep - key_start));
      linep = skipwhite(linep);

      if (STRCMP(key, "NONE") == 0) {
        if (!init || HL_TABLE()[idx].sg_set == 0) {
          if (!init)
            HL_TABLE()[idx].sg_set |= SG_TERM+SG_CTERM+SG_GUI;
          highlight_clear(idx);
        }
        continue;
      }

      /*
       * Check for the equal sign.
       */
      if (*linep != '=') {
        EMSG2(_("E416: missing equal sign: %s"), key_start);
        error = TRUE;
        break;
      }
      ++linep;

      /*
       * Isolate the argument.
       */
      linep = skipwhite(linep);
      if (*linep == '\'') {             /* guifg='color name' */
        arg_start = ++linep;
        linep = vim_strchr(linep, '\'');
        if (linep == NULL) {
          EMSG2(_(e_invarg2), key_start);
          error = TRUE;
          break;
        }
      } else {
        arg_start = linep;
        linep = skiptowhite(linep);
      }
      if (linep == arg_start) {
        EMSG2(_("E417: missing argument: %s"), key_start);
        error = TRUE;
        break;
      }
      free(arg);
      arg = vim_strnsave(arg_start, (int)(linep - arg_start));

      if (*linep == '\'')
        ++linep;

      /*
       * Store the argument.
       */
      if (  STRCMP(key, "TERM") == 0
            || STRCMP(key, "CTERM") == 0
            || STRCMP(key, "GUI") == 0) {
        attr = 0;
        off = 0;
        while (arg[off] != NUL) {
          for (i = ARRAY_SIZE(hl_attr_table); --i >= 0; ) {
            len = (int)STRLEN(hl_name_table[i]);
            if (STRNICMP(arg + off, hl_name_table[i], len) == 0) {
              attr |= hl_attr_table[i];
              off += len;
              break;
            }
          }
          if (i < 0) {
            EMSG2(_("E418: Illegal value: %s"), arg);
            error = TRUE;
            break;
          }
          if (arg[off] == ',')                  /* another one follows */
            ++off;
        }
        if (error)
          break;
        if (*key == 'T') {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_TERM)) {
            if (!init)
              HL_TABLE()[idx].sg_set |= SG_TERM;
            HL_TABLE()[idx].sg_term = attr;
          }
        } else if (*key == 'C')   {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
            if (!init)
              HL_TABLE()[idx].sg_set |= SG_CTERM;
            HL_TABLE()[idx].sg_cterm = attr;
            HL_TABLE()[idx].sg_cterm_bold = FALSE;
          }
        } else {
          if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
            if (!init)
              HL_TABLE()[idx].sg_set |= SG_GUI;
            HL_TABLE()[idx].sg_gui = attr;
          }
        }
      } else if (STRCMP(key, "FONT") == 0)   {
        /* in non-GUI fonts are simply ignored */
      } else if (STRCMP(key,
                     "CTERMFG") == 0 || STRCMP(key, "CTERMBG") == 0)   {
        if (!init || !(HL_TABLE()[idx].sg_set & SG_CTERM)) {
          if (!init)
            HL_TABLE()[idx].sg_set |= SG_CTERM;

          /* When setting the foreground color, and previously the "bold"
           * flag was set for a light color, reset it now */
          if (key[5] == 'F' && HL_TABLE()[idx].sg_cterm_bold) {
            HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
            HL_TABLE()[idx].sg_cterm_bold = FALSE;
          }

          if (VIM_ISDIGIT(*arg))
            color = atoi((char *)arg);
          else if (STRICMP(arg, "fg") == 0) {
            if (cterm_normal_fg_color)
              color = cterm_normal_fg_color - 1;
            else {
              EMSG(_("E419: FG color unknown"));
              error = TRUE;
              break;
            }
          } else if (STRICMP(arg, "bg") == 0)   {
            if (cterm_normal_bg_color > 0)
              color = cterm_normal_bg_color - 1;
            else {
              EMSG(_("E420: BG color unknown"));
              error = TRUE;
              break;
            }
          } else {
            static char *(color_names[28]) = {
              "Black", "DarkBlue", "DarkGreen", "DarkCyan",
              "DarkRed", "DarkMagenta", "Brown", "DarkYellow",
              "Gray", "Grey",
              "LightGray", "LightGrey", "DarkGray", "DarkGrey",
              "Blue", "LightBlue", "Green", "LightGreen",
              "Cyan", "LightCyan", "Red", "LightRed", "Magenta",
              "LightMagenta", "Yellow", "LightYellow", "White", "NONE"
            };
            static int color_numbers_16[28] = {0, 1, 2, 3,
                                               4, 5, 6, 6,
                                               7, 7,
                                               7, 7, 8, 8,
                                               9, 9, 10, 10,
                                               11, 11, 12, 12, 13,
                                               13, 14, 14, 15, -1};
            /* for xterm with 88 colors... */
            static int color_numbers_88[28] = {0, 4, 2, 6,
                                               1, 5, 32, 72,
                                               84, 84,
                                               7, 7, 82, 82,
                                               12, 43, 10, 61,
                                               14, 63, 9, 74, 13,
                                               75, 11, 78, 15, -1};
            /* for xterm with 256 colors... */
            static int color_numbers_256[28] = {0, 4, 2, 6,
                                                1, 5, 130, 130,
                                                248, 248,
                                                7, 7, 242, 242,
                                                12, 81, 10, 121,
                                                14, 159, 9, 224, 13,
                                                225, 11, 229, 15, -1};
            /* for terminals with less than 16 colors... */
            static int color_numbers_8[28] = {0, 4, 2, 6,
                                              1, 5, 3, 3,
                                              7, 7,
                                              7, 7, 0+8, 0+8,
                                              4+8, 4+8, 2+8, 2+8,
                                              6+8, 6+8, 1+8, 1+8, 5+8,
                                              5+8, 3+8, 3+8, 7+8, -1};

            /* reduce calls to STRICMP a bit, it can be slow */
            off = TOUPPER_ASC(*arg);
            for (i = ARRAY_SIZE(color_names); --i >= 0; )
              if (off == color_names[i][0]
                  && STRICMP(arg + 1, color_names[i] + 1) == 0)
                break;
            if (i < 0) {
              EMSG2(_(
                      "E421: Color name or number not recognized: %s"),
                  key_start);
              error = TRUE;
              break;
            }

            /* Use the _16 table to check if its a valid color name. */
            color = color_numbers_16[i];
            if (color >= 0) {
              if (t_colors == 8) {
                /* t_Co is 8: use the 8 colors table */
                color = color_numbers_8[i];
                if (key[5] == 'F') {
                  /* set/reset bold attribute to get light foreground
                   * colors (on some terminals, e.g. "linux") */
                  if (color & 8) {
                    HL_TABLE()[idx].sg_cterm |= HL_BOLD;
                    HL_TABLE()[idx].sg_cterm_bold = TRUE;
                  } else
                    HL_TABLE()[idx].sg_cterm &= ~HL_BOLD;
                }
                color &= 7;             /* truncate to 8 colors */
              } else if (t_colors == 16 || t_colors == 88 || t_colors == 256) {
                /*
                 * Guess: if the termcap entry ends in 'm', it is
                 * probably an xterm-like terminal.  Use the changed
                 * order for colors.
                 */
                if (*T_CAF != NUL)
                  p = T_CAF;
                else
                  p = T_CSF;
                if (abstract_ui || (*p != NUL && *(p + STRLEN(p) - 1) == 'm'))
                  switch (t_colors) {
                  case 16:
                    color = color_numbers_8[i];
                    break;
                  case 88:
                    color = color_numbers_88[i];
                    break;
                  case 256:
                    color = color_numbers_256[i];
                    break;
                  }
              }
            }
          }
          /* Add one to the argument, to avoid zero.  Zero is used for
           * "NONE", then "color" is -1. */
          if (key[5] == 'F') {
            HL_TABLE()[idx].sg_cterm_fg = color + 1;
            if (is_normal_group) {
              cterm_normal_fg_color = color + 1;
              cterm_normal_fg_bold = (HL_TABLE()[idx].sg_cterm & HL_BOLD);
              {
                must_redraw = CLEAR;
                if (termcap_active && color >= 0)
                  term_fg_color(color);
              }
            }
          } else {
            HL_TABLE()[idx].sg_cterm_bg = color + 1;
            if (is_normal_group) {
              cterm_normal_bg_color = color + 1;
              {
                must_redraw = CLEAR;
                if (color >= 0) {
                  if (termcap_active)
                    term_bg_color(color);
                  if (t_colors < 16)
                    i = (color == 0 || color == 4);
                  else
                    i = (color < 7 || color == 8);
                  /* Set the 'background' option if the value is
                   * wrong. */
                  if (i != (*p_bg == 'd'))
                    set_option_value((char_u *)"bg", 0L,
                        i ?  (char_u *)"dark"
                        : (char_u *)"light", 0);
                }
              }
            }
          }
        }
      } else if (STRCMP(key, "GUIFG") == 0)   {
        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init)
            HL_TABLE()[idx].sg_set |= SG_GUI;

          free(HL_TABLE()[idx].sg_rgb_fg_name);
          if (STRCMP(arg, "NONE")) {
            HL_TABLE()[idx].sg_rgb_fg_name = (uint8_t *)xstrdup((char *)arg);
            HL_TABLE()[idx].sg_rgb_fg = name_to_color(arg);
          } else {
            HL_TABLE()[idx].sg_rgb_fg_name = NULL;
            HL_TABLE()[idx].sg_rgb_fg = -1;
          }
        }

        if (is_normal_group) {
          normal_fg = HL_TABLE()[idx].sg_rgb_fg;
        }
      } else if (STRCMP(key, "GUIBG") == 0)   {
        if (!init || !(HL_TABLE()[idx].sg_set & SG_GUI)) {
          if (!init)
            HL_TABLE()[idx].sg_set |= SG_GUI;

          free(HL_TABLE()[idx].sg_rgb_bg_name);
          if (STRCMP(arg, "NONE") != 0) {
            HL_TABLE()[idx].sg_rgb_bg_name = (uint8_t *)xstrdup((char *)arg);
            HL_TABLE()[idx].sg_rgb_bg = name_to_color(arg);
          } else {
            HL_TABLE()[idx].sg_rgb_bg_name = NULL;
            HL_TABLE()[idx].sg_rgb_bg = -1;
          }
        }

        if (is_normal_group) {
          normal_bg = HL_TABLE()[idx].sg_rgb_bg;
        }
      } else if (STRCMP(key, "GUISP") == 0)   {
        // Ignored
      } else if (STRCMP(key, "START") == 0 || STRCMP(key, "STOP") == 0)   {
        char_u buf[100];
        char_u      *tname;

        if (!init)
          HL_TABLE()[idx].sg_set |= SG_TERM;

        /*
         * The "start" and "stop"  arguments can be a literal escape
         * sequence, or a comma separated list of terminal codes.
         */
        if (STRNCMP(arg, "t_", 2) == 0) {
          off = 0;
          buf[0] = 0;
          while (arg[off] != NUL) {
            /* Isolate one termcap name */
            for (len = 0; arg[off + len] &&
                 arg[off + len] != ','; ++len)
              ;
            tname = vim_strnsave(arg + off, len);
            /* lookup the escape sequence for the item */
            p = get_term_code(tname);
            free(tname);
            if (p == NULL)                  /* ignore non-existing things */
              p = (char_u *)"";

            /* Append it to the already found stuff */
            if ((int)(STRLEN(buf) + STRLEN(p)) >= 99) {
              EMSG2(_("E422: terminal code too long: %s"), arg);
              error = TRUE;
              break;
            }
            STRCAT(buf, p);

            /* Advance to the next item */
            off += len;
            if (arg[off] == ',')                    /* another one follows */
              ++off;
          }
        } else {
          /*
           * Copy characters from arg[] to buf[], translating <> codes.
           */
          for (p = arg, off = 0; off < 100 - 6 && *p; ) {
            len = (int)trans_special(&p, buf + off, FALSE);
            if (len > 0)                    /* recognized special char */
              off += len;
            else                            /* copy as normal char */
              buf[off++] = *p++;
          }
          buf[off] = NUL;
        }
        if (error)
          break;

        if (STRCMP(buf, "NONE") == 0)           /* resetting the value */
          p = NULL;
        else
          p = vim_strsave(buf);
        if (key[2] == 'A') {
          free(HL_TABLE()[idx].sg_start);
          HL_TABLE()[idx].sg_start = p;
        } else {
          free(HL_TABLE()[idx].sg_stop);
          HL_TABLE()[idx].sg_stop = p;
        }
      } else {
        EMSG2(_("E423: Illegal argument: %s"), key_start);
        error = TRUE;
        break;
      }

      /*
       * When highlighting has been given for a group, don't link it.
       */
      if (!init || !(HL_TABLE()[idx].sg_set & SG_LINK))
        HL_TABLE()[idx].sg_link = 0;

      /*
       * Continue with next argument.
       */
      linep = skipwhite(linep);
    }

  /*
   * If there is an error, and it's a new entry, remove it from the table.
   */
  if (error && idx == highlight_ga.ga_len)
    syn_unadd_group();
  else {
    if (is_normal_group) {
      HL_TABLE()[idx].sg_term_attr = 0;
      HL_TABLE()[idx].sg_cterm_attr = 0;
      if (abstract_ui) {
        // If the normal group has changed, it is simpler to refresh every UI
        ui_refresh();
      }
    } else
      set_hl_attr(idx);
    HL_TABLE()[idx].sg_scriptID = current_SID;
    redraw_all_later(NOT_VALID);
  }
  free(key);
  free(arg);

  /* Only call highlight_changed() once, after sourcing a syntax file */
  need_highlight_changed = TRUE;
}

#if defined(EXITFREE)
void free_highlight(void)
{
  for (int i = 0; i < highlight_ga.ga_len; ++i) {
    highlight_clear(i);
    free(HL_TABLE()[i].sg_name);
    free(HL_TABLE()[i].sg_name_u);
  }
  ga_clear(&highlight_ga);
}

#endif

/*
 * Reset the cterm colors to what they were before Vim was started, if
 * possible.  Otherwise reset them to zero.
 */
void restore_cterm_colors(void)
{
  normal_fg = -1;
  normal_bg = -1;
  cterm_normal_fg_color = 0;
  cterm_normal_fg_bold = 0;
  cterm_normal_bg_color = 0;
}

/*
 * Return TRUE if highlight group "idx" has any settings.
 * When "check_link" is TRUE also check for an existing link.
 */
static int hl_has_settings(int idx, int check_link)
{
  return HL_TABLE()[idx].sg_term_attr != 0
         || HL_TABLE()[idx].sg_cterm_attr != 0
         || HL_TABLE()[idx].sg_cterm_fg != 0
         || HL_TABLE()[idx].sg_cterm_bg != 0
         || (check_link && (HL_TABLE()[idx].sg_set & SG_LINK));
}

/*
 * Clear highlighting for one group.
 */
static void highlight_clear(int idx)
{
  HL_TABLE()[idx].sg_term = 0;
  free(HL_TABLE()[idx].sg_start);
  HL_TABLE()[idx].sg_start = NULL;
  free(HL_TABLE()[idx].sg_stop);
  HL_TABLE()[idx].sg_stop = NULL;
  HL_TABLE()[idx].sg_term_attr = 0;
  HL_TABLE()[idx].sg_cterm = 0;
  HL_TABLE()[idx].sg_cterm_bold = FALSE;
  HL_TABLE()[idx].sg_cterm_fg = 0;
  HL_TABLE()[idx].sg_cterm_bg = 0;
  HL_TABLE()[idx].sg_cterm_attr = 0;
  HL_TABLE()[idx].sg_gui = 0;
  HL_TABLE()[idx].sg_rgb_fg = -1;
  HL_TABLE()[idx].sg_rgb_bg = -1;
  free(HL_TABLE()[idx].sg_rgb_fg_name);
  HL_TABLE()[idx].sg_rgb_fg_name = NULL;
  free(HL_TABLE()[idx].sg_rgb_bg_name);
  HL_TABLE()[idx].sg_rgb_bg_name = NULL;
  /* Clear the script ID only when there is no link, since that is not
   * cleared. */
  if (HL_TABLE()[idx].sg_link == 0)
    HL_TABLE()[idx].sg_scriptID = 0;
}


/*
 * Table with the specifications for an attribute number.
 * Note that this table is used by ALL buffers.  This is required because the
 * GUI can redraw at any time for any buffer.
 */
static garray_T term_attr_table = GA_EMPTY_INIT_VALUE;

#define TERM_ATTR_ENTRY(idx) ((attrentry_T *)term_attr_table.ga_data)[idx]

static garray_T cterm_attr_table = GA_EMPTY_INIT_VALUE;

#define CTERM_ATTR_ENTRY(idx) ((attrentry_T *)cterm_attr_table.ga_data)[idx]


/*
 * Return the attr number for a set of colors and font.
 * Add a new entry to the term_attr_table, cterm_attr_table or gui_attr_table
 * if the combination is new.
 * Return 0 for error.
 */
static int get_attr_entry(garray_T *table, attrentry_T *aep)
{
  attrentry_T *taep;
  static int recursive = FALSE;

  /*
   * Init the table, in case it wasn't done yet.
   */
  table->ga_itemsize = sizeof(attrentry_T);
  ga_set_growsize(table, 7);

  /*
   * Try to find an entry with the same specifications.
   */
  for (int i = 0; i < table->ga_len; ++i) {
    taep = &(((attrentry_T *)table->ga_data)[i]);
    if (       aep->ae_attr == taep->ae_attr
               && (
                 (table == &term_attr_table
                  && (aep->ae_u.term.start == NULL)
                  == (taep->ae_u.term.start == NULL)
                  && (aep->ae_u.term.start == NULL
                      || STRCMP(aep->ae_u.term.start,
                          taep->ae_u.term.start) == 0)
                  && (aep->ae_u.term.stop == NULL)
                  == (taep->ae_u.term.stop == NULL)
                  && (aep->ae_u.term.stop == NULL
                      || STRCMP(aep->ae_u.term.stop,
                          taep->ae_u.term.stop) == 0))
                 || (table == &cterm_attr_table
                     && aep->ae_u.cterm.fg_color
                     == taep->ae_u.cterm.fg_color
                     && aep->ae_u.cterm.bg_color
                     == taep->ae_u.cterm.bg_color
                     && aep->fg_color
                     == taep->fg_color
                     && aep->bg_color
                     == taep->bg_color)
                 ))

      return i + ATTR_OFF;
  }

  if (table->ga_len + ATTR_OFF > MAX_TYPENR) {
    /*
     * Running out of attribute entries!  remove all attributes, and
     * compute new ones for all groups.
     * When called recursively, we are really out of numbers.
     */
    if (recursive) {
      EMSG(_("E424: Too many different highlighting attributes in use"));
      return 0;
    }
    recursive = TRUE;

    clear_hl_tables();

    must_redraw = CLEAR;

    for (int i = 0; i < highlight_ga.ga_len; ++i) {
      set_hl_attr(i);
    }

    recursive = FALSE;
  }

  /*
   * This is a new combination of colors and font, add an entry.
   */
  taep = GA_APPEND_VIA_PTR(attrentry_T, table);
  memset(taep, 0, sizeof(*taep));
  taep->ae_attr = aep->ae_attr;
  if (table == &term_attr_table) {
    if (aep->ae_u.term.start == NULL)
      taep->ae_u.term.start = NULL;
    else
      taep->ae_u.term.start = vim_strsave(aep->ae_u.term.start);
    if (aep->ae_u.term.stop == NULL)
      taep->ae_u.term.stop = NULL;
    else
      taep->ae_u.term.stop = vim_strsave(aep->ae_u.term.stop);
  } else if (table == &cterm_attr_table)   {
    taep->ae_u.cterm.fg_color = aep->ae_u.cterm.fg_color;
    taep->ae_u.cterm.bg_color = aep->ae_u.cterm.bg_color;
    taep->fg_color = aep->fg_color;
    taep->bg_color = aep->bg_color;
  }

  return table->ga_len - 1 + ATTR_OFF;
}

/*
 * Clear all highlight tables.
 */
void clear_hl_tables(void)
{
  attrentry_T *taep;

  for (int i = 0; i < term_attr_table.ga_len; ++i) {
    taep = &(((attrentry_T *)term_attr_table.ga_data)[i]);
    free(taep->ae_u.term.start);
    free(taep->ae_u.term.stop);
  }
  ga_clear(&term_attr_table);
  ga_clear(&cterm_attr_table);
}

/*
 * Combine special attributes (e.g., for spelling) with other attributes
 * (e.g., for syntax highlighting).
 * "prim_attr" overrules "char_attr".
 * This creates a new group when required.
 * Since we expect there to be few spelling mistakes we don't cache the
 * result.
 * Return the resulting attributes.
 */
int hl_combine_attr(int char_attr, int prim_attr)
{
  attrentry_T *char_aep = NULL;
  attrentry_T *spell_aep;
  attrentry_T new_en;

  if (char_attr == 0)
    return prim_attr;
  if (char_attr <= HL_ALL && prim_attr <= HL_ALL)
    return char_attr | prim_attr;

  if (abstract_ui || t_colors > 1) {
    if (char_attr > HL_ALL)
      char_aep = syn_cterm_attr2entry(char_attr);
    if (char_aep != NULL)
      new_en = *char_aep;
    else {
      memset(&new_en, 0, sizeof(new_en));
      if (char_attr <= HL_ALL)
        new_en.ae_attr = char_attr;
    }

    if (prim_attr <= HL_ALL)
      new_en.ae_attr |= prim_attr;
    else {
      spell_aep = syn_cterm_attr2entry(prim_attr);
      if (spell_aep != NULL) {
        new_en.ae_attr |= spell_aep->ae_attr;
        if (spell_aep->ae_u.cterm.fg_color > 0)
          new_en.ae_u.cterm.fg_color = spell_aep->ae_u.cterm.fg_color;
        if (spell_aep->ae_u.cterm.bg_color > 0)
          new_en.ae_u.cterm.bg_color = spell_aep->ae_u.cterm.bg_color;
        if (spell_aep->fg_color >= 0)
          new_en.fg_color = spell_aep->fg_color;
        if (spell_aep->bg_color >= 0)
          new_en.bg_color = spell_aep->bg_color;
      }
    }
    return get_attr_entry(&cterm_attr_table, &new_en);
  }

  if (char_attr > HL_ALL)
    char_aep = syn_term_attr2entry(char_attr);
  if (char_aep != NULL)
    new_en = *char_aep;
  else {
    memset(&new_en, 0, sizeof(new_en));
    if (char_attr <= HL_ALL)
      new_en.ae_attr = char_attr;
  }

  if (prim_attr <= HL_ALL)
    new_en.ae_attr |= prim_attr;
  else {
    spell_aep = syn_term_attr2entry(prim_attr);
    if (spell_aep != NULL) {
      new_en.ae_attr |= spell_aep->ae_attr;
      if (spell_aep->ae_u.term.start != NULL) {
        new_en.ae_u.term.start = spell_aep->ae_u.term.start;
        new_en.ae_u.term.stop = spell_aep->ae_u.term.stop;
      }
    }
  }
  return get_attr_entry(&term_attr_table, &new_en);
}


/*
 * Get the highlight attributes (HL_BOLD etc.) from an attribute nr.
 * Only to be used when "attr" > HL_ALL.
 */
int syn_attr2attr(int attr)
{
  attrentry_T *aep;

  if (abstract_ui || t_colors > 1)
    aep = syn_cterm_attr2entry(attr);
  else
    aep = syn_term_attr2entry(attr);

  if (aep == NULL)          /* highlighting not set */
    return 0;
  return aep->ae_attr;
}


attrentry_T *syn_term_attr2entry(int attr)
{
  attr -= ATTR_OFF;
  if (attr >= term_attr_table.ga_len)       /* did ":syntax clear" */
    return NULL;
  return &(TERM_ATTR_ENTRY(attr));
}

attrentry_T *syn_cterm_attr2entry(int attr)
{
  attr -= ATTR_OFF;
  if (attr >= cterm_attr_table.ga_len)          /* did ":syntax clear" */
    return NULL;
  return &(CTERM_ATTR_ENTRY(attr));
}

#define LIST_ATTR   1
#define LIST_STRING 2
#define LIST_INT    3

static void highlight_list_one(int id)
{
  struct hl_group     *sgp;
  int didh = FALSE;

  sgp = &HL_TABLE()[id - 1];        /* index is ID minus one */

  didh = highlight_list_arg(id, didh, LIST_ATTR,
      sgp->sg_term, NULL, "term");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_start, "start");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_stop, "stop");

  didh = highlight_list_arg(id, didh, LIST_ATTR,
      sgp->sg_cterm, NULL, "cterm");
  didh = highlight_list_arg(id, didh, LIST_INT,
      sgp->sg_cterm_fg, NULL, "ctermfg");
  didh = highlight_list_arg(id, didh, LIST_INT,
      sgp->sg_cterm_bg, NULL, "ctermbg");

  didh = highlight_list_arg(id, didh, LIST_ATTR,
      sgp->sg_gui, NULL, "gui");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_rgb_fg_name, "guifg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, sgp->sg_rgb_bg_name, "guibg");
  didh = highlight_list_arg(id, didh, LIST_STRING,
      0, NULL, "guisp");

  if (sgp->sg_link && !got_int) {
    (void)syn_list_header(didh, 9999, id);
    didh = TRUE;
    msg_puts_attr((char_u *)"links to", hl_attr(HLF_D));
    msg_putchar(' ');
    msg_outtrans(HL_TABLE()[HL_TABLE()[id - 1].sg_link - 1].sg_name);
  }

  if (!didh)
    highlight_list_arg(id, didh, LIST_STRING, 0, (char_u *)"cleared", "");
  if (p_verbose > 0)
    last_set_msg(sgp->sg_scriptID);
}

static int highlight_list_arg(int id, int didh, int type, int iarg, char_u *sarg, char *name)
{
  char_u buf[100];
  char_u      *ts;
  int i;

  if (got_int)
    return FALSE;
  if (type == LIST_STRING ? (sarg != NULL) : (iarg != 0)) {
    ts = buf;
    if (type == LIST_INT)
      sprintf((char *)buf, "%d", iarg - 1);
    else if (type == LIST_STRING)
      ts = sarg;
    else {   /* type == LIST_ATTR */
      buf[0] = NUL;
      for (i = 0; hl_attr_table[i] != 0; ++i) {
        if (iarg & hl_attr_table[i]) {
          if (buf[0] != NUL)
            vim_strcat(buf, (char_u *)",", 100);
          vim_strcat(buf, (char_u *)hl_name_table[i], 100);
          iarg &= ~hl_attr_table[i];                /* don't want "inverse" */
        }
      }
    }

    (void)syn_list_header(didh,
        (int)(vim_strsize(ts) + STRLEN(name) + 1), id);
    didh = TRUE;
    if (!got_int) {
      if (*name != NUL) {
        MSG_PUTS_ATTR(name, hl_attr(HLF_D));
        MSG_PUTS_ATTR("=", hl_attr(HLF_D));
      }
      msg_outtrans(ts);
    }
  }
  return didh;
}

/*
 * Return "1" if highlight group "id" has attribute "flag".
 * Return NULL otherwise.
 */
char_u *
highlight_has_attr (
    int id,
    int flag,
    int modec              /* 'g' for GUI, 'c' for cterm, 't' for term */
)
{
  int attr;

  if (id <= 0 || id > highlight_ga.ga_len)
    return NULL;

  if (modec == 'g')
    attr = HL_TABLE()[id - 1].sg_gui;
  else if (modec == 'c')
    attr = HL_TABLE()[id - 1].sg_cterm;
  else
    attr = HL_TABLE()[id - 1].sg_term;

  if (attr & flag)
    return (char_u *)"1";
  return NULL;
}

/*
 * Return color name of highlight group "id".
 */
char_u *
highlight_color (
    int id,
    char_u *what,      /* "font", "fg", "bg", "sp", "fg#", "bg#" or "sp#" */
    int modec              /* 'g' for GUI, 'c' for cterm, 't' for term */
)
{
  static char_u name[20];
  int n;
  int fg = FALSE;
  int sp = FALSE;
  int font = FALSE;

  if (id <= 0 || id > highlight_ga.ga_len)
    return NULL;

  if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'g')
    fg = TRUE;
  else if (TOLOWER_ASC(what[0]) == 'f' && TOLOWER_ASC(what[1]) == 'o'
           && TOLOWER_ASC(what[2]) == 'n' && TOLOWER_ASC(what[3]) == 't')
    font = TRUE;
  else if (TOLOWER_ASC(what[0]) == 's' && TOLOWER_ASC(what[1]) == 'p')
    sp = TRUE;
  else if (!(TOLOWER_ASC(what[0]) == 'b' && TOLOWER_ASC(what[1]) == 'g'))
    return NULL;
  if (modec == 'g') {
    if (fg)
      return HL_TABLE()[id - 1].sg_rgb_fg_name;
    if (sp)
      return NULL;
    return HL_TABLE()[id - 1].sg_rgb_bg_name;
  }
  if (font || sp)
    return NULL;
  if (modec == 'c') {
    if (fg)
      n = HL_TABLE()[id - 1].sg_cterm_fg - 1;
    else
      n = HL_TABLE()[id - 1].sg_cterm_bg - 1;
    sprintf((char *)name, "%d", n);
    return name;
  }
  /* term doesn't have color */
  return NULL;
}

/*
 * Output the syntax list header.
 * Return TRUE when started a new line.
 */
int 
syn_list_header (
    int did_header,                 /* did header already */
    int outlen,                     /* length of string that comes */
    int id                         /* highlight group id */
)
{
  int endcol = 19;
  int newline = TRUE;

  if (!did_header) {
    msg_putchar('\n');
    if (got_int)
      return TRUE;
    msg_outtrans(HL_TABLE()[id - 1].sg_name);
    endcol = 15;
  } else if (msg_col + outlen + 1 >= Columns)   {
    msg_putchar('\n');
    if (got_int)
      return TRUE;
  } else {
    if (msg_col >= endcol)      /* wrap around is like starting a new line */
      newline = FALSE;
  }

  if (msg_col >= endcol)        /* output at least one space */
    endcol = msg_col + 1;
  if (Columns <= endcol)        /* avoid hang for tiny window */
    endcol = Columns - 1;

  msg_advance(endcol);

  /* Show "xxx" with the attributes. */
  if (!did_header) {
    msg_puts_attr((char_u *)"xxx", syn_id2attr(id));
    msg_putchar(' ');
  }

  return newline;
}

/*
 * Set the attribute numbers for a highlight group.
 * Called after one of the attributes has changed.
 */
static void 
set_hl_attr (
    int idx                    /* index in array */
)
{
  attrentry_T at_en;
  struct hl_group     *sgp = HL_TABLE() + idx;

  /* The "Normal" group doesn't need an attribute number */
  if (sgp->sg_name_u != NULL && STRCMP(sgp->sg_name_u, "NORMAL") == 0)
    return;

  /*
   * For the term mode: If there are other than "normal" highlighting
   * attributes, need to allocate an attr number.
   */
  if (sgp->sg_start == NULL && sgp->sg_stop == NULL)
    sgp->sg_term_attr = sgp->sg_term;
  else {
    at_en.ae_attr = sgp->sg_term;
    at_en.ae_u.term.start = sgp->sg_start;
    at_en.ae_u.term.stop = sgp->sg_stop;
    sgp->sg_term_attr = get_attr_entry(&term_attr_table, &at_en);
  }

  /*
   * For the color term mode: If there are other than "normal"
   * highlighting attributes, need to allocate an attr number.
   */
  if (sgp->sg_cterm_fg == 0 && sgp->sg_cterm_bg == 0
      && sgp->sg_rgb_fg == -1 && sgp->sg_rgb_bg == -1) {
    sgp->sg_cterm_attr = sgp->sg_cterm;
  } else {
    at_en.ae_attr = abstract_ui ? sgp->sg_gui : sgp->sg_cterm;
    at_en.ae_u.cterm.fg_color = sgp->sg_cterm_fg;
    at_en.ae_u.cterm.bg_color = sgp->sg_cterm_bg;
    // FIXME(tarruda): The "unset value" for rgb is -1, but since hlgroup is
    // initialized with 0(by garray functions), check for sg_rgb_{f,b}g_name
    // before setting attr_entry->{f,g}g_color to a other than -1
    at_en.fg_color = sgp->sg_rgb_fg_name ? sgp->sg_rgb_fg : -1;
    at_en.bg_color = sgp->sg_rgb_bg_name ? sgp->sg_rgb_bg : -1;
    sgp->sg_cterm_attr = get_attr_entry(&cterm_attr_table, &at_en);
  }
}

/*
 * Lookup a highlight group name and return it's ID.
 * If it is not found, 0 is returned.
 */
int syn_name2id(char_u *name)
{
  int i;
  char_u name_u[200];

  /* Avoid using stricmp() too much, it's slow on some systems */
  /* Avoid alloc()/free(), these are slow too.  ID names over 200 chars
   * don't deserve to be found! */
  STRLCPY(name_u, name, 200);
  vim_strup(name_u);
  for (i = highlight_ga.ga_len; --i >= 0; )
    if (HL_TABLE()[i].sg_name_u != NULL
        && STRCMP(name_u, HL_TABLE()[i].sg_name_u) == 0)
      break;
  return i + 1;
}

/*
 * Return TRUE if highlight group "name" exists.
 */
int highlight_exists(char_u *name)
{
  return syn_name2id(name) > 0;
}

/*
 * Return the name of highlight group "id".
 * When not a valid ID return an empty string.
 */
char_u *syn_id2name(int id)
{
  if (id <= 0 || id > highlight_ga.ga_len)
    return (char_u *)"";
  return HL_TABLE()[id - 1].sg_name;
}

/*
 * Like syn_name2id(), but take a pointer + length argument.
 */
int syn_namen2id(char_u *linep, int len)
{
  char_u *name = vim_strnsave(linep, len);
  int id = syn_name2id(name);
  free(name);

  return id;
}

/*
 * Find highlight group name in the table and return it's ID.
 * The argument is a pointer to the name and the length of the name.
 * If it doesn't exist yet, a new entry is created.
 * Return 0 for failure.
 */
int syn_check_group(char_u *pp, int len)
{
  int id;
  char_u  *name;

  name = vim_strnsave(pp, len);

  id = syn_name2id(name);
  if (id == 0)                          /* doesn't exist yet */
    id = syn_add_group(name);
  else
    free(name);
  return id;
}

/*
 * Add new highlight group and return it's ID.
 * "name" must be an allocated string, it will be consumed.
 * Return 0 for failure.
 */
static int syn_add_group(char_u *name)
{
  char_u      *p;

  /* Check that the name is ASCII letters, digits and underscore. */
  for (p = name; *p != NUL; ++p) {
    if (!vim_isprintc(*p)) {
      EMSG(_("E669: Unprintable character in group name"));
      free(name);
      return 0;
    } else if (!ASCII_ISALNUM(*p) && *p != '_')   {
      /* This is an error, but since there previously was no check only
       * give a warning. */
      msg_source(hl_attr(HLF_W));
      MSG(_("W18: Invalid character in group name"));
      break;
    }
  }

  /*
   * First call for this growarray: init growing array.
   */
  if (highlight_ga.ga_data == NULL) {
    highlight_ga.ga_itemsize = sizeof(struct hl_group);
    ga_set_growsize(&highlight_ga, 10);
  }

  if (highlight_ga.ga_len >= MAX_HL_ID) {
    EMSG(_("E849: Too many highlight and syntax groups"));
    free(name);
    return 0;
  }

  // Append another syntax_highlight entry.
  struct hl_group* hlgp = GA_APPEND_VIA_PTR(struct hl_group, &highlight_ga);
  memset(hlgp, 0, sizeof(*hlgp));
  hlgp->sg_name = name;
  hlgp->sg_name_u = vim_strsave_up(name);

  return highlight_ga.ga_len;               /* ID is index plus one */
}

/*
 * When, just after calling syn_add_group(), an error is discovered, this
 * function deletes the new name.
 */
static void syn_unadd_group(void)
{
  --highlight_ga.ga_len;
  free(HL_TABLE()[highlight_ga.ga_len].sg_name);
  free(HL_TABLE()[highlight_ga.ga_len].sg_name_u);
}

/*
 * Translate a group ID to highlight attributes.
 */
int syn_id2attr(int hl_id)
{
  int attr;
  struct hl_group     *sgp;

  hl_id = syn_get_final_id(hl_id);
  sgp = &HL_TABLE()[hl_id - 1];             /* index is ID minus one */

  if (abstract_ui || t_colors > 1)
    attr = sgp->sg_cterm_attr;
  else
    attr = sgp->sg_term_attr;

  return attr;
}


/*
 * Translate a group ID to the final group ID (following links).
 */
int syn_get_final_id(int hl_id)
{
  int count;
  struct hl_group     *sgp;

  if (hl_id > highlight_ga.ga_len || hl_id < 1)
    return 0;                           /* Can be called from eval!! */

  /*
   * Follow links until there is no more.
   * Look out for loops!  Break after 100 links.
   */
  for (count = 100; --count >= 0; ) {
    sgp = &HL_TABLE()[hl_id - 1];           /* index is ID minus one */
    if (sgp->sg_link == 0 || sgp->sg_link > highlight_ga.ga_len)
      break;
    hl_id = sgp->sg_link;
  }

  return hl_id;
}


/*
 * Translate the 'highlight' option into attributes in highlight_attr[] and
 * set up the user highlights User1..9. A set of
 * corresponding highlights to use on top of HLF_SNC is computed.
 * Called only when the 'highlight' option has been changed and upon first
 * screen redraw after any :highlight command.
 * Return FAIL when an invalid flag is found in 'highlight'.  OK otherwise.
 */
int highlight_changed(void)
{
  int hlf;
  int i;
  char_u      *p;
  int attr;
  char_u      *end;
  int id;
#ifdef USER_HIGHLIGHT
  char_u userhl[10];
  int id_SNC = -1;
  int id_S = -1;
  int hlcnt;
#endif
  static int hl_flags[HLF_COUNT] = HL_FLAGS;

  need_highlight_changed = FALSE;

  /*
   * Clear all attributes.
   */
  for (hlf = 0; hlf < (int)HLF_COUNT; ++hlf)
    highlight_attr[hlf] = 0;

  /*
   * First set all attributes to their default value.
   * Then use the attributes from the 'highlight' option.
   */
  for (i = 0; i < 2; ++i) {
    if (i)
      p = p_hl;
    else
      p = get_highlight_default();
    if (p == NULL)          /* just in case */
      continue;

    while (*p) {
      for (hlf = 0; hlf < (int)HLF_COUNT; ++hlf)
        if (hl_flags[hlf] == *p)
          break;
      ++p;
      if (hlf == (int)HLF_COUNT || *p == NUL)
        return FAIL;

      /*
       * Allow several hl_flags to be combined, like "bu" for
       * bold-underlined.
       */
      attr = 0;
      for (; *p && *p != ','; ++p) {                /* parse upto comma */
        if (vim_iswhite(*p))                        /* ignore white space */
          continue;

        if (attr > HL_ALL)          /* Combination with ':' is not allowed. */
          return FAIL;

        switch (*p) {
        case 'b':   attr |= HL_BOLD;
          break;
        case 'i':   attr |= HL_ITALIC;
          break;
        case '-':
        case 'n':                                   /* no highlighting */
          break;
        case 'r':   attr |= HL_INVERSE;
          break;
        case 's':   attr |= HL_STANDOUT;
          break;
        case 'u':   attr |= HL_UNDERLINE;
          break;
        case 'c':   attr |= HL_UNDERCURL;
          break;
        case ':':   ++p;                            /* highlight group name */
          if (attr || *p == NUL)                         /* no combinations */
            return FAIL;
          end = vim_strchr(p, ',');
          if (end == NULL)
            end = p + STRLEN(p);
          id = syn_check_group(p, (int)(end - p));
          if (id == 0)
            return FAIL;
          attr = syn_id2attr(id);
          p = end - 1;
#ifdef USER_HIGHLIGHT
          if (hlf == (int)HLF_SNC)
            id_SNC = syn_get_final_id(id);
          else if (hlf == (int)HLF_S)
            id_S = syn_get_final_id(id);
#endif
          break;
        default:    return FAIL;
        }
      }
      highlight_attr[hlf] = attr;

      p = skip_to_option_part(p);           /* skip comma and spaces */
    }
  }

#ifdef USER_HIGHLIGHT
  /* Setup the user highlights
   *
   * Temporarily  utilize 10 more hl entries.  Have to be in there
   * simultaneously in case of table overflows in get_attr_entry()
   */
  ga_grow(&highlight_ga, 10);
  hlcnt = highlight_ga.ga_len;
  if (id_S == 0) {  /* Make sure id_S is always valid to simplify code below */
    memset(&HL_TABLE()[hlcnt + 9], 0, sizeof(struct hl_group));
    HL_TABLE()[hlcnt + 9].sg_term = highlight_attr[HLF_S];
    id_S = hlcnt + 10;
  }
  for (int i = 0; i < 9; i++) {
    sprintf((char *)userhl, "User%d", i + 1);
    id = syn_name2id(userhl);
    if (id == 0) {
      highlight_user[i] = 0;
      highlight_stlnc[i] = 0;
    } else {
      struct hl_group *hlt = HL_TABLE();

      highlight_user[i] = syn_id2attr(id);
      if (id_SNC == 0) {
        memset(&hlt[hlcnt + i], 0, sizeof(struct hl_group));
        hlt[hlcnt + i].sg_term = highlight_attr[HLF_SNC];
        hlt[hlcnt + i].sg_cterm = highlight_attr[HLF_SNC];
        hlt[hlcnt + i].sg_gui = highlight_attr[HLF_SNC];
      } else
        memmove(&hlt[hlcnt + i],
            &hlt[id_SNC - 1],
            sizeof(struct hl_group));
      hlt[hlcnt + i].sg_link = 0;

      /* Apply difference between UserX and HLF_S to HLF_SNC */
      hlt[hlcnt + i].sg_term ^=
        hlt[id - 1].sg_term ^ hlt[id_S - 1].sg_term;
      if (hlt[id - 1].sg_start != hlt[id_S - 1].sg_start)
        hlt[hlcnt + i].sg_start = hlt[id - 1].sg_start;
      if (hlt[id - 1].sg_stop != hlt[id_S - 1].sg_stop)
        hlt[hlcnt + i].sg_stop = hlt[id - 1].sg_stop;
      hlt[hlcnt + i].sg_cterm ^=
        hlt[id - 1].sg_cterm ^ hlt[id_S - 1].sg_cterm;
      if (hlt[id - 1].sg_cterm_fg != hlt[id_S - 1].sg_cterm_fg)
        hlt[hlcnt + i].sg_cterm_fg = hlt[id - 1].sg_cterm_fg;
      if (hlt[id - 1].sg_cterm_bg != hlt[id_S - 1].sg_cterm_bg)
        hlt[hlcnt + i].sg_cterm_bg = hlt[id - 1].sg_cterm_bg;
      hlt[hlcnt + i].sg_gui ^=
        hlt[id - 1].sg_gui ^ hlt[id_S - 1].sg_gui;
      highlight_ga.ga_len = hlcnt + i + 1;
      set_hl_attr(hlcnt + i);           /* At long last we can apply */
      highlight_stlnc[i] = syn_id2attr(hlcnt + i + 1);
    }
  }
  highlight_ga.ga_len = hlcnt;

#endif /* USER_HIGHLIGHT */

  return OK;
}


/*
 * Handle command line completion for :highlight command.
 */
void set_context_in_highlight_cmd(expand_T *xp, char_u *arg)
{
  char_u      *p;

  /* Default: expand group names */
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = arg;
  include_link = 2;
  include_default = 1;

  /* (part of) subcommand already typed */
  if (*arg != NUL) {
    p = skiptowhite(arg);
    if (*p != NUL) {                    /* past "default" or group name */
      include_default = 0;
      if (STRNCMP("default", arg, p - arg) == 0) {
        arg = skipwhite(p);
        xp->xp_pattern = arg;
        p = skiptowhite(arg);
      }
      if (*p != NUL) {                          /* past group name */
        include_link = 0;
        if (arg[1] == 'i' && arg[0] == 'N')
          highlight_list();
        if (STRNCMP("link", arg, p - arg) == 0
            || STRNCMP("clear", arg, p - arg) == 0) {
          xp->xp_pattern = skipwhite(p);
          p = skiptowhite(xp->xp_pattern);
          if (*p != NUL) {                      /* past first group name */
            xp->xp_pattern = skipwhite(p);
            p = skiptowhite(xp->xp_pattern);
          }
        }
        if (*p != NUL)                          /* past group name(s) */
          xp->xp_context = EXPAND_NOTHING;
      }
    }
  }
}

/*
 * List highlighting matches in a nice way.
 */
static void highlight_list(void)
{
  int i;

  for (i = 10; --i >= 0; )
    highlight_list_two(i, hl_attr(HLF_D));
  for (i = 40; --i >= 0; )
    highlight_list_two(99, 0);
}

static void highlight_list_two(int cnt, int attr)
{
  msg_puts_attr((char_u *)&("N \bI \b!  \b"[cnt / 11]), attr);
  msg_clr_eos();
  out_flush();
  os_delay(cnt == 99 ? 40L : (long)cnt * 50L, false);
}


/*
 * Function given to ExpandGeneric() to obtain the list of group names.
 * Also used for synIDattr() function.
 */
char_u *get_highlight_name(expand_T *xp, int idx)
{
  //TODO: 'xp' is unused
  if (idx == highlight_ga.ga_len && include_none != 0)
    return (char_u *)"none";
  if (idx == highlight_ga.ga_len + include_none && include_default != 0)
    return (char_u *)"default";
  if (idx == highlight_ga.ga_len + include_none + include_default
      && include_link != 0)
    return (char_u *)"link";
  if (idx == highlight_ga.ga_len + include_none + include_default + 1
      && include_link != 0)
    return (char_u *)"clear";
  if (idx < 0 || idx >= highlight_ga.ga_len)
    return NULL;
  return HL_TABLE()[idx].sg_name;
}

/*
 * Reset include_link, include_default, include_none to 0.
 * Called when we are done expanding.
 */
void reset_expand_highlight(void)
{
  include_link = include_default = include_none = 0;
}

/*
 * Handle command line completion for :match and :echohl command: Add "None"
 * as highlight group.
 */
void set_context_in_echohl_cmd(expand_T *xp, char_u *arg)
{
  xp->xp_context = EXPAND_HIGHLIGHT;
  xp->xp_pattern = arg;
  include_none = 1;
}

#define RGB(r, g, b) ((r << 16) | (g << 8) | b)
color_name_table_T color_name_table[] = {
  // Color names taken from
  // http://www.rapidtables.com/web/color/RGB_Color.htm
  {"Maroon", RGB(0x80, 0x00, 0x00)},
  {"DarkRed", RGB(0x8b, 0x00, 0x00)},
  {"Brown", RGB(0xa5, 0x2a, 0x2a)},
  {"Firebrick", RGB(0xb2, 0x22, 0x22)},
  {"Crimson", RGB(0xdc, 0x14, 0x3c)},
  {"Red", RGB(0xff, 0x00, 0x00)},
  {"Tomato", RGB(0xff, 0x63, 0x47)},
  {"Coral", RGB(0xff, 0x7f, 0x50)},
  {"IndianRed", RGB(0xcd, 0x5c, 0x5c)},
  {"LightCoral", RGB(0xf0, 0x80, 0x80)},
  {"DarkSalmon", RGB(0xe9, 0x96, 0x7a)},
  {"Salmon", RGB(0xfa, 0x80, 0x72)},
  {"LightSalmon", RGB(0xff, 0xa0, 0x7a)},
  {"OrangeRed", RGB(0xff, 0x45, 0x00)},
  {"DarkOrange", RGB(0xff, 0x8c, 0x00)},
  {"Orange", RGB(0xff, 0xa5, 0x00)},
  {"Gold", RGB(0xff, 0xd7, 0x00)},
  {"DarkGoldenRod", RGB(0xb8, 0x86, 0x0b)},
  {"GoldenRod", RGB(0xda, 0xa5, 0x20)},
  {"PaleGoldenRod", RGB(0xee, 0xe8, 0xaa)},
  {"DarkKhaki", RGB(0xbd, 0xb7, 0x6b)},
  {"Khaki", RGB(0xf0, 0xe6, 0x8c)},
  {"Olive", RGB(0x80, 0x80, 0x00)},
  {"Yellow", RGB(0xff, 0xff, 0x00)},
  {"YellowGreen", RGB(0x9a, 0xcd, 0x32)},
  {"DarkOliveGreen", RGB(0x55, 0x6b, 0x2f)},
  {"OliveDrab", RGB(0x6b, 0x8e, 0x23)},
  {"LawnGreen", RGB(0x7c, 0xfc, 0x00)},
  {"ChartReuse", RGB(0x7f, 0xff, 0x00)},
  {"GreenYellow", RGB(0xad, 0xff, 0x2f)},
  {"DarkGreen", RGB(0x00, 0x64, 0x00)},
  {"Green", RGB(0x00, 0x80, 0x00)},
  {"ForestGreen", RGB(0x22, 0x8b, 0x22)},
  {"Lime", RGB(0x00, 0xff, 0x00)},
  {"LimeGreen", RGB(0x32, 0xcd, 0x32)},
  {"LightGreen", RGB(0x90, 0xee, 0x90)},
  {"PaleGreen", RGB(0x98, 0xfb, 0x98)},
  {"DarkSeaGreen", RGB(0x8f, 0xbc, 0x8f)},
  {"MediumSpringGreen", RGB(0x00, 0xfa, 0x9a)},
  {"SpringGreen", RGB(0x00, 0xff, 0x7f)},
  {"SeaGreen", RGB(0x2e, 0x8b, 0x57)},
  {"MediumAquamarine", RGB(0x66, 0xcd, 0xaa)},
  {"MediumSeaGreen", RGB(0x3c, 0xb3, 0x71)},
  {"LightSeaGreen", RGB(0x20, 0xb2, 0xaa)},
  {"DarkSlateGray", RGB(0x2f, 0x4f, 0x4f)},
  {"Teal", RGB(0x00, 0x80, 0x80)},
  {"DarkCyan", RGB(0x00, 0x8b, 0x8b)},
  {"Aqua", RGB(0x00, 0xff, 0xff)},
  {"Cyan", RGB(0x00, 0xff, 0xff)},
  {"LightCyan", RGB(0xe0, 0xff, 0xff)},
  {"DarkTurquoise", RGB(0x00, 0xce, 0xd1)},
  {"Turquoise", RGB(0x40, 0xe0, 0xd0)},
  {"MediumTurquoise", RGB(0x48, 0xd1, 0xcc)},
  {"PaleTurquoise", RGB(0xaf, 0xee, 0xee)},
  {"Aquamarine", RGB(0x7f, 0xff, 0xd4)},
  {"PowderBlue", RGB(0xb0, 0xe0, 0xe6)},
  {"CadetBlue", RGB(0x5f, 0x9e, 0xa0)},
  {"SteelBlue", RGB(0x46, 0x82, 0xb4)},
  {"CornFlowerBlue", RGB(0x64, 0x95, 0xed)},
  {"DeepSkyBlue", RGB(0x00, 0xbf, 0xff)},
  {"DodgerBlue", RGB(0x1e, 0x90, 0xff)},
  {"LightBlue", RGB(0xad, 0xd8, 0xe6)},
  {"SkyBlue", RGB(0x87, 0xce, 0xeb)},
  {"LightSkyBlue", RGB(0x87, 0xce, 0xfa)},
  {"MidnightBlue", RGB(0x19, 0x19, 0x70)},
  {"Navy", RGB(0x00, 0x00, 0x80)},
  {"DarkBlue", RGB(0x00, 0x00, 0x8b)},
  {"MediumBlue", RGB(0x00, 0x00, 0xcd)},
  {"Blue", RGB(0x00, 0x00, 0xff)},
  {"RoyalBlue", RGB(0x41, 0x69, 0xe1)},
  {"BlueViolet", RGB(0x8a, 0x2b, 0xe2)},
  {"Indigo", RGB(0x4b, 0x00, 0x82)},
  {"DarkSlateBlue", RGB(0x48, 0x3d, 0x8b)},
  {"SlateBlue", RGB(0x6a, 0x5a, 0xcd)},
  {"MediumSlateBlue", RGB(0x7b, 0x68, 0xee)},
  {"MediumPurple", RGB(0x93, 0x70, 0xdb)},
  {"DarkMagenta", RGB(0x8b, 0x00, 0x8b)},
  {"DarkViolet", RGB(0x94, 0x00, 0xd3)},
  {"DarkOrchid", RGB(0x99, 0x32, 0xcc)},
  {"MediumOrchid", RGB(0xba, 0x55, 0xd3)},
  {"Purple", RGB(0x80, 0x00, 0x80)},
  {"Thistle", RGB(0xd8, 0xbf, 0xd8)},
  {"Plum", RGB(0xdd, 0xa0, 0xdd)},
  {"Violet", RGB(0xee, 0x82, 0xee)},
  {"Magenta", RGB(0xff, 0x00, 0xff)},
  {"Fuchsia", RGB(0xff, 0x00, 0xff)},
  {"Orchid", RGB(0xda, 0x70, 0xd6)},
  {"MediumVioletRed", RGB(0xc7, 0x15, 0x85)},
  {"PaleVioletRed", RGB(0xdb, 0x70, 0x93)},
  {"DeepPink", RGB(0xff, 0x14, 0x93)},
  {"HotPink", RGB(0xff, 0x69, 0xb4)},
  {"LightPink", RGB(0xff, 0xb6, 0xc1)},
  {"Pink", RGB(0xff, 0xc0, 0xcb)},
  {"AntiqueWhite", RGB(0xfa, 0xeb, 0xd7)},
  {"Beige", RGB(0xf5, 0xf5, 0xdc)},
  {"Bisque", RGB(0xff, 0xe4, 0xc4)},
  {"BlanchedAlmond", RGB(0xff, 0xeb, 0xcd)},
  {"Wheat", RGB(0xf5, 0xde, 0xb3)},
  {"Cornsilk", RGB(0xff, 0xf8, 0xdc)},
  {"LemonChiffon", RGB(0xff, 0xfa, 0xcd)},
  {"LightGoldenRodYellow", RGB(0xfa, 0xfa, 0xd2)},
  {"LightYellow", RGB(0xff, 0xff, 0xe0)},
  {"SaddleBrown", RGB(0x8b, 0x45, 0x13)},
  {"Sienna", RGB(0xa0, 0x52, 0x2d)},
  {"Chocolate", RGB(0xd2, 0x69, 0x1e)},
  {"Peru", RGB(0xcd, 0x85, 0x3f)},
  {"SandyBrown", RGB(0xf4, 0xa4, 0x60)},
  {"BurlyWood", RGB(0xde, 0xb8, 0x87)},
  {"Tan", RGB(0xd2, 0xb4, 0x8c)},
  {"RosyBrown", RGB(0xbc, 0x8f, 0x8f)},
  {"Moccasin", RGB(0xff, 0xe4, 0xb5)},
  {"NavajoWhite", RGB(0xff, 0xde, 0xad)},
  {"PeachPuff", RGB(0xff, 0xda, 0xb9)},
  {"MistyRose", RGB(0xff, 0xe4, 0xe1)},
  {"LavenderBlush", RGB(0xff, 0xf0, 0xf5)},
  {"Linen", RGB(0xfa, 0xf0, 0xe6)},
  {"Oldlace", RGB(0xfd, 0xf5, 0xe6)},
  {"PapayaWhip", RGB(0xff, 0xef, 0xd5)},
  {"SeaShell", RGB(0xff, 0xf5, 0xee)},
  {"MintCream", RGB(0xf5, 0xff, 0xfa)},
  {"SlateGray", RGB(0x70, 0x80, 0x90)},
  {"LightSlateGray", RGB(0x77, 0x88, 0x99)},
  {"LightSteelBlue", RGB(0xb0, 0xc4, 0xde)},
  {"Lavender", RGB(0xe6, 0xe6, 0xfa)},
  {"FloralWhite", RGB(0xff, 0xfa, 0xf0)},
  {"AliceBlue", RGB(0xf0, 0xf8, 0xff)},
  {"GhostWhite", RGB(0xf8, 0xf8, 0xff)},
  {"Honeydew", RGB(0xf0, 0xff, 0xf0)},
  {"Ivory", RGB(0xff, 0xff, 0xf0)},
  {"Azure", RGB(0xf0, 0xff, 0xff)},
  {"Snow", RGB(0xff, 0xfa, 0xfa)},
  {"Black", RGB(0x00, 0x00, 0x00)},
  {"DimGray", RGB(0x69, 0x69, 0x69)},
  {"DimGrey", RGB(0x69, 0x69, 0x69)},
  {"Gray", RGB(0x80, 0x80, 0x80)},
  {"Grey", RGB(0x80, 0x80, 0x80)},
  {"DarkGray", RGB(0xa9, 0xa9, 0xa9)},
  {"DarkGrey", RGB(0xa9, 0xa9, 0xa9)},
  {"Silver", RGB(0xc0, 0xc0, 0xc0)},
  {"LightGray", RGB(0xd3, 0xd3, 0xd3)},
  {"LightGrey", RGB(0xd3, 0xd3, 0xd3)},
  {"Gainsboro", RGB(0xdc, 0xdc, 0xdc)},
  {"WhiteSmoke", RGB(0xf5, 0xf5, 0xf5)},
  {"White", RGB(0xff, 0xff, 0xff)},
  // The color names below were taken from gui_x11.c in vim source 
  {"LightRed", RGB(0xff, 0xbb, 0xbb)},
  {"LightMagenta",RGB(0xff, 0xbb, 0xff)},
  {"DarkYellow", RGB(0xbb, 0xbb, 0x00)},
  {"Gray10", RGB(0x1a, 0x1a, 0x1a)},
  {"Grey10", RGB(0x1a, 0x1a, 0x1a)},
  {"Gray20", RGB(0x33, 0x33, 0x33)},
  {"Grey20", RGB(0x33, 0x33, 0x33)},
  {"Gray30", RGB(0x4d, 0x4d, 0x4d)},
  {"Grey30", RGB(0x4d, 0x4d, 0x4d)},
  {"Gray40", RGB(0x66, 0x66, 0x66)},
  {"Grey40", RGB(0x66, 0x66, 0x66)},
  {"Gray50", RGB(0x7f, 0x7f, 0x7f)},
  {"Grey50", RGB(0x7f, 0x7f, 0x7f)},
  {"Gray60", RGB(0x99, 0x99, 0x99)},
  {"Grey60", RGB(0x99, 0x99, 0x99)},
  {"Gray70", RGB(0xb3, 0xb3, 0xb3)},
  {"Grey70", RGB(0xb3, 0xb3, 0xb3)},
  {"Gray80", RGB(0xcc, 0xcc, 0xcc)},
  {"Grey80", RGB(0xcc, 0xcc, 0xcc)},
  {"Gray90", RGB(0xe5, 0xe5, 0xe5)},
  {"Grey90", RGB(0xe5, 0xe5, 0xe5)},
  {NULL, 0},
};

RgbValue name_to_color(uint8_t *name)
{

  if (name[0] == '#' && isxdigit(name[1]) && isxdigit(name[2])
      && isxdigit(name[3]) && isxdigit(name[4]) && isxdigit(name[5])
      && isxdigit(name[6]) && name[7] == NUL) {
    // rgb hex string
    return strtol((char *)(name + 1), NULL, 16);
  }

  for (int i = 0; color_name_table[i].name != NULL; i++) {
    if (!STRICMP(name, color_name_table[i].name)) {
      return color_name_table[i].color;
    }
  }

  return -1;
}

