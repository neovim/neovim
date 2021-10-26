// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file popupmnu.c
///
/// Popup menu (PUM)

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>

#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/edit.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/vim.h"
#include "nvim/window.h"

static pumitem_T *pum_array = NULL;  // items of displayed pum
static int pum_size;                // nr of items in "pum_array"
static int pum_selected;            // index of selected item or -1
static int pum_first = 0;           // index of top item

static int pum_height;              // nr of displayed pum items
static int pum_width;               // width of displayed pum items
static int pum_base_width;          // width of pum items base
static int pum_kind_width;          // width of pum items kind column
static int pum_extra_width;         // width of extra stuff
static int pum_scrollbar;           // one when scrollbar present, else zero
static bool pum_rl;                 // true when popupmenu is drawn 'rightleft'

static int pum_anchor_grid;         // grid where position is defined
static int pum_row;                 // top row of pum
static int pum_col;                 // left column of pum
static bool pum_above;              // pum is drawn above cursor line

static bool pum_is_visible = false;
static bool pum_is_drawn = false;
static bool pum_external = false;
static bool pum_invalid = false;  // the screen was just cleared

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "popupmnu.c.generated.h"
#endif
#define PUM_DEF_HEIGHT 10

static void pum_compute_size(void)
{
  // Compute the width of the widest match and the widest extra.
  pum_base_width = 0;
  pum_kind_width = 0;
  pum_extra_width = 0;
  for (int i = 0; i < pum_size; i++) {
    int w;
    if (pum_array[i].pum_text != NULL) {
      w = vim_strsize(pum_array[i].pum_text);
      if (pum_base_width < w) {
        pum_base_width = w;
      }
    }
    if (pum_array[i].pum_kind != NULL) {
      w = vim_strsize(pum_array[i].pum_kind) + 1;
      if (pum_kind_width < w) {
        pum_kind_width = w;
      }
    }
    if (pum_array[i].pum_extra != NULL) {
      w = vim_strsize(pum_array[i].pum_extra) + 1;
      if (pum_extra_width < w) {
        pum_extra_width = w;
      }
    }
  }
}

/// Show the popup menu with items "array[size]".
/// "array" must remain valid until pum_undisplay() is called!
/// When possible the leftmost character is aligned with cursor column.
/// The menu appears above the screen line "row" or at "row" + "height" - 1.
///
/// @param array
/// @param size
/// @param selected index of initially selected item, none if out of range
/// @param array_changed if true, array contains different items since last call
///                      if false, a new item is selected, but the array
///                      is the same
/// @param cmd_startcol only for cmdline mode: column of completed match
void pum_display(pumitem_T *array, int size, int selected, bool array_changed, int cmd_startcol)
{
  int context_lines;
  int above_row;
  int below_row;
  int redo_count = 0;
  int pum_win_row;
  int cursor_col;

  if (!pum_is_visible) {
    // To keep the code simple, we only allow changing the
    // draw mode when the popup menu is not being displayed
    pum_external = ui_has(kUIPopupmenu)
                   || (State == CMDLINE && ui_has(kUIWildmenu));
  }

  pum_rl = (curwin->w_p_rl && State != CMDLINE);

  do {
    // Mark the pum as visible already here,
    // to avoid that must_redraw is set when 'cursorcolumn' is on.
    pum_is_visible = true;
    pum_is_drawn = true;
    validate_cursor_col();
    above_row = 0;
    below_row = cmdline_row;

    // wildoptions=pum
    if (State == CMDLINE) {
      pum_win_row = ui_has(kUICmdline) ? 0 : cmdline_row;
      cursor_col = cmd_startcol;
      pum_anchor_grid = ui_has(kUICmdline) ? -1 : DEFAULT_GRID_HANDLE;
    } else {
      // anchor position: the start of the completed word
      pum_win_row = curwin->w_wrow;
      if (pum_rl) {
        cursor_col = curwin->w_width - curwin->w_wcol - 1;
      } else {
        cursor_col = curwin->w_wcol;
      }

      pum_anchor_grid = (int)curwin->w_grid.target->handle;
      pum_win_row += curwin->w_grid.row_offset;
      cursor_col += curwin->w_grid.col_offset;
      if (!ui_has(kUIMultigrid) && curwin->w_grid.target != &default_grid) {
        pum_anchor_grid = (int)default_grid.handle;
        pum_win_row += curwin->w_winrow;
        cursor_col += curwin->w_wincol;
      }
    }

    if (pum_external) {
      if (array_changed) {
        Array arr = ARRAY_DICT_INIT;
        for (int i = 0; i < size; i++) {
          Array item = ARRAY_DICT_INIT;
          ADD(item, STRING_OBJ(cstr_to_string((char *)array[i].pum_text)));
          ADD(item, STRING_OBJ(cstr_to_string((char *)array[i].pum_kind)));
          ADD(item, STRING_OBJ(cstr_to_string((char *)array[i].pum_extra)));
          ADD(item, STRING_OBJ(cstr_to_string((char *)array[i].pum_info)));
          ADD(arr, ARRAY_OBJ(item));
        }
        ui_call_popupmenu_show(arr, selected, pum_win_row, cursor_col,
                               pum_anchor_grid);
      } else {
        ui_call_popupmenu_select(selected);
        return;
      }
    }

    int def_width = (int)p_pw;

    win_T *pvwin = NULL;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_p_pvw) {
        pvwin = wp;
        break;
      }
    }

    if (pvwin != NULL) {
      if (pvwin->w_winrow < curwin->w_winrow) {
        above_row = pvwin->w_winrow + pvwin->w_height;
      } else if (pvwin->w_winrow > curwin->w_winrow + curwin->w_height) {
        below_row = pvwin->w_winrow;
      }
    }

    // Figure out the size and position of the pum.
    if (size < PUM_DEF_HEIGHT) {
      pum_height = size;
    } else {
      pum_height = PUM_DEF_HEIGHT;
    }

    if ((p_ph > 0) && (pum_height > p_ph)) {
      pum_height = (int)p_ph;
    }

    // Put the pum below "pum_win_row" if possible.
    // If there are few lines decide on where there is more room.
    if (pum_win_row + 2 >= below_row - pum_height
        && pum_win_row - above_row > (below_row - above_row) / 2) {
      // pum above "pum_win_row"
      pum_above = true;

      // Leave two lines of context if possible
      if (curwin->w_wrow - curwin->w_cline_row >= 2) {
        context_lines = 2;
      } else {
        context_lines = curwin->w_wrow - curwin->w_cline_row;
      }

      if (pum_win_row >= size + context_lines) {
        pum_row = pum_win_row - size - context_lines;
        pum_height = size;
      } else {
        pum_row = 0;
        pum_height = pum_win_row - context_lines;
      }

      if ((p_ph > 0) && (pum_height > p_ph)) {
        pum_row += pum_height - (int)p_ph;
        pum_height = (int)p_ph;
      }
    } else {
      // pum below "pum_win_row"
      pum_above = false;

      // Leave two lines of context if possible
      validate_cheight();
      if (curwin->w_cline_row + curwin->w_cline_height - curwin->w_wrow >= 3) {
        context_lines = 3;
      } else {
        context_lines = curwin->w_cline_row
                        + curwin->w_cline_height - curwin->w_wrow;
      }

      pum_row = pum_win_row + context_lines;
      if (size > below_row - pum_row) {
        pum_height = below_row - pum_row;
      } else {
        pum_height = size;
      }

      if ((p_ph > 0) && (pum_height > p_ph)) {
        pum_height = (int)p_ph;
      }
    }

    // don't display when we only have room for one line
    if ((pum_height < 1) || ((pum_height == 1) && (size > 1))) {
      return;
    }

    // If there is a preview window above avoid drawing over it.
    if (pvwin != NULL && pum_row < above_row && pum_height > above_row) {
      pum_row = above_row;
      pum_height = pum_win_row - above_row;
    }
    if (pum_external) {
      return;
    }

    pum_array = array;
    pum_size = size;
    pum_compute_size();
    int max_width = pum_base_width;

    // if there are more items than room we need a scrollbar
    if (pum_height < size) {
      pum_scrollbar = 1;
      max_width++;
    } else {
      pum_scrollbar = 0;
    }

    if (def_width < max_width) {
      def_width = max_width;
    }

    if ((((cursor_col < Columns - p_pw) || (cursor_col < Columns - max_width))
         && !pum_rl)
        || (pum_rl && ((cursor_col > p_pw) || (cursor_col > max_width)))) {
      // align pum with "cursor_col"
      pum_col = cursor_col;

      // start with the maximum space available
      if (pum_rl) {
        pum_width = pum_col - pum_scrollbar + 1;
      } else {
        assert(Columns - pum_col - pum_scrollbar >= INT_MIN
               && Columns - pum_col - pum_scrollbar <= INT_MAX);
        pum_width = (int)(Columns - pum_col - pum_scrollbar);
      }

      if ((pum_width > max_width + pum_kind_width + pum_extra_width + 1)
          && (pum_width > p_pw)) {
        // the width is more than needed for the items, make it
        // narrower
        pum_width = max_width + pum_kind_width + pum_extra_width + 1;

        if (pum_width < p_pw) {
          pum_width = (int)p_pw;
        }
      } else if (((cursor_col > p_pw || cursor_col > max_width) && !pum_rl)
                 || (pum_rl && (cursor_col < Columns - p_pw
                                || cursor_col < Columns - max_width))) {
        // align pum edge with "cursor_col"
        if (pum_rl && W_ENDCOL(curwin) < max_width + pum_scrollbar + 1) {
          pum_col = cursor_col + max_width + pum_scrollbar + 1;
          if (pum_col >= Columns) {
            pum_col = Columns - 1;
          }
        } else if (!pum_rl) {
          if (curwin->w_wincol > Columns - max_width - pum_scrollbar
              && max_width <= p_pw) {
            // use full width to end of the screen
            pum_col = Columns - max_width - pum_scrollbar;
            if (pum_col < 0) {
              pum_col = 0;
            }
          }
        }

        if (pum_rl) {
          pum_width = pum_col - pum_scrollbar + 1;
        } else {
          pum_width = Columns - pum_col - pum_scrollbar;
        }

        if (pum_width < p_pw) {
          pum_width = (int)p_pw;
          if (pum_rl) {
            if (pum_width > pum_col) {
              pum_width = pum_col;
            }
          } else {
            if (pum_width >= Columns - pum_col) {
              pum_width = Columns - pum_col - 1;
            }
          }
        } else if (pum_width > max_width + pum_kind_width + pum_extra_width + 1
                   && pum_width > p_pw) {
          pum_width = max_width + pum_kind_width + pum_extra_width + 1;
          if (pum_width < p_pw) {
            pum_width = (int)p_pw;
          }
        }
      }
    } else if (Columns < def_width) {
      // not enough room, will use what we have
      if (pum_rl) {
        assert(Columns - 1 >= INT_MIN);
        pum_col = (int)(Columns - 1);
      } else {
        pum_col = 0;
      }
      assert(Columns - 1 >= INT_MIN);
      pum_width = (int)(Columns - 1);
    } else {
      if (max_width > p_pw) {
        // truncate
        max_width = (int)p_pw;
      }

      if (pum_rl) {
        pum_col = max_width - 1;
      } else {
        assert(Columns - max_width >= INT_MIN
               && Columns - max_width <= INT_MAX);
        pum_col = (int)(Columns - max_width);
      }
      pum_width = max_width - pum_scrollbar;
    }

    // Set selected item and redraw.  If the window size changed need to redo
    // the positioning.  Limit this to two times, when there is not much
    // room the window size will keep changing.
  } while (pum_set_selected(selected, redo_count) && (++redo_count <= 2));

  pum_redraw();
}

/// Redraw the popup menu, using "pum_first" and "pum_selected".
void pum_redraw(void)
{
  int row = 0;
  int col;
  int attr_norm = win_hl_attr(curwin, HLF_PNI);
  int attr_select = win_hl_attr(curwin, HLF_PSI);
  int attr_scroll = win_hl_attr(curwin, HLF_PSB);
  int attr_thumb = win_hl_attr(curwin, HLF_PST);
  int attr;
  int i;
  int idx;
  char_u *s;
  char_u *p = NULL;
  int totwidth, width, w;
  int thumb_pos = 0;
  int thumb_height = 1;
  int round;
  int n;

  int grid_width = pum_width;
  int col_off = 0;
  bool extra_space = false;
  if (pum_rl) {
    col_off = pum_width;
    if (pum_col < curwin->w_wincol + curwin->w_width - 1) {
      grid_width += 1;
      extra_space = true;
    }
  } else if (pum_col > 0) {
    grid_width += 1;
    col_off = 1;
    extra_space = true;
  }
  if (pum_scrollbar > 0) {
    grid_width++;
  }

  grid_assign_handle(&pum_grid);

  pum_grid.zindex = ((State == CMDLINE)
                     ? kZIndexCmdlinePopupMenu : kZIndexPopupMenu);

  bool moved = ui_comp_put_grid(&pum_grid, pum_row, pum_col-col_off,
                                pum_height, grid_width, false, true);
  bool invalid_grid = moved || pum_invalid;
  pum_invalid = false;
  must_redraw_pum = false;

  if (!pum_grid.chars
      || pum_grid.Rows != pum_height || pum_grid.Columns != grid_width) {
    grid_alloc(&pum_grid, pum_height, grid_width, !invalid_grid, false);
    ui_call_grid_resize(pum_grid.handle, pum_grid.Columns, pum_grid.Rows);
  } else if (invalid_grid) {
    grid_invalidate(&pum_grid);
  }
  if (ui_has(kUIMultigrid)) {
    const char *anchor = pum_above ? "SW" : "NW";
    int row_off = pum_above ? -pum_height : 0;
    ui_call_win_float_pos(pum_grid.handle, -1, cstr_to_string(anchor),
                          pum_anchor_grid, pum_row-row_off, pum_col-col_off,
                          false, pum_grid.zindex);
  }


  // Never display more than we have
  if (pum_first > pum_size - pum_height) {
    pum_first = pum_size - pum_height;
  }

  if (pum_scrollbar) {
    thumb_height = pum_height * pum_height / pum_size;
    if (thumb_height == 0) {
      thumb_height = 1;
    }
    thumb_pos = (pum_first * (pum_height - thumb_height)
                 + (pum_size - pum_height) / 2)
                / (pum_size - pum_height);
  }

  for (i = 0; i < pum_height; ++i) {
    idx = i + pum_first;
    attr = (idx == pum_selected) ? attr_select : attr_norm;

    grid_puts_line_start(&pum_grid, row);

    // prepend a space if there is room
    if (extra_space) {
      if (pum_rl) {
        grid_putchar(&pum_grid, ' ', row, col_off + 1, attr);
      } else {
        grid_putchar(&pum_grid, ' ', row, col_off - 1, attr);
      }
    }

    // Display each entry, use two spaces for a Tab.
    // Do this 3 times: For the main text, kind and extra info
    col = col_off;
    totwidth = 0;

    for (round = 1; round <= 3; ++round) {
      width = 0;
      s = NULL;

      switch (round) {
      case 1:
        p = pum_array[idx].pum_text;
        break;

      case 2:
        p = pum_array[idx].pum_kind;
        break;

      case 3:
        p = pum_array[idx].pum_extra;
        break;
      }

      if (p != NULL) {
        for (;; MB_PTR_ADV(p)) {
          if (s == NULL) {
            s = p;
          }
          w = ptr2cells(p);

          if ((*p == NUL) || (*p == TAB) || (totwidth + w > pum_width)) {
            // Display the text that fits or comes before a Tab.
            // First convert it to printable characters.
            char_u *st;
            char_u saved = *p;

            *p = NUL;
            st = (char_u *)transstr((const char *)s, true);
            *p = saved;

            if (pum_rl) {
              char_u *rt = reverse_text(st);
              char_u *rt_start = rt;
              int size = vim_strsize(rt);

              if (size > pum_width) {
                do {
                  size -= utf_ptr2cells(rt);
                  MB_PTR_ADV(rt);
                } while (size > pum_width);

                if (size < pum_width) {
                  // Most left character requires 2-cells but only 1 cell
                  // is available on screen.  Put a '<' on the left of the
                  // pum item
                  *(--rt) = '<';
                  size++;
                }
              }
              grid_puts_len(&pum_grid, rt, (int)STRLEN(rt), row,
                            col - size + 1, attr);
              xfree(rt_start);
              xfree(st);
              col -= width;
            } else {
              int size = (int)STRLEN(st);
              int cells = (int)mb_string2cells(st);

              // only draw the text that fits
              while (size > 0 && col + cells > pum_width + pum_col) {
                size--;
                size -= utf_head_off(st, st + size);
                cells -= utf_ptr2cells(st + size);
              }

              grid_puts_len(&pum_grid, st, size, row, col, attr);
              xfree(st);
              col += width;
            }

            if (*p != TAB) {
              break;
            }

            // Display two spaces for a Tab.
            if (pum_rl) {
              grid_puts_len(&pum_grid, (char_u *)"  ", 2, row, col - 1,
                            attr);
              col -= 2;
            } else {
              grid_puts_len(&pum_grid, (char_u *)"  ", 2, row, col, attr);
              col += 2;
            }
            totwidth += 2;
            // start text at next char
            s = NULL;
            width = 0;
          } else {
            width += w;
          }
        }
      }

      if (round > 1) {
        n = pum_kind_width + 1;
      } else {
        n = 1;
      }

      // Stop when there is nothing more to display.
      if ((round == 3)
          || ((round == 2)
              && (pum_array[idx].pum_extra == NULL))
          || ((round == 1)
              && (pum_array[idx].pum_kind == NULL)
              && (pum_array[idx].pum_extra == NULL))
          || (pum_base_width + n >= pum_width)) {
        break;
      }

      if (pum_rl) {
        grid_fill(&pum_grid, row, row + 1, col_off - pum_base_width - n + 1,
                  col + 1, ' ', ' ', attr);
        col = col_off - pum_base_width - n + 1;
      } else {
        grid_fill(&pum_grid, row, row + 1, col,
                  col_off + pum_base_width + n, ' ', ' ', attr);
        col = col_off + pum_base_width + n;
      }
      totwidth = pum_base_width + n;
    }

    if (pum_rl) {
      grid_fill(&pum_grid, row, row + 1, col_off - pum_width + 1, col + 1,
                ' ', ' ', attr);
    } else {
      grid_fill(&pum_grid, row, row + 1, col, col_off + pum_width, ' ', ' ',
                attr);
    }

    if (pum_scrollbar > 0) {
      if (pum_rl) {
        grid_putchar(&pum_grid, ' ', row, col_off - pum_width,
                     i >= thumb_pos && i < thumb_pos + thumb_height
                     ? attr_thumb : attr_scroll);
      } else {
        grid_putchar(&pum_grid, ' ', row, col_off + pum_width,
                     i >= thumb_pos && i < thumb_pos + thumb_height
                     ? attr_thumb : attr_scroll);
      }
    }
    grid_puts_line_flush(false);
    row++;
  }
}

/// Set the index of the currently selected item.  The menu will scroll when
/// necessary.  When "n" is out of range don't scroll.
/// This may be repeated when the preview window is used:
/// "repeat" == 0: open preview window normally
/// "repeat" == 1: open preview window but don't set the size
/// "repeat" == 2: don't open preview window
///
/// @param n
/// @param repeat
///
/// @returns TRUE when the window was resized and the location of the popup
/// menu must be recomputed.
static int pum_set_selected(int n, int repeat)
{
  int resized = FALSE;
  int context = pum_height / 2;

  pum_selected = n;

  if ((pum_selected >= 0) && (pum_selected < pum_size)) {
    if (pum_first > pum_selected - 4) {
      // scroll down; when we did a jump it's probably a PageUp then
      // scroll a whole page
      if (pum_first > pum_selected - 2) {
        pum_first -= pum_height - 2;
        if (pum_first < 0) {
          pum_first = 0;
        } else if (pum_first > pum_selected) {
          pum_first = pum_selected;
        }
      } else {
        pum_first = pum_selected;
      }
    } else if (pum_first < pum_selected - pum_height + 5) {
      // scroll up; when we did a jump it's probably a PageDown then
      // scroll a whole page
      if (pum_first < pum_selected - pum_height + 1 + 2) {
        pum_first += pum_height - 2;
        if (pum_first < pum_selected - pum_height + 1) {
          pum_first = pum_selected - pum_height + 1;
        }
      } else {
        pum_first = pum_selected - pum_height + 1;
      }
    }

    // Give a few lines of context when possible.
    if (context > 3) {
      context = 3;
    }

    if (pum_height > 2) {
      if (pum_first > pum_selected - context) {
        // scroll down
        pum_first = pum_selected - context;

        if (pum_first < 0) {
          pum_first = 0;
        }
      } else if (pum_first < pum_selected + context - pum_height + 1) {
        // scroll up
        pum_first = pum_selected + context - pum_height + 1;
      }
    }

    // Show extra info in the preview window if there is something and
    // 'completeopt' contains "preview".
    // Skip this when tried twice already.
    // Skip this also when there is not much room.
    // NOTE: Be very careful not to sync undo!
    if ((pum_array[pum_selected].pum_info != NULL)
        && (Rows > 10)
        && (repeat <= 1)
        && (vim_strchr(p_cot, 'p') != NULL)) {
      win_T *curwin_save = curwin;
      tabpage_T *curtab_save = curtab;
      int res = OK;

      // Open a preview window.  3 lines by default.  Prefer
      // 'previewheight' if set and smaller.
      g_do_tagpreview = 3;

      if ((p_pvh > 0) && (p_pvh < g_do_tagpreview)) {
        g_do_tagpreview = (int)p_pvh;
      }
      RedrawingDisabled++;
      // Prevent undo sync here, if an autocommand syncs undo weird
      // things can happen to the undo tree.
      no_u_sync++;
      resized = prepare_tagpreview(false);
      no_u_sync--;
      RedrawingDisabled--;
      g_do_tagpreview = 0;

      if (curwin->w_p_pvw) {
        if (!resized
            && (curbuf->b_nwindows == 1)
            && (curbuf->b_fname == NULL)
            && (curbuf->b_p_bt[0] == 'n')
            && (curbuf->b_p_bt[2] == 'f')
            && (curbuf->b_p_bh[0] == 'w')) {
          // Already a "wipeout" buffer, make it empty.
          while (!buf_is_empty(curbuf)) {
            ml_delete((linenr_T)1, false);
          }
        } else {
          // Don't want to sync undo in the current buffer.
          no_u_sync++;
          res = do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, 0, NULL);
          no_u_sync--;

          if (res == OK) {
            // Edit a new, empty buffer. Set options for a "wipeout"
            // buffer.
            set_option_value("swf", 0L, NULL, OPT_LOCAL);
            set_option_value("bl", 0L, NULL, OPT_LOCAL);
            set_option_value("bt", 0L, "nofile", OPT_LOCAL);
            set_option_value("bh", 0L, "wipe", OPT_LOCAL);
            set_option_value("diff", 0L, NULL, OPT_LOCAL);
          }
        }

        if (res == OK) {
          char_u *p, *e;
          linenr_T lnum = 0;

          for (p = pum_array[pum_selected].pum_info; *p != NUL;) {
            e = vim_strchr(p, '\n');
            if (e == NULL) {
              ml_append(lnum++, p, 0, false);
              break;
            } else {
              *e = NUL;
              ml_append(lnum++, p, (int)(e - p + 1), false);
              *e = '\n';
              p = e + 1;
            }
          }

          // Increase the height of the preview window to show the
          // text, but no more than 'previewheight' lines.
          if (repeat == 0) {
            if (lnum > p_pvh) {
              lnum = p_pvh;
            }

            if (curwin->w_height < lnum) {
              win_setheight((int)lnum);
              resized = TRUE;
            }
          }

          curbuf->b_changed = false;
          curbuf->b_p_ma = FALSE;
          curwin->w_cursor.lnum = 1;
          curwin->w_cursor.col = 0;

          if ((curwin != curwin_save && win_valid(curwin_save))
              || (curtab != curtab_save && valid_tabpage(curtab_save))) {
            if (curtab != curtab_save && valid_tabpage(curtab_save)) {
              goto_tabpage_tp(curtab_save, false, false);
            }

            // When the first completion is done and the preview
            // window is not resized, skip the preview window's
            // status line redrawing.
            if (ins_compl_active() && !resized) {
              curwin->w_redr_status = FALSE;
            }

            // Return cursor to where we were
            validate_cursor();
            redraw_later(curwin, SOME_VALID);

            // When the preview window was resized we need to
            // update the view on the buffer.  Only go back to
            // the window when needed, otherwise it will always be
            // redraw.
            if (resized) {
              no_u_sync++;
              win_enter(curwin_save, true);
              no_u_sync--;
              update_topline(curwin);
            }

            // Update the screen before drawing the popup menu.
            // Enable updating the status lines.
            // TODO(bfredl): can simplify, get rid of the flag munging?
            // or at least eliminate extra redraw before win_enter()?
            pum_is_visible = false;
            update_screen(0);
            pum_is_visible = true;

            if (!resized && win_valid(curwin_save)) {
              no_u_sync++;
              win_enter(curwin_save, true);
              no_u_sync--;
            }

            // May need to update the screen again when there are
            // autocommands involved.
            pum_is_visible = false;
            update_screen(0);
            pum_is_visible = true;
          }
        }
      }
    }
  }

  return resized;
}

/// Undisplay the popup menu (later).
void pum_undisplay(bool immediate)
{
  pum_is_visible = false;
  pum_array = NULL;
  must_redraw_pum = false;

  if (immediate) {
    pum_check_clear();
  }
}

void pum_check_clear(void)
{
  if (!pum_is_visible && pum_is_drawn) {
    if (pum_external) {
      ui_call_popupmenu_hide();
    } else {
      ui_comp_remove_grid(&pum_grid);
      if (ui_has(kUIMultigrid)) {
        ui_call_win_close(pum_grid.handle);
        ui_call_grid_destroy(pum_grid.handle);
      }
      // TODO(bfredl): consider keeping float grids allocated.
      grid_free(&pum_grid);
    }
    pum_is_drawn = false;
  }
}

/// Clear the popup menu.  Currently only resets the offset to the first
/// displayed item.
void pum_clear(void)
{
  pum_first = 0;
}

/// @return true if the popup menu is displayed.
bool pum_visible(void)
{
  return pum_is_visible;
}

/// @return true if the popup menu is displayed and drawn on the grid.
bool pum_drawn(void)
{
  return pum_visible() && !pum_external;
}

/// Screen was cleared, need to redraw next time
void pum_invalidate(void)
{
  pum_invalid = true;
}

void pum_recompose(void)
{
  ui_comp_compose_grid(&pum_grid);
}

/// Gets the height of the menu.
///
/// @return the height of the popup menu, the number of entries visible.
/// Only valid when pum_visible() returns TRUE!
int pum_get_height(void)
{
  if (pum_external) {
    int ui_pum_height = ui_pum_get_height();
    if (ui_pum_height) {
      return ui_pum_height;
    }
  }
  return pum_height;
}

/// Add size information about the pum to "dict".
void pum_set_event_info(dict_T *dict)
{
  if (!pum_visible()) {
    return;
  }
  double w, h, r, c;
  if (!ui_pum_get_pos(&w, &h, &r, &c)) {
    w = (double)pum_width;
    h = (double)pum_height;
    r = (double)pum_row;
    c = (double)pum_col;
  }
  (void)tv_dict_add_float(dict, S_LEN("height"), h);
  (void)tv_dict_add_float(dict, S_LEN("width"), w);
  (void)tv_dict_add_float(dict, S_LEN("row"), r);
  (void)tv_dict_add_float(dict, S_LEN("col"), c);
  (void)tv_dict_add_nr(dict, S_LEN("size"), pum_size);
  (void)tv_dict_add_bool(dict, S_LEN("scrollbar"),
                         pum_scrollbar ? kBoolVarTrue : kBoolVarFalse);
}
