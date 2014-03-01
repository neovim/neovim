/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * popupmnu.c: Popup menu (PUM)
 */
#include "vim.h"
#include "popupmnu.h"
#include "charset.h"
#include "ex_cmds.h"
#include "memline.h"
#include "misc2.h"
#include "move.h"
#include "option.h"
#include "screen.h"
#include "search.h"
#include "window.h"

static pumitem_T *pum_array = NULL;     /* items of displayed pum */
static int pum_size;                    /* nr of items in "pum_array" */
static int pum_selected;                /* index of selected item or -1 */
static int pum_first = 0;               /* index of top item */

static int pum_height;                  /* nr of displayed pum items */
static int pum_width;                   /* width of displayed pum items */
static int pum_base_width;              /* width of pum items base */
static int pum_kind_width;              /* width of pum items kind column */
static int pum_scrollbar;               /* TRUE when scrollbar present */

static int pum_row;                     /* top row of pum */
static int pum_col;                     /* left column of pum */

static int pum_do_redraw = FALSE;       /* do redraw anyway */

static int pum_set_selected __ARGS((int n, int repeat));

#define PUM_DEF_HEIGHT 10
#define PUM_DEF_WIDTH  15

/**
 * Figure out the height of the pum.
 */
static int pum_calc_height(int num_items)
{
  int pum_height;
  if (num_items < PUM_DEF_HEIGHT)
    pum_height = num_items;
  else
    pum_height = PUM_DEF_HEIGHT;

  if (p_ph > 0 && pum_height > p_ph)
    pum_height = p_ph;

  return pum_height;
}

/**
 * Finds the last possible row where the pum must stop.
 *
 * This returns the row just above the status bar
 */
static int pum_find_last_possible_render_row()
{
  assert(lastwin);
  int last_row = cmdline_row;
  if (lastwin->w_p_pvw)
    last_row -= lastwin->w_height + lastwin->w_status_height + 1;
  return last_row;
}

/**
 * Calculate number of context lines we can show.
 *
 * Try to make room for 'lines' context lines.
 */
static int pum_calc_context_lines_if_above(int lines)
{
  assert(curwin);
  int context_lines = (curwin->w_wrow - curwin->w_cline_row >= lines) ?
    lines : curwin->w_wrow - curwin->w_cline_row;
  assert(context_lines >= 0 && context_lines <= lines);
  return context_lines;
}

/**
 */
static int pum_calc_context_lines_if_below(int lines)
{
  assert(curwin);
  int context_lines =
    (curwin->w_cline_row + curwin->w_cline_height - curwin->w_wrow >= lines) ?
    lines : curwin->w_cline_row + curwin->w_cline_height - curwin->w_wrow;
  assert(context_lines >= 0 && context_lines <= lines);
  return context_lines;
}

/**
 *
 */
static void pum_calc_and_set_row_and_height_if_above(int size, int ctx_lines, int row)
{
  if (row >= size + ctx_lines) {
    pum_row = row - size - ctx_lines;
    pum_height = size;
  } else {
    pum_row = 0;
    pum_height = row - ctx_lines;
  }

  if (p_ph > 0 && pum_height > p_ph) {
    pum_row += pum_height - p_ph;
    pum_height = p_ph;
  }
}

static int pum_should_render_above(int row, int bottom_row, int pum_height, int top_clear)
{
  return row  + 2 >= bottom_row - pum_height &&
    row > (bottom_row - top_clear) / 2;
}

/**
 */
static void pum_calc_and_set_row_and_height_if_below(int size, int above_row, int row,
  int context_lines)
{
  pum_row = row + context_lines;
  if (size > above_row - pum_row)
    pum_height = above_row - pum_row;
  else
    pum_height = size;

  if (p_ph > 0 && pum_height > p_ph)
    pum_height = p_ph;
}

/**
 */
static void pum_calc_and_set_size_and_pos(int size)
{
  /* When the preview window is at the bottom stop just above it.  Also
   * avoid drawing over the status line so that it's clear there is a window
   * boundary. */
  int above_row = pum_find_last_possible_render_row();

  pum_height = pum_calc_height(size);

  assert(curwin);
  int row = curwin->w_wrow + W_WINROW(curwin);

  assert(firstwin);
  int top_clear;
  if (firstwin->w_p_pvw)
    top_clear = firstwin->w_height;
  else
    top_clear = 0;

  /* Put the pum below "row" if possible.  If there are few lines decide on
   * where there is more room. */
  int render_above = pum_should_render_above(row, above_row, pum_height,
      top_clear);
  if (render_above) {
    /* Leave two lines of context if possible */
    int context_lines = pum_calc_context_lines_if_above(2);
    pum_calc_and_set_row_and_height_if_above(size, context_lines, row);
  } else {
    /* Leave two lines of context if possible */
    int context_lines = pum_calc_context_lines_if_below(3);
    pum_calc_and_set_row_and_height_if_below(size, above_row, row, context_lines);
  }
}

static int pum_max_text_width(pumitem_T *items, int num_items)
{
  assert(items);
  assert(num_items >= 0);

  int max = 0;
  for (int i = 0; i < num_items; ++i) {
    if(!items[i].pum_text) continue;
    int w = vim_strsize(items[i].pum_text);
    if (max < w)
      max = w;
  }
  return max;
}

static int pum_max_kind_width(pumitem_T *items, int num_items)
{
  assert(items);
  assert(num_items >= 0);

  int max = 0;
  for (int i = 0; i < num_items; ++i) {
    if(!items[i].pum_kind) continue;
    int w = vim_strsize(items[i].pum_kind) + 1;
    if (max < w)
      max = w;
  }
  return max;
}

static int pum_max_extra_width(pumitem_T *items, int num_items)
{
  assert(items);
  assert(num_items >= 0);

  int max = 0;
  for (int i = 0; i < num_items; ++i) {
    if(!items[i].pum_extra) continue;
    int w = vim_strsize(items[i].pum_extra) + 1;
    if (max < w)
      max = w;
  }
  return max;
}


/* Calculate column */
static int pum_calc_col()
{
  assert(curwin);
  return curwin-> w_p_rl ?
    W_WINCOL(curwin) + W_WIDTH(curwin) - curwin->w_wcol - 1 :
    W_WINCOL(curwin) + curwin->w_wcol;
}

/* If there is a preview window at the top avoid drawing over it. */
static void pum_avoid_preview_win_overlap()
{
  assert(firstwin);
  if (firstwin->w_p_pvw
      && pum_row < firstwin->w_height
      && pum_height > firstwin->w_height + 4)
  {
    pum_row    += firstwin->w_height;
    pum_height -= firstwin->w_height;
  }
}

/**
 * @param r_to_l Render text right to left?
 * @param scr_cols Number of columns our screen has
 * @param col Starting column for the pum
 * @param max_text_width The longest text width of the pum items to be rendered
 * */
static int pum_fits_width(int r_to_l, int scr_cols, int col, int max_text_width)
{
  if(r_to_l)
    return col > PUM_DEF_WIDTH || col > max_text_width;
  else
    return col < scr_cols - PUM_DEF_WIDTH || col < scr_cols - max_text_width;
}

/*
 * Show the popup menu with items "items[size]".
 * "items" must remain valid until pum_undisplay() is called!
 * When possible the leftmost character is aligned with screen column "col".
 * The menu appears above the screen line "row" or at "row" + "height" - 1.
 *
 * @param selected index of initially selected item, none if out of range
 */
void pum_display(pumitem_T *items, int num_items, int selected)
{
  int redo_count = 0;

  int def_width   = PUM_DEF_WIDTH;
  int max_width   = 0;
  int kind_width  = 0;
  int extra_width = 0;
redo:

  /* Pretend the pum is already there to avoid that must_redraw is set when
   * 'cuc' is on. */
  pum_array = (pumitem_T *)1;
  validate_cursor_col();
  pum_array = NULL;

  pum_calc_and_set_size_and_pos(num_items);

  /* don't display when we only have room for one line */
  if (pum_height < 1 || (pum_height == 1 && num_items > 1))
    return;

  pum_avoid_preview_win_overlap();

  max_width   = pum_max_text_width(items, num_items);
  kind_width  = pum_max_kind_width(items, num_items);
  extra_width = pum_max_extra_width(items, num_items);

  pum_base_width = max_width;
  pum_kind_width = kind_width;

  /* if there are more items than room we need a scrollbar */
  if (pum_height < num_items) {
    pum_scrollbar = TRUE;
    ++max_width;
  } else {
    pum_scrollbar = FALSE;
  }

  if (def_width < max_width)
    def_width = max_width;

  int col = pum_calc_col();

  int fits_width = pum_fits_width(curwin->w_p_rl, Columns, col, max_width);
  if (fits_width) {
    /* align pum column with "col" */
    pum_col = col;

    if (curwin->w_p_rl)
      pum_width = pum_col - pum_scrollbar + 1;
    else
      pum_width = Columns - pum_col - pum_scrollbar;

    if (pum_width > max_width + kind_width + extra_width + 1
        && pum_width > PUM_DEF_WIDTH) {
      pum_width = max_width + kind_width + extra_width + 1;
      if (pum_width < PUM_DEF_WIDTH)
        pum_width = PUM_DEF_WIDTH;
    }
  } else if (Columns < def_width)   {
    /* not enough room, will use what we have */
    if (curwin->w_p_rl)
      pum_col = Columns - 1;
    else
      pum_col = 0;
    pum_width = Columns - 1;
  } else   {
    if (max_width > PUM_DEF_WIDTH)
      max_width = PUM_DEF_WIDTH;        /* truncate */
    if (curwin->w_p_rl)
      pum_col = max_width - 1;
    else
      pum_col = Columns - max_width;
    pum_width = max_width - pum_scrollbar;
  }

  pum_array = items;
  pum_size = num_items;

  /* Set selected item and redraw.  If the window size changed need to redo
   * the positioning.  Limit this to two times, when there is not much
   * room the window size will keep changing. */
  if (pum_set_selected(selected, redo_count) && ++redo_count <= 2)
    goto redo;
}

/*
 * Redraw the popup menu, using "pum_first" and "pum_selected".
 */
void pum_redraw(void)
{
  int row = pum_row;
  int col;
  int attr_norm = highlight_attr[HLF_PNI];
  int attr_select = highlight_attr[HLF_PSI];
  int attr_scroll = highlight_attr[HLF_PSB];
  int attr_thumb = highlight_attr[HLF_PST];
  int attr;
  int i;
  int idx;
  char_u      *s;
  char_u      *p = NULL;
  int totwidth, width, w;
  int thumb_pos = 0;
  int thumb_heigth = 1;
  int round;
  int n;

  /* Never display more than we have */
  if (pum_first > pum_size - pum_height)
    pum_first = pum_size - pum_height;

  if (pum_scrollbar) {
    thumb_heigth = pum_height * pum_height / pum_size;
    if (thumb_heigth == 0)
      thumb_heigth = 1;
    thumb_pos = (pum_first * (pum_height - thumb_heigth)
                 + (pum_size - pum_height) / 2)
                / (pum_size - pum_height);
  }

  for (i = 0; i < pum_height; ++i) {
    idx = i + pum_first;
    attr = (idx == pum_selected) ? attr_select : attr_norm;

    /* prepend a space if there is room */
    if (curwin->w_p_rl) {
      if (pum_col < W_WINCOL(curwin) + W_WIDTH(curwin) - 1)
        screen_putchar(' ', row, pum_col + 1, attr);
    } else if (pum_col > 0)
      screen_putchar(' ', row, pum_col - 1, attr);

    /* Display each entry, use two spaces for a Tab.
     * Do this 3 times: For the main text, kind and extra info */
    col = pum_col;
    totwidth = 0;
    for (round = 1; round <= 3; ++round) {
      width = 0;
      s = NULL;
      switch (round) {
      case 1: p = pum_array[idx].pum_text; break;
      case 2: p = pum_array[idx].pum_kind; break;
      case 3: p = pum_array[idx].pum_extra; break;
      }
      if (p != NULL)
        for (;; mb_ptr_adv(p)) {
          if (s == NULL)
            s = p;
          w = ptr2cells(p);
          if (*p == NUL || *p == TAB || totwidth + w > pum_width) {
            /* Display the text that fits or comes before a Tab.
             * First convert it to printable characters. */
            char_u  *st;
            int saved = *p;

            *p = NUL;
            st = transstr(s);
            *p = saved;
            if (curwin->w_p_rl) {
              if (st != NULL) {
                char_u  *rt = reverse_text(st);

                if (rt != NULL) {
                  char_u      *rt_start = rt;
                  int size;

                  size = vim_strsize(rt);
                  if (size > pum_width) {
                    do {
                      size -= has_mbyte
                              ? (*mb_ptr2cells)(rt) : 1;
                      mb_ptr_adv(rt);
                    } while (size > pum_width);

                    if (size < pum_width) {
                      /* Most left character requires
                       * 2-cells but only 1 cell is
                       * available on screen.  Put a
                       * '<' on the left of the pum
                       * item */
                      *(--rt) = '<';
                      size++;
                    }
                  }
                  screen_puts_len(rt, (int)STRLEN(rt),
                      row, col - size + 1, attr);
                  vim_free(rt_start);
                }
                vim_free(st);
              }
              col -= width;
            } else   {
              if (st != NULL) {
                screen_puts_len(st, (int)STRLEN(st), row, col,
                    attr);
                vim_free(st);
              }
              col += width;
            }

            if (*p != TAB)
              break;

            /* Display two spaces for a Tab. */
            if (curwin->w_p_rl) {
              screen_puts_len((char_u *)"  ", 2, row, col - 1,
                  attr);
              col -= 2;
            } else   {
              screen_puts_len((char_u *)"  ", 2, row, col, attr);
              col += 2;
            }
            totwidth += 2;
            s = NULL;                       /* start text at next char */
            width = 0;
          } else
            width += w;
        }

      if (round > 1)
        n = pum_kind_width + 1;
      else
        n = 1;

      /* Stop when there is nothing more to display. */
      if (round == 3
          || (round == 2 && pum_array[idx].pum_extra == NULL)
          || (round == 1 && pum_array[idx].pum_kind == NULL
              && pum_array[idx].pum_extra == NULL)
          || pum_base_width + n >= pum_width)
        break;
      if (curwin->w_p_rl) {
        screen_fill(row, row + 1, pum_col - pum_base_width - n + 1,
            col + 1, ' ', ' ', attr);
        col = pum_col - pum_base_width - n + 1;
      } else   {
        screen_fill(row, row + 1, col, pum_col + pum_base_width + n,
            ' ', ' ', attr);
        col = pum_col + pum_base_width + n;
      }
      totwidth = pum_base_width + n;
    }

    if (curwin->w_p_rl)
      screen_fill(row, row + 1, pum_col - pum_width + 1, col + 1, ' ',
          ' ', attr);
    else
      screen_fill(row, row + 1, col, pum_col + pum_width, ' ', ' ',
          attr);
    if (pum_scrollbar > 0) {
      if (curwin->w_p_rl)
        screen_putchar(' ', row, pum_col - pum_width,
            i >= thumb_pos && i < thumb_pos + thumb_heigth
            ? attr_thumb : attr_scroll);
      else
        screen_putchar(' ', row, pum_col + pum_width,
            i >= thumb_pos && i < thumb_pos + thumb_heigth
            ? attr_thumb : attr_scroll);
    }

    ++row;
  }
}

/*
 * Set the index of the currently selected item.  The menu will scroll when
 * necessary.  When "n" is out of range don't scroll.
 * This may be repeated when the preview window is used:
 * "repeat" == 0: open preview window normally
 * "repeat" == 1: open preview window but don't set the size
 * "repeat" == 2: don't open preview window
 * Returns TRUE when the window was resized and the location of the popup menu
 * must be recomputed.
 */
static int pum_set_selected(int n, int repeat)
{
  int resized = FALSE;
  int context = pum_height / 2;

  pum_selected = n;

  if (pum_selected >= 0 && pum_selected < pum_size) {
    if (pum_first > pum_selected - 4) {
      /* scroll down; when we did a jump it's probably a PageUp then
       * scroll a whole page */
      if (pum_first > pum_selected - 2) {
        pum_first -= pum_height - 2;
        if (pum_first < 0)
          pum_first = 0;
        else if (pum_first > pum_selected)
          pum_first = pum_selected;
      } else
        pum_first = pum_selected;
    } else if (pum_first < pum_selected - pum_height + 5)   {
      /* scroll up; when we did a jump it's probably a PageDown then
       * scroll a whole page */
      if (pum_first < pum_selected - pum_height + 1 + 2) {
        pum_first += pum_height - 2;
        if (pum_first < pum_selected - pum_height + 1)
          pum_first = pum_selected - pum_height + 1;
      } else
        pum_first = pum_selected - pum_height + 1;
    }

    /* Give a few lines of context when possible. */
    if (context > 3)
      context = 3;
    if (pum_height > 2) {
      if (pum_first > pum_selected - context) {
        /* scroll down */
        pum_first = pum_selected - context;
        if (pum_first < 0)
          pum_first = 0;
      } else if (pum_first < pum_selected + context - pum_height + 1)   {
        /* scroll up */
        pum_first = pum_selected + context - pum_height + 1;
      }
    }

    /*
     * Show extra info in the preview window if there is something and
     * 'completeopt' contains "preview".
     * Skip this when tried twice already.
     * Skip this also when there is not much room.
     * NOTE: Be very careful not to sync undo!
     */
    if (pum_array[pum_selected].pum_info != NULL
        && Rows > 10
        && repeat <= 1
        && vim_strchr(p_cot, 'p') != NULL) {
      win_T       *curwin_save = curwin;
      int res = OK;

      /* Open a preview window.  3 lines by default.  Prefer
       * 'previewheight' if set and smaller. */
      g_do_tagpreview = 3;
      if (p_pvh > 0 && p_pvh < g_do_tagpreview)
        g_do_tagpreview = p_pvh;
      resized = prepare_tagpreview(FALSE);
      g_do_tagpreview = 0;

      if (curwin->w_p_pvw) {
        if (curbuf->b_fname == NULL
            && curbuf->b_p_bt[0] == 'n' && curbuf->b_p_bt[2] == 'f'
            && curbuf->b_p_bh[0] == 'w') {
          /* Already a "wipeout" buffer, make it empty. */
          while (!bufempty())
            ml_delete((linenr_T)1, FALSE);
        } else   {
          /* Don't want to sync undo in the current buffer. */
          ++no_u_sync;
          res = do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, 0, NULL);
          --no_u_sync;
          if (res == OK) {
            /* Edit a new, empty buffer. Set options for a "wipeout"
             * buffer. */
            set_option_value((char_u *)"swf", 0L, NULL, OPT_LOCAL);
            set_option_value((char_u *)"bt", 0L,
                (char_u *)"nofile", OPT_LOCAL);
            set_option_value((char_u *)"bh", 0L,
                (char_u *)"wipe", OPT_LOCAL);
            set_option_value((char_u *)"diff", 0L,
                NULL, OPT_LOCAL);
          }
        }
        if (res == OK) {
          char_u      *p, *e;
          linenr_T lnum = 0;

          for (p = pum_array[pum_selected].pum_info; *p != NUL; ) {
            e = vim_strchr(p, '\n');
            if (e == NULL) {
              ml_append(lnum++, p, 0, FALSE);
              break;
            } else   {
              *e = NUL;
              ml_append(lnum++, p, (int)(e - p + 1), FALSE);
              *e = '\n';
              p = e + 1;
            }
          }

          /* Increase the height of the preview window to show the
           * text, but no more than 'previewheight' lines. */
          if (repeat == 0) {
            if (lnum > p_pvh)
              lnum = p_pvh;
            if (curwin->w_height < lnum) {
              win_setheight((int)lnum);
              resized = TRUE;
            }
          }

          curbuf->b_changed = 0;
          curbuf->b_p_ma = FALSE;
          curwin->w_cursor.lnum = 1;
          curwin->w_cursor.col = 0;

          if (curwin != curwin_save && win_valid(curwin_save)) {
            /* Return cursor to where we were */
            validate_cursor();
            redraw_later(SOME_VALID);

            /* When the preview window was resized we need to
             * update the view on the buffer.  Only go back to
             * the window when needed, otherwise it will always be
             * redraw. */
            if (resized) {
              win_enter(curwin_save, TRUE);
              update_topline();
            }

            /* Update the screen before drawing the popup menu.
             * Enable updating the status lines. */
            pum_do_redraw = TRUE;
            update_screen(0);
            pum_do_redraw = FALSE;

            if (!resized && win_valid(curwin_save))
              win_enter(curwin_save, TRUE);

            /* May need to update the screen again when there are
             * autocommands involved. */
            pum_do_redraw = TRUE;
            update_screen(0);
            pum_do_redraw = FALSE;
          }
        }
      }
    }
  }

  if (!resized)
    pum_redraw();

  return resized;
}

/*
 * Undisplay the popup menu (later).
 */
void pum_undisplay(void)
{
  pum_array = NULL;
  redraw_all_later(SOME_VALID);
  redraw_tabline = TRUE;
  status_redraw_all();
}

/*
 * Clear the popup menu.  Currently only resets the offset to the first
 * displayed item.
 */
void pum_clear(void)
{
  pum_first = 0;
}

/*
 * Return TRUE if the popup menu is displayed.
 * Overruled when "pum_do_redraw" is set, used to redraw the status lines.
 */
int pum_visible(void)
{
  return !pum_do_redraw && pum_array != NULL;
}

/*
 * Return the height of the popup menu, the number of entries visible.
 * Only valid when pum_visible() returns TRUE!
 */
int pum_get_height(void)
{
  return pum_height;
}

