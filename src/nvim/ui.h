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
  kUIMessages,
#define kUIGlobalCount kUILinegrid
  kUILinegrid,
  kUIMultigrid,
  kUIHlState,
  kUITermColors,
  kUIFloatDebug,
  kUIExtCount,
} UIExtension;

EXTERN const char *ui_ext_names[] INIT(= {
  "ext_cmdline",
  "ext_popupmenu",
  "ext_tabline",
  "ext_wildmenu",
  "ext_messages",
  "ext_linegrid",
  "ext_multigrid",
  "ext_hlstate",
  "ext_termcolors",
  "_debug_float",
});

typedef struct ui_t UI;

enum {
  kLineFlagWrap = 1,
  kLineFlagInvalid = 2,
};

typedef int LineFlags;

struct ui_t {
  bool rgb;
  bool override;  ///< Force highest-requested UI capabilities.
  bool composed;
  bool ui_ext[kUIExtCount];  ///< Externalized UI capabilities.
  int width;
  int height;
  int pum_height;
  void *data;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_events.generated.h"
#endif

  void (*inspect)(UI *ui, Dictionary *info);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
# include "ui_events_call.h.generated.h"
#endif


EXTERN MultiQueue *resize_events;
#endif  // NVIM_UI_H
