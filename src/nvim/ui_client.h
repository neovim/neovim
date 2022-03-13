#ifndef NVIM_UI_CLIENT_H
#define NVIM_UI_CLIENT_H

#include "nvim/api/private/defs.h"

typedef void (*UIClientHandler)(Array args);

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "ui_client.h.generated.h"
#include "ui_events_client.h.generated.h"
#endif

#endif  // NVIM_UI_CLIENT_H
