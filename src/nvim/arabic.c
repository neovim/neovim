/// @file arabic.c
///
/// Functions for Arabic language.
///
/// Author: Nadim Shaikli & Isam Bayazidi
/// Farsi support and restructuring to make adding new letters easier by Ali
/// Gholami Rudi.  Further work by Ameretat Reith.

/// Sorted list of unicode Arabic characters.  Each entry holds the
/// presentation forms of a letter.
///
/// Arabic characters are categorized into following types:
///
/// Isolated    - iso-8859-6 form         char denoted with  a_*
/// Initial     - unicode form-B start    char denoted with  a_i_*
/// Medial      - unicode form-B middle   char denoted with  a_m_*
/// Final       - unicode form-B final    char denoted with  a_f_*
/// Stand-Alone - unicode form-B isolated char denoted with  a_s_* (NOT USED)

#include <stdbool.h>
#include <stddef.h>

#include "nvim/arabic.h"
#include "nvim/ascii_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/option_vars.h"

// Unicode values for Arabic characters.
enum {
  a_HAMZA = 0x0621,
  a_ALEF_MADDA = 0x0622,
  a_ALEF_HAMZA_ABOVE = 0x0623,
  a_WAW_HAMZA = 0x0624,
  a_ALEF_HAMZA_BELOW = 0x0625,
  a_YEH_HAMZA = 0x0626,
  a_ALEF = 0x0627,
  a_BEH = 0x0628,
  a_TEH_MARBUTA = 0x0629,
  a_TEH = 0x062a,
  a_THEH = 0x062b,
  a_JEEM = 0x062c,
  a_HAH = 0x062d,
  a_KHAH = 0x062e,
  a_DAL = 0x062f,
  a_THAL = 0x0630,
  a_REH = 0x0631,
  a_ZAIN = 0x0632,
  a_SEEN = 0x0633,
  a_SHEEN = 0x0634,
  a_SAD = 0x0635,
  a_DAD = 0x0636,
  a_TAH = 0x0637,
  a_ZAH = 0x0638,
  a_AIN = 0x0639,
  a_GHAIN = 0x063a,
  a_TATWEEL = 0x0640,
  a_FEH = 0x0641,
  a_QAF = 0x0642,
  a_KAF = 0x0643,
  a_LAM = 0x0644,
  a_MEEM = 0x0645,
  a_NOON = 0x0646,
  a_HEH = 0x0647,
  a_WAW = 0x0648,
  a_ALEF_MAKSURA = 0x0649,
  a_YEH = 0x064a,
  a_FATHATAN = 0x064b,
  a_DAMMATAN = 0x064c,
  a_KASRATAN = 0x064d,
  a_FATHA = 0x064e,
  a_DAMMA = 0x064f,
  a_KASRA = 0x0650,
  a_SHADDA = 0x0651,
  a_SUKUN = 0x0652,
  a_MADDA_ABOVE = 0x0653,
  a_HAMZA_ABOVE = 0x0654,
  a_HAMZA_BELOW = 0x0655,

  a_PEH = 0x067e,
  a_TCHEH = 0x0686,
  a_JEH = 0x0698,
  a_FKAF = 0x06a9,
  a_GAF = 0x06af,
  a_FYEH = 0x06cc,

  a_s_LAM_ALEF_MADDA_ABOVE = 0xfef5,
  a_f_LAM_ALEF_MADDA_ABOVE = 0xfef6,
  a_s_LAM_ALEF_HAMZA_ABOVE = 0xfef7,
  a_f_LAM_ALEF_HAMZA_ABOVE = 0xfef8,
  a_s_LAM_ALEF_HAMZA_BELOW = 0xfef9,
  a_f_LAM_ALEF_HAMZA_BELOW = 0xfefa,
  a_s_LAM_ALEF = 0xfefb,
  a_f_LAM_ALEF = 0xfefc,
};

static struct achar {
  unsigned c;
  unsigned isolated;
  unsigned initial;
  unsigned medial;
  unsigned final;
} achars[] = {
  { a_HAMZA, 0xfe80, 0, 0, 0 },
  { a_ALEF_MADDA, 0xfe81, 0, 0, 0xfe82 },
  { a_ALEF_HAMZA_ABOVE, 0xfe83, 0, 0, 0xfe84 },
  { a_WAW_HAMZA, 0xfe85, 0, 0, 0xfe86 },
  { a_ALEF_HAMZA_BELOW, 0xfe87, 0, 0, 0xfe88 },
  { a_YEH_HAMZA, 0xfe89, 0xfe8b, 0xfe8c, 0xfe8a },
  { a_ALEF, 0xfe8d, 0, 0, 0xfe8e },
  { a_BEH, 0xfe8f, 0xfe91, 0xfe92, 0xfe90 },
  { a_TEH_MARBUTA, 0xfe93, 0, 0, 0xfe94 },
  { a_TEH, 0xfe95, 0xfe97, 0xfe98, 0xfe96 },
  { a_THEH, 0xfe99, 0xfe9b, 0xfe9c, 0xfe9a },
  { a_JEEM, 0xfe9d, 0xfe9f, 0xfea0, 0xfe9e },
  { a_HAH, 0xfea1, 0xfea3, 0xfea4, 0xfea2 },
  { a_KHAH, 0xfea5, 0xfea7, 0xfea8, 0xfea6 },
  { a_DAL, 0xfea9, 0, 0, 0xfeaa },
  { a_THAL, 0xfeab, 0, 0, 0xfeac },
  { a_REH, 0xfead, 0, 0, 0xfeae },
  { a_ZAIN, 0xfeaf, 0, 0, 0xfeb0 },
  { a_SEEN, 0xfeb1, 0xfeb3, 0xfeb4, 0xfeb2 },
  { a_SHEEN, 0xfeb5, 0xfeb7, 0xfeb8, 0xfeb6 },
  { a_SAD, 0xfeb9, 0xfebb, 0xfebc, 0xfeba },
  { a_DAD, 0xfebd, 0xfebf, 0xfec0, 0xfebe },
  { a_TAH, 0xfec1, 0xfec3, 0xfec4, 0xfec2 },
  { a_ZAH, 0xfec5, 0xfec7, 0xfec8, 0xfec6 },
  { a_AIN, 0xfec9, 0xfecb, 0xfecc, 0xfeca },
  { a_GHAIN, 0xfecd, 0xfecf, 0xfed0, 0xfece },
  { a_TATWEEL, 0, 0x0640, 0x0640, 0x0640 },
  { a_FEH, 0xfed1, 0xfed3, 0xfed4, 0xfed2 },
  { a_QAF, 0xfed5, 0xfed7, 0xfed8, 0xfed6 },
  { a_KAF, 0xfed9, 0xfedb, 0xfedc, 0xfeda },
  { a_LAM, 0xfedd, 0xfedf, 0xfee0, 0xfede },
  { a_MEEM, 0xfee1, 0xfee3, 0xfee4, 0xfee2 },
  { a_NOON, 0xfee5, 0xfee7, 0xfee8, 0xfee6 },
  { a_HEH, 0xfee9, 0xfeeb, 0xfeec, 0xfeea },
  { a_WAW, 0xfeed, 0, 0, 0xfeee },
  { a_ALEF_MAKSURA, 0xfeef, 0, 0, 0xfef0 },
  { a_YEH, 0xfef1, 0xfef3, 0xfef4, 0xfef2 },
  { a_FATHATAN, 0xfe70, 0, 0, 0 },
  { a_DAMMATAN, 0xfe72, 0, 0, 0 },
  { a_KASRATAN, 0xfe74, 0, 0, 0 },
  { a_FATHA, 0xfe76, 0, 0xfe77, 0 },
  { a_DAMMA, 0xfe78, 0, 0xfe79, 0 },
  { a_KASRA, 0xfe7a, 0, 0xfe7b, 0 },
  { a_SHADDA, 0xfe7c, 0, 0xfe7c, 0 },
  { a_SUKUN, 0xfe7e, 0, 0xfe7f, 0 },
  { a_MADDA_ABOVE, 0, 0, 0, 0 },
  { a_HAMZA_ABOVE, 0, 0, 0, 0 },
  { a_HAMZA_BELOW, 0, 0, 0, 0 },
  { a_PEH, 0xfb56, 0xfb58, 0xfb59, 0xfb57 },
  { a_TCHEH, 0xfb7a, 0xfb7c, 0xfb7d, 0xfb7b },
  { a_JEH, 0xfb8a, 0, 0, 0xfb8b },
  { a_FKAF, 0xfb8e, 0xfb90, 0xfb91, 0xfb8f },
  { a_GAF, 0xfb92, 0xfb94, 0xfb95, 0xfb93 },
  { a_FYEH, 0xfbfc, 0xfbfe, 0xfbff, 0xfbfd },
};

#define a_BYTE_ORDER_MARK               0xfeff

#include "arabic.c.generated.h"

/// Find the struct achar pointer to the given Arabic char.
/// Returns NULL if not found.
static struct achar *find_achar(int c)
{
  // using binary search to find c
  int h = ARRAY_SIZE(achars);
  int l = 0;
  while (l < h) {
    int m = (h + l) / 2;
    if (achars[m].c == (unsigned)c) {
      return &achars[m];
    }
    if ((unsigned)c < achars[m].c) {
      h = m;
    } else {
      l = m + 1;
    }
  }
  return NULL;
}

/// Change shape - from Combination (2 char) to an Isolated
static int chg_c_laa2i(int hid_c)
{
  int tempc;

  switch (hid_c) {
  case a_ALEF_MADDA:
    tempc = a_s_LAM_ALEF_MADDA_ABOVE;
    break;
  case a_ALEF_HAMZA_ABOVE:
    tempc = a_s_LAM_ALEF_HAMZA_ABOVE;
    break;
  case a_ALEF_HAMZA_BELOW:
    tempc = a_s_LAM_ALEF_HAMZA_BELOW;
    break;
  case a_ALEF:
    tempc = a_s_LAM_ALEF;
    break;
  default:
    tempc = 0;
  }

  return tempc;
}

/// Change shape - from Combination-Isolated to Final
static int chg_c_laa2f(int hid_c)
{
  int tempc;

  switch (hid_c) {
  case a_ALEF_MADDA:
    tempc = a_f_LAM_ALEF_MADDA_ABOVE;
    break;
  case a_ALEF_HAMZA_ABOVE:
    tempc = a_f_LAM_ALEF_HAMZA_ABOVE;
    break;
  case a_ALEF_HAMZA_BELOW:
    tempc = a_f_LAM_ALEF_HAMZA_BELOW;
    break;
  case a_ALEF:
    tempc = a_f_LAM_ALEF;
    break;
  default:
    tempc = 0;
  }

  return tempc;
}

/// Returns whether it is possible to join the given letters
static int can_join(int c1, int c2)
{
  struct achar *a1 = find_achar(c1);
  struct achar *a2 = find_achar(c2);

  return a1 && a2 && (a1->initial || a1->medial) && (a2->final || a2->medial);
}

/// Check whether we are dealing with a character that could be regarded as an
/// Arabic combining character, need to check the character before this.
bool arabic_maycombine(int two)
  FUNC_ATTR_PURE
{
  if (p_arshape && !p_tbidi) {
    return two == a_ALEF_MADDA
           || two == a_ALEF_HAMZA_ABOVE
           || two == a_ALEF_HAMZA_BELOW
           || two == a_ALEF;
  }
  return false;
}

/// Check whether we are dealing with Arabic combining characters.
/// Returns false for negative values.
/// Note: these are NOT really composing characters!
///
/// @param one First character.
/// @param two Character just after "one".
bool arabic_combine(int one, int two)
  FUNC_ATTR_PURE
{
  if (one == a_LAM) {
    return arabic_maycombine(two);
  }
  return false;
}

/// @return  true if 'c' is an Arabic ISO-8859-6 character
///          (alphabet/number/punctuation)
static bool A_is_iso(int c)
{
  return find_achar(c) != NULL;
}

/// @return  true if 'c' is an Arabic 10646 (8859-6 or Form-B)
static bool A_is_ok(int c)
{
  return (A_is_iso(c) || c == a_BYTE_ORDER_MARK);
}

/// @return  true if 'c' is an Arabic 10646 (8859-6 or Form-B)
///          with some exceptions/exclusions
static bool A_is_valid(int c)
{
  return (A_is_ok(c) && c != a_HAMZA);
}

// Do Arabic shaping on character "c".  Returns the shaped character.
// in/out: "c1p" points to the first composing char for "c".
// in:     "prev_c"  is the previous character (not shaped)
// in:     "prev_c1" is the first composing char for the previous char
//          (not shaped)
// in:     "next_c"  is the next character (not shaped).
int arabic_shape(int c, int *c1p, int prev_c, int prev_c1, int next_c)
{
  // Deal only with Arabic character, pass back all others
  if (!A_is_ok(c)) {
    return c;
  }

  int curr_c;
  bool curr_laa = arabic_combine(c, *c1p);
  bool prev_laa = arabic_combine(prev_c, prev_c1);

  if (curr_laa) {
    if (A_is_valid(prev_c) && can_join(prev_c, a_LAM) && !prev_laa) {
      curr_c = chg_c_laa2f(*c1p);
    } else {
      curr_c = chg_c_laa2i(*c1p);
    }
    // Remove the composing character
    *c1p = 0;
  } else {
    struct achar *curr_a = find_achar(c);
    int backward_combine = !prev_laa && can_join(prev_c, c);
    int forward_combine = can_join(c, next_c);

    if (backward_combine) {
      if (forward_combine) {
        curr_c = (int)curr_a->medial;
      } else {
        curr_c = (int)curr_a->final;
      }
    } else {
      if (forward_combine) {
        curr_c = (int)curr_a->initial;
      } else {
        curr_c = (int)curr_a->isolated;
      }
    }
  }

  // Character missing from the table means using original character.
  if (curr_c == NUL) {
    curr_c = c;
  }

  // Return the shaped character
  return curr_c;
}
