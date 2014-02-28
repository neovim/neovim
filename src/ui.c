/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ui.c: functions that handle the user interface.
 * 1. Keyboard input stuff, and a bit of windowing stuff.  These are called
 *    before the machine specific stuff (mch_*) so that we can call the GUI
 *    stuff instead if the GUI is running.
 * 2. Clipboard stuff.
 * 3. Input buffer stuff.
 */

#include "vim.h"
#include "ui.h"
#include "diff.h"
#include "ex_cmds2.h"
#include "fold.h"
#include "main.h"
#include "mbyte.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "screen.h"
#include "term.h"
#include "window.h"

void ui_write(char_u *s, int len)
{
#ifndef NO_CONSOLE
  /* Don't output anything in silent mode ("ex -s") unless 'verbose' set */
  if (!(silent_mode && p_verbose == 0)) {
    char_u  *tofree = NULL;

    if (output_conv.vc_type != CONV_NONE) {
      /* Convert characters from 'encoding' to 'termencoding'. */
      tofree = string_convert(&output_conv, s, &len);
      if (tofree != NULL)
        s = tofree;
    }

    mch_write(s, len);

    if (output_conv.vc_type != CONV_NONE)
      vim_free(tofree);
  }
#endif
}

#if defined(UNIX) || defined(VMS) || defined(PROTO) || defined(WIN3264)
/*
 * When executing an external program, there may be some typed characters that
 * are not consumed by it.  Give them back to ui_inchar() and they are stored
 * here for the next call.
 */
static char_u *ta_str = NULL;
static int ta_off;      /* offset for next char to use when ta_str != NULL */
static int ta_len;      /* length of ta_str when it's not NULL*/

void ui_inchar_undo(char_u *s, int len)
{
  char_u  *new;
  int newlen;

  newlen = len;
  if (ta_str != NULL)
    newlen += ta_len - ta_off;
  new = alloc(newlen);
  if (new != NULL) {
    if (ta_str != NULL) {
      mch_memmove(new, ta_str + ta_off, (size_t)(ta_len - ta_off));
      mch_memmove(new + ta_len - ta_off, s, (size_t)len);
      vim_free(ta_str);
    } else
      mch_memmove(new, s, (size_t)len);
    ta_str = new;
    ta_len = newlen;
    ta_off = 0;
  }
}
#endif

/*
 * ui_inchar(): low level input function.
 * Get characters from the keyboard.
 * Return the number of characters that are available.
 * If "wtime" == 0 do not wait for characters.
 * If "wtime" == -1 wait forever for characters.
 * If "wtime" > 0 wait "wtime" milliseconds for a character.
 *
 * "tb_change_cnt" is the value of typebuf.tb_change_cnt if "buf" points into
 * it.  When typebuf.tb_change_cnt changes (e.g., when a message is received
 * from a remote client) "buf" can no longer be used.  "tb_change_cnt" is NULL
 * otherwise.
 */
int 
ui_inchar (
    char_u *buf,
    int maxlen,
    long wtime,                 /* don't use "time", MIPS cannot handle it */
    int tb_change_cnt
)
{
  int retval = 0;


  if (do_profiling == PROF_YES && wtime != 0)
    prof_inchar_enter();

#ifdef NO_CONSOLE_INPUT
  /* Don't wait for character input when the window hasn't been opened yet.
   * Do try reading, this works when redirecting stdin from a file.
   * Must return something, otherwise we'll loop forever.  If we run into
   * this very often we probably got stuck, exit Vim. */
  if (no_console_input()) {
    static int count = 0;

# ifndef NO_CONSOLE
    retval = mch_inchar(buf, maxlen, (wtime >= 0 && wtime < 10)
        ? 10L : wtime, tb_change_cnt);
    if (retval > 0 || typebuf_changed(tb_change_cnt) || wtime >= 0)
      goto theend;
# endif
    if (wtime == -1 && ++count == 1000)
      read_error_exit();
    buf[0] = CAR;
    retval = 1;
    goto theend;
  }
#endif

  /* If we are going to wait for some time or block... */
  if (wtime == -1 || wtime > 100L) {
    /* ... allow signals to kill us. */
    (void)vim_handle_signal(SIGNAL_UNBLOCK);

    /* ... there is no need for CTRL-C to interrupt something, don't let
     * it set got_int when it was mapped. */
    if (mapped_ctrl_c)
      ctrl_c_interrupts = FALSE;
  }

#ifndef NO_CONSOLE
  {
    retval = mch_inchar(buf, maxlen, wtime, tb_change_cnt);
  }
#endif

  if (wtime == -1 || wtime > 100L)
    /* block SIGHUP et al. */
    (void)vim_handle_signal(SIGNAL_BLOCK);

  ctrl_c_interrupts = TRUE;

#ifdef NO_CONSOLE_INPUT
theend:
#endif
  if (do_profiling == PROF_YES && wtime != 0)
    prof_inchar_exit();
  return retval;
}

/*
 * return non-zero if a character is available
 */
int ui_char_avail(void)         {
#ifndef NO_CONSOLE
# ifdef NO_CONSOLE_INPUT
  if (no_console_input())
    return 0;
# endif
  return mch_char_avail();
#else
  return 0;
#endif
}

/*
 * Delay for the given number of milliseconds.	If ignoreinput is FALSE then we
 * cancel the delay if a key is hit.
 */
void ui_delay(long msec, int ignoreinput)
{
  mch_delay(msec, ignoreinput);
}

/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 * When running the GUI iconify the window.
 */
void ui_suspend(void)          {
  mch_suspend();
}

#if !defined(UNIX) || !defined(SIGTSTP) || defined(PROTO) || defined(__BEOS__)
/*
 * When the OS can't really suspend, call this function to start a shell.
 * This is never called in the GUI.
 */
void suspend_shell(void)          {
  if (*p_sh == NUL)
    EMSG(_(e_shellempty));
  else {
    MSG_PUTS(_("new shell started\n"));
    do_shell(NULL, 0);
  }
}

#endif

/*
 * Try to get the current Vim shell size.  Put the result in Rows and Columns.
 * Use the new sizes as defaults for 'columns' and 'lines'.
 * Return OK when size could be determined, FAIL otherwise.
 */
int ui_get_shellsize(void)         {
  int retval;

  retval = mch_get_shellsize();

  check_shellsize();

  /* adjust the default for 'lines' and 'columns' */
  if (retval == OK) {
    set_number_default("lines", Rows);
    set_number_default("columns", Columns);
  }
  return retval;
}

/*
 * Set the size of the Vim shell according to Rows and Columns, if possible.
 * The gui_set_shellsize() or mch_set_shellsize() function will try to set the
 * new size.  If this is not possible, it will adjust Rows and Columns.
 */
void 
ui_set_shellsize (
    int mustset             /* set by the user */
)
{
  mch_set_shellsize();
}

/*
 * Called when Rows and/or Columns changed.  Adjust scroll region and mouse
 * region.
 */
void ui_new_shellsize(void)          {
  if (full_screen && !exiting) {
    mch_new_shellsize();
  }
}

void ui_breakcheck(void)          {
  mch_breakcheck();
}

/*****************************************************************************
 * Functions for copying and pasting text between applications.
 * This is always included in a GUI version, but may also be included when the
 * clipboard and mouse is available to a terminal version such as xterm.
 * Note: there are some more functions in ops.c that handle selection stuff.
 *
 * Also note that the majority of functions here deal with the X 'primary'
 * (visible - for Visual mode use) selection, and only that. There are no
 * versions of these for the 'clipboard' selection, as Visual mode has no use
 * for them.
 */


/*****************************************************************************
 * Functions that handle the input buffer.
 * This is used for any GUI version, and the unix terminal version.
 *
 * For Unix, the input characters are buffered to be able to check for a
 * CTRL-C.  This should be done with signals, but I don't know how to do that
 * in a portable way for a tty in RAW mode.
 *
 * For the client-server code in the console the received keys are put in the
 * input buffer.
 */

#if defined(USE_INPUT_BUF) || defined(PROTO)

/*
 * Internal typeahead buffer.  Includes extra space for long key code
 * descriptions which would otherwise overflow.  The buffer is considered full
 * when only this extra space (or part of it) remains.
 */
#if defined(FEAT_SUN_WORKSHOP) || defined(FEAT_NETBEANS_INTG) \
  || defined(FEAT_CLIENTSERVER)
/*
 * Sun WorkShop and NetBeans stuff debugger commands into the input buffer.
 * This requires a larger buffer...
 * (Madsen) Go with this for remote input as well ...
 */
# define INBUFLEN 4096
#else
# define INBUFLEN 250
#endif

static char_u inbuf[INBUFLEN + MAX_KEY_CODE_LEN];
static int inbufcount = 0;          /* number of chars in inbuf[] */

/*
 * vim_is_input_buf_full(), vim_is_input_buf_empty(), add_to_input_buf(), and
 * trash_input_buf() are functions for manipulating the input buffer.  These
 * are used by the gui_* calls when a GUI is used to handle keyboard input.
 */

int vim_is_input_buf_full(void)         {
  return inbufcount >= INBUFLEN;
}

int vim_is_input_buf_empty(void)         {
  return inbufcount == 0;
}

#if defined(FEAT_OLE) || defined(PROTO)
int vim_free_in_input_buf(void)         {
  return INBUFLEN - inbufcount;
}

#endif


/*
 * Return the current contents of the input buffer and make it empty.
 * The returned pointer must be passed to set_input_buf() later.
 */
char_u *get_input_buf(void)              {
  garray_T    *gap;

  /* We use a growarray to store the data pointer and the length. */
  gap = (garray_T *)alloc((unsigned)sizeof(garray_T));
  if (gap != NULL) {
    /* Add one to avoid a zero size. */
    gap->ga_data = alloc((unsigned)inbufcount + 1);
    if (gap->ga_data != NULL)
      mch_memmove(gap->ga_data, inbuf, (size_t)inbufcount);
    gap->ga_len = inbufcount;
  }
  trash_input_buf();
  return (char_u *)gap;
}

/*
 * Restore the input buffer with a pointer returned from get_input_buf().
 * The allocated memory is freed, this only works once!
 */
void set_input_buf(char_u *p)
{
  garray_T    *gap = (garray_T *)p;

  if (gap != NULL) {
    if (gap->ga_data != NULL) {
      mch_memmove(inbuf, gap->ga_data, gap->ga_len);
      inbufcount = gap->ga_len;
      vim_free(gap->ga_data);
    }
    vim_free(gap);
  }
}

#if defined(FEAT_GUI) \
  || defined(FEAT_MOUSE_GPM) || defined(FEAT_SYSMOUSE) \
  || defined(FEAT_XCLIPBOARD) || defined(VMS) \
  || defined(FEAT_SNIFF) || defined(FEAT_CLIENTSERVER) \
  || defined(PROTO)
/*
 * Add the given bytes to the input buffer
 * Special keys start with CSI.  A real CSI must have been translated to
 * CSI KS_EXTRA KE_CSI.  K_SPECIAL doesn't require translation.
 */
void add_to_input_buf(char_u *s, int len)
{
  if (inbufcount + len > INBUFLEN + MAX_KEY_CODE_LEN)
    return;         /* Shouldn't ever happen! */

  if ((State & (INSERT|CMDLINE)) && hangul_input_state_get())
    if ((len = hangul_input_process(s, len)) == 0)
      return;

  while (len--)
    inbuf[inbufcount++] = *s++;
}
#endif

#if ((defined(FEAT_XIM) || defined(FEAT_DND)) && defined(FEAT_GUI_GTK)) \
  || defined(FEAT_GUI_MSWIN) \
  || defined(FEAT_GUI_MAC) \
  || (defined(FEAT_MBYTE) && defined(FEAT_MBYTE_IME)) \
  || (defined(FEAT_GUI) && (!defined(USE_ON_FLY_SCROLL) \
  || defined(FEAT_MENU))) \
  || defined(PROTO)
/*
 * Add "str[len]" to the input buffer while escaping CSI bytes.
 */
void add_to_input_buf_csi(char_u *str, int len)          {
  int i;
  char_u buf[2];

  for (i = 0; i < len; ++i) {
    add_to_input_buf(str + i, 1);
    if (str[i] == CSI) {
      /* Turn CSI into K_CSI. */
      buf[0] = KS_EXTRA;
      buf[1] = (int)KE_CSI;
      add_to_input_buf(buf, 2);
    }
  }
}

#endif

void push_raw_key(char_u *s, int len)
{
  while (len--)
    inbuf[inbufcount++] = *s++;
}

#if defined(FEAT_GUI) || defined(FEAT_EVAL) || defined(FEAT_EX_EXTRA) \
  || defined(PROTO)
/* Remove everything from the input buffer.  Called when ^C is found */
void trash_input_buf(void)          {
  inbufcount = 0;
}

#endif

/*
 * Read as much data from the input buffer as possible up to maxlen, and store
 * it in buf.
 * Note: this function used to be Read() in unix.c
 */
int read_from_input_buf(char_u *buf, long maxlen)
{
  if (inbufcount == 0)          /* if the buffer is empty, fill it */
    fill_input_buf(TRUE);
  if (maxlen > inbufcount)
    maxlen = inbufcount;
  mch_memmove(buf, inbuf, (size_t)maxlen);
  inbufcount -= maxlen;
  if (inbufcount)
    mch_memmove(inbuf, inbuf + maxlen, (size_t)inbufcount);
  return (int)maxlen;
}

void fill_input_buf(int exit_on_error)
{
#if defined(UNIX) || defined(OS2) || defined(VMS) || defined(MACOS_X_UNIX)
  int len;
  int try;
  static int did_read_something = FALSE;
  static char_u *rest = NULL;       /* unconverted rest of previous read */
  static int restlen = 0;
  int unconverted;
#endif

#if defined(UNIX) || defined(OS2) || defined(VMS) || defined(MACOS_X_UNIX)
  if (vim_is_input_buf_full())
    return;
  /*
   * Fill_input_buf() is only called when we really need a character.
   * If we can't get any, but there is some in the buffer, just return.
   * If we can't get any, and there isn't any in the buffer, we give up and
   * exit Vim.
   */


  if (rest != NULL) {
    /* Use remainder of previous call, starts with an invalid character
     * that may become valid when reading more. */
    if (restlen > INBUFLEN - inbufcount)
      unconverted = INBUFLEN - inbufcount;
    else
      unconverted = restlen;
    mch_memmove(inbuf + inbufcount, rest, unconverted);
    if (unconverted == restlen) {
      vim_free(rest);
      rest = NULL;
    } else   {
      restlen -= unconverted;
      mch_memmove(rest, rest + unconverted, restlen);
    }
    inbufcount += unconverted;
  } else
    unconverted = 0;

  len = 0;      /* to avoid gcc warning */
  for (try = 0; try < 100; ++try) {
    len = read(read_cmd_fd,
        (char *)inbuf + inbufcount, (size_t)((INBUFLEN - inbufcount)
                                             / input_conv.vc_factor
                                             ));

    if (len > 0 || got_int)
      break;
    /*
     * If reading stdin results in an error, continue reading stderr.
     * This helps when using "foo | xargs vim".
     */
    if (!did_read_something && !isatty(read_cmd_fd) && read_cmd_fd == 0) {
      int m = cur_tmode;

      /* We probably set the wrong file descriptor to raw mode.  Switch
       * back to cooked mode, use another descriptor and set the mode to
       * what it was. */
      settmode(TMODE_COOK);
#ifdef HAVE_DUP
      /* Use stderr for stdin, also works for shell commands. */
      close(0);
      ignored = dup(2);
#else
      read_cmd_fd = 2;          /* read from stderr instead of stdin */
#endif
      settmode(m);
    }
    if (!exit_on_error)
      return;
  }
  if (len <= 0 && !got_int)
    read_error_exit();
  if (len > 0)
    did_read_something = TRUE;
  if (got_int) {
    /* Interrupted, pretend a CTRL-C was typed. */
    inbuf[0] = 3;
    inbufcount = 1;
  } else   {
    /*
     * May perform conversion on the input characters.
     * Include the unconverted rest of the previous call.
     * If there is an incomplete char at the end it is kept for the next
     * time, reading more bytes should make conversion possible.
     * Don't do this in the unlikely event that the input buffer is too
     * small ("rest" still contains more bytes).
     */
    if (input_conv.vc_type != CONV_NONE) {
      inbufcount -= unconverted;
      len = convert_input_safe(inbuf + inbufcount,
          len + unconverted, INBUFLEN - inbufcount,
          rest == NULL ? &rest : NULL, &restlen);
    }
    while (len-- > 0) {
      /*
       * if a CTRL-C was typed, remove it from the buffer and set got_int
       */
      if (inbuf[inbufcount] == 3 && ctrl_c_interrupts) {
        /* remove everything typed before the CTRL-C */
        mch_memmove(inbuf, inbuf + inbufcount, (size_t)(len + 1));
        inbufcount = 0;
        got_int = TRUE;
      }
      ++inbufcount;
    }
  }
#endif /* UNIX or OS2 or VMS*/
}
#endif /* defined(UNIX) || defined(FEAT_GUI) || defined(OS2)  || defined(VMS) */

/*
 * Exit because of an input read error.
 */
void read_error_exit(void)          {
  if (silent_mode)      /* Normal way to exit for "ex -s" */
    getout(0);
  STRCPY(IObuff, _("Vim: Error reading input, exiting...\n"));
  preserve_exit();
}

#if defined(CURSOR_SHAPE) || defined(PROTO)
/*
 * May update the shape of the cursor.
 */
void ui_cursor_shape(void)          {
  term_cursor_shape();


  conceal_check_cursur_line();
}

#endif

#if defined(FEAT_CLIPBOARD) || defined(FEAT_GUI) || defined(FEAT_RIGHTLEFT) \
  || defined(FEAT_MBYTE) || defined(PROTO)
/*
 * Check bounds for column number
 */
int check_col(int col)
{
  if (col < 0)
    return 0;
  if (col >= (int)screen_Columns)
    return (int)screen_Columns - 1;
  return col;
}

/*
 * Check bounds for row number
 */
int check_row(int row)
{
  if (row < 0)
    return 0;
  if (row >= (int)screen_Rows)
    return (int)screen_Rows - 1;
  return row;
}
#endif

/*
 * Stuff for the X clipboard.  Shared between VMS and Unix.
 */


#if defined(FEAT_XCLIPBOARD) || defined(FEAT_GUI_X11) \
  || defined(FEAT_GUI_GTK) || defined(PROTO)
/*
 * Get the contents of the X CUT_BUFFER0 and put it in "cbd".
 */
void yank_cut_buffer0(Display *dpy, VimClipboard *cbd)
{
  int nbytes = 0;
  char_u      *buffer = (char_u *)XFetchBuffer(dpy, &nbytes, 0);

  if (nbytes > 0) {
    int done = FALSE;

    /* CUT_BUFFER0 is supposed to be always latin1.  Convert to 'enc' when
     * using a multi-byte encoding.  Conversion between two 8-bit
     * character sets usually fails and the text might actually be in
     * 'enc' anyway. */
    if (has_mbyte) {
      char_u      *conv_buf;
      vimconv_T vc;

      vc.vc_type = CONV_NONE;
      if (convert_setup(&vc, (char_u *)"latin1", p_enc) == OK) {
        conv_buf = string_convert(&vc, buffer, &nbytes);
        if (conv_buf != NULL) {
          clip_yank_selection(MCHAR, conv_buf, (long)nbytes, cbd);
          vim_free(conv_buf);
          done = TRUE;
        }
        convert_setup(&vc, NULL, NULL);
      }
    }
    if (!done)      /* use the text without conversion */
      clip_yank_selection(MCHAR, buffer, (long)nbytes, cbd);
    XFree((void *)buffer);
    if (p_verbose > 0) {
      verbose_enter();
      verb_msg((char_u *)_("Used CUT_BUFFER0 instead of empty selection"));
      verbose_leave();
    }
  }
}
#endif


/*
 * Move the cursor to the specified row and column on the screen.
 * Change current window if necessary.	Returns an integer with the
 * CURSOR_MOVED bit set if the cursor has moved or unset otherwise.
 *
 * The MOUSE_FOLD_CLOSE bit is set when clicked on the '-' in a fold column.
 * The MOUSE_FOLD_OPEN bit is set when clicked on the '+' in a fold column.
 *
 * If flags has MOUSE_FOCUS, then the current window will not be changed, and
 * if the mouse is outside the window then the text will scroll, or if the
 * mouse was previously on a status line, then the status line may be dragged.
 *
 * If flags has MOUSE_MAY_VIS, then VIsual mode will be started before the
 * cursor is moved unless the cursor was on a status line.
 * This function returns one of IN_UNKNOWN, IN_BUFFER, IN_STATUS_LINE or
 * IN_SEP_LINE depending on where the cursor was clicked.
 *
 * If flags has MOUSE_MAY_STOP_VIS, then Visual mode will be stopped, unless
 * the mouse is on the status line of the same window.
 *
 * If flags has MOUSE_DID_MOVE, nothing is done if the mouse didn't move since
 * the last call.
 *
 * If flags has MOUSE_SETPOS, nothing is done, only the current position is
 * remembered.
 */
int 
jump_to_mouse (
    int flags,
    int *inclusive,         /* used for inclusive operator, can be NULL */
    int which_button               /* MOUSE_LEFT, MOUSE_RIGHT, MOUSE_MIDDLE */
)
{
  static int on_status_line = 0;        /* #lines below bottom of window */
  static int on_sep_line = 0;           /* on separator right of window */
  static int prev_row = -1;
  static int prev_col = -1;
  static win_T *dragwin = NULL;         /* window being dragged */
  static int did_drag = FALSE;          /* drag was noticed */

  win_T       *wp, *old_curwin;
  pos_T old_cursor;
  int count;
  int first;
  int row = mouse_row;
  int col = mouse_col;
  int mouse_char;

  mouse_past_bottom = FALSE;
  mouse_past_eol = FALSE;

  if (flags & MOUSE_RELEASED) {
    /* On button release we may change window focus if positioned on a
     * status line and no dragging happened. */
    if (dragwin != NULL && !did_drag)
      flags &= ~(MOUSE_FOCUS | MOUSE_DID_MOVE);
    dragwin = NULL;
    did_drag = FALSE;
  }

  if ((flags & MOUSE_DID_MOVE)
      && prev_row == mouse_row
      && prev_col == mouse_col) {
retnomove:
    /* before moving the cursor for a left click which is NOT in a status
     * line, stop Visual mode */
    if (on_status_line)
      return IN_STATUS_LINE;
    if (on_sep_line)
      return IN_SEP_LINE;
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }
    return IN_BUFFER;
  }

  prev_row = mouse_row;
  prev_col = mouse_col;

  if (flags & MOUSE_SETPOS)
    goto retnomove;                             /* ugly goto... */

  /* Remember the character under the mouse, it might be a '-' or '+' in the
   * fold column. */
  if (row >= 0 && row < Rows && col >= 0 && col <= Columns
      && ScreenLines != NULL)
    mouse_char = ScreenLines[LineOffset[row] + col];
  else
    mouse_char = ' ';

  old_curwin = curwin;
  old_cursor = curwin->w_cursor;

  if (!(flags & MOUSE_FOCUS)) {
    if (row < 0 || col < 0)                     /* check if it makes sense */
      return IN_UNKNOWN;

    /* find the window where the row is in */
    wp = mouse_find_win(&row, &col);
    dragwin = NULL;
    /*
     * winpos and height may change in win_enter()!
     */
    if (row >= wp->w_height) {                  /* In (or below) status line */
      on_status_line = row - wp->w_height + 1;
      dragwin = wp;
    } else
      on_status_line = 0;
    if (col >= wp->w_width) {           /* In separator line */
      on_sep_line = col - wp->w_width + 1;
      dragwin = wp;
    } else
      on_sep_line = 0;

    /* The rightmost character of the status line might be a vertical
     * separator character if there is no connecting window to the right. */
    if (on_status_line && on_sep_line) {
      if (stl_connected(wp))
        on_sep_line = 0;
      else
        on_status_line = 0;
    }

    /* Before jumping to another buffer, or moving the cursor for a left
     * click, stop Visual mode. */
    if (VIsual_active
        && (wp->w_buffer != curwin->w_buffer
            || (!on_status_line
                && !on_sep_line
                && (
                  wp->w_p_rl ? col < W_WIDTH(wp) - wp->w_p_fdc :
                                     col >= wp->w_p_fdc
                                             + (cmdwin_type == 0 && wp ==
                                                curwin ? 0 : 1)
                  )
                && (flags & MOUSE_MAY_STOP_VIS)))) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }
    if (cmdwin_type != 0 && wp != curwin) {
      /* A click outside the command-line window: Use modeless
       * selection if possible.  Allow dragging the status lines. */
      on_sep_line = 0;
      row = 0;
      col += wp->w_wincol;
      wp = curwin;
    }
    /* Only change window focus when not clicking on or dragging the
     * status line.  Do change focus when releasing the mouse button
     * (MOUSE_FOCUS was set above if we dragged first). */
    if (dragwin == NULL || (flags & MOUSE_RELEASED))
      win_enter(wp, TRUE);                      /* can make wp invalid! */
# ifdef CHECK_DOUBLE_CLICK
    /* set topline, to be able to check for double click ourselves */
    if (curwin != old_curwin)
      set_mouse_topline(curwin);
# endif
    if (on_status_line) {                       /* In (or below) status line */
      /* Don't use start_arrow() if we're in the same window */
      if (curwin == old_curwin)
        return IN_STATUS_LINE;
      else
        return IN_STATUS_LINE | CURSOR_MOVED;
    }
    if (on_sep_line) {                          /* In (or below) status line */
      /* Don't use start_arrow() if we're in the same window */
      if (curwin == old_curwin)
        return IN_SEP_LINE;
      else
        return IN_SEP_LINE | CURSOR_MOVED;
    }

    curwin->w_cursor.lnum = curwin->w_topline;
  } else if (on_status_line && which_button == MOUSE_LEFT)   {
    if (dragwin != NULL) {
      /* Drag the status line */
      count = row - dragwin->w_winrow - dragwin->w_height + 1
              - on_status_line;
      win_drag_status_line(dragwin, count);
      did_drag |= count;
    }
    return IN_STATUS_LINE;                      /* Cursor didn't move */
  } else if (on_sep_line && which_button == MOUSE_LEFT)   {
    if (dragwin != NULL) {
      /* Drag the separator column */
      count = col - dragwin->w_wincol - dragwin->w_width + 1
              - on_sep_line;
      win_drag_vsep_line(dragwin, count);
      did_drag |= count;
    }
    return IN_SEP_LINE;                         /* Cursor didn't move */
  } else   { /* keep_window_focus must be TRUE */
          /* before moving the cursor for a left click, stop Visual mode */
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }


    row -= W_WINROW(curwin);
    col -= W_WINCOL(curwin);

    /*
     * When clicking beyond the end of the window, scroll the screen.
     * Scroll by however many rows outside the window we are.
     */
    if (row < 0) {
      count = 0;
      for (first = TRUE; curwin->w_topline > 1; ) {
        if (curwin->w_topfill < diff_check(curwin, curwin->w_topline))
          ++count;
        else
          count += plines(curwin->w_topline - 1);
        if (!first && count > -row)
          break;
        first = FALSE;
        hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
        if (curwin->w_topfill < diff_check(curwin, curwin->w_topline))
          ++curwin->w_topfill;
        else {
          --curwin->w_topline;
          curwin->w_topfill = 0;
        }
      }
      check_topfill(curwin, FALSE);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      redraw_later(VALID);
      row = 0;
    } else if (row >= curwin->w_height)   {
      count = 0;
      for (first = TRUE; curwin->w_topline < curbuf->b_ml.ml_line_count; ) {
        if (curwin->w_topfill > 0)
          ++count;
        else
          count += plines(curwin->w_topline);
        if (!first && count > row - curwin->w_height + 1)
          break;
        first = FALSE;
        if (hasFolding(curwin->w_topline, NULL, &curwin->w_topline)
            && curwin->w_topline == curbuf->b_ml.ml_line_count)
          break;
        if (curwin->w_topfill > 0)
          --curwin->w_topfill;
        else {
          ++curwin->w_topline;
          curwin->w_topfill =
            diff_check_fill(curwin, curwin->w_topline);
        }
      }
      check_topfill(curwin, FALSE);
      redraw_later(VALID);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      row = curwin->w_height - 1;
    } else if (row == 0)   {
      /* When dragging the mouse, while the text has been scrolled up as
       * far as it goes, moving the mouse in the top line should scroll
       * the text down (done later when recomputing w_topline). */
      if (mouse_dragging > 0
          && curwin->w_cursor.lnum
          == curwin->w_buffer->b_ml.ml_line_count
          && curwin->w_cursor.lnum == curwin->w_topline)
        curwin->w_valid &= ~(VALID_TOPLINE);
    }
  }

  /* Check for position outside of the fold column. */
  if (
    curwin->w_p_rl ? col < W_WIDTH(curwin) - curwin->w_p_fdc :
                           col >= curwin->w_p_fdc
                                   + (cmdwin_type == 0 ? 0 : 1)
    )
    mouse_char = ' ';

  /* compute the position in the buffer line from the posn on the screen */
  if (mouse_comp_pos(curwin, &row, &col, &curwin->w_cursor.lnum))
    mouse_past_bottom = TRUE;

  /* Start Visual mode before coladvance(), for when 'sel' != "old" */
  if ((flags & MOUSE_MAY_VIS) && !VIsual_active) {
    check_visual_highlight();
    VIsual = old_cursor;
    VIsual_active = TRUE;
    VIsual_reselect = TRUE;
    /* if 'selectmode' contains "mouse", start Select mode */
    may_start_select('o');
    setmouse();
    if (p_smd && msg_silent == 0)
      redraw_cmdline = TRUE;            /* show visual mode later */
  }

  curwin->w_curswant = col;
  curwin->w_set_curswant = FALSE;       /* May still have been TRUE */
  if (coladvance(col) == FAIL) {        /* Mouse click beyond end of line */
    if (inclusive != NULL)
      *inclusive = TRUE;
    mouse_past_eol = TRUE;
  } else if (inclusive != NULL)
    *inclusive = FALSE;

  count = IN_BUFFER;
  if (curwin != old_curwin || curwin->w_cursor.lnum != old_cursor.lnum
      || curwin->w_cursor.col != old_cursor.col)
    count |= CURSOR_MOVED;              /* Cursor has moved */

  if (mouse_char == '+')
    count |= MOUSE_FOLD_OPEN;
  else if (mouse_char != ' ')
    count |= MOUSE_FOLD_CLOSE;

  return count;
}

/*
 * Compute the position in the buffer line from the posn on the screen in
 * window "win".
 * Returns TRUE if the position is below the last line.
 */
int mouse_comp_pos(win_T *win, int *rowp, int *colp, linenr_T *lnump)
{
  int col = *colp;
  int row = *rowp;
  linenr_T lnum;
  int retval = FALSE;
  int off;
  int count;

  if (win->w_p_rl)
    col = W_WIDTH(win) - 1 - col;

  lnum = win->w_topline;

  while (row > 0) {
    /* Don't include filler lines in "count" */
    if (win->w_p_diff
        && !hasFoldingWin(win, lnum, NULL, NULL, TRUE, NULL)
        ) {
      if (lnum == win->w_topline)
        row -= win->w_topfill;
      else
        row -= diff_check_fill(win, lnum);
      count = plines_win_nofill(win, lnum, TRUE);
    } else
      count = plines_win(win, lnum, TRUE);
    if (count > row)
      break;            /* Position is in this buffer line. */
    (void)hasFoldingWin(win, lnum, NULL, &lnum, TRUE, NULL);
    if (lnum == win->w_buffer->b_ml.ml_line_count) {
      retval = TRUE;
      break;                    /* past end of file */
    }
    row -= count;
    ++lnum;
  }

  if (!retval) {
    /* Compute the column without wrapping. */
    off = win_col_off(win) - win_col_off2(win);
    if (col < off)
      col = off;
    col += row * (W_WIDTH(win) - off);
    /* add skip column (for long wrapping line) */
    col += win->w_skipcol;
  }

  if (!win->w_p_wrap)
    col += win->w_leftcol;

  /* skip line number and fold column in front of the line */
  col -= win_col_off(win);
  if (col < 0) {
    col = 0;
  }

  *colp = col;
  *rowp = row;
  *lnump = lnum;
  return retval;
}

/*
 * Find the window at screen position "*rowp" and "*colp".  The positions are
 * updated to become relative to the top-left of the window.
 */
win_T *mouse_find_win(int *rowp, int *colp)
{
  frame_T     *fp;

  fp = topframe;
  *rowp -= firstwin->w_winrow;
  for (;; ) {
    if (fp->fr_layout == FR_LEAF)
      break;
    if (fp->fr_layout == FR_ROW) {
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*colp < fp->fr_width)
          break;
        *colp -= fp->fr_width;
      }
    } else   {  /* fr_layout == FR_COL */
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*rowp < fp->fr_height)
          break;
        *rowp -= fp->fr_height;
      }
    }
  }
  return fp->fr_win;
}

#if defined(FEAT_GUI_MOTIF) || defined(FEAT_GUI_GTK) || defined(FEAT_GUI_MAC) \
  || defined(FEAT_GUI_ATHENA) || defined(FEAT_GUI_MSWIN) \
  || defined(FEAT_GUI_PHOTON) || defined(PROTO)
/*
 * Translate window coordinates to buffer position without any side effects
 */
int get_fpos_of_mouse(pos_T *mpos)
{
  win_T       *wp;
  int row = mouse_row;
  int col = mouse_col;

  if (row < 0 || col < 0)               /* check if it makes sense */
    return IN_UNKNOWN;

  /* find the window where the row is in */
  wp = mouse_find_win(&row, &col);
  /*
   * winpos and height may change in win_enter()!
   */
  if (row >= wp->w_height)      /* In (or below) status line */
    return IN_STATUS_LINE;
  if (col >= wp->w_width)       /* In vertical separator line */
    return IN_SEP_LINE;

  if (wp != curwin)
    return IN_UNKNOWN;

  /* compute the position in the buffer line from the posn on the screen */
  if (mouse_comp_pos(curwin, &row, &col, &mpos->lnum))
    return IN_STATUS_LINE;     /* past bottom */

  mpos->col = vcol2col(wp, mpos->lnum, col);

  if (mpos->col > 0)
    --mpos->col;
  mpos->coladd = 0;
  return IN_BUFFER;
}

/*
 * Convert a virtual (screen) column to a character column.
 * The first column is one.
 */
int vcol2col(win_T *wp, linenr_T lnum, int vcol)
{
  /* try to advance to the specified column */
  int count = 0;
  char_u      *ptr;
  char_u      *start;

  start = ptr = ml_get_buf(wp->w_buffer, lnum, FALSE);
  while (count < vcol && *ptr != NUL) {
    count += win_lbr_chartabsize(wp, ptr, count, NULL);
    mb_ptr_adv(ptr);
  }
  return (int)(ptr - start);
}
#endif



#if defined(USE_IM_CONTROL) || defined(PROTO)
/*
 * Save current Input Method status to specified place.
 */
void im_save_status(long *psave)
{
  /* Don't save when 'imdisable' is set or "xic" is NULL, IM is always
   * disabled then (but might start later).
   * Also don't save when inside a mapping, vgetc_im_active has not been set
   * then.
   * And don't save when the keys were stuffed (e.g., for a "." command).
   * And don't save when the GUI is running but our window doesn't have
   * input focus (e.g., when a find dialog is open). */
  if (!p_imdisable && KeyTyped && !KeyStuffed
      ) {
    /* Do save when IM is on, or IM is off and saved status is on. */
    if (vgetc_im_active)
      *psave = B_IMODE_IM;
    else if (*psave == B_IMODE_IM)
      *psave = B_IMODE_NONE;
  }
}
#endif
