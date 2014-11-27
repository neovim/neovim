/*
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

#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/ex_cmds2.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/signal.h"
#include "nvim/screen.h"
#include "nvim/term.h"
#include "nvim/window.h"

void ui_write(char_u *s, int len)
{
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
      free(tofree);
  }
}

/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 * When running the GUI iconify the window.
 */
void ui_suspend(void)
{
  mch_suspend();
}

/*
 * Try to get the current Vim shell size.  Put the result in Rows and Columns.
 * Use the new sizes as defaults for 'columns' and 'lines'.
 * Return OK when size could be determined, FAIL otherwise.
 */
int ui_get_shellsize(void)
{
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
 * Exit because of an input read error.
 */
void read_error_exit(void)
{
  if (silent_mode)      /* Normal way to exit for "ex -s" */
    getout(0);
  STRCPY(IObuff, _("Vim: Error reading input, exiting...\n"));
  preserve_exit();
}

/*
 * May update the shape of the cursor.
 */
void ui_cursor_shape(void)
{
  term_cursor_shape();
  conceal_check_cursur_line();
}

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

