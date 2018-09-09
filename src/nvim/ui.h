#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#include "nvim/globals.h"
#include "nvim/api/private/defs.h"
#include "nvim/highlight_defs.h"

typedef enum {
  kUICmdline = 0,
  kUIPopupmenu,
  kUITabline,
  kUIWildmenu,
#define kUIGlobalCount (kUIWildmenu+1)
  kUINewgrid,
  kUIHlState,
  kUIExtCount,
} UIExtension;

EXTERN const char *ui_ext_names[] INIT(= {
  "ext_cmdline",
  "ext_popupmenu",
  "ext_tabline",
  "ext_wildmenu",
  "ext_newgrid",
  "ext_hlstate",
});


typedef struct ui_t UI;

struct ui_t {
  bool rgb;
  bool ui_ext[kUIExtCount];  ///< Externalized widgets
  int width, height;
  void *data;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_events.generated.h"
#endif

  // For perfomance and simplicity, we use the dense screen representation
  // in the bridge and the TUI. The remote_ui module will translate this
  // in to the public grid_line format.
  void (*raw_line)(UI *ui, Integer grid, Integer row, Integer startcol,
                   Integer endcol, Integer clearcol, Integer clearattr,
                   Boolean wrap, const schar_T *chunk, const sattr_T *attrs);
  void (*event)(UI *ui, char *name, Array args, bool *args_consumed);
  void (*stop)(UI *ui);
  void (*inspect)(UI *ui, Dictionary *info);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
# include "ui_events_call.h.generated.h"
#endif
#endif  // NVIM_UI_H
