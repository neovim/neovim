// Bidirectional text support.
//
// A subset of the Unicode Bidirectional Algorithm (UAX #9), enough to display
// Hebrew and Arabic mixed with Latin script and numbers: the paragraph rules
// P2 and P3, the weak rules W2 to W7, the neutral rules N0 to N2, the implicit
// rules I1 and I2, and L1 to L4.
//
// The characters that set the direction explicitly are not resolved (rules X1
// to X8), so a paragraph has one embedding level to start from, and the marks
// that combine with the character to their left are left where they are (rule
// L3).
//
// This file works on characters.  Applying the order it resolves to the cells
// of a line, which also hold the sign, number and fold columns and any virtual
// text, is grid.c's half.

#include <stdbool.h>
#include <stdint.h>
#include <utf8proc.h>

#include "nvim/ascii_defs.h"
#include "nvim/bidi.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/option_vars.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bidi.c.generated.h"
#endif

/// @return  the bidirectional character class of "c" (UAX #9 table 4).
BidiClass bidi_char_class(int c)
  FUNC_ATTR_PURE
{
  switch (utf8proc_get_property(c)->bidi_class) {
  case UTF8PROC_BIDI_CLASS_L:
    return kBidiL;
  case UTF8PROC_BIDI_CLASS_R:
    return kBidiR;
  case UTF8PROC_BIDI_CLASS_AL:
    return kBidiAL;
  case UTF8PROC_BIDI_CLASS_EN:
    return kBidiEN;
  case UTF8PROC_BIDI_CLASS_ES:
    return kBidiES;
  case UTF8PROC_BIDI_CLASS_ET:
    return kBidiET;
  case UTF8PROC_BIDI_CLASS_AN:
    return kBidiAN;
  case UTF8PROC_BIDI_CLASS_CS:
    return kBidiCS;
  case UTF8PROC_BIDI_CLASS_S:
    return kBidiS;
  case UTF8PROC_BIDI_CLASS_B:
    return kBidiB;
  case UTF8PROC_BIDI_CLASS_WS:
    return kBidiWS;
  default:
    // The explicit formatting and isolate characters are not resolved, and a
    // nonspacing mark is part of the cell of the character it sits on, so it is
    // never classified on its own.  Both read as neutral.
    return kBidiON;
  }
}

/// @return  the first line of the paragraph "lnum" belongs to.
///
/// A paragraph runs between blank lines, the way a reader sees one, not between
/// newlines.  Scanning back is bounded: a block of text longer than this is not
/// a paragraph anyone is reading as a unit.
static linenr_T bidi_paragraph_start(buf_T *buf, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  static buf_T *cached_buf = NULL;
  static linenr_T cached_lnum = 0;
  static linenr_T cached_start = 0;
  static int cached_changedtick = -1;

  int changedtick = (int)buf_get_changedtick(buf);

  // Lines are drawn in order, so the paragraph of the line before is nearly
  // always the answer, and one line has to be read instead of the whole scan.
  if (buf == cached_buf && changedtick == cached_changedtick && lnum == cached_lnum + 1) {
    cached_start = (ml_get_buf_len(buf, lnum - 1) == 0) ? lnum : cached_start;
    cached_lnum = lnum;
    return cached_start;
  }

  linenr_T limit = MAX(1, lnum - 500);
  linenr_T start = limit;
  for (linenr_T l = lnum; l > limit; l--) {
    if (ml_get_buf_len(buf, l - 1) == 0) {
      start = l;
      break;
    }
  }

  cached_buf = buf;
  cached_lnum = lnum;
  cached_start = start;
  cached_changedtick = changedtick;
  return start;
}

/// @return  true if the paragraph holding "lnum" reads right to left.
///
/// Resolving this per paragraph rather than per line keeps a Hebrew paragraph
/// aligned the same way throughout, even where one of its lines opens with a
/// Latin word (UAX #9 P1 to P3).
static bool bidi_paragraph_is_rtl(buf_T *buf, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  static buf_T *cached_buf = NULL;
  static linenr_T cached_start = 0;
  static int cached_changedtick = -1;
  static bool cached_rtl = false;

  linenr_T start = bidi_paragraph_start(buf, lnum);
  int changedtick = (int)buf_get_changedtick(buf);
  if (buf == cached_buf && start == cached_start && changedtick == cached_changedtick) {
    return cached_rtl;
  }

  bool rtl = false;
  for (linenr_T l = start; l <= buf->b_ml.ml_line_count && l < start + 500; l++) {
    if (ml_get_buf_len(buf, l) == 0) {
      if (l > start) {
        break;
      }
      continue;
    }
    const char *text = ml_get_buf(buf, l);
    bool strong = false;
    for (const char *p = text; *p != NUL; p += utfc_ptr2len(p)) {
      switch (bidi_char_class(utf_ptr2char(p))) {
      case kBidiL:
        strong = true;
        break;
      case kBidiR:
      case kBidiAL:
        rtl = true;
        strong = true;
        break;
      default:
        continue;
      }
      break;
    }
    if (strong) {
      break;
    }
  }

  cached_buf = buf;
  cached_start = start;
  cached_changedtick = changedtick;
  cached_rtl = rtl;
  return rtl;
}

/// @return  what 'bidi' does with the lines of "wp".
///
/// 'termbidi' and 'rightleft' both say the reordering is already someone else's
/// job, so 'bidi' stands down for either.
BidiMode bidi_mode(win_T *wp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  if (p_tbidi || wp->w_p_rl) {
    return kBidiOff;
  }
  switch (*wp->w_p_bidi) {
  case 'a':
    return kBidiAuto;
  case 'l':
    return kBidiLtr;
  case 'r':
    return kBidiRtl;
  default:
    return kBidiOff;
  }
}

/// @return  true if the paragraph holding line "lnum" of "wp" reads right to
///          left, and so starts at the right margin.
bool bidi_win_is_rtl(win_T *wp, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  switch (bidi_mode(wp)) {
  case kBidiRtl:
    return true;
  case kBidiAuto:
    return bidi_paragraph_is_rtl(wp->w_buffer, lnum);
  default:
    return false;
  }
}

/// @return  true if 'bidi' moves the cells of line "lnum" of "wp" when it is
///          drawn, because the line holds text that reads right to left or its
///          paragraph does, which pushes the line to the right margin.
///
/// Cached on the line, so that walking the cursor along one line costs a single
/// scan of it.
bool bidi_line_is_reordered(win_T *wp, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  static buf_T *cached_buf = NULL;
  static linenr_T cached_lnum = 0;
  static int cached_changedtick = -1;
  static bool cached_reordered = false;

  if (bidi_mode(wp) == kBidiOff) {
    return false;
  }
  if (bidi_win_is_rtl(wp, lnum)) {
    return true;
  }

  buf_T *buf = wp->w_buffer;
  int changedtick = (int)buf_get_changedtick(buf);
  if (buf == cached_buf && lnum == cached_lnum && changedtick == cached_changedtick) {
    return cached_reordered;
  }

  bool reordered = false;
  for (const char *p = ml_get_buf(buf, lnum); !reordered && *p != NUL; p += utfc_ptr2len(p)) {
    switch (bidi_char_class(utf_ptr2char(p))) {
    case kBidiR:
    case kBidiAL:
    case kBidiAN:
      reordered = true;
      break;
    default:
      break;
    }
  }

  cached_buf = buf;
  cached_lnum = lnum;
  cached_changedtick = changedtick;
  cached_reordered = reordered;
  return reordered;
}

/// The characters that mirror each other, from Unicode's BidiMirroring.txt,
/// each mapped to its counterpart.  A pair that BidiBrackets.txt also lists
/// opens and closes, and is matched as a pair by UAX #9 rule BD16.
///
/// Sorted by "from", for bidi_mirror_find().  This carries the pairs that turn
/// up in text a person edits, not the whole of BidiMirroring.txt.
static const struct {
  int32_t from;
  int32_t to;       ///< the character "from" is drawn as at an odd level
  int8_t bracket;   ///< 1 opens a pair, -1 closes one, 0 is not a pair
} bidi_mirror[] = {
  { 0x0028, 0x0029, 1 },
  { 0x0029, 0x0028, -1 },
  { 0x003c, 0x003e, 0 },
  { 0x003e, 0x003c, 0 },
  { 0x005b, 0x005d, 1 },
  { 0x005d, 0x005b, -1 },
  { 0x007b, 0x007d, 1 },
  { 0x007d, 0x007b, -1 },
  { 0x00ab, 0x00bb, 0 },
  { 0x00bb, 0x00ab, 0 },
  { 0x0f3a, 0x0f3b, 1 },
  { 0x0f3b, 0x0f3a, -1 },
  { 0x0f3c, 0x0f3d, 1 },
  { 0x0f3d, 0x0f3c, -1 },
  { 0x169b, 0x169c, 1 },
  { 0x169c, 0x169b, -1 },
  { 0x2039, 0x203a, 0 },
  { 0x203a, 0x2039, 0 },
  { 0x2045, 0x2046, 1 },
  { 0x2046, 0x2045, -1 },
  { 0x207d, 0x207e, 1 },
  { 0x207e, 0x207d, -1 },
  { 0x208d, 0x208e, 1 },
  { 0x208e, 0x208d, -1 },
  { 0x2208, 0x220b, 0 },
  { 0x220b, 0x2208, 0 },
  { 0x2264, 0x2265, 0 },
  { 0x2265, 0x2264, 0 },
  { 0x226a, 0x226b, 0 },
  { 0x226b, 0x226a, 0 },
  { 0x2308, 0x2309, 1 },
  { 0x2309, 0x2308, -1 },
  { 0x230a, 0x230b, 1 },
  { 0x230b, 0x230a, -1 },
  { 0x2329, 0x232a, 1 },
  { 0x232a, 0x2329, -1 },
  { 0x2768, 0x2769, 1 },
  { 0x2769, 0x2768, -1 },
  { 0x276a, 0x276b, 1 },
  { 0x276b, 0x276a, -1 },
  { 0x276c, 0x276d, 1 },
  { 0x276d, 0x276c, -1 },
  { 0x276e, 0x276f, 1 },
  { 0x276f, 0x276e, -1 },
  { 0x2770, 0x2771, 1 },
  { 0x2771, 0x2770, -1 },
  { 0x2772, 0x2773, 1 },
  { 0x2773, 0x2772, -1 },
  { 0x2774, 0x2775, 1 },
  { 0x2775, 0x2774, -1 },
  { 0x27c5, 0x27c6, 1 },
  { 0x27c6, 0x27c5, -1 },
  { 0x27e6, 0x27e7, 1 },
  { 0x27e7, 0x27e6, -1 },
  { 0x27e8, 0x27e9, 1 },
  { 0x27e9, 0x27e8, -1 },
  { 0x27ea, 0x27eb, 1 },
  { 0x27eb, 0x27ea, -1 },
  { 0x27ec, 0x27ed, 1 },
  { 0x27ed, 0x27ec, -1 },
  { 0x27ee, 0x27ef, 1 },
  { 0x27ef, 0x27ee, -1 },
  { 0x2983, 0x2984, 1 },
  { 0x2984, 0x2983, -1 },
  { 0x2985, 0x2986, 1 },
  { 0x2986, 0x2985, -1 },
  { 0x2987, 0x2988, 1 },
  { 0x2988, 0x2987, -1 },
  { 0x2989, 0x298a, 1 },
  { 0x298a, 0x2989, -1 },
  { 0x298b, 0x298c, 1 },
  { 0x298c, 0x298b, -1 },
  { 0x298d, 0x2990, 1 },
  { 0x298e, 0x298f, -1 },
  { 0x298f, 0x298e, 1 },
  { 0x2990, 0x298d, -1 },
  { 0x2991, 0x2992, 1 },
  { 0x2992, 0x2991, -1 },
  { 0x2993, 0x2994, 1 },
  { 0x2994, 0x2993, -1 },
  { 0x2995, 0x2996, 1 },
  { 0x2996, 0x2995, -1 },
  { 0x2997, 0x2998, 1 },
  { 0x2998, 0x2997, -1 },
  { 0x29d8, 0x29d9, 1 },
  { 0x29d9, 0x29d8, -1 },
  { 0x29da, 0x29db, 1 },
  { 0x29db, 0x29da, -1 },
  { 0x29fc, 0x29fd, 1 },
  { 0x29fd, 0x29fc, -1 },
  { 0x2e22, 0x2e23, 1 },
  { 0x2e23, 0x2e22, -1 },
  { 0x2e24, 0x2e25, 1 },
  { 0x2e25, 0x2e24, -1 },
  { 0x2e26, 0x2e27, 1 },
  { 0x2e27, 0x2e26, -1 },
  { 0x2e28, 0x2e29, 1 },
  { 0x2e29, 0x2e28, -1 },
  { 0x2e55, 0x2e56, 1 },
  { 0x2e56, 0x2e55, -1 },
  { 0x2e57, 0x2e58, 1 },
  { 0x2e58, 0x2e57, -1 },
  { 0x2e59, 0x2e5a, 1 },
  { 0x2e5a, 0x2e59, -1 },
  { 0x2e5b, 0x2e5c, 1 },
  { 0x2e5c, 0x2e5b, -1 },
  { 0x3008, 0x3009, 1 },
  { 0x3009, 0x3008, -1 },
  { 0x300a, 0x300b, 1 },
  { 0x300b, 0x300a, -1 },
  { 0x300c, 0x300d, 1 },
  { 0x300d, 0x300c, -1 },
  { 0x300e, 0x300f, 1 },
  { 0x300f, 0x300e, -1 },
  { 0x3010, 0x3011, 1 },
  { 0x3011, 0x3010, -1 },
  { 0x3014, 0x3015, 1 },
  { 0x3015, 0x3014, -1 },
  { 0x3016, 0x3017, 1 },
  { 0x3017, 0x3016, -1 },
  { 0x3018, 0x3019, 1 },
  { 0x3019, 0x3018, -1 },
  { 0x301a, 0x301b, 1 },
  { 0x301b, 0x301a, -1 },
  { 0xfe59, 0xfe5a, 1 },
  { 0xfe5a, 0xfe59, -1 },
  { 0xfe5b, 0xfe5c, 1 },
  { 0xfe5c, 0xfe5b, -1 },
  { 0xfe5d, 0xfe5e, 1 },
  { 0xfe5e, 0xfe5d, -1 },
  { 0xff08, 0xff09, 1 },
  { 0xff09, 0xff08, -1 },
  { 0xff3b, 0xff3d, 1 },
  { 0xff3d, 0xff3b, -1 },
  { 0xff5b, 0xff5d, 1 },
  { 0xff5d, 0xff5b, -1 },
  { 0xff5f, 0xff60, 1 },
  { 0xff60, 0xff5f, -1 },
  { 0xff62, 0xff63, 1 },
  { 0xff63, 0xff62, -1 },
};

/// @return  the index of "c" in bidi_mirror[], or -1 when it is not there.
static int bidi_mirror_find(int c)
  FUNC_ATTR_PURE
{
  int lo = 0;
  int hi = (int)ARRAY_SIZE(bidi_mirror) - 1;

  while (lo <= hi) {
    int mid = (lo + hi) / 2;
    if (c < bidi_mirror[mid].from) {
      hi = mid - 1;
    } else if (c > bidi_mirror[mid].from) {
      lo = mid + 1;
    } else {
      return mid;
    }
  }
  return -1;
}

/// @return  the form "c" is drawn as at an odd embedding level, so that an
///          opening bracket keeps opening towards the text it encloses
///          (UAX #9 L4).  NUL when it has no counterpart.
int bidi_char_mirror(int c)
  FUNC_ATTR_PURE
{
  int i = bidi_mirror_find(c);
  return (i < 0) ? NUL : bidi_mirror[i].to;
}

/// @return  true for a neutral or isolate formatting class, the "NI" of UAX #9.
static bool bidi_class_is_neutral(uint8_t bidi_class)
{
  return bidi_class == kBidiB || bidi_class == kBidiS
         || bidi_class == kBidiWS || bidi_class == kBidiON;
}

/// @return  the direction a class counts as while resolving neutrals, where a
///          number counts as right-to-left (UAX #9 N1).
static uint8_t bidi_class_direction(uint8_t bidi_class)
{
  switch (bidi_class) {
  case kBidiL:
    return kBidiL;
  case kBidiR:
  case kBidiEN:
  case kBidiAN:
    return kBidiR;
  default:
    return kBidiON;
  }
}

/// U+2329 and U+3008, and their closing counterparts, are canonically the same
/// character and pair with each other.
static int bidi_bracket_canonical(int c)
  FUNC_ATTR_CONST
{
  switch (c) {
  case 0x2329:
    return 0x3008;
  case 0x232a:
    return 0x3009;
  default:
    return c;
  }
}

/// @param[out] closing  the bracket "c" pairs with, when it opens one.
/// @return  whether "c" opens (1), closes (-1) or is not (0) a bracket.
static int bidi_bracket_kind(int c, int *closing)
  FUNC_ATTR_NONNULL_ALL
{
  int i = bidi_mirror_find(c);
  if (i < 0 || bidi_mirror[i].bracket == 0) {
    return 0;
  }
  if (bidi_mirror[i].bracket > 0) {
    *closing = bidi_mirror[i].to;
  }
  return bidi_mirror[i].bracket;
}

/// Give both brackets of each pair in "cls" the direction the text between them
/// establishes (UAX #9 BD16 and N0).
///
/// Runs after the weak rules and before the neutral ones, so that a bracket
/// takes the direction of what it encloses rather than of what surrounds it.
///
/// @param cps  the character behind each class, for finding the pairs.
static void bidi_resolve_brackets(uint8_t *cls, const int *cps, int len, int para_level)
  FUNC_ATTR_NONNULL_ALL
{
  // BD16: match the brackets with a stack, in logical order.  Unicode caps the
  // stack at 63 entries and abandons the rule when it overflows.
  struct { int closing; int pos; } stack[63];
  int depth = 0;
  int open_at[63];
  int close_at[63];
  int pairs = 0;

  for (int i = 0; i < len && pairs < 63; i++) {
    if (cls[i] != kBidiON) {
      continue;
    }
    int closing = 0;
    int kind = bidi_bracket_kind(cps[i], &closing);
    if (kind == 1) {
      if (depth == 63) {
        return;
      }
      stack[depth].closing = bidi_bracket_canonical(closing);
      stack[depth].pos = i;
      depth++;
    } else if (kind == -1) {
      for (int d = depth - 1; d >= 0; d--) {
        if (stack[d].closing != bidi_bracket_canonical(cps[i])) {
          continue;
        }
        open_at[pairs] = stack[d].pos;
        close_at[pairs] = i;
        pairs++;
        depth = d;
        break;
      }
    }
  }

  uint8_t embedding = (para_level & 1) ? kBidiR : kBidiL;
  uint8_t opposite = (para_level & 1) ? kBidiL : kBidiR;

  for (int p = 0; p < pairs; p++) {
    // N0 b and c: what strong directions does the text between them hold?
    bool has_embedding = false;
    bool has_opposite = false;
    for (int i = open_at[p] + 1; i < close_at[p]; i++) {
      uint8_t dir = bidi_class_direction(cls[i]);
      has_embedding |= (dir == embedding);
      has_opposite |= (dir == opposite);
    }

    uint8_t resolved = kBidiON;
    if (has_embedding) {
      resolved = embedding;
    } else if (has_opposite) {
      // N0 c: the direction before the pair decides, back to the start of the
      // line, which counts as the direction of the paragraph.
      uint8_t before = embedding;
      for (int i = open_at[p] - 1; i >= 0; i--) {
        uint8_t dir = bidi_class_direction(cls[i]);
        if (dir != kBidiON) {
          before = dir;
          break;
        }
      }
      resolved = (before == opposite) ? opposite : embedding;
    }

    if (resolved != kBidiON) {
      cls[open_at[p]] = resolved;
      cls[close_at[p]] = resolved;
    }
  }
}

/// Resolve the embedding level of each of the "len" characters whose classes are
/// in "cls", starting from "para_level".
///
/// This is the weak, neutral and implicit half of UAX #9: rules W2 to W7, N0 to
/// N2, and I1 and I2, followed by L1.  W1 needs no work here because a
/// nonspacing mark travels with the character it sits on.
///
/// @param cls    the class of each character.  Resolved in place.
/// @param orig   the class each character started with, which L1 needs.
/// @param cps    the character behind each class, for matching bracket pairs.
/// @param[out] levels  the resolved level of each character.
void bidi_resolve_levels(uint8_t *cls, const uint8_t *orig, const int *cps, uint8_t *levels,
                         int len, int para_level)
  FUNC_ATTR_NONNULL_ALL
{
  uint8_t sos = (para_level & 1) ? kBidiR : kBidiL;

  // W2: a European number takes the type of the last strong character before it
  // when that is Arabic.  W3: Arabic letters are then plain right-to-left.
  uint8_t strong = sos;
  for (int i = 0; i < len; i++) {
    if (cls[i] == kBidiL || cls[i] == kBidiR || cls[i] == kBidiAL) {
      strong = cls[i];
    } else if (cls[i] == kBidiEN && strong == kBidiAL) {
      cls[i] = kBidiAN;
    }
  }
  for (int i = 0; i < len; i++) {
    if (cls[i] == kBidiAL) {
      cls[i] = kBidiR;
    }
  }

  // W4: a single separator between two numbers of the same kind joins them.
  for (int i = 1; i < len - 1; i++) {
    if (cls[i] == kBidiES && cls[i - 1] == kBidiEN && cls[i + 1] == kBidiEN) {
      cls[i] = kBidiEN;
    } else if (cls[i] == kBidiCS && cls[i - 1] == cls[i + 1]
               && (cls[i - 1] == kBidiEN || cls[i - 1] == kBidiAN)) {
      cls[i] = cls[i - 1];
    }
  }

  // W5: a run of European terminators next to a European number joins it.
  for (int i = 0; i < len; i++) {
    if (cls[i] != kBidiET) {
      continue;
    }
    int end = i;
    while (end < len && cls[end] == kBidiET) {
      end++;
    }
    if ((i > 0 && cls[i - 1] == kBidiEN) || (end < len && cls[end] == kBidiEN)) {
      for (int j = i; j < end; j++) {
        cls[j] = kBidiEN;
      }
    }
    i = end - 1;
  }

  // W6: the separators and terminators that are left are neutral.
  // W7: a European number after a strong left-to-right character joins it.
  strong = sos;
  for (int i = 0; i < len; i++) {
    if (cls[i] == kBidiET || cls[i] == kBidiES || cls[i] == kBidiCS) {
      cls[i] = kBidiON;
    }
    if (cls[i] == kBidiL || cls[i] == kBidiR) {
      strong = cls[i];
    } else if (cls[i] == kBidiEN && strong == kBidiL) {
      cls[i] = kBidiL;
    }
  }

  bidi_resolve_brackets(cls, cps, len, para_level);

  // N1: a run of neutrals between two characters of the same direction takes it.
  // N2: any that are left take the direction of the paragraph.
  for (int i = 0; i < len; i++) {
    if (!bidi_class_is_neutral(cls[i])) {
      continue;
    }
    int end = i;
    while (end < len && bidi_class_is_neutral(cls[end])) {
      end++;
    }
    uint8_t before = (i > 0) ? bidi_class_direction(cls[i - 1]) : sos;
    uint8_t after = (end < len) ? bidi_class_direction(cls[end]) : sos;
    uint8_t resolved = (before == after && before != kBidiON) ? before : sos;
    for (int j = i; j < end; j++) {
      cls[j] = resolved;
    }
    i = end - 1;
  }

  // I1 and I2: the levels the classes imply.
  for (int i = 0; i < len; i++) {
    int level = para_level;
    if (para_level % 2 == 0) {
      if (cls[i] == kBidiR) {
        level += 1;
      } else if (cls[i] == kBidiAN || cls[i] == kBidiEN) {
        level += 2;
      }
    } else if (cls[i] == kBidiL || cls[i] == kBidiEN || cls[i] == kBidiAN) {
      level += 1;
    }
    levels[i] = (uint8_t)level;
  }

  // L1: a segment separator, and any whitespace running up to it or to the end
  // of the line, is drawn at the level of the paragraph.  This looks at the
  // class a character started with, not the one the rules above resolved.
  bool trailing = true;
  for (int i = len - 1; i >= 0; i--) {
    if (orig[i] == kBidiS || orig[i] == kBidiB) {
      levels[i] = (uint8_t)para_level;
      trailing = true;
    } else if (orig[i] == kBidiWS) {
      if (trailing) {
        levels[i] = (uint8_t)para_level;
      }
    } else {
      trailing = false;
    }
  }
}

/// Fill "order" with the visual order of "len" items given their "levels": the
/// index of the item drawn in each position, left to right (UAX #9 L2).
void bidi_visual_order(const uint8_t *levels, int len, int para_level, int *order)
  FUNC_ATTR_NONNULL_ALL
{
  for (int i = 0; i < len; i++) {
    order[i] = i;
  }

  int highest = para_level;
  int lowest_odd = UINT8_MAX;
  for (int i = 0; i < len; i++) {
    highest = MAX(highest, (int)levels[i]);
    if (levels[i] & 1) {
      lowest_odd = MIN(lowest_odd, (int)levels[i]);
    }
  }

  for (int level = highest; level >= lowest_odd; level--) {
    for (int i = 0; i < len; i++) {
      if (levels[order[i]] < level) {
        continue;
      }
      int end = i;
      while (end < len && levels[order[end]] >= level) {
        end++;
      }
      for (int a = i, b = end - 1; a < b; a++, b--) {
        int tmp = order[a];
        order[a] = order[b];
        order[b] = tmp;
      }
      i = end;
    }
  }
}
