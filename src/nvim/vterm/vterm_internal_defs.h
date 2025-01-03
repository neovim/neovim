#pragma once

#include <stdarg.h>

#include "nvim/mbyte_defs.h"
#include "nvim/vterm/vterm_defs.h"

#ifdef DEBUG
# define DEBUG_LOG(...) fprintf(stderr, __VA_ARGS__)
#else
# define DEBUG_LOG(...)
#endif

#define ESC_S "\x1b"

#define INTERMED_MAX 16

#define CSI_ARGS_MAX 16
#define CSI_LEADER_MAX 16

#define BUFIDX_PRIMARY   0
#define BUFIDX_ALTSCREEN 1

typedef struct VTermEncoding VTermEncoding;

typedef struct {
  VTermEncoding *enc;

  // This size should be increased if required by other stateful encodings
  char data[4 * sizeof(uint32_t)];
} VTermEncodingInstance;

struct VTermPen {
  VTermColor fg;
  VTermColor bg;
  int uri;
  unsigned bold:1;
  unsigned underline:2;
  unsigned italic:1;
  unsigned blink:1;
  unsigned reverse:1;
  unsigned conceal:1;
  unsigned strike:1;
  unsigned font:4;  // To store 0-9
  unsigned small:1;
  unsigned baseline:2;
};

struct VTermState {
  VTerm *vt;

  const VTermStateCallbacks *callbacks;
  void *cbdata;

  const VTermStateFallbacks *fallbacks;
  void *fbdata;

  int rows;
  int cols;

  // Current cursor position
  VTermPos pos;

  int at_phantom;  // True if we're on the "81st" phantom column to defer a wraparound

  int scrollregion_top;
  int scrollregion_bottom;  // -1 means unbounded
#define SCROLLREGION_BOTTOM(state) ((state)->scrollregion_bottom > \
                                    -1 ? (state)->scrollregion_bottom : (state)->rows)
  int scrollregion_left;
#define SCROLLREGION_LEFT(state)  ((state)->mode.leftrightmargin ? (state)->scrollregion_left : 0)
  int scrollregion_right;  // -1 means unbounded
#define SCROLLREGION_RIGHT(state) ((state)->mode.leftrightmargin \
                                   && (state)->scrollregion_right > \
                                   -1 ? (state)->scrollregion_right : (state)->cols)

  // Bitvector of tab stops
  uint8_t *tabstops;

  // Primary and Altscreen; lineinfos[1] is lazily allocated as needed
  VTermLineInfo *lineinfos[2];

  // lineinfo will == lineinfos[0] or lineinfos[1], depending on altscreen
  VTermLineInfo *lineinfo;
#define ROWWIDTH(state, \
                 row) ((state)->lineinfo[(row)].doublewidth ? ((state)->cols / 2) : (state)->cols)
#define THISROWWIDTH(state) ROWWIDTH(state, (state)->pos.row)

  // Mouse state
  int mouse_col, mouse_row;
  int mouse_buttons;
  int mouse_flags;
#define MOUSE_WANT_CLICK 0x01
#define MOUSE_WANT_DRAG  0x02
#define MOUSE_WANT_MOVE  0x04

  enum { MOUSE_X10, MOUSE_UTF8, MOUSE_SGR, MOUSE_RXVT, } mouse_protocol;

// Last glyph output, for Unicode recombining purposes
  char grapheme_buf[MAX_SCHAR_SIZE];
  size_t grapheme_len;
  uint32_t grapheme_last;  // last added UTF-32 char
  GraphemeState grapheme_state;
  int combine_width;  // The width of the glyph above
  VTermPos combine_pos;   // Position before movement

  struct {
    unsigned keypad:1;
    unsigned cursor:1;
    unsigned autowrap:1;
    unsigned insert:1;
    unsigned newline:1;
    unsigned cursor_visible:1;
    unsigned cursor_blink:1;
    unsigned cursor_shape:2;
    unsigned alt_screen:1;
    unsigned origin:1;
    unsigned screen:1;
    unsigned leftrightmargin:1;
    unsigned bracketpaste:1;
    unsigned report_focus:1;
  } mode;

  VTermEncodingInstance encoding[4], encoding_utf8;
  int gl_set, gr_set, gsingle_set;

  struct VTermPen pen;

  VTermColor default_fg;
  VTermColor default_bg;
  VTermColor colors[16];  // Store the 8 ANSI and the 8 ANSI high-brights only

  int bold_is_highbright;

  unsigned protected_cell : 1;

// Saved state under DEC mode 1048/1049
  struct {
    VTermPos pos;
    struct VTermPen pen;

    struct {
      unsigned cursor_visible:1;
      unsigned cursor_blink:1;
      unsigned cursor_shape:2;
    } mode;
  } saved;

// Temporary state for DECRQSS parsing
  union {
    char decrqss[4];
    struct {
      uint16_t mask;
      enum {
        SELECTION_INITIAL,
        SELECTION_SELECTED,
        SELECTION_QUERY,
        SELECTION_SET_INITIAL,
        SELECTION_SET,
        SELECTION_INVALID,
      } state : 8;
      uint32_t recvpartial;
      uint32_t sendpartial;
    } selection;
  } tmp;

  struct {
    const VTermSelectionCallbacks *callbacks;
    void *user;
    char *buffer;
    size_t buflen;
  } selection;
};

struct VTerm {
  const VTermAllocatorFunctions *allocator;
  void *allocdata;

  int rows;
  int cols;

  struct {
    unsigned utf8:1;
    unsigned ctrl8bit:1;
  } mode;

  struct {
    enum VTermParserState {
      NORMAL,
      CSI_LEADER,
      CSI_ARGS,
      CSI_INTERMED,
      DCS_COMMAND,
      // below here are the "string states"
      OSC_COMMAND,
      OSC,
      DCS_VTERM,
      APC,
      PM,
      SOS,
    } state;

    bool in_esc : 1;

    int intermedlen;
    char intermed[INTERMED_MAX];

    union {
      struct {
        int leaderlen;
        char leader[CSI_LEADER_MAX];

        int argi;
        long args[CSI_ARGS_MAX];
      } csi;
      struct {
        int command;
      } osc;
      struct {
        int commandlen;
        char command[CSI_LEADER_MAX];
      } dcs;
    } v;

    const VTermParserCallbacks *callbacks;
    void *cbdata;

    bool string_initial;

    bool emit_nul;
  } parser;

  // len == malloc()ed size; cur == number of valid bytes

  VTermOutputCallback *outfunc;
  void *outdata;

  char *outbuffer;
  size_t outbuffer_len;
  size_t outbuffer_cur;

  char *tmpbuffer;
  size_t tmpbuffer_len;

  VTermState *state;
  VTermScreen *screen;
};

struct VTermEncoding {
  void (*init)(VTermEncoding *enc, void *data);
  void (*decode)(VTermEncoding *enc, void *data, uint32_t cp[], int *cpi, int cplen,
                 const char bytes[], size_t *pos, size_t len);
};

typedef enum {
  ENC_UTF8,
  ENC_SINGLE_94,
} VTermEncodingType;

enum {
  C1_SS3 = 0x8f,
  C1_DCS = 0x90,
  C1_CSI = 0x9b,
  C1_ST  = 0x9c,
  C1_OSC = 0x9d,
};
