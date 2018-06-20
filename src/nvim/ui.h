#ifndef NVIM_UI_H
#define NVIM_UI_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#include "api/private/defs.h"
#include "nvim/buffer_defs.h"

typedef enum {
  kUICmdline = 0,
  kUIPopupmenu,
  kUITabline,
  kUIWildmenu,
  kUIExtCount,
} UIExtension;

EXTERN const char *ui_ext_names[] INIT(= {
  "ext_cmdline",
  "ext_popupmenu",
  "ext_tabline",
  "ext_wildmenu"
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
  void (*event)(UI *ui, char *name, Array args, bool *args_consumed);
  void (*stop)(UI *ui);
  void (*inspect)(UI *ui, Dictionary *info);
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
# include "ui_events_call.h.generated.h"
#endif
#endif  // NVIM_UI_H
