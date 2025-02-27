/// @file popupmenu.c
///
/// Popup menu (PUM)

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/api/buffer.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

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
static int pum_col;                 // left column of pum, right column if 'rightleft'
static int pum_left_col;            // left column of pum, before padding or scrollbar
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
    if (pum_array[i].pum_text != NULL) {
      int w = vim_strsize(pum_array[i].pum_text);
      if (pum_base_width < w) {
        pum_base_width = w;
      }
    }
    if (pum_array[i].pum_kind != NULL) {
      int w = vim_strsize(pum_array[i].pum_kind) + 1;
      if (pum_kind_width < w) {
        pum_kind_width = w;
      }
    }
    if (pum_array[i].pum_extra != NULL) {
      int w = vim_strsize(pum_array[i].pum_extra) + 1;
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

  pum_rl = State != MODE_CMDLINE && curwin->w_p_rl;

  do {
    // Mark the pum as visible already here,
    // to avoid that must_redraw is set when 'cursorcolumn' is on.
    pum_is_visible = true;
    pum_is_drawn = true;
    validate_cursor_col(curwin);
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
    pum_height = MIN(size, PUM_DEF_HEIGHT);
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
        context_lines = MIN(2, curwin->w_wrow - curwin->w_cline_row);
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
        validate_cheight(curwin);
        int cline_visible_offset = curwin->w_cline_row +
                                   curwin->w_cline_height - curwin->w_wrow;
        context_lines = MIN(3, cline_visible_offset);
      }

      pum_row = pum_win_row + context_lines;
      pum_height = MIN(below_row - pum_row, size);
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

      int content_width = max_width + pum_kind_width + pum_extra_width + 1;
      if (pum_width > content_width && pum_width > p_pw) {
        // Reduce width to fit item
        pum_width = MAX(content_width, (int)p_pw);
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
          int right_edge_col = max_col - max_width - pum_scrollbar;
          if (win_start_col > right_edge_col && max_width <= p_pw) {
            // use full width to end of the screen
            pum_col = MAX(min_col, right_edge_col);
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
        } else if (pum_width > content_width && pum_width > p_pw) {
          pum_width = MAX(content_width, (int)p_pw);
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

/// Computes attributes of text on the popup menu.
/// Returns attributes for every cell, or NULL if all attributes are the same.
static int *pum_compute_text_attrs(char *text, hlf_T hlf, int user_hlattr)
{
  if (*text == NUL || (hlf != HLF_PSI && hlf != HLF_PNI)
      || (win_hl_attr(curwin, HLF_PMSI) == win_hl_attr(curwin, HLF_PSI)
          && win_hl_attr(curwin, HLF_PMNI) == win_hl_attr(curwin, HLF_PNI))) {
    return NULL;
  }

  char *leader = State == MODE_CMDLINE ? cmdline_compl_pattern()
                                       : ins_compl_leader();
  if (leader == NULL || *leader == NUL) {
    return NULL;
  }

  int *attrs = xmalloc(sizeof(int) * (size_t)vim_strsize(text));
  bool in_fuzzy = State == MODE_CMDLINE ? cmdline_compl_is_fuzzy()
                                        : (get_cot_flags() & kOptCotFlagFuzzy) != 0;
  size_t leader_len = strlen(leader);

  garray_T *ga = NULL;
  bool matched_start = false;

  if (in_fuzzy) {
    ga = fuzzy_match_str_with_pos(text, leader);
  } else {
    matched_start = mb_strnicmp(text, leader, leader_len) == 0;
  }

  const char *ptr = text;
  int cell_idx = 0;
  uint32_t char_pos = 0;
  bool is_select = hlf == HLF_PSI;

  while (*ptr != NUL) {
    int new_attr = win_hl_attr(curwin, (int)hlf);

    if (ga != NULL) {
      // Handle fuzzy matching
      for (int i = 0; i < ga->ga_len; i++) {
        if (char_pos == ((uint32_t *)ga->ga_data)[i]) {
          new_attr = win_hl_attr(curwin, is_select ? HLF_PMSI : HLF_PMNI);
          new_attr = hl_combine_attr(win_hl_attr(curwin, HLF_PMNI), new_attr);
          new_attr = hl_combine_attr(win_hl_attr(curwin, (int)hlf), new_attr);
          break;
        }
      }
    } else if (matched_start && ptr < text + leader_len) {
      new_attr = win_hl_attr(curwin, is_select ? HLF_PMSI : HLF_PMNI);
      new_attr = hl_combine_attr(win_hl_attr(curwin, HLF_PMNI), new_attr);
      new_attr = hl_combine_attr(win_hl_attr(curwin, (int)hlf), new_attr);
    }

    new_attr = hl_combine_attr(win_hl_attr(curwin, HLF_PNI), new_attr);

    if (user_hlattr > 0) {
      new_attr = hl_combine_attr(new_attr, user_hlattr);
    }

    int char_cells = utf_ptr2cells(ptr);
    for (int i = 0; i < char_cells; i++) {
      attrs[cell_idx + i] = new_attr;
    }
    cell_idx += char_cells;

    MB_PTR_ADV(ptr);
    char_pos++;
  }

  if (ga != NULL) {
    ga_clear(ga);
    xfree(ga);
  }
  return attrs;
}

/// Displays text on the popup menu with specific attributes.
static void pum_grid_puts_with_attrs(int col, int cells, const char *text, int textlen,
                                     const int *attrs)
{
  const int col_start = col;
  const char *ptr = text;

  // Render text with proper attributes
  while (*ptr != NUL && (textlen < 0 || ptr < text + textlen)) {
    int char_len = utfc_ptr2len(ptr);
    int attr = attrs[pum_rl ? (col_start + cells - col - 1) : (col - col_start)];
    grid_line_puts(col, ptr, char_len, attr);
    col += utf_ptr2cells(ptr);
    ptr += char_len;
  }
}

static inline void pum_align_order(int *order)
{
  bool is_default = cia_flags == 0;
  order[0] = is_default ? CPT_ABBR : cia_flags / 100;
  order[1] = is_default ? CPT_KIND : (cia_flags / 10) % 10;
  order[2] = is_default ? CPT_MENU : cia_flags % 10;
}

static inline char *pum_get_item(int index, int type)
{
  switch (type) {
  case CPT_ABBR:
    return pum_array[index].pum_text;
  case CPT_KIND:
    return pum_array[index].pum_kind;
  case CPT_MENU:
    return pum_array[index].pum_extra;
  }
  return NULL;
}

static inline int pum_user_attr_combine(int idx, int type, int attr)
{
  int user_attr[] = {
    pum_array[idx].pum_user_abbr_hlattr,
    pum_array[idx].pum_user_kind_hlattr,
  };
  return user_attr[type] > 0 ? hl_combine_attr(attr, user_attr[type]) : attr;
}

/// Redraw the popup menu, using "pum_first" and "pum_selected".
void pum_redraw(void)
{
  int row = 0;
  int attr_scroll = win_hl_attr(curwin, HLF_PSB);
  int attr_thumb = win_hl_attr(curwin, HLF_PST);
  char *p = NULL;
  int thumb_pos = 0;
  int thumb_height = 1;
  int n;

  //                         "word"   "kind"   "extra text"
  const hlf_T hlfsNorm[3] = { HLF_PNI, HLF_PNK, HLF_PNX };
  const hlf_T hlfsSel[3] = { HLF_PSI, HLF_PSK, HLF_PSX };

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

  pum_left_col = pum_col - col_off;
  bool moved = ui_comp_put_grid(&pum_grid, pum_row, pum_left_col,
                                pum_height, grid_width, false, true);
  bool invalid_grid = moved || pum_invalid;
  pum_invalid = false;
  must_redraw_pum = false;

  if (!pum_grid.chars || pum_grid.rows != pum_height || pum_grid.cols != grid_width) {
    grid_alloc(&pum_grid, pum_height, grid_width, !invalid_grid, false);
    ui_call_grid_resize(pum_grid.handle, pum_grid.cols, pum_grid.rows);
  } else if (invalid_grid) {
    grid_invalidate(&pum_grid);
  }
  if (ui_has(kUIMultigrid)) {
    const char *anchor = pum_above ? "SW" : "NW";
    int row_off = pum_above ? -pum_height : 0;
    ui_call_win_float_pos(pum_grid.handle, -1, cstr_as_string(anchor), pum_anchor_grid,
                          pum_row - row_off, pum_left_col, false, pum_grid.zindex);
  }

  int scroll_range = pum_size - pum_height;
  // Never display more than we have
  pum_first = MIN(pum_first, scroll_range);

  if (pum_scrollbar) {
    thumb_height = pum_height * pum_height / pum_size;
    if (thumb_height == 0) {
      thumb_height = 1;
    }
    thumb_pos = (pum_first * (pum_height - thumb_height) + scroll_range / 2) / scroll_range;
  }

  for (int i = 0; i < pum_height; i++) {
    int idx = i + pum_first;
    const hlf_T *const hlfs = (idx == pum_selected) ? hlfsSel : hlfsNorm;
    hlf_T hlf = hlfs[0];  // start with "word" highlight
    int attr = win_hl_attr(curwin, (int)hlf);
    attr = hl_combine_attr(win_hl_attr(curwin, HLF_PNI), attr);

    grid_line_start(&pum_grid, row);

    // prepend a space if there is room
    if (extra_space) {
      if (pum_rl) {
        grid_line_puts(col_off + 1, " ", 1, attr);
      } else {
        grid_line_puts(col_off - 1, " ", 1, attr);
      }
    }

    // Display each entry, use two spaces for a Tab.
    // Do this 3 times and order from p_cia
    int grid_col = col_off;
    int totwidth = 0;
    int order[3];
    int items_width_array[3] = { pum_base_width, pum_kind_width, pum_extra_width };
    pum_align_order(order);
    int basic_width = items_width_array[order[0]];  // first item width
    bool last_isabbr = order[2] == CPT_ABBR;
    int orig_attr = -1;

    for (int j = 0; j < 3; j++) {
      int item_type = order[j];
      hlf = hlfs[item_type];
      attr = win_hl_attr(curwin, (int)hlf);
      attr = hl_combine_attr(win_hl_attr(curwin, HLF_PNI), attr);
      orig_attr = attr;
      if (item_type < 2) {  // try combine attr with user custom
        attr = pum_user_attr_combine(idx, item_type, attr);
      }
      int width = 0;
      char *s = NULL;
      p = pum_get_item(idx, item_type);
      if (p != NULL) {
        for (;; MB_PTR_ADV(p)) {
          if (s == NULL) {
            s = p;
          }
          int w = ptr2cells(p);
          if (*p != NUL && *p != TAB && totwidth + w <= pum_width) {
            width += w;
            continue;
          }

          // Display the text that fits or comes before a Tab.
          // First convert it to printable characters.
          char saved = *p;

          if (saved != NUL) {
            *p = NUL;
          }
          char *st = transstr(s, true);
          if (saved != NUL) {
            *p = saved;
          }

          int *attrs = NULL;
          if (item_type == CPT_ABBR) {
            attrs = pum_compute_text_attrs(st, hlf,
                                           pum_array[idx].pum_user_abbr_hlattr);
          }

          if (pum_rl) {
            char *rt = reverse_text(st);
            char *rt_start = rt;
            int cells = vim_strsize(rt);

            if (cells > pum_width) {
              do {
                cells -= utf_ptr2cells(rt);
                MB_PTR_ADV(rt);
              } while (cells > pum_width);

              if (cells < pum_width) {
                // Most left character requires 2-cells but only 1 cell is available on
                // screen.  Put a '<' on the left of the pum item.
                *(--rt) = '<';
                cells++;
              }
            }

            if (attrs == NULL) {
              grid_line_puts(grid_col - cells + 1, rt, -1, attr);
            } else {
              pum_grid_puts_with_attrs(grid_col - cells + 1, cells, rt, -1, attrs);
            }

            xfree(rt_start);
            xfree(st);
            grid_col -= width;
          } else {
            if (attrs == NULL) {
              grid_line_puts(grid_col, st, -1, attr);
            } else {
              pum_grid_puts_with_attrs(grid_col, vim_strsize(st), st, -1, attrs);
            }

            xfree(st);
            grid_col += width;
          }

          if (attrs != NULL) {
            XFREE_CLEAR(attrs);
          }

          if (*p != TAB) {
            break;
          }

          // Display two spaces for a Tab.
          if (pum_rl) {
            grid_line_puts(grid_col - 1, "  ", 2, attr);
            grid_col -= 2;
          } else {
            grid_line_puts(grid_col, "  ", 2, attr);
            grid_col += 2;
          }
          totwidth += 2;
          s = NULL;  // start text at next char
          width = 0;
        }
      }

      if (j > 0) {
        n = items_width_array[order[1]] + (last_isabbr ? 0 : 1);
      } else {
        n = order[j] == CPT_ABBR ? 1 : 0;
      }

      bool next_isempty = false;
      if (j + 1 < 3) {
        next_isempty = pum_get_item(idx, order[j + 1]) == NULL;
      }
      // Stop when there is nothing more to display.
      if ((j == 2)
          || (next_isempty && (j == 1 || (j == 0 && pum_get_item(idx, order[j + 2]) == NULL)))
          || (basic_width + n >= pum_width)) {
        break;
      }

      if (pum_rl) {
        grid_line_fill(col_off - basic_width - n + 1, grid_col + 1,
                       schar_from_ascii(' '), orig_attr);
        grid_col = col_off - basic_width - n;
      } else {
        grid_line_fill(grid_col, col_off + basic_width + n,
                       schar_from_ascii(' '), orig_attr);
        grid_col = col_off + basic_width + n;
      }
      totwidth = basic_width + n;
    }

    if (pum_rl) {
      grid_line_fill(col_off - pum_width + 1, grid_col + 1, schar_from_ascii(' '), orig_attr);
    } else {
      grid_line_fill(grid_col, col_off + pum_width, schar_from_ascii(' '), orig_attr);
    }

    if (pum_scrollbar > 0) {
      if (pum_rl) {
        grid_line_puts(col_off - pum_width, " ", 1,
                       i >= thumb_pos && i < thumb_pos + thumb_height ? attr_thumb : attr_scroll);
      } else {
        grid_line_puts(col_off + pum_width, " ", 1,
                       i >= thumb_pos && i < thumb_pos + thumb_height ? attr_thumb : attr_scroll);
      }
    }
    grid_line_flush();
    row++;
  }
}

/// Set the informational text in the preview buffer when the completion
/// item does not include a dedicated preview or popup window.
///
/// @param[in]  buf        Buffer where the text will be set.
/// @param[in]  info       Informational text to display in the preview buffer.
/// @param[in]  lnum       Where to start the text. Incremented for each added line.
/// @param[out] max_width  Maximum width of the displayed text.
static void pum_preview_set_text(buf_T *buf, char *info, linenr_T *lnum, int *max_width)
{
  Error err = ERROR_INIT;
  Arena arena = ARENA_EMPTY;
  Array replacement = ARRAY_DICT_INIT;
  char *token = NULL;
  char *line = os_strtok(info, "\n", &token);
  buf->b_p_ma = true;
  while (line != NULL) {
    ADD(replacement, STRING_OBJ(cstr_to_string(line)));
    (*lnum)++;
    (*max_width) = MAX(*max_width, (int)mb_string2cells(line));
    line = os_strtok(NULL, "\n", &token);
  }

  int original_textlock = textlock;
  if (textlock > 0) {
    textlock = 0;
  }
  nvim_buf_set_lines(0, buf->handle, 0, -1, false, replacement, &arena, &err);
  textlock = original_textlock;
  if (ERROR_SET(&err)) {
    emsg(err.msg);
    api_clear_error(&err);
  }
  arena_mem_free(arena_finish(&arena));
  api_free_array(replacement);
  buf->b_p_ma = false;
}

/// adjust floating info preview window position
static void pum_adjust_info_position(win_T *wp, int height, int width)
{
  int col = pum_col + pum_width + pum_scrollbar + 1;
  // TODO(glepnir): support config align border by using completepopup
  // align menu
  int right_extra = Columns - col;
  int left_extra = pum_col - 2;

  if (right_extra > width) {  // place in right
    wp->w_config.width = width;
    wp->w_config.col = col - 1;
  } else if (left_extra > width) {  // place in left
    wp->w_config.width = width;
    wp->w_config.col = pum_col - wp->w_config.width - 1;
  } else {  // either width is enough just use the biggest one.
    const bool place_in_right = right_extra > left_extra;
    wp->w_config.width = place_in_right ? right_extra : left_extra;
    wp->w_config.col = place_in_right ? col - 1 : pum_col - wp->w_config.width - 1;
  }
  // when pum_above is SW otherwise is NW
  wp->w_config.anchor = pum_above ? kFloatAnchorSouth : 0;
  wp->w_config.row = pum_above ? pum_row + height : pum_row;
  wp->w_config.height = MIN(Rows, height);
  wp->w_config.hide = false;
  win_config_float(wp, wp->w_config);
}

/// Used for nvim__complete_set
///
/// @param selected the selected compl item.
/// @param info     Info string.
/// @return a win_T pointer.
win_T *pum_set_info(int selected, char *info)
{
  if (!pum_is_visible || !compl_match_curr_select(selected)) {
    return NULL;
  }
  block_autocmds();
  RedrawingDisabled++;
  no_u_sync++;
  win_T *wp = win_float_find_preview();
  if (wp == NULL) {
    wp = win_float_create(false, true);
    if (!wp) {
      return NULL;
    }
    wp->w_p_wfb = true;
  }
  linenr_T lnum = 0;
  int max_info_width = 0;
  pum_preview_set_text(wp->w_buffer, info, &lnum, &max_info_width);
  no_u_sync--;
  RedrawingDisabled--;
  redraw_later(wp, UPD_NOT_VALID);

  if (wp->w_p_wrap) {
    lnum += plines_win(wp, lnum, true);
  }
  pum_adjust_info_position(wp, lnum, max_info_width);
  unblock_autocmds();
  return wp;
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
  bool resized = false;
  int context = pum_height / 2;
  int prev_selected = pum_selected;

  pum_selected = n;
  int scroll_offset = pum_selected - pum_height;
  unsigned cur_cot_flags = get_cot_flags();
  bool use_float = (cur_cot_flags & kOptCotFlagPopup) != 0;

  // Close the floating preview window if 'selected' is -1, indicating a return to the original
  // state. It is also closed when the selected item has no corresponding info item.
  if (use_float && (pum_selected < 0 || pum_array[pum_selected].pum_info == NULL)) {
    win_T *wp = win_float_find_preview();
    if (wp) {
      wp->w_config.hide = true;
      win_config_float(wp, wp->w_config);
    }
  }

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
    } else if (pum_first < scroll_offset + 5) {
      // scroll up; when we did a jump it's probably a PageDown then
      // scroll a whole page
      if (pum_first < scroll_offset + 3) {
        pum_first = MAX(pum_first + pum_height - 2, scroll_offset + 1);
      } else {
        pum_first = scroll_offset + 1;
      }
    }

    // Give a few lines of context when possible.
    context = MIN(context, 3);

    if (pum_height > 2) {
      if (pum_first > pum_selected - context) {
        pum_first = MAX(pum_selected - context, 0);  // scroll down
      } else if (pum_first < pum_selected + context - pum_height + 1) {
        pum_first = pum_selected + context - pum_height + 1;  // up
      }
    }
    // adjust for the number of lines displayed
    pum_first = MIN(pum_first, pum_size - pum_height);

    // Show extra info in the preview window if there is something and
    // 'completeopt' contains "preview".
    // Skip this when tried twice already.
    // Skip this also when there is not much room.
    // NOTE: Be very careful not to sync undo!
    if ((pum_array[pum_selected].pum_info != NULL)
        && (Rows > 10)
        && (repeat <= 1)
        && (cur_cot_flags & (kOptCotFlagPreview | kOptCotFlagPopup))) {
      win_T *curwin_save = curwin;
      tabpage_T *curtab_save = curtab;

      if (use_float) {
        block_autocmds();
      }

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

      if (!use_float) {
        resized = prepare_tagpreview(false);
      } else {
        win_T *wp = win_float_find_preview();
        if (wp) {
          win_enter(wp, false);
        } else {
          wp = win_float_create(true, true);
          if (wp) {
            resized = true;
          }
        }
      }

      no_u_sync--;
      RedrawingDisabled--;
      g_do_tagpreview = 0;

      if (curwin->w_p_pvw || curwin->w_float_is_info) {
        int res = OK;
        if (!resized
            && (curbuf->b_nwindows == 1)
            && (curbuf->b_fname == NULL)
            && bt_nofile(curbuf)
            && (curbuf->b_p_bh[0] == 'w')
            && !use_float) {
          // Already a "wipeout" buffer, make it empty.
          while (!buf_is_empty(curbuf)) {
            ml_delete(1, false);
          }
        } else {
          // Don't want to sync undo in the current buffer.
          no_u_sync++;
          res = do_ecmd(0, NULL, NULL, NULL, ECMD_ONE, 0, NULL);
          no_u_sync--;

          if (res == OK) {
            // Edit a new, empty buffer. Set options for a "wipeout"
            // buffer.
            set_option_value_give_err(kOptSwapfile, BOOLEAN_OPTVAL(false), OPT_LOCAL);
            set_option_value_give_err(kOptBuflisted, BOOLEAN_OPTVAL(false), OPT_LOCAL);
            set_option_value_give_err(kOptBuftype, STATIC_CSTR_AS_OPTVAL("nofile"), OPT_LOCAL);
            set_option_value_give_err(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("wipe"), OPT_LOCAL);
            set_option_value_give_err(kOptDiff, BOOLEAN_OPTVAL(false), OPT_LOCAL);
          }
        }

        if (res == OK) {
          linenr_T lnum = 0;
          int max_info_width = 0;
          pum_preview_set_text(curbuf, pum_array[pum_selected].pum_info, &lnum, &max_info_width);
          // Increase the height of the preview window to show the
          // text, but no more than 'previewheight' lines.
          if (repeat == 0 && !use_float) {
            lnum = MIN(lnum, (linenr_T)p_pvh);

            if (curwin->w_height < lnum) {
              win_setheight((int)lnum);
              resized = true;
            }
          }

          curbuf->b_changed = false;
          curbuf->b_p_ma = false;
          if (pum_selected != prev_selected) {
            curwin->w_topline = 1;
          } else if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
            curwin->w_topline = curbuf->b_ml.ml_line_count;
          }
          curwin->w_cursor.lnum = 1;
          curwin->w_cursor.col = 0;

          if (use_float) {
            if (curwin->w_p_wrap) {
              lnum += plines_win(curwin, lnum, true);
            }
            // adjust floating window by actually height and max info text width
            pum_adjust_info_position(curwin, lnum, max_info_width);
          }

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
            validate_cursor(curwin);
            redraw_later(curwin, UPD_SOME_VALID);

            // When the preview window was resized we need to
            // update the view on the buffer.  Only go back to
            // the window when needed, otherwise it will always be
            // redrawn.
            if (resized && win_valid(curwin_save)) {
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

      if (use_float) {
        unblock_autocmds();
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
    win_T *wp = win_float_find_preview();
    if (wp != NULL) {
      win_close(wp, false, false);
    }
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
  tv_dict_add_float(dict, S_LEN("height"), h);
  tv_dict_add_float(dict, S_LEN("width"), w);
  tv_dict_add_float(dict, S_LEN("row"), r);
  tv_dict_add_float(dict, S_LEN("col"), c);
  tv_dict_add_nr(dict, S_LEN("size"), pum_size);
  tv_dict_add_bool(dict, S_LEN("scrollbar"),
                   pum_scrollbar ? kBoolVarTrue : kBoolVarFalse);
}

static void pum_position_at_mouse(int min_width)
{
  int min_row = 0;
  int min_col = 0;
  int max_row = Rows;
  int max_col = Columns;
  if (mouse_grid > 1) {
    win_T *wp = get_win_by_grid_handle(mouse_grid);
    if (wp != NULL) {
      min_row = -wp->w_winrow;
      min_col = -wp->w_wincol;
      max_row = MAX(Rows - wp->w_winrow, wp->w_grid.rows);
      max_col = MAX(Columns - wp->w_wincol, wp->w_grid.cols);
    }
  }
  if (pum_grid.handle != 0 && mouse_grid == pum_grid.handle) {
    // Repositioning the menu by right-clicking on itself
    mouse_grid = pum_anchor_grid;
    mouse_row += pum_row;
    mouse_col += pum_left_col;
  } else {
    pum_anchor_grid = mouse_grid;
  }

  if (max_row - mouse_row > pum_size || max_row - mouse_row > mouse_row - min_row) {
    // Enough space below the mouse row,
    // or there is more space below the mouse row than above.
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

  if (pum_rl) {
    if (mouse_col - min_col + 1 >= pum_base_width
        || mouse_col - min_col + 1 > min_width) {
      // Enough space to show at mouse column.
      pum_col = mouse_col;
    } else {
      // Not enough space, left align with window.
      pum_col = min_col + MIN(pum_base_width, min_width) - 1;
    }
    pum_width = pum_col - min_col + 1;
  } else {
    if (max_col - mouse_col >= pum_base_width
        || max_col - mouse_col > min_width) {
      // Enough space to show at mouse column.
      pum_col = mouse_col;
    } else {
      // Not enough space, right align with window.
      pum_col = max_col - MIN(pum_base_width, min_width);
    }
    pum_width = max_col - pum_col;
  }

  pum_width = MIN(pum_width, pum_base_width + 1);
}

/// Select the pum entry at the mouse position.
static void pum_select_mouse_pos(void)
{
  if (mouse_grid == pum_grid.handle) {
    pum_selected = mouse_row;
    return;
  } else if (mouse_grid != pum_anchor_grid || mouse_col < pum_grid.comp_col
             || mouse_col >= pum_grid.comp_col + pum_grid.comp_width) {
    pum_selected = -1;
    return;
  }

  int idx = mouse_row - pum_grid.comp_row;

  if (idx < 0 || idx >= pum_grid.comp_height) {
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
  pum_rl = curwin->w_p_rl;
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
    setcursor_mayforce(curwin, true);

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
    mouse_col = curwin->w_grid.col_offset
                + (curwin->w_p_rl ? curwin->w_width_inner - curwin->w_wcol - 1
                                  : curwin->w_wcol);
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
