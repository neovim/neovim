#ifdef __cplusplus
extern "C" {
#endif

#ifndef GUARD_TERMKEY_H_
#define GUARD_TERMKEY_H_

#include <stdint.h>
#include <stdlib.h>

#define TERMKEY_VERSION_MAJOR 0
#define TERMKEY_VERSION_MINOR 22

#define TERMKEY_CHECK_VERSION \
        termkey_check_version(TERMKEY_VERSION_MAJOR, TERMKEY_VERSION_MINOR)

typedef enum {
  TERMKEY_SYM_UNKNOWN = -1,
  TERMKEY_SYM_NONE = 0,

  /* Special names in C0 */
  TERMKEY_SYM_BACKSPACE,
  TERMKEY_SYM_TAB,
  TERMKEY_SYM_ENTER,
  TERMKEY_SYM_ESCAPE,

  /* Special names in G0 */
  TERMKEY_SYM_SPACE,
  TERMKEY_SYM_DEL,

  /* Special keys */
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

  /* Special keys from terminfo */
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

  /* Numeric keypad special keys */
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

  /* et cetera ad nauseum */
  TERMKEY_N_SYMS
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
  /* add other recognised types here */

  TERMKEY_TYPE_UNKNOWN_CSI = -1
} TermKeyType;

typedef enum {
  TERMKEY_RES_NONE,
  TERMKEY_RES_KEY,
  TERMKEY_RES_EOF,
  TERMKEY_RES_AGAIN,
  TERMKEY_RES_ERROR
} TermKeyResult;

typedef enum {
  TERMKEY_MOUSE_UNKNOWN,
  TERMKEY_MOUSE_PRESS,
  TERMKEY_MOUSE_DRAG,
  TERMKEY_MOUSE_RELEASE
} TermKeyMouseEvent;

enum {
  TERMKEY_KEYMOD_SHIFT = 1 << 0,
  TERMKEY_KEYMOD_ALT   = 1 << 1,
  TERMKEY_KEYMOD_CTRL  = 1 << 2
};

typedef struct {
  TermKeyType type;
  union {
    long       codepoint; /* TERMKEY_TYPE_UNICODE */
    int        number;    /* TERMKEY_TYPE_FUNCTION */
    TermKeySym sym;       /* TERMKEY_TYPE_KEYSYM */
    char       mouse[4];  /* TERMKEY_TYPE_MOUSE */
                          /* opaque. see termkey_interpret_mouse */
  } code;

  int modifiers;

  /* Any Unicode character can be UTF-8 encoded in no more than 6 bytes, plus
   * terminating NUL */
  char utf8[7];
} TermKeyKey;

typedef struct {
  const unsigned char *param;
  size_t length;
} TermKeyCsiParam;

typedef struct TermKey TermKey;

enum {
  TERMKEY_FLAG_NOINTERPRET = 1 << 0, /* Do not interpret C0//DEL codes if possible */
  TERMKEY_FLAG_CONVERTKP   = 1 << 1, /* Convert KP codes to regular keypresses */
  TERMKEY_FLAG_RAW         = 1 << 2, /* Input is raw bytes, not UTF-8 */
  TERMKEY_FLAG_UTF8        = 1 << 3, /* Input is definitely UTF-8 */
  TERMKEY_FLAG_NOTERMIOS   = 1 << 4, /* Do not make initial termios calls on construction */
  TERMKEY_FLAG_SPACESYMBOL = 1 << 5, /* Sets TERMKEY_CANON_SPACESYMBOL */
  TERMKEY_FLAG_CTRLC       = 1 << 6, /* Allow Ctrl-C to be read as normal, disabling SIGINT */
  TERMKEY_FLAG_EINTR       = 1 << 7, /* Return ERROR on signal (EINTR) rather than retry */
  TERMKEY_FLAG_NOSTART     = 1 << 8  /* Do not call termkey_start() in constructor */
};

enum {
  TERMKEY_CANON_SPACESYMBOL = 1 << 0, /* Space is symbolic rather than Unicode */
  TERMKEY_CANON_DELBS       = 1 << 1  /* Del is converted to Backspace */
};

void termkey_check_version(int major, int minor);

TermKey *termkey_new(int fd, int flags);
TermKey *termkey_new_abstract(const char *term, int flags);
void     termkey_free(TermKey *tk);
void     termkey_destroy(TermKey *tk);

/* Mostly-undocumented hooks for doing evil evil things */
typedef const char *TermKey_Terminfo_Getstr_Hook(const char *name, const char *value, void *data);
void termkey_hook_terminfo_getstr(TermKey *tk, TermKey_Terminfo_Getstr_Hook *hookfn, void *data);

int termkey_start(TermKey *tk);
int termkey_stop(TermKey *tk);
int termkey_is_started(TermKey *tk);

int termkey_get_fd(TermKey *tk);

int  termkey_get_flags(TermKey *tk);
void termkey_set_flags(TermKey *tk, int newflags);

int  termkey_get_waittime(TermKey *tk);
void termkey_set_waittime(TermKey *tk, int msec);

int  termkey_get_canonflags(TermKey *tk);
void termkey_set_canonflags(TermKey *tk, int);

size_t termkey_get_buffer_size(TermKey *tk);
int    termkey_set_buffer_size(TermKey *tk, size_t size);

size_t termkey_get_buffer_remaining(TermKey *tk);

void termkey_canonicalise(TermKey *tk, TermKeyKey *key);

TermKeyResult termkey_getkey(TermKey *tk, TermKeyKey *key);
TermKeyResult termkey_getkey_force(TermKey *tk, TermKeyKey *key);
TermKeyResult termkey_waitkey(TermKey *tk, TermKeyKey *key);

TermKeyResult termkey_advisereadable(TermKey *tk);

size_t termkey_push_bytes(TermKey *tk, const char *bytes, size_t len);

TermKeySym termkey_register_keyname(TermKey *tk, TermKeySym sym, const char *name);
const char *termkey_get_keyname(TermKey *tk, TermKeySym sym);
const char *termkey_lookup_keyname(TermKey *tk, const char *str, TermKeySym *sym);

TermKeySym termkey_keyname2sym(TermKey *tk, const char *keyname);

TermKeyResult termkey_interpret_mouse(TermKey *tk, const TermKeyKey *key, TermKeyMouseEvent *event, int *button, int *line, int *col);

TermKeyResult termkey_interpret_position(TermKey *tk, const TermKeyKey *key, int *line, int *col);

TermKeyResult termkey_interpret_modereport(TermKey *tk, const TermKeyKey *key, int *initial, int *mode, int *value);

TermKeyResult termkey_interpret_csi(TermKey *tk, const TermKeyKey *key, TermKeyCsiParam params[], size_t *nparams, unsigned long *cmd);

TermKeyResult termkey_interpret_csi_param(TermKeyCsiParam param, long *paramp, long subparams[], size_t *nsubparams);

TermKeyResult termkey_interpret_string(TermKey *tk, const TermKeyKey *key, const char **strp);

typedef enum {
  TERMKEY_FORMAT_LONGMOD     = 1 << 0, /* Shift-... instead of S-... */
  TERMKEY_FORMAT_CARETCTRL   = 1 << 1, /* ^X instead of C-X */
  TERMKEY_FORMAT_ALTISMETA   = 1 << 2, /* Meta- or M- instead of Alt- or A- */
  TERMKEY_FORMAT_WRAPBRACKET = 1 << 3, /* Wrap special keys in brackets like <Escape> */
  TERMKEY_FORMAT_SPACEMOD    = 1 << 4, /* M Foo instead of M-Foo */
  TERMKEY_FORMAT_LOWERMOD    = 1 << 5, /* meta or m instead of Meta or M */
  TERMKEY_FORMAT_LOWERSPACE  = 1 << 6, /* page down instead of PageDown */

  TERMKEY_FORMAT_MOUSE_POS   = 1 << 8  /* Include mouse position if relevant; @ col,line */
} TermKeyFormat;

/* Some useful combinations */

#define TERMKEY_FORMAT_VIM (TermKeyFormat)(TERMKEY_FORMAT_ALTISMETA|TERMKEY_FORMAT_WRAPBRACKET)
#define TERMKEY_FORMAT_URWID (TermKeyFormat)(TERMKEY_FORMAT_LONGMOD|TERMKEY_FORMAT_ALTISMETA| \
          TERMKEY_FORMAT_LOWERMOD|TERMKEY_FORMAT_SPACEMOD|TERMKEY_FORMAT_LOWERSPACE)

size_t      termkey_strfkey(TermKey *tk, char *buffer, size_t len, TermKeyKey *key, TermKeyFormat format);
const char *termkey_strpkey(TermKey *tk, const char *str, TermKeyKey *key, TermKeyFormat format);

int termkey_keycmp(TermKey *tk, const TermKeyKey *key1, const TermKeyKey *key2);

#endif

#ifdef __cplusplus
}
#endif
