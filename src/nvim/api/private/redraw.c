#include <stdint.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/undo.h"
#include "nvim/syntax.h"
#include "nvim/screen.h"
#include "nvim/ascii.h"
#include "nvim/path.h"
#include "nvim/buffer_defs.h"
#include "nvim/os/channel.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/redraw.h"
#include "nvim/api/private/helpers.h"

typedef struct {
  char buffer[4096];
  size_t offset, prev_offset;
  Dictionary attributes;
} LineData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/redraw.c.generated.h"
#endif


void redraw_tabs(uint64_t channel_id)
{
  if (false) {
    return;
  }

  // Array containing the tab state for the redraw event
  Array event_data = {0, 0, 0};
  size_t tabcount = 0;

  for (tabpage_T *tp = first_tabpage; tp != NULL; tp = tp->tp_next) {
    tabcount++;
  }

  for (tabpage_T *tp = first_tabpage; tp != NULL; tp = tp->tp_next) {
    win_T *wp, *cwp;
    Dictionary tab_data = {0, 0, 0};
    PUT(tab_data, "tabpage_id", INTEGER_OBJ(tp->handle));
    PUT(tab_data, "selected", BOOLEAN_OBJ(tp->tp_topframe == topframe));

    if (tp == curtab) {
      cwp = curwin;
      wp = firstwin;
    } else {
      cwp = tp->tp_curwin;
      wp = tp->tp_firstwin;
    }

    bool modified = false;
    size_t wincount;
    for (wincount = 0; wp != NULL; wp = wp->w_next, wincount++) {
      if (bufIsChanged(wp->w_buffer)) {
        modified = true;
      }
    }

    PUT(tab_data, "window_count", INTEGER_OBJ(wincount));
    PUT(tab_data, "modified", BOOLEAN_OBJ(modified));
    // Get buffer name in NameBuff[]
    get_trans_bufname(cwp->w_buffer);
    shorten_dir(NameBuff);
    PUT(tab_data, "text", STRING_OBJ(cstr_to_string((char *)NameBuff)));
    ADD(event_data, DICTIONARY_OBJ(tab_data));
  }

  channel_send_event(channel_id, "redraw:tabs", ARRAY_OBJ(event_data));
}

void redraw_insert_line(uint64_t channel_id, win_T *window, int row, int count)
{
  if (false) {
    return;
  }

  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(window->handle));
  PUT(event_data, "row", INTEGER_OBJ(row - window->w_winrow));
  PUT(event_data, "count", INTEGER_OBJ(count));
  channel_send_event(channel_id,
                     "redraw:insert_line",
                     DICTIONARY_OBJ(event_data));
}

void redraw_delete_line(uint64_t channel_id, win_T *window, int row, int count)
{
  if (false) {
    return;
  }

  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(window->handle));
  PUT(event_data, "row", INTEGER_OBJ(row - window->w_winrow));
  PUT(event_data, "count", INTEGER_OBJ(count));
  channel_send_event(channel_id,
                     "redraw:delete_line",
                     DICTIONARY_OBJ(event_data));
}

void redraw_update_line(uint64_t channel_id,
                        win_T *window,
                        UpdateLineWidths *widths,
                        size_t row,
                        size_t startcol,
                        size_t endcol,
                        size_t off_from,
                        size_t max_off_from)
{
  if (false) {
    return;
  }

  // Check for illegal row and col, just in case.
  if (row >= (size_t)Rows) {
    row = Rows - 1;
  }

  if (endcol > (size_t)Columns) {
    endcol = Columns;
  }

  size_t col = 0;
  size_t off_to = LineOffset[row] + startcol;
  size_t char_cells;
  LineData ldata = {
    .attributes = {0, 0, 0},
    .offset = 0,
    .prev_offset = 0
  };

  while (col < endcol) {
    if (has_mbyte && (col + 1 < endcol)) {
      char_cells = (*mb_off2cells)(off_from, max_off_from);
    } else {
      char_cells = 1;
    }

    add_line_char(&ldata, off_to);

    off_to += char_cells;
    off_from += char_cells;
    col += char_cells;
  }

  // Prepare to emit the 'redraw:update_line' event
  // Start by terminating the line buffer
  ldata.buffer[ldata.offset] = NUL;
  // Now split the logical sections of the line into the sections array
  Array line = {0, 0, 0};
  ldata.offset = 0;
  add_line_section(&ldata, "colon", widths->colon, &line);
  add_line_section(&ldata, "fold", widths->fold, &line);
  add_line_section(&ldata, "sign", widths->sign, &line);
  add_line_section(&ldata, "number", widths->number, &line);
  add_line_section(&ldata, "deleted", widths->deleted, &line);
  add_line_section(&ldata, "linebreak", widths->linebreak, &line);
  size_t user_section_width = strlen(ldata.buffer + ldata.offset);
  add_line_section(&ldata, "user", user_section_width, &line);
  // Broadcast the event
  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(window->handle));
  PUT(event_data, "row", INTEGER_OBJ(row - window->w_winrow));
  PUT(event_data, "line", ARRAY_OBJ(line));

  if (ldata.attributes.size) {
    PUT(event_data, "attributes", DICTIONARY_OBJ(ldata.attributes));
  }

  channel_send_event(channel_id,
                     "redraw:update_line",
                     DICTIONARY_OBJ(event_data));
}

void redraw_status(uint64_t channel_id, win_T *window)
{
  if (false) {
    return;
  }

  // Put the buffer name in NameBuff
  get_trans_bufname(window->w_buffer);

  // Prepare the event data
  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(window->handle));
  PUT(event_data, "name", STRING_OBJ(cstr_to_string((char *)NameBuff)));

  if (window->w_buffer->b_help) {
    PUT(event_data, "help", BOOLEAN_OBJ(true));
  }

  if (window->w_p_pvw) {
    PUT(event_data, "preview", BOOLEAN_OBJ(true));
  }

  if (bufIsChanged(window->w_buffer)) {
    PUT(event_data, "modified", BOOLEAN_OBJ(true));
  }

  if (window->w_buffer->b_p_ro) {
    PUT(event_data, "readonly", BOOLEAN_OBJ(true));
  }

  channel_send_event(0, "redraw:status_line", DICTIONARY_OBJ(event_data));
}

void redraw_ruler(uint64_t channel_id, win_T *window, bool empty, char *relpos)
{
  if (false) {
    return;
  }


  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(window->handle));
  PUT(event_data, "lnum", INTEGER_OBJ(window->w_cursor.lnum));
  PUT(event_data, "col", INTEGER_OBJ(empty ? 0: window->w_cursor.col + 1));
  PUT(event_data, "relpos", STRING_OBJ(cstr_to_string(relpos)));
  channel_send_event(0, "redraw:ruler", DICTIONARY_OBJ(event_data));
}

void redraw_layout(uint64_t channel_id)
{
  if (false) {
    return;
  }

  Dictionary event_data = build_layout_event(topframe);
  redraw_foreground_color(channel_id);
  redraw_background_color(channel_id);
  channel_send_event(channel_id, "redraw:layout", DICTIONARY_OBJ(event_data));
  update_screen(CLEAR);
}

void redraw_cursor(uint64_t channel_id)
{
  if (false) {
    return;
  }

  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "window_id", INTEGER_OBJ(curwin->handle));
  PUT(event_data, "lnum", INTEGER_OBJ(curwin->w_cursor.lnum));
  PUT(event_data, "row", INTEGER_OBJ(curwin->w_wrow));
  // TODO(stefan991): there is a special case for RTL languages which
  // is not handled here, see setcursor()
  PUT(event_data, "col", INTEGER_OBJ(curwin->w_wcol));
  channel_send_event(0, "redraw:cursor", DICTIONARY_OBJ(event_data));
}

void redraw_foreground_color(uint64_t channel_id)
{
  if (false) {
    return;
  }

  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "color", STRING_OBJ(cstr_to_string(cterm_normal_gui_fg)));
  channel_send_event(0, "redraw:foreground_color", DICTIONARY_OBJ(event_data));
}

void redraw_background_color(uint64_t channel_id)
{
  if (false) {
    return;
  }

  Dictionary event_data = {0, 0, 0};
  PUT(event_data, "color", STRING_OBJ(cstr_to_string(cterm_normal_gui_bg)));
  channel_send_event(0, "redraw:background_color", DICTIONARY_OBJ(event_data));
}

static void add_line_char(LineData *ldata, size_t screen_offset)
{
  size_t char_len;  // length in bytes of the utf8-encoded character
  // Put text and attributes to the line data object for the next
  // redraw event
  if (enc_utf8 && ScreenLinesUC[screen_offset]) {
    uint8_t *text = (uint8_t *)(ldata->buffer + ldata->offset);
    char_len = utfc_char2bytes(screen_offset, text);
  } else {
    ldata->buffer[ldata->offset] = ScreenLines[screen_offset];
    char_len = 1;
  }

  // Now parse the character attributes
  int attr = ScreenAttrs[screen_offset];
  attrentry_T *aep = NULL;

  if (attr > HL_ALL) {
    aep = syn_cterm_attr2entry(attr);
    attr = aep ? aep->ae_attr : 0;
  }

  if (attr & HL_BOLD) {
    add_line_attribute(ldata, "bold", char_len);
  }

  if (attr & HL_STANDOUT) {
    add_line_attribute(ldata, "standout", char_len);
  }

  if (attr & HL_UNDERLINE) {
    add_line_attribute(ldata, "underline", char_len);
  }

  if (attr & HL_UNDERCURL) {
    add_line_attribute(ldata, "undercurl", char_len);
  }

  if (attr & HL_ITALIC) {
    add_line_attribute(ldata, "italic", char_len);
  }

  if (attr & HL_INVERSE) {
    add_line_attribute(ldata, "inverse", char_len);
  }

#define COLOR_BUFFER_SIZE 11  // fg:#000000 + NUL

  if (aep && aep->ae_u.cterm.gui_fg
      && (!cterm_normal_gui_fg
        || STRICMP(cterm_normal_gui_fg, aep->ae_u.cterm.gui_fg))) {
    char buf[COLOR_BUFFER_SIZE];
    snprintf(buf, COLOR_BUFFER_SIZE, "fg:%s", aep->ae_u.cterm.gui_fg);
    add_line_attribute(ldata, buf, char_len);
  }

  if (aep && aep->ae_u.cterm.gui_bg
      && (!cterm_normal_gui_bg
        || STRICMP(cterm_normal_gui_bg, aep->ae_u.cterm.gui_bg))) {
    char buf[COLOR_BUFFER_SIZE];
    snprintf(buf, COLOR_BUFFER_SIZE, "bg:%s", aep->ae_u.cterm.gui_bg);
    add_line_attribute(ldata, buf, char_len);
  }

  ldata->prev_offset = ldata->offset;
  ldata->offset += char_len;
}

static void add_line_attribute(LineData *ldata, char *name, size_t char_len)
{
  // Attributes are arrays, where each element specifies where the attribute
  // should be applied in the line. Elements can have one of two types:
  // - Integer: A line index
  // - [start, end) array: A range of line indexes
  Array attribute;
  size_t idx;

  // previous, current and next offsets
  int cur_offset = (int)ldata->offset;
  int prev_offset = (int)ldata->prev_offset;
  int next_offset = cur_offset + char_len;

  for (idx = 0; idx < ldata->attributes.size; idx++) {
    String key = ldata->attributes.items[idx].key;
    if (!STRNICMP(key.data, name, key.size)) {
      break;
    }
  }

  bool found = idx < ldata->attributes.size;

  if (!found) {
    attribute = (Array) {0, 0, 0};
    // Add the current buffer offset
    ADD(attribute, INTEGER_OBJ(cur_offset));
    // and put the array into the attributes dictionary
    PUT(ldata->attributes, name, ARRAY_OBJ(attribute));
    return;
  }

  // attribute array
  attribute = ldata->attributes.items[idx].value.data.array;
  // last location where this attribute was applied
  Object last_applied = attribute.items[attribute.size - 1];
  // There are 3 possible cases:
  if (last_applied.type == kObjectTypeInteger
      && last_applied.data.integer == prev_offset) {
    // The last location is the previous offset in the line buffer, so
    // promote it to a range
    last_applied.type = kObjectTypeArray;
    last_applied.data.array = (Array){0, 0, 0};
    ADD(last_applied.data.array, INTEGER_OBJ(prev_offset));
    ADD(last_applied.data.array, INTEGER_OBJ(next_offset));

    // update the attribute array with the range
    attribute.items[attribute.size - 1] = last_applied;
  } else if (last_applied.type == kObjectTypeArray
      && last_applied.data.array.items[1].data.integer == cur_offset) {
    // The last location is a range with the end boundary equal to the
    // current offset, so all we need is increase the range by `char_len
    last_applied.data.array.items[1].data.integer += char_len;
    attribute.items[attribute.size - 1] = last_applied;
  } else {
    // In all other cases, the last location where the attribute was applied
    // is not adjacent to the current location, so we need a new element in the
    // attribute's array
    ADD(attribute, INTEGER_OBJ(cur_offset));
  }
  // The attribute *items pointer might have changed by reallocs, to
  // be safe we update the dictionary entry
  ldata->attributes.items[idx].value.data.array = attribute;
}

static void add_line_section(LineData *ldata,
                             const char *section_type,
                             size_t section_width,
                             Array *target)
{
  if (section_width) {
    Dictionary section = {0, 0, 0};
    PUT(section, "type", STRING_OBJ(cstr_to_string(section_type)));
    char str[sizeof(ldata->buffer)];
    xstrlcpy(str, ldata->buffer + ldata->offset, section_width);
    PUT(section, "content", STRING_OBJ(cstr_to_string(str)));
    ADD(*target, DICTIONARY_OBJ(section));
  }

  ldata->offset += section_width;
}

static Dictionary build_layout_event(frame_T *frame)
{
  Dictionary rv = {0, 0, 0};

  if (frame->fr_layout == FR_LEAF) {
    PUT(rv, "window_id", INTEGER_OBJ(frame->fr_win->handle));
    PUT(rv, "width", INTEGER_OBJ(frame->fr_win->w_width));
    PUT(rv, "height", INTEGER_OBJ(frame->fr_win->w_height));
    PUT(rv, "type", STRING_OBJ(cstr_to_string("leaf")));
  } else {
    Array children = {0, 0, 0};

    for (frame_T *f = frame->fr_child; f != NULL; f = f->fr_next) {
      ADD(children, DICTIONARY_OBJ(build_layout_event(f)));
    }

    PUT(rv, "children", ARRAY_OBJ(children));
    PUT(rv, "width", INTEGER_OBJ(frame->fr_width));
    PUT(rv, "height", INTEGER_OBJ(frame->fr_height));
    PUT(rv, "type", STRING_OBJ(cstr_to_string(
            frame->fr_layout == FR_ROW ? "row": "column")));
  }

  return rv;
}

