// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file popupmenu.c
///
/// Popup menu (PUM)

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
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
# include "popupmenu.c.generated.h"
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
  int redo_count = 0;
  int pum_win_row;
  int cursor_col;

  if (!pum_is_visible) {
    // To keep the code simple, we only allow changing the
    // draw mode when the popup menu is not being displayed
    pum_external = ui_has(kUIPopupmenu)
                   || (State == MODE_CMDLINE && ui_has(kUIWildmenu));
  }

  pum_rl = (curwin->w_p_rl && State != MODE_CMDLINE);

  do {
    // Mark the pum as visible already here,
    // to avoid that must_redraw is set when 'cursorcolumn' is on.
    pum_is_visible = true;
    pum_is_drawn = true;
    validate_cursor_col();
    int above_row = 0;
    int below_row = cmdline_row;

    // wildoptions=pum
    if (State == MODE_CMDLINE) {
      pum_win_row = ui_has(kUICmdline) ? 0 : cmdline_row;
      cursor_col = cmd_startcol;
      pum_anchor_grid = ui_has(kUICmdline) ? -1 : DEFAULT_GRID_HANDLE;
    } else {
      // anchor position: the start of the completed word
      pum_win_row = curwin->w_wrow;
      if (pum_rl) {
        cursor_col = curwin->w_width_inner - curwin->w_wcol - 1;
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
        Arena arena = ARENA_EMPTY;
        Array arr = arena_array(&arena, (size_t)size);
        for (int i = 0; i < size; i++) {
          Array item = arena_array(&arena, 4);
          ADD_C(item, CSTR_AS_OBJ(array[i].pum_text));
          ADD_C(item, CSTR_AS_OBJ(array[i].pum_kind));
          ADD_C(item, CSTR_AS_OBJ(array[i].pum_extra));
          ADD_C(item, CSTR_AS_OBJ(array[i].pum_info));
          ADD_C(arr, ARRAY_OBJ(item));
        }
        ui_call_popupmenu_show(arr, selected, pum_win_row, cursor_col,
                               pum_anchor_grid);
        arena_mem_free(arena_finish(&arena));
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

    int min_row = 0;
    int min_col = 0;
    int max_col = Columns;
    int win_start_col = curwin->w_wincol;
    int win_end_col = W_ENDCOL(curwin);
    if (!(State & MODE_CMDLINE) && ui_has(kUIMultigrid)) {
      above_row -= curwin->w_winrow;
      below_row = MAX(below_row - curwin->w_winrow, curwin->w_grid.rows);
      min_row = -curwin->w_winrow;
      min_col = -curwin->w_wincol;
      max_col = MAX(Columns - curwin->w_wincol, curwin->w_grid.cols);
      win_start_col = 0;
      win_end_col = curwin->w_grid.cols;
    }

    // Figure out the size and position of the pum.
    if (size < PUM_DEF_HEIGHT) {
      pum_height = size;
    } else {
      pum_height = PUM_DEF_HEIGHT;
    }

    if (p_ph > 0 && pum_height > p_ph) {
      pum_height = (int)p_ph;
    }

    // Put the pum below "pum_win_row" if possible.
    // If there are few lines decide on where there is more room.
    if (pum_win_row + 2 >= below_row - pum_height
        && pum_win_row - above_row > (below_row - above_row) / 2) {
      // pum above "pum_win_row"
      pum_above = true;

      if (State == MODE_CMDLINE) {
        // for cmdline pum, no need for context lines
        context_lines = 0;
      } else {
        // Leave two lines of context if possible
        if (curwin->w_wrow - curwin->w_cline_row >= 2) {
          context_lines = 2;
        } else {
          context_lines = curwin->w_wrow - curwin->w_cline_row;
        }
      }

      if (pum_win_row - min_row >= size + context_lines) {
        pum_row = pum_win_row - size - context_lines;
        pum_height = size;
      } else {
        pum_row = min_row;
        pum_height = pum_win_row - min_row - context_lines;
      }

      if (p_ph > 0 && pum_height > p_ph) {
        pum_row += pum_height - (int)p_ph;
        pum_height = (int)p_ph;
      }
    } else {
      // pum below "pum_win_row"
      pum_above = false;

      if (State == MODE_CMDLINE) {
        // for cmdline pum, no need for context lines
        context_lines = 0;
      } else {
        // Leave two lines of context if possible
        validate_cheight();
        if (curwin->w_cline_row + curwin->w_cline_height - curwin->w_wrow >= 3) {
          context_lines = 3;
        } else {
          context_lines = curwin->w_cline_row + curwin->w_cline_height - curwin->w_wrow;
        }
      }

      pum_row = pum_win_row + context_lines;
      if (size > below_row - pum_row) {
        pum_height = below_row - pum_row;
      } else {
        pum_height = size;
      }

      if (p_ph > 0 && pum_height > p_ph) {
        pum_height = (int)p_ph;
      }
    }

    // don't display when we only have room for one line
    if (pum_height < 1 || (pum_height == 1 && size > 1)) {
      return;
    }

    // If there is a preview window above avoid drawing over it.
    if (pvwin != NULL && pum_row < above_row && pum_height > above_row) {
      pum_row = above_row;
      pum_height = pum_win_row - above_row;
    }

    pum_array = array;
    // Set "pum_size" before returning so that pum_set_event_info() gets the correct size.
    pum_size = size;

    if (pum_external) {
      return;
    }

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

    if (((cursor_col < max_col - p_pw
          || cursor_col < max_col - max_width) && !pum_rl)
        || (pum_rl && (cursor_col - min_col > p_pw
                       || cursor_col - min_col > max_width))) {
      // align pum with "cursor_col"
      pum_col = cursor_col;

      // start with the maximum space available
      if (pum_rl) {
        pum_width = pum_col - min_col - pum_scrollbar + 1;
      } else {
        assert(max_col - pum_col - pum_scrollbar >= 0);
        pum_width = max_col - pum_col - pum_scrollbar;
      }

      if (pum_width > max_width + pum_kind_width + pum_extra_width + 1
          && pum_width > p_pw) {
        // the width is more than needed for the items, make it
        // narrower
        pum_width = max_width + pum_kind_width + pum_extra_width + 1;

        if (pum_width < p_pw) {
          pum_width = (int)p_pw;
        }
      } else if (((cursor_col - min_col > p_pw
                   || cursor_col - min_col > max_width) && !pum_rl)
                 || (pum_rl && (cursor_col < max_col - p_pw
                                || cursor_col < max_col - max_width))) {
        // align pum edge with "cursor_col"
        if (pum_rl && win_end_col < max_width + pum_scrollbar + 1) {
          pum_col = cursor_col + max_width + pum_scrollbar + 1;
          if (pum_col >= max_col) {
            pum_col = max_col - 1;
          }
        } else if (!pum_rl) {
          if (win_start_col > max_col - max_width - pum_scrollbar
              && max_width <= p_pw) {
            // use full width to end of the screen
            pum_col = max_col - max_width - pum_scrollbar;
            if (pum_col < min_col) {
              pum_col = min_col;
            }
          }
        }

        if (pum_rl) {
          pum_width = pum_col - min_col - pum_scrollbar + 1;
        } else {
          pum_width = max_col - pum_col - pum_scrollbar;
        }

        if (pum_width < p_pw) {
          pum_width = (int)p_pw;
          if (pum_rl) {
            if (pum_width > pum_col - min_col) {
              pum_width = pum_col - min_col;
            }
          } else {
            if (pum_width >= max_col - pum_col) {
              pum_width = max_col - pum_col - 1;
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
    } else if (max_col - min_col < def_width) {
      // not enough room, will use what we have
      if (pum_rl) {
        pum_col = max_col - 1;
      } else {
        pum_col = min_col;
      }
      pum_width = max_col - min_col - 1;
    } else {
      if (max_width > p_pw) {
        // truncate
        max_width = (int)p_pw;
      }
      if (pum_rl) {
        pum_col = min_col + max_width - 1;
      } else {
        pum_col = max_col - max_width;
      }
      pum_width = max_width - pum_scrollbar;
    }

    // Set selected item and redraw.  If the window size changed need to redo
    // the positioning.  Limit this to two times, when there is not much
    // room the window size will keep changing.
  } while (pum_set_selected(selected, redo_count) && ++redo_count <= 2);

  pum_grid.zindex = (State == MODE_CMDLINE) ? kZIndexCmdlinePopupMenu : kZIndexPopupMenu;
  pum_redraw();
}

/// Redraw the popup menu, using "pum_first" and "pum_selected".
void pum_redraw(void)
{
  int row = 0;
  int attr_scroll = win_hl_attr(curwin, HLF_PSB);
  int attr_thumb = win_hl_attr(curwin, HLF_PST);
  int i;
  char *s;
  char *p = NULL;
  int width;
  int w;
  int thumb_pos = 0;
  int thumb_height = 1;
  int n;

#define HA(hlf) (win_hl_attr(curwin, (hlf)))
  //                         "word"       "kind"       "extra text"
  const int attrsNorm[3] = { HA(HLF_PNI), HA(HLF_PNK), HA(HLF_PNX) };
  const int attrsSel[3] = { HA(HLF_PSI), HA(HLF_PSK), HA(HLF_PSX) };
#undef HA

  int grid_width = pum_width;
  int col_off = 0;
  bool extra_space = false;
  if (pum_rl) {
    col_off = pum_width - 1;
    assert(!(State & MODE_CMDLINE));
    int win_end_col = ui_has(kUIMultigrid) ? curwin->w_grid.cols : W_ENDCOL(curwin);
    if (pum_col < win_end_col - 1) {
      grid_width += 1;
      extra_space = true;
    }
  } else {
    int min_col = (!(State & MODE_CMDLINE) && ui_has(kUIMultigrid)) ? -curwin->w_wincol : 0;
    if (pum_col > min_col) {
      grid_width += 1;
      col_off = 1;
      extra_space = true;
    }
  }
  if (pum_scrollbar > 0) {
    grid_width++;
    if (pum_rl) {
      col_off++;
    }
  }

  grid_assign_handle(&pum_grid);

  bool moved = ui_comp_put_grid(&pum_grid, pum_row, pum_col - col_off,
                                pum_height, grid_width, false, true);
  bool invalid_grid = moved || pum_invalid;
  pum_invalid = false;
  must_redraw_pum = false;

  if (!pum_grid.chars
      || pum_grid.rows != pum_height || pum_grid.cols != grid_width) {
    grid_alloc(&pum_grid, pum_height, grid_width, !invalid_grid, false);
    ui_call_grid_resize(pum_grid.handle, pum_grid.cols, pum_grid.rows);
  } else if (invalid_grid) {
    grid_invalidate(&pum_grid);
  }
  if (ui_has(kUIMultigrid)) {
    const char *anchor = pum_above ? "SW" : "NW";
    int row_off = pum_above ? -pum_height : 0;
    ui_call_win_float_pos(pum_grid.handle, -1, cstr_as_string((char *)anchor),
                          pum_anchor_grid, pum_row - row_off, pum_col - col_off,
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

  for (i = 0; i < pum_height; i++) {
    int idx = i + pum_first;
    const int *const attrs = (idx == pum_selected) ? attrsSel : attrsNorm;
    int attr = attrs[0];  // start with "word" highlight

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
    // Do this 3 times:
    // 0 - main text
    // 1 - kind
    // 2 - extra info
    int grid_col = col_off;
    int totwidth = 0;

    for (int round = 0; round < 3; round++) {
      attr = attrs[round];
      width = 0;
      s = NULL;

      switch (round) {
      case 0:
        p = pum_array[idx].pum_text; break;
      case 1:
        p = pum_array[idx].pum_kind; break;
      case 2:
        p = pum_array[idx].pum_extra; break;
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
            char *st;
            char saved = *p;

            if (saved != NUL) {
              *p = NUL;
            }
            st = transstr(s, true);
            if (saved != NUL) {
              *p = saved;
            }

            if (pum_rl) {
              char *rt = reverse_text(st);
              char *rt_start = rt;
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
              grid_puts_len(&pum_grid, rt, (int)strlen(rt), row, grid_col - size + 1, attr);
              xfree(rt_start);
              xfree(st);
              grid_col -= width;
            } else {
              // use grid_puts_len() to truncate the text
              grid_puts(&pum_grid, st, row, grid_col, attr);
              xfree(st);
              grid_col += width;
            }

            if (*p != TAB) {
              break;
            }

            // Display two spaces for a Tab.
            if (pum_rl) {
              grid_puts_len(&pum_grid, "  ", 2, row, grid_col - 1,
                            attr);
              grid_col -= 2;
            } else {
              grid_puts_len(&pum_grid, "  ", 2, row, grid_col, attr);
              grid_col += 2;
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

      if (round > 0) {
        n = pum_kind_width + 1;
      } else {
        n = 1;
      }

      // Stop when there is nothing more to display.
      if ((round == 2)
          || ((round == 1)
              && (pum_array[idx].pum_extra == NULL))
          || ((round == 0)
              && (pum_array[idx].pum_kind == NULL)
              && (pum_array[idx].pum_extra == NULL))
          || (pum_base_width + n >= pum_width)) {
        break;
      }

      if (pum_rl) {
        grid_fill(&pum_grid, row, row + 1, col_off - pum_base_width - n + 1,
                  grid_col + 1, ' ', ' ', attr);
        grid_col = col_off - pum_base_width - n + 1;
      } else {
        grid_fill(&pum_grid, row, row + 1, grid_col,
                  col_off + pum_base_width + n, ' ', ' ', attr);
        grid_col = col_off + pum_base_width + n;
      }
      totwidth = pum_base_width + n;
    }

    if (pum_rl) {
      grid_fill(&pum_grid, row, row + 1, col_off - pum_width + 1, grid_col + 1,
                ' ', ' ', attr);
    } else {
      grid_fill(&pum_grid, row, row + 1, grid_col, col_off + pum_width, ' ', ' ',
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
/// @returns true when the window was resized and the location of the popup
/// menu must be recomputed.
static bool pum_set_selected(int n, int repeat)
{
  int resized = false;
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
        int res = OK;
        if (!resized
            && (curbuf->b_nwindows == 1)
            && (curbuf->b_fname == NULL)
            && bt_nofile(curbuf)
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
            set_option_value_give_err("swf", BOOLEAN_OPTVAL(false), OPT_LOCAL);
            set_option_value_give_err("bl", BOOLEAN_OPTVAL(false), OPT_LOCAL);
            set_option_value_give_err("bt", STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL);
            set_option_value_give_err("bh", STATIC_CSTR_AS_OPTVAL("wipe"), OPT_LOCAL);
            set_option_value_give_err("diff", BOOLEAN_OPTVAL(false), OPT_LOCAL);
          }
        }

        if (res == OK) {
          char *p, *e;
          linenr_T lnum = 0;

          for (p = pum_array[pum_selected].pum_info; *p != NUL;) {
            e = vim_strchr(p, '\n');
            if (e == NULL) {
              ml_append(lnum++, p, 0, false);
              break;
            }
            *e = NUL;
            ml_append(lnum++, p, (int)(e - p + 1), false);
            *e = '\n';
            p = e + 1;
          }

          // Increase the height of the preview window to show the
          // text, but no more than 'previewheight' lines.
          if (repeat == 0) {
            if (lnum > p_pvh) {
              lnum = (linenr_T)p_pvh;
            }

            if (curwin->w_height < lnum) {
              win_setheight((int)lnum);
              resized = true;
            }
          }

          curbuf->b_changed = false;
          curbuf->b_p_ma = false;
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
              curwin->w_redr_status = false;
            }

            // Return cursor to where we were
            validate_cursor();
            redraw_later(curwin, UPD_SOME_VALID);

            // When the preview window was resized we need to
            // update the view on the buffer.  Only go back to
            // the window when needed, otherwise it will always be
            // redrawn.
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
            update_screen();
            pum_is_visible = true;

            if (!resized && win_valid(curwin_save)) {
              no_u_sync++;
              win_enter(curwin_save, true);
              no_u_sync--;
            }

            // May need to update the screen again when there are
            // autocommands involved.
            pum_is_visible = false;
            update_screen();
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
    pum_external = false;
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

void pum_ext_select_item(int item, bool insert, bool finish)
{
  if (!pum_visible() || item < -1 || item >= pum_size) {
    return;
  }
  pum_want.active = true;
  pum_want.item = item;
  pum_want.insert = insert;
  pum_want.finish = finish;
}

/// Gets the height of the menu.
///
/// @return the height of the popup menu, the number of entries visible.
/// Only valid when pum_visible() returns true!
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

static void pum_position_at_mouse(int min_width)
{
  int min_row = 0;
  int max_row = Rows;
  int max_col = Columns;
  if (mouse_grid > 1) {
    win_T *wp = get_win_by_grid_handle(mouse_grid);
    if (wp != NULL) {
      min_row = -wp->w_winrow;
      max_row = MAX(Rows - wp->w_winrow, wp->w_grid.rows);
      max_col = MAX(Columns - wp->w_wincol, wp->w_grid.cols);
    }
  }
  pum_anchor_grid = mouse_grid;
  if (max_row - mouse_row > pum_size) {
    // Enough space below the mouse row.
    pum_above = false;
    pum_row = mouse_row + 1;
    if (pum_height > max_row - pum_row) {
      pum_height = max_row - pum_row;
    }
  } else {
    // Show above the mouse row, reduce height if it does not fit.
    pum_above = true;
    pum_row = mouse_row - pum_size;
    if (pum_row < min_row) {
      pum_height += pum_row - min_row;
      pum_row = min_row;
    }
  }
  if (max_col - mouse_col >= pum_base_width
      || max_col - mouse_col > min_width) {
    // Enough space to show at mouse column.
    pum_col = mouse_col;
  } else {
    // Not enough space, right align with window.
    pum_col = max_col - (pum_base_width > min_width ? min_width : pum_base_width);
  }

  pum_width = max_col - pum_col;
  if (pum_width > pum_base_width + 1) {
    pum_width = pum_base_width + 1;
  }
}

/// Select the pum entry at the mouse position.
static void pum_select_mouse_pos(void)
{
  if (mouse_grid == pum_grid.handle) {
    pum_selected = mouse_row;
    return;
  } else if (mouse_grid != pum_anchor_grid) {
    pum_selected = -1;
    return;
  }

  int idx = mouse_row - pum_row;

  if (idx < 0 || idx >= pum_size) {
    pum_selected = -1;
  } else if (*pum_array[idx].pum_text != NUL) {
    pum_selected = idx;
  }
}

/// Execute the currently selected popup menu item.
static void pum_execute_menu(vimmenu_T *menu, int mode)
{
  int idx = 0;
  exarg_T ea;

  for (vimmenu_T *mp = menu->children; mp != NULL; mp = mp->next) {
    if ((mp->modes & mp->enabled & mode) && idx++ == pum_selected) {
      CLEAR_FIELD(ea);
      execute_menu(&ea, mp, -1);
      break;
    }
  }
}

/// Open the terminal version of the popup menu and don't return until it is closed.
void pum_show_popupmenu(vimmenu_T *menu)
{
  pum_undisplay(true);
  pum_size = 0;
  int mode = get_menu_mode_flag();

  for (vimmenu_T *mp = menu->children; mp != NULL; mp = mp->next) {
    if (menu_is_separator(mp->dname) || (mp->modes & mp->enabled & mode)) {
      pum_size++;
    }
  }

  // When there are only Terminal mode menus, using "popup Edit" results in
  // pum_size being zero.
  if (pum_size <= 0) {
    emsg(_(e_menu_only_exists_in_another_mode));
    return;
  }

  int idx = 0;
  pumitem_T *array = (pumitem_T *)xcalloc((size_t)pum_size, sizeof(pumitem_T));

  for (vimmenu_T *mp = menu->children; mp != NULL; mp = mp->next) {
    char *s = NULL;
    // Make a copy of the text, the menu may be redefined in a callback.
    if (menu_is_separator(mp->dname)) {
      s = "";
    } else if (mp->modes & mp->enabled & mode) {
      s = mp->dname;
    }
    if (s != NULL) {
      s = xstrdup(s);
      array[idx++].pum_text = s;
    }
  }

  pum_array = array;
  pum_compute_size();
  pum_scrollbar = 0;
  pum_height = pum_size;
  pum_position_at_mouse(20);

  pum_selected = -1;
  pum_first = 0;
  if (!p_mousemev) {
    // Pretend 'mousemoveevent' is set.
    ui_call_option_set(STATIC_CSTR_AS_STRING("mousemoveevent"), BOOLEAN_OBJ(true));
  }

  while (true) {
    pum_is_visible = true;
    pum_is_drawn = true;
    pum_grid.zindex = kZIndexCmdlinePopupMenu;  // show above cmdline area #23275
    pum_redraw();
    setcursor_mayforce(true);

    int c = vgetc();

    // Bail out when typing Esc, CTRL-C or some callback or <expr> mapping
    // closed the popup menu.
    if (c == ESC || c == Ctrl_C || pum_array == NULL) {
      break;
    } else if (c == CAR || c == NL) {
      // enter: select current item, if any, and close
      pum_execute_menu(menu, mode);
      break;
    } else if (c == 'k' || c == K_UP || c == K_MOUSEUP) {
      // cursor up: select previous item
      while (pum_selected > 0) {
        pum_selected--;
        if (*array[pum_selected].pum_text != NUL) {
          break;
        }
      }
    } else if (c == 'j' || c == K_DOWN || c == K_MOUSEDOWN) {
      // cursor down: select next item
      while (pum_selected < pum_size - 1) {
        pum_selected++;
        if (*array[pum_selected].pum_text != NUL) {
          break;
        }
      }
    } else if (c == K_RIGHTMOUSE) {
      // Right mouse down: reposition the menu.
      vungetc(c);
      break;
    } else if (c == K_LEFTDRAG || c == K_RIGHTDRAG || c == K_MOUSEMOVE) {
      // mouse moved: select item in the mouse row
      pum_select_mouse_pos();
    } else if (c == K_LEFTMOUSE || c == K_LEFTMOUSE_NM || c == K_RIGHTRELEASE) {
      // left mouse click: select clicked item, if any, and close;
      // right mouse release: select clicked item, close if any
      pum_select_mouse_pos();
      if (pum_selected >= 0) {
        pum_execute_menu(menu, mode);
        break;
      }
      if (c == K_LEFTMOUSE || c == K_LEFTMOUSE_NM) {
        break;
      }
    }
  }

  for (idx = 0; idx < pum_size; idx++) {
    xfree(array[idx].pum_text);
  }
  xfree(array);
  pum_undisplay(true);
  if (!p_mousemev) {
    ui_call_option_set(STATIC_CSTR_AS_STRING("mousemoveevent"), BOOLEAN_OBJ(false));
  }
}

void pum_make_popup(const char *path_name, int use_mouse_pos)
{
  if (!use_mouse_pos) {
    // Hack: set mouse position at the cursor so that the menu pops up
    // around there.
    mouse_row = curwin->w_grid.row_offset + curwin->w_wrow;
    mouse_col = curwin->w_grid.col_offset + curwin->w_wcol;
    if (ui_has(kUIMultigrid)) {
      mouse_grid = curwin->w_grid.target->handle;
    } else if (curwin->w_grid.target != &default_grid) {
      mouse_grid = 0;
      mouse_row += curwin->w_winrow;
      mouse_col += curwin->w_wincol;
    }
  }

  vimmenu_T *menu = menu_find(path_name);
  if (menu != NULL) {
    pum_show_popupmenu(menu);
  }
}
