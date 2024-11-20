#pragma once

#include <stdint.h>

#include "nvim/tui/termkey/termkey_defs.h"

#define HAVE_TERMIOS
#ifdef _WIN32
# undef HAVE_TERMIOS
#endif

#ifdef HAVE_TERMIOS
# include <termios.h>
#endif

#ifdef _MSC_VER
# include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#endif

struct TermKeyDriver {
  const char *name;
  void *(*new_driver)(TermKey *tk, const char *term);
  void (*free_driver)(void *info);
  int (*start_driver)(TermKey *tk, void *info);
  int (*stop_driver)(TermKey *tk, void *info);
  TermKeyResult (*peekkey)(TermKey *tk, void *info, TermKeyKey *key, int force, size_t *nbytes);
};

struct keyinfo {
  TermKeyType type;
  TermKeySym sym;
  int modifier_mask;
  int modifier_set;
};

struct TermKeyDriverNode;
struct TermKeyDriverNode {
  struct TermKeyDriver *driver;
  void *info;
  struct TermKeyDriverNode *next;
};

struct TermKey {
  int fd;
  int flags;
  int canonflags;
  unsigned char *buffer;
  size_t buffstart;  // First offset in buffer
  size_t buffcount;  // NUMBER of entries valid in buffer
  size_t buffsize;   // Total malloc'ed size
  size_t hightide;   // Position beyond buffstart at which peekkey() should next start
                     // normally 0, but see also termkey_interpret_csi

#ifdef HAVE_TERMIOS
  struct termios restore_termios;
  char restore_termios_valid;
#endif

  TermKey_Terminfo_Getstr_Hook *ti_getstr_hook;
  void *ti_getstr_hook_data;

  int waittime;  // msec

  char is_closed;
  char is_started;

  int nkeynames;
  const char **keynames;

  // There are 32 C0 codes
  struct keyinfo c0[32];

  struct TermKeyDriverNode *drivers;

  // Now some "protected" methods for the driver to call but which we don't
  // want exported as real symbols in the library
  struct {
    void (*emit_codepoint)(TermKey *tk, int codepoint, TermKeyKey *key);
    TermKeyResult (*peekkey_simple)(TermKey *tk, TermKeyKey *key, int force, size_t *nbytes);
    TermKeyResult (*peekkey_mouse)(TermKey *tk, TermKeyKey *key, size_t *nbytes);
  } method;
};

static inline void termkey_key_get_linecol(const TermKeyKey *key, int *line, int *col)
{
  if (col) {
    *col = (unsigned char)key->code.mouse[1] | ((unsigned char)key->code.mouse[3] & 0x0f) << 8;
  }

  if (line) {
    *line = (unsigned char)key->code.mouse[2] | ((unsigned char)key->code.mouse[3] & 0x70) << 4;
  }
}

static inline void termkey_key_set_linecol(TermKeyKey *key, int line, int col)
{
  if (line > 0xfff) {
    line = 0xfff;
  }

  if (col > 0x7ff) {
    col = 0x7ff;
  }

  key->code.mouse[1] = (char)(line & 0x0ff);
  key->code.mouse[2] = (char)(col & 0x0ff);
  key->code.mouse[3] = (line & 0xf00) >> 8 | (col & 0x300) >> 4;
}
