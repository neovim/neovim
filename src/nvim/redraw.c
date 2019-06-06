// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/redraw.h"
#include "nvim/api/private/helpers.h"
#include "nvim/highlight.h"
#include "nvim/ui.h"
#include "nvim/screen.h"

static Map(String, ApiRedrawWrapper) *redraw_methods = NULL;

static void add_redraw_event_handler(String method, ApiRedrawWrapper handler)
{
  map_put(String, ApiRedrawWrapper)(redraw_methods, method, handler);
}

/// @param name Redraw method name
/// @param name_len name size (includes terminating NUL)
ApiRedrawWrapper get_redraw_event_handler(const char *name, size_t name_len, Error *error)
{
  String m = { .data = (char *)name, .size = name_len };
  ApiRedrawWrapper rv =
    map_get(String, ApiRedrawWrapper)(redraw_methods, m);

  if (!rv) {
    api_set_error(error, kErrorTypeException, "Invalid method: %.*s",
                  m.size > 0 ? (int)m.size : (int)sizeof("<empty>"),
                  m.size > 0 ? m.data : "<empty>");
  }
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "ui_events_redraw.generated.h"
#endif
