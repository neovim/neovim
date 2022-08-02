#ifndef NVIM_UI_CLIENT_H
#define NVIM_UI_CLIENT_H

#include "nvim/api/private/defs.h"
#include "nvim/grid_defs.h"

typedef struct {
  const char *name;
  void (*fn)(Array args);
} UIClientHandler;

// Temporary buffer for converting a single grid_line event
EXTERN size_t grid_line_buf_size INIT(= 0);
EXTERN schar_T *grid_line_buf_char INIT(= NULL);
EXTERN sattr_T *grid_line_buf_attr INIT(= NULL);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_client.h.generated.h"

# include "ui_events_client.h.generated.h"
#endif

#endif  // NVIM_UI_CLIENT_H
