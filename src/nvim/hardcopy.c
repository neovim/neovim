// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * hardcopy.c: printing to paper
 */

#include <assert.h>
#include <string.h>
#include <inttypes.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/hardcopy.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/garray.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/version.h"
#include "nvim/os/os.h"
#include "nvim/os/input.h"

/*
 * To implement printing on a platform, the following functions must be
 * defined:
 *
 * int mch_print_init(prt_settings_T *psettings, char_u *jobname, int forceit)
 * Called once.  Code should display printer dialogue (if appropriate) and
 * determine printer font and margin settings.  Reset has_color if the printer
 * doesn't support colors at all.
 * Returns FAIL to abort.
 *
 * int mch_print_begin(prt_settings_T *settings)
 * Called to start the print job.
 * Return FALSE to abort.
 *
 * int mch_print_begin_page(char_u *msg)
 * Called at the start of each page.
 * "msg" indicates the progress of the print job, can be NULL.
 * Return FALSE to abort.
 *
 * int mch_print_end_page()
 * Called at the end of each page.
 * Return FALSE to abort.
 *
 * int mch_print_blank_page()
 * Called to generate a blank page for collated, duplex, multiple copy
 * document.  Return FALSE to abort.
 *
 * void mch_print_end(prt_settings_T *psettings)
 * Called at normal end of print job.
 *
 * void mch_print_cleanup()
 * Called if print job ends normally or is abandoned. Free any memory, close
 * devices and handles.  Also called when mch_print_begin() fails, but not
 * when mch_print_init() fails.
 *
 * void mch_print_set_font(int Bold, int Italic, int Underline);
 * Called whenever the font style changes.
 *
 * void mch_print_set_bg(uint32_t bgcol);
 * Called to set the background color for the following text. Parameter is an
 * RGB value.
 *
 * void mch_print_set_fg(uint32_t fgcol);
 * Called to set the foreground color for the following text. Parameter is an
 * RGB value.
 *
 * mch_print_start_line(int margin, int page_line)
 * Sets the current position at the start of line "page_line".
 * If margin is TRUE start in the left margin (for header and line number).
 *
 * int mch_print_text_out(char_u *p, size_t len);
 * Output one character of text p[len] at the current position.
 * Return TRUE if there is no room for another character in the same line.
 *
 * Note that the generic code has no idea of margins. The machine code should
 * simply make the page look smaller!  The header and the line numbers are
 * printed in the margin.
 */

static option_table_T printer_opts[OPT_PRINT_NUM_OPTIONS]
  =
  {
  {"top",     TRUE, 0, NULL, 0, FALSE},
  {"bottom",  TRUE, 0, NULL, 0, FALSE},
  {"left",    TRUE, 0, NULL, 0, FALSE},
  {"right",   TRUE, 0, NULL, 0, FALSE},
  {"header",  TRUE, 0, NULL, 0, FALSE},
  {"syntax",  FALSE, 0, NULL, 0, FALSE},
  {"number",  FALSE, 0, NULL, 0, FALSE},
  {"wrap",    FALSE, 0, NULL, 0, FALSE},
  {"duplex",  FALSE, 0, NULL, 0, FALSE},
  {"portrait", FALSE, 0, NULL, 0, FALSE},
  {"paper",   FALSE, 0, NULL, 0, FALSE},
  {"collate", FALSE, 0, NULL, 0, FALSE},
  {"jobsplit", FALSE, 0, NULL, 0, FALSE},
  {"formfeed", FALSE, 0, NULL, 0, FALSE},
  }
;


static const uint32_t cterm_color_8[8] = {
  0x000000, 0xff0000, 0x00ff00, 0xffff00,
  0x0000ff, 0xff00ff, 0x00ffff, 0xffffff
};

static const uint32_t cterm_color_16[16] = {
  0x000000, 0x0000c0, 0x008000, 0x004080,
  0xc00000, 0xc000c0, 0x808000, 0xc0c0c0,
  0x808080, 0x6060ff, 0x00ff00, 0x00ffff,
  0xff8080, 0xff40ff, 0xffff00, 0xffffff
};

static int current_syn_id;

#define PRCOLOR_BLACK 0
#define PRCOLOR_WHITE 0xffffff

static TriState curr_italic;
static TriState curr_bold;
static TriState curr_underline;
static uint32_t curr_bg;
static uint32_t curr_fg;
static int page_count;

# define OPT_MBFONT_USECOURIER  0
# define OPT_MBFONT_ASCII       1
# define OPT_MBFONT_REGULAR     2
# define OPT_MBFONT_BOLD        3
# define OPT_MBFONT_OBLIQUE     4
# define OPT_MBFONT_BOLDOBLIQUE 5
# define OPT_MBFONT_NUM_OPTIONS 6

static option_table_T mbfont_opts[OPT_MBFONT_NUM_OPTIONS] =
{
  {"c",       FALSE, 0, NULL, 0, FALSE},
  {"a",       FALSE, 0, NULL, 0, FALSE},
  {"r",       FALSE, 0, NULL, 0, FALSE},
  {"b",       FALSE, 0, NULL, 0, FALSE},
  {"i",       FALSE, 0, NULL, 0, FALSE},
  {"o",       FALSE, 0, NULL, 0, FALSE},
};

/*
 * These values determine the print position on a page.
 */
typedef struct {
  int lead_spaces;                  /* remaining spaces for a TAB */
  int print_pos;                    /* virtual column for computing TABs */
  colnr_T column;                   /* byte column */
  linenr_T file_line;               /* line nr in the buffer */
  size_t bytes_printed;             /* bytes printed so far */
  int ff;                           /* seen form feed character */
} prt_pos_T;

struct prt_mediasize_S {
  char *name;
  double width;                  /* width and height in points for portrait */
  double height;
};

/* PS font names, must be in Roman, Bold, Italic, Bold-Italic order */
struct prt_ps_font_S {
  int wx;
  int uline_offset;
  int uline_width;
  int bbox_min_y;
  int bbox_max_y;
  char        *(ps_fontname[4]);
};

/* Structures to map user named encoding and mapping to PS equivalents for
 * building CID font name */
struct prt_ps_encoding_S {
  char        *encoding;
  char        *cmap_encoding;
  int needs_charset;
};

struct prt_ps_charset_S {
  char        *charset;
  char        *cmap_charset;
  int has_charset;
};

/* Collections of encodings and charsets for multi-byte printing */
struct prt_ps_mbfont_S {
  int num_encodings;
  struct prt_ps_encoding_S    *encodings;
  int num_charsets;
  struct prt_ps_charset_S     *charsets;
  char                        *ascii_enc;
  char                        *defcs;
};

struct prt_ps_resource_S {
  char_u name[64];
  char_u filename[MAXPATHL + 1];
  int type;
  char_u title[256];
  char_u version[256];
};

struct prt_dsc_comment_S {
  char        *string;
  int len;
  int type;
};

struct prt_dsc_line_S {
  int type;
  char_u      *string;
  int len;
};

/* Static buffer to read initial comments in a resource file, some can have a
 * couple of KB of comments! */
#define PRT_FILE_BUFFER_LEN (2048)
struct prt_resfile_buffer_S {
  char_u buffer[PRT_FILE_BUFFER_LEN];
  int len;
  int line_start;
  int line_end;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "hardcopy.c.generated.h"
#endif

/*
 * Parse 'printoptions' and set the flags in "printer_opts".
 * Returns an error message or NULL;
 */
char_u *parse_printoptions(void)
{
  return parse_list_options(p_popt, printer_opts, OPT_PRINT_NUM_OPTIONS);
}

/*
 * Parse 'printoptions' and set the flags in "printer_opts".
 * Returns an error message or NULL;
 */
char_u *parse_printmbfont(void)
{
  return parse_list_options(p_pmfn, mbfont_opts, OPT_MBFONT_NUM_OPTIONS);
}

/*
 * Parse a list of options in the form
 * option:value,option:value,option:value
 *
 * "value" can start with a number which is parsed out, e.g.  margin:12mm
 *
 * Returns an error message for an illegal option, NULL otherwise.
 * Only used for the printer at the moment...
 */
static char_u *parse_list_options(char_u *option_str, option_table_T *table,
                                  size_t table_size)
{
  option_table_T *old_opts;
  char_u      *ret = NULL;
  char_u      *stringp;
  char_u      *colonp;
  char_u      *commap;
  char_u      *p;
  size_t idx = 0;                          // init for GCC
  int len;

  // Save the old values, so that they can be restored in case of an error.
  old_opts = (option_table_T *)xmalloc(sizeof(option_table_T) * table_size);

  for (idx = 0; idx < table_size; idx++) {
    old_opts[idx] = table[idx];
    table[idx].present = false;
  }

  /*
   * Repeat for all comma separated parts.
   */
  stringp = option_str;
  while (*stringp) {
    colonp = vim_strchr(stringp, ':');
    if (colonp == NULL) {
      ret = (char_u *)N_("E550: Missing colon");
      break;
    }
    commap = vim_strchr(stringp, ',');
    if (commap == NULL)
      commap = option_str + STRLEN(option_str);

    len = (int)(colonp - stringp);

    for (idx = 0; idx < table_size; ++idx)
      if (STRNICMP(stringp, table[idx].name, len) == 0)
        break;

    if (idx == table_size) {
      ret = (char_u *)N_("E551: Illegal component");
      break;
    }

    p = colonp + 1;
    table[idx].present = TRUE;

    if (table[idx].hasnum) {
      if (!ascii_isdigit(*p)) {
        ret = (char_u *)N_("E552: digit expected");
        break;
      }

      table[idx].number = getdigits_int(&p);
    }

    table[idx].string = p;
    table[idx].strlen = (int)(commap - p);

    stringp = commap;
    if (*stringp == ',')
      ++stringp;
  }

  if (ret != NULL) {
    // Restore old options in case of error
    for (idx = 0; idx < table_size; idx++) {
      table[idx] = old_opts[idx];
    }
  }

  xfree(old_opts);
  return ret;
}


/*
 * If using a dark background, the colors will probably be too bright to show
 * up well on white paper, so reduce their brightness.
 */
static uint32_t darken_rgb(uint32_t rgb)
{
  return ((rgb >> 17) << 16)
         +   (((rgb & 0xff00) >> 9) << 8)
         +   ((rgb & 0xff) >> 1);
}

static uint32_t prt_get_term_color(int colorindex)
{
  /* TODO: Should check for xterm with 88 or 256 colors. */
  if (t_colors > 8)
    return cterm_color_16[colorindex % 16];
  return cterm_color_8[colorindex % 8];
}

static void prt_get_attr(int hl_id, prt_text_attr_T *pattr, int modec)
{
  int colorindex;
  uint32_t fg_color;

  pattr->bold = (highlight_has_attr(hl_id, HL_BOLD, modec) != NULL);
  pattr->italic = (highlight_has_attr(hl_id, HL_ITALIC, modec) != NULL);
  pattr->underline = (highlight_has_attr(hl_id, HL_UNDERLINE, modec) != NULL);
  pattr->undercurl = (highlight_has_attr(hl_id, HL_UNDERCURL, modec) != NULL);

  {
    const char *color = highlight_color(hl_id, "fg", modec);
    if (color == NULL) {
      colorindex = 0;
    } else {
      colorindex = atoi(color);
    }

    if (colorindex >= 0 && colorindex < t_colors)
      fg_color = prt_get_term_color(colorindex);
    else
      fg_color = PRCOLOR_BLACK;
  }

  if (fg_color == PRCOLOR_WHITE)
    fg_color = PRCOLOR_BLACK;
  else if (*p_bg == 'd')
    fg_color = darken_rgb(fg_color);

  pattr->fg_color = fg_color;
  pattr->bg_color = PRCOLOR_WHITE;
}

static void prt_set_fg(uint32_t fg)
{
  if (fg != curr_fg) {
    curr_fg = fg;
    mch_print_set_fg(fg);
  }
}

static void prt_set_bg(uint32_t bg)
{
  if (bg != curr_bg) {
    curr_bg = bg;
    mch_print_set_bg(bg);
  }
}

static void prt_set_font(const TriState bold, const TriState italic,
                         const TriState underline)
{
  if (curr_bold != bold
      || curr_italic != italic
      || curr_underline != underline) {
    curr_underline = underline;
    curr_italic = italic;
    curr_bold = bold;
    mch_print_set_font(bold, italic, underline);
  }
}

// Print the line number in the left margin.
static void prt_line_number(prt_settings_T *const psettings,
                            const int page_line, const linenr_T lnum)
{
  prt_set_fg(psettings->number.fg_color);
  prt_set_bg(psettings->number.bg_color);
  prt_set_font(psettings->number.bold, psettings->number.italic,
               psettings->number.underline);
  mch_print_start_line(true, page_line);

  // Leave two spaces between the number and the text; depends on
  // PRINT_NUMBER_WIDTH.
  char_u tbuf[20];
  snprintf((char *)tbuf, sizeof(tbuf), "%6ld", (long)lnum);
  for (int i = 0; i < 6; i++) {
    (void)mch_print_text_out(&tbuf[i], 1);
  }

  if (psettings->do_syntax) {
    // Set colors for next character.
    current_syn_id = -1;
  } else {
    // Set colors and font back to normal.
    prt_set_fg(PRCOLOR_BLACK);
    prt_set_bg(PRCOLOR_WHITE);
    prt_set_font(kFalse, kFalse, kFalse);
  }
}

/*
 * Get the currently effective header height.
 */
int prt_header_height(void)
{
  if (printer_opts[OPT_PRINT_HEADERHEIGHT].present) {
    return printer_opts[OPT_PRINT_HEADERHEIGHT].number;
  }
  return 2;
}

/*
 * Return TRUE if using a line number for printing.
 */
int prt_use_number(void)
{
  return printer_opts[OPT_PRINT_NUMBER].present
         && TOLOWER_ASC(printer_opts[OPT_PRINT_NUMBER].string[0]) == 'y';
}

/*
 * Return the unit used in a margin item in 'printoptions'.
 * Returns PRT_UNIT_NONE if not recognized.
 */
int prt_get_unit(int idx)
{
  int u = PRT_UNIT_NONE;
  int i;
  static char *(units[4]) = PRT_UNIT_NAMES;

  if (printer_opts[idx].present)
    for (i = 0; i < 4; ++i)
      if (STRNICMP(printer_opts[idx].string, units[i], 2) == 0) {
        u = i;
        break;
      }
  return u;
}

// Print the page header.
static void prt_header(prt_settings_T *const psettings, const int pagenum,
                       const linenr_T lnum)
{
  int width = psettings->chars_per_line;

  // Also use the space for the line number.
  if (prt_use_number()) {
    width += PRINT_NUMBER_WIDTH;
  }

  assert(width >= 0);
  const size_t tbuf_size = (size_t)width + IOSIZE;
  char_u *tbuf = xmalloc(tbuf_size);

  if (*p_header != NUL) {
    linenr_T tmp_lnum, tmp_topline, tmp_botline;
    int use_sandbox = FALSE;

    /*
     * Need to (temporarily) set current line number and first/last line
     * number on the 'window'.  Since we don't know how long the page is,
     * set the first and current line number to the top line, and guess
     * that the page length is 64.
     */
    tmp_lnum = curwin->w_cursor.lnum;
    tmp_topline = curwin->w_topline;
    tmp_botline = curwin->w_botline;
    curwin->w_cursor.lnum = lnum;
    curwin->w_topline = lnum;
    curwin->w_botline = lnum + 63;
    printer_page_num = pagenum;

    use_sandbox = was_set_insecurely((char_u *)"printheader", 0);
    build_stl_str_hl(curwin, tbuf, (size_t)width + IOSIZE,
        p_header, use_sandbox,
        ' ', width, NULL, NULL);

    /* Reset line numbers */
    curwin->w_cursor.lnum = tmp_lnum;
    curwin->w_topline = tmp_topline;
    curwin->w_botline = tmp_botline;
  } else {
    snprintf((char *)tbuf, tbuf_size, _("Page %d"), pagenum);
  }

  prt_set_fg(PRCOLOR_BLACK);
  prt_set_bg(PRCOLOR_WHITE);
  prt_set_font(kTrue, kFalse, kFalse);

  // Use a negative line number to indicate printing in the top margin.
  int page_line = 0 - prt_header_height();
  mch_print_start_line(true, page_line);
  for (char_u *p = tbuf; *p != NUL; ) {
    const int l = (*mb_ptr2len)(p);
    assert(l >= 0);
    if (mch_print_text_out(p, (size_t)l)) {
      page_line++;
      if (page_line >= 0) {     // out of room in header
        break;
      }
      mch_print_start_line(true, page_line);
    }
    p += l;
  }

  xfree(tbuf);

  if (psettings->do_syntax) {
    // Set colors for next character.
    current_syn_id = -1;
  } else {
    // Set colors and font back to normal.
    prt_set_fg(PRCOLOR_BLACK);
    prt_set_bg(PRCOLOR_WHITE);
    prt_set_font(kFalse, kFalse, kFalse);
  }
}

/*
 * Display a print status message.
 */
static void prt_message(char_u *s)
{
  // TODO(bfredl): delete this
  grid_fill(&default_grid, Rows - 1, Rows, 0, Columns, ' ', ' ', 0);
  grid_puts(&default_grid, s, Rows - 1, 0, HL_ATTR(HLF_R));
  ui_flush();
}

void ex_hardcopy(exarg_T *eap)
{
  linenr_T lnum;
  int collated_copies, uncollated_copies;
  prt_settings_T settings;
  size_t bytes_to_print = 0;
  int page_line;
  int jobsplit;

  memset(&settings, 0, sizeof(prt_settings_T));
  settings.has_color = TRUE;

  if (*eap->arg == '>') {
    char_u  *errormsg = NULL;

    /* Expand things like "%.ps". */
    if (expand_filename(eap, eap->cmdlinep, &errormsg) == FAIL) {
      if (errormsg != NULL)
        EMSG(errormsg);
      return;
    }
    settings.outfile = skipwhite(eap->arg + 1);
  } else if (*eap->arg != NUL)
    settings.arguments = eap->arg;

  /*
   * Initialise for printing.  Ask the user for settings, unless forceit is
   * set.
   * The mch_print_init() code should set up margins if applicable. (It may
   * not be a real printer - for example the engine might generate HTML or
   * PS.)
   */
  if (mch_print_init(&settings,
          curbuf->b_fname == NULL
          ? (char_u *)buf_spname(curbuf)
          : curbuf->b_sfname == NULL
          ? curbuf->b_fname
          : curbuf->b_sfname,
          eap->forceit) == FAIL)
    return;

  settings.modec = 'c';

  if (!syntax_present(curwin))
    settings.do_syntax = FALSE;
  else if (printer_opts[OPT_PRINT_SYNTAX].present
           && TOLOWER_ASC(printer_opts[OPT_PRINT_SYNTAX].string[0]) != 'a')
    settings.do_syntax =
      (TOLOWER_ASC(printer_opts[OPT_PRINT_SYNTAX].string[0]) == 'y');
  else
    settings.do_syntax = settings.has_color;

  // Set up printing attributes for line numbers
  settings.number.fg_color = PRCOLOR_BLACK;
  settings.number.bg_color = PRCOLOR_WHITE;
  settings.number.bold = kFalse;
  settings.number.italic = kTrue;
  settings.number.underline = kFalse;

  // Syntax highlighting of line numbers.
  if (prt_use_number() && settings.do_syntax) {
    int id = syn_name2id((char_u *)"LineNr");
    if (id > 0) {
      id = syn_get_final_id(id);
    }

    prt_get_attr(id, &settings.number, settings.modec);
  }

  /*
   * Estimate the total lines to be printed
   */
  for (lnum = eap->line1; lnum <= eap->line2; lnum++)
    bytes_to_print += STRLEN(skipwhite(ml_get(lnum)));
  if (bytes_to_print == 0) {
    MSG(_("No text to be printed"));
    goto print_fail_no_begin;
  }

  /* Set colors and font to normal. */
  curr_bg = 0xffffffff;
  curr_fg = 0xffffffff;
  curr_italic = kNone;
  curr_bold = kNone;
  curr_underline = kNone;

  prt_set_fg(PRCOLOR_BLACK);
  prt_set_bg(PRCOLOR_WHITE);
  prt_set_font(kFalse, kFalse, kFalse);
  current_syn_id = -1;

  jobsplit = (printer_opts[OPT_PRINT_JOBSPLIT].present
              && TOLOWER_ASC(printer_opts[OPT_PRINT_JOBSPLIT].string[0]) == 'y');

  if (!mch_print_begin(&settings))
    goto print_fail_no_begin;

  /*
   * Loop over collated copies: 1 2 3, 1 2 3, ...
   */
  page_count = 0;
  for (collated_copies = 0;
       collated_copies < settings.n_collated_copies;
       collated_copies++) {
    prt_pos_T prtpos;                   /* current print position */
    prt_pos_T page_prtpos;              /* print position at page start */
    int side;

    memset(&page_prtpos, 0, sizeof(prt_pos_T));
    page_prtpos.file_line = eap->line1;
    prtpos = page_prtpos;

    if (jobsplit && collated_copies > 0) {
      /* Splitting jobs: Stop a previous job and start a new one. */
      mch_print_end(&settings);
      if (!mch_print_begin(&settings))
        goto print_fail_no_begin;
    }

    /*
     * Loop over all pages in the print job: 1 2 3 ...
     */
    for (page_count = 0; prtpos.file_line <= eap->line2; ++page_count) {
      /*
       * Loop over uncollated copies: 1 1 1, 2 2 2, 3 3 3, ...
       * For duplex: 12 12 12 34 34 34, ...
       */
      for (uncollated_copies = 0;
           uncollated_copies < settings.n_uncollated_copies;
           uncollated_copies++) {
        /* Set the print position to the start of this page. */
        prtpos = page_prtpos;

        /*
         * Do front and rear side of a page.
         */
        for (side = 0; side <= settings.duplex; ++side) {
          /*
           * Print one page.
           */

          /* Check for interrupt character every page. */
          os_breakcheck();
          if (got_int || settings.user_abort)
            goto print_fail;

          assert(prtpos.bytes_printed <= SIZE_MAX / 100);
          sprintf((char *)IObuff, _("Printing page %d (%zu%%)"),
                  page_count + 1 + side,
                  prtpos.bytes_printed * 100 / bytes_to_print);
          if (!mch_print_begin_page(IObuff))
            goto print_fail;

          if (settings.n_collated_copies > 1)
            sprintf((char *)IObuff + STRLEN(IObuff),
                _(" Copy %d of %d"),
                collated_copies + 1,
                settings.n_collated_copies);
          prt_message(IObuff);

          /*
           * Output header if required
           */
          if (prt_header_height() > 0)
            prt_header(&settings, page_count + 1 + side,
                prtpos.file_line);

          for (page_line = 0; page_line < settings.lines_per_page;
               ++page_line) {
            prtpos.column = hardcopy_line(&settings,
                page_line, &prtpos);
            if (prtpos.column == 0) {
              /* finished a file line */
              prtpos.bytes_printed +=
                STRLEN(skipwhite(ml_get(prtpos.file_line)));
              if (++prtpos.file_line > eap->line2)
                break;                 /* reached the end */
            } else if (prtpos.ff) {
              /* Line had a formfeed in it - start new page but
               * stay on the current line */
              break;
            }
          }

          if (!mch_print_end_page())
            goto print_fail;
          if (prtpos.file_line > eap->line2)
            break;             /* reached the end */
        }

        /*
         * Extra blank page for duplexing with odd number of pages and
         * more copies to come.
         */
        if (prtpos.file_line > eap->line2 && settings.duplex
            && side == 0
            && uncollated_copies + 1 < settings.n_uncollated_copies) {
          if (!mch_print_blank_page())
            goto print_fail;
        }
      }
      if (settings.duplex && prtpos.file_line <= eap->line2)
        ++page_count;

      /* Remember the position where the next page starts. */
      page_prtpos = prtpos;
    }

    vim_snprintf((char *)IObuff, IOSIZE, _("Printed: %s"),
        settings.jobname);
    prt_message(IObuff);
  }

print_fail:
  if (got_int || settings.user_abort) {
    sprintf((char *)IObuff, "%s", _("Printing aborted"));
    prt_message(IObuff);
  }
  mch_print_end(&settings);

print_fail_no_begin:
  mch_print_cleanup();
}

/*
 * Print one page line.
 * Return the next column to print, or zero if the line is finished.
 */
static colnr_T hardcopy_line(prt_settings_T *psettings, int page_line, prt_pos_T *ppos)
{
  colnr_T col;
  char_u      *line;
  int need_break = FALSE;
  int outputlen;
  int tab_spaces;
  int print_pos;
  prt_text_attr_T attr;
  int id;

  if (ppos->column == 0 || ppos->ff) {
    print_pos = 0;
    tab_spaces = 0;
    if (!ppos->ff && prt_use_number())
      prt_line_number(psettings, page_line, ppos->file_line);
    ppos->ff = FALSE;
  } else {
    // left over from wrap halfway through a tab
    print_pos = ppos->print_pos;
    tab_spaces = ppos->lead_spaces;
  }

  mch_print_start_line(false, page_line);
  line = ml_get(ppos->file_line);

  /*
   * Loop over the columns until the end of the file line or right margin.
   */
  for (col = ppos->column; line[col] != NUL && !need_break; col += outputlen) {
    if ((outputlen = (*mb_ptr2len)(line + col)) < 1) {
      outputlen = 1;
    }
    // syntax highlighting stuff.
    if (psettings->do_syntax) {
      id = syn_get_id(curwin, ppos->file_line, col, 1, NULL, FALSE);
      if (id > 0)
        id = syn_get_final_id(id);
      else
        id = 0;
      /* Get the line again, a multi-line regexp may invalidate it. */
      line = ml_get(ppos->file_line);

      if (id != current_syn_id) {
        current_syn_id = id;
        prt_get_attr(id, &attr, psettings->modec);
        prt_set_font(attr.bold, attr.italic, attr.underline);
        prt_set_fg(attr.fg_color);
        prt_set_bg(attr.bg_color);
      }
    }

    /*
     * Appropriately expand any tabs to spaces.
     */
    if (line[col] == TAB || tab_spaces != 0) {
      if (tab_spaces == 0)
        tab_spaces = (int)(curbuf->b_p_ts - (print_pos % curbuf->b_p_ts));

      while (tab_spaces > 0) {
        need_break = mch_print_text_out((char_u *)" ", 1);
        print_pos++;
        tab_spaces--;
        if (need_break)
          break;
      }
      /* Keep the TAB if we didn't finish it. */
      if (need_break && tab_spaces > 0)
        break;
    } else if (line[col] == FF
               && printer_opts[OPT_PRINT_FORMFEED].present
               && TOLOWER_ASC(printer_opts[OPT_PRINT_FORMFEED].string[0])
               == 'y') {
      ppos->ff = TRUE;
      need_break = 1;
    } else {
      need_break = mch_print_text_out(line + col, (size_t)outputlen);
      print_pos += utf_ptr2cells(line + col);
    }
  }

  ppos->lead_spaces = tab_spaces;
  ppos->print_pos = print_pos;

  /*
   * Start next line of file if we clip lines, or have reached end of the
   * line, unless we are doing a formfeed.
   */
  if (!ppos->ff
      && (line[col] == NUL
          || (printer_opts[OPT_PRINT_WRAP].present
              && TOLOWER_ASC(printer_opts[OPT_PRINT_WRAP].string[0])
              == 'n')))
    return 0;
  return col;
}


/*
 * PS printer stuff.
 *
 * Sources of information to help maintain the PS printing code:
 *
 * 1. PostScript Language Reference, 3rd Edition,
 *      Addison-Wesley, 1999, ISBN 0-201-37922-8
 * 2. PostScript Language Program Design,
 *      Addison-Wesley, 1988, ISBN 0-201-14396-8
 * 3. PostScript Tutorial and Cookbook,
 *      Addison Wesley, 1985, ISBN 0-201-10179-3
 * 4. PostScript Language Document Structuring Conventions Specification,
 *    version 3.0,
 *      Adobe Technote 5001, 25th September 1992
 * 5. PostScript Printer Description File Format Specification, Version 4.3,
 *      Adobe technote 5003, 9th February 1996
 * 6. Adobe Font Metrics File Format Specification, Version 4.1,
 *      Adobe Technote 5007, 7th October 1998
 * 7. Adobe CMap and CIDFont Files Specification, Version 1.0,
 *      Adobe Technote 5014, 8th October 1996
 * 8. Adobe CJKV Character Collections and CMaps for CID-Keyed Fonts,
 *      Adoboe Technote 5094, 8th September, 2001
 * 9. CJKV Information Processing, 2nd Edition,
 *      O'Reilly, 2002, ISBN 1-56592-224-7
 *
 * Some of these documents can be found in PDF form on Adobe's web site -
 * http://www.adobe.com
 */

#define PRT_PS_DEFAULT_DPI          (72)    /* Default user space resolution */
#define PRT_PS_DEFAULT_FONTSIZE     (10)
#define PRT_PS_DEFAULT_BUFFER_SIZE  (80)

#define PRT_MEDIASIZE_LEN  (sizeof(prt_mediasize) / \
                            sizeof(struct prt_mediasize_S))

static struct prt_mediasize_S prt_mediasize[] =
{
  {"A4",              595.0,  842.0},
  {"letter",          612.0,  792.0},
  {"10x14",           720.0, 1008.0},
  {"A3",              842.0, 1191.0},
  {"A5",              420.0,  595.0},
  {"B4",              729.0, 1032.0},
  {"B5",              516.0,  729.0},
  {"executive",       522.0,  756.0},
  {"folio",           595.0,  935.0},
  {"ledger",         1224.0,  792.0},     /* Yes, it is wider than taller! */
  {"legal",           612.0, 1008.0},
  {"quarto",          610.0,  780.0},
  {"statement",       396.0,  612.0},
  {"tabloid",         792.0, 1224.0}
};

#define PRT_PS_FONT_ROMAN       (0)
#define PRT_PS_FONT_BOLD        (1)
#define PRT_PS_FONT_OBLIQUE     (2)
#define PRT_PS_FONT_BOLDOBLIQUE (3)

/* Standard font metrics for Courier family */
static struct prt_ps_font_S prt_ps_courier_font =
{
  600,
  -100, 50,
  -250, 805,
  {"Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"}
};

/* Generic font metrics for multi-byte fonts */
static struct prt_ps_font_S prt_ps_mb_font =
{
  1000,
  -100, 50,
  -250, 805,
  {NULL, NULL, NULL, NULL}
};

/* Pointer to current font set being used */
static struct prt_ps_font_S* prt_ps_font;


#define CS_JIS_C_1978   (0x01)
#define CS_JIS_X_1983   (0x02)
#define CS_JIS_X_1990   (0x04)
#define CS_NEC          (0x08)
#define CS_MSWINDOWS    (0x10)
#define CS_CP932        (0x20)
#define CS_KANJITALK6   (0x40)
#define CS_KANJITALK7   (0x80)

/* Japanese encodings and charsets */
static struct prt_ps_encoding_S j_encodings[] =
{
  {"iso-2022-jp", NULL,       (CS_JIS_C_1978|CS_JIS_X_1983|CS_JIS_X_1990|
                               CS_NEC)},
  {"euc-jp",      "EUC",      (CS_JIS_C_1978|CS_JIS_X_1983|CS_JIS_X_1990)},
  {"sjis",        "RKSJ",     (CS_JIS_C_1978|CS_JIS_X_1983|CS_MSWINDOWS|
                               CS_KANJITALK6|CS_KANJITALK7)},
  {"cp932",       "RKSJ",     CS_JIS_X_1983},
  {"ucs-2",       "UCS2",     CS_JIS_X_1990},
  {"utf-8",       "UTF8",    CS_JIS_X_1990}
};
static struct prt_ps_charset_S j_charsets[] =
{
  {"JIS_C_1978",  "78",       CS_JIS_C_1978},
  {"JIS_X_1983",  NULL,       CS_JIS_X_1983},
  {"JIS_X_1990",  "Hojo",     CS_JIS_X_1990},
  {"NEC",         "Ext",      CS_NEC},
  {"MSWINDOWS",   "90ms",     CS_MSWINDOWS},
  {"CP932",       "90ms",     CS_JIS_X_1983},
  {"KANJITALK6",  "83pv",     CS_KANJITALK6},
  {"KANJITALK7",  "90pv",     CS_KANJITALK7}
};

#define CS_GB_2312_80       (0x01)
#define CS_GBT_12345_90     (0x02)
#define CS_GBK2K            (0x04)
#define CS_SC_MAC           (0x08)
#define CS_GBT_90_MAC       (0x10)
#define CS_GBK              (0x20)
#define CS_SC_ISO10646      (0x40)

/* Simplified Chinese encodings and charsets */
static struct prt_ps_encoding_S sc_encodings[] =
{
  {"iso-2022",    NULL,       (CS_GB_2312_80|CS_GBT_12345_90)},
  {"gb18030",     NULL,       CS_GBK2K},
  {"euc-cn",      "EUC",      (CS_GB_2312_80|CS_GBT_12345_90|CS_SC_MAC|
                               CS_GBT_90_MAC)},
  {"gbk",         "EUC",      CS_GBK},
  {"ucs-2",       "UCS2",     CS_SC_ISO10646},
  {"utf-8",       "UTF8",     CS_SC_ISO10646}
};
static struct prt_ps_charset_S sc_charsets[] =
{
  {"GB_2312-80",  "GB",       CS_GB_2312_80},
  {"GBT_12345-90","GBT",      CS_GBT_12345_90},
  {"MAC",         "GBpc",     CS_SC_MAC},
  {"GBT-90_MAC",  "GBTpc",    CS_GBT_90_MAC},
  {"GBK",         "GBK",      CS_GBK},
  {"GB18030",     "GBK2K",    CS_GBK2K},
  {"ISO10646",    "UniGB",    CS_SC_ISO10646}
};

#define CS_CNS_PLANE_1      (0x01)
#define CS_CNS_PLANE_2      (0x02)
#define CS_CNS_PLANE_1_2    (0x04)
#define CS_B5               (0x08)
#define CS_ETEN             (0x10)
#define CS_HK_GCCS          (0x20)
#define CS_HK_SCS           (0x40)
#define CS_HK_SCS_ETEN      (0x80)
#define CS_MTHKL            (0x100)
#define CS_MTHKS            (0x200)
#define CS_DLHKL            (0x400)
#define CS_DLHKS            (0x800)
#define CS_TC_ISO10646      (0x1000)

/* Traditional Chinese encodings and charsets */
static struct prt_ps_encoding_S tc_encodings[] =
{
  {"iso-2022",    NULL,       (CS_CNS_PLANE_1|CS_CNS_PLANE_2)},
  {"euc-tw",      "EUC",      CS_CNS_PLANE_1_2},
  {"big5",        "B5",       (CS_B5|CS_ETEN|CS_HK_GCCS|CS_HK_SCS|
                               CS_HK_SCS_ETEN|CS_MTHKL|CS_MTHKS|CS_DLHKL|
                               CS_DLHKS)},
  {"cp950",       "B5",       CS_B5},
  {"ucs-2",       "UCS2",     CS_TC_ISO10646},
  {"utf-8",       "UTF8",     CS_TC_ISO10646},
  {"utf-16",      "UTF16",    CS_TC_ISO10646},
  {"utf-32",      "UTF32",    CS_TC_ISO10646}
};
static struct prt_ps_charset_S tc_charsets[] =
{
  {"CNS_1992_1",  "CNS1",     CS_CNS_PLANE_1},
  {"CNS_1992_2",  "CNS2",     CS_CNS_PLANE_2},
  {"CNS_1993",    "CNS",      CS_CNS_PLANE_1_2},
  {"BIG5",        NULL,       CS_B5},
  {"CP950",       NULL,       CS_B5},
  {"ETEN",        "ETen",     CS_ETEN},
  {"HK_GCCS",     "HKgccs",   CS_HK_GCCS},
  {"SCS",         "HKscs",    CS_HK_SCS},
  {"SCS_ETEN",    "ETHK",     CS_HK_SCS_ETEN},
  {"MTHKL",       "HKm471",   CS_MTHKL},
  {"MTHKS",       "HKm314",   CS_MTHKS},
  {"DLHKL",       "HKdla",    CS_DLHKL},
  {"DLHKS",       "HKdlb",    CS_DLHKS},
  {"ISO10646",    "UniCNS",   CS_TC_ISO10646}
};

#define CS_KR_X_1992        (0x01)
#define CS_KR_MAC           (0x02)
#define CS_KR_X_1992_MS     (0x04)
#define CS_KR_ISO10646      (0x08)

/* Korean encodings and charsets */
static struct prt_ps_encoding_S k_encodings[] =
{
  {"iso-2022-kr", NULL,       CS_KR_X_1992},
  {"euc-kr",      "EUC",      (CS_KR_X_1992|CS_KR_MAC)},
  {"johab",       "Johab",    CS_KR_X_1992},
  {"cp1361",      "Johab",    CS_KR_X_1992},
  {"uhc",         "UHC",      CS_KR_X_1992_MS},
  {"cp949",       "UHC",      CS_KR_X_1992_MS},
  {"ucs-2",       "UCS2",     CS_KR_ISO10646},
  {"utf-8",       "UTF8",     CS_KR_ISO10646}
};
static struct prt_ps_charset_S k_charsets[] =
{
  {"KS_X_1992",   "KSC",      CS_KR_X_1992},
  {"CP1361",      "KSC",      CS_KR_X_1992},
  {"MAC",         "KSCpc",    CS_KR_MAC},
  {"MSWINDOWS",   "KSCms",    CS_KR_X_1992_MS},
  {"CP949",       "KSCms",    CS_KR_X_1992_MS},
  {"WANSUNG",     "KSCms",    CS_KR_X_1992_MS},
  {"ISO10646",    "UniKS",    CS_KR_ISO10646}
};

static struct prt_ps_mbfont_S prt_ps_mbfonts[] =
{
  {
    ARRAY_SIZE(j_encodings),
    j_encodings,
    ARRAY_SIZE(j_charsets),
    j_charsets,
    "jis_roman",
    "JIS_X_1983"
  },
  {
    ARRAY_SIZE(sc_encodings),
    sc_encodings,
    ARRAY_SIZE(sc_charsets),
    sc_charsets,
    "gb_roman",
    "GB_2312-80"
  },
  {
    ARRAY_SIZE(tc_encodings),
    tc_encodings,
    ARRAY_SIZE(tc_charsets),
    tc_charsets,
    "cns_roman",
    "BIG5"
  },
  {
    ARRAY_SIZE(k_encodings),
    k_encodings,
    ARRAY_SIZE(k_charsets),
    k_charsets,
    "ks_roman",
    "KS_X_1992"
  }
};

/* Types of PS resource file currently used */
#define PRT_RESOURCE_TYPE_PROCSET   (0)
#define PRT_RESOURCE_TYPE_ENCODING  (1)
#define PRT_RESOURCE_TYPE_CMAP      (2)

/* The PS prolog file version number has to match - if the prolog file is
 * updated, increment the number in the file and here.  Version checking was
 * added as of VIM 6.2.
 * The CID prolog file version number behaves as per PS prolog.
 * Table of VIM and prolog versions:
 *
 * VIM      Prolog  CIDProlog
 * 6.2      1.3
 * 7.0      1.4	    1.0
 */
#define PRT_PROLOG_VERSION  ((char_u *)"1.4")
#define PRT_CID_PROLOG_VERSION  ((char_u *)"1.0")

/* String versions of PS resource types - indexed by constants above so don't
 * re-order!
 */
static char *prt_resource_types[] =
{
  "procset",
  "encoding",
  "cmap"
};

/* Strings to look for in a PS resource file */
#define PRT_RESOURCE_HEADER         "%!PS-Adobe-"
#define PRT_RESOURCE_RESOURCE       "Resource-"
#define PRT_RESOURCE_PROCSET        "ProcSet"
#define PRT_RESOURCE_ENCODING       "Encoding"
#define PRT_RESOURCE_CMAP           "CMap"


/* Data for table based DSC comment recognition, easy to extend if VIM needs to
 * read more comments. */
#define PRT_DSC_MISC_TYPE           (-1)
#define PRT_DSC_TITLE_TYPE          (1)
#define PRT_DSC_VERSION_TYPE        (2)
#define PRT_DSC_ENDCOMMENTS_TYPE    (3)

#define PRT_DSC_TITLE               "%%Title:"
#define PRT_DSC_VERSION             "%%Version:"
#define PRT_DSC_ENDCOMMENTS         "%%EndComments:"


#define SIZEOF_CSTR(s)      (sizeof(s) - 1)
static struct prt_dsc_comment_S prt_dsc_table[] =
{
  {PRT_DSC_TITLE,       SIZEOF_CSTR(PRT_DSC_TITLE),     PRT_DSC_TITLE_TYPE},
  {PRT_DSC_VERSION,     SIZEOF_CSTR(PRT_DSC_VERSION),
   PRT_DSC_VERSION_TYPE},
  {PRT_DSC_ENDCOMMENTS, SIZEOF_CSTR(PRT_DSC_ENDCOMMENTS),
   PRT_DSC_ENDCOMMENTS_TYPE}
};


/*
 * Variables for the output PostScript file.
 */
static FILE *prt_ps_fd;
static int prt_file_error;
static char_u *prt_ps_file_name = NULL;

/*
 * Various offsets and dimensions in default PostScript user space (points).
 * Used for text positioning calculations
 */
static double prt_page_width;
static double prt_page_height;
static double prt_left_margin;
static double prt_right_margin;
static double prt_top_margin;
static double prt_bottom_margin;
static double prt_line_height;
static double prt_first_line_height;
static double prt_char_width;
static double prt_number_width;
static double prt_bgcol_offset;
static double prt_pos_x_moveto = 0.0;
static double prt_pos_y_moveto = 0.0;

/*
 * Various control variables used to decide when and how to change the
 * PostScript graphics state.
 */
static int prt_need_moveto;
static int prt_do_moveto;
static int prt_need_font;
static int prt_font;
static int prt_need_underline;
static TriState prt_underline;
static TriState prt_do_underline;
static int prt_need_fgcol;
static uint32_t prt_fgcol;
static int prt_need_bgcol;
static int prt_do_bgcol;
static uint32_t prt_bgcol;
static uint32_t prt_new_bgcol;
static int prt_attribute_change;
static double prt_text_run;
static int prt_page_num;
static int prt_bufsiz;

/*
 * Variables controlling physical printing.
 */
static int prt_media;
static int prt_portrait;
static int prt_num_copies;
static int prt_duplex;
static int prt_tumble;
static int prt_collate;

/*
 * Buffers used when generating PostScript output
 */
static char_u prt_line_buffer[257];
static garray_T prt_ps_buffer = GA_EMPTY_INIT_VALUE;

static int prt_do_conv;
static vimconv_T prt_conv;

static int prt_out_mbyte;
static int prt_custom_cmap;
static char prt_cmap[80];
static int prt_use_courier;
static int prt_in_ascii;
static int prt_half_width;
static char *prt_ascii_encoding;
static char_u prt_hexchar[] = "0123456789abcdef";

static void prt_write_file_raw_len(char_u *buffer, size_t bytes)
{
  if (!prt_file_error
      && fwrite(buffer, sizeof(char_u), bytes, prt_ps_fd) != bytes) {
    EMSG(_("E455: Error writing to PostScript output file"));
    prt_file_error = TRUE;
  }
}

static void prt_write_file(char_u *buffer)
{
  prt_write_file_len(buffer, STRLEN(buffer));
}

static void prt_write_file_len(char_u *buffer, size_t bytes)
{
  prt_write_file_raw_len(buffer, bytes);
}

/*
 * Write a string.
 */
static void prt_write_string(char *s)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer), "%s", s);
  prt_write_file(prt_line_buffer);
}

/*
 * Write an int and a space.
 */
static void prt_write_int(int i)
{
  sprintf((char *)prt_line_buffer, "%d ", i);
  prt_write_file(prt_line_buffer);
}

/*
 * Write a boolean and a space.
 */
static void prt_write_boolean(int b)
{
  sprintf((char *)prt_line_buffer, "%s ", (b ? "T" : "F"));
  prt_write_file(prt_line_buffer);
}

/*
 * Write PostScript to re-encode and define the font.
 */
static void prt_def_font(char *new_name, char *encoding, int height, char *font)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "/_%s /VIM-%s /%s ref\n", new_name, encoding, font);
  prt_write_file(prt_line_buffer);
  if (prt_out_mbyte)
    sprintf((char *)prt_line_buffer, "/%s %d %f /_%s sffs\n",
        new_name, height, 500./prt_ps_courier_font.wx, new_name);
  else
    vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
        "/%s %d /_%s ffs\n", new_name, height, new_name);
  prt_write_file(prt_line_buffer);
}

/*
 * Write a line to define the CID font.
 */
static void prt_def_cidfont(char *new_name, int height, char *cidfont)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "/_%s /%s[/%s] vim_composefont\n", new_name, prt_cmap, cidfont);
  prt_write_file(prt_line_buffer);
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "/%s %d /_%s ffs\n", new_name, height, new_name);
  prt_write_file(prt_line_buffer);
}

/*
 * Write a line to define a duplicate of a CID font
 */
static void prt_dup_cidfont(char *original_name, char *new_name)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "/%s %s d\n", new_name, original_name);
  prt_write_file(prt_line_buffer);
}

/*
 * Convert a real value into an integer and fractional part as integers, with
 * the fractional part being in the range [0,10^precision).  The fractional part
 * is also rounded based on the precision + 1'th fractional digit.
 */
static void prt_real_bits(double real, int precision, int *pinteger, int *pfraction)
{
  int integer = (int)real;
  double fraction = real - integer;
  if (real < integer)
    fraction = -fraction;
  for (int i = 0; i < precision; i++)
    fraction *= 10.0;

  *pinteger = integer;
  *pfraction = (int)(fraction + 0.5);
}

/*
 * Write a real and a space.  Save bytes if real value has no fractional part!
 * We use prt_real_bits() as %f in sprintf uses the locale setting to decide
 * what decimal point character to use, but PS always requires a '.'.
 */
static void prt_write_real(double val, int prec)
{
  int integer;
  int fraction;

  prt_real_bits(val, prec, &integer, &fraction);
  /* Emit integer part */
  sprintf((char *)prt_line_buffer, "%d", integer);
  prt_write_file(prt_line_buffer);
  /* Only emit fraction if necessary */
  if (fraction != 0) {
    /* Remove any trailing zeros */
    while ((fraction % 10) == 0) {
      prec--;
      fraction /= 10;
    }
    /* Emit fraction left padded with zeros */
    sprintf((char *)prt_line_buffer, ".%0*d", prec, fraction);
    prt_write_file(prt_line_buffer);
  }
  sprintf((char *)prt_line_buffer, " ");
  prt_write_file(prt_line_buffer);
}

/*
 * Write a line to define a numeric variable.
 */
static void prt_def_var(char *name, double value, int prec)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "/%s ", name);
  prt_write_file(prt_line_buffer);
  prt_write_real(value, prec);
  sprintf((char *)prt_line_buffer, "d\n");
  prt_write_file(prt_line_buffer);
}

/* Convert size from font space to user space at current font scale */
#define PRT_PS_FONT_TO_USER(scale, size)    ((size) * ((scale)/1000.0))

static void prt_flush_buffer(void)
{
  if (!GA_EMPTY(&prt_ps_buffer)) {
    /* Any background color must be drawn first */
    if (prt_do_bgcol && (prt_new_bgcol != PRCOLOR_WHITE)) {
      unsigned int r, g, b;

      if (prt_do_moveto) {
        prt_write_real(prt_pos_x_moveto, 2);
        prt_write_real(prt_pos_y_moveto, 2);
        prt_write_string("m\n");
        prt_do_moveto = FALSE;
      }

      /* Size of rect of background color on which text is printed */
      prt_write_real(prt_text_run, 2);
      prt_write_real(prt_line_height, 2);

      /* Lastly add the color of the background */
      r = (prt_new_bgcol & 0xff0000) >> 16;
      g = (prt_new_bgcol & 0xff00) >> 8;
      b = prt_new_bgcol & 0xff;
      prt_write_real(r / 255.0, 3);
      prt_write_real(g / 255.0, 3);
      prt_write_real(b / 255.0, 3);
      prt_write_string("bg\n");
    }
    /* Draw underlines before the text as it makes it slightly easier to
     * find the starting point.
     */
    if (prt_do_underline) {
      if (prt_do_moveto) {
        prt_write_real(prt_pos_x_moveto, 2);
        prt_write_real(prt_pos_y_moveto, 2);
        prt_write_string("m\n");
        prt_do_moveto = FALSE;
      }

      /* Underline length of text run */
      prt_write_real(prt_text_run, 2);
      prt_write_string("ul\n");
    }
    // Draw the text
    if (prt_out_mbyte)
      prt_write_string("<");
    else
      prt_write_string("(");
    assert(prt_ps_buffer.ga_len >= 0);
    prt_write_file_raw_len(prt_ps_buffer.ga_data, (size_t)prt_ps_buffer.ga_len);
    if (prt_out_mbyte)
      prt_write_string(">");
    else
      prt_write_string(")");
    /* Add a moveto if need be and use the appropriate show procedure */
    if (prt_do_moveto) {
      prt_write_real(prt_pos_x_moveto, 2);
      prt_write_real(prt_pos_y_moveto, 2);
      /* moveto and a show */
      prt_write_string("ms\n");
      prt_do_moveto = FALSE;
    } else   /* Simple show */
      prt_write_string("s\n");

    ga_clear(&prt_ps_buffer);
    ga_init(&prt_ps_buffer, (int)sizeof(char), prt_bufsiz);
  }
}

static void prt_resource_name(char_u *filename, void *cookie)
{
  char_u *resource_filename = cookie;

  if (STRLEN(filename) >= MAXPATHL)
    *resource_filename = NUL;
  else
    STRCPY(resource_filename, filename);
}

static int prt_find_resource(char *name, struct prt_ps_resource_S *resource)
{
  char_u      *buffer;
  int retval;

  buffer = xmallocz(MAXPATHL);

  STRLCPY(resource->name, name, 64);
  /* Look for named resource file in runtimepath */
  STRCPY(buffer, "print");
  add_pathsep((char *)buffer);
  xstrlcat((char *)buffer, name, MAXPATHL);
  xstrlcat((char *)buffer, ".ps", MAXPATHL);
  resource->filename[0] = NUL;
  retval = (do_in_runtimepath(buffer, 0, prt_resource_name, resource->filename)
            && resource->filename[0] != NUL);
  xfree(buffer);
  return retval;
}

/* PS CR and LF characters have platform independent values */
#define PSLF  (0x0a)
#define PSCR  (0x0d)

static struct prt_resfile_buffer_S prt_resfile;

static int prt_resfile_next_line(void)
{
  int idx;

  /* Move to start of next line and then find end of line */
  idx = prt_resfile.line_end + 1;
  while (idx < prt_resfile.len) {
    if (prt_resfile.buffer[idx] != PSLF && prt_resfile.buffer[idx] != PSCR)
      break;
    idx++;
  }
  prt_resfile.line_start = idx;

  while (idx < prt_resfile.len) {
    if (prt_resfile.buffer[idx] == PSLF || prt_resfile.buffer[idx] == PSCR)
      break;
    idx++;
  }
  prt_resfile.line_end = idx;

  return idx < prt_resfile.len;
}

static int prt_resfile_strncmp(int offset, char *string, int len)
{
  /* Force not equal if string is longer than remainder of line */
  if (len > (prt_resfile.line_end - (prt_resfile.line_start + offset)))
    return 1;

  return STRNCMP(&prt_resfile.buffer[prt_resfile.line_start + offset],
      string, len);
}

static int prt_resfile_skip_nonws(int offset)
{
  int idx;

  idx = prt_resfile.line_start + offset;
  while (idx < prt_resfile.line_end) {
    if (isspace(prt_resfile.buffer[idx]))
      return idx - prt_resfile.line_start;
    idx++;
  }
  return -1;
}

static int prt_resfile_skip_ws(int offset)
{
  int idx;

  idx = prt_resfile.line_start + offset;
  while (idx < prt_resfile.line_end) {
    if (!isspace(prt_resfile.buffer[idx]))
      return idx - prt_resfile.line_start;
    idx++;
  }
  return -1;
}

/* prt_next_dsc() - returns detail on next DSC comment line found.  Returns true
 * if a DSC comment is found, else false */
static int prt_next_dsc(struct prt_dsc_line_S *p_dsc_line)
{
  int comment;
  int offset;

  /* Move to start of next line */
  if (!prt_resfile_next_line())
    return FALSE;

  /* DSC comments always start %% */
  if (prt_resfile_strncmp(0, "%%", 2) != 0)
    return FALSE;

  /* Find type of DSC comment */
  for (comment = 0; comment < (int)ARRAY_SIZE(prt_dsc_table); comment++)
    if (prt_resfile_strncmp(0, prt_dsc_table[comment].string,
            prt_dsc_table[comment].len) == 0)
      break;

  if (comment != ARRAY_SIZE(prt_dsc_table)) {
    /* Return type of comment */
    p_dsc_line->type = prt_dsc_table[comment].type;
    offset = prt_dsc_table[comment].len;
  } else {
    /* Unrecognised DSC comment, skip to ws after comment leader */
    p_dsc_line->type = PRT_DSC_MISC_TYPE;
    offset = prt_resfile_skip_nonws(0);
    if (offset == -1)
      return FALSE;
  }

  /* Skip ws to comment value */
  offset = prt_resfile_skip_ws(offset);
  if (offset == -1)
    return FALSE;

  p_dsc_line->string = &prt_resfile.buffer[prt_resfile.line_start + offset];
  p_dsc_line->len = prt_resfile.line_end - (prt_resfile.line_start + offset);

  return TRUE;
}

/* Improved hand crafted parser to get the type, title, and version number of a
 * PS resource file so the file details can be added to the DSC header comments.
 */
static int prt_open_resource(struct prt_ps_resource_S *resource)
{
  int offset;
  int seen_all;
  int seen_title;
  int seen_version;
  FILE        *fd_resource;
  struct prt_dsc_line_S dsc_line;

  fd_resource = os_fopen((char *)resource->filename, READBIN);
  if (fd_resource == NULL) {
    EMSG2(_("E624: Can't open file \"%s\""), resource->filename);
    return FALSE;
  }
  memset(prt_resfile.buffer, NUL, PRT_FILE_BUFFER_LEN);

  /* Parse first line to ensure valid resource file */
  prt_resfile.len = (int)fread((char *)prt_resfile.buffer, sizeof(char_u),
      PRT_FILE_BUFFER_LEN, fd_resource);
  if (ferror(fd_resource)) {
    EMSG2(_("E457: Can't read PostScript resource file \"%s\""),
        resource->filename);
    fclose(fd_resource);
    return FALSE;
  }
  fclose(fd_resource);

  prt_resfile.line_end = -1;
  prt_resfile.line_start = 0;
  if (!prt_resfile_next_line())
    return FALSE;

  offset = 0;

  if (prt_resfile_strncmp(offset, PRT_RESOURCE_HEADER,
          (int)STRLEN(PRT_RESOURCE_HEADER)) != 0) {
    EMSG2(_("E618: file \"%s\" is not a PostScript resource file"),
        resource->filename);
    return FALSE;
  }

  /* Skip over any version numbers and following ws */
  offset += (int)STRLEN(PRT_RESOURCE_HEADER);
  offset = prt_resfile_skip_nonws(offset);
  if (offset == -1)
    return FALSE;
  offset = prt_resfile_skip_ws(offset);
  if (offset == -1)
    return FALSE;

  if (prt_resfile_strncmp(offset, PRT_RESOURCE_RESOURCE,
          (int)STRLEN(PRT_RESOURCE_RESOURCE)) != 0) {
    EMSG2(_("E619: file \"%s\" is not a supported PostScript resource file"),
        resource->filename);
    return FALSE;
  }
  offset += (int)STRLEN(PRT_RESOURCE_RESOURCE);

  /* Decide type of resource in the file */
  if (prt_resfile_strncmp(offset, PRT_RESOURCE_PROCSET,
          (int)STRLEN(PRT_RESOURCE_PROCSET)) == 0)
    resource->type = PRT_RESOURCE_TYPE_PROCSET;
  else if (prt_resfile_strncmp(offset, PRT_RESOURCE_ENCODING,
               (int)STRLEN(PRT_RESOURCE_ENCODING)) == 0)
    resource->type = PRT_RESOURCE_TYPE_ENCODING;
  else if (prt_resfile_strncmp(offset, PRT_RESOURCE_CMAP,
               (int)STRLEN(PRT_RESOURCE_CMAP)) == 0)
    resource->type = PRT_RESOURCE_TYPE_CMAP;
  else {
    EMSG2(_("E619: file \"%s\" is not a supported PostScript resource file"),
        resource->filename);
    return FALSE;
  }

  /* Look for title and version of resource */
  resource->title[0] = '\0';
  resource->version[0] = '\0';
  seen_title = FALSE;
  seen_version = FALSE;
  seen_all = FALSE;
  while (!seen_all && prt_next_dsc(&dsc_line)) {
    switch (dsc_line.type) {
    case PRT_DSC_TITLE_TYPE:
      STRLCPY(resource->title, dsc_line.string, dsc_line.len + 1);
      seen_title = TRUE;
      if (seen_version)
        seen_all = TRUE;
      break;

    case PRT_DSC_VERSION_TYPE:
      STRLCPY(resource->version, dsc_line.string, dsc_line.len + 1);
      seen_version = TRUE;
      if (seen_title)
        seen_all = TRUE;
      break;

    case PRT_DSC_ENDCOMMENTS_TYPE:
      /* Wont find title or resource after this comment, stop searching */
      seen_all = TRUE;
      break;

    case PRT_DSC_MISC_TYPE:
      /* Not interested in whatever comment this line had */
      break;
    }
  }

  if (!seen_title || !seen_version) {
    EMSG2(_("E619: file \"%s\" is not a supported PostScript resource file"),
        resource->filename);
    return FALSE;
  }

  return TRUE;
}

static int prt_check_resource(struct prt_ps_resource_S *resource, char_u *version)
{
  /* Version number m.n should match, the revision number does not matter */
  if (STRNCMP(resource->version, version, STRLEN(version))) {
    EMSG2(_("E621: \"%s\" resource file has wrong version"),
        resource->name);
    return FALSE;
  }

  /* Other checks to be added as needed */
  return TRUE;
}

static void prt_dsc_start(void)
{
  prt_write_string("%!PS-Adobe-3.0\n");
}

static void prt_dsc_noarg(char *comment)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "%%%%%s\n", comment);
  prt_write_file(prt_line_buffer);
}

static void prt_dsc_textline(char *comment, char *text)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "%%%%%s: %s\n", comment, text);
  prt_write_file(prt_line_buffer);
}

static void prt_dsc_text(char *comment, char *text)
{
  /* TODO - should scan 'text' for any chars needing escaping! */
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "%%%%%s: (%s)\n", comment, text);
  prt_write_file(prt_line_buffer);
}

#define prt_dsc_atend(c)        prt_dsc_text((c), "atend")

static void prt_dsc_ints(char *comment, int count, int *ints)
{
  int i;

  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "%%%%%s:", comment);
  prt_write_file(prt_line_buffer);

  for (i = 0; i < count; i++) {
    sprintf((char *)prt_line_buffer, " %d", ints[i]);
    prt_write_file(prt_line_buffer);
  }

  prt_write_string("\n");
}

static void 
prt_dsc_resources (
    char *comment,           /* if NULL add to previous */
    char *type,
    char *string
)
{
  if (comment != NULL)
    vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
        "%%%%%s: %s", comment, type);
  else
    vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
        "%%%%+ %s", type);
  prt_write_file(prt_line_buffer);

  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      " %s\n", string);
  prt_write_file(prt_line_buffer);
}

static void prt_dsc_font_resource(char *resource, struct prt_ps_font_S *ps_font)
{
  int i;

  prt_dsc_resources(resource, "font",
      ps_font->ps_fontname[PRT_PS_FONT_ROMAN]);
  for (i = PRT_PS_FONT_BOLD; i <= PRT_PS_FONT_BOLDOBLIQUE; i++)
    if (ps_font->ps_fontname[i] != NULL)
      prt_dsc_resources(NULL, "font", ps_font->ps_fontname[i]);
}

static void prt_dsc_requirements(int duplex, int tumble, int collate, int color, int num_copies)
{
  /* Only output the comment if we need to.
   * Note: tumble is ignored if we are not duplexing
   */
  if (!(duplex || collate || color || (num_copies > 1)))
    return;

  sprintf((char *)prt_line_buffer, "%%%%Requirements:");
  prt_write_file(prt_line_buffer);

  if (duplex) {
    prt_write_string(" duplex");
    if (tumble)
      prt_write_string("(tumble)");
  }
  if (collate)
    prt_write_string(" collate");
  if (color)
    prt_write_string(" color");
  if (num_copies > 1) {
    prt_write_string(" numcopies(");
    /* Note: no space wanted so don't use prt_write_int() */
    sprintf((char *)prt_line_buffer, "%d", num_copies);
    prt_write_file(prt_line_buffer);
    prt_write_string(")");
  }
  prt_write_string("\n");
}

static void prt_dsc_docmedia(char *paper_name, double width, double height, double weight, char *colour, char *type)
{
  vim_snprintf((char *)prt_line_buffer, sizeof(prt_line_buffer),
      "%%%%DocumentMedia: %s ", paper_name);
  prt_write_file(prt_line_buffer);
  prt_write_real(width, 2);
  prt_write_real(height, 2);
  prt_write_real(weight, 2);
  if (colour == NULL)
    prt_write_string("()");
  else
    prt_write_string(colour);
  prt_write_string(" ");
  if (type == NULL)
    prt_write_string("()");
  else
    prt_write_string(type);
  prt_write_string("\n");
}

void mch_print_cleanup(void)
{
  if (prt_out_mbyte) {
    int i;

    /* Free off all CID font names created, but first clear duplicate
     * pointers to the same string (when the same font is used for more than
     * one style).
     */
    for (i = PRT_PS_FONT_ROMAN; i <= PRT_PS_FONT_BOLDOBLIQUE; i++) {
      if (prt_ps_mb_font.ps_fontname[i] != NULL)
        xfree(prt_ps_mb_font.ps_fontname[i]);
      prt_ps_mb_font.ps_fontname[i] = NULL;
    }
  }

  if (prt_do_conv) {
    convert_setup(&prt_conv, NULL, NULL);
    prt_do_conv = FALSE;
  }
  if (prt_ps_fd != NULL) {
    fclose(prt_ps_fd);
    prt_ps_fd = NULL;
    prt_file_error = FALSE;
  }
  if (prt_ps_file_name != NULL) {
    XFREE_CLEAR(prt_ps_file_name);
  }
}

static double to_device_units(int idx, double physsize, int def_number)
{
  double ret;
  int nr;

  int u = prt_get_unit(idx);
  if (u == PRT_UNIT_NONE) {
    u = PRT_UNIT_PERC;
    nr = def_number;
  } else {
    nr = printer_opts[idx].number;
  }

  switch (u) {
  case PRT_UNIT_INCH:
    ret = nr * PRT_PS_DEFAULT_DPI;
    break;
  case PRT_UNIT_MM:
    ret = nr * PRT_PS_DEFAULT_DPI / 25.4;
    break;
  case PRT_UNIT_POINT:
    ret = nr;
    break;
  case PRT_UNIT_PERC:
  default:
    ret = physsize * nr / 100;
    break;
  }

  return ret;
}

/*
 * Calculate margins for given width and height from printoptions settings.
 */
static void prt_page_margins(double width, double height, double *left, double *right, double *top, double *bottom)
{
  *left   = to_device_units(OPT_PRINT_LEFT, width, 10);
  *right  = width - to_device_units(OPT_PRINT_RIGHT, width, 5);
  *top    = height - to_device_units(OPT_PRINT_TOP, height, 5);
  *bottom = to_device_units(OPT_PRINT_BOT, height, 5);
}

static void prt_font_metrics(int font_scale)
{
  prt_line_height = (double)font_scale;
  prt_char_width = PRT_PS_FONT_TO_USER(font_scale, prt_ps_font->wx);
}


static int prt_get_cpl(void)
{
  if (prt_use_number()) {
    prt_number_width = PRINT_NUMBER_WIDTH * prt_char_width;
    /* If we are outputting multi-byte characters then line numbers will be
     * printed with half width characters
     */
    if (prt_out_mbyte)
      prt_number_width /= 2;
    prt_left_margin += prt_number_width;
  } else
    prt_number_width = 0.0;

  return (int)((prt_right_margin - prt_left_margin) / prt_char_width);
}

static void prt_build_cid_fontname(int font, char_u *name, int name_len)
{
  assert(name_len >= 0);
  char *fontname = xstrndup((char *)name, (size_t)name_len);
  prt_ps_mb_font.ps_fontname[font] = fontname;
}

/*
 * Get number of lines of text that fit on a page (excluding the header).
 */
static int prt_get_lpp(void)
{
  int lpp;

  /*
   * Calculate offset to lower left corner of background rect based on actual
   * font height (based on its bounding box) and the line height, handling the
   * case where the font height can exceed the line height.
   */
  prt_bgcol_offset = PRT_PS_FONT_TO_USER(prt_line_height,
      prt_ps_font->bbox_min_y);
  if ((prt_ps_font->bbox_max_y - prt_ps_font->bbox_min_y) < 1000.0) {
    prt_bgcol_offset -= PRT_PS_FONT_TO_USER(prt_line_height,
        (1000.0 - (prt_ps_font->bbox_max_y -
                   prt_ps_font->bbox_min_y)) / 2);
  }

  /* Get height for topmost line based on background rect offset. */
  prt_first_line_height = prt_line_height + prt_bgcol_offset;

  /* Calculate lpp */
  lpp = (int)((prt_top_margin - prt_bottom_margin) / prt_line_height);

  /* Adjust top margin if there is a header */
  prt_top_margin -= prt_line_height * prt_header_height();

  return lpp - prt_header_height();
}

static int prt_match_encoding(char *p_encoding, struct prt_ps_mbfont_S *p_cmap, struct prt_ps_encoding_S **pp_mbenc)
{
  int mbenc;
  int enc_len;
  struct prt_ps_encoding_S    *p_mbenc;

  *pp_mbenc = NULL;
  /* Look for recognised encoding */
  enc_len = (int)STRLEN(p_encoding);
  p_mbenc = p_cmap->encodings;
  for (mbenc = 0; mbenc < p_cmap->num_encodings; mbenc++) {
    if (STRNICMP(p_mbenc->encoding, p_encoding, enc_len) == 0) {
      *pp_mbenc = p_mbenc;
      return TRUE;
    }
    p_mbenc++;
  }
  return FALSE;
}

static int prt_match_charset(char *p_charset, struct prt_ps_mbfont_S *p_cmap, struct prt_ps_charset_S **pp_mbchar)
{
  int mbchar;
  int char_len;
  struct prt_ps_charset_S *p_mbchar;

  /* Look for recognised character set, using default if one is not given */
  if (*p_charset == NUL)
    p_charset = p_cmap->defcs;
  char_len = (int)STRLEN(p_charset);
  p_mbchar = p_cmap->charsets;
  for (mbchar = 0; mbchar < p_cmap->num_charsets; mbchar++) {
    if (STRNICMP(p_mbchar->charset, p_charset, char_len) == 0) {
      *pp_mbchar = p_mbchar;
      return TRUE;
    }
    p_mbchar++;
  }
  return FALSE;
}

int mch_print_init(prt_settings_T *psettings, char_u *jobname, int forceit)
{
  int i;
  char        *paper_name;
  int paper_strlen;
  int fontsize;
  char_u      *p;
  int props;
  int cmap = 0;
  char_u      *p_encoding;
  struct prt_ps_encoding_S *p_mbenc;
  struct prt_ps_encoding_S *p_mbenc_first;
  struct prt_ps_charset_S  *p_mbchar = NULL;


  /*
   * Set up font and encoding.
   */
  p_encoding = enc_skip(p_penc);
  if (*p_encoding == NUL)
    p_encoding = enc_skip(p_enc);

  /* Look for a multi-byte font that matches the encoding and character set.
   * Only look if multi-byte character set is defined, or using multi-byte
   * encoding other than Unicode.  This is because a Unicode encoding does not
   * uniquely identify a CJK character set to use. */
  p_mbenc = NULL;
  props = enc_canon_props(p_encoding);
  if (!(props & ENC_8BIT) && ((*p_pmcs != NUL) || !(props & ENC_UNICODE))) {
    p_mbenc_first = NULL;
    int effective_cmap = 0;
    for (cmap = 0; cmap < (int)ARRAY_SIZE(prt_ps_mbfonts); cmap++)
      if (prt_match_encoding((char *)p_encoding, &prt_ps_mbfonts[cmap],
                             &p_mbenc)) {
        if (p_mbenc_first == NULL) {
          p_mbenc_first = p_mbenc;
          effective_cmap = cmap;
        }
        if (prt_match_charset((char *)p_pmcs, &prt_ps_mbfonts[cmap], &p_mbchar))
          break;
      }

    /* Use first encoding matched if no charset matched */
    if (p_mbenc_first != NULL && p_mbchar == NULL) {
      p_mbenc = p_mbenc_first;
      cmap = effective_cmap;
    }

    assert(p_mbenc == NULL || cmap < (int)ARRAY_SIZE(prt_ps_mbfonts));
  }

  prt_out_mbyte = (p_mbenc != NULL);
  if (prt_out_mbyte) {
    /* Build CMap name - will be same for all multi-byte fonts used */
    prt_cmap[0] = NUL;

    prt_custom_cmap = (p_mbchar == NULL);
    if (!prt_custom_cmap) {
      /* Check encoding and character set are compatible */
      if ((p_mbenc->needs_charset & p_mbchar->has_charset) == 0) {
        EMSG(_("E673: Incompatible multi-byte encoding and character set."));
        return FALSE;
      }

      /* Add charset name if not empty */
      if (p_mbchar->cmap_charset != NULL) {
        STRLCPY(prt_cmap, p_mbchar->cmap_charset, sizeof(prt_cmap) - 2);
        STRCAT(prt_cmap, "-");
      }
    } else {
      /* Add custom CMap character set name */
      if (*p_pmcs == NUL) {
        EMSG(_("E674: printmbcharset cannot be empty with multi-byte encoding."));
        return FALSE;
      }
      STRLCPY(prt_cmap, p_pmcs, sizeof(prt_cmap) - 2);
      STRCAT(prt_cmap, "-");
    }

    /* CMap name ends with (optional) encoding name and -H for horizontal */
    if (p_mbenc->cmap_encoding != NULL && STRLEN(prt_cmap)
        + STRLEN(p_mbenc->cmap_encoding) + 3 < sizeof(prt_cmap)) {
      STRCAT(prt_cmap, p_mbenc->cmap_encoding);
      STRCAT(prt_cmap, "-");
    }
    STRCAT(prt_cmap, "H");

    if (!mbfont_opts[OPT_MBFONT_REGULAR].present) {
      EMSG(_("E675: No default font specified for multi-byte printing."));
      return FALSE;
    }

    /* Derive CID font names with fallbacks if not defined */
    prt_build_cid_fontname(PRT_PS_FONT_ROMAN,
                           mbfont_opts[OPT_MBFONT_REGULAR].string,
                           mbfont_opts[OPT_MBFONT_REGULAR].strlen);
    if (mbfont_opts[OPT_MBFONT_BOLD].present) {
      prt_build_cid_fontname(PRT_PS_FONT_BOLD,
                             mbfont_opts[OPT_MBFONT_BOLD].string,
                             mbfont_opts[OPT_MBFONT_BOLD].strlen);

    }
    if (mbfont_opts[OPT_MBFONT_OBLIQUE].present) {
      prt_build_cid_fontname(PRT_PS_FONT_OBLIQUE,
                             mbfont_opts[OPT_MBFONT_OBLIQUE].string,
                             mbfont_opts[OPT_MBFONT_OBLIQUE].strlen);
    }
    if (mbfont_opts[OPT_MBFONT_BOLDOBLIQUE].present) {
      prt_build_cid_fontname(PRT_PS_FONT_BOLDOBLIQUE,
                             mbfont_opts[OPT_MBFONT_BOLDOBLIQUE].string,
                             mbfont_opts[OPT_MBFONT_BOLDOBLIQUE].strlen);
    }

    // Check if need to use Courier for ASCII code range, and if so pick up
    // the encoding to use
    prt_use_courier = (
        mbfont_opts[OPT_MBFONT_USECOURIER].present
        && (TOLOWER_ASC(mbfont_opts[OPT_MBFONT_USECOURIER].string[0]) == 'y'));
    if (prt_use_courier) {
      // Use national ASCII variant unless ASCII wanted
      if (mbfont_opts[OPT_MBFONT_ASCII].present
          && (TOLOWER_ASC(mbfont_opts[OPT_MBFONT_ASCII].string[0]) == 'y')) {
        prt_ascii_encoding = "ascii";
      } else {
        prt_ascii_encoding = prt_ps_mbfonts[cmap].ascii_enc;
      }
    }

    prt_ps_font = &prt_ps_mb_font;
  } else {
    prt_use_courier = FALSE;
    prt_ps_font = &prt_ps_courier_font;
  }

  /*
   * Find the size of the paper and set the margins.
   */
  prt_portrait = (!printer_opts[OPT_PRINT_PORTRAIT].present
                  || TOLOWER_ASC(printer_opts[OPT_PRINT_PORTRAIT].string[0]) ==
                  'y');
  if (printer_opts[OPT_PRINT_PAPER].present) {
    paper_name = (char *)printer_opts[OPT_PRINT_PAPER].string;
    paper_strlen = printer_opts[OPT_PRINT_PAPER].strlen;
  } else {
    paper_name = "A4";
    paper_strlen = 2;
  }
  for (i = 0; i < (int)PRT_MEDIASIZE_LEN; ++i)
    if (STRLEN(prt_mediasize[i].name) == (unsigned)paper_strlen
        && STRNICMP(prt_mediasize[i].name, paper_name,
            paper_strlen) == 0)
      break;
  if (i == PRT_MEDIASIZE_LEN)
    i = 0;
  prt_media = i;

  /*
   * Set PS pagesize based on media dimensions and print orientation.
   * Note: Media and page sizes have defined meanings in PostScript and should
   * be kept distinct.  Media is the paper (or transparency, or ...) that is
   * printed on, whereas the page size is the area that the PostScript
   * interpreter renders into.
   */
  if (prt_portrait) {
    prt_page_width = prt_mediasize[i].width;
    prt_page_height = prt_mediasize[i].height;
  } else {
    prt_page_width = prt_mediasize[i].height;
    prt_page_height = prt_mediasize[i].width;
  }

  // Set PS page margins based on the PS pagesize, not the mediasize - this
  // needs to be done before the cpl and lpp are calculated.
  double left, right, top, bottom;
  prt_page_margins(prt_page_width, prt_page_height, &left, &right, &top,
      &bottom);
  prt_left_margin = left;
  prt_right_margin = right;
  prt_top_margin = top;
  prt_bottom_margin = bottom;

  /*
   * Set up the font size.
   */
  fontsize = PRT_PS_DEFAULT_FONTSIZE;
  for (p = p_pfn; (p = vim_strchr(p, ':')) != NULL; ++p)
    if (p[1] == 'h' && ascii_isdigit(p[2]))
      fontsize = atoi((char *)p + 2);
  prt_font_metrics(fontsize);

  /*
   * Return the number of characters per line, and lines per page for the
   * generic print code.
   */
  psettings->chars_per_line = prt_get_cpl();
  psettings->lines_per_page = prt_get_lpp();

  /* Catch margin settings that leave no space for output! */
  if (psettings->chars_per_line <= 0 || psettings->lines_per_page <= 0)
    return FAIL;

  /*
   * Sort out the number of copies to be printed.  PS by default will do
   * uncollated copies for you, so once we know how many uncollated copies are
   * wanted cache it away and lie to the generic code that we only want one
   * uncollated copy.
   */
  psettings->n_collated_copies = 1;
  psettings->n_uncollated_copies = 1;
  prt_num_copies = 1;
  prt_collate = (!printer_opts[OPT_PRINT_COLLATE].present
                 || TOLOWER_ASC(printer_opts[OPT_PRINT_COLLATE].string[0]) ==
                 'y');
  if (prt_collate) {
    /* TODO: Get number of collated copies wanted. */
    psettings->n_collated_copies = 1;
  } else {
    /* TODO: Get number of uncollated copies wanted and update the cached
     * count.
     */
    prt_num_copies = 1;
  }

  psettings->jobname = jobname;

  /*
   * Set up printer duplex and tumble based on Duplex option setting - default
   * is long sided duplex printing (i.e. no tumble).
   */
  prt_duplex = TRUE;
  prt_tumble = FALSE;
  psettings->duplex = 1;
  if (printer_opts[OPT_PRINT_DUPLEX].present) {
    if (STRNICMP(printer_opts[OPT_PRINT_DUPLEX].string, "off", 3) == 0) {
      prt_duplex = FALSE;
      psettings->duplex = 0;
    } else if (STRNICMP(printer_opts[OPT_PRINT_DUPLEX].string, "short", 5)
               == 0)
      prt_tumble = TRUE;
  }

  /* For now user abort not supported */
  psettings->user_abort = 0;

  /* If the user didn't specify a file name, use a temp file. */
  if (psettings->outfile == NULL) {
    prt_ps_file_name = vim_tempname();
    if (prt_ps_file_name == NULL) {
      EMSG(_(e_notmp));
      return FAIL;
    }
    prt_ps_fd = os_fopen((char *)prt_ps_file_name, WRITEBIN);
  } else {
    p = expand_env_save(psettings->outfile);
    if (p != NULL) {
      prt_ps_fd = os_fopen((char *)p, WRITEBIN);
      xfree(p);
    }
  }
  if (prt_ps_fd == NULL) {
    EMSG(_("E324: Can't open PostScript output file"));
    mch_print_cleanup();
    return FAIL;
  }

  prt_bufsiz = psettings->chars_per_line;
  if (prt_out_mbyte)
    prt_bufsiz *= 2;
  ga_init(&prt_ps_buffer, (int)sizeof(char), prt_bufsiz);

  prt_page_num = 0;

  prt_attribute_change = FALSE;
  prt_need_moveto = FALSE;
  prt_need_font = FALSE;
  prt_need_fgcol = FALSE;
  prt_need_bgcol = FALSE;
  prt_need_underline = FALSE;

  prt_file_error = FALSE;

  return OK;
}

static int prt_add_resource(struct prt_ps_resource_S *resource)
{
  FILE*       fd_resource;
  char_u resource_buffer[512];
  size_t bytes_read;

  fd_resource = os_fopen((char *)resource->filename, READBIN);
  if (fd_resource == NULL) {
    EMSG2(_("E456: Can't open file \"%s\""), resource->filename);
    return FALSE;
  }
  prt_dsc_resources("BeginResource", prt_resource_types[resource->type],
      (char *)resource->title);

  prt_dsc_textline("BeginDocument", (char *)resource->filename);

  for (;; ) {
    bytes_read = fread((char *)resource_buffer, sizeof(char_u),
        sizeof(resource_buffer), fd_resource);
    if (ferror(fd_resource)) {
      EMSG2(_("E457: Can't read PostScript resource file \"%s\""),
          resource->filename);
      fclose(fd_resource);
      return FALSE;
    }
    if (bytes_read == 0)
      break;
    prt_write_file_raw_len(resource_buffer, bytes_read);
    if (prt_file_error) {
      fclose(fd_resource);
      return FALSE;
    }
  }
  fclose(fd_resource);

  prt_dsc_noarg("EndDocument");

  prt_dsc_noarg("EndResource");

  return TRUE;
}

int mch_print_begin(prt_settings_T *psettings)
{
  time_t now;
  int bbox[4];
  char        *p_time;
  double left;
  double right;
  double top;
  double bottom;
  struct prt_ps_resource_S res_prolog;
  struct prt_ps_resource_S res_encoding;
  char buffer[256];
  char_u      *p_encoding;
  char_u      *p;
  struct prt_ps_resource_S res_cidfont;
  struct prt_ps_resource_S res_cmap;
  int retval = FALSE;

  /*
   * PS DSC Header comments - no PS code!
   */
  prt_dsc_start();
  prt_dsc_textline("Title", (char *)psettings->jobname);
  if (os_get_user_name(buffer, 256) == FAIL) {
    STRCPY(buffer, "Unknown");
  }
  prt_dsc_textline("For", buffer);
  prt_dsc_textline("Creator", longVersion);
  /* Note: to ensure Clean8bit I don't think we can use LC_TIME */
  now = time(NULL);
  p_time = ctime(&now);
  /* Note: ctime() adds a \n so we have to remove it :-( */
  p = vim_strchr((char_u *)p_time, '\n');
  if (p != NULL)
    *p = NUL;
  prt_dsc_textline("CreationDate", p_time);
  prt_dsc_textline("DocumentData", "Clean8Bit");
  prt_dsc_textline("Orientation", "Portrait");
  prt_dsc_atend("Pages");
  prt_dsc_textline("PageOrder", "Ascend");
  /* The bbox does not change with orientation - it is always in the default
   * user coordinate system!  We have to recalculate right and bottom
   * coordinates based on the font metrics for the bbox to be accurate. */
  prt_page_margins(prt_mediasize[prt_media].width,
      prt_mediasize[prt_media].height,
      &left, &right, &top, &bottom);
  bbox[0] = (int)left;
  if (prt_portrait) {
    /* In portrait printing the fixed point is the top left corner so we
     * derive the bbox from that point.  We have the expected cpl chars
     * across the media and lpp lines down the media.
     */
    bbox[1] = (int)(top - (psettings->lines_per_page + prt_header_height())
                    * prt_line_height);
    bbox[2] = (int)(left + psettings->chars_per_line * prt_char_width
                    + 0.5);
    bbox[3] = (int)(top + 0.5);
  } else {
    /* In landscape printing the fixed point is the bottom left corner so we
     * derive the bbox from that point.  We have lpp chars across the media
     * and cpl lines up the media.
     */
    bbox[1] = (int)bottom;
    bbox[2] = (int)(left + ((psettings->lines_per_page
                             + prt_header_height()) * prt_line_height) + 0.5);
    bbox[3] = (int)(bottom + psettings->chars_per_line * prt_char_width
                    + 0.5);
  }
  prt_dsc_ints("BoundingBox", 4, bbox);
  /* The media width and height does not change with landscape printing! */
  prt_dsc_docmedia(prt_mediasize[prt_media].name,
      prt_mediasize[prt_media].width,
      prt_mediasize[prt_media].height,
      (double)0, NULL, NULL);
  /* Define fonts needed */
  if (!prt_out_mbyte || prt_use_courier)
    prt_dsc_font_resource("DocumentNeededResources", &prt_ps_courier_font);
  if (prt_out_mbyte) {
    prt_dsc_font_resource((prt_use_courier ? NULL
                           : "DocumentNeededResources"), &prt_ps_mb_font);
    if (!prt_custom_cmap)
      prt_dsc_resources(NULL, "cmap", prt_cmap);
  }

  /* Search for external resources VIM supplies */
  if (!prt_find_resource("prolog", &res_prolog)) {
    EMSG(_("E456: Can't find PostScript resource file \"prolog.ps\""));
    return FALSE;
  }
  if (!prt_open_resource(&res_prolog))
    return FALSE;
  if (!prt_check_resource(&res_prolog, PRT_PROLOG_VERSION))
    return FALSE;
  if (prt_out_mbyte) {
    /* Look for required version of multi-byte printing procset */
    if (!prt_find_resource("cidfont", &res_cidfont)) {
      EMSG(_("E456: Can't find PostScript resource file \"cidfont.ps\""));
      return FALSE;
    }
    if (!prt_open_resource(&res_cidfont))
      return FALSE;
    if (!prt_check_resource(&res_cidfont, PRT_CID_PROLOG_VERSION))
      return FALSE;
  }

  /* Find an encoding to use for printing.
   * Check 'printencoding'. If not set or not found, then use 'encoding'. If
   * that cannot be found then default to "latin1".
   * Note: VIM specific encoding header is always skipped.
   */
  if (!prt_out_mbyte) {
    p_encoding = enc_skip(p_penc);
    if (*p_encoding == NUL
        || !prt_find_resource((char *)p_encoding, &res_encoding)) {
      /* 'printencoding' not set or not supported - find alternate */
      int props;

      p_encoding = enc_skip(p_enc);
      props = enc_canon_props(p_encoding);
      if (!(props & ENC_8BIT)
          || !prt_find_resource((char *)p_encoding, &res_encoding)) {
        /* 8-bit 'encoding' is not supported */
        /* Use latin1 as default printing encoding */
        p_encoding = (char_u *)"latin1";
        if (!prt_find_resource((char *)p_encoding, &res_encoding)) {
          EMSG2(_("E456: Can't find PostScript resource file \"%s.ps\""),
              p_encoding);
          return FALSE;
        }
      }
    }
    if (!prt_open_resource(&res_encoding))
      return FALSE;
    /* For the moment there are no checks on encoding resource files to
     * perform */
  } else {
    p_encoding = enc_skip(p_penc);
    if (*p_encoding == NUL)
      p_encoding = enc_skip(p_enc);
    if (prt_use_courier) {
      /* Include ASCII range encoding vector */
      if (!prt_find_resource(prt_ascii_encoding, &res_encoding)) {
        EMSG2(_("E456: Can't find PostScript resource file \"%s.ps\""),
            prt_ascii_encoding);
        return FALSE;
      }
      if (!prt_open_resource(&res_encoding))
        return FALSE;
      /* For the moment there are no checks on encoding resource files to
       * perform */
    }
  }

  prt_conv.vc_type = CONV_NONE;
  if (!(enc_canon_props(p_enc) & enc_canon_props(p_encoding) & ENC_8BIT)) {
    // Set up encoding conversion if required
    if (convert_setup(&prt_conv, p_enc, p_encoding) == FAIL) {
      emsgf(_("E620: Unable to convert to print encoding \"%s\""),
            p_encoding);
      return false;
    }
  }
  prt_do_conv = prt_conv.vc_type != CONV_NONE;

  if (prt_out_mbyte && prt_custom_cmap) {
    /* Find user supplied CMap */
    if (!prt_find_resource(prt_cmap, &res_cmap)) {
      EMSG2(_("E456: Can't find PostScript resource file \"%s.ps\""),
          prt_cmap);
      return FALSE;
    }
    if (!prt_open_resource(&res_cmap))
      return FALSE;
  }

  /* List resources supplied */
  STRCPY(buffer, res_prolog.title);
  STRCAT(buffer, " ");
  STRCAT(buffer, res_prolog.version);
  prt_dsc_resources("DocumentSuppliedResources", "procset", buffer);
  if (prt_out_mbyte) {
    STRCPY(buffer, res_cidfont.title);
    STRCAT(buffer, " ");
    STRCAT(buffer, res_cidfont.version);
    prt_dsc_resources(NULL, "procset", buffer);

    if (prt_custom_cmap) {
      STRCPY(buffer, res_cmap.title);
      STRCAT(buffer, " ");
      STRCAT(buffer, res_cmap.version);
      prt_dsc_resources(NULL, "cmap", buffer);
    }
  }
  if (!prt_out_mbyte || prt_use_courier) {
    STRCPY(buffer, res_encoding.title);
    STRCAT(buffer, " ");
    STRCAT(buffer, res_encoding.version);
    prt_dsc_resources(NULL, "encoding", buffer);
  }
  prt_dsc_requirements(prt_duplex, prt_tumble, prt_collate,
      psettings->do_syntax
      , prt_num_copies);
  prt_dsc_noarg("EndComments");

  /*
   * PS Document page defaults
   */
  prt_dsc_noarg("BeginDefaults");

  /* List font resources most likely common to all pages */
  if (!prt_out_mbyte || prt_use_courier)
    prt_dsc_font_resource("PageResources", &prt_ps_courier_font);
  if (prt_out_mbyte) {
    prt_dsc_font_resource((prt_use_courier ? NULL : "PageResources"),
        &prt_ps_mb_font);
    if (!prt_custom_cmap)
      prt_dsc_resources(NULL, "cmap", prt_cmap);
  }

  /* Paper will be used for all pages */
  prt_dsc_textline("PageMedia", prt_mediasize[prt_media].name);

  prt_dsc_noarg("EndDefaults");

  /*
   * PS Document prolog inclusion - all required procsets.
   */
  prt_dsc_noarg("BeginProlog");

  /* Add required procsets - NOTE: order is important! */
  if (!prt_add_resource(&res_prolog))
    return FALSE;
  if (prt_out_mbyte) {
    /* Add CID font procset, and any user supplied CMap */
    if (!prt_add_resource(&res_cidfont))
      return FALSE;
    if (prt_custom_cmap && !prt_add_resource(&res_cmap))
      return FALSE;
  }

  if (!prt_out_mbyte || prt_use_courier)
    /* There will be only one Roman font encoding to be included in the PS
     * file. */
    if (!prt_add_resource(&res_encoding))
      return FALSE;

  prt_dsc_noarg("EndProlog");

  /*
   * PS Document setup - must appear after the prolog
   */
  prt_dsc_noarg("BeginSetup");

  /* Device setup - page size and number of uncollated copies */
  prt_write_int((int)prt_mediasize[prt_media].width);
  prt_write_int((int)prt_mediasize[prt_media].height);
  prt_write_int(0);
  prt_write_string("sps\n");
  prt_write_int(prt_num_copies);
  prt_write_string("nc\n");
  prt_write_boolean(prt_duplex);
  prt_write_boolean(prt_tumble);
  prt_write_string("dt\n");
  prt_write_boolean(prt_collate);
  prt_write_string("c\n");

  /* Font resource inclusion and definition */
  if (!prt_out_mbyte || prt_use_courier) {
    /* When using Courier for ASCII range when printing multi-byte, need to
     * pick up ASCII encoding to use with it. */
    if (prt_use_courier)
      p_encoding = (char_u *)prt_ascii_encoding;
    prt_dsc_resources("IncludeResource", "font",
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_ROMAN]);
    prt_def_font("F0", (char *)p_encoding, (int)prt_line_height,
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_ROMAN]);
    prt_dsc_resources("IncludeResource", "font",
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_BOLD]);
    prt_def_font("F1", (char *)p_encoding, (int)prt_line_height,
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_BOLD]);
    prt_dsc_resources("IncludeResource", "font",
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_OBLIQUE]);
    prt_def_font("F2", (char *)p_encoding, (int)prt_line_height,
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_OBLIQUE]);
    prt_dsc_resources("IncludeResource", "font",
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_BOLDOBLIQUE]);
    prt_def_font("F3", (char *)p_encoding, (int)prt_line_height,
        prt_ps_courier_font.ps_fontname[PRT_PS_FONT_BOLDOBLIQUE]);
  }
  if (prt_out_mbyte) {
    /* Define the CID fonts to be used in the job.	Typically CJKV fonts do
     * not have an italic form being a western style, so where no font is
     * defined for these faces VIM falls back to an existing face.
     * Note: if using Courier for the ASCII range then the printout will
     * have bold/italic/bolditalic regardless of the setting of printmbfont.
     */
    prt_dsc_resources("IncludeResource", "font",
        prt_ps_mb_font.ps_fontname[PRT_PS_FONT_ROMAN]);
    if (!prt_custom_cmap)
      prt_dsc_resources("IncludeResource", "cmap", prt_cmap);
    prt_def_cidfont("CF0", (int)prt_line_height,
        prt_ps_mb_font.ps_fontname[PRT_PS_FONT_ROMAN]);

    if (prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLD] != NULL) {
      prt_dsc_resources("IncludeResource", "font",
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLD]);
      if (!prt_custom_cmap)
        prt_dsc_resources("IncludeResource", "cmap", prt_cmap);
      prt_def_cidfont("CF1", (int)prt_line_height,
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLD]);
    } else
      /* Use ROMAN for BOLD */
      prt_dup_cidfont("CF0", "CF1");

    if (prt_ps_mb_font.ps_fontname[PRT_PS_FONT_OBLIQUE] != NULL) {
      prt_dsc_resources("IncludeResource", "font",
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_OBLIQUE]);
      if (!prt_custom_cmap)
        prt_dsc_resources("IncludeResource", "cmap", prt_cmap);
      prt_def_cidfont("CF2", (int)prt_line_height,
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_OBLIQUE]);
    } else
      /* Use ROMAN for OBLIQUE */
      prt_dup_cidfont("CF0", "CF2");

    if (prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLDOBLIQUE] != NULL) {
      prt_dsc_resources("IncludeResource", "font",
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLDOBLIQUE]);
      if (!prt_custom_cmap)
        prt_dsc_resources("IncludeResource", "cmap", prt_cmap);
      prt_def_cidfont("CF3", (int)prt_line_height,
          prt_ps_mb_font.ps_fontname[PRT_PS_FONT_BOLDOBLIQUE]);
    } else
      /* Use BOLD for BOLDOBLIQUE */
      prt_dup_cidfont("CF1", "CF3");
  }

  /* Misc constant vars used for underlining and background rects */
  prt_def_var("UO", PRT_PS_FONT_TO_USER(prt_line_height,
          prt_ps_font->uline_offset), 2);
  prt_def_var("UW", PRT_PS_FONT_TO_USER(prt_line_height,
          prt_ps_font->uline_width), 2);
  prt_def_var("BO", prt_bgcol_offset, 2);

  prt_dsc_noarg("EndSetup");

  /* Fail if any problems writing out to the PS file */
  retval = !prt_file_error;

  return retval;
}

void mch_print_end(prt_settings_T *psettings)
{
  prt_dsc_noarg("Trailer");

  /*
   * Output any info we don't know in toto until we finish
   */
  prt_dsc_ints("Pages", 1, &prt_page_num);

  prt_dsc_noarg("EOF");

  /* Write CTRL-D to close serial communication link if used.
   * NOTHING MUST BE WRITTEN AFTER THIS! */
  prt_write_file((char_u *)"\004");

  if (!prt_file_error && psettings->outfile == NULL
      && !got_int && !psettings->user_abort) {
    /* Close the file first. */
    if (prt_ps_fd != NULL) {
      fclose(prt_ps_fd);
      prt_ps_fd = NULL;
    }
    prt_message((char_u *)_("Sending to printer..."));

    // Not printing to a file: use 'printexpr' to print the file.
    if (eval_printexpr((char *) prt_ps_file_name, (char *) psettings->arguments)
        == FAIL) {
      EMSG(_("E365: Failed to print PostScript file"));
    } else {
      prt_message((char_u *)_("Print job sent."));
    }
  }

  mch_print_cleanup();
}

int mch_print_end_page(void)
{
  prt_flush_buffer();

  prt_write_string("re sp\n");

  prt_dsc_noarg("PageTrailer");

  return !prt_file_error;
}

int mch_print_begin_page(char_u *str)
{
  int page_num[2];

  prt_page_num++;

  page_num[0] = page_num[1] = prt_page_num;
  prt_dsc_ints("Page", 2, page_num);

  prt_dsc_noarg("BeginPageSetup");

  prt_write_string("sv\n0 g\n");
  prt_in_ascii = !prt_out_mbyte;
  if (prt_out_mbyte)
    prt_write_string("CF0 sf\n");
  else
    prt_write_string("F0 sf\n");
  prt_fgcol = PRCOLOR_BLACK;
  prt_bgcol = PRCOLOR_WHITE;
  prt_font = PRT_PS_FONT_ROMAN;

  /* Set up page transformation for landscape printing. */
  if (!prt_portrait) {
    prt_write_int(-((int)prt_mediasize[prt_media].width));
    prt_write_string("sl\n");
  }

  prt_dsc_noarg("EndPageSetup");

  /* We have reset the font attributes, force setting them again. */
  curr_bg = 0xffffffff;
  curr_fg = 0xffffffff;
  curr_bold = kNone;

  return !prt_file_error;
}

int mch_print_blank_page(void)
{
  return mch_print_begin_page(NULL) ? (mch_print_end_page()) : FALSE;
}

static double prt_pos_x = 0;
static double prt_pos_y = 0;

void mch_print_start_line(const bool margin, const int page_line)
{
  prt_pos_x = prt_left_margin;
  if (margin) {
    prt_pos_x -= prt_number_width;
  }

  prt_pos_y = prt_top_margin - prt_first_line_height -
              page_line * prt_line_height;

  prt_attribute_change = TRUE;
  prt_need_moveto = TRUE;
  prt_half_width = FALSE;
}

int mch_print_text_out(char_u *const textp, size_t len)
{
  char_u *p = textp;
  char_u ch;
  char_u ch_buff[8];
  char_u *tofree = NULL;
  double char_width = prt_char_width;

  /* Ideally VIM would create a rearranged CID font to combine a Roman and
   * CJKV font to do what VIM is doing here - use a Roman font for characters
   * in the ASCII range, and the original CID font for everything else.
   * The problem is that GhostScript still (as of 8.13) does not support
   * rearranged fonts even though they have been documented by Adobe for 7
   * years!  If they ever do, a lot of this code will disappear.
   */
  if (prt_use_courier) {
    const bool in_ascii = (len == 1 && *p < 0x80);
    if (prt_in_ascii) {
      if (!in_ascii) {
        /* No longer in ASCII range - need to switch font */
        prt_in_ascii = FALSE;
        prt_need_font = TRUE;
        prt_attribute_change = TRUE;
      }
    } else if (in_ascii) {
      /* Now in ASCII range - need to switch font */
      prt_in_ascii = TRUE;
      prt_need_font = TRUE;
      prt_attribute_change = TRUE;
    }
  }
  if (prt_out_mbyte) {
    const bool half_width = (utf_ptr2cells(p) == 1);
    if (half_width) {
      char_width /= 2;
    }
    if (prt_half_width) {
      if (!half_width) {
        prt_half_width = FALSE;
        prt_pos_x += prt_char_width/4;
        prt_need_moveto = TRUE;
        prt_attribute_change = TRUE;
      }
    } else if (half_width) {
      prt_half_width = TRUE;
      prt_pos_x += prt_char_width/4;
      prt_need_moveto = TRUE;
      prt_attribute_change = TRUE;
    }
  }

  /* Output any required changes to the graphics state, after flushing any
   * text buffered so far.
   */
  if (prt_attribute_change) {
    prt_flush_buffer();
    /* Reset count of number of chars that will be printed */
    prt_text_run = 0;

    if (prt_need_moveto) {
      prt_pos_x_moveto = prt_pos_x;
      prt_pos_y_moveto = prt_pos_y;
      prt_do_moveto = TRUE;

      prt_need_moveto = FALSE;
    }
    if (prt_need_font) {
      if (!prt_in_ascii)
        prt_write_string("CF");
      else
        prt_write_string("F");
      prt_write_int(prt_font);
      prt_write_string("sf\n");
      prt_need_font = FALSE;
    }
    if (prt_need_fgcol) {
      unsigned int r, g, b;
      r = (prt_fgcol & 0xff0000) >> 16;
      g = (prt_fgcol & 0xff00) >> 8;
      b = prt_fgcol & 0xff;

      prt_write_real(r / 255.0, 3);
      if (r == g && g == b)
        prt_write_string("g\n");
      else {
        prt_write_real(g / 255.0, 3);
        prt_write_real(b / 255.0, 3);
        prt_write_string("r\n");
      }
      prt_need_fgcol = FALSE;
    }

    if (prt_bgcol != PRCOLOR_WHITE) {
      prt_new_bgcol = prt_bgcol;
      if (prt_need_bgcol)
        prt_do_bgcol = TRUE;
    } else
      prt_do_bgcol = FALSE;
    prt_need_bgcol = FALSE;

    if (prt_need_underline)
      prt_do_underline = prt_underline;
    prt_need_underline = FALSE;

    prt_attribute_change = FALSE;
  }

  if (prt_do_conv) {
    // Convert from multi-byte to 8-bit encoding
    tofree = p = string_convert(&prt_conv, p, &len);
    if (p == NULL) {
      p = (char_u *)"";
      len = 0;
    }
  }

  if (prt_out_mbyte) {
    // Multi-byte character strings are represented more efficiently as hex
    // strings when outputting clean 8 bit PS.
    while (len-- > 0) {
      ch = prt_hexchar[(unsigned)(*p) >> 4];
      ga_append(&prt_ps_buffer, (char)ch);
      ch = prt_hexchar[(*p) & 0xf];
      ga_append(&prt_ps_buffer, (char)ch);
      p++;
    }
  } else {
    /* Add next character to buffer of characters to output.
     * Note: One printed character may require several PS characters to
     * represent it, but we only count them as one printed character.
     */
    ch = *p;
    if (ch < 32 || ch == '(' || ch == ')' || ch == '\\') {
      /* Convert non-printing characters to either their escape or octal
       * sequence, ensures PS sent over a serial line does not interfere
       * with the comms protocol.
       */
      ga_append(&prt_ps_buffer, '\\');
      switch (ch) {
      case BS:   ga_append(&prt_ps_buffer, 'b'); break;
      case TAB:  ga_append(&prt_ps_buffer, 't'); break;
      case NL:   ga_append(&prt_ps_buffer, 'n'); break;
      case FF:   ga_append(&prt_ps_buffer, 'f'); break;
      case CAR:  ga_append(&prt_ps_buffer, 'r'); break;
      case '(':  ga_append(&prt_ps_buffer, '('); break;
      case ')':  ga_append(&prt_ps_buffer, ')'); break;
      case '\\': ga_append(&prt_ps_buffer, '\\'); break;

      default:
        sprintf((char *)ch_buff, "%03o", (unsigned int)ch);
        ga_append(&prt_ps_buffer, (char)ch_buff[0]);
        ga_append(&prt_ps_buffer, (char)ch_buff[1]);
        ga_append(&prt_ps_buffer, (char)ch_buff[2]);
        break;
      }
    } else
      ga_append(&prt_ps_buffer, (char)ch);
  }

  // Need to free any translated characters
  xfree(tofree);

  prt_text_run += char_width;
  prt_pos_x += char_width;

  // The downside of fp - use relative error on right margin check
  const double next_pos = prt_pos_x + prt_char_width;
  const bool need_break = (next_pos > prt_right_margin)
      && ((next_pos - prt_right_margin) > (prt_right_margin * 1e-5));

  if (need_break) {
    prt_flush_buffer();
  }

  return need_break;
}

void mch_print_set_font(const TriState iBold, const TriState iItalic,
                        const TriState iUnderline)
{
  int font = 0;

  if (iBold)
    font |= 0x01;
  if (iItalic)
    font |= 0x02;

  if (font != prt_font) {
    prt_font = font;
    prt_attribute_change = TRUE;
    prt_need_font = TRUE;
  }
  if (prt_underline != iUnderline) {
    prt_underline = iUnderline;
    prt_attribute_change = TRUE;
    prt_need_underline = TRUE;
  }
}

void mch_print_set_bg(uint32_t bgcol)
{
  prt_bgcol = bgcol;
  prt_attribute_change = TRUE;
  prt_need_bgcol = TRUE;
}

void mch_print_set_fg(uint32_t fgcol)
{
  if (fgcol != prt_fgcol) {
    prt_fgcol = fgcol;
    prt_attribute_change = TRUE;
    prt_need_fgcol = TRUE;
  }
}

