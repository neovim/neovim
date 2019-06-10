#ifndef NVIM_REDRAW_H
#define NVIM_REDRAW_H

#include "nvim/api/private/defs.h"

typedef void (*ApiRedrawWrapper)(Array args);                                     

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "redraw.h.generated.h"
#include "ui_events_redraw.h.generated.h"
#endif
#endif  // NVIM_REDRAW_H
