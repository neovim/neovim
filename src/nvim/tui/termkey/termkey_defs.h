#pragma once

#include <stddef.h>
#include <stdint.h>
#include <unibilium.h>
#include <uv.h>

#include "nvim/event/defs.h"
#include "nvim/tui/tui_defs.h"
#include "nvim/types_defs.h"

typedef struct TermKey TermKey;

typedef struct {
  TermKey *tk;
  int saved_string_id;
  char *saved_string;
} TermKeyCsi;

typedef enum {
  TERMKEY_RES_NONE,
  TERMKEY_RES_KEY,
  TERMKEY_RES_EOF,
  TERMKEY_RES_AGAIN,
  TERMKEY_RES_ERROR,
} TermKeyResult;

typedef enum {
  TERMKEY_SYM_UNKNOWN = -1,
  TERMKEY_SYM_NONE = 0,

  // Special names in C0
  TERMKEY_SYM_BACKSPACE,
  TERMKEY_SYM_TAB,
  TERMKEY_SYM_ENTER,
  TERMKEY_SYM_ESCAPE,

  // Special names in G0
  TERMKEY_SYM_SPACE,
  TERMKEY_SYM_DEL,

  // Special keys
  TERMKEY_SYM_UP,
  TERMKEY_SYM_DOWN,
  TERMKEY_SYM_LEFT,
  TERMKEY_SYM_RIGHT,
  TERMKEY_SYM_BEGIN,
  TERMKEY_SYM_FIND,
  TERMKEY_SYM_INSERT,
  TERMKEY_SYM_DELETE,
  TERMKEY_SYM_SELECT,
  TERMKEY_SYM_PAGEUP,
  TERMKEY_SYM_PAGEDOWN,
  TERMKEY_SYM_HOME,
  TERMKEY_SYM_END,

  // Special keys from terminfo
  TERMKEY_SYM_CANCEL,
  TERMKEY_SYM_CLEAR,
  TERMKEY_SYM_CLOSE,
  TERMKEY_SYM_COMMAND,
  TERMKEY_SYM_COPY,
  TERMKEY_SYM_EXIT,
  TERMKEY_SYM_HELP,
  TERMKEY_SYM_MARK,
  TERMKEY_SYM_MESSAGE,
  TERMKEY_SYM_MOVE,
  TERMKEY_SYM_OPEN,
  TERMKEY_SYM_OPTIONS,
  TERMKEY_SYM_PRINT,
  TERMKEY_SYM_REDO,
  TERMKEY_SYM_REFERENCE,
  TERMKEY_SYM_REFRESH,
  TERMKEY_SYM_REPLACE,
  TERMKEY_SYM_RESTART,
  TERMKEY_SYM_RESUME,
  TERMKEY_SYM_SAVE,
  TERMKEY_SYM_SUSPEND,
  TERMKEY_SYM_UNDO,

  // Numeric keypad special keys
  TERMKEY_SYM_KP0,
  TERMKEY_SYM_KP1,
  TERMKEY_SYM_KP2,
  TERMKEY_SYM_KP3,
  TERMKEY_SYM_KP4,
  TERMKEY_SYM_KP5,
  TERMKEY_SYM_KP6,
  TERMKEY_SYM_KP7,
  TERMKEY_SYM_KP8,
  TERMKEY_SYM_KP9,
  TERMKEY_SYM_KPENTER,
  TERMKEY_SYM_KPPLUS,
  TERMKEY_SYM_KPMINUS,
  TERMKEY_SYM_KPMULT,
  TERMKEY_SYM_KPDIV,
  TERMKEY_SYM_KPCOMMA,
  TERMKEY_SYM_KPPERIOD,
  TERMKEY_SYM_KPEQUALS,

  // et cetera ad nauseum
  TERMKEY_N_SYMS,
} TermKeySym;

typedef enum {
  TERMKEY_TYPE_UNICODE,
  TERMKEY_TYPE_FUNCTION,
  TERMKEY_TYPE_KEYSYM,
  TERMKEY_TYPE_MOUSE,
  TERMKEY_TYPE_POSITION,
  TERMKEY_TYPE_MODEREPORT,
  TERMKEY_TYPE_DCS,
  TERMKEY_TYPE_OSC,
  // add other recognised types here

  TERMKEY_TYPE_UNKNOWN_CSI = -1,
} TermKeyType;

typedef enum {
  TERMKEY_MOUSE_UNKNOWN,
  TERMKEY_MOUSE_PRESS,
  TERMKEY_MOUSE_DRAG,
  TERMKEY_MOUSE_RELEASE,
} TermKeyMouseEvent;

typedef enum {
  TERMKEY_EVENT_UNKNOWN,
  TERMKEY_EVENT_PRESS,
  TERMKEY_EVENT_REPEAT,
  TERMKEY_EVENT_RELEASE,
} TermKeyEvent;

enum {
  TERMKEY_KEYMOD_SHIFT = 1 << 0,
  TERMKEY_KEYMOD_ALT   = 1 << 1,
  TERMKEY_KEYMOD_CTRL  = 1 << 2,
};

typedef struct {
  const unsigned char *param;
  size_t length;
} TermKeyCsiParam;

enum {
  TERMKEY_FLAG_NOINTERPRET = 1 << 0,  // Do not interpret C0//DEL codes if possible
  TERMKEY_FLAG_CONVERTKP   = 1 << 1,  // Convert KP codes to regular keypresses
  TERMKEY_FLAG_RAW         = 1 << 2,  // Input is raw bytes, not UTF-8
  TERMKEY_FLAG_UTF8        = 1 << 3,  // Input is definitely UTF-8
  TERMKEY_FLAG_NOTERMIOS   = 1 << 4,  // Do not make initial termios calls on construction
  TERMKEY_FLAG_SPACESYMBOL = 1 << 5,  // Sets TERMKEY_CANON_SPACESYMBOL
  TERMKEY_FLAG_CTRLC       = 1 << 6,  // Allow Ctrl-C to be read as normal, disabling SIGINT
  TERMKEY_FLAG_EINTR       = 1 << 7,  // Return ERROR on signal (EINTR) rather than retry
  TERMKEY_FLAG_NOSTART     = 1 << 8,  // Do not call termkey_start() in constructor
};

enum {
  TERMKEY_CANON_SPACESYMBOL = 1 << 0,  // Space is symbolic rather than Unicode
  TERMKEY_CANON_DELBS       = 1 << 1,  // Del is converted to Backspace
};

typedef struct {
  TermKeyType type;
  union {
    int codepoint;  // TERMKEY_TYPE_UNICODE
    int number;    // TERMKEY_TYPE_FUNCTION
    TermKeySym sym;       // TERMKEY_TYPE_KEYSYM
    char mouse[4];  // TERMKEY_TYPE_MOUSE
                    // opaque. see termkey_interpret_mouse
  } code;

  int modifiers;

  TermKeyEvent event;

  // Any Unicode character can be UTF-8 encoded in no more than 6 bytes, plus
  // terminating NUL
  char utf8[7];
} TermKeyKey;

// Mostly-undocumented hooks for doing evil evil things
typedef const char *TermKey_Terminfo_Getstr_Hook(const char *name, const char *value, void *data);

typedef enum {
  TERMKEY_FORMAT_LONGMOD     = 1 << 0,  // Shift-... instead of S-...
  TERMKEY_FORMAT_CARETCTRL   = 1 << 1,  // ^X instead of C-X
  TERMKEY_FORMAT_ALTISMETA   = 1 << 2,  // Meta- or M- instead of Alt- or A-
  TERMKEY_FORMAT_WRAPBRACKET = 1 << 3,  // Wrap special keys in brackets like <Escape>
  TERMKEY_FORMAT_SPACEMOD    = 1 << 4,  // M Foo instead of M-Foo
  TERMKEY_FORMAT_LOWERMOD    = 1 << 5,  // meta or m instead of Meta or M
  TERMKEY_FORMAT_LOWERSPACE  = 1 << 6,  // page down instead of PageDown

  TERMKEY_FORMAT_MOUSE_POS   = 1 << 8,  // Include mouse position if relevant; @ col,line
} TermKeyFormat;

// Some useful combinations

#define TERMKEY_FORMAT_VIM (TermKeyFormat)(TERMKEY_FORMAT_ALTISMETA|TERMKEY_FORMAT_WRAPBRACKET)

typedef struct {
  TermKey *tk;

  unibi_term *unibi;  // only valid until first 'start' call

  struct trie_node *root;

  char *start_string;
  char *stop_string;
} TermKeyTI;
