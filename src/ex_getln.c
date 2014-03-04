/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ex_getln.c: Functions for entering and editing an Ex command line.
 */

#include "vim.h"
#include "ex_getln.h"
#include "buffer.h"
#include "charset.h"
#include "digraph.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_eval.h"
#include "fileio.h"
#include "getchar.h"
#include "if_cscope.h"
#include "indent.h"
#include "main.h"
#include "mbyte.h"
#include "memline.h"
#include "menu.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "ops.h"
#include "option.h"
#include "os_unix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "syntax.h"
#include "tag.h"
#include "term.h"
#include "window.h"
#include "os/os.h"

/*
 * Variables shared between getcmdline(), redrawcmdline() and others.
 * These need to be saved when using CTRL-R |, that's why they are in a
 * structure.
 */
struct cmdline_info {
  char_u      *cmdbuff;         /* pointer to command line buffer */
  int cmdbufflen;               /* length of cmdbuff */
  int cmdlen;                   /* number of chars in command line */
  int cmdpos;                   /* current cursor position */
  int cmdspos;                  /* cursor column on screen */
  int cmdfirstc;                /* ':', '/', '?', '=', '>' or NUL */
  int cmdindent;                /* number of spaces before cmdline */
  char_u      *cmdprompt;       /* message in front of cmdline */
  int cmdattr;                  /* attributes for prompt */
  int overstrike;               /* Typing mode on the command line.  Shared by
                                   getcmdline() and put_on_cmdline(). */
  expand_T    *xpc;             /* struct being used for expansion, xp_pattern
                                   may point into cmdbuff */
  int xp_context;               /* type of expansion */
  char_u      *xp_arg;          /* user-defined expansion arg */
  int input_fn;                 /* when TRUE Invoked for input() function */
};

/* The current cmdline_info.  It is initialized in getcmdline() and after that
 * used by other functions.  When invoking getcmdline() recursively it needs
 * to be saved with save_cmdline() and restored with restore_cmdline().
 * TODO: make it local to getcmdline() and pass it around. */
static struct cmdline_info ccline;

static int cmd_showtail;                /* Only show path tail in lists ? */

static int new_cmdpos;          /* position set by set_cmdline_pos() */

typedef struct hist_entry {
  int hisnum;                   /* identifying number */
  int viminfo;                  /* when TRUE hisstr comes from viminfo */
  char_u      *hisstr;          /* actual entry, separator char after the NUL */
} histentry_T;

static histentry_T *(history[HIST_COUNT]) = {NULL, NULL, NULL, NULL, NULL};
static int hisidx[HIST_COUNT] = {-1, -1, -1, -1, -1};       /* lastused entry */
static int hisnum[HIST_COUNT] = {0, 0, 0, 0, 0};
/* identifying (unique) number of newest history entry */
static int hislen = 0;                  /* actual length of history tables */

static int hist_char2type(int c);

static int in_history(int, char_u *, int, int, int);
static int calc_hist_idx(int histype, int num);

static int cmd_hkmap = 0;       /* Hebrew mapping during command line */

static int cmd_fkmap = 0;       /* Farsi mapping during command line */

static int cmdline_charsize(int idx);
static void set_cmdspos(void);
static void set_cmdspos_cursor(void);
static void correct_cmdspos(int idx, int cells);
static void alloc_cmdbuff(int len);
static int realloc_cmdbuff(int len);
static void draw_cmdline(int start, int len);
static void save_cmdline(struct cmdline_info *ccp);
static void restore_cmdline(struct cmdline_info *ccp);
static int cmdline_paste(int regname, int literally, int remcr);
static void cmdline_del(int from);
static void redrawcmdprompt(void);
static void cursorcmd(void);
static int ccheck_abbr(int);
static int nextwild(expand_T *xp, int type, int options, int escape);
static void escape_fname(char_u **pp);
static int showmatches(expand_T *xp, int wildmenu);
static void set_expand_context(expand_T *xp);
static int ExpandFromContext(expand_T *xp, char_u *, int *, char_u ***, int);
static int expand_showtail(expand_T *xp);
static int expand_shellcmd(char_u *filepat, int *num_file,
                           char_u ***file,
                           int flagsarg);
static int ExpandRTDir(char_u *pat, int *num_file, char_u ***file,
                               char *dirname[]);
static char_u   *get_history_arg(expand_T *xp, int idx);
static int ExpandUserDefined(expand_T *xp, regmatch_T *regmatch,
                             int *num_file,
                             char_u ***file);
static int ExpandUserList(expand_T *xp, int *num_file, char_u ***file);
static void clear_hist_entry(histentry_T *hisptr);

static int ex_window(void);

static int sort_func_compare(const void *s1, const void *s2);

/*
 * getcmdline() - accept a command line starting with firstc.
 *
 * firstc == ':'	    get ":" command line.
 * firstc == '/' or '?'	    get search pattern
 * firstc == '='	    get expression
 * firstc == '@'	    get text for input() function
 * firstc == '>'	    get text for debug mode
 * firstc == NUL	    get text for :insert command
 * firstc == -1		    like NUL, and break on CTRL-C
 *
 * The line is collected in ccline.cmdbuff, which is reallocated to fit the
 * command line.
 *
 * Careful: getcmdline() can be called recursively!
 *
 * Return pointer to allocated string if there is a commandline, NULL
 * otherwise.
 */
char_u *
getcmdline (
    int firstc,
    long count,              /* only used for incremental search */
    int indent                     /* indent for inside conditionals */
)
{
  int c;
  int i;
  int j;
  int gotesc = FALSE;                   /* TRUE when <ESC> just typed */
  int do_abbr;                          /* when TRUE check for abbr. */
  char_u      *lookfor = NULL;          /* string to match */
  int hiscnt;                           /* current history line in use */
  int histype;                          /* history type to be used */
  pos_T old_cursor;
  colnr_T old_curswant;
  colnr_T old_leftcol;
  linenr_T old_topline;
  int old_topfill;
  linenr_T old_botline;
  int did_incsearch = FALSE;
  int incsearch_postponed = FALSE;
  int did_wild_list = FALSE;            /* did wild_list() recently */
  int wim_index = 0;                    /* index in wim_flags[] */
  int res;
  int save_msg_scroll = msg_scroll;
  int save_State = State;               /* remember State when called */
  int some_key_typed = FALSE;           /* one of the keys was typed */
  /* mouse drag and release events are ignored, unless they are
   * preceded with a mouse down event */
  int ignore_drag_release = TRUE;
  int break_ctrl_c = FALSE;
  expand_T xpc;
  long        *b_im_ptr = NULL;
  /* Everything that may work recursively should save and restore the
   * current command line in save_ccline.  That includes update_screen(), a
   * custom status line may invoke ":normal". */
  struct cmdline_info save_ccline;

  if (firstc == -1) {
    firstc = NUL;
    break_ctrl_c = TRUE;
  }
  /* start without Hebrew mapping for a command line */
  if (firstc == ':' || firstc == '=' || firstc == '>')
    cmd_hkmap = 0;

  ccline.overstrike = FALSE;                /* always start in insert mode */
  old_cursor = curwin->w_cursor;            /* needs to be restored later */
  old_curswant = curwin->w_curswant;
  old_leftcol = curwin->w_leftcol;
  old_topline = curwin->w_topline;
  old_topfill = curwin->w_topfill;
  old_botline = curwin->w_botline;

  /*
   * set some variables for redrawcmd()
   */
  ccline.cmdfirstc = (firstc == '@' ? 0 : firstc);
  ccline.cmdindent = (firstc > 0 ? indent : 0);

  /* alloc initial ccline.cmdbuff */
  alloc_cmdbuff(exmode_active ? 250 : indent + 1);
  if (ccline.cmdbuff == NULL)
    return NULL;                            /* out of memory */
  ccline.cmdlen = ccline.cmdpos = 0;
  ccline.cmdbuff[0] = NUL;

  /* autoindent for :insert and :append */
  if (firstc <= 0) {
    copy_spaces(ccline.cmdbuff, indent);
    ccline.cmdbuff[indent] = NUL;
    ccline.cmdpos = indent;
    ccline.cmdspos = indent;
    ccline.cmdlen = indent;
  }

  ExpandInit(&xpc);
  ccline.xpc = &xpc;

  if (curwin->w_p_rl && *curwin->w_p_rlc == 's'
      && (firstc == '/' || firstc == '?'))
    cmdmsg_rl = TRUE;
  else
    cmdmsg_rl = FALSE;

  redir_off = TRUE;             /* don't redirect the typed command */
  if (!cmd_silent) {
    i = msg_scrolled;
    msg_scrolled = 0;                   /* avoid wait_return message */
    gotocmdline(TRUE);
    msg_scrolled += i;
    redrawcmdprompt();                  /* draw prompt or indent */
    set_cmdspos();
  }
  xpc.xp_context = EXPAND_NOTHING;
  xpc.xp_backslash = XP_BS_NONE;
#ifndef BACKSLASH_IN_FILENAME
  xpc.xp_shell = FALSE;
#endif

  if (ccline.input_fn) {
    xpc.xp_context = ccline.xp_context;
    xpc.xp_pattern = ccline.cmdbuff;
    xpc.xp_arg = ccline.xp_arg;
  }

  /*
   * Avoid scrolling when called by a recursive do_cmdline(), e.g. when
   * doing ":@0" when register 0 doesn't contain a CR.
   */
  msg_scroll = FALSE;

  State = CMDLINE;

  if (firstc == '/' || firstc == '?' || firstc == '@') {
    /* Use ":lmap" mappings for search pattern and input(). */
    if (curbuf->b_p_imsearch == B_IMODE_USE_INSERT)
      b_im_ptr = &curbuf->b_p_iminsert;
    else
      b_im_ptr = &curbuf->b_p_imsearch;
    if (*b_im_ptr == B_IMODE_LMAP)
      State |= LANGMAP;
#ifdef USE_IM_CONTROL
    im_set_active(*b_im_ptr == B_IMODE_IM);
#endif
  }
#ifdef USE_IM_CONTROL
  else if (p_imcmdline)
    im_set_active(TRUE);
#endif

  setmouse();
#ifdef CURSOR_SHAPE
  ui_cursor_shape();            /* may show different cursor shape */
#endif

  /* When inside an autocommand for writing "exiting" may be set and
  * terminal mode set to cooked.  Need to set raw mode here then. */
  settmode(TMODE_RAW);

  init_history();
  hiscnt = hislen;              /* set hiscnt to impossible history value */
  histype = hist_char2type(firstc);

  do_digraph(-1);               /* init digraph typeahead */

  /*
   * Collect the command string, handling editing keys.
   */
  for (;; ) {
    redir_off = TRUE;           /* Don't redirect the typed command.
                                   Repeated, because a ":redir" inside
                                   completion may switch it on. */
#ifdef USE_ON_FLY_SCROLL
    dont_scroll = FALSE;        /* allow scrolling here */
#endif
    quit_more = FALSE;          /* reset after CTRL-D which had a more-prompt */

    cursorcmd();                /* set the cursor on the right spot */

    /* Get a character.  Ignore K_IGNORE, it should not do anything, such
     * as stop completion. */
    do {
      c = safe_vgetc();
    } while (c == K_IGNORE);

    if (KeyTyped) {
      some_key_typed = TRUE;
      if (cmd_hkmap)
        c = hkmap(c);
      if (cmd_fkmap)
        c = cmdl_fkmap(c);
      if (cmdmsg_rl && !KeyStuffed) {
        /* Invert horizontal movements and operations.  Only when
         * typed by the user directly, not when the result of a
         * mapping. */
        switch (c) {
        case K_RIGHT:   c = K_LEFT; break;
        case K_S_RIGHT: c = K_S_LEFT; break;
        case K_C_RIGHT: c = K_C_LEFT; break;
        case K_LEFT:    c = K_RIGHT; break;
        case K_S_LEFT:  c = K_S_RIGHT; break;
        case K_C_LEFT:  c = K_C_RIGHT; break;
        }
      }
    }

    /*
     * Ignore got_int when CTRL-C was typed here.
     * Don't ignore it in :global, we really need to break then, e.g., for
     * ":g/pat/normal /pat" (without the <CR>).
     * Don't ignore it for the input() function.
     */
    if ((c == Ctrl_C
#ifdef UNIX
         || c == intr_char
#endif
         )
        && firstc != '@'
        && !break_ctrl_c
        && !global_busy)
      got_int = FALSE;

    /* free old command line when finished moving around in the history
     * list */
    if (lookfor != NULL
        && c != K_S_DOWN && c != K_S_UP
        && c != K_DOWN && c != K_UP
        && c != K_PAGEDOWN && c != K_PAGEUP
        && c != K_KPAGEDOWN && c != K_KPAGEUP
        && c != K_LEFT && c != K_RIGHT
        && (xpc.xp_numfiles > 0 || (c != Ctrl_P && c != Ctrl_N))) {
      vim_free(lookfor);
      lookfor = NULL;
    }

    /*
     * When there are matching completions to select <S-Tab> works like
     * CTRL-P (unless 'wc' is <S-Tab>).
     */
    if (c != p_wc && c == K_S_TAB && xpc.xp_numfiles > 0)
      c = Ctrl_P;

    /* Special translations for 'wildmenu' */
    if (did_wild_list && p_wmnu) {
      if (c == K_LEFT)
        c = Ctrl_P;
      else if (c == K_RIGHT)
        c = Ctrl_N;
    }
    /* Hitting CR after "emenu Name.": complete submenu */
    if (xpc.xp_context == EXPAND_MENUNAMES && p_wmnu
        && ccline.cmdpos > 1
        && ccline.cmdbuff[ccline.cmdpos - 1] == '.'
        && ccline.cmdbuff[ccline.cmdpos - 2] != '\\'
        && (c == '\n' || c == '\r' || c == K_KENTER))
      c = K_DOWN;

    /* free expanded names when finished walking through matches */
    if (xpc.xp_numfiles != -1
        && !(c == p_wc && KeyTyped) && c != p_wcm
        && c != Ctrl_N && c != Ctrl_P && c != Ctrl_A
        && c != Ctrl_L) {
      (void)ExpandOne(&xpc, NULL, NULL, 0, WILD_FREE);
      did_wild_list = FALSE;
      if (!p_wmnu || (c != K_UP && c != K_DOWN))
        xpc.xp_context = EXPAND_NOTHING;
      wim_index = 0;
      if (p_wmnu && wild_menu_showing != 0) {
        int skt = KeyTyped;
        int old_RedrawingDisabled = RedrawingDisabled;

        if (ccline.input_fn)
          RedrawingDisabled = 0;

        if (wild_menu_showing == WM_SCROLLED) {
          /* Entered command line, move it up */
          cmdline_row--;
          redrawcmd();
        } else if (save_p_ls != -1)   {
          /* restore 'laststatus' and 'winminheight' */
          p_ls = save_p_ls;
          p_wmh = save_p_wmh;
          last_status(FALSE);
          save_cmdline(&save_ccline);
          update_screen(VALID);                 /* redraw the screen NOW */
          restore_cmdline(&save_ccline);
          redrawcmd();
          save_p_ls = -1;
        } else   {
          win_redraw_last_status(topframe);
          redraw_statuslines();
        }
        KeyTyped = skt;
        wild_menu_showing = 0;
        if (ccline.input_fn)
          RedrawingDisabled = old_RedrawingDisabled;
      }
    }

    /* Special translations for 'wildmenu' */
    if (xpc.xp_context == EXPAND_MENUNAMES && p_wmnu) {
      /* Hitting <Down> after "emenu Name.": complete submenu */
      if (c == K_DOWN && ccline.cmdpos > 0
          && ccline.cmdbuff[ccline.cmdpos - 1] == '.')
        c = p_wc;
      else if (c == K_UP) {
        /* Hitting <Up>: Remove one submenu name in front of the
         * cursor */
        int found = FALSE;

        j = (int)(xpc.xp_pattern - ccline.cmdbuff);
        i = 0;
        while (--j > 0) {
          /* check for start of menu name */
          if (ccline.cmdbuff[j] == ' '
              && ccline.cmdbuff[j - 1] != '\\') {
            i = j + 1;
            break;
          }
          /* check for start of submenu name */
          if (ccline.cmdbuff[j] == '.'
              && ccline.cmdbuff[j - 1] != '\\') {
            if (found) {
              i = j + 1;
              break;
            } else
              found = TRUE;
          }
        }
        if (i > 0)
          cmdline_del(i);
        c = p_wc;
        xpc.xp_context = EXPAND_NOTHING;
      }
    }
    if ((xpc.xp_context == EXPAND_FILES
         || xpc.xp_context == EXPAND_DIRECTORIES
         || xpc.xp_context == EXPAND_SHELLCMD) && p_wmnu) {
      char_u upseg[5];

      upseg[0] = PATHSEP;
      upseg[1] = '.';
      upseg[2] = '.';
      upseg[3] = PATHSEP;
      upseg[4] = NUL;

      if (c == K_DOWN
          && ccline.cmdpos > 0
          && ccline.cmdbuff[ccline.cmdpos - 1] == PATHSEP
          && (ccline.cmdpos < 3
              || ccline.cmdbuff[ccline.cmdpos - 2] != '.'
              || ccline.cmdbuff[ccline.cmdpos - 3] != '.')) {
        /* go down a directory */
        c = p_wc;
      } else if (STRNCMP(xpc.xp_pattern, upseg + 1, 3) == 0 && c == K_DOWN)   {
        /* If in a direct ancestor, strip off one ../ to go down */
        int found = FALSE;

        j = ccline.cmdpos;
        i = (int)(xpc.xp_pattern - ccline.cmdbuff);
        while (--j > i) {
          if (has_mbyte)
            j -= (*mb_head_off)(ccline.cmdbuff, ccline.cmdbuff + j);
          if (vim_ispathsep(ccline.cmdbuff[j])) {
            found = TRUE;
            break;
          }
        }
        if (found
            && ccline.cmdbuff[j - 1] == '.'
            && ccline.cmdbuff[j - 2] == '.'
            && (vim_ispathsep(ccline.cmdbuff[j - 3]) || j == i + 2)) {
          cmdline_del(j - 2);
          c = p_wc;
        }
      } else if (c == K_UP)   {
        /* go up a directory */
        int found = FALSE;

        j = ccline.cmdpos - 1;
        i = (int)(xpc.xp_pattern - ccline.cmdbuff);
        while (--j > i) {
          if (has_mbyte)
            j -= (*mb_head_off)(ccline.cmdbuff, ccline.cmdbuff + j);
          if (vim_ispathsep(ccline.cmdbuff[j])
#ifdef BACKSLASH_IN_FILENAME
              && vim_strchr(" *?[{`$%#", ccline.cmdbuff[j + 1])
              == NULL
#endif
              ) {
            if (found) {
              i = j + 1;
              break;
            } else
              found = TRUE;
          }
        }

        if (!found)
          j = i;
        else if (STRNCMP(ccline.cmdbuff + j, upseg, 4) == 0)
          j += 4;
        else if (STRNCMP(ccline.cmdbuff + j, upseg + 1, 3) == 0
                 && j == i)
          j += 3;
        else
          j = 0;
        if (j > 0) {
          /* TODO this is only for DOS/UNIX systems - need to put in
           * machine-specific stuff here and in upseg init */
          cmdline_del(j);
          put_on_cmdline(upseg + 1, 3, FALSE);
        } else if (ccline.cmdpos > i)
          cmdline_del(i);

        /* Now complete in the new directory. Set KeyTyped in case the
         * Up key came from a mapping. */
        c = p_wc;
        KeyTyped = TRUE;
      }
    }


    /* CTRL-\ CTRL-N goes to Normal mode, CTRL-\ CTRL-G goes to Insert
     * mode when 'insertmode' is set, CTRL-\ e prompts for an expression. */
    if (c == Ctrl_BSL) {
      ++no_mapping;
      ++allow_keys;
      c = plain_vgetc();
      --no_mapping;
      --allow_keys;
      /* CTRL-\ e doesn't work when obtaining an expression, unless it
       * is in a mapping. */
      if (c != Ctrl_N && c != Ctrl_G && (c != 'e'
                                         || (ccline.cmdfirstc == '=' &&
                                             KeyTyped))) {
        vungetc(c);
        c = Ctrl_BSL;
      } else if (c == 'e')   {
        char_u  *p = NULL;
        int len;

        /*
         * Replace the command line with the result of an expression.
         * Need to save and restore the current command line, to be
         * able to enter a new one...
         */
        if (ccline.cmdpos == ccline.cmdlen)
          new_cmdpos = 99999;           /* keep it at the end */
        else
          new_cmdpos = ccline.cmdpos;

        save_cmdline(&save_ccline);
        c = get_expr_register();
        restore_cmdline(&save_ccline);
        if (c == '=') {
          /* Need to save and restore ccline.  And set "textlock"
           * to avoid nasty things like going to another buffer when
           * evaluating an expression. */
          save_cmdline(&save_ccline);
          ++textlock;
          p = get_expr_line();
          --textlock;
          restore_cmdline(&save_ccline);

          if (p != NULL) {
            len = (int)STRLEN(p);
            if (realloc_cmdbuff(len + 1) == OK) {
              ccline.cmdlen = len;
              STRCPY(ccline.cmdbuff, p);
              vim_free(p);

              /* Restore the cursor or use the position set with
               * set_cmdline_pos(). */
              if (new_cmdpos > ccline.cmdlen)
                ccline.cmdpos = ccline.cmdlen;
              else
                ccline.cmdpos = new_cmdpos;

              KeyTyped = FALSE;                 /* Don't do p_wc completion. */
              redrawcmd();
              goto cmdline_changed;
            }
          }
        }
        beep_flush();
        got_int = FALSE;                /* don't abandon the command line */
        did_emsg = FALSE;
        emsg_on_display = FALSE;
        redrawcmd();
        goto cmdline_not_changed;
      } else   {
        if (c == Ctrl_G && p_im && restart_edit == 0)
          restart_edit = 'a';
        gotesc = TRUE;          /* will free ccline.cmdbuff after putting it
                                   in history */
        goto returncmd;         /* back to Normal mode */
      }
    }

    if (c == cedit_key || c == K_CMDWIN) {
      /*
       * Open a window to edit the command line (and history).
       */
      c = ex_window();
      some_key_typed = TRUE;
    } else
      c = do_digraph(c);

    if (c == '\n' || c == '\r' || c == K_KENTER || (c == ESC
                                                    && (!KeyTyped ||
                                                        vim_strchr(p_cpo,
                                                            CPO_ESC) !=
                                                        NULL))) {
      /* In Ex mode a backslash escapes a newline. */
      if (exmode_active
          && c != ESC
          && ccline.cmdpos == ccline.cmdlen
          && ccline.cmdpos > 0
          && ccline.cmdbuff[ccline.cmdpos - 1] == '\\') {
        if (c == K_KENTER)
          c = '\n';
      } else   {
        gotesc = FALSE;         /* Might have typed ESC previously, don't
                                       truncate the cmdline now. */
        if (ccheck_abbr(c + ABBR_OFF))
          goto cmdline_changed;
        if (!cmd_silent) {
          windgoto(msg_row, 0);
          out_flush();
        }
        break;
      }
    }

    /*
     * Completion for 'wildchar' or 'wildcharm' key.
     * - hitting <ESC> twice means: abandon command line.
     * - wildcard expansion is only done when the 'wildchar' key is really
     *   typed, not when it comes from a macro
     */
    if ((c == p_wc && !gotesc && KeyTyped) || c == p_wcm) {
      if (xpc.xp_numfiles > 0) {       /* typed p_wc at least twice */
        /* if 'wildmode' contains "list" may still need to list */
        if (xpc.xp_numfiles > 1
            && !did_wild_list
            && (wim_flags[wim_index] & WIM_LIST)) {
          (void)showmatches(&xpc, FALSE);
          redrawcmd();
          did_wild_list = TRUE;
        }
        if (wim_flags[wim_index] & WIM_LONGEST)
          res = nextwild(&xpc, WILD_LONGEST, WILD_NO_BEEP,
              firstc != '@');
        else if (wim_flags[wim_index] & WIM_FULL)
          res = nextwild(&xpc, WILD_NEXT, WILD_NO_BEEP,
              firstc != '@');
        else
          res = OK;                 /* don't insert 'wildchar' now */
      } else   {                    /* typed p_wc first time */
        wim_index = 0;
        j = ccline.cmdpos;
        /* if 'wildmode' first contains "longest", get longest
         * common part */
        if (wim_flags[0] & WIM_LONGEST)
          res = nextwild(&xpc, WILD_LONGEST, WILD_NO_BEEP,
              firstc != '@');
        else
          res = nextwild(&xpc, WILD_EXPAND_KEEP, WILD_NO_BEEP,
              firstc != '@');

        /* if interrupted while completing, behave like it failed */
        if (got_int) {
          (void)vpeekc();               /* remove <C-C> from input stream */
          got_int = FALSE;              /* don't abandon the command line */
          (void)ExpandOne(&xpc, NULL, NULL, 0, WILD_FREE);
          xpc.xp_context = EXPAND_NOTHING;
          goto cmdline_changed;
        }

        /* when more than one match, and 'wildmode' first contains
         * "list", or no change and 'wildmode' contains "longest,list",
         * list all matches */
        if (res == OK && xpc.xp_numfiles > 1) {
          /* a "longest" that didn't do anything is skipped (but not
           * "list:longest") */
          if (wim_flags[0] == WIM_LONGEST && ccline.cmdpos == j)
            wim_index = 1;
          if ((wim_flags[wim_index] & WIM_LIST)
              || (p_wmnu && (wim_flags[wim_index] & WIM_FULL) != 0)
              ) {
            if (!(wim_flags[0] & WIM_LONGEST)) {
              int p_wmnu_save = p_wmnu;
              p_wmnu = 0;
              /* remove match */
              nextwild(&xpc, WILD_PREV, 0, firstc != '@');
              p_wmnu = p_wmnu_save;
            }
            (void)showmatches(&xpc, p_wmnu
                && ((wim_flags[wim_index] & WIM_LIST) == 0));
            redrawcmd();
            did_wild_list = TRUE;
            if (wim_flags[wim_index] & WIM_LONGEST)
              nextwild(&xpc, WILD_LONGEST, WILD_NO_BEEP,
                  firstc != '@');
            else if (wim_flags[wim_index] & WIM_FULL)
              nextwild(&xpc, WILD_NEXT, WILD_NO_BEEP,
                  firstc != '@');
          } else
            vim_beep();
        } else if (xpc.xp_numfiles == -1)
          xpc.xp_context = EXPAND_NOTHING;
      }
      if (wim_index < 3)
        ++wim_index;
      if (c == ESC)
        gotesc = TRUE;
      if (res == OK)
        goto cmdline_changed;
    }

    gotesc = FALSE;

    /* <S-Tab> goes to last match, in a clumsy way */
    if (c == K_S_TAB && KeyTyped) {
      if (nextwild(&xpc, WILD_EXPAND_KEEP, 0, firstc != '@') == OK
          && nextwild(&xpc, WILD_PREV, 0, firstc != '@') == OK
          && nextwild(&xpc, WILD_PREV, 0, firstc != '@') == OK)
        goto cmdline_changed;
    }

    if (c == NUL || c == K_ZERO)            /* NUL is stored as NL */
      c = NL;

    do_abbr = TRUE;             /* default: check for abbreviation */

    /*
     * Big switch for a typed command line character.
     */
    switch (c) {
    case K_BS:
    case Ctrl_H:
    case K_DEL:
    case K_KDEL:
    case Ctrl_W:
      if (cmd_fkmap && c == K_BS)
        c = K_DEL;
      if (c == K_KDEL)
        c = K_DEL;

      /*
       * delete current character is the same as backspace on next
       * character, except at end of line
       */
      if (c == K_DEL && ccline.cmdpos != ccline.cmdlen)
        ++ccline.cmdpos;
      if (has_mbyte && c == K_DEL)
        ccline.cmdpos += mb_off_next(ccline.cmdbuff,
            ccline.cmdbuff + ccline.cmdpos);
      if (ccline.cmdpos > 0) {
        char_u *p;

        j = ccline.cmdpos;
        p = ccline.cmdbuff + j;
        if (has_mbyte) {
          p = mb_prevptr(ccline.cmdbuff, p);
          if (c == Ctrl_W) {
            while (p > ccline.cmdbuff && vim_isspace(*p))
              p = mb_prevptr(ccline.cmdbuff, p);
            i = mb_get_class(p);
            while (p > ccline.cmdbuff && mb_get_class(p) == i)
              p = mb_prevptr(ccline.cmdbuff, p);
            if (mb_get_class(p) != i)
              p += (*mb_ptr2len)(p);
          }
        } else if (c == Ctrl_W)    {
          while (p > ccline.cmdbuff && vim_isspace(p[-1]))
            --p;
          i = vim_iswordc(p[-1]);
          while (p > ccline.cmdbuff && !vim_isspace(p[-1])
                 && vim_iswordc(p[-1]) == i)
            --p;
        } else
          --p;
        ccline.cmdpos = (int)(p - ccline.cmdbuff);
        ccline.cmdlen -= j - ccline.cmdpos;
        i = ccline.cmdpos;
        while (i < ccline.cmdlen)
          ccline.cmdbuff[i++] = ccline.cmdbuff[j++];

        /* Truncate at the end, required for multi-byte chars. */
        ccline.cmdbuff[ccline.cmdlen] = NUL;
        redrawcmd();
      } else if (ccline.cmdlen == 0 && c != Ctrl_W
                 && ccline.cmdprompt == NULL && indent == 0) {
        /* In ex and debug mode it doesn't make sense to return. */
        if (exmode_active
            || ccline.cmdfirstc == '>'
            )
          goto cmdline_not_changed;

        vim_free(ccline.cmdbuff);               /* no commandline to return */
        ccline.cmdbuff = NULL;
        if (!cmd_silent) {
          if (cmdmsg_rl)
            msg_col = Columns;
          else
            msg_col = 0;
          msg_putchar(' ');                             /* delete ':' */
        }
        redraw_cmdline = TRUE;
        goto returncmd;                         /* back to cmd mode */
      }
      goto cmdline_changed;

    case K_INS:
    case K_KINS:
      /* if Farsi mode set, we are in reverse insert mode -
         Do not change the mode */
      if (cmd_fkmap)
        beep_flush();
      else
        ccline.overstrike = !ccline.overstrike;
#ifdef CURSOR_SHAPE
      ui_cursor_shape();                /* may show different cursor shape */
#endif
      goto cmdline_not_changed;

    case Ctrl_HAT:
      if (map_to_exists_mode((char_u *)"", LANGMAP, FALSE)) {
        /* ":lmap" mappings exists, toggle use of mappings. */
        State ^= LANGMAP;
#ifdef USE_IM_CONTROL
        im_set_active(FALSE);                   /* Disable input method */
#endif
        if (b_im_ptr != NULL) {
          if (State & LANGMAP)
            *b_im_ptr = B_IMODE_LMAP;
          else
            *b_im_ptr = B_IMODE_NONE;
        }
      }
#ifdef USE_IM_CONTROL
      else {
        /* There are no ":lmap" mappings, toggle IM.  When
         * 'imdisable' is set don't try getting the status, it's
         * always off. */
        if ((p_imdisable && b_im_ptr != NULL)
            ? *b_im_ptr == B_IMODE_IM : im_get_status()) {
          im_set_active(FALSE);                 /* Disable input method */
          if (b_im_ptr != NULL)
            *b_im_ptr = B_IMODE_NONE;
        } else   {
          im_set_active(TRUE);                  /* Enable input method */
          if (b_im_ptr != NULL)
            *b_im_ptr = B_IMODE_IM;
        }
      }
#endif
      if (b_im_ptr != NULL) {
        if (b_im_ptr == &curbuf->b_p_iminsert)
          set_iminsert_global();
        else
          set_imsearch_global();
      }
#ifdef CURSOR_SHAPE
      ui_cursor_shape();                /* may show different cursor shape */
#endif
      /* Show/unshow value of 'keymap' in status lines later. */
      status_redraw_curbuf();
      goto cmdline_not_changed;

    /*	case '@':   only in very old vi */
    case Ctrl_U:
      /* delete all characters left of the cursor */
      j = ccline.cmdpos;
      ccline.cmdlen -= j;
      i = ccline.cmdpos = 0;
      while (i < ccline.cmdlen)
        ccline.cmdbuff[i++] = ccline.cmdbuff[j++];
      /* Truncate at the end, required for multi-byte chars. */
      ccline.cmdbuff[ccline.cmdlen] = NUL;
      redrawcmd();
      goto cmdline_changed;


    case ESC:           /* get here if p_wc != ESC or when ESC typed twice */
    case Ctrl_C:
      /* In exmode it doesn't make sense to return.  Except when
       * ":normal" runs out of characters. */
      if (exmode_active
          && (ex_normal_busy == 0 || typebuf.tb_len > 0)
          )
        goto cmdline_not_changed;

      gotesc = TRUE;                    /* will free ccline.cmdbuff after
                                           putting it in history */
      goto returncmd;                   /* back to cmd mode */

    case Ctrl_R:                        /* insert register */
#ifdef USE_ON_FLY_SCROLL
      dont_scroll = TRUE;               /* disallow scrolling here */
#endif
      putcmdline('"', TRUE);
      ++no_mapping;
      i = c = plain_vgetc();            /* CTRL-R <char> */
      if (i == Ctrl_O)
        i = Ctrl_R;                     /* CTRL-R CTRL-O == CTRL-R CTRL-R */
      if (i == Ctrl_R)
        c = plain_vgetc();              /* CTRL-R CTRL-R <char> */
      --no_mapping;
      /*
       * Insert the result of an expression.
       * Need to save the current command line, to be able to enter
       * a new one...
       */
      new_cmdpos = -1;
      if (c == '=') {
        if (ccline.cmdfirstc == '=') {          /* can't do this recursively */
          beep_flush();
          c = ESC;
        } else   {
          save_cmdline(&save_ccline);
          c = get_expr_register();
          restore_cmdline(&save_ccline);
        }
      }
      if (c != ESC) {               /* use ESC to cancel inserting register */
        cmdline_paste(c, i == Ctrl_R, FALSE);

        /* When there was a serious error abort getting the
         * command line. */
        if (aborting()) {
          gotesc = TRUE;                /* will free ccline.cmdbuff after
                                           putting it in history */
          goto returncmd;               /* back to cmd mode */
        }
        KeyTyped = FALSE;               /* Don't do p_wc completion. */
        if (new_cmdpos >= 0) {
          /* set_cmdline_pos() was used */
          if (new_cmdpos > ccline.cmdlen)
            ccline.cmdpos = ccline.cmdlen;
          else
            ccline.cmdpos = new_cmdpos;
        }
      }
      redrawcmd();
      goto cmdline_changed;

    case Ctrl_D:
      if (showmatches(&xpc, FALSE) == EXPAND_NOTHING)
        break;                  /* Use ^D as normal char instead */

      redrawcmd();
      continue;                 /* don't do incremental search now */

    case K_RIGHT:
    case K_S_RIGHT:
    case K_C_RIGHT:
      do {
        if (ccline.cmdpos >= ccline.cmdlen)
          break;
        i = cmdline_charsize(ccline.cmdpos);
        if (KeyTyped && ccline.cmdspos + i >= Columns * Rows)
          break;
        ccline.cmdspos += i;
        if (has_mbyte)
          ccline.cmdpos += (*mb_ptr2len)(ccline.cmdbuff
                                         + ccline.cmdpos);
        else
          ++ccline.cmdpos;
      } while ((c == K_S_RIGHT || c == K_C_RIGHT
                || (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)))
               && ccline.cmdbuff[ccline.cmdpos] != ' ');
      if (has_mbyte)
        set_cmdspos_cursor();
      goto cmdline_not_changed;

    case K_LEFT:
    case K_S_LEFT:
    case K_C_LEFT:
      if (ccline.cmdpos == 0)
        goto cmdline_not_changed;
      do {
        --ccline.cmdpos;
        if (has_mbyte)                  /* move to first byte of char */
          ccline.cmdpos -= (*mb_head_off)(ccline.cmdbuff,
                                          ccline.cmdbuff + ccline.cmdpos);
        ccline.cmdspos -= cmdline_charsize(ccline.cmdpos);
      } while (ccline.cmdpos > 0
               && (c == K_S_LEFT || c == K_C_LEFT
                   || (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)))
               && ccline.cmdbuff[ccline.cmdpos - 1] != ' ');
      if (has_mbyte)
        set_cmdspos_cursor();
      goto cmdline_not_changed;

    case K_IGNORE:
      /* Ignore mouse event or ex_window() result. */
      goto cmdline_not_changed;


    case K_MIDDLEDRAG:
    case K_MIDDLERELEASE:
      goto cmdline_not_changed;                 /* Ignore mouse */

    case K_MIDDLEMOUSE:
      if (!mouse_has(MOUSE_COMMAND))
        goto cmdline_not_changed;                   /* Ignore mouse */
      cmdline_paste(0, TRUE, TRUE);
      redrawcmd();
      goto cmdline_changed;


    case K_LEFTDRAG:
    case K_LEFTRELEASE:
    case K_RIGHTDRAG:
    case K_RIGHTRELEASE:
      /* Ignore drag and release events when the button-down wasn't
       * seen before. */
      if (ignore_drag_release)
        goto cmdline_not_changed;
    /* FALLTHROUGH */
    case K_LEFTMOUSE:
    case K_RIGHTMOUSE:
      if (c == K_LEFTRELEASE || c == K_RIGHTRELEASE)
        ignore_drag_release = TRUE;
      else
        ignore_drag_release = FALSE;
      if (!mouse_has(MOUSE_COMMAND))
        goto cmdline_not_changed;                   /* Ignore mouse */

      set_cmdspos();
      for (ccline.cmdpos = 0; ccline.cmdpos < ccline.cmdlen;
           ++ccline.cmdpos) {
        i = cmdline_charsize(ccline.cmdpos);
        if (mouse_row <= cmdline_row + ccline.cmdspos / Columns
            && mouse_col < ccline.cmdspos % Columns + i)
          break;
        if (has_mbyte) {
          /* Count ">" for double-wide char that doesn't fit. */
          correct_cmdspos(ccline.cmdpos, i);
          ccline.cmdpos += (*mb_ptr2len)(ccline.cmdbuff
                                         + ccline.cmdpos) - 1;
        }
        ccline.cmdspos += i;
      }
      goto cmdline_not_changed;

    /* Mouse scroll wheel: ignored here */
    case K_MOUSEDOWN:
    case K_MOUSEUP:
    case K_MOUSELEFT:
    case K_MOUSERIGHT:
    /* Alternate buttons ignored here */
    case K_X1MOUSE:
    case K_X1DRAG:
    case K_X1RELEASE:
    case K_X2MOUSE:
    case K_X2DRAG:
    case K_X2RELEASE:
      goto cmdline_not_changed;



    case K_SELECT:          /* end of Select mode mapping - ignore */
      goto cmdline_not_changed;

    case Ctrl_B:            /* begin of command line */
    case K_HOME:
    case K_KHOME:
    case K_S_HOME:
    case K_C_HOME:
      ccline.cmdpos = 0;
      set_cmdspos();
      goto cmdline_not_changed;

    case Ctrl_E:            /* end of command line */
    case K_END:
    case K_KEND:
    case K_S_END:
    case K_C_END:
      ccline.cmdpos = ccline.cmdlen;
      set_cmdspos_cursor();
      goto cmdline_not_changed;

    case Ctrl_A:            /* all matches */
      if (nextwild(&xpc, WILD_ALL, 0, firstc != '@') == FAIL)
        break;
      goto cmdline_changed;

    case Ctrl_L:
      if (p_is && !cmd_silent && (firstc == '/' || firstc == '?')) {
        /* Add a character from under the cursor for 'incsearch' */
        if (did_incsearch
            && !equalpos(curwin->w_cursor, old_cursor)) {
          c = gchar_cursor();
          /* If 'ignorecase' and 'smartcase' are set and the
           * command line has no uppercase characters, convert
           * the character to lowercase */
          if (p_ic && p_scs && !pat_has_uppercase(ccline.cmdbuff))
            c = MB_TOLOWER(c);
          if (c != NUL) {
            if (c == firstc || vim_strchr((char_u *)(
                      p_magic ? "\\^$.*[" : "\\^$"), c)
                != NULL) {
              /* put a backslash before special characters */
              stuffcharReadbuff(c);
              c = '\\';
            }
            break;
          }
        }
        goto cmdline_not_changed;
      }

      /* completion: longest common part */
      if (nextwild(&xpc, WILD_LONGEST, 0, firstc != '@') == FAIL)
        break;
      goto cmdline_changed;

    case Ctrl_N:            /* next match */
    case Ctrl_P:            /* previous match */
      if (xpc.xp_numfiles > 0) {
        if (nextwild(&xpc, (c == Ctrl_P) ? WILD_PREV : WILD_NEXT,
                0, firstc != '@') == FAIL)
          break;
        goto cmdline_changed;
      }

    case K_UP:
    case K_DOWN:
    case K_S_UP:
    case K_S_DOWN:
    case K_PAGEUP:
    case K_KPAGEUP:
    case K_PAGEDOWN:
    case K_KPAGEDOWN:
      if (hislen == 0 || firstc == NUL)                 /* no history */
        goto cmdline_not_changed;

      i = hiscnt;

      /* save current command string so it can be restored later */
      if (lookfor == NULL) {
        if ((lookfor = vim_strsave(ccline.cmdbuff)) == NULL)
          goto cmdline_not_changed;
        lookfor[ccline.cmdpos] = NUL;
      }

      j = (int)STRLEN(lookfor);
      for (;; ) {
        /* one step backwards */
        if (c == K_UP|| c == K_S_UP || c == Ctrl_P
            || c == K_PAGEUP || c == K_KPAGEUP) {
          if (hiscnt == hislen)                 /* first time */
            hiscnt = hisidx[histype];
          else if (hiscnt == 0 && hisidx[histype] != hislen - 1)
            hiscnt = hislen - 1;
          else if (hiscnt != hisidx[histype] + 1)
            --hiscnt;
          else {                                /* at top of list */
            hiscnt = i;
            break;
          }
        } else   {          /* one step forwards */
          /* on last entry, clear the line */
          if (hiscnt == hisidx[histype]) {
            hiscnt = hislen;
            break;
          }

          /* not on a history line, nothing to do */
          if (hiscnt == hislen)
            break;
          if (hiscnt == hislen - 1)                 /* wrap around */
            hiscnt = 0;
          else
            ++hiscnt;
        }
        if (hiscnt < 0 || history[histype][hiscnt].hisstr == NULL) {
          hiscnt = i;
          break;
        }
        if ((c != K_UP && c != K_DOWN)
            || hiscnt == i
            || STRNCMP(history[histype][hiscnt].hisstr,
                lookfor, (size_t)j) == 0)
          break;
      }

      if (hiscnt != i) {                /* jumped to other entry */
        char_u      *p;
        int len;
        int old_firstc;

        vim_free(ccline.cmdbuff);
        xpc.xp_context = EXPAND_NOTHING;
        if (hiscnt == hislen)
          p = lookfor;                  /* back to the old one */
        else
          p = history[histype][hiscnt].hisstr;

        if (histype == HIST_SEARCH
            && p != lookfor
            && (old_firstc = p[STRLEN(p) + 1]) != firstc) {
          /* Correct for the separator character used when
           * adding the history entry vs the one used now.
           * First loop: count length.
           * Second loop: copy the characters. */
          for (i = 0; i <= 1; ++i) {
            len = 0;
            for (j = 0; p[j] != NUL; ++j) {
              /* Replace old sep with new sep, unless it is
               * escaped. */
              if (p[j] == old_firstc
                  && (j == 0 || p[j - 1] != '\\')) {
                if (i > 0)
                  ccline.cmdbuff[len] = firstc;
              } else   {
                /* Escape new sep, unless it is already
                 * escaped. */
                if (p[j] == firstc
                    && (j == 0 || p[j - 1] != '\\')) {
                  if (i > 0)
                    ccline.cmdbuff[len] = '\\';
                  ++len;
                }
                if (i > 0)
                  ccline.cmdbuff[len] = p[j];
              }
              ++len;
            }
            if (i == 0) {
              alloc_cmdbuff(len);
              if (ccline.cmdbuff == NULL)
                goto returncmd;
            }
          }
          ccline.cmdbuff[len] = NUL;
        } else   {
          alloc_cmdbuff((int)STRLEN(p));
          if (ccline.cmdbuff == NULL)
            goto returncmd;
          STRCPY(ccline.cmdbuff, p);
        }

        ccline.cmdpos = ccline.cmdlen = (int)STRLEN(ccline.cmdbuff);
        redrawcmd();
        goto cmdline_changed;
      }
      beep_flush();
      goto cmdline_not_changed;

    case Ctrl_V:
    case Ctrl_Q:
      ignore_drag_release = TRUE;
      putcmdline('^', TRUE);
      c = get_literal();                    /* get next (two) character(s) */
      do_abbr = FALSE;                      /* don't do abbreviation now */
      /* may need to remove ^ when composing char was typed */
      if (enc_utf8 && utf_iscomposing(c) && !cmd_silent) {
        draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
        msg_putchar(' ');
        cursorcmd();
      }
      break;

    case Ctrl_K:
      ignore_drag_release = TRUE;
      putcmdline('?', TRUE);
#ifdef USE_ON_FLY_SCROLL
      dont_scroll = TRUE;                   /* disallow scrolling here */
#endif
      c = get_digraph(TRUE);
      if (c != NUL)
        break;

      redrawcmd();
      goto cmdline_not_changed;

    case Ctrl__:            /* CTRL-_: switch language mode */
      if (!p_ari)
        break;
      if (p_altkeymap) {
        cmd_fkmap = !cmd_fkmap;
        if (cmd_fkmap)                  /* in Farsi always in Insert mode */
          ccline.overstrike = FALSE;
      } else                                /* Hebrew is default */
        cmd_hkmap = !cmd_hkmap;
      goto cmdline_not_changed;

    default:
#ifdef UNIX
      if (c == intr_char) {
        gotesc = TRUE;                  /* will free ccline.cmdbuff after
                                           putting it in history */
        goto returncmd;                 /* back to Normal mode */
      }
#endif
      /*
       * Normal character with no special meaning.  Just set mod_mask
       * to 0x0 so that typing Shift-Space in the GUI doesn't enter
       * the string <S-Space>.  This should only happen after ^V.
       */
      if (!IS_SPECIAL(c))
        mod_mask = 0x0;
      break;
    }
    /*
     * End of switch on command line character.
     * We come here if we have a normal character.
     */

    if (do_abbr && (IS_SPECIAL(c) || !vim_iswordc(c)) && (ccheck_abbr(
                                                              /* Add ABBR_OFF for characters above 0x100, this is
                                                               * what check_abbr() expects. */
                                                              (has_mbyte &&
                                                               c >=
                                                               0x100) ? (c +
                                                                         ABBR_OFF) :
                                                              c) || c ==
                                                          Ctrl_RSB))
      goto cmdline_changed;

    /*
     * put the character in the command line
     */
    if (IS_SPECIAL(c) || mod_mask != 0)
      put_on_cmdline(get_special_key_name(c, mod_mask), -1, TRUE);
    else {
      if (has_mbyte) {
        j = (*mb_char2bytes)(c, IObuff);
        IObuff[j] = NUL;                /* exclude composing chars */
        put_on_cmdline(IObuff, j, TRUE);
      } else   {
        IObuff[0] = c;
        put_on_cmdline(IObuff, 1, TRUE);
      }
    }
    goto cmdline_changed;

    /*
     * This part implements incremental searches for "/" and "?"
     * Jump to cmdline_not_changed when a character has been read but the command
     * line did not change. Then we only search and redraw if something changed in
     * the past.
     * Jump to cmdline_changed when the command line did change.
     * (Sorry for the goto's, I know it is ugly).
     */
cmdline_not_changed:
    if (!incsearch_postponed)
      continue;

cmdline_changed:
    /*
     * 'incsearch' highlighting.
     */
    if (p_is && !cmd_silent && (firstc == '/' || firstc == '?')) {
      pos_T end_pos;
      proftime_T tm;

      /* if there is a character waiting, search and redraw later */
      if (char_avail()) {
        incsearch_postponed = TRUE;
        continue;
      }
      incsearch_postponed = FALSE;
      curwin->w_cursor = old_cursor;        /* start at old position */

      /* If there is no command line, don't do anything */
      if (ccline.cmdlen == 0)
        i = 0;
      else {
        cursor_off();                   /* so the user knows we're busy */
        out_flush();
        ++emsg_off;            /* So it doesn't beep if bad expr */
        /* Set the time limit to half a second. */
        profile_setlimit(500L, &tm);
        i = do_search(NULL, firstc, ccline.cmdbuff, count,
            SEARCH_KEEP + SEARCH_OPT + SEARCH_NOOF + SEARCH_PEEK,
            &tm
            );
        --emsg_off;
        /* if interrupted while searching, behave like it failed */
        if (got_int) {
          (void)vpeekc();               /* remove <C-C> from input stream */
          got_int = FALSE;              /* don't abandon the command line */
          i = 0;
        } else if (char_avail())
          /* cancelled searching because a char was typed */
          incsearch_postponed = TRUE;
      }
      if (i != 0)
        highlight_match = TRUE;                 /* highlight position */
      else
        highlight_match = FALSE;                /* remove highlight */

      /* first restore the old curwin values, so the screen is
       * positioned in the same way as the actual search command */
      curwin->w_leftcol = old_leftcol;
      curwin->w_topline = old_topline;
      curwin->w_topfill = old_topfill;
      curwin->w_botline = old_botline;
      changed_cline_bef_curs();
      update_topline();

      if (i != 0) {
        pos_T save_pos = curwin->w_cursor;

        /*
         * First move cursor to end of match, then to the start.  This
         * moves the whole match onto the screen when 'nowrap' is set.
         */
        curwin->w_cursor.lnum += search_match_lines;
        curwin->w_cursor.col = search_match_endcol;
        if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
          curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
          coladvance((colnr_T)MAXCOL);
        }
        validate_cursor();
        end_pos = curwin->w_cursor;
        curwin->w_cursor = save_pos;
      } else
        end_pos = curwin->w_cursor;         /* shutup gcc 4 */

      validate_cursor();
      /* May redraw the status line to show the cursor position. */
      if (p_ru && curwin->w_status_height > 0)
        curwin->w_redr_status = TRUE;

      save_cmdline(&save_ccline);
      update_screen(SOME_VALID);
      restore_cmdline(&save_ccline);

      /* Leave it at the end to make CTRL-R CTRL-W work. */
      if (i != 0)
        curwin->w_cursor = end_pos;

      msg_starthere();
      redrawcmdline();
      did_incsearch = TRUE;
    }

    if (cmdmsg_rl
        || (p_arshape && !p_tbidi && enc_utf8)
        )
      /* Always redraw the whole command line to fix shaping and
       * right-left typing.  Not efficient, but it works.
       * Do it only when there are no characters left to read
       * to avoid useless intermediate redraws. */
      if (vpeekc() == NUL)
        redrawcmd();
  }

returncmd:

  cmdmsg_rl = FALSE;

  cmd_fkmap = 0;

  ExpandCleanup(&xpc);
  ccline.xpc = NULL;

  if (did_incsearch) {
    curwin->w_cursor = old_cursor;
    curwin->w_curswant = old_curswant;
    curwin->w_leftcol = old_leftcol;
    curwin->w_topline = old_topline;
    curwin->w_topfill = old_topfill;
    curwin->w_botline = old_botline;
    highlight_match = FALSE;
    validate_cursor();          /* needed for TAB */
    redraw_later(SOME_VALID);
  }

  if (ccline.cmdbuff != NULL) {
    /*
     * Put line in history buffer (":" and "=" only when it was typed).
     */
    if (ccline.cmdlen && firstc != NUL
        && (some_key_typed || histype == HIST_SEARCH)) {
      add_to_history(histype, ccline.cmdbuff, TRUE,
          histype == HIST_SEARCH ? firstc : NUL);
      if (firstc == ':') {
        vim_free(new_last_cmdline);
        new_last_cmdline = vim_strsave(ccline.cmdbuff);
      }
    }

    if (gotesc) {           /* abandon command line */
      vim_free(ccline.cmdbuff);
      ccline.cmdbuff = NULL;
      if (msg_scrolled == 0)
        compute_cmdrow();
      MSG("");
      redraw_cmdline = TRUE;
    }
  }

  /*
   * If the screen was shifted up, redraw the whole screen (later).
   * If the line is too long, clear it, so ruler and shown command do
   * not get printed in the middle of it.
   */
  msg_check();
  msg_scroll = save_msg_scroll;
  redir_off = FALSE;

  /* When the command line was typed, no need for a wait-return prompt. */
  if (some_key_typed)
    need_wait_return = FALSE;

  State = save_State;
#ifdef USE_IM_CONTROL
  if (b_im_ptr != NULL && *b_im_ptr != B_IMODE_LMAP)
    im_save_status(b_im_ptr);
  im_set_active(FALSE);
#endif
  setmouse();
#ifdef CURSOR_SHAPE
  ui_cursor_shape();            /* may show different cursor shape */
#endif

  {
    char_u *p = ccline.cmdbuff;

    /* Make ccline empty, getcmdline() may try to use it. */
    ccline.cmdbuff = NULL;
    return p;
  }
}

/*
 * Get a command line with a prompt.
 * This is prepared to be called recursively from getcmdline() (e.g. by
 * f_input() when evaluating an expression from CTRL-R =).
 * Returns the command line in allocated memory, or NULL.
 */
char_u *
getcmdline_prompt (
    int firstc,
    char_u *prompt,            /* command line prompt */
    int attr,                       /* attributes for prompt */
    int xp_context,                 /* type of expansion */
    char_u *xp_arg            /* user-defined expansion argument */
)
{
  char_u              *s;
  struct cmdline_info save_ccline;
  int msg_col_save = msg_col;

  save_cmdline(&save_ccline);
  ccline.cmdprompt = prompt;
  ccline.cmdattr = attr;
  ccline.xp_context = xp_context;
  ccline.xp_arg = xp_arg;
  ccline.input_fn = (firstc == '@');
  s = getcmdline(firstc, 1L, 0);
  restore_cmdline(&save_ccline);
  /* Restore msg_col, the prompt from input() may have changed it.
   * But only if called recursively and the commandline is therefore being
   * restored to an old one; if not, the input() prompt stays on the screen,
   * so we need its modified msg_col left intact. */
  if (ccline.cmdbuff != NULL)
    msg_col = msg_col_save;

  return s;
}

/*
 * Return TRUE when the text must not be changed and we can't switch to
 * another window or buffer.  Used when editing the command line, evaluating
 * 'balloonexpr', etc.
 */
int text_locked(void)         {
  if (cmdwin_type != 0)
    return TRUE;
  return textlock != 0;
}

/*
 * Give an error message for a command that isn't allowed while the cmdline
 * window is open or editing the cmdline in another way.
 */
void text_locked_msg(void)          {
  if (cmdwin_type != 0)
    EMSG(_(e_cmdwin));
  else
    EMSG(_(e_secure));
}

/*
 * Check if "curbuf_lock" or "allbuf_lock" is set and return TRUE when it is
 * and give an error message.
 */
int curbuf_locked(void)         {
  if (curbuf_lock > 0) {
    EMSG(_("E788: Not allowed to edit another buffer now"));
    return TRUE;
  }
  return allbuf_locked();
}

/*
 * Check if "allbuf_lock" is set and return TRUE when it is and give an error
 * message.
 */
int allbuf_locked(void)         {
  if (allbuf_lock > 0) {
    EMSG(_("E811: Not allowed to change buffer information now"));
    return TRUE;
  }
  return FALSE;
}

static int cmdline_charsize(int idx)
{
  if (cmdline_star > 0)             /* showing '*', always 1 position */
    return 1;
  return ptr2cells(ccline.cmdbuff + idx);
}

/*
 * Compute the offset of the cursor on the command line for the prompt and
 * indent.
 */
static void set_cmdspos(void)                 {
  if (ccline.cmdfirstc != NUL)
    ccline.cmdspos = 1 + ccline.cmdindent;
  else
    ccline.cmdspos = 0 + ccline.cmdindent;
}

/*
 * Compute the screen position for the cursor on the command line.
 */
static void set_cmdspos_cursor(void)                 {
  int i, m, c;

  set_cmdspos();
  if (KeyTyped) {
    m = Columns * Rows;
    if (m < 0)          /* overflow, Columns or Rows at weird value */
      m = MAXCOL;
  } else
    m = MAXCOL;
  for (i = 0; i < ccline.cmdlen && i < ccline.cmdpos; ++i) {
    c = cmdline_charsize(i);
    /* Count ">" for double-wide multi-byte char that doesn't fit. */
    if (has_mbyte)
      correct_cmdspos(i, c);
    /* If the cmdline doesn't fit, show cursor on last visible char.
     * Don't move the cursor itself, so we can still append. */
    if ((ccline.cmdspos += c) >= m) {
      ccline.cmdspos -= c;
      break;
    }
    if (has_mbyte)
      i += (*mb_ptr2len)(ccline.cmdbuff + i) - 1;
  }
}

/*
 * Check if the character at "idx", which is "cells" wide, is a multi-byte
 * character that doesn't fit, so that a ">" must be displayed.
 */
static void correct_cmdspos(int idx, int cells)
{
  if ((*mb_ptr2len)(ccline.cmdbuff + idx) > 1
      && (*mb_ptr2cells)(ccline.cmdbuff + idx) > 1
      && ccline.cmdspos % Columns + cells > Columns)
    ccline.cmdspos++;
}

/*
 * Get an Ex command line for the ":" command.
 */
char_u *
getexline (
    int c,                          /* normally ':', NUL for ":append" */
    void *cookie,
    int indent                     /* indent for inside conditionals */
)
{
  /* When executing a register, remove ':' that's in front of each line. */
  if (exec_from_reg && vpeekc() == ':')
    (void)vgetc();
  return getcmdline(c, 1L, indent);
}

/*
 * Get an Ex command line for Ex mode.
 * In Ex mode we only use the OS supplied line editing features and no
 * mappings or abbreviations.
 * Returns a string in allocated memory or NULL.
 */
char_u *
getexmodeline (
    int promptc,                    /* normally ':', NUL for ":append" and '?' for
                                   :s prompt */
    void *cookie,
    int indent                     /* indent for inside conditionals */
)
{
  garray_T line_ga;
  char_u      *pend;
  int startcol = 0;
  int c1 = 0;
  int escaped = FALSE;                  /* CTRL-V typed */
  int vcol = 0;
  char_u      *p;
  int prev_char;

  /* Switch cursor on now.  This avoids that it happens after the "\n", which
   * confuses the system function that computes tabstops. */
  cursor_on();

  /* always start in column 0; write a newline if necessary */
  compute_cmdrow();
  if ((msg_col || msg_didout) && promptc != '?')
    msg_putchar('\n');
  if (promptc == ':') {
    /* indent that is only displayed, not in the line itself */
    if (p_prompt)
      msg_putchar(':');
    while (indent-- > 0)
      msg_putchar(' ');
    startcol = msg_col;
  }

  ga_init2(&line_ga, 1, 30);

  /* autoindent for :insert and :append is in the line itself */
  if (promptc <= 0) {
    vcol = indent;
    while (indent >= 8) {
      ga_append(&line_ga, TAB);
      msg_puts((char_u *)"        ");
      indent -= 8;
    }
    while (indent-- > 0) {
      ga_append(&line_ga, ' ');
      msg_putchar(' ');
    }
  }
  ++no_mapping;
  ++allow_keys;

  /*
   * Get the line, one character at a time.
   */
  got_int = FALSE;
  while (!got_int) {
    if (ga_grow(&line_ga, 40) == FAIL)
      break;

    /* Get one character at a time.  Don't use inchar(), it can't handle
     * special characters. */
    prev_char = c1;
    c1 = vgetc();

    /*
     * Handle line editing.
     * Previously this was left to the system, putting the terminal in
     * cooked mode, but then CTRL-D and CTRL-T can't be used properly.
     */
    if (got_int) {
      msg_putchar('\n');
      break;
    }

    if (!escaped) {
      /* CR typed means "enter", which is NL */
      if (c1 == '\r')
        c1 = '\n';

      if (c1 == BS || c1 == K_BS
          || c1 == DEL || c1 == K_DEL || c1 == K_KDEL) {
        if (line_ga.ga_len > 0) {
          --line_ga.ga_len;
          goto redraw;
        }
        continue;
      }

      if (c1 == Ctrl_U) {
        msg_col = startcol;
        msg_clr_eos();
        line_ga.ga_len = 0;
        continue;
      }

      if (c1 == Ctrl_T) {
        long sw = get_sw_value(curbuf);

        p = (char_u *)line_ga.ga_data;
        p[line_ga.ga_len] = NUL;
        indent = get_indent_str(p, 8);
        indent += sw - indent % sw;
add_indent:
        while (get_indent_str(p, 8) < indent) {
          char_u *s = skipwhite(p);

          ga_grow(&line_ga, 1);
          mch_memmove(s + 1, s, line_ga.ga_len - (s - p) + 1);
          *s = ' ';
          ++line_ga.ga_len;
        }
redraw:
        /* redraw the line */
        msg_col = startcol;
        vcol = 0;
        for (p = (char_u *)line_ga.ga_data;
             p < (char_u *)line_ga.ga_data + line_ga.ga_len; ++p) {
          if (*p == TAB) {
            do {
              msg_putchar(' ');
            } while (++vcol % 8);
          } else   {
            msg_outtrans_len(p, 1);
            vcol += char2cells(*p);
          }
        }
        msg_clr_eos();
        windgoto(msg_row, msg_col);
        continue;
      }

      if (c1 == Ctrl_D) {
        /* Delete one shiftwidth. */
        p = (char_u *)line_ga.ga_data;
        if (prev_char == '0' || prev_char == '^') {
          if (prev_char == '^')
            ex_keep_indent = TRUE;
          indent = 0;
          p[--line_ga.ga_len] = NUL;
        } else   {
          p[line_ga.ga_len] = NUL;
          indent = get_indent_str(p, 8);
          --indent;
          indent -= indent % get_sw_value(curbuf);
        }
        while (get_indent_str(p, 8) > indent) {
          char_u *s = skipwhite(p);

          mch_memmove(s - 1, s, line_ga.ga_len - (s - p) + 1);
          --line_ga.ga_len;
        }
        goto add_indent;
      }

      if (c1 == Ctrl_V || c1 == Ctrl_Q) {
        escaped = TRUE;
        continue;
      }

      /* Ignore special key codes: mouse movement, K_IGNORE, etc. */
      if (IS_SPECIAL(c1))
        continue;
    }

    if (IS_SPECIAL(c1))
      c1 = '?';
    ((char_u *)line_ga.ga_data)[line_ga.ga_len] = c1;
    if (c1 == '\n')
      msg_putchar('\n');
    else if (c1 == TAB) {
      /* Don't use chartabsize(), 'ts' can be different */
      do {
        msg_putchar(' ');
      } while (++vcol % 8);
    } else   {
      msg_outtrans_len(
          ((char_u *)line_ga.ga_data) + line_ga.ga_len, 1);
      vcol += char2cells(c1);
    }
    ++line_ga.ga_len;
    escaped = FALSE;

    windgoto(msg_row, msg_col);
    pend = (char_u *)(line_ga.ga_data) + line_ga.ga_len;

    /* We are done when a NL is entered, but not when it comes after an
     * odd number of backslashes, that results in a NUL. */
    if (line_ga.ga_len > 0 && pend[-1] == '\n') {
      int bcount = 0;

      while (line_ga.ga_len - 2 >= bcount && pend[-2 - bcount] == '\\')
        ++bcount;

      if (bcount > 0) {
        /* Halve the number of backslashes: "\NL" -> "NUL", "\\NL" ->
         * "\NL", etc. */
        line_ga.ga_len -= (bcount + 1) / 2;
        pend -= (bcount + 1) / 2;
        pend[-1] = '\n';
      }

      if ((bcount & 1) == 0) {
        --line_ga.ga_len;
        --pend;
        *pend = NUL;
        break;
      }
    }
  }

  --no_mapping;
  --allow_keys;

  /* make following messages go to the next line */
  msg_didout = FALSE;
  msg_col = 0;
  if (msg_row < Rows - 1)
    ++msg_row;
  emsg_on_display = FALSE;              /* don't want ui_delay() */

  if (got_int)
    ga_clear(&line_ga);

  return (char_u *)line_ga.ga_data;
}

# if defined(MCH_CURSOR_SHAPE) || defined(FEAT_GUI) \
  || defined(FEAT_MOUSESHAPE) || defined(PROTO)
/*
 * Return TRUE if ccline.overstrike is on.
 */
int cmdline_overstrike(void)         {
  return ccline.overstrike;
}

/*
 * Return TRUE if the cursor is at the end of the cmdline.
 */
int cmdline_at_end(void)         {
  return ccline.cmdpos >= ccline.cmdlen;
}

#endif



/*
 * Allocate a new command line buffer.
 * Assigns the new buffer to ccline.cmdbuff and ccline.cmdbufflen.
 * Returns the new value of ccline.cmdbuff and ccline.cmdbufflen.
 */
static void alloc_cmdbuff(int len)
{
  /*
   * give some extra space to avoid having to allocate all the time
   */
  if (len < 80)
    len = 100;
  else
    len += 20;

  ccline.cmdbuff = alloc(len);      /* caller should check for out-of-memory */
  ccline.cmdbufflen = len;
}

/*
 * Re-allocate the command line to length len + something extra.
 * return FAIL for failure, OK otherwise
 */
static int realloc_cmdbuff(int len)
{
  char_u      *p;

  if (len < ccline.cmdbufflen)
    return OK;                          /* no need to resize */

  p = ccline.cmdbuff;
  alloc_cmdbuff(len);                   /* will get some more */
  if (ccline.cmdbuff == NULL) {         /* out of memory */
    ccline.cmdbuff = p;                 /* keep the old one */
    return FAIL;
  }
  /* There isn't always a NUL after the command, but it may need to be
   * there, thus copy up to the NUL and add a NUL. */
  mch_memmove(ccline.cmdbuff, p, (size_t)ccline.cmdlen);
  ccline.cmdbuff[ccline.cmdlen] = NUL;
  vim_free(p);

  if (ccline.xpc != NULL
      && ccline.xpc->xp_pattern != NULL
      && ccline.xpc->xp_context != EXPAND_NOTHING
      && ccline.xpc->xp_context != EXPAND_UNSUCCESSFUL) {
    int i = (int)(ccline.xpc->xp_pattern - p);

    /* If xp_pattern points inside the old cmdbuff it needs to be adjusted
     * to point into the newly allocated memory. */
    if (i >= 0 && i <= ccline.cmdlen)
      ccline.xpc->xp_pattern = ccline.cmdbuff + i;
  }

  return OK;
}

static char_u   *arshape_buf = NULL;

# if defined(EXITFREE) || defined(PROTO)
void free_cmdline_buf(void)          {
  vim_free(arshape_buf);
}

# endif

/*
 * Draw part of the cmdline at the current cursor position.  But draw stars
 * when cmdline_star is TRUE.
 */
static void draw_cmdline(int start, int len)
{
  int i;

  if (cmdline_star > 0)
    for (i = 0; i < len; ++i) {
      msg_putchar('*');
      if (has_mbyte)
        i += (*mb_ptr2len)(ccline.cmdbuff + start + i) - 1;
    }
  else if (p_arshape && !p_tbidi && enc_utf8 && len > 0)  {
    static int buflen = 0;
    char_u          *p;
    int j;
    int newlen = 0;
    int mb_l;
    int pc, pc1 = 0;
    int prev_c = 0;
    int prev_c1 = 0;
    int u8c;
    int u8cc[MAX_MCO];
    int nc = 0;

    /*
     * Do arabic shaping into a temporary buffer.  This is very
     * inefficient!
     */
    if (len * 2 + 2 > buflen) {
      /* Re-allocate the buffer.  We keep it around to avoid a lot of
       * alloc()/free() calls. */
      vim_free(arshape_buf);
      buflen = len * 2 + 2;
      arshape_buf = alloc(buflen);
      if (arshape_buf == NULL)
        return;         /* out of memory */
    }

    if (utf_iscomposing(utf_ptr2char(ccline.cmdbuff + start))) {
      /* Prepend a space to draw the leading composing char on. */
      arshape_buf[0] = ' ';
      newlen = 1;
    }

    for (j = start; j < start + len; j += mb_l) {
      p = ccline.cmdbuff + j;
      u8c = utfc_ptr2char_len(p, u8cc, start + len - j);
      mb_l = utfc_ptr2len_len(p, start + len - j);
      if (ARABIC_CHAR(u8c)) {
        /* Do Arabic shaping. */
        if (cmdmsg_rl) {
          /* displaying from right to left */
          pc = prev_c;
          pc1 = prev_c1;
          prev_c1 = u8cc[0];
          if (j + mb_l >= start + len)
            nc = NUL;
          else
            nc = utf_ptr2char(p + mb_l);
        } else   {
          /* displaying from left to right */
          if (j + mb_l >= start + len)
            pc = NUL;
          else {
            int pcc[MAX_MCO];

            pc = utfc_ptr2char_len(p + mb_l, pcc,
                start + len - j - mb_l);
            pc1 = pcc[0];
          }
          nc = prev_c;
        }
        prev_c = u8c;

        u8c = arabic_shape(u8c, NULL, &u8cc[0], pc, pc1, nc);

        newlen += (*mb_char2bytes)(u8c, arshape_buf + newlen);
        if (u8cc[0] != 0) {
          newlen += (*mb_char2bytes)(u8cc[0], arshape_buf + newlen);
          if (u8cc[1] != 0)
            newlen += (*mb_char2bytes)(u8cc[1],
                                       arshape_buf + newlen);
        }
      } else   {
        prev_c = u8c;
        mch_memmove(arshape_buf + newlen, p, mb_l);
        newlen += mb_l;
      }
    }

    msg_outtrans_len(arshape_buf, newlen);
  } else
    msg_outtrans_len(ccline.cmdbuff + start, len);
}

/*
 * Put a character on the command line.  Shifts the following text to the
 * right when "shift" is TRUE.  Used for CTRL-V, CTRL-K, etc.
 * "c" must be printable (fit in one display cell)!
 */
void putcmdline(int c, int shift)
{
  if (cmd_silent)
    return;
  msg_no_more = TRUE;
  msg_putchar(c);
  if (shift)
    draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
  msg_no_more = FALSE;
  cursorcmd();
}

/*
 * Undo a putcmdline(c, FALSE).
 */
void unputcmdline(void)          {
  if (cmd_silent)
    return;
  msg_no_more = TRUE;
  if (ccline.cmdlen == ccline.cmdpos)
    msg_putchar(' ');
  else if (has_mbyte)
    draw_cmdline(ccline.cmdpos,
        (*mb_ptr2len)(ccline.cmdbuff + ccline.cmdpos));
  else
    draw_cmdline(ccline.cmdpos, 1);
  msg_no_more = FALSE;
  cursorcmd();
}

/*
 * Put the given string, of the given length, onto the command line.
 * If len is -1, then STRLEN() is used to calculate the length.
 * If 'redraw' is TRUE then the new part of the command line, and the remaining
 * part will be redrawn, otherwise it will not.  If this function is called
 * twice in a row, then 'redraw' should be FALSE and redrawcmd() should be
 * called afterwards.
 */
int put_on_cmdline(char_u *str, int len, int redraw)
{
  int retval;
  int i;
  int m;
  int c;

  if (len < 0)
    len = (int)STRLEN(str);

  /* Check if ccline.cmdbuff needs to be longer */
  if (ccline.cmdlen + len + 1 >= ccline.cmdbufflen)
    retval = realloc_cmdbuff(ccline.cmdlen + len + 1);
  else
    retval = OK;
  if (retval == OK) {
    if (!ccline.overstrike) {
      mch_memmove(ccline.cmdbuff + ccline.cmdpos + len,
          ccline.cmdbuff + ccline.cmdpos,
          (size_t)(ccline.cmdlen - ccline.cmdpos));
      ccline.cmdlen += len;
    } else   {
      if (has_mbyte) {
        /* Count nr of characters in the new string. */
        m = 0;
        for (i = 0; i < len; i += (*mb_ptr2len)(str + i))
          ++m;
        /* Count nr of bytes in cmdline that are overwritten by these
         * characters. */
        for (i = ccline.cmdpos; i < ccline.cmdlen && m > 0;
             i += (*mb_ptr2len)(ccline.cmdbuff + i))
          --m;
        if (i < ccline.cmdlen) {
          mch_memmove(ccline.cmdbuff + ccline.cmdpos + len,
              ccline.cmdbuff + i, (size_t)(ccline.cmdlen - i));
          ccline.cmdlen += ccline.cmdpos + len - i;
        } else
          ccline.cmdlen = ccline.cmdpos + len;
      } else if (ccline.cmdpos + len > ccline.cmdlen)
        ccline.cmdlen = ccline.cmdpos + len;
    }
    mch_memmove(ccline.cmdbuff + ccline.cmdpos, str, (size_t)len);
    ccline.cmdbuff[ccline.cmdlen] = NUL;

    if (enc_utf8) {
      /* When the inserted text starts with a composing character,
       * backup to the character before it.  There could be two of them.
       */
      i = 0;
      c = utf_ptr2char(ccline.cmdbuff + ccline.cmdpos);
      while (ccline.cmdpos > 0 && utf_iscomposing(c)) {
        i = (*mb_head_off)(ccline.cmdbuff,
                           ccline.cmdbuff + ccline.cmdpos - 1) + 1;
        ccline.cmdpos -= i;
        len += i;
        c = utf_ptr2char(ccline.cmdbuff + ccline.cmdpos);
      }
      if (i == 0 && ccline.cmdpos > 0 && arabic_maycombine(c)) {
        /* Check the previous character for Arabic combining pair. */
        i = (*mb_head_off)(ccline.cmdbuff,
                           ccline.cmdbuff + ccline.cmdpos - 1) + 1;
        if (arabic_combine(utf_ptr2char(ccline.cmdbuff
                    + ccline.cmdpos - i), c)) {
          ccline.cmdpos -= i;
          len += i;
        } else
          i = 0;
      }
      if (i != 0) {
        /* Also backup the cursor position. */
        i = ptr2cells(ccline.cmdbuff + ccline.cmdpos);
        ccline.cmdspos -= i;
        msg_col -= i;
        if (msg_col < 0) {
          msg_col += Columns;
          --msg_row;
        }
      }
    }

    if (redraw && !cmd_silent) {
      msg_no_more = TRUE;
      i = cmdline_row;
      cursorcmd();
      draw_cmdline(ccline.cmdpos, ccline.cmdlen - ccline.cmdpos);
      /* Avoid clearing the rest of the line too often. */
      if (cmdline_row != i || ccline.overstrike)
        msg_clr_eos();
      msg_no_more = FALSE;
    }
    /*
     * If we are in Farsi command mode, the character input must be in
     * Insert mode. So do not advance the cmdpos.
     */
    if (!cmd_fkmap) {
      if (KeyTyped) {
        m = Columns * Rows;
        if (m < 0)              /* overflow, Columns or Rows at weird value */
          m = MAXCOL;
      } else
        m = MAXCOL;
      for (i = 0; i < len; ++i) {
        c = cmdline_charsize(ccline.cmdpos);
        /* count ">" for a double-wide char that doesn't fit. */
        if (has_mbyte)
          correct_cmdspos(ccline.cmdpos, c);
        /* Stop cursor at the end of the screen, but do increment the
         * insert position, so that entering a very long command
         * works, even though you can't see it. */
        if (ccline.cmdspos + c < m)
          ccline.cmdspos += c;
        if (has_mbyte) {
          c = (*mb_ptr2len)(ccline.cmdbuff + ccline.cmdpos) - 1;
          if (c > len - i - 1)
            c = len - i - 1;
          ccline.cmdpos += c;
          i += c;
        }
        ++ccline.cmdpos;
      }
    }
  }
  if (redraw)
    msg_check();
  return retval;
}

static struct cmdline_info prev_ccline;
static int prev_ccline_used = FALSE;

/*
 * Save ccline, because obtaining the "=" register may execute "normal :cmd"
 * and overwrite it.  But get_cmdline_str() may need it, thus make it
 * available globally in prev_ccline.
 */
static void save_cmdline(struct cmdline_info *ccp)
{
  if (!prev_ccline_used) {
    vim_memset(&prev_ccline, 0, sizeof(struct cmdline_info));
    prev_ccline_used = TRUE;
  }
  *ccp = prev_ccline;
  prev_ccline = ccline;
  ccline.cmdbuff = NULL;
  ccline.cmdprompt = NULL;
  ccline.xpc = NULL;
}

/*
 * Restore ccline after it has been saved with save_cmdline().
 */
static void restore_cmdline(struct cmdline_info *ccp)
{
  ccline = prev_ccline;
  prev_ccline = *ccp;
}

/*
 * Save the command line into allocated memory.  Returns a pointer to be
 * passed to restore_cmdline_alloc() later.
 * Returns NULL when failed.
 */
char_u *save_cmdline_alloc(void)              {
  struct cmdline_info *p;

  p = (struct cmdline_info *)alloc((unsigned)sizeof(struct cmdline_info));
  if (p != NULL)
    save_cmdline(p);
  return (char_u *)p;
}

/*
 * Restore the command line from the return value of save_cmdline_alloc().
 */
void restore_cmdline_alloc(char_u *p)
{
  if (p != NULL) {
    restore_cmdline((struct cmdline_info *)p);
    vim_free(p);
  }
}

/*
 * paste a yank register into the command line.
 * used by CTRL-R command in command-line mode
 * insert_reg() can't be used here, because special characters from the
 * register contents will be interpreted as commands.
 *
 * return FAIL for failure, OK otherwise
 */
static int 
cmdline_paste (
    int regname,
    int literally,          /* Insert text literally instead of "as typed" */
    int remcr              /* remove trailing CR */
)
{
  long i;
  char_u              *arg;
  char_u              *p;
  int allocated;
  struct cmdline_info save_ccline;

  /* check for valid regname; also accept special characters for CTRL-R in
   * the command line */
  if (regname != Ctrl_F && regname != Ctrl_P && regname != Ctrl_W
      && regname != Ctrl_A && !valid_yank_reg(regname, FALSE))
    return FAIL;

  /* A register containing CTRL-R can cause an endless loop.  Allow using
   * CTRL-C to break the loop. */
  line_breakcheck();
  if (got_int)
    return FAIL;


  /* Need to save and restore ccline.  And set "textlock" to avoid nasty
   * things like going to another buffer when evaluating an expression. */
  save_cmdline(&save_ccline);
  ++textlock;
  i = get_spec_reg(regname, &arg, &allocated, TRUE);
  --textlock;
  restore_cmdline(&save_ccline);

  if (i) {
    /* Got the value of a special register in "arg". */
    if (arg == NULL)
      return FAIL;

    /* When 'incsearch' is set and CTRL-R CTRL-W used: skip the duplicate
     * part of the word. */
    p = arg;
    if (p_is && regname == Ctrl_W) {
      char_u  *w;
      int len;

      /* Locate start of last word in the cmd buffer. */
      for (w = ccline.cmdbuff + ccline.cmdpos; w > ccline.cmdbuff; ) {
        if (has_mbyte) {
          len = (*mb_head_off)(ccline.cmdbuff, w - 1) + 1;
          if (!vim_iswordc(mb_ptr2char(w - len)))
            break;
          w -= len;
        } else   {
          if (!vim_iswordc(w[-1]))
            break;
          --w;
        }
      }
      len = (int)((ccline.cmdbuff + ccline.cmdpos) - w);
      if (p_ic ? STRNICMP(w, arg, len) == 0 : STRNCMP(w, arg, len) == 0)
        p += len;
    }

    cmdline_paste_str(p, literally);
    if (allocated)
      vim_free(arg);
    return OK;
  }

  return cmdline_paste_reg(regname, literally, remcr);
}

/*
 * Put a string on the command line.
 * When "literally" is TRUE, insert literally.
 * When "literally" is FALSE, insert as typed, but don't leave the command
 * line.
 */
void cmdline_paste_str(char_u *s, int literally)
{
  int c, cv;

  if (literally)
    put_on_cmdline(s, -1, TRUE);
  else
    while (*s != NUL) {
      cv = *s;
      if (cv == Ctrl_V && s[1])
        ++s;
      if (has_mbyte)
        c = mb_cptr2char_adv(&s);
      else
        c = *s++;
      if (cv == Ctrl_V || c == ESC || c == Ctrl_C
          || c == CAR || c == NL || c == Ctrl_L
#ifdef UNIX
          || c == intr_char
#endif
          || (c == Ctrl_BSL && *s == Ctrl_N))
        stuffcharReadbuff(Ctrl_V);
      stuffcharReadbuff(c);
    }
}

/*
 * Delete characters on the command line, from "from" to the current
 * position.
 */
static void cmdline_del(int from)
{
  mch_memmove(ccline.cmdbuff + from, ccline.cmdbuff + ccline.cmdpos,
      (size_t)(ccline.cmdlen - ccline.cmdpos + 1));
  ccline.cmdlen -= ccline.cmdpos - from;
  ccline.cmdpos = from;
}

/*
 * this function is called when the screen size changes and with incremental
 * search
 */
void redrawcmdline(void)          {
  if (cmd_silent)
    return;
  need_wait_return = FALSE;
  compute_cmdrow();
  redrawcmd();
  cursorcmd();
}

static void redrawcmdprompt(void)                 {
  int i;

  if (cmd_silent)
    return;
  if (ccline.cmdfirstc != NUL)
    msg_putchar(ccline.cmdfirstc);
  if (ccline.cmdprompt != NULL) {
    msg_puts_attr(ccline.cmdprompt, ccline.cmdattr);
    ccline.cmdindent = msg_col + (msg_row - cmdline_row) * Columns;
    /* do the reverse of set_cmdspos() */
    if (ccline.cmdfirstc != NUL)
      --ccline.cmdindent;
  } else
    for (i = ccline.cmdindent; i > 0; --i)
      msg_putchar(' ');
}

/*
 * Redraw what is currently on the command line.
 */
void redrawcmd(void)          {
  if (cmd_silent)
    return;

  /* when 'incsearch' is set there may be no command line while redrawing */
  if (ccline.cmdbuff == NULL) {
    windgoto(cmdline_row, 0);
    msg_clr_eos();
    return;
  }

  msg_start();
  redrawcmdprompt();

  /* Don't use more prompt, truncate the cmdline if it doesn't fit. */
  msg_no_more = TRUE;
  draw_cmdline(0, ccline.cmdlen);
  msg_clr_eos();
  msg_no_more = FALSE;

  set_cmdspos_cursor();

  /*
   * An emsg() before may have set msg_scroll. This is used in normal mode,
   * in cmdline mode we can reset them now.
   */
  msg_scroll = FALSE;           /* next message overwrites cmdline */

  /* Typing ':' at the more prompt may set skip_redraw.  We don't want this
   * in cmdline mode */
  skip_redraw = FALSE;
}

void compute_cmdrow(void)          {
  if (exmode_active || msg_scrolled != 0)
    cmdline_row = Rows - 1;
  else
    cmdline_row = W_WINROW(lastwin) + lastwin->w_height
                  + W_STATUS_HEIGHT(lastwin);
}

static void cursorcmd(void)                 {
  if (cmd_silent)
    return;

  if (cmdmsg_rl) {
    msg_row = cmdline_row  + (ccline.cmdspos / (int)(Columns - 1));
    msg_col = (int)Columns - (ccline.cmdspos % (int)(Columns - 1)) - 1;
    if (msg_row <= 0)
      msg_row = Rows - 1;
  } else   {
    msg_row = cmdline_row + (ccline.cmdspos / (int)Columns);
    msg_col = ccline.cmdspos % (int)Columns;
    if (msg_row >= Rows)
      msg_row = Rows - 1;
  }

  windgoto(msg_row, msg_col);
}

void gotocmdline(int clr)
{
  msg_start();
  if (cmdmsg_rl)
    msg_col = Columns - 1;
  else
    msg_col = 0;            /* always start in column 0 */
  if (clr)                  /* clear the bottom line(s) */
    msg_clr_eos();          /* will reset clear_cmdline */
  windgoto(cmdline_row, 0);
}

/*
 * Check the word in front of the cursor for an abbreviation.
 * Called when the non-id character "c" has been entered.
 * When an abbreviation is recognized it is removed from the text with
 * backspaces and the replacement string is inserted, followed by "c".
 */
static int ccheck_abbr(int c)
{
  if (p_paste || no_abbr)           /* no abbreviations or in paste mode */
    return FALSE;

  return check_abbr(c, ccline.cmdbuff, ccline.cmdpos, 0);
}

static int sort_func_compare(const void *s1, const void *s2)
{
  char_u *p1 = *(char_u **)s1;
  char_u *p2 = *(char_u **)s2;

  if (*p1 != '<' && *p2 == '<') return -1;
  if (*p1 == '<' && *p2 != '<') return 1;
  return STRCMP(p1, p2);
}

/*
 * Return FAIL if this is not an appropriate context in which to do
 * completion of anything, return OK if it is (even if there are no matches).
 * For the caller, this means that the character is just passed through like a
 * normal character (instead of being expanded).  This allows :s/^I^D etc.
 */
static int 
nextwild (
    expand_T *xp,
    int type,
    int options,                    /* extra options for ExpandOne() */
    int escape                     /* if TRUE, escape the returned matches */
)
{
  int i, j;
  char_u      *p1;
  char_u      *p2;
  int difflen;
  int v;

  if (xp->xp_numfiles == -1) {
    set_expand_context(xp);
    cmd_showtail = expand_showtail(xp);
  }

  if (xp->xp_context == EXPAND_UNSUCCESSFUL) {
    beep_flush();
    return OK;      /* Something illegal on command line */
  }
  if (xp->xp_context == EXPAND_NOTHING) {
    /* Caller can use the character as a normal char instead */
    return FAIL;
  }

  MSG_PUTS("...");          /* show that we are busy */
  out_flush();

  i = (int)(xp->xp_pattern - ccline.cmdbuff);
  xp->xp_pattern_len = ccline.cmdpos - i;

  if (type == WILD_NEXT || type == WILD_PREV) {
    /*
     * Get next/previous match for a previous expanded pattern.
     */
    p2 = ExpandOne(xp, NULL, NULL, 0, type);
  } else   {
    /*
     * Translate string into pattern and expand it.
     */
    if ((p1 = addstar(xp->xp_pattern, xp->xp_pattern_len,
             xp->xp_context)) == NULL)
      p2 = NULL;
    else {
      int use_options = options |
                        WILD_HOME_REPLACE|WILD_ADD_SLASH|WILD_SILENT;
      if (escape)
        use_options |= WILD_ESCAPE;

      if (p_wic)
        use_options += WILD_ICASE;
      p2 = ExpandOne(xp, p1,
          vim_strnsave(&ccline.cmdbuff[i], xp->xp_pattern_len),
          use_options, type);
      vim_free(p1);
      /* longest match: make sure it is not shorter, happens with :help */
      if (p2 != NULL && type == WILD_LONGEST) {
        for (j = 0; j < xp->xp_pattern_len; ++j)
          if (ccline.cmdbuff[i + j] == '*'
              || ccline.cmdbuff[i + j] == '?')
            break;
        if ((int)STRLEN(p2) < j) {
          vim_free(p2);
          p2 = NULL;
        }
      }
    }
  }

  if (p2 != NULL && !got_int) {
    difflen = (int)STRLEN(p2) - xp->xp_pattern_len;
    if (ccline.cmdlen + difflen + 4 > ccline.cmdbufflen) {
      v = realloc_cmdbuff(ccline.cmdlen + difflen + 4);
      xp->xp_pattern = ccline.cmdbuff + i;
    } else
      v = OK;
    if (v == OK) {
      mch_memmove(&ccline.cmdbuff[ccline.cmdpos + difflen],
          &ccline.cmdbuff[ccline.cmdpos],
          (size_t)(ccline.cmdlen - ccline.cmdpos + 1));
      mch_memmove(&ccline.cmdbuff[i], p2, STRLEN(p2));
      ccline.cmdlen += difflen;
      ccline.cmdpos += difflen;
    }
  }
  vim_free(p2);

  redrawcmd();
  cursorcmd();

  /* When expanding a ":map" command and no matches are found, assume that
   * the key is supposed to be inserted literally */
  if (xp->xp_context == EXPAND_MAPPINGS && p2 == NULL)
    return FAIL;

  if (xp->xp_numfiles <= 0 && p2 == NULL)
    beep_flush();
  else if (xp->xp_numfiles == 1)
    /* free expanded pattern */
    (void)ExpandOne(xp, NULL, NULL, 0, WILD_FREE);

  return OK;
}

/*
 * Do wildcard expansion on the string 'str'.
 * Chars that should not be expanded must be preceded with a backslash.
 * Return a pointer to allocated memory containing the new string.
 * Return NULL for failure.
 *
 * "orig" is the originally expanded string, copied to allocated memory.  It
 * should either be kept in orig_save or freed.  When "mode" is WILD_NEXT or
 * WILD_PREV "orig" should be NULL.
 *
 * Results are cached in xp->xp_files and xp->xp_numfiles, except when "mode"
 * is WILD_EXPAND_FREE or WILD_ALL.
 *
 * mode = WILD_FREE:	    just free previously expanded matches
 * mode = WILD_EXPAND_FREE: normal expansion, do not keep matches
 * mode = WILD_EXPAND_KEEP: normal expansion, keep matches
 * mode = WILD_NEXT:	    use next match in multiple match, wrap to first
 * mode = WILD_PREV:	    use previous match in multiple match, wrap to first
 * mode = WILD_ALL:	    return all matches concatenated
 * mode = WILD_LONGEST:	    return longest matched part
 * mode = WILD_ALL_KEEP:    get all matches, keep matches
 *
 * options = WILD_LIST_NOTFOUND:    list entries without a match
 * options = WILD_HOME_REPLACE:	    do home_replace() for buffer names
 * options = WILD_USE_NL:	    Use '\n' for WILD_ALL
 * options = WILD_NO_BEEP:	    Don't beep for multiple matches
 * options = WILD_ADD_SLASH:	    add a slash after directory names
 * options = WILD_KEEP_ALL:	    don't remove 'wildignore' entries
 * options = WILD_SILENT:	    don't print warning messages
 * options = WILD_ESCAPE:	    put backslash before special chars
 * options = WILD_ICASE:	    ignore case for files
 *
 * The variables xp->xp_context and xp->xp_backslash must have been set!
 */
char_u *
ExpandOne (
    expand_T *xp,
    char_u *str,
    char_u *orig,          /* allocated copy of original of expanded string */
    int options,
    int mode
)
{
  char_u      *ss = NULL;
  static int findex;
  static char_u *orig_save = NULL;      /* kept value of orig */
  int orig_saved = FALSE;
  int i;
  long_u len;
  int non_suf_match;                    /* number without matching suffix */

  /*
   * first handle the case of using an old match
   */
  if (mode == WILD_NEXT || mode == WILD_PREV) {
    if (xp->xp_numfiles > 0) {
      if (mode == WILD_PREV) {
        if (findex == -1)
          findex = xp->xp_numfiles;
        --findex;
      } else        /* mode == WILD_NEXT */
        ++findex;

      /*
       * When wrapping around, return the original string, set findex to
       * -1.
       */
      if (findex < 0) {
        if (orig_save == NULL)
          findex = xp->xp_numfiles - 1;
        else
          findex = -1;
      }
      if (findex >= xp->xp_numfiles) {
        if (orig_save == NULL)
          findex = 0;
        else
          findex = -1;
      }
      if (p_wmnu)
        win_redr_status_matches(xp, xp->xp_numfiles, xp->xp_files,
            findex, cmd_showtail);
      if (findex == -1)
        return vim_strsave(orig_save);
      return vim_strsave(xp->xp_files[findex]);
    } else
      return NULL;
  }

  /* free old names */
  if (xp->xp_numfiles != -1 && mode != WILD_ALL && mode != WILD_LONGEST) {
    FreeWild(xp->xp_numfiles, xp->xp_files);
    xp->xp_numfiles = -1;
    vim_free(orig_save);
    orig_save = NULL;
  }
  findex = 0;

  if (mode == WILD_FREE)        /* only release file name */
    return NULL;

  if (xp->xp_numfiles == -1) {
    vim_free(orig_save);
    orig_save = orig;
    orig_saved = TRUE;

    /*
     * Do the expansion.
     */
    if (ExpandFromContext(xp, str, &xp->xp_numfiles, &xp->xp_files,
            options) == FAIL) {
#ifdef FNAME_ILLEGAL
      /* Illegal file name has been silently skipped.  But when there
       * are wildcards, the real problem is that there was no match,
       * causing the pattern to be added, which has illegal characters.
       */
      if (!(options & WILD_SILENT) && (options & WILD_LIST_NOTFOUND))
        EMSG2(_(e_nomatch2), str);
#endif
    } else if (xp->xp_numfiles == 0)   {
      if (!(options & WILD_SILENT))
        EMSG2(_(e_nomatch2), str);
    } else   {
      /* Escape the matches for use on the command line. */
      ExpandEscape(xp, str, xp->xp_numfiles, xp->xp_files, options);

      /*
       * Check for matching suffixes in file names.
       */
      if (mode != WILD_ALL && mode != WILD_ALL_KEEP
          && mode != WILD_LONGEST) {
        if (xp->xp_numfiles)
          non_suf_match = xp->xp_numfiles;
        else
          non_suf_match = 1;
        if ((xp->xp_context == EXPAND_FILES
             || xp->xp_context == EXPAND_DIRECTORIES)
            && xp->xp_numfiles > 1) {
          /*
           * More than one match; check suffix.
           * The files will have been sorted on matching suffix in
           * expand_wildcards, only need to check the first two.
           */
          non_suf_match = 0;
          for (i = 0; i < 2; ++i)
            if (match_suffix(xp->xp_files[i]))
              ++non_suf_match;
        }
        if (non_suf_match != 1) {
          /* Can we ever get here unless it's while expanding
           * interactively?  If not, we can get rid of this all
           * together. Don't really want to wait for this message
           * (and possibly have to hit return to continue!).
           */
          if (!(options & WILD_SILENT))
            EMSG(_(e_toomany));
          else if (!(options & WILD_NO_BEEP))
            beep_flush();
        }
        if (!(non_suf_match != 1 && mode == WILD_EXPAND_FREE))
          ss = vim_strsave(xp->xp_files[0]);
      }
    }
  }

  /* Find longest common part */
  if (mode == WILD_LONGEST && xp->xp_numfiles > 0) {
    for (len = 0; xp->xp_files[0][len]; ++len) {
      for (i = 0; i < xp->xp_numfiles; ++i) {
        if (p_fic && (xp->xp_context == EXPAND_DIRECTORIES
                      || xp->xp_context == EXPAND_FILES
                      || xp->xp_context == EXPAND_SHELLCMD
                      || xp->xp_context == EXPAND_BUFFERS)) {
          if (TOLOWER_LOC(xp->xp_files[i][len]) !=
              TOLOWER_LOC(xp->xp_files[0][len]))
            break;
        } else if (xp->xp_files[i][len] != xp->xp_files[0][len])
          break;
      }
      if (i < xp->xp_numfiles) {
        if (!(options & WILD_NO_BEEP))
          vim_beep();
        break;
      }
    }
    ss = alloc((unsigned)len + 1);
    if (ss)
      vim_strncpy(ss, xp->xp_files[0], (size_t)len);
    findex = -1;                            /* next p_wc gets first one */
  }

  /* Concatenate all matching names */
  if (mode == WILD_ALL && xp->xp_numfiles > 0) {
    len = 0;
    for (i = 0; i < xp->xp_numfiles; ++i)
      len += (long_u)STRLEN(xp->xp_files[i]) + 1;
    ss = lalloc(len, TRUE);
    if (ss != NULL) {
      *ss = NUL;
      for (i = 0; i < xp->xp_numfiles; ++i) {
        STRCAT(ss, xp->xp_files[i]);
        if (i != xp->xp_numfiles - 1)
          STRCAT(ss, (options & WILD_USE_NL) ? "\n" : " ");
      }
    }
  }

  if (mode == WILD_EXPAND_FREE || mode == WILD_ALL)
    ExpandCleanup(xp);

  /* Free "orig" if it wasn't stored in "orig_save". */
  if (!orig_saved)
    vim_free(orig);

  return ss;
}

/*
 * Prepare an expand structure for use.
 */
void ExpandInit(expand_T *xp)
{
  xp->xp_pattern = NULL;
  xp->xp_pattern_len = 0;
  xp->xp_backslash = XP_BS_NONE;
#ifndef BACKSLASH_IN_FILENAME
  xp->xp_shell = FALSE;
#endif
  xp->xp_numfiles = -1;
  xp->xp_files = NULL;
  xp->xp_arg = NULL;
  xp->xp_line = NULL;
}

/*
 * Cleanup an expand structure after use.
 */
void ExpandCleanup(expand_T *xp)
{
  if (xp->xp_numfiles >= 0) {
    FreeWild(xp->xp_numfiles, xp->xp_files);
    xp->xp_numfiles = -1;
  }
}

void ExpandEscape(expand_T *xp, char_u *str, int numfiles, char_u **files, int options)
{
  int i;
  char_u      *p;

  /*
   * May change home directory back to "~"
   */
  if (options & WILD_HOME_REPLACE)
    tilde_replace(str, numfiles, files);

  if (options & WILD_ESCAPE) {
    if (xp->xp_context == EXPAND_FILES
        || xp->xp_context == EXPAND_FILES_IN_PATH
        || xp->xp_context == EXPAND_SHELLCMD
        || xp->xp_context == EXPAND_BUFFERS
        || xp->xp_context == EXPAND_DIRECTORIES) {
      /*
       * Insert a backslash into a file name before a space, \, %, #
       * and wildmatch characters, except '~'.
       */
      for (i = 0; i < numfiles; ++i) {
        /* for ":set path=" we need to escape spaces twice */
        if (xp->xp_backslash == XP_BS_THREE) {
          p = vim_strsave_escaped(files[i], (char_u *)" ");
          if (p != NULL) {
            vim_free(files[i]);
            files[i] = p;
#if defined(BACKSLASH_IN_FILENAME)
            p = vim_strsave_escaped(files[i], (char_u *)" ");
            if (p != NULL) {
              vim_free(files[i]);
              files[i] = p;
            }
#endif
          }
        }
#ifdef BACKSLASH_IN_FILENAME
        p = vim_strsave_fnameescape(files[i], FALSE);
#else
        p = vim_strsave_fnameescape(files[i], xp->xp_shell);
#endif
        if (p != NULL) {
          vim_free(files[i]);
          files[i] = p;
        }

        /* If 'str' starts with "\~", replace "~" at start of
         * files[i] with "\~". */
        if (str[0] == '\\' && str[1] == '~' && files[i][0] == '~')
          escape_fname(&files[i]);
      }
      xp->xp_backslash = XP_BS_NONE;

      /* If the first file starts with a '+' escape it.  Otherwise it
       * could be seen as "+cmd". */
      if (*files[0] == '+')
        escape_fname(&files[0]);
    } else if (xp->xp_context == EXPAND_TAGS)   {
      /*
       * Insert a backslash before characters in a tag name that
       * would terminate the ":tag" command.
       */
      for (i = 0; i < numfiles; ++i) {
        p = vim_strsave_escaped(files[i], (char_u *)"\\|\"");
        if (p != NULL) {
          vim_free(files[i]);
          files[i] = p;
        }
      }
    }
  }
}

/*
 * Escape special characters in "fname" for when used as a file name argument
 * after a Vim command, or, when "shell" is non-zero, a shell command.
 * Returns the result in allocated memory.
 */
char_u *vim_strsave_fnameescape(char_u *fname, int shell)
{
  char_u      *p;
#ifdef BACKSLASH_IN_FILENAME
  char_u buf[20];
  int j = 0;

  /* Don't escape '[', '{' and '!' if they are in 'isfname'. */
  for (p = PATH_ESC_CHARS; *p != NUL; ++p)
    if ((*p != '[' && *p != '{' && *p != '!') || !vim_isfilec(*p))
      buf[j++] = *p;
  buf[j] = NUL;
  p = vim_strsave_escaped(fname, buf);
#else
  p = vim_strsave_escaped(fname, shell ? SHELL_ESC_CHARS : PATH_ESC_CHARS);
  if (shell && csh_like_shell() && p != NULL) {
    char_u      *s;

    /* For csh and similar shells need to put two backslashes before '!'.
     * One is taken by Vim, one by the shell. */
    s = vim_strsave_escaped(p, (char_u *)"!");
    vim_free(p);
    p = s;
  }
#endif

  /* '>' and '+' are special at the start of some commands, e.g. ":edit" and
   * ":write".  "cd -" has a special meaning. */
  if (p != NULL && (*p == '>' || *p == '+' || (*p == '-' && p[1] == NUL)))
    escape_fname(&p);

  return p;
}

/*
 * Put a backslash before the file name in "pp", which is in allocated memory.
 */
static void escape_fname(char_u **pp)
{
  char_u      *p;

  p = alloc((unsigned)(STRLEN(*pp) + 2));
  if (p != NULL) {
    p[0] = '\\';
    STRCPY(p + 1, *pp);
    vim_free(*pp);
    *pp = p;
  }
}

/*
 * For each file name in files[num_files]:
 * If 'orig_pat' starts with "~/", replace the home directory with "~".
 */
void tilde_replace(char_u *orig_pat, int num_files, char_u **files)
{
  int i;
  char_u  *p;

  if (orig_pat[0] == '~' && vim_ispathsep(orig_pat[1])) {
    for (i = 0; i < num_files; ++i) {
      p = home_replace_save(NULL, files[i]);
      if (p != NULL) {
        vim_free(files[i]);
        files[i] = p;
      }
    }
  }
}

/*
 * Show all matches for completion on the command line.
 * Returns EXPAND_NOTHING when the character that triggered expansion should
 * be inserted like a normal character.
 */
static int showmatches(expand_T *xp, int wildmenu)
{
#define L_SHOWFILE(m) (showtail ? sm_gettail(files_found[m]) : files_found[m])
  int num_files;
  char_u      **files_found;
  int i, j, k;
  int maxlen;
  int lines;
  int columns;
  char_u      *p;
  int lastlen;
  int attr;
  int showtail;

  if (xp->xp_numfiles == -1) {
    set_expand_context(xp);
    i = expand_cmdline(xp, ccline.cmdbuff, ccline.cmdpos,
        &num_files, &files_found);
    showtail = expand_showtail(xp);
    if (i != EXPAND_OK)
      return i;

  } else   {
    num_files = xp->xp_numfiles;
    files_found = xp->xp_files;
    showtail = cmd_showtail;
  }

  if (!wildmenu) {
    msg_didany = FALSE;                 /* lines_left will be set */
    msg_start();                        /* prepare for paging */
    msg_putchar('\n');
    out_flush();
    cmdline_row = msg_row;
    msg_didany = FALSE;                 /* lines_left will be set again */
    msg_start();                        /* prepare for paging */
  }

  if (got_int)
    got_int = FALSE;            /* only int. the completion, not the cmd line */
  else if (wildmenu)
    win_redr_status_matches(xp, num_files, files_found, 0, showtail);
  else {
    /* find the length of the longest file name */
    maxlen = 0;
    for (i = 0; i < num_files; ++i) {
      if (!showtail && (xp->xp_context == EXPAND_FILES
                        || xp->xp_context == EXPAND_SHELLCMD
                        || xp->xp_context == EXPAND_BUFFERS)) {
        home_replace(NULL, files_found[i], NameBuff, MAXPATHL, TRUE);
        j = vim_strsize(NameBuff);
      } else
        j = vim_strsize(L_SHOWFILE(i));
      if (j > maxlen)
        maxlen = j;
    }

    if (xp->xp_context == EXPAND_TAGS_LISTFILES)
      lines = num_files;
    else {
      /* compute the number of columns and lines for the listing */
      maxlen += 2;          /* two spaces between file names */
      columns = ((int)Columns + 2) / maxlen;
      if (columns < 1)
        columns = 1;
      lines = (num_files + columns - 1) / columns;
    }

    attr = hl_attr(HLF_D);      /* find out highlighting for directories */

    if (xp->xp_context == EXPAND_TAGS_LISTFILES) {
      MSG_PUTS_ATTR(_("tagname"), hl_attr(HLF_T));
      msg_clr_eos();
      msg_advance(maxlen - 3);
      MSG_PUTS_ATTR(_(" kind file\n"), hl_attr(HLF_T));
    }

    /* list the files line by line */
    for (i = 0; i < lines; ++i) {
      lastlen = 999;
      for (k = i; k < num_files; k += lines) {
        if (xp->xp_context == EXPAND_TAGS_LISTFILES) {
          msg_outtrans_attr(files_found[k], hl_attr(HLF_D));
          p = files_found[k] + STRLEN(files_found[k]) + 1;
          msg_advance(maxlen + 1);
          msg_puts(p);
          msg_advance(maxlen + 3);
          msg_puts_long_attr(p + 2, hl_attr(HLF_D));
          break;
        }
        for (j = maxlen - lastlen; --j >= 0; )
          msg_putchar(' ');
        if (xp->xp_context == EXPAND_FILES
            || xp->xp_context == EXPAND_SHELLCMD
            || xp->xp_context == EXPAND_BUFFERS) {
          /* highlight directories */
          if (xp->xp_numfiles != -1) {
            char_u  *halved_slash;
            char_u  *exp_path;

            /* Expansion was done before and special characters
             * were escaped, need to halve backslashes.  Also
             * $HOME has been replaced with ~/. */
            exp_path = expand_env_save_opt(files_found[k], TRUE);
            halved_slash = backslash_halve_save(
                exp_path != NULL ? exp_path : files_found[k]);
            j = mch_isdir(halved_slash != NULL ? halved_slash
                : files_found[k]);
            vim_free(exp_path);
            vim_free(halved_slash);
          } else
            /* Expansion was done here, file names are literal. */
            j = mch_isdir(files_found[k]);
          if (showtail)
            p = L_SHOWFILE(k);
          else {
            home_replace(NULL, files_found[k], NameBuff, MAXPATHL,
                TRUE);
            p = NameBuff;
          }
        } else   {
          j = FALSE;
          p = L_SHOWFILE(k);
        }
        lastlen = msg_outtrans_attr(p, j ? attr : 0);
      }
      if (msg_col > 0) {        /* when not wrapped around */
        msg_clr_eos();
        msg_putchar('\n');
      }
      out_flush();                          /* show one line at a time */
      if (got_int) {
        got_int = FALSE;
        break;
      }
    }

    /*
     * we redraw the command below the lines that we have just listed
     * This is a bit tricky, but it saves a lot of screen updating.
     */
    cmdline_row = msg_row;      /* will put it back later */
  }

  if (xp->xp_numfiles == -1)
    FreeWild(num_files, files_found);

  return EXPAND_OK;
}

/*
 * Private gettail for showmatches() (and win_redr_status_matches()):
 * Find tail of file name path, but ignore trailing "/".
 */
char_u *sm_gettail(char_u *s)
{
  char_u      *p;
  char_u      *t = s;
  int had_sep = FALSE;

  for (p = s; *p != NUL; ) {
    if (vim_ispathsep(*p)
#ifdef BACKSLASH_IN_FILENAME
        && !rem_backslash(p)
#endif
        )
      had_sep = TRUE;
    else if (had_sep) {
      t = p;
      had_sep = FALSE;
    }
    mb_ptr_adv(p);
  }
  return t;
}

/*
 * Return TRUE if we only need to show the tail of completion matches.
 * When not completing file names or there is a wildcard in the path FALSE is
 * returned.
 */
static int expand_showtail(expand_T *xp)
{
  char_u      *s;
  char_u      *end;

  /* When not completing file names a "/" may mean something different. */
  if (xp->xp_context != EXPAND_FILES
      && xp->xp_context != EXPAND_SHELLCMD
      && xp->xp_context != EXPAND_DIRECTORIES)
    return FALSE;

  end = gettail(xp->xp_pattern);
  if (end == xp->xp_pattern)            /* there is no path separator */
    return FALSE;

  for (s = xp->xp_pattern; s < end; s++) {
    /* Skip escaped wildcards.  Only when the backslash is not a path
    * separator, on DOS the '*' "path\*\file" must not be skipped. */
    if (rem_backslash(s))
      ++s;
    else if (vim_strchr((char_u *)"*?[", *s) != NULL)
      return FALSE;
  }
  return TRUE;
}

/*
 * Prepare a string for expansion.
 * When expanding file names: The string will be used with expand_wildcards().
 * Copy "fname[len]" into allocated memory and add a '*' at the end.
 * When expanding other names: The string will be used with regcomp().  Copy
 * the name into allocated memory and prepend "^".
 */
char_u *
addstar (
    char_u *fname,
    int len,
    int context                    /* EXPAND_FILES etc. */
)
{
  char_u      *retval;
  int i, j;
  int new_len;
  char_u      *tail;
  int ends_in_star;

  if (context != EXPAND_FILES
      && context != EXPAND_FILES_IN_PATH
      && context != EXPAND_SHELLCMD
      && context != EXPAND_DIRECTORIES) {
    /*
     * Matching will be done internally (on something other than files).
     * So we convert the file-matching-type wildcards into our kind for
     * use with vim_regcomp().  First work out how long it will be:
     */

    /* For help tags the translation is done in find_help_tags().
     * For a tag pattern starting with "/" no translation is needed. */
    if (context == EXPAND_HELP
        || context == EXPAND_COLORS
        || context == EXPAND_COMPILER
        || context == EXPAND_OWNSYNTAX
        || context == EXPAND_FILETYPE
        || (context == EXPAND_TAGS && fname[0] == '/'))
      retval = vim_strnsave(fname, len);
    else {
      new_len = len + 2;                /* +2 for '^' at start, NUL at end */
      for (i = 0; i < len; i++) {
        if (fname[i] == '*' || fname[i] == '~')
          new_len++;                    /* '*' needs to be replaced by ".*"
                                           '~' needs to be replaced by "\~" */

        /* Buffer names are like file names.  "." should be literal */
        if (context == EXPAND_BUFFERS && fname[i] == '.')
          new_len++;                    /* "." becomes "\." */

        /* Custom expansion takes care of special things, match
         * backslashes literally (perhaps also for other types?) */
        if ((context == EXPAND_USER_DEFINED
             || context == EXPAND_USER_LIST) && fname[i] == '\\')
          new_len++;                    /* '\' becomes "\\" */
      }
      retval = alloc(new_len);
      if (retval != NULL) {
        retval[0] = '^';
        j = 1;
        for (i = 0; i < len; i++, j++) {
          /* Skip backslash.  But why?  At least keep it for custom
           * expansion. */
          if (context != EXPAND_USER_DEFINED
              && context != EXPAND_USER_LIST
              && fname[i] == '\\'
              && ++i == len)
            break;

          switch (fname[i]) {
          case '*':   retval[j++] = '.';
            break;
          case '~':   retval[j++] = '\\';
            break;
          case '?':   retval[j] = '.';
            continue;
          case '.':   if (context == EXPAND_BUFFERS)
              retval[j++] = '\\';
            break;
          case '\\':  if (context == EXPAND_USER_DEFINED
                          || context == EXPAND_USER_LIST)
              retval[j++] = '\\';
            break;
          }
          retval[j] = fname[i];
        }
        retval[j] = NUL;
      }
    }
  } else   {
    retval = alloc(len + 4);
    if (retval != NULL) {
      vim_strncpy(retval, fname, len);

      /*
       * Don't add a star to *, ~, ~user, $var or `cmd`.
       * * would become **, which walks the whole tree.
       * ~ would be at the start of the file name, but not the tail.
       * $ could be anywhere in the tail.
       * ` could be anywhere in the file name.
       * When the name ends in '$' don't add a star, remove the '$'.
       */
      tail = gettail(retval);
      ends_in_star = (len > 0 && retval[len - 1] == '*');
#ifndef BACKSLASH_IN_FILENAME
      for (i = len - 2; i >= 0; --i) {
        if (retval[i] != '\\')
          break;
        ends_in_star = !ends_in_star;
      }
#endif
      if ((*retval != '~' || tail != retval)
          && !ends_in_star
          && vim_strchr(tail, '$') == NULL
          && vim_strchr(retval, '`') == NULL)
        retval[len++] = '*';
      else if (len > 0 && retval[len - 1] == '$')
        --len;
      retval[len] = NUL;
    }
  }
  return retval;
}

/*
 * Must parse the command line so far to work out what context we are in.
 * Completion can then be done based on that context.
 * This routine sets the variables:
 *  xp->xp_pattern	    The start of the pattern to be expanded within
 *				the command line (ends at the cursor).
 *  xp->xp_context	    The type of thing to expand.  Will be one of:
 *
 *  EXPAND_UNSUCCESSFUL	    Used sometimes when there is something illegal on
 *			    the command line, like an unknown command.	Caller
 *			    should beep.
 *  EXPAND_NOTHING	    Unrecognised context for completion, use char like
 *			    a normal char, rather than for completion.	eg
 *			    :s/^I/
 *  EXPAND_COMMANDS	    Cursor is still touching the command, so complete
 *			    it.
 *  EXPAND_BUFFERS	    Complete file names for :buf and :sbuf commands.
 *  EXPAND_FILES	    After command with XFILE set, or after setting
 *			    with P_EXPAND set.	eg :e ^I, :w>>^I
 *  EXPAND_DIRECTORIES	    In some cases this is used instead of the latter
 *			    when we know only directories are of interest.  eg
 *			    :set dir=^I
 *  EXPAND_SHELLCMD	    After ":!cmd", ":r !cmd"  or ":w !cmd".
 *  EXPAND_SETTINGS	    Complete variable names.  eg :set d^I
 *  EXPAND_BOOL_SETTINGS    Complete boolean variables only,  eg :set no^I
 *  EXPAND_TAGS		    Complete tags from the files in p_tags.  eg :ta a^I
 *  EXPAND_TAGS_LISTFILES   As above, but list filenames on ^D, after :tselect
 *  EXPAND_HELP		    Complete tags from the file 'helpfile'/tags
 *  EXPAND_EVENTS	    Complete event names
 *  EXPAND_SYNTAX	    Complete :syntax command arguments
 *  EXPAND_HIGHLIGHT	    Complete highlight (syntax) group names
 *  EXPAND_AUGROUP	    Complete autocommand group names
 *  EXPAND_USER_VARS	    Complete user defined variable names, eg :unlet a^I
 *  EXPAND_MAPPINGS	    Complete mapping and abbreviation names,
 *			      eg :unmap a^I , :cunab x^I
 *  EXPAND_FUNCTIONS	    Complete internal or user defined function names,
 *			      eg :call sub^I
 *  EXPAND_USER_FUNC	    Complete user defined function names, eg :delf F^I
 *  EXPAND_EXPRESSION	    Complete internal or user defined function/variable
 *			    names in expressions, eg :while s^I
 *  EXPAND_ENV_VARS	    Complete environment variable names
 *  EXPAND_USER		    Complete user names
 */
static void set_expand_context(expand_T *xp)
{
  /* only expansion for ':', '>' and '=' command-lines */
  if (ccline.cmdfirstc != ':'
      && ccline.cmdfirstc != '>' && ccline.cmdfirstc != '='
      && !ccline.input_fn
      ) {
    xp->xp_context = EXPAND_NOTHING;
    return;
  }
  set_cmd_context(xp, ccline.cmdbuff, ccline.cmdlen, ccline.cmdpos);
}

void 
set_cmd_context (
    expand_T *xp,
    char_u *str,           /* start of command line */
    int len,                    /* length of command line (excl. NUL) */
    int col                    /* position of cursor */
)
{
  int old_char = NUL;
  char_u      *nextcomm;

  /*
   * Avoid a UMR warning from Purify, only save the character if it has been
   * written before.
   */
  if (col < len)
    old_char = str[col];
  str[col] = NUL;
  nextcomm = str;

  if (ccline.cmdfirstc == '=') {
    /* pass CMD_SIZE because there is no real command */
    set_context_for_expression(xp, str, CMD_SIZE);
  } else if (ccline.input_fn)   {
    xp->xp_context = ccline.xp_context;
    xp->xp_pattern = ccline.cmdbuff;
    xp->xp_arg = ccline.xp_arg;
  } else
    while (nextcomm != NULL)
      nextcomm = set_one_cmd_context(xp, nextcomm);

  /* Store the string here so that call_user_expand_func() can get to them
   * easily. */
  xp->xp_line = str;
  xp->xp_col = col;

  str[col] = old_char;
}

/*
 * Expand the command line "str" from context "xp".
 * "xp" must have been set by set_cmd_context().
 * xp->xp_pattern points into "str", to where the text that is to be expanded
 * starts.
 * Returns EXPAND_UNSUCCESSFUL when there is something illegal before the
 * cursor.
 * Returns EXPAND_NOTHING when there is nothing to expand, might insert the
 * key that triggered expansion literally.
 * Returns EXPAND_OK otherwise.
 */
int 
expand_cmdline (
    expand_T *xp,
    char_u *str,               /* start of command line */
    int col,                        /* position of cursor */
    int *matchcount,        /* return: nr of matches */
    char_u ***matches         /* return: array of pointers to matches */
)
{
  char_u      *file_str = NULL;
  int options = WILD_ADD_SLASH|WILD_SILENT;

  if (xp->xp_context == EXPAND_UNSUCCESSFUL) {
    beep_flush();
    return EXPAND_UNSUCCESSFUL;      /* Something illegal on command line */
  }
  if (xp->xp_context == EXPAND_NOTHING) {
    /* Caller can use the character as a normal char instead */
    return EXPAND_NOTHING;
  }

  /* add star to file name, or convert to regexp if not exp. files. */
  xp->xp_pattern_len = (int)(str + col - xp->xp_pattern);
  file_str = addstar(xp->xp_pattern, xp->xp_pattern_len, xp->xp_context);
  if (file_str == NULL)
    return EXPAND_UNSUCCESSFUL;

  if (p_wic)
    options += WILD_ICASE;

  /* find all files that match the description */
  if (ExpandFromContext(xp, file_str, matchcount, matches, options) == FAIL) {
    *matchcount = 0;
    *matches = NULL;
  }
  vim_free(file_str);

  return EXPAND_OK;
}

/*
 * Cleanup matches for help tags: remove "@en" if "en" is the only language.
 */
static void cleanup_help_tags(int num_file, char_u **file);

static void cleanup_help_tags(int num_file, char_u **file)
{
  int i, j;
  int len;

  for (i = 0; i < num_file; ++i) {
    len = (int)STRLEN(file[i]) - 3;
    if (len > 0 && STRCMP(file[i] + len, "@en") == 0) {
      /* Sorting on priority means the same item in another language may
       * be anywhere.  Search all items for a match up to the "@en". */
      for (j = 0; j < num_file; ++j)
        if (j != i
            && (int)STRLEN(file[j]) == len + 3
            && STRNCMP(file[i], file[j], len + 1) == 0)
          break;
      if (j == num_file)
        file[i][len] = NUL;
    }
  }
}

/*
 * Do the expansion based on xp->xp_context and "pat".
 */
static int 
ExpandFromContext (
    expand_T *xp,
    char_u *pat,
    int *num_file,
    char_u ***file,
    int options              /* EW_ flags */
)
{
  regmatch_T regmatch;
  int ret;
  int flags;

  flags = EW_DIR;       /* include directories */
  if (options & WILD_LIST_NOTFOUND)
    flags |= EW_NOTFOUND;
  if (options & WILD_ADD_SLASH)
    flags |= EW_ADDSLASH;
  if (options & WILD_KEEP_ALL)
    flags |= EW_KEEPALL;
  if (options & WILD_SILENT)
    flags |= EW_SILENT;

  if (xp->xp_context == EXPAND_FILES
      || xp->xp_context == EXPAND_DIRECTORIES
      || xp->xp_context == EXPAND_FILES_IN_PATH) {
    /*
     * Expand file or directory names.
     */
    int free_pat = FALSE;
    int i;

    /* for ":set path=" and ":set tags=" halve backslashes for escaped
     * space */
    if (xp->xp_backslash != XP_BS_NONE) {
      free_pat = TRUE;
      pat = vim_strsave(pat);
      for (i = 0; pat[i]; ++i)
        if (pat[i] == '\\') {
          if (xp->xp_backslash == XP_BS_THREE
              && pat[i + 1] == '\\'
              && pat[i + 2] == '\\'
              && pat[i + 3] == ' ')
            STRMOVE(pat + i, pat + i + 3);
          if (xp->xp_backslash == XP_BS_ONE
              && pat[i + 1] == ' ')
            STRMOVE(pat + i, pat + i + 1);
        }
    }

    if (xp->xp_context == EXPAND_FILES)
      flags |= EW_FILE;
    else if (xp->xp_context == EXPAND_FILES_IN_PATH)
      flags |= (EW_FILE | EW_PATH);
    else
      flags = (flags | EW_DIR) & ~EW_FILE;
    if (options & WILD_ICASE)
      flags |= EW_ICASE;

    /* Expand wildcards, supporting %:h and the like. */
    ret = expand_wildcards_eval(&pat, num_file, file, flags);
    if (free_pat)
      vim_free(pat);
    return ret;
  }

  *file = (char_u **)"";
  *num_file = 0;
  if (xp->xp_context == EXPAND_HELP) {
    /* With an empty argument we would get all the help tags, which is
     * very slow.  Get matches for "help" instead. */
    if (find_help_tags(*pat == NUL ? (char_u *)"help" : pat,
            num_file, file, FALSE) == OK) {
      cleanup_help_tags(*num_file, *file);
      return OK;
    }
    return FAIL;
  }

  if (xp->xp_context == EXPAND_SHELLCMD)
    return expand_shellcmd(pat, num_file, file, flags);
  if (xp->xp_context == EXPAND_OLD_SETTING)
    return ExpandOldSetting(num_file, file);
  if (xp->xp_context == EXPAND_BUFFERS)
    return ExpandBufnames(pat, num_file, file, options);
  if (xp->xp_context == EXPAND_TAGS
      || xp->xp_context == EXPAND_TAGS_LISTFILES)
    return expand_tags(xp->xp_context == EXPAND_TAGS, pat, num_file, file);
  if (xp->xp_context == EXPAND_COLORS) {
    char *directories[] = {"colors", NULL};
    return ExpandRTDir(pat, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_COMPILER) {
    char *directories[] = {"compiler", NULL};
    return ExpandRTDir(pat, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_OWNSYNTAX) {
    char *directories[] = {"syntax", NULL};
    return ExpandRTDir(pat, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_FILETYPE) {
    char *directories[] = {"syntax", "indent", "ftplugin", NULL};
    return ExpandRTDir(pat, num_file, file, directories);
  }
  if (xp->xp_context == EXPAND_USER_LIST)
    return ExpandUserList(xp, num_file, file);

  regmatch.regprog = vim_regcomp(pat, p_magic ? RE_MAGIC : 0);
  if (regmatch.regprog == NULL)
    return FAIL;

  /* set ignore-case according to p_ic, p_scs and pat */
  regmatch.rm_ic = ignorecase(pat);

  if (xp->xp_context == EXPAND_SETTINGS
      || xp->xp_context == EXPAND_BOOL_SETTINGS)
    ret = ExpandSettings(xp, &regmatch, num_file, file);
  else if (xp->xp_context == EXPAND_MAPPINGS)
    ret = ExpandMappings(&regmatch, num_file, file);
  else if (xp->xp_context == EXPAND_USER_DEFINED)
    ret = ExpandUserDefined(xp, &regmatch, num_file, file);
  else {
    static struct expgen {
      int context;
      char_u      *((*func)(expand_T *, int));
      int ic;
      int escaped;
    } tab[] =
    {
      {EXPAND_COMMANDS, get_command_name, FALSE, TRUE},
      {EXPAND_BEHAVE, get_behave_arg, TRUE, TRUE},
      {EXPAND_HISTORY, get_history_arg, TRUE, TRUE},
      {EXPAND_USER_COMMANDS, get_user_commands, FALSE, TRUE},
      {EXPAND_USER_CMD_FLAGS, get_user_cmd_flags, FALSE, TRUE},
      {EXPAND_USER_NARGS, get_user_cmd_nargs, FALSE, TRUE},
      {EXPAND_USER_COMPLETE, get_user_cmd_complete, FALSE, TRUE},
      {EXPAND_USER_VARS, get_user_var_name, FALSE, TRUE},
      {EXPAND_FUNCTIONS, get_function_name, FALSE, TRUE},
      {EXPAND_USER_FUNC, get_user_func_name, FALSE, TRUE},
      {EXPAND_EXPRESSION, get_expr_name, FALSE, TRUE},
      {EXPAND_MENUS, get_menu_name, FALSE, TRUE},
      {EXPAND_MENUNAMES, get_menu_names, FALSE, TRUE},
      {EXPAND_SYNTAX, get_syntax_name, TRUE, TRUE},
      {EXPAND_SYNTIME, get_syntime_arg, TRUE, TRUE},
      {EXPAND_HIGHLIGHT, get_highlight_name, TRUE, TRUE},
      {EXPAND_EVENTS, get_event_name, TRUE, TRUE},
      {EXPAND_AUGROUP, get_augroup_name, TRUE, TRUE},
      {EXPAND_CSCOPE, get_cscope_name, TRUE, TRUE},
      {EXPAND_PROFILE, get_profile_name, TRUE, TRUE},
#ifdef HAVE_WORKING_LIBINTL
      {EXPAND_LANGUAGE, get_lang_arg, TRUE, FALSE},
      {EXPAND_LOCALES, get_locales, TRUE, FALSE},
#endif
      {EXPAND_ENV_VARS, get_env_name, TRUE, TRUE},
      {EXPAND_USER, get_users, TRUE, FALSE},
    };
    int i;

    /*
     * Find a context in the table and call the ExpandGeneric() with the
     * right function to do the expansion.
     */
    ret = FAIL;
    for (i = 0; i < (int)(sizeof(tab) / sizeof(struct expgen)); ++i)
      if (xp->xp_context == tab[i].context) {
        if (tab[i].ic)
          regmatch.rm_ic = TRUE;
        ret = ExpandGeneric(xp, &regmatch, num_file, file,
            tab[i].func, tab[i].escaped);
        break;
      }
  }

  vim_regfree(regmatch.regprog);

  return ret;
}

/*
 * Expand a list of names.
 *
 * Generic function for command line completion.  It calls a function to
 * obtain strings, one by one.	The strings are matched against a regexp
 * program.  Matching strings are copied into an array, which is returned.
 *
 * Returns OK when no problems encountered, FAIL for error (out of memory).
 */
int ExpandGeneric(xp, regmatch, num_file, file, func, escaped)
expand_T    *xp;
regmatch_T  *regmatch;
int         *num_file;
char_u      ***file;
char_u      *((*func)(expand_T *, int));
/* returns a string from the list */
int escaped;
{
  int i;
  int count = 0;
  int round;
  char_u      *str;

  /* do this loop twice:
   * round == 0: count the number of matching names
   * round == 1: copy the matching names into allocated memory
   */
  for (round = 0; round <= 1; ++round) {
    for (i = 0;; ++i) {
      str = (*func)(xp, i);
      if (str == NULL)              /* end of list */
        break;
      if (*str == NUL)              /* skip empty strings */
        continue;

      if (vim_regexec(regmatch, str, (colnr_T)0)) {
        if (round) {
          if (escaped)
            str = vim_strsave_escaped(str, (char_u *)" \t\\.");
          else
            str = vim_strsave(str);
          (*file)[count] = str;
          if (func == get_menu_names && str != NULL) {
            /* test for separator added by get_menu_names() */
            str += STRLEN(str) - 1;
            if (*str == '\001')
              *str = '.';
          }
        }
        ++count;
      }
    }
    if (round == 0) {
      if (count == 0)
        return OK;
      *num_file = count;
      *file = (char_u **)alloc((unsigned)(count * sizeof(char_u *)));
      if (*file == NULL) {
        *file = (char_u **)"";
        return FAIL;
      }
      count = 0;
    }
  }

  /* Sort the results.  Keep menu's in the specified order. */
  if (xp->xp_context != EXPAND_MENUNAMES && xp->xp_context != EXPAND_MENUS) {
    if (xp->xp_context == EXPAND_EXPRESSION
        || xp->xp_context == EXPAND_FUNCTIONS
        || xp->xp_context == EXPAND_USER_FUNC)
      /* <SNR> functions should be sorted to the end. */
      qsort((void *)*file, (size_t)*num_file, sizeof(char_u *),
          sort_func_compare);
    else
      sort_strings(*file, *num_file);
  }

  /* Reset the variables used for special highlight names expansion, so that
   * they don't show up when getting normal highlight names by ID. */
  reset_expand_highlight();

  return OK;
}

/*
 * Complete a shell command.
 * Returns FAIL or OK;
 */
static int 
expand_shellcmd (
    char_u *filepat,           /* pattern to match with command names */
    int *num_file,          /* return: number of matches */
    char_u ***file,            /* return: array with matches */
    int flagsarg                   /* EW_ flags */
)
{
  char_u      *pat;
  int i;
  char_u      *path;
  int mustfree = FALSE;
  garray_T ga;
  char_u      *buf = alloc(MAXPATHL);
  size_t l;
  char_u      *s, *e;
  int flags = flagsarg;
  int ret;

  if (buf == NULL)
    return FAIL;

  /* for ":set path=" and ":set tags=" halve backslashes for escaped
   * space */
  pat = vim_strsave(filepat);
  for (i = 0; pat[i]; ++i)
    if (pat[i] == '\\' && pat[i + 1] == ' ')
      STRMOVE(pat + i, pat + i + 1);

  flags |= EW_FILE | EW_EXEC;

  /* For an absolute name we don't use $PATH. */
  if (mch_is_full_name(pat))
    path = (char_u *)" ";
  else if ((pat[0] == '.' && (vim_ispathsep(pat[1])
                              || (pat[1] == '.' && vim_ispathsep(pat[2])))))
    path = (char_u *)".";
  else {
    path = vim_getenv((char_u *)"PATH", &mustfree);
    if (path == NULL)
      path = (char_u *)"";
  }

  /*
   * Go over all directories in $PATH.  Expand matches in that directory and
   * collect them in "ga".
   */
  ga_init2(&ga, (int)sizeof(char *), 10);
  for (s = path; *s != NUL; s = e) {
    if (*s == ' ')
      ++s;              /* Skip space used for absolute path name. */

    e = vim_strchr(s, ':');
    if (e == NULL)
      e = s + STRLEN(s);

    l = e - s;
    if (l > MAXPATHL - 5)
      break;
    vim_strncpy(buf, s, l);
    add_pathsep(buf);
    l = STRLEN(buf);
    vim_strncpy(buf + l, pat, MAXPATHL - 1 - l);

    /* Expand matches in one directory of $PATH. */
    ret = expand_wildcards(1, &buf, num_file, file, flags);
    if (ret == OK) {
      if (ga_grow(&ga, *num_file) == FAIL)
        FreeWild(*num_file, *file);
      else {
        for (i = 0; i < *num_file; ++i) {
          s = (*file)[i];
          if (STRLEN(s) > l) {
            /* Remove the path again. */
            STRMOVE(s, s + l);
            ((char_u **)ga.ga_data)[ga.ga_len++] = s;
          } else
            vim_free(s);
        }
        vim_free(*file);
      }
    }
    if (*e != NUL)
      ++e;
  }
  *file = ga.ga_data;
  *num_file = ga.ga_len;

  vim_free(buf);
  vim_free(pat);
  if (mustfree)
    vim_free(path);
  return OK;
}

typedef void *(*user_expand_func_T)(char_u *, int, char_u **, int);
static void * call_user_expand_func(user_expand_func_T user_expand_func,
                                    expand_T *xp, int *num_file,
                                    char_u ***file);

/*
 * Call "user_expand_func()" to invoke a user defined VimL function and return
 * the result (either a string or a List).
 */
static void * call_user_expand_func(user_expand_func, xp, num_file, file)
user_expand_func_T user_expand_func;
expand_T           *xp;
int                *num_file;
char_u             ***file;
{
  int keep = 0;
  char_u num[50];
  char_u      *args[3];
  int save_current_SID = current_SID;
  void        *ret;
  struct cmdline_info save_ccline;

  if (xp->xp_arg == NULL || xp->xp_arg[0] == '\0' || xp->xp_line == NULL)
    return NULL;
  *num_file = 0;
  *file = NULL;

  if (ccline.cmdbuff != NULL) {
    keep = ccline.cmdbuff[ccline.cmdlen];
    ccline.cmdbuff[ccline.cmdlen] = 0;
  }

  args[0] = vim_strnsave(xp->xp_pattern, xp->xp_pattern_len);
  args[1] = xp->xp_line;
  sprintf((char *)num, "%d", xp->xp_col);
  args[2] = num;

  /* Save the cmdline, we don't know what the function may do. */
  save_ccline = ccline;
  ccline.cmdbuff = NULL;
  ccline.cmdprompt = NULL;
  current_SID = xp->xp_scriptID;

  ret = user_expand_func(xp->xp_arg, 3, args, FALSE);

  ccline = save_ccline;
  current_SID = save_current_SID;
  if (ccline.cmdbuff != NULL)
    ccline.cmdbuff[ccline.cmdlen] = keep;

  vim_free(args[0]);
  return ret;
}

/*
 * Expand names with a function defined by the user.
 */
static int ExpandUserDefined(expand_T *xp, regmatch_T *regmatch, int *num_file, char_u ***file)
{
  char_u      *retstr;
  char_u      *s;
  char_u      *e;
  char_u keep;
  garray_T ga;

  retstr = call_user_expand_func(call_func_retstr, xp, num_file, file);
  if (retstr == NULL)
    return FAIL;

  ga_init2(&ga, (int)sizeof(char *), 3);
  for (s = retstr; *s != NUL; s = e) {
    e = vim_strchr(s, '\n');
    if (e == NULL)
      e = s + STRLEN(s);
    keep = *e;
    *e = 0;

    if (xp->xp_pattern[0] && vim_regexec(regmatch, s, (colnr_T)0) == 0) {
      *e = keep;
      if (*e != NUL)
        ++e;
      continue;
    }

    if (ga_grow(&ga, 1) == FAIL)
      break;

    ((char_u **)ga.ga_data)[ga.ga_len] = vim_strnsave(s, (int)(e - s));
    ++ga.ga_len;

    *e = keep;
    if (*e != NUL)
      ++e;
  }
  vim_free(retstr);
  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/*
 * Expand names with a list returned by a function defined by the user.
 */
static int ExpandUserList(expand_T *xp, int *num_file, char_u ***file)
{
  list_T      *retlist;
  listitem_T  *li;
  garray_T ga;

  retlist = call_user_expand_func(call_func_retlist, xp, num_file, file);
  if (retlist == NULL)
    return FAIL;

  ga_init2(&ga, (int)sizeof(char *), 3);
  /* Loop over the items in the list. */
  for (li = retlist->lv_first; li != NULL; li = li->li_next) {
    if (li->li_tv.v_type != VAR_STRING || li->li_tv.vval.v_string == NULL)
      continue;        /* Skip non-string items and empty strings */

    if (ga_grow(&ga, 1) == FAIL)
      break;

    ((char_u **)ga.ga_data)[ga.ga_len] =
      vim_strsave(li->li_tv.vval.v_string);
    ++ga.ga_len;
  }
  list_unref(retlist);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/*
 * Expand color scheme, compiler or filetype names:
 * 'runtimepath'/{dirnames}/{pat}.vim
 * "dirnames" is an array with one or more directory names.
 */
static int ExpandRTDir(char_u *pat, int *num_file, char_u ***file, char *dirnames[])
{
  char_u      *matches;
  char_u      *s;
  char_u      *e;
  garray_T ga;
  int i;
  int pat_len;

  *num_file = 0;
  *file = NULL;
  pat_len = (int)STRLEN(pat);
  ga_init2(&ga, (int)sizeof(char *), 10);

  for (i = 0; dirnames[i] != NULL; ++i) {
    s = alloc((unsigned)(STRLEN(dirnames[i]) + pat_len + 7));
    if (s == NULL) {
      ga_clear_strings(&ga);
      return FAIL;
    }
    sprintf((char *)s, "%s/%s*.vim", dirnames[i], pat);
    matches = globpath(p_rtp, s, 0);
    vim_free(s);
    if (matches == NULL)
      continue;

    for (s = matches; *s != NUL; s = e) {
      e = vim_strchr(s, '\n');
      if (e == NULL)
        e = s + STRLEN(s);
      if (ga_grow(&ga, 1) == FAIL)
        break;
      if (e - 4 > s && STRNICMP(e - 4, ".vim", 4) == 0) {
        for (s = e - 4; s > matches; mb_ptr_back(matches, s))
          if (*s == '\n' || vim_ispathsep(*s))
            break;
        ++s;
        ((char_u **)ga.ga_data)[ga.ga_len] =
          vim_strnsave(s, (int)(e - s - 4));
        ++ga.ga_len;
      }
      if (*e != NUL)
        ++e;
    }
    vim_free(matches);
  }
  if (ga.ga_len == 0)
    return FAIL;

  /* Sort and remove duplicates which can happen when specifying multiple
   * directories in dirnames. */
  remove_duplicates(&ga);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}


/*
 * Expand "file" for all comma-separated directories in "path".
 * Returns an allocated string with all matches concatenated, separated by
 * newlines.  Returns NULL for an error or no matches.
 */
char_u *globpath(char_u *path, char_u *file, int expand_options)
{
  expand_T xpc;
  char_u      *buf;
  garray_T ga;
  int i;
  int len;
  int num_p;
  char_u      **p;
  char_u      *cur = NULL;

  buf = alloc(MAXPATHL);
  if (buf == NULL)
    return NULL;

  ExpandInit(&xpc);
  xpc.xp_context = EXPAND_FILES;

  ga_init2(&ga, 1, 100);

  /* Loop over all entries in {path}. */
  while (*path != NUL) {
    /* Copy one item of the path to buf[] and concatenate the file name. */
    copy_option_part(&path, buf, MAXPATHL, ",");
    if (STRLEN(buf) + STRLEN(file) + 2 < MAXPATHL) {
      add_pathsep(buf);
      STRCAT(buf, file);
      if (ExpandFromContext(&xpc, buf, &num_p, &p,
              WILD_SILENT|expand_options) != FAIL && num_p > 0) {
        ExpandEscape(&xpc, buf, num_p, p, WILD_SILENT|expand_options);
        for (len = 0, i = 0; i < num_p; ++i)
          len += (int)STRLEN(p[i]) + 1;

        /* Concatenate new results to previous ones. */
        if (ga_grow(&ga, len) == OK) {
          cur = (char_u *)ga.ga_data + ga.ga_len;
          for (i = 0; i < num_p; ++i) {
            STRCPY(cur, p[i]);
            cur += STRLEN(p[i]);
            *cur++ = '\n';
          }
          ga.ga_len += len;
        }
        FreeWild(num_p, p);
      }
    }
  }
  if (cur != NULL)
    *--cur = 0;     /* Replace trailing newline with NUL */

  vim_free(buf);
  return (char_u *)ga.ga_data;
}



/*********************************
*  Command line history stuff	 *
*********************************/

/*
 * Translate a history character to the associated type number.
 */
static int hist_char2type(int c)
{
  if (c == ':')
    return HIST_CMD;
  if (c == '=')
    return HIST_EXPR;
  if (c == '@')
    return HIST_INPUT;
  if (c == '>')
    return HIST_DEBUG;
  return HIST_SEARCH;       /* must be '?' or '/' */
}

/*
 * Table of history names.
 * These names are used in :history and various hist...() functions.
 * It is sufficient to give the significant prefix of a history name.
 */

static char *(history_names[]) =
{
  "cmd",
  "search",
  "expr",
  "input",
  "debug",
  NULL
};

/*
 * Function given to ExpandGeneric() to obtain the possible first
 * arguments of the ":history command.
 */
static char_u *get_history_arg(expand_T *xp, int idx)
{
  static char_u compl[2] = { NUL, NUL };
  char *short_names = ":=@>?/";
  int short_names_count = (int)STRLEN(short_names);
  int history_name_count = sizeof(history_names) / sizeof(char *) - 1;

  if (idx < short_names_count) {
    compl[0] = (char_u)short_names[idx];
    return compl;
  }
  if (idx < short_names_count + history_name_count)
    return (char_u *)history_names[idx - short_names_count];
  if (idx == short_names_count + history_name_count)
    return (char_u *)"all";
  return NULL;
}

/*
 * init_history() - Initialize the command line history.
 * Also used to re-allocate the history when the size changes.
 */
void init_history(void)          {
  int newlen;               /* new length of history table */
  histentry_T *temp;
  int i;
  int j;
  int type;

  /*
   * If size of history table changed, reallocate it
   */
  newlen = (int)p_hi;
  if (newlen != hislen) {                       /* history length changed */
    for (type = 0; type < HIST_COUNT; ++type) {     /* adjust the tables */
      if (newlen) {
        temp = (histentry_T *)lalloc(
            (long_u)(newlen * sizeof(histentry_T)), TRUE);
        if (temp == NULL) {         /* out of memory! */
          if (type == 0) {          /* first one: just keep the old length */
            newlen = hislen;
            break;
          }
          /* Already changed one table, now we can only have zero
           * length for all tables. */
          newlen = 0;
          type = -1;
          continue;
        }
      } else
        temp = NULL;
      if (newlen == 0 || temp != NULL) {
        if (hisidx[type] < 0) {                 /* there are no entries yet */
          for (i = 0; i < newlen; ++i)
            clear_hist_entry(&temp[i]);
        } else if (newlen > hislen)   {         /* array becomes bigger */
          for (i = 0; i <= hisidx[type]; ++i)
            temp[i] = history[type][i];
          j = i;
          for (; i <= newlen - (hislen - hisidx[type]); ++i)
            clear_hist_entry(&temp[i]);
          for (; j < hislen; ++i, ++j)
            temp[i] = history[type][j];
        } else   {                              /* array becomes smaller or 0 */
          j = hisidx[type];
          for (i = newlen - 1;; --i) {
            if (i >= 0)                         /* copy newest entries */
              temp[i] = history[type][j];
            else                                /* remove older entries */
              vim_free(history[type][j].hisstr);
            if (--j < 0)
              j = hislen - 1;
            if (j == hisidx[type])
              break;
          }
          hisidx[type] = newlen - 1;
        }
        vim_free(history[type]);
        history[type] = temp;
      }
    }
    hislen = newlen;
  }
}

static void clear_hist_entry(histentry_T *hisptr)
{
  hisptr->hisnum = 0;
  hisptr->viminfo = FALSE;
  hisptr->hisstr = NULL;
}

/*
 * Check if command line 'str' is already in history.
 * If 'move_to_front' is TRUE, matching entry is moved to end of history.
 */
static int 
in_history (
    int type,
    char_u *str,
    int move_to_front,              /* Move the entry to the front if it exists */
    int sep,
    int writing                    /* ignore entries read from viminfo */
)
{
  int i;
  int last_i = -1;
  char_u  *p;

  if (hisidx[type] < 0)
    return FALSE;
  i = hisidx[type];
  do {
    if (history[type][i].hisstr == NULL)
      return FALSE;

    /* For search history, check that the separator character matches as
     * well. */
    p = history[type][i].hisstr;
    if (STRCMP(str, p) == 0
        && !(writing && history[type][i].viminfo)
        && (type != HIST_SEARCH || sep == p[STRLEN(p) + 1])) {
      if (!move_to_front)
        return TRUE;
      last_i = i;
      break;
    }
    if (--i < 0)
      i = hislen - 1;
  } while (i != hisidx[type]);

  if (last_i >= 0) {
    str = history[type][i].hisstr;
    while (i != hisidx[type]) {
      if (++i >= hislen)
        i = 0;
      history[type][last_i] = history[type][i];
      last_i = i;
    }
    history[type][i].hisnum = ++hisnum[type];
    history[type][i].viminfo = FALSE;
    history[type][i].hisstr = str;
    return TRUE;
  }
  return FALSE;
}

/*
 * Convert history name (from table above) to its HIST_ equivalent.
 * When "name" is empty, return "cmd" history.
 * Returns -1 for unknown history name.
 */
int get_histtype(char_u *name)
{
  int i;
  int len = (int)STRLEN(name);

  /* No argument: use current history. */
  if (len == 0)
    return hist_char2type(ccline.cmdfirstc);

  for (i = 0; history_names[i] != NULL; ++i)
    if (STRNICMP(name, history_names[i], len) == 0)
      return i;

  if (vim_strchr((char_u *)":=@>?/", name[0]) != NULL && name[1] == NUL)
    return hist_char2type(name[0]);

  return -1;
}

static int last_maptick = -1;           /* last seen maptick */

/*
 * Add the given string to the given history.  If the string is already in the
 * history then it is moved to the front.  "histype" may be one of he HIST_
 * values.
 */
void 
add_to_history (
    int histype,
    char_u *new_entry,
    int in_map,                     /* consider maptick when inside a mapping */
    int sep                        /* separator character used (search hist) */
)
{
  histentry_T *hisptr;
  int len;

  if (hislen == 0)              /* no history */
    return;

  if (cmdmod.keeppatterns && histype == HIST_SEARCH)
    return;

  /*
   * Searches inside the same mapping overwrite each other, so that only
   * the last line is kept.  Be careful not to remove a line that was moved
   * down, only lines that were added.
   */
  if (histype == HIST_SEARCH && in_map) {
    if (maptick == last_maptick) {
      /* Current line is from the same mapping, remove it */
      hisptr = &history[HIST_SEARCH][hisidx[HIST_SEARCH]];
      vim_free(hisptr->hisstr);
      clear_hist_entry(hisptr);
      --hisnum[histype];
      if (--hisidx[HIST_SEARCH] < 0)
        hisidx[HIST_SEARCH] = hislen - 1;
    }
    last_maptick = -1;
  }
  if (!in_history(histype, new_entry, TRUE, sep, FALSE)) {
    if (++hisidx[histype] == hislen)
      hisidx[histype] = 0;
    hisptr = &history[histype][hisidx[histype]];
    vim_free(hisptr->hisstr);

    /* Store the separator after the NUL of the string. */
    len = (int)STRLEN(new_entry);
    hisptr->hisstr = vim_strnsave(new_entry, len + 2);
    if (hisptr->hisstr != NULL)
      hisptr->hisstr[len + 1] = sep;

    hisptr->hisnum = ++hisnum[histype];
    hisptr->viminfo = FALSE;
    if (histype == HIST_SEARCH && in_map)
      last_maptick = maptick;
  }
}


/*
 * Get identifier of newest history entry.
 * "histype" may be one of the HIST_ values.
 */
int get_history_idx(int histype)
{
  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || hisidx[histype] < 0)
    return -1;

  return history[histype][hisidx[histype]].hisnum;
}

static struct cmdline_info *get_ccline_ptr(void);

/*
 * Get pointer to the command line info to use. cmdline_paste() may clear
 * ccline and put the previous value in prev_ccline.
 */
static struct cmdline_info *get_ccline_ptr(void)
{
  if ((State & CMDLINE) == 0)
    return NULL;
  if (ccline.cmdbuff != NULL)
    return &ccline;
  if (prev_ccline_used && prev_ccline.cmdbuff != NULL)
    return &prev_ccline;
  return NULL;
}

/*
 * Get the current command line in allocated memory.
 * Only works when the command line is being edited.
 * Returns NULL when something is wrong.
 */
char_u *get_cmdline_str(void)              {
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return NULL;
  return vim_strnsave(p->cmdbuff, p->cmdlen);
}

/*
 * Get the current command line position, counted in bytes.
 * Zero is the first position.
 * Only works when the command line is being edited.
 * Returns -1 when something is wrong.
 */
int get_cmdline_pos(void)         {
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return -1;
  return p->cmdpos;
}

/*
 * Set the command line byte position to "pos".  Zero is the first position.
 * Only works when the command line is being edited.
 * Returns 1 when failed, 0 when OK.
 */
int set_cmdline_pos(int pos)
{
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return 1;

  /* The position is not set directly but after CTRL-\ e or CTRL-R = has
   * changed the command line. */
  if (pos < 0)
    new_cmdpos = 0;
  else
    new_cmdpos = pos;
  return 0;
}

/*
 * Get the current command-line type.
 * Returns ':' or '/' or '?' or '@' or '>' or '-'
 * Only works when the command line is being edited.
 * Returns NUL when something is wrong.
 */
int get_cmdline_type(void)         {
  struct cmdline_info *p = get_ccline_ptr();

  if (p == NULL)
    return NUL;
  if (p->cmdfirstc == NUL)
    return (p->input_fn) ? '@' : '-';
  return p->cmdfirstc;
}

/*
 * Calculate history index from a number:
 *   num > 0: seen as identifying number of a history entry
 *   num < 0: relative position in history wrt newest entry
 * "histype" may be one of the HIST_ values.
 */
static int calc_hist_idx(int histype, int num)
{
  int i;
  histentry_T *hist;
  int wrapped = FALSE;

  if (hislen == 0 || histype < 0 || histype >= HIST_COUNT
      || (i = hisidx[histype]) < 0 || num == 0)
    return -1;

  hist = history[histype];
  if (num > 0) {
    while (hist[i].hisnum > num)
      if (--i < 0) {
        if (wrapped)
          break;
        i += hislen;
        wrapped = TRUE;
      }
    if (hist[i].hisnum == num && hist[i].hisstr != NULL)
      return i;
  } else if (-num <= hislen)   {
    i += num + 1;
    if (i < 0)
      i += hislen;
    if (hist[i].hisstr != NULL)
      return i;
  }
  return -1;
}

/*
 * Get a history entry by its index.
 * "histype" may be one of the HIST_ values.
 */
char_u *get_history_entry(int histype, int idx)
{
  idx = calc_hist_idx(histype, idx);
  if (idx >= 0)
    return history[histype][idx].hisstr;
  else
    return (char_u *)"";
}

/*
 * Clear all entries of a history.
 * "histype" may be one of the HIST_ values.
 */
int clr_history(int histype)
{
  int i;
  histentry_T *hisptr;

  if (hislen != 0 && histype >= 0 && histype < HIST_COUNT) {
    hisptr = history[histype];
    for (i = hislen; i--; ) {
      vim_free(hisptr->hisstr);
      clear_hist_entry(hisptr);
    }
    hisidx[histype] = -1;       /* mark history as cleared */
    hisnum[histype] = 0;        /* reset identifier counter */
    return OK;
  }
  return FAIL;
}

/*
 * Remove all entries matching {str} from a history.
 * "histype" may be one of the HIST_ values.
 */
int del_history_entry(int histype, char_u *str)
{
  regmatch_T regmatch;
  histentry_T *hisptr;
  int idx;
  int i;
  int last;
  int found = FALSE;

  regmatch.regprog = NULL;
  regmatch.rm_ic = FALSE;       /* always match case */
  if (hislen != 0
      && histype >= 0
      && histype < HIST_COUNT
      && *str != NUL
      && (idx = hisidx[histype]) >= 0
      && (regmatch.regprog = vim_regcomp(str, RE_MAGIC + RE_STRING))
      != NULL) {
    i = last = idx;
    do {
      hisptr = &history[histype][i];
      if (hisptr->hisstr == NULL)
        break;
      if (vim_regexec(&regmatch, hisptr->hisstr, (colnr_T)0)) {
        found = TRUE;
        vim_free(hisptr->hisstr);
        clear_hist_entry(hisptr);
      } else   {
        if (i != last) {
          history[histype][last] = *hisptr;
          clear_hist_entry(hisptr);
        }
        if (--last < 0)
          last += hislen;
      }
      if (--i < 0)
        i += hislen;
    } while (i != idx);
    if (history[histype][idx].hisstr == NULL)
      hisidx[histype] = -1;
  }
  vim_regfree(regmatch.regprog);
  return found;
}

/*
 * Remove an indexed entry from a history.
 * "histype" may be one of the HIST_ values.
 */
int del_history_idx(int histype, int idx)
{
  int i, j;

  i = calc_hist_idx(histype, idx);
  if (i < 0)
    return FALSE;
  idx = hisidx[histype];
  vim_free(history[histype][i].hisstr);

  /* When deleting the last added search string in a mapping, reset
   * last_maptick, so that the last added search string isn't deleted again.
   */
  if (histype == HIST_SEARCH && maptick == last_maptick && i == idx)
    last_maptick = -1;

  while (i != idx) {
    j = (i + 1) % hislen;
    history[histype][i] = history[histype][j];
    i = j;
  }
  clear_hist_entry(&history[histype][i]);
  if (--i < 0)
    i += hislen;
  hisidx[histype] = i;
  return TRUE;
}


/*
 * Very specific function to remove the value in ":set key=val" from the
 * history.
 */
void remove_key_from_history(void)          {
  char_u      *p;
  int i;

  i = hisidx[HIST_CMD];
  if (i < 0)
    return;
  p = history[HIST_CMD][i].hisstr;
  if (p != NULL)
    for (; *p; ++p)
      if (STRNCMP(p, "key", 3) == 0 && !isalpha(p[3])) {
        p = vim_strchr(p + 3, '=');
        if (p == NULL)
          break;
        ++p;
        for (i = 0; p[i] && !vim_iswhite(p[i]); ++i)
          if (p[i] == '\\' && p[i + 1])
            ++i;
        STRMOVE(p, p + i);
        --p;
      }
}

/*
 * Get indices "num1,num2" that specify a range within a list (not a range of
 * text lines in a buffer!) from a string.  Used for ":history" and ":clist".
 * Returns OK if parsed successfully, otherwise FAIL.
 */
int get_list_range(char_u **str, int *num1, int *num2)
{
  int len;
  int first = FALSE;
  long num;

  *str = skipwhite(*str);
  if (**str == '-' || vim_isdigit(**str)) {  /* parse "from" part of range */
    vim_str2nr(*str, NULL, &len, FALSE, FALSE, &num, NULL);
    *str += len;
    *num1 = (int)num;
    first = TRUE;
  }
  *str = skipwhite(*str);
  if (**str == ',') {                   /* parse "to" part of range */
    *str = skipwhite(*str + 1);
    vim_str2nr(*str, NULL, &len, FALSE, FALSE, &num, NULL);
    if (len > 0) {
      *num2 = (int)num;
      *str = skipwhite(*str + len);
    } else if (!first)                  /* no number given at all */
      return FAIL;
  } else if (first)                     /* only one number given */
    *num2 = *num1;
  return OK;
}

/*
 * :history command - print a history
 */
void ex_history(exarg_T *eap)
{
  histentry_T *hist;
  int histype1 = HIST_CMD;
  int histype2 = HIST_CMD;
  int hisidx1 = 1;
  int hisidx2 = -1;
  int idx;
  int i, j, k;
  char_u      *end;
  char_u      *arg = eap->arg;

  if (hislen == 0) {
    MSG(_("'history' option is zero"));
    return;
  }

  if (!(VIM_ISDIGIT(*arg) || *arg == '-' || *arg == ',')) {
    end = arg;
    while (ASCII_ISALPHA(*end)
           || vim_strchr((char_u *)":=@>/?", *end) != NULL)
      end++;
    i = *end;
    *end = NUL;
    histype1 = get_histtype(arg);
    if (histype1 == -1) {
      if (STRNICMP(arg, "all", STRLEN(arg)) == 0) {
        histype1 = 0;
        histype2 = HIST_COUNT-1;
      } else   {
        *end = i;
        EMSG(_(e_trailing));
        return;
      }
    } else
      histype2 = histype1;
    *end = i;
  } else
    end = arg;
  if (!get_list_range(&end, &hisidx1, &hisidx2) || *end != NUL) {
    EMSG(_(e_trailing));
    return;
  }

  for (; !got_int && histype1 <= histype2; ++histype1) {
    STRCPY(IObuff, "\n      #  ");
    STRCAT(STRCAT(IObuff, history_names[histype1]), " history");
    MSG_PUTS_TITLE(IObuff);
    idx = hisidx[histype1];
    hist = history[histype1];
    j = hisidx1;
    k = hisidx2;
    if (j < 0)
      j = (-j > hislen) ? 0 : hist[(hislen+j+idx+1) % hislen].hisnum;
    if (k < 0)
      k = (-k > hislen) ? 0 : hist[(hislen+k+idx+1) % hislen].hisnum;
    if (idx >= 0 && j <= k)
      for (i = idx + 1; !got_int; ++i) {
        if (i == hislen)
          i = 0;
        if (hist[i].hisstr != NULL
            && hist[i].hisnum >= j && hist[i].hisnum <= k) {
          msg_putchar('\n');
          sprintf((char *)IObuff, "%c%6d  ", i == idx ? '>' : ' ',
              hist[i].hisnum);
          if (vim_strsize(hist[i].hisstr) > (int)Columns - 10)
            trunc_string(hist[i].hisstr, IObuff + STRLEN(IObuff),
                (int)Columns - 10, IOSIZE - (int)STRLEN(IObuff));
          else
            STRCAT(IObuff, hist[i].hisstr);
          msg_outtrans(IObuff);
          out_flush();
        }
        if (i == idx)
          break;
      }
  }
}

/*
 * Buffers for history read from a viminfo file.  Only valid while reading.
 */
static char_u **viminfo_history[HIST_COUNT] = {NULL, NULL, NULL, NULL};
static int viminfo_hisidx[HIST_COUNT] = {0, 0, 0, 0};
static int viminfo_hislen[HIST_COUNT] = {0, 0, 0, 0};
static int viminfo_add_at_front = FALSE;

static int hist_type2char(int type, int use_question);

/*
 * Translate a history type number to the associated character.
 */
static int 
hist_type2char (
    int type,
    int use_question                   /* use '?' instead of '/' */
)
{
  if (type == HIST_CMD)
    return ':';
  if (type == HIST_SEARCH) {
    if (use_question)
      return '?';
    else
      return '/';
  }
  if (type == HIST_EXPR)
    return '=';
  return '@';
}

/*
 * Prepare for reading the history from the viminfo file.
 * This allocates history arrays to store the read history lines.
 */
void prepare_viminfo_history(int asklen, int writing)
{
  int i;
  int num;
  int type;
  int len;

  init_history();
  viminfo_add_at_front = (asklen != 0 && !writing);
  if (asklen > hislen)
    asklen = hislen;

  for (type = 0; type < HIST_COUNT; ++type) {
    /* Count the number of empty spaces in the history list.  Entries read
     * from viminfo previously are also considered empty.  If there are
     * more spaces available than we request, then fill them up. */
    for (i = 0, num = 0; i < hislen; i++)
      if (history[type][i].hisstr == NULL || history[type][i].viminfo)
        num++;
    len = asklen;
    if (num > len)
      len = num;
    if (len <= 0)
      viminfo_history[type] = NULL;
    else
      viminfo_history[type] =
        (char_u **)lalloc((long_u)(len * sizeof(char_u *)), FALSE);
    if (viminfo_history[type] == NULL)
      len = 0;
    viminfo_hislen[type] = len;
    viminfo_hisidx[type] = 0;
  }
}

/*
 * Accept a line from the viminfo, store it in the history array when it's
 * new.
 */
int read_viminfo_history(vir_T *virp, int writing)
{
  int type;
  long_u len;
  char_u      *val;
  char_u      *p;

  type = hist_char2type(virp->vir_line[0]);
  if (viminfo_hisidx[type] < viminfo_hislen[type]) {
    val = viminfo_readstring(virp, 1, TRUE);
    if (val != NULL && *val != NUL) {
      int sep = (*val == ' ' ? NUL : *val);

      if (!in_history(type, val + (type == HIST_SEARCH),
              viminfo_add_at_front, sep, writing)) {
        /* Need to re-allocate to append the separator byte. */
        len = STRLEN(val);
        p = lalloc(len + 2, TRUE);
        if (p != NULL) {
          if (type == HIST_SEARCH) {
            /* Search entry: Move the separator from the first
             * column to after the NUL. */
            mch_memmove(p, val + 1, (size_t)len);
            p[len] = sep;
          } else   {
            /* Not a search entry: No separator in the viminfo
             * file, add a NUL separator. */
            mch_memmove(p, val, (size_t)len + 1);
            p[len + 1] = NUL;
          }
          viminfo_history[type][viminfo_hisidx[type]++] = p;
        }
      }
    }
    vim_free(val);
  }
  return viminfo_readline(virp);
}

/*
 * Finish reading history lines from viminfo.  Not used when writing viminfo.
 */
void finish_viminfo_history(void)          {
  int idx;
  int i;
  int type;

  for (type = 0; type < HIST_COUNT; ++type) {
    if (history[type] == NULL)
      continue;
    idx = hisidx[type] + viminfo_hisidx[type];
    if (idx >= hislen)
      idx -= hislen;
    else if (idx < 0)
      idx = hislen - 1;
    if (viminfo_add_at_front)
      hisidx[type] = idx;
    else {
      if (hisidx[type] == -1)
        hisidx[type] = hislen - 1;
      do {
        if (history[type][idx].hisstr != NULL
            || history[type][idx].viminfo)
          break;
        if (++idx == hislen)
          idx = 0;
      } while (idx != hisidx[type]);
      if (idx != hisidx[type] && --idx < 0)
        idx = hislen - 1;
    }
    for (i = 0; i < viminfo_hisidx[type]; i++) {
      vim_free(history[type][idx].hisstr);
      history[type][idx].hisstr = viminfo_history[type][i];
      history[type][idx].viminfo = TRUE;
      if (--idx < 0)
        idx = hislen - 1;
    }
    idx += 1;
    idx %= hislen;
    for (i = 0; i < viminfo_hisidx[type]; i++) {
      history[type][idx++].hisnum = ++hisnum[type];
      idx %= hislen;
    }
    vim_free(viminfo_history[type]);
    viminfo_history[type] = NULL;
    viminfo_hisidx[type] = 0;
  }
}

/*
 * Write history to viminfo file in "fp".
 * When "merge" is TRUE merge history lines with a previously read viminfo
 * file, data is in viminfo_history[].
 * When "merge" is FALSE just write all history lines.  Used for ":wviminfo!".
 */
void write_viminfo_history(FILE *fp, int merge)
{
  int i;
  int type;
  int num_saved;
  char_u  *p;
  int c;
  int round;

  init_history();
  if (hislen == 0)
    return;
  for (type = 0; type < HIST_COUNT; ++type) {
    num_saved = get_viminfo_parameter(hist_type2char(type, FALSE));
    if (num_saved == 0)
      continue;
    if (num_saved < 0)      /* Use default */
      num_saved = hislen;
    fprintf(fp, _("\n# %s History (newest to oldest):\n"),
        type == HIST_CMD ? _("Command Line") :
        type == HIST_SEARCH ? _("Search String") :
        type == HIST_EXPR ?  _("Expression") :
        _("Input Line"));
    if (num_saved > hislen)
      num_saved = hislen;

    /*
     * Merge typed and viminfo history:
     * round 1: history of typed commands.
     * round 2: history from recently read viminfo.
     */
    for (round = 1; round <= 2; ++round) {
      if (round == 1)
        /* start at newest entry, somewhere in the list */
        i = hisidx[type];
      else if (viminfo_hisidx[type] > 0)
        /* start at newest entry, first in the list */
        i = 0;
      else
        /* empty list */
        i = -1;
      if (i >= 0)
        while (num_saved > 0
               && !(round == 2 && i >= viminfo_hisidx[type])) {
          p = round == 1 ? history[type][i].hisstr
              : viminfo_history[type] == NULL ? NULL
              : viminfo_history[type][i];
          if (p != NULL && (round == 2
                            || !merge
                            || !history[type][i].viminfo)) {
            --num_saved;
            fputc(hist_type2char(type, TRUE), fp);
            /* For the search history: put the separator in the
            * second column; use a space if there isn't one. */
            if (type == HIST_SEARCH) {
              c = p[STRLEN(p) + 1];
              putc(c == NUL ? ' ' : c, fp);
            }
            viminfo_writestring(fp, p);
          }
          if (round == 1) {
            /* Decrement index, loop around and stop when back at
             * the start. */
            if (--i < 0)
              i = hislen - 1;
            if (i == hisidx[type])
              break;
          } else   {
            /* Increment index. Stop at the end in the while. */
            ++i;
          }
        }
    }
    for (i = 0; i < viminfo_hisidx[type]; ++i)
      if (viminfo_history[type] != NULL)
        vim_free(viminfo_history[type][i]);
    vim_free(viminfo_history[type]);
    viminfo_history[type] = NULL;
    viminfo_hisidx[type] = 0;
  }
}

/*
 * Write a character at the current cursor+offset position.
 * It is directly written into the command buffer block.
 */
void cmd_pchar(int c, int offset)
{
  if (ccline.cmdpos + offset >= ccline.cmdlen || ccline.cmdpos + offset < 0) {
    EMSG(_("E198: cmd_pchar beyond the command length"));
    return;
  }
  ccline.cmdbuff[ccline.cmdpos + offset] = (char_u)c;
  ccline.cmdbuff[ccline.cmdlen] = NUL;
}

int cmd_gchar(int offset)
{
  if (ccline.cmdpos + offset >= ccline.cmdlen || ccline.cmdpos + offset < 0) {
    /*  EMSG(_("cmd_gchar beyond the command length")); */
    return NUL;
  }
  return (int)ccline.cmdbuff[ccline.cmdpos + offset];
}

/*
 * Open a window on the current command line and history.  Allow editing in
 * the window.  Returns when the window is closed.
 * Returns:
 *	CR	 if the command is to be executed
 *	Ctrl_C	 if it is to be abandoned
 *	K_IGNORE if editing continues
 */
static int ex_window(void)                {
  struct cmdline_info save_ccline;
  buf_T               *old_curbuf = curbuf;
  win_T               *old_curwin = curwin;
  buf_T               *bp;
  win_T               *wp;
  int i;
  linenr_T lnum;
  int histtype;
  garray_T winsizes;
  char_u typestr[2];
  int save_restart_edit = restart_edit;
  int save_State = State;
  int save_exmode = exmode_active;
  int save_cmdmsg_rl = cmdmsg_rl;

  /* Can't do this recursively.  Can't do it when typing a password. */
  if (cmdwin_type != 0
      || cmdline_star > 0
      ) {
    beep_flush();
    return K_IGNORE;
  }

  /* Save current window sizes. */
  win_size_save(&winsizes);

  /* Don't execute autocommands while creating the window. */
  block_autocmds();
  /* don't use a new tab page */
  cmdmod.tab = 0;

  /* Create a window for the command-line buffer. */
  if (win_split((int)p_cwh, WSP_BOT) == FAIL) {
    beep_flush();
    unblock_autocmds();
    return K_IGNORE;
  }
  cmdwin_type = get_cmdline_type();

  /* Create the command-line buffer empty. */
  (void)do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, ECMD_HIDE, NULL);
  (void)setfname(curbuf, (char_u *)"[Command Line]", NULL, TRUE);
  set_option_value((char_u *)"bt", 0L, (char_u *)"nofile", OPT_LOCAL);
  set_option_value((char_u *)"swf", 0L, NULL, OPT_LOCAL);
  curbuf->b_p_ma = TRUE;
  curwin->w_p_fen = FALSE;
  curwin->w_p_rl = cmdmsg_rl;
  cmdmsg_rl = FALSE;
  RESET_BINDING(curwin);

  /* Do execute autocommands for setting the filetype (load syntax). */
  unblock_autocmds();

  /* Showing the prompt may have set need_wait_return, reset it. */
  need_wait_return = FALSE;

  histtype = hist_char2type(cmdwin_type);
  if (histtype == HIST_CMD || histtype == HIST_DEBUG) {
    if (p_wc == TAB) {
      add_map((char_u *)"<buffer> <Tab> <C-X><C-V>", INSERT);
      add_map((char_u *)"<buffer> <Tab> a<C-X><C-V>", NORMAL);
    }
    set_option_value((char_u *)"ft", 0L, (char_u *)"vim", OPT_LOCAL);
  }

  /* Reset 'textwidth' after setting 'filetype' (the Vim filetype plugin
   * sets 'textwidth' to 78). */
  curbuf->b_p_tw = 0;

  /* Fill the buffer with the history. */
  init_history();
  if (hislen > 0) {
    i = hisidx[histtype];
    if (i >= 0) {
      lnum = 0;
      do {
        if (++i == hislen)
          i = 0;
        if (history[histtype][i].hisstr != NULL)
          ml_append(lnum++, history[histtype][i].hisstr,
              (colnr_T)0, FALSE);
      } while (i != hisidx[histtype]);
    }
  }

  /* Replace the empty last line with the current command-line and put the
   * cursor there. */
  ml_replace(curbuf->b_ml.ml_line_count, ccline.cmdbuff, TRUE);
  curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  curwin->w_cursor.col = ccline.cmdpos;
  changed_line_abv_curs();
  invalidate_botline();
  redraw_later(SOME_VALID);

  /* Save the command line info, can be used recursively. */
  save_ccline = ccline;
  ccline.cmdbuff = NULL;
  ccline.cmdprompt = NULL;

  /* No Ex mode here! */
  exmode_active = 0;

  State = NORMAL;
  setmouse();

  /* Trigger CmdwinEnter autocommands. */
  typestr[0] = cmdwin_type;
  typestr[1] = NUL;
  apply_autocmds(EVENT_CMDWINENTER, typestr, typestr, FALSE, curbuf);
  if (restart_edit != 0)        /* autocmd with ":startinsert" */
    stuffcharReadbuff(K_NOP);

  i = RedrawingDisabled;
  RedrawingDisabled = 0;

  /*
   * Call the main loop until <CR> or CTRL-C is typed.
   */
  cmdwin_result = 0;
  main_loop(TRUE, FALSE);

  RedrawingDisabled = i;

  /* Trigger CmdwinLeave autocommands. */
  apply_autocmds(EVENT_CMDWINLEAVE, typestr, typestr, FALSE, curbuf);

  /* Restore the command line info. */
  ccline = save_ccline;
  cmdwin_type = 0;

  exmode_active = save_exmode;

  /* Safety check: The old window or buffer was deleted: It's a bug when
   * this happens! */
  if (!win_valid(old_curwin) || !buf_valid(old_curbuf)) {
    cmdwin_result = Ctrl_C;
    EMSG(_("E199: Active window or buffer deleted"));
  } else   {
    /* autocmds may abort script processing */
    if (aborting() && cmdwin_result != K_IGNORE)
      cmdwin_result = Ctrl_C;
    /* Set the new command line from the cmdline buffer. */
    vim_free(ccline.cmdbuff);
    if (cmdwin_result == K_XF1 || cmdwin_result == K_XF2) {   /* :qa[!] typed */
      char *p = (cmdwin_result == K_XF2) ? "qa" : "qa!";

      if (histtype == HIST_CMD) {
        /* Execute the command directly. */
        ccline.cmdbuff = vim_strsave((char_u *)p);
        cmdwin_result = CAR;
      } else   {
        /* First need to cancel what we were doing. */
        ccline.cmdbuff = NULL;
        stuffcharReadbuff(':');
        stuffReadbuff((char_u *)p);
        stuffcharReadbuff(CAR);
      }
    } else if (cmdwin_result == K_XF2)   {      /* :qa typed */
      ccline.cmdbuff = vim_strsave((char_u *)"qa");
      cmdwin_result = CAR;
    } else if (cmdwin_result == Ctrl_C)   {
      /* :q or :close, don't execute any command
       * and don't modify the cmd window. */
      ccline.cmdbuff = NULL;
    } else
      ccline.cmdbuff = vim_strsave(ml_get_curline());
    if (ccline.cmdbuff == NULL)
      cmdwin_result = Ctrl_C;
    else {
      ccline.cmdlen = (int)STRLEN(ccline.cmdbuff);
      ccline.cmdbufflen = ccline.cmdlen + 1;
      ccline.cmdpos = curwin->w_cursor.col;
      if (ccline.cmdpos > ccline.cmdlen)
        ccline.cmdpos = ccline.cmdlen;
      if (cmdwin_result == K_IGNORE) {
        set_cmdspos_cursor();
        redrawcmd();
      }
    }

    /* Don't execute autocommands while deleting the window. */
    block_autocmds();
    wp = curwin;
    bp = curbuf;
    win_goto(old_curwin);
    win_close(wp, TRUE);

    /* win_close() may have already wiped the buffer when 'bh' is
     * set to 'wipe' */
    if (buf_valid(bp))
      close_buffer(NULL, bp, DOBUF_WIPE, FALSE);

    /* Restore window sizes. */
    win_size_restore(&winsizes);

    unblock_autocmds();
  }

  ga_clear(&winsizes);
  restart_edit = save_restart_edit;
  cmdmsg_rl = save_cmdmsg_rl;

  State = save_State;
  setmouse();

  return cmdwin_result;
}

/*
 * Used for commands that either take a simple command string argument, or:
 *	cmd << endmarker
 *	  {script}
 *	endmarker
 * Returns a pointer to allocated memory with {script} or NULL.
 */
char_u *script_get(exarg_T *eap, char_u *cmd)
{
  char_u      *theline;
  char        *end_pattern = NULL;
  char dot[] = ".";
  garray_T ga;

  if (cmd[0] != '<' || cmd[1] != '<' || eap->getline == NULL)
    return NULL;

  ga_init2(&ga, 1, 0x400);

  if (cmd[2] != NUL)
    end_pattern = (char *)skipwhite(cmd + 2);
  else
    end_pattern = dot;

  for (;; ) {
    theline = eap->getline(
        eap->cstack->cs_looplevel > 0 ? -1 :
        NUL, eap->cookie, 0);

    if (theline == NULL || STRCMP(end_pattern, theline) == 0) {
      vim_free(theline);
      break;
    }

    ga_concat(&ga, theline);
    ga_append(&ga, '\n');
    vim_free(theline);
  }
  ga_append(&ga, NUL);

  return (char_u *)ga.ga_data;
}
