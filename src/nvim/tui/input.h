#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/event/defs.h"
#include "nvim/tui/input_defs.h"  // IWYU pragma: keep
#include "nvim/tui/termkey/termkey_defs.h"
#include "nvim/tui/tui_defs.h"
#include "nvim/types_defs.h"

typedef enum {
  kKeyEncodingLegacy,  ///< Legacy key encoding
  kKeyEncodingKitty,   ///< Kitty keyboard protocol encoding
  kKeyEncodingXterm,   ///< Xterm's modifyOtherKeys encoding (XTMODKEYS)
} KeyEncoding;

typedef struct {
  void (*primary_device_attr)(TUIData *tui);
} TermInputCallbacks;

#define KEY_BUFFER_SIZE 0x1000
typedef struct {
  int in_fd;
  // Phases: -1=all 0=disabled 1=first-chunk 2=continue 3=last-chunk
  int8_t paste;
  bool ttimeout;

  TermInputCallbacks callbacks;

  KeyEncoding key_encoding;       ///< The key encoding used by the terminal emulator

  OptInt ttimeoutlen;
  TermKey *tk;
  TermKey_Terminfo_Getstr_Hook *tk_ti_hook_fn;  ///< libtermkey terminfo hook
  uv_timer_t timer_handle;
  uv_timer_t bg_query_timer;  ///< timer used to batch background color queries
  Loop *loop;
  RStream read_stream;
  TUIData *tui_data;
  char key_buffer[KEY_BUFFER_SIZE];
  size_t key_buffer_len;
} TermInput;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.h.generated.h"
#endif
