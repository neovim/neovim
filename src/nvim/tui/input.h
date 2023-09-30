#ifndef NVIM_TUI_INPUT_H
#define NVIM_TUI_INPUT_H

#include <stdbool.h>
#include <stdint.h>
#include <termkey.h>
#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/stream.h"
#include "nvim/event/time.h"
#include "nvim/rbuffer.h"
#include "nvim/tui/input_defs.h"
#include "nvim/tui/tui.h"
#include "nvim/types.h"

typedef enum {
  kExtkeysNone,
  kExtkeysCSIu,
  kExtkeysXterm,
} ExtkeysType;

typedef struct term_input {
  int in_fd;
  // Phases: -1=all 0=disabled 1=first-chunk 2=continue 3=last-chunk
  int8_t paste;
  bool ttimeout;
  int8_t waiting_for_bg_response;
  int8_t waiting_for_csiu_response;
  ExtkeysType extkeys_type;
  OptInt ttimeoutlen;
  TermKey *tk;
  TermKey_Terminfo_Getstr_Hook *tk_ti_hook_fn;  ///< libtermkey terminfo hook
  TimeWatcher timer_handle;
  Loop *loop;
  Stream read_stream;
  RBuffer *key_buffer;
  TUIData *tui_data;
} TermInput;

typedef enum {
  kIncomplete = -1,
  kNotApplicable = 0,
  kComplete = 1,
} HandleState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.h.generated.h"
#endif

#endif  // NVIM_TUI_INPUT_H
