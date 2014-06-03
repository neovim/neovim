#include <stdint.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/undo.h"
#include "nvim/screen.h"
#include "nvim/path.h"
#include "nvim/buffer_defs.h"
#include "nvim/os/channel.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/redraw.h"
#include "nvim/api/private/helpers.h"

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
