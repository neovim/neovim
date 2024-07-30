/// mbyte.c: Code specifically for handling multi-byte characters.
/// Multibyte extensions partly by Sung-Hoon Baek
///
/// Strings internal to Nvim are always encoded as UTF-8 (thus the legacy
/// 'encoding' option is always "utf-8").
///
/// The cell width on the display needs to be determined from the character
/// value. Recognizing UTF-8 bytes is easy: 0xxx.xxxx is a single-byte char,
/// 10xx.xxxx is a trailing byte, 11xx.xxxx is a leading byte of a multi-byte
/// character. To make things complicated, up to six composing characters
/// are allowed. These are drawn on top of the first char. For most editing
/// the sequence of bytes with composing characters included is considered to
/// be one character.
///
/// UTF-8 is used everywhere in the core. This is in registers, text
/// manipulation, buffers, etc. Nvim core communicates with external plugins
/// and GUIs in this encoding.
///
/// The encoding of a file is specified with 'fileencoding'.  Conversion
/// is to be done when it's different from "utf-8".
///
/// Vim scripts may contain an ":scriptencoding" command. This has an effect
/// for some commands, like ":menutrans".

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <iconv.h>
#include <locale.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <utf8proc.h>
#include <uv.h>
#include <wctype.h>

#include "auto/config.h"
#include "nvim/arabic.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/iconv_defs.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/os.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

typedef struct {
  int rangeStart;
  int rangeEnd;
  int step;
  int offset;
} convertStruct;

struct interval {
  int first;
  int last;
};

// uncrustify:off
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.c.generated.h"
# include "unicode_tables.generated.h"
#endif
// uncrustify:on

static const char e_list_item_nr_is_not_list[]
  = N_("E1109: List item %d is not a List");
static const char e_list_item_nr_does_not_contain_3_numbers[]
  = N_("E1110: List item %d does not contain 3 numbers");
static const char e_list_item_nr_range_invalid[]
  = N_("E1111: List item %d range invalid");
static const char e_list_item_nr_cell_width_invalid[]
  = N_("E1112: List item %d cell width invalid");
static const char e_overlapping_ranges_for_nr[]
  = N_("E1113: Overlapping ranges for 0x%lx");
static const char e_only_values_of_0x80_and_higher_supported[]
  = N_("E1114: Only values of 0x80 and higher supported");

// To speed up BYTELEN(); keep a lookup table to quickly get the length in
// bytes of a UTF-8 character from the first byte of a UTF-8 string.  Bytes
// which are illegal when used as the first byte have a 1.  The NUL byte has
// length 1.
const uint8_t utf8len_tab[] = {
  // ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 0?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 1?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 2?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 3?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 4?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 5?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 6?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 7?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 8?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 9?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // A?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // B?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // C?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // D?
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  // E?
  4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1,  // F?
};

// Like utf8len_tab above, but using a zero for illegal lead bytes.
const uint8_t utf8len_tab_zero[] = {
  // ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 0?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 1?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 2?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 3?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 4?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 5?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 6?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // 7?
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 8?
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 9?
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // A?
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // B?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // C?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // D?
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  // E?
  4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 0, 0,  // F?
};

// Canonical encoding names and their properties.
// "iso-8859-n" is handled by enc_canonize() directly.
static struct
{   const char *name;   int prop;              int codepage; }
enc_canon_table[] = {
#define IDX_LATIN_1     0
  { "latin1",          ENC_8BIT + ENC_LATIN1,  1252 },
#define IDX_ISO_2       1
  { "iso-8859-2",      ENC_8BIT,               0 },
#define IDX_ISO_3       2
  { "iso-8859-3",      ENC_8BIT,               0 },
#define IDX_ISO_4       3
  { "iso-8859-4",      ENC_8BIT,               0 },
#define IDX_ISO_5       4
  { "iso-8859-5",      ENC_8BIT,               0 },
#define IDX_ISO_6       5
  { "iso-8859-6",      ENC_8BIT,               0 },
#define IDX_ISO_7       6
  { "iso-8859-7",      ENC_8BIT,               0 },
#define IDX_ISO_8       7
  { "iso-8859-8",      ENC_8BIT,               0 },
#define IDX_ISO_9       8
  { "iso-8859-9",      ENC_8BIT,               0 },
#define IDX_ISO_10      9
  { "iso-8859-10",     ENC_8BIT,               0 },
#define IDX_ISO_11      10
  { "iso-8859-11",     ENC_8BIT,               0 },
#define IDX_ISO_13      11
  { "iso-8859-13",     ENC_8BIT,               0 },
#define IDX_ISO_14      12
  { "iso-8859-14",     ENC_8BIT,               0 },
#define IDX_ISO_15      13
  { "iso-8859-15",     ENC_8BIT + ENC_LATIN9,  0 },
#define IDX_KOI8_R      14
  { "koi8-r",          ENC_8BIT,               0 },
#define IDX_KOI8_U      15
  { "koi8-u",          ENC_8BIT,               0 },
#define IDX_UTF8        16
  { "utf-8",           ENC_UNICODE,            0 },
#define IDX_UCS2        17
  { "ucs-2",           ENC_UNICODE + ENC_ENDIAN_B + ENC_2BYTE, 0 },
#define IDX_UCS2LE      18
  { "ucs-2le",         ENC_UNICODE + ENC_ENDIAN_L + ENC_2BYTE, 0 },
#define IDX_UTF16       19
  { "utf-16",          ENC_UNICODE + ENC_ENDIAN_B + ENC_2WORD, 0 },
#define IDX_UTF16LE     20
  { "utf-16le",        ENC_UNICODE + ENC_ENDIAN_L + ENC_2WORD, 0 },
#define IDX_UCS4        21
  { "ucs-4",           ENC_UNICODE + ENC_ENDIAN_B + ENC_4BYTE, 0 },
#define IDX_UCS4LE      22
  { "ucs-4le",         ENC_UNICODE + ENC_ENDIAN_L + ENC_4BYTE, 0 },

  // For debugging DBCS encoding on Unix.
#define IDX_DEBUG       23
  { "debug",           ENC_DBCS,               DBCS_DEBUG },
#define IDX_EUC_JP      24
  { "euc-jp",          ENC_DBCS,               DBCS_JPNU },
#define IDX_SJIS        25
  { "sjis",            ENC_DBCS,               DBCS_JPN },
#define IDX_EUC_KR      26
  { "euc-kr",          ENC_DBCS,               DBCS_KORU },
#define IDX_EUC_CN      27
  { "euc-cn",          ENC_DBCS,               DBCS_CHSU },
#define IDX_EUC_TW      28
  { "euc-tw",          ENC_DBCS,               DBCS_CHTU },
#define IDX_BIG5        29
  { "big5",            ENC_DBCS,               DBCS_CHT },

  // MS-DOS and MS-Windows codepages are included here, so that they can be
  // used on Unix too.  Most of them are similar to ISO-8859 encodings, but
  // not exactly the same.
#define IDX_CP437       30
  { "cp437",           ENC_8BIT,               437 },   // like iso-8859-1
#define IDX_CP737       31
  { "cp737",           ENC_8BIT,               737 },   // like iso-8859-7
#define IDX_CP775       32
  { "cp775",           ENC_8BIT,               775 },   // Baltic
#define IDX_CP850       33
  { "cp850",           ENC_8BIT,               850 },   // like iso-8859-4
#define IDX_CP852       34
  { "cp852",           ENC_8BIT,               852 },   // like iso-8859-1
#define IDX_CP855       35
  { "cp855",           ENC_8BIT,               855 },   // like iso-8859-2
#define IDX_CP857       36
  { "cp857",           ENC_8BIT,               857 },   // like iso-8859-5
#define IDX_CP860       37
  { "cp860",           ENC_8BIT,               860 },   // like iso-8859-9
#define IDX_CP861       38
  { "cp861",           ENC_8BIT,               861 },   // like iso-8859-1
#define IDX_CP862       39
  { "cp862",           ENC_8BIT,               862 },   // like iso-8859-1
#define IDX_CP863       40
  { "cp863",           ENC_8BIT,               863 },   // like iso-8859-8
#define IDX_CP865       41
  { "cp865",           ENC_8BIT,               865 },   // like iso-8859-1
#define IDX_CP866       42
  { "cp866",           ENC_8BIT,               866 },   // like iso-8859-5
#define IDX_CP869       43
  { "cp869",           ENC_8BIT,               869 },   // like iso-8859-7
#define IDX_CP874       44
  { "cp874",           ENC_8BIT,               874 },   // Thai
#define IDX_CP932       45
  { "cp932",           ENC_DBCS,               DBCS_JPN },
#define IDX_CP936       46
  { "cp936",           ENC_DBCS,               DBCS_CHS },
#define IDX_CP949       47
  { "cp949",           ENC_DBCS,               DBCS_KOR },
#define IDX_CP950       48
  { "cp950",           ENC_DBCS,               DBCS_CHT },
#define IDX_CP1250      49
  { "cp1250",          ENC_8BIT,               1250 },   // Czech, Polish, etc.
#define IDX_CP1251      50
  { "cp1251",          ENC_8BIT,               1251 },   // Cyrillic
  // cp1252 is considered to be equal to latin1
#define IDX_CP1253      51
  { "cp1253",          ENC_8BIT,               1253 },   // Greek
#define IDX_CP1254      52
  { "cp1254",          ENC_8BIT,               1254 },   // Turkish
#define IDX_CP1255      53
  { "cp1255",          ENC_8BIT,               1255 },   // Hebrew
#define IDX_CP1256      54
  { "cp1256",          ENC_8BIT,               1256 },   // Arabic
#define IDX_CP1257      55
  { "cp1257",          ENC_8BIT,               1257 },   // Baltic
#define IDX_CP1258      56
  { "cp1258",          ENC_8BIT,               1258 },   // Vietnamese

#define IDX_MACROMAN    57
  { "macroman",        ENC_8BIT + ENC_MACROMAN, 0 },      // Mac OS
#define IDX_HPROMAN8    58
  { "hp-roman8",       ENC_8BIT,               0 },       // HP Roman8
#define IDX_COUNT       59
};

// Aliases for encoding names.
static struct
{   const char *name; int canon; }
enc_alias_table[] = {
  { "ansi",            IDX_LATIN_1 },
  { "iso-8859-1",      IDX_LATIN_1 },
  { "latin2",          IDX_ISO_2 },
  { "latin3",          IDX_ISO_3 },
  { "latin4",          IDX_ISO_4 },
  { "cyrillic",        IDX_ISO_5 },
  { "arabic",          IDX_ISO_6 },
  { "greek",           IDX_ISO_7 },
  { "hebrew",          IDX_ISO_8 },
  { "latin5",          IDX_ISO_9 },
  { "turkish",         IDX_ISO_9 },   // ?
  { "latin6",          IDX_ISO_10 },
  { "nordic",          IDX_ISO_10 },  // ?
  { "thai",            IDX_ISO_11 },  // ?
  { "latin7",          IDX_ISO_13 },
  { "latin8",          IDX_ISO_14 },
  { "latin9",          IDX_ISO_15 },
  { "utf8",            IDX_UTF8 },
  { "unicode",         IDX_UCS2 },
  { "ucs2",            IDX_UCS2 },
  { "ucs2be",          IDX_UCS2 },
  { "ucs-2be",         IDX_UCS2 },
  { "ucs2le",          IDX_UCS2LE },
  { "utf16",           IDX_UTF16 },
  { "utf16be",         IDX_UTF16 },
  { "utf-16be",        IDX_UTF16 },
  { "utf16le",         IDX_UTF16LE },
  { "ucs4",            IDX_UCS4 },
  { "ucs4be",          IDX_UCS4 },
  { "ucs-4be",         IDX_UCS4 },
  { "ucs4le",          IDX_UCS4LE },
  { "utf32",           IDX_UCS4 },
  { "utf-32",          IDX_UCS4 },
  { "utf32be",         IDX_UCS4 },
  { "utf-32be",        IDX_UCS4 },
  { "utf32le",         IDX_UCS4LE },
  { "utf-32le",        IDX_UCS4LE },
  { "932",             IDX_CP932 },
  { "949",             IDX_CP949 },
  { "936",             IDX_CP936 },
  { "gbk",             IDX_CP936 },
  { "950",             IDX_CP950 },
  { "eucjp",           IDX_EUC_JP },
  { "unix-jis",        IDX_EUC_JP },
  { "ujis",            IDX_EUC_JP },
  { "shift-jis",       IDX_SJIS },
  { "pck",             IDX_SJIS },        // Sun: PCK
  { "euckr",           IDX_EUC_KR },
  { "5601",            IDX_EUC_KR },      // Sun: KS C 5601
  { "euccn",           IDX_EUC_CN },
  { "gb2312",          IDX_EUC_CN },
  { "euctw",           IDX_EUC_TW },
  { "japan",           IDX_EUC_JP },
  { "korea",           IDX_EUC_KR },
  { "prc",             IDX_EUC_CN },
  { "zh-cn",           IDX_EUC_CN },
  { "chinese",         IDX_EUC_CN },
  { "zh-tw",           IDX_EUC_TW },
  { "taiwan",          IDX_EUC_TW },
  { "cp950",           IDX_BIG5 },
  { "950",             IDX_BIG5 },
  { "mac",             IDX_MACROMAN },
  { "mac-roman",       IDX_MACROMAN },
  { NULL,              0 }
};

/// Find encoding "name" in the list of canonical encoding names.
/// Returns -1 if not found.
static int enc_canon_search(const char *name)
  FUNC_ATTR_PURE
{
  for (int i = 0; i < IDX_COUNT; i++) {
    if (strcmp(name, enc_canon_table[i].name) == 0) {
      return i;
    }
  }
  return -1;
}

// Find canonical encoding "name" in the list and return its properties.
// Returns 0 if not found.
int enc_canon_props(const char *name)
  FUNC_ATTR_PURE
{
  int i = enc_canon_search(name);
  if (i >= 0) {
    return enc_canon_table[i].prop;
  } else if (strncmp(name, "2byte-", 6) == 0) {
    return ENC_DBCS;
  } else if (strncmp(name, "8bit-", 5) == 0 || strncmp(name, "iso-8859-", 9) == 0) {
    return ENC_8BIT;
  }
  return 0;
}

// Return the size of the BOM for the current buffer:
// 0 - no BOM
// 2 - UCS-2 or UTF-16 BOM
// 4 - UCS-4 BOM
// 3 - UTF-8 BOM
int bomb_size(void)
  FUNC_ATTR_PURE
{
  int n = 0;

  if (curbuf->b_p_bomb && !curbuf->b_p_bin) {
    if (*curbuf->b_p_fenc == NUL
        || strcmp(curbuf->b_p_fenc, "utf-8") == 0) {
      n = 3;
    } else if (strncmp(curbuf->b_p_fenc, "ucs-2", 5) == 0
               || strncmp(curbuf->b_p_fenc, "utf-16", 6) == 0) {
      n = 2;
    } else if (strncmp(curbuf->b_p_fenc, "ucs-4", 5) == 0) {
      n = 4;
    }
  }
  return n;
}

// Remove all BOM from "s" by moving remaining text.
void remove_bom(char *s)
{
  char *p = s;

  while ((p = strchr(p, 0xef)) != NULL) {
    if ((uint8_t)p[1] == 0xbb && (uint8_t)p[2] == 0xbf) {
      STRMOVE(p, p + 3);
    } else {
      p++;
    }
  }
}

// Get class of pointer:
// 0 for blank or NUL
// 1 for punctuation
// 2 for an (ASCII) word character
// >2 for other word characters
int mb_get_class(const char *p)
  FUNC_ATTR_PURE
{
  return mb_get_class_tab(p, curbuf->b_chartab);
}

int mb_get_class_tab(const char *p, const uint64_t *const chartab)
  FUNC_ATTR_PURE
{
  if (MB_BYTE2LEN((uint8_t)p[0]) == 1) {
    if (p[0] == NUL || ascii_iswhite(p[0])) {
      return 0;
    }
    if (vim_iswordc_tab((uint8_t)p[0], chartab)) {
      return 2;
    }
    return 1;
  }
  return utf_class_tab(utf_ptr2char(p), chartab);
}

// Return true if "c" is in "table".
static bool intable(const struct interval *table, size_t n_items, int c)
  FUNC_ATTR_PURE
{
  assert(n_items > 0);
  // first quick check for Latin1 etc. characters
  if (c < table[0].first) {
    return false;
  }

  assert(n_items <= SIZE_MAX / 2);
  // binary search in table
  size_t bot = 0;
  size_t top = n_items;
  do {
    size_t mid = (bot + top) >> 1;
    if (table[mid].last < c) {
      bot = mid + 1;
    } else if (table[mid].first > c) {
      top = mid;
    } else {
      return true;
    }
  } while (top > bot);
  return false;
}

/// For UTF-8 character "c" return 2 for a double-width character, 1 for others.
/// Returns 4 or 6 for an unprintable character.
/// Is only correct for characters >= 0x80.
/// When p_ambw is "double", return 2 for a character with East Asian Width
/// class 'A'(mbiguous).
///
/// @note Tables `doublewidth` and `ambiguous` are generated by
///       gen_unicode_tables.lua, which must be manually invoked as needed.
int utf_char2cells(int c)
{
  if (c < 0x80) {
    return 1;
  }

  if (!vim_isprintc(c)) {
    assert(c <= 0xFFFF);
    // unprintable is displayed either as <xx> or <xxxx>
    return c > 0xFF ? 6 : 4;
  }

  int n = cw_value(c);
  if (n != 0) {
    return n;
  }

  if (intable(doublewidth, ARRAY_SIZE(doublewidth), c)) {
    return 2;
  }
  if (p_emoji && intable(emoji_wide, ARRAY_SIZE(emoji_wide), c)) {
    return 2;
  }
  if (*p_ambw == 'd' && intable(ambiguous, ARRAY_SIZE(ambiguous), c)) {
    return 2;
  }

  return 1;
}

/// Return the number of display cells character at "*p" occupies.
/// This doesn't take care of unprintable characters, use ptr2cells() for that.
int utf_ptr2cells(const char *p)
{
  // Need to convert to a character number.
  if ((uint8_t)(*p) >= 0x80) {
    int c = utf_ptr2char(p);
    // An illegal byte is displayed as <xx>.
    if (utf_ptr2len(p) == 1 || c == NUL) {
      return 4;
    }
    // If the char is ASCII it must be an overlong sequence.
    if (c < 0x80) {
      return char2cells(c);
    }
    return utf_char2cells(c);
  }
  return 1;
}

/// Convert a UTF-8 byte sequence to a character number.
/// Doesn't handle ascii! only multibyte and illegal sequences.
///
/// @param[in]  p      String to convert.
/// @param[in]  len    Length of the character in bytes, 0 or 1 if illegal.
///
/// @return Unicode codepoint. A negative value when the sequence is illegal.
int32_t utf_ptr2CharInfo_impl(uint8_t const *p, uintptr_t const len)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
// uint8_t is a reminder for clang to use smaller cmp
#define CHECK \
  do { \
    if (EXPECT((uint8_t)(cur & 0xC0U) != 0x80U, false)) { \
      return -1; \
    } \
  } while (0)

  static uint32_t const corrections[] = {
    (1U << 31),  // invalid - set invalid bits (safe to add as first 2 bytes
    (1U << 31),  // won't affect highest bit in normal ret)
    -(0x80U + (0xC0U << 6)),  // multibyte - subtract added UTF8 bits (1..10xxx and 10xxx)
    -(0x80U + (0x80U << 6) + (0xE0U << 12)),
    -(0x80U + (0x80U << 6) + (0x80U << 12) + (0xF0U << 18)),
    -(0x80U + (0x80U << 6) + (0x80U << 12) + (0x80U << 18) + (0xF8U << 24)),
    -(0x80U + (0x80U << 6) + (0x80U << 12) + (0x80U << 18) + (0x80U << 24)),  // + (0xFCU << 30)
  };

  // len is 0-6, but declared uintptr_t to avoid zeroing out upper bits
  uint32_t const corr = corrections[len];
  uint8_t cur;

  // reading second byte unconditionally, safe for invalid
  // as it cannot be the last byte, not safe for ascii
  uint32_t code_point = ((uint32_t)p[0] << 6) + (cur = p[1]);
  CHECK;
  if ((uint32_t)len < 3) {
    goto ret;  // len == 0, 1, 2
  }

  code_point = (code_point << 6) + (cur = p[2]);
  CHECK;
  if ((uint32_t)len == 3) {
    goto ret;
  }

  code_point = (code_point << 6) + (cur = p[3]);
  CHECK;
  if ((uint32_t)len == 4) {
    goto ret;
  }

  code_point = (code_point << 6) + (cur = p[4]);
  CHECK;
  if ((uint32_t)len == 5) {
    goto ret;
  }

  code_point = (code_point << 6) + (cur = p[5]);
  CHECK;
  // len == 6

ret:
  return (int32_t)(code_point + corr);

#undef CHECK
}

/// Like utf_ptr2cells(), but limit string length to "size".
/// For an empty string or truncated character returns 1.
int utf_ptr2cells_len(const char *p, int size)
{
  // Need to convert to a wide character.
  if (size > 0 && (uint8_t)(*p) >= 0x80) {
    if (utf_ptr2len_len(p, size) < utf8len_tab[(uint8_t)(*p)]) {
      return 1;        // truncated
    }
    int c = utf_ptr2char(p);
    // An illegal byte is displayed as <xx>.
    if (utf_ptr2len(p) == 1 || c == NUL) {
      return 4;
    }
    // If the char is ASCII it must be an overlong sequence.
    if (c < 0x80) {
      return char2cells(c);
    }
    return utf_char2cells(c);
  }
  return 1;
}

/// Calculate the number of cells occupied by string `str`.
///
/// @param str The source string, may not be NULL, must be a NUL-terminated
///            string.
/// @return The number of cells occupied by string `str`
size_t mb_string2cells(const char *str)
{
  size_t clen = 0;

  for (const char *p = str; *p != NUL; p += utfc_ptr2len(p)) {
    clen += (size_t)utf_ptr2cells(p);
  }

  return clen;
}

/// Get the number of cells occupied by string `str` with maximum length `size`
///
/// @param str The source string, may not be NULL, must be a NUL-terminated
///            string.
/// @param size maximum length of string. It will terminate on earlier NUL.
/// @return The number of cells occupied by string `str`
size_t mb_string2cells_len(const char *str, size_t size)
  FUNC_ATTR_NONNULL_ARG(1)
{
  size_t clen = 0;

  for (const char *p = str; *p != NUL && p < str + size;
       p += utfc_ptr2len_len(p, (int)size + (int)(p - str))) {
    clen += (size_t)utf_ptr2cells(p);
  }

  return clen;
}

/// Convert a UTF-8 byte sequence to a character number.
///
/// If the sequence is illegal or truncated by a NUL then the first byte is
/// returned.
/// For an overlong sequence this may return zero.
/// Does not include composing characters for obvious reasons.
///
/// @param[in]  p_in  String to convert.
///
/// @return Unicode codepoint or byte value.
int utf_ptr2char(const char *const p_in)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  uint8_t *p = (uint8_t *)p_in;

  uint32_t const v0 = p[0];
  if (EXPECT(v0 < 0x80U, true)) {  // Be quick for ASCII.
    return (int)v0;
  }

  const uint8_t len = utf8len_tab[v0];
  if (EXPECT(len < 2, false)) {
    return (int)v0;
  }

#define CHECK(v) \
  do { \
    if (EXPECT((uint8_t)((v) & 0xC0U) != 0x80U, false)) { \
      return (int)v0; \
    } \
  } while (0)
#define LEN_RETURN(len_v, result) \
  do { \
    if (len == (len_v)) { \
      return (int)(result); \
    } \
  } while (0)
#define S(s) ((uint32_t)0x80U << (s))

  uint32_t const v1 = p[1];
  CHECK(v1);
  LEN_RETURN(2, (v0 << 6) + v1 - ((0xC0U << 6) + S(0)));

  uint32_t const v2 = p[2];
  CHECK(v2);
  LEN_RETURN(3, (v0 << 12) + (v1 << 6) + v2 - ((0xE0U << 12) + S(6) + S(0)));

  uint32_t const v3 = p[3];
  CHECK(v3);
  LEN_RETURN(4, (v0 << 18) + (v1 << 12) + (v2 << 6) + v3
             - ((0xF0U << 18) + S(12) + S(6) + S(0)));

  uint32_t const v4 = p[4];
  CHECK(v4);
  LEN_RETURN(5, (v0 << 24) + (v1 << 18) + (v2 << 12) + (v3 << 6) + v4
             - ((0xF8U << 24) + S(18) + S(12) + S(6) + S(0)));

  uint32_t const v5 = p[5];
  CHECK(v5);
  // len == 6
  return (int)((v0 << 30) + (v1 << 24) + (v2 << 18) + (v3 << 12) + (v4 << 6) + v5
               // - (0xFCU << 30)
               - (S(24) + S(18) + S(12) + S(6) + S(0)));

#undef S
#undef CHECK
#undef LEN_RETURN
}

// Convert a UTF-8 byte sequence to a wide character.
// String is assumed to be terminated by NUL or after "n" bytes, whichever
// comes first.
// The function is safe in the sense that it never accesses memory beyond the
// first "n" bytes of "s".
//
// On success, returns decoded codepoint, advances "s" to the beginning of
// next character and decreases "n" accordingly.
//
// If end of string was reached, returns 0 and, if "n" > 0, advances "s" past
// NUL byte.
//
// If byte sequence is illegal or incomplete, returns -1 and does not advance
// "s".
static int utf_safe_read_char_adv(const char **s, size_t *n)
{
  if (*n == 0) {  // end of buffer
    return 0;
  }

  uint8_t k = utf8len_tab_zero[(uint8_t)(**s)];

  if (k == 1) {
    // ASCII character or NUL
    (*n)--;
    return (uint8_t)(*(*s)++);
  }

  if (k <= *n) {
    // We have a multibyte sequence and it isn't truncated by buffer
    // limits so utf_ptr2char() is safe to use. Or the first byte is
    // illegal (k=0), and it's also safe to use utf_ptr2char().
    int c = utf_ptr2char(*s);

    // On failure, utf_ptr2char() returns the first byte, so here we
    // check equality with the first byte. The only non-ASCII character
    // which equals the first byte of its own UTF-8 representation is
    // U+00C3 (UTF-8: 0xC3 0x83), so need to check that special case too.
    // It's safe even if n=1, else we would have k=2 > n.
    if (c != (int)((uint8_t)(**s)) || (c == 0xC3 && (uint8_t)(*s)[1] == 0x83)) {
      // byte sequence was successfully decoded
      *s += k;
      *n -= k;
      return c;
    }
  }

  // byte sequence is incomplete or illegal
  return -1;
}

// Get character at **pp and advance *pp to the next character.
// Note: composing characters are skipped!
int mb_ptr2char_adv(const char **const pp)
{
  int c = utf_ptr2char(*pp);
  *pp += utfc_ptr2len(*pp);
  return c;
}

// Get character at **pp and advance *pp to the next character.
// Note: composing characters are returned as separate characters.
int mb_cptr2char_adv(const char **pp)
{
  int c = utf_ptr2char(*pp);
  *pp += utf_ptr2len(*pp);
  return c;
}

/// Check if the character pointed to by "p2" is a composing character when it
/// comes after "p1".  For Arabic sometimes "ab" is replaced with "c", which
/// behaves like a composing character.
bool utf_composinglike(const char *p1, const char *p2)
{
  int c2 = utf_ptr2char(p2);
  if (utf_iscomposing(c2)) {
    return true;
  }
  if (!arabic_maycombine(c2)) {
    return false;
  }
  return arabic_combine(utf_ptr2char(p1), c2);
}

/// Check if the next character is a composing character when it
/// comes after the first. For Arabic sometimes "ab" is replaced with "c", which
/// behaves like a composing character.
/// returns false for negative values
bool utf_char_composinglike(int32_t const first, int32_t const next)
  FUNC_ATTR_PURE
{
  return utf_iscomposing(next) || arabic_combine(first, next);
}

/// Get the screen char at the beginning of a string
///
/// Caller is expected to check for things like unprintable chars etc
/// If first char in string is a composing char, prepend a space to display it correctly.
///
/// If "p" starts with an invalid sequence, zero is returned.
///
/// @param[out] firstc (required) The first codepoint of the screen char,
///                    or the first byte of an invalid sequence
///
/// @return the char
schar_T utfc_ptr2schar(const char *p, int *firstc)
  FUNC_ATTR_NONNULL_ALL
{
  int c = utf_ptr2char(p);
  *firstc = c;  // NOT optional, you are gonna need it
  bool first_compose = utf_iscomposing(c);
  size_t maxlen = MAX_SCHAR_SIZE - 1 - first_compose;
  size_t len = (size_t)utfc_ptr2len_len(p, (int)maxlen);

  if (len == 1 && (uint8_t)(*p) >= 0x80) {
    return 0;  // invalid sequence
  }

  return schar_from_buf_first(p, len, first_compose);
}

/// Get the screen char at the beginning of a string with length
///
/// Like utfc_ptr2schar but use no more than p[maxlen].
schar_T utfc_ptr2schar_len(const char *p, int maxlen, int *firstc)
  FUNC_ATTR_NONNULL_ALL
{
  assert(maxlen > 0);

  size_t len = (size_t)utf_ptr2len_len(p, maxlen);
  if (len > (size_t)maxlen || (len == 1 && (uint8_t)(*p) >= 0x80) || len == 0) {
    // invalid or truncated sequence
    *firstc = (uint8_t)(*p);
    return 0;
  }

  int c = utf_ptr2char(p);
  *firstc = c;
  bool first_compose = utf_iscomposing(c);
  maxlen = MIN(maxlen, MAX_SCHAR_SIZE - 1 - first_compose);
  len = (size_t)utfc_ptr2len_len(p, maxlen);

  return schar_from_buf_first(p, len, first_compose);
}

/// Caller must ensure there is space for `first_compose`
static schar_T schar_from_buf_first(const char *buf, size_t len, bool first_compose)
{
  if (first_compose) {
    char cbuf[MAX_SCHAR_SIZE];
    cbuf[0] = ' ';
    memcpy(cbuf + 1, buf, len);
    return schar_from_buf(cbuf, len + 1);
  } else {
    return schar_from_buf(buf, len);
  }
}

/// Get the length of a UTF-8 byte sequence representing a single codepoint
///
/// @param[in]  p  UTF-8 string.
///
/// @return Sequence length, 0 for empty string and 1 for non-UTF-8 byte
///         sequence.
int utf_ptr2len(const char *const p_in)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  uint8_t *p = (uint8_t *)p_in;
  if (*p == NUL) {
    return 0;
  }
  const int len = utf8len_tab[*p];
  for (int i = 1; i < len; i++) {
    if ((p[i] & 0xc0) != 0x80) {
      return 1;
    }
  }
  return len;
}

// Return length of UTF-8 character, obtained from the first byte.
// "b" must be between 0 and 255!
// Returns 1 for an invalid first byte value.
int utf_byte2len(int b)
{
  return utf8len_tab[b];
}

// Get the length of UTF-8 byte sequence "p[size]".  Does not include any
// following composing characters.
// Returns 1 for "".
// Returns 1 for an illegal byte sequence (also in incomplete byte seq.).
// Returns number > "size" for an incomplete byte sequence.
// Never returns zero.
int utf_ptr2len_len(const char *p, int size)
{
  int m;

  int len = utf8len_tab[(uint8_t)(*p)];
  if (len == 1) {
    return 1;           // NUL, ascii or illegal lead byte
  }
  if (len > size) {
    m = size;           // incomplete byte sequence.
  } else {
    m = len;
  }
  for (int i = 1; i < m; i++) {
    if ((p[i] & 0xc0) != 0x80) {
      return 1;
    }
  }
  return len;
}

/// Return the number of bytes occupied by a UTF-8 character in a string.
/// This includes following composing characters.
/// Returns zero for NUL.
int utfc_ptr2len(const char *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  uint8_t b0 = (uint8_t)(*p);

  if (b0 == NUL) {
    return 0;
  }
  if (b0 < 0x80 && (uint8_t)p[1] < 0x80) {  // be quick for ASCII
    return 1;
  }

  // Skip over first UTF-8 char, stopping at a NUL byte.
  int len = utf_ptr2len(p);

  // Check for illegal byte.
  if (len == 1 && b0 >= 0x80) {
    return 1;
  }

  // Check for composing characters.
  int prevlen = 0;
  while (true) {
    if ((uint8_t)p[len] < 0x80 || !utf_composinglike(p + prevlen, p + len)) {
      return len;
    }

    // Skip over composing char.
    prevlen = len;
    len += utf_ptr2len(p + len);
  }
}

/// Return the number of bytes the UTF-8 encoding of the character at "p[size]"
/// takes.  This includes following composing characters.
/// Returns 0 for an empty string.
/// Returns 1 for an illegal char or an incomplete byte sequence.
int utfc_ptr2len_len(const char *p, int size)
{
  if (size < 1 || *p == NUL) {
    return 0;
  }
  if ((uint8_t)p[0] < 0x80 && (size == 1 || (uint8_t)p[1] < 0x80)) {  // be quick for ASCII
    return 1;
  }

  // Skip over first UTF-8 char, stopping at a NUL byte.
  int len = utf_ptr2len_len(p, size);

  // Check for illegal byte and incomplete byte sequence.
  if ((len == 1 && (uint8_t)p[0] >= 0x80) || len > size) {
    return 1;
  }

  // Check for composing characters.  We can handle only the first six, but
  // skip all of them (otherwise the cursor would get stuck).
  int prevlen = 0;
  while (len < size) {
    if ((uint8_t)p[len] < 0x80) {
      break;
    }

    // Next character length should not go beyond size to ensure that
    // utf_composinglike(...) does not read beyond size.
    int len_next_char = utf_ptr2len_len(p + len, size - len);
    if (len_next_char > size - len) {
      break;
    }

    if (!utf_composinglike(p + prevlen, p + len)) {
      break;
    }

    // Skip over composing char
    prevlen = len;
    len += len_next_char;
  }
  return len;
}

/// Determine how many bytes certain unicode codepoint will occupy
int utf_char2len(const int c)
{
  if (c < 0x80) {
    return 1;
  } else if (c < 0x800) {
    return 2;
  } else if (c < 0x10000) {
    return 3;
  } else if (c < 0x200000) {
    return 4;
  } else if (c < 0x4000000) {
    return 5;
  } else {
    return 6;
  }
}

/// Convert Unicode character to UTF-8 string
///
/// @param c         character to convert to UTF-8 string in \p buf
/// @param[out] buf  UTF-8 string generated from \p c, does not add \0
///                  must have room for at least 6 bytes
/// @return Number of bytes (1-6).
int utf_char2bytes(const int c, char *const buf)
{
  if (c < 0x80) {  // 7 bits
    buf[0] = (char)c;
    return 1;
  } else if (c < 0x800) {  // 11 bits
    buf[0] = (char)(0xc0 + ((unsigned)c >> 6));
    buf[1] = (char)(0x80 + ((unsigned)c & 0x3f));
    return 2;
  } else if (c < 0x10000) {  // 16 bits
    buf[0] = (char)(0xe0 + ((unsigned)c >> 12));
    buf[1] = (char)(0x80 + (((unsigned)c >> 6) & 0x3f));
    buf[2] = (char)(0x80 + ((unsigned)c & 0x3f));
    return 3;
  } else if (c < 0x200000) {  // 21 bits
    buf[0] = (char)(0xf0 + ((unsigned)c >> 18));
    buf[1] = (char)(0x80 + (((unsigned)c >> 12) & 0x3f));
    buf[2] = (char)(0x80 + (((unsigned)c >> 6) & 0x3f));
    buf[3] = (char)(0x80 + ((unsigned)c & 0x3f));
    return 4;
  } else if (c < 0x4000000) {  // 26 bits
    buf[0] = (char)(0xf8 + ((unsigned)c >> 24));
    buf[1] = (char)(0x80 + (((unsigned)c >> 18) & 0x3f));
    buf[2] = (char)(0x80 + (((unsigned)c >> 12) & 0x3f));
    buf[3] = (char)(0x80 + (((unsigned)c >> 6) & 0x3f));
    buf[4] = (char)(0x80 + ((unsigned)c & 0x3f));
    return 5;
  } else {  // 31 bits
    buf[0] = (char)(0xfc + ((unsigned)c >> 30));
    buf[1] = (char)(0x80 + (((unsigned)c >> 24) & 0x3f));
    buf[2] = (char)(0x80 + (((unsigned)c >> 18) & 0x3f));
    buf[3] = (char)(0x80 + (((unsigned)c >> 12) & 0x3f));
    buf[4] = (char)(0x80 + (((unsigned)c >> 6) & 0x3f));
    buf[5] = (char)(0x80 + ((unsigned)c & 0x3f));
    return 6;
  }
}

/// Return true if "c" is a composing UTF-8 character.
/// This means it will be drawn on top of the preceding character.
/// Based on code from Markus Kuhn.
/// Returns false for negative values.
bool utf_iscomposing(int c)
{
  return intable(combining, ARRAY_SIZE(combining), c);
}

#ifdef __SSE2__

# include <emmintrin.h>

// Return true for characters that can be displayed in a normal way.
// Only for characters of 0x100 and above!
bool utf_printable(int c)
  FUNC_ATTR_CONST
{
  if (c < 0x180B || c > 0xFFFF) {
    return c != 0x70F;
  }

# define L(v) ((int16_t)((v) - 1))  // lower bound (exclusive)
# define H(v) ((int16_t)(v))  // upper bound (inclusive)

  // Boundaries of unprintable characters.
  // Some values are negative when converted to int16_t.
  // Ranges must not wrap around when converted to int16_t.
  __m128i const lo = _mm_setr_epi16(L(0x180b), L(0x200b), L(0x202a), L(0x2060),
                                    L(0xd800), L(0xfeff), L(0xfff9), L(0xfffe));

  __m128i const hi = _mm_setr_epi16(H(0x180e), H(0x200f), H(0x202e), H(0x206f),
                                    H(0xdfff), H(0xfeff), H(0xfffb), H(0xffff));

# undef L
# undef H

  __m128i value = _mm_set1_epi16((int16_t)c);

  // Using _mm_cmplt_epi16() is less optimal, since it would require
  // swapping operands (sse2 only has cmpgt instruction),
  // and only the second operand can be a memory location.

  // Character is printable when it is above/below both bounds of each range
  // (corresponding bits in both masks are equal).
  return _mm_movemask_epi8(_mm_cmpgt_epi16(value, lo))
         == _mm_movemask_epi8(_mm_cmpgt_epi16(value, hi));
}

#else

// Return true for characters that can be displayed in a normal way.
// Only for characters of 0x100 and above!
bool utf_printable(int c)
  FUNC_ATTR_PURE
{
  // Sorted list of non-overlapping intervals.
  // 0xd800-0xdfff is reserved for UTF-16, actually illegal.
  static struct interval nonprint[] = {
    { 0x070f, 0x070f }, { 0x180b, 0x180e }, { 0x200b, 0x200f }, { 0x202a, 0x202e },
    { 0x2060, 0x206f }, { 0xd800, 0xdfff }, { 0xfeff, 0xfeff }, { 0xfff9, 0xfffb },
    { 0xfffe, 0xffff }
  };

  return !intable(nonprint, ARRAY_SIZE(nonprint), c);
}

#endif

// Get class of a Unicode character.
// 0: white space
// 1: punctuation
// 2 or bigger: some class of word character.
int utf_class(const int c)
{
  return utf_class_tab(c, curbuf->b_chartab);
}

int utf_class_tab(const int c, const uint64_t *const chartab)
  FUNC_ATTR_PURE
{
  // sorted list of non-overlapping intervals
  static struct clinterval {
    unsigned first;
    unsigned last;
    unsigned cls;
  } classes[] = {
    { 0x037e, 0x037e, 1 },              // Greek question mark
    { 0x0387, 0x0387, 1 },              // Greek ano teleia
    { 0x055a, 0x055f, 1 },              // Armenian punctuation
    { 0x0589, 0x0589, 1 },              // Armenian full stop
    { 0x05be, 0x05be, 1 },
    { 0x05c0, 0x05c0, 1 },
    { 0x05c3, 0x05c3, 1 },
    { 0x05f3, 0x05f4, 1 },
    { 0x060c, 0x060c, 1 },
    { 0x061b, 0x061b, 1 },
    { 0x061f, 0x061f, 1 },
    { 0x066a, 0x066d, 1 },
    { 0x06d4, 0x06d4, 1 },
    { 0x0700, 0x070d, 1 },              // Syriac punctuation
    { 0x0964, 0x0965, 1 },
    { 0x0970, 0x0970, 1 },
    { 0x0df4, 0x0df4, 1 },
    { 0x0e4f, 0x0e4f, 1 },
    { 0x0e5a, 0x0e5b, 1 },
    { 0x0f04, 0x0f12, 1 },
    { 0x0f3a, 0x0f3d, 1 },
    { 0x0f85, 0x0f85, 1 },
    { 0x104a, 0x104f, 1 },              // Myanmar punctuation
    { 0x10fb, 0x10fb, 1 },              // Georgian punctuation
    { 0x1361, 0x1368, 1 },              // Ethiopic punctuation
    { 0x166d, 0x166e, 1 },              // Canadian Syl. punctuation
    { 0x1680, 0x1680, 0 },
    { 0x169b, 0x169c, 1 },
    { 0x16eb, 0x16ed, 1 },
    { 0x1735, 0x1736, 1 },
    { 0x17d4, 0x17dc, 1 },              // Khmer punctuation
    { 0x1800, 0x180a, 1 },              // Mongolian punctuation
    { 0x2000, 0x200b, 0 },              // spaces
    { 0x200c, 0x2027, 1 },              // punctuation and symbols
    { 0x2028, 0x2029, 0 },
    { 0x202a, 0x202e, 1 },              // punctuation and symbols
    { 0x202f, 0x202f, 0 },
    { 0x2030, 0x205e, 1 },              // punctuation and symbols
    { 0x205f, 0x205f, 0 },
    { 0x2060, 0x27ff, 1 },              // punctuation and symbols
    { 0x2070, 0x207f, 0x2070 },         // superscript
    { 0x2080, 0x2094, 0x2080 },         // subscript
    { 0x20a0, 0x27ff, 1 },              // all kinds of symbols
    { 0x2800, 0x28ff, 0x2800 },         // braille
    { 0x2900, 0x2998, 1 },              // arrows, brackets, etc.
    { 0x29d8, 0x29db, 1 },
    { 0x29fc, 0x29fd, 1 },
    { 0x2e00, 0x2e7f, 1 },              // supplemental punctuation
    { 0x3000, 0x3000, 0 },              // ideographic space
    { 0x3001, 0x3020, 1 },              // ideographic punctuation
    { 0x3030, 0x3030, 1 },
    { 0x303d, 0x303d, 1 },
    { 0x3040, 0x309f, 0x3040 },         // Hiragana
    { 0x30a0, 0x30ff, 0x30a0 },         // Katakana
    { 0x3300, 0x9fff, 0x4e00 },         // CJK Ideographs
    { 0xac00, 0xd7a3, 0xac00 },         // Hangul Syllables
    { 0xf900, 0xfaff, 0x4e00 },         // CJK Ideographs
    { 0xfd3e, 0xfd3f, 1 },
    { 0xfe30, 0xfe6b, 1 },              // punctuation forms
    { 0xff00, 0xff0f, 1 },              // half/fullwidth ASCII
    { 0xff1a, 0xff20, 1 },              // half/fullwidth ASCII
    { 0xff3b, 0xff40, 1 },              // half/fullwidth ASCII
    { 0xff5b, 0xff65, 1 },              // half/fullwidth ASCII
    { 0x1d000, 0x1d24f, 1 },            // Musical notation
    { 0x1d400, 0x1d7ff, 1 },            // Mathematical Alphanumeric Symbols
    { 0x1f000, 0x1f2ff, 1 },            // Game pieces; enclosed characters
    { 0x1f300, 0x1f9ff, 1 },            // Many symbol blocks
    { 0x20000, 0x2a6df, 0x4e00 },       // CJK Ideographs
    { 0x2a700, 0x2b73f, 0x4e00 },       // CJK Ideographs
    { 0x2b740, 0x2b81f, 0x4e00 },       // CJK Ideographs
    { 0x2f800, 0x2fa1f, 0x4e00 },       // CJK Ideographs
  };
  int bot = 0;
  int top = ARRAY_SIZE(classes) - 1;

  // First quick check for Latin1 characters, use 'iskeyword'.
  if (c < 0x100) {
    if (c == ' ' || c == '\t' || c == NUL || c == 0xa0) {
      return 0;             // blank
    }
    if (vim_iswordc_tab(c, chartab)) {
      return 2;             // word character
    }
    return 1;               // punctuation
  }

  // emoji
  if (intable(emoji_all, ARRAY_SIZE(emoji_all), c)) {
    return 3;
  }

  // binary search in table
  while (top >= bot) {
    int mid = (bot + top) / 2;
    if (classes[mid].last < (unsigned)c) {
      bot = mid + 1;
    } else if (classes[mid].first > (unsigned)c) {
      top = mid - 1;
    } else {
      return (int)classes[mid].cls;
    }
  }

  // most other characters are "word" characters
  return 2;
}

bool utf_ambiguous_width(int c)
{
  return c >= 0x80 && (intable(ambiguous, ARRAY_SIZE(ambiguous), c)
                       || intable(emoji_all, ARRAY_SIZE(emoji_all), c));
}

// Generic conversion function for case operations.
// Return the converted equivalent of "a", which is a UCS-4 character.  Use
// the given conversion "table".  Uses binary search on "table".
static int utf_convert(int a, const convertStruct *const table, size_t n_items)
{
  // indices into table
  size_t start = 0;
  size_t end = n_items;
  while (start < end) {
    // need to search further
    size_t mid = (end + start) / 2;
    if (table[mid].rangeEnd < a) {
      start = mid + 1;
    } else {
      end = mid;
    }
  }
  if (start < n_items
      && table[start].rangeStart <= a
      && a <= table[start].rangeEnd
      && (a - table[start].rangeStart) % table[start].step == 0) {
    return a + table[start].offset;
  }
  return a;
}

// Return the folded-case equivalent of "a", which is a UCS-4 character.  Uses
// simple case folding.
int utf_fold(int a)
{
  if (a < 0x80) {
    // be fast for ASCII
    return a >= 0x41 && a <= 0x5a ? a + 32 : a;
  }
  return utf_convert(a, foldCase, ARRAY_SIZE(foldCase));
}

// Vim's own character class functions.  These exist because many library
// islower()/toupper() etc. do not work properly: they crash when used with
// invalid values or can't handle latin1 when the locale is C.
// Speed is most important here.

/// Return the upper-case equivalent of "a", which is a UCS-4 character.  Use
/// simple case folding.
int mb_toupper(int a)
{
  // If 'casemap' contains "keepascii" use ASCII style toupper().
  if (a < 128 && (cmp_flags & CMP_KEEPASCII)) {
    return TOUPPER_ASC(a);
  }

  if (!(cmp_flags & CMP_INTERNAL)) {
    return (int)towupper((wint_t)a);
  }

  // For characters below 128 use locale sensitive toupper().
  if (a < 128) {
    return TOUPPER_LOC(a);
  }

  return utf8proc_toupper(a);
}

bool mb_islower(int a)
{
  return mb_toupper(a) != a;
}

/// Return the lower-case equivalent of "a", which is a UCS-4 character.  Use
/// simple case folding.
int mb_tolower(int a)
{
  // If 'casemap' contains "keepascii" use ASCII style tolower().
  if (a < 128 && (cmp_flags & CMP_KEEPASCII)) {
    return TOLOWER_ASC(a);
  }

  if (!(cmp_flags & CMP_INTERNAL)) {
    return (int)towlower((wint_t)a);
  }

  // For characters below 128 use locale sensitive tolower().
  if (a < 128) {
    return TOLOWER_LOC(a);
  }

  return utf8proc_tolower(a);
}

bool mb_isupper(int a)
{
  return mb_tolower(a) != a;
}

bool mb_isalpha(int a)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return mb_islower(a) || mb_isupper(a);
}

int utf_strnicmp(const char *s1, const char *s2, size_t n1, size_t n2)
{
  int c1, c2;
  char buffer[6];

  while (true) {
    c1 = utf_safe_read_char_adv(&s1, &n1);
    c2 = utf_safe_read_char_adv(&s2, &n2);

    if (c1 <= 0 || c2 <= 0) {
      break;
    }

    if (c1 == c2) {
      continue;
    }

    int cdiff = utf_fold(c1) - utf_fold(c2);
    if (cdiff != 0) {
      return cdiff;
    }
  }

  // some string ended or has an incomplete/illegal character sequence

  if (c1 == 0 || c2 == 0) {
    // some string ended. shorter string is smaller
    if (c1 == 0 && c2 == 0) {
      return 0;
    }
    return c1 == 0 ? -1 : 1;
  }

  // Continue with bytewise comparison to produce some result that
  // would make comparison operations involving this function transitive.
  //
  // If only one string had an error, comparison should be made with
  // folded version of the other string. In this case it is enough
  // to fold just one character to determine the result of comparison.

  if (c1 != -1 && c2 == -1) {
    n1 = (size_t)utf_char2bytes(utf_fold(c1), buffer);
    s1 = buffer;
  } else if (c2 != -1 && c1 == -1) {
    n2 = (size_t)utf_char2bytes(utf_fold(c2), buffer);
    s2 = buffer;
  }

  while (n1 > 0 && n2 > 0 && *s1 != NUL && *s2 != NUL) {
    int cdiff = (int)((uint8_t)(*s1)) - (int)((uint8_t)(*s2));
    if (cdiff != 0) {
      return cdiff;
    }

    s1++;
    s2++;
    n1--;
    n2--;
  }

  if (n1 > 0 && *s1 == NUL) {
    n1 = 0;
  }
  if (n2 > 0 && *s2 == NUL) {
    n2 = 0;
  }

  if (n1 == 0 && n2 == 0) {
    return 0;
  }
  return n1 == 0 ? -1 : 1;
}

#ifdef MSWIN
# ifndef CP_UTF8
#  define CP_UTF8 65001  // magic number from winnls.h
# endif

/// Converts string from UTF-8 to UTF-16.
///
/// @param utf8  UTF-8 string.
/// @param utf8len  Length of `utf8`. May be -1 if `utf8` is NUL-terminated.
/// @param utf16[out,allocated]  NUL-terminated UTF-16 string, or NULL on error
/// @return 0 on success, or libuv error code
int utf8_to_utf16(const char *utf8, int utf8len, wchar_t **utf16)
  FUNC_ATTR_NONNULL_ALL
{
  // Compute the length needed for the converted UTF-16 string.
  int bufsize = MultiByteToWideChar(CP_UTF8,
                                    0,     // dwFlags: must be 0 for UTF-8
                                    utf8,  // -1: process up to NUL
                                    utf8len,
                                    NULL,
                                    0);    // 0: get length, don't convert
  if (bufsize == 0) {
    *utf16 = NULL;
    return uv_translate_sys_error(GetLastError());
  }

  // Allocate the destination buffer adding an extra byte for the terminating
  // NULL. If `utf8len` is not -1 MultiByteToWideChar will not add it, so
  // we do it ourselves always, just in case.
  *utf16 = xmalloc(sizeof(wchar_t) * (bufsize + 1));

  // Convert to UTF-16.
  bufsize = MultiByteToWideChar(CP_UTF8, 0, utf8, utf8len, *utf16, bufsize);
  if (bufsize == 0) {
    XFREE_CLEAR(*utf16);
    return uv_translate_sys_error(GetLastError());
  }

  (*utf16)[bufsize] = L'\0';
  return 0;
}

/// Converts string from UTF-16 to UTF-8.
///
/// @param utf16  UTF-16 string.
/// @param utf16len  Length of `utf16`. May be -1 if `utf16` is NUL-terminated.
/// @param utf8[out,allocated]  NUL-terminated UTF-8 string, or NULL on error
/// @return 0 on success, or libuv error code
int utf16_to_utf8(const wchar_t *utf16, int utf16len, char **utf8)
  FUNC_ATTR_NONNULL_ALL
{
  // Compute the space needed for the converted UTF-8 string.
  DWORD bufsize = WideCharToMultiByte(CP_UTF8,
                                      0,
                                      utf16,
                                      utf16len,
                                      NULL,
                                      0,
                                      NULL,
                                      NULL);
  if (bufsize == 0) {
    *utf8 = NULL;
    return uv_translate_sys_error(GetLastError());
  }

  // Allocate the destination buffer adding an extra byte for the terminating
  // NULL. If `utf16len` is not -1 WideCharToMultiByte will not add it, so
  // we do it ourselves always, just in case.
  *utf8 = xmalloc(bufsize + 1);

  // Convert to UTF-8.
  bufsize = WideCharToMultiByte(CP_UTF8,
                                0,
                                utf16,
                                utf16len,
                                *utf8,
                                bufsize,
                                NULL,
                                NULL);
  if (bufsize == 0) {
    XFREE_CLEAR(*utf8);
    return uv_translate_sys_error(GetLastError());
  }

  (*utf8)[bufsize] = NUL;
  return 0;
}

#endif

/// Measure the length of a string in corresponding UTF-32 and UTF-16 units.
///
/// Invalid UTF-8 bytes, or embedded surrogates, count as one code point/unit
/// each.
///
/// The out parameters are incremented. This is used to measure the size of
/// a buffer region consisting of multiple line segments.
///
/// @param s the string
/// @param len maximum length (an earlier NUL terminates)
/// @param[out] codepoints incremented with UTF-32 code point size
/// @param[out] codeunits incremented with UTF-16 code unit size
void mb_utflen(const char *s, size_t len, size_t *codepoints, size_t *codeunits)
  FUNC_ATTR_NONNULL_ALL
{
  size_t count = 0;
  size_t extra = 0;
  size_t clen;
  for (size_t i = 0; i < len; i += clen) {
    clen = (size_t)utf_ptr2len_len(s + i, (int)(len - i));
    // NB: gets the byte value of invalid sequence bytes.
    // we only care whether the char fits in the BMP or not
    int c = (clen > 1) ? utf_ptr2char(s + i) : (uint8_t)s[i];
    count++;
    if (c > 0xFFFF) {
      extra++;
    }
  }
  *codepoints += count;
  *codeunits += count + extra;
}

ssize_t mb_utf_index_to_bytes(const char *s, size_t len, size_t index, bool use_utf16_units)
  FUNC_ATTR_NONNULL_ALL
{
  size_t count = 0;
  size_t clen;
  if (index == 0) {
    return 0;
  }
  for (size_t i = 0; i < len; i += clen) {
    clen = (size_t)utf_ptr2len_len(s + i, (int)(len - i));
    // NB: gets the byte value of invalid sequence bytes.
    // we only care whether the char fits in the BMP or not
    int c = (clen > 1) ? utf_ptr2char(s + i) : (uint8_t)s[i];
    count++;
    if (use_utf16_units && c > 0xFFFF) {
      count++;
    }
    if (count >= index) {
      return (ssize_t)(i + clen);
    }
  }
  return -1;
}

/// Version of strnicmp() that handles multi-byte characters.
/// Needed for Big5, Shift-JIS and UTF-8 encoding.  Other DBCS encodings can
/// probably use strnicmp(), because there are no ASCII characters in the
/// second byte.
///
/// @return  zero if s1 and s2 are equal (ignoring case), the difference between
///          two characters otherwise.
int mb_strnicmp(const char *s1, const char *s2, const size_t nn)
{
  return utf_strnicmp(s1, s2, nn, nn);
}

/// Compare strings case-insensitively
///
/// @note We need to call mb_stricmp() even when we aren't dealing with
///       a multi-byte encoding because mb_stricmp() takes care of all ASCII and
///       non-ascii encodings, including characters with umlauts in latin1,
///       etc., while STRICMP() only handles the system locale version, which
///       often does not handle non-ascii properly.
///
/// @param[in]  s1  First string to compare, not more then #MAXCOL characters.
/// @param[in]  s2  Second string to compare, not more then #MAXCOL characters.
///
/// @return 0 if strings are equal, <0 if s1 < s2, >0 if s1 > s2.
int mb_stricmp(const char *s1, const char *s2)
{
  return mb_strnicmp(s1, s2, MAXCOL);
}

// "g8": show bytes of the UTF-8 char under the cursor.  Doesn't matter what
// 'encoding' has been set to.
void show_utf8(void)
{
  // Get the byte length of the char under the cursor, including composing
  // characters.
  char *line = get_cursor_pos_ptr();
  int len = utfc_ptr2len(line);
  if (len == 0) {
    msg("NUL", 0);
    return;
  }

  size_t rlen = 0;
  int clen = 0;
  for (int i = 0; i < len; i++) {
    if (clen == 0) {
      // start of (composing) character, get its length
      if (i > 0) {
        STRCPY(IObuff + rlen, "+ ");
        rlen += 2;
      }
      clen = utf_ptr2len(line + i);
    }
    assert(IOSIZE > rlen);
    snprintf(IObuff + rlen, IOSIZE - rlen, "%02x ",
             (line[i] == NL) ? NUL : (uint8_t)line[i]);  // NUL is stored as NL
    clen--;
    rlen += strlen(IObuff + rlen);
    if (rlen > IOSIZE - 20) {
      break;
    }
  }

  msg(IObuff, 0);
}

/// Return offset from "p" to the start of a character, including composing characters.
/// "base" must be the start of the string, which must be NUL terminated.
/// If "p" points to the NUL at the end of the string return 0.
/// Returns 0 when already at the first byte of a character.
int utf_head_off(const char *base_in, const char *p_in)
{
  if ((uint8_t)(*p_in) < 0x80) {              // be quick for ASCII
    return 0;
  }

  const uint8_t *base = (uint8_t *)base_in;
  const uint8_t *p = (uint8_t *)p_in;

  // Skip backwards over trailing bytes: 10xx.xxxx
  // Skip backwards again if on a composing char.
  const uint8_t *q;
  for (q = p;; q--) {
    // Move s to the last byte of this char.
    const uint8_t *s;
    for (s = q; (s[1] & 0xc0) == 0x80; s++) {}

    // Move q to the first byte of this char.
    while (q > base && (*q & 0xc0) == 0x80) {
      q--;
    }
    // Check for illegal sequence. Do allow an illegal byte after where we
    // started.
    int len = utf8len_tab[*q];
    if (len != (int)(s - q + 1) && len != (int)(p - q + 1)) {
      return 0;
    }

    if (q <= base) {
      break;
    }

    int c = utf_ptr2char((char *)q);
    if (utf_iscomposing(c)) {
      continue;
    }

    if (arabic_maycombine(c)) {
      // Advance to get a sneak-peak at the next char
      const uint8_t *j = q;
      j--;
      // Move j to the first byte of this char.
      while (j > base && (*j & 0xc0) == 0x80) {
        j--;
      }
      if (arabic_combine(utf_ptr2char((char *)j), c)) {
        continue;
      }
    }
    break;
  }

  return (int)(p - q);
}

// Whether space is NOT allowed before/after 'c'.
bool utf_eat_space(int cc)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (cc >= 0x2000 && cc <= 0x206F)   // General punctuations
         || (cc >= 0x2e00 && cc <= 0x2e7f)   // Supplemental punctuations
         || (cc >= 0x3000 && cc <= 0x303f)   // CJK symbols and punctuations
         || (cc >= 0xff01 && cc <= 0xff0f)   // Full width ASCII punctuations
         || (cc >= 0xff1a && cc <= 0xff20)   // ..
         || (cc >= 0xff3b && cc <= 0xff40)   // ..
         || (cc >= 0xff5b && cc <= 0xff65);  // ..
}

// Whether line break is allowed before "cc".
bool utf_allow_break_before(int cc)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  static const int BOL_prohibition_punct[] = {
    '!',
    '%',
    ')',
    ',',
    ':',
    ';',
    '>',
    '?',
    ']',
    '}',
    0x2019,  // ’ right single quotation mark
    0x201d,  // ” right double quotation mark
    0x2020,  // † dagger
    0x2021,  // ‡ double dagger
    0x2026,  // … horizontal ellipsis
    0x2030,  // ‰ per mille sign
    0x2031,  // ‱ per the thousand sign
    0x203c,  // ‼ double exclamation mark
    0x2047,  // ⁇ double question mark
    0x2048,  // ⁈ question exclamation mark
    0x2049,  // ⁉ exclamation question mark
    0x2103,  // ℃ degree celsius
    0x2109,  // ℉ degree fahrenheit
    0x3001,  // 、 ideographic comma
    0x3002,  // 。 ideographic full stop
    0x3009,  // 〉 right angle bracket
    0x300b,  // 》 right double angle bracket
    0x300d,  // 」 right corner bracket
    0x300f,  // 』 right white corner bracket
    0x3011,  // 】 right black lenticular bracket
    0x3015,  // 〕 right tortoise shell bracket
    0x3017,  // 〗 right white lenticular bracket
    0x3019,  // 〙 right white tortoise shell bracket
    0x301b,  // 〛 right white square bracket
    0xff01,  // ！ fullwidth exclamation mark
    0xff09,  // ） fullwidth right parenthesis
    0xff0c,  // ， fullwidth comma
    0xff0e,  // ． fullwidth full stop
    0xff1a,  // ： fullwidth colon
    0xff1b,  // ； fullwidth semicolon
    0xff1f,  // ？ fullwidth question mark
    0xff3d,  // ］ fullwidth right square bracket
    0xff5d,  // ｝ fullwidth right curly bracket
  };

  int first = 0;
  int last = ARRAY_SIZE(BOL_prohibition_punct) - 1;

  while (first < last) {
    const int mid = (first + last) / 2;

    if (cc == BOL_prohibition_punct[mid]) {
      return false;
    } else if (cc > BOL_prohibition_punct[mid]) {
      first = mid + 1;
    } else {
      last = mid - 1;
    }
  }

  return cc != BOL_prohibition_punct[first];
}

// Whether line break is allowed after "cc".
bool utf_allow_break_after(int cc)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  static const int EOL_prohibition_punct[] = {
    '(',
    '<',
    '[',
    '`',
    '{',
    // 0x2014,  // — em dash
    0x2018,     // ‘ left single quotation mark
    0x201c,     // “ left double quotation mark
    // 0x2053,  // ～ swung dash
    0x3008,     // 〈 left angle bracket
    0x300a,     // 《 left double angle bracket
    0x300c,     // 「 left corner bracket
    0x300e,     // 『 left white corner bracket
    0x3010,     // 【 left black lenticular bracket
    0x3014,     // 〔 left tortoise shell bracket
    0x3016,     // 〖 left white lenticular bracket
    0x3018,     // 〘 left white tortoise shell bracket
    0x301a,     // 〚 left white square bracket
    0xff08,     // （ fullwidth left parenthesis
    0xff3b,     // ［ fullwidth left square bracket
    0xff5b,     // ｛ fullwidth left curly bracket
  };

  int first = 0;
  int last = ARRAY_SIZE(EOL_prohibition_punct) - 1;

  while (first < last) {
    const int mid = (first + last)/2;

    if (cc == EOL_prohibition_punct[mid]) {
      return false;
    } else if (cc > EOL_prohibition_punct[mid]) {
      first = mid + 1;
    } else {
      last = mid - 1;
    }
  }

  return cc != EOL_prohibition_punct[first];
}

// Whether line break is allowed between "cc" and "ncc".
bool utf_allow_break(int cc, int ncc)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  // don't break between two-letter punctuations
  if (cc == ncc
      && (cc == 0x2014         // em dash
          || cc == 0x2026)) {  // horizontal ellipsis
    return false;
  }
  return utf_allow_break_after(cc) && utf_allow_break_before(ncc);
}

/// Copy a character, advancing the pointers
///
/// @param[in,out]  fp  Source of the character to copy.
/// @param[in,out]  tp  Destination to copy to.
void mb_copy_char(const char **const fp, char **const tp)
{
  const size_t l = (size_t)utfc_ptr2len(*fp);

  memmove(*tp, *fp, l);
  *tp += l;
  *fp += l;
}

/// Return the offset from "p" to the first byte of a character.  When "p" is
/// at the start of a character 0 is returned, otherwise the offset to the next
/// character.  Can start anywhere in a stream of bytes.
int mb_off_next(const char *base, const char *p)
{
  int head_off = utf_head_off(base, p);

  if (head_off == 0) {
    return 0;
  }

  return utfc_ptr2len(p - head_off) - head_off;
}

/// Returns the offset in bytes from "p_in" to the first and one-past-end bytes
/// of the codepoint it points to.
/// "p_in" can point anywhere in a stream of bytes.
/// "p_len" limits number of bytes after "p_in".
/// Note: Counts individual codepoints of composed characters separately.
CharBoundsOff utf_cp_bounds_len(char const *base, char const *p_in, int p_len)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_ALL
{
  assert(base <= p_in && p_len > 0);
  uint8_t const *const b = (uint8_t *)base;
  uint8_t const *const p = (uint8_t *)p_in;
  if (*p < 0x80U) {  // be quick for ASCII
    return (CharBoundsOff){ 0, 1 };
  }

  int const max_first_off = -MIN((int)(p - b), MB_MAXCHAR - 1);
  int first_off = 0;
  for (; utf_is_trail_byte(p[first_off]); first_off--) {
    if (first_off == max_first_off) {  // failed to find first byte
      return (CharBoundsOff){ 0, 1 };
    }
  }

  int const max_end_off = utf8len_tab[p[first_off]] + first_off;
  if (max_end_off <= 0 || max_end_off > p_len) {  // illegal or incomplete sequence
    return (CharBoundsOff){ 0, 1 };
  }

  for (int end_off = 1; end_off < max_end_off; end_off++) {
    if (!utf_is_trail_byte(p[end_off])) {  // not enough trail bytes
      return (CharBoundsOff){ 0, 1 };
    }
  }

  return (CharBoundsOff){ .begin_off = (int8_t)-first_off, .end_off = (int8_t)max_end_off };
}

/// Returns the offset in bytes from "p_in" to the first and one-past-end bytes
/// of the codepoint it points to.
/// "p_in" can point anywhere in a stream of bytes.
/// Stream must be NUL-terminated.
/// Note: Counts individual codepoints of composed characters separately.
CharBoundsOff utf_cp_bounds(char const *base, char const *p_in)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_ALL
{
  return utf_cp_bounds_len(base, p_in, INT_MAX);
}

// Find the next illegal byte sequence.
void utf_find_illegal(void)
{
  pos_T pos = curwin->w_cursor;
  vimconv_T vimconv;
  char *tofree = NULL;

  vimconv.vc_type = CONV_NONE;
  if (enc_canon_props(curbuf->b_p_fenc) & ENC_8BIT) {
    // 'encoding' is "utf-8" but we are editing a 8-bit encoded file,
    // possibly a utf-8 file with illegal bytes.  Setup for conversion
    // from utf-8 to 'fileencoding'.
    convert_setup(&vimconv, p_enc, curbuf->b_p_fenc);
  }

  curwin->w_cursor.coladd = 0;
  while (true) {
    char *p = get_cursor_pos_ptr();
    if (vimconv.vc_type != CONV_NONE) {
      xfree(tofree);
      tofree = string_convert(&vimconv, p, NULL);
      if (tofree == NULL) {
        break;
      }
      p = tofree;
    }

    while (*p != NUL) {
      // Illegal means that there are not enough trail bytes (checked by
      // utf_ptr2len()) or too many of them (overlong sequence).
      int len = utf_ptr2len(p);
      if ((uint8_t)(*p) >= 0x80 && (len == 1 || utf_char2len(utf_ptr2char(p)) != len)) {
        if (vimconv.vc_type == CONV_NONE) {
          curwin->w_cursor.col += (colnr_T)(p - get_cursor_pos_ptr());
        } else {
          int l;

          len = (int)(p - tofree);
          for (p = get_cursor_pos_ptr(); *p != NUL && len-- > 0; p += l) {
            l = utf_ptr2len(p);
            curwin->w_cursor.col += l;
          }
        }
        goto theend;
      }
      p += len;
    }
    if (curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count) {
      break;
    }
    curwin->w_cursor.lnum++;
    curwin->w_cursor.col = 0;
  }

  // didn't find it: don't move and beep
  curwin->w_cursor = pos;
  beep_flush();

theend:
  xfree(tofree);
  convert_setup(&vimconv, NULL, NULL);
}

/// @return  true if string "s" is a valid utf-8 string.
/// When "end" is NULL stop at the first NUL.  Otherwise stop at "end".
bool utf_valid_string(const char *s, const char *end)
{
  const uint8_t *p = (uint8_t *)s;

  while (end == NULL ? *p != NUL : p < (uint8_t *)end) {
    int l = utf8len_tab_zero[*p];
    if (l == 0) {
      return false;  // invalid lead byte
    }
    if (end != NULL && p + l > (uint8_t *)end) {
      return false;  // incomplete byte sequence
    }
    p++;
    while (--l > 0) {
      if ((*p++ & 0xc0) != 0x80) {
        return false;  // invalid trail byte
      }
    }
  }
  return true;
}

// If the cursor moves on an trail byte, set the cursor on the lead byte.
// Thus it moves left if necessary.
void mb_adjust_cursor(void)
{
  mark_mb_adjustpos(curbuf, &curwin->w_cursor);
}

/// Checks and adjusts cursor column. Not mode-dependent.
/// @see check_cursor_col_win
///
/// @param  win_  Places cursor on a valid column for this window.
void mb_check_adjust_col(void *win_)
{
  win_T *win = (win_T *)win_;
  colnr_T oldcol = win->w_cursor.col;

  // Column 0 is always valid.
  if (oldcol != 0) {
    char *p = ml_get_buf(win->w_buffer, win->w_cursor.lnum);
    colnr_T len = (colnr_T)strlen(p);

    // Empty line or invalid column?
    if (len == 0 || oldcol < 0) {
      win->w_cursor.col = 0;
    } else {
      // Cursor column too big for line?
      if (oldcol > len) {
        win->w_cursor.col = len - 1;
      }
      // Move the cursor to the head byte.
      win->w_cursor.col -= utf_head_off(p, p + win->w_cursor.col);
    }

    // Reset `coladd` when the cursor would be on the right half of a
    // double-wide character.
    if (win->w_cursor.coladd == 1 && p[win->w_cursor.col] != TAB
        && vim_isprintc(utf_ptr2char(p + win->w_cursor.col))
        && ptr2cells(p + win->w_cursor.col) > 1) {
      win->w_cursor.coladd = 0;
    }
  }
}

/// @param line  start of the string
///
/// @return      a pointer to the character before "*p", if there is one.
char *mb_prevptr(char *line, char *p)
{
  if (p > line) {
    MB_PTR_BACK(line, p);
  }
  return p;
}

/// Return the character length of "str".  Each multi-byte character (with
/// following composing characters) counts as one.
int mb_charlen(const char *str)
{
  const char *p = str;
  int count;

  if (p == NULL) {
    return 0;
  }

  for (count = 0; *p != NUL; count++) {
    p += utfc_ptr2len(p);
  }

  return count;
}

int mb_charlen2bytelen(const char *str, int charlen)
{
  const char *p = str;
  int count = 0;

  if (p == NULL) {
    return 0;
  }

  for (int i = 0; *p != NUL && i < charlen; i++) {
    int b = utfc_ptr2len(p);
    p += b;
    count += b;
  }

  return count;
}

/// Like mb_charlen() but for a string with specified length.
int mb_charlen_len(const char *str, int len)
{
  const char *p = str;
  int count;

  for (count = 0; *p != NUL && p < str + len; count++) {
    p += utfc_ptr2len(p);
  }

  return count;
}

/// Try to unescape a multibyte character
///
/// Used for the rhs and lhs of the mappings.
///
/// @param[in,out]  pp  String to unescape. Is advanced to just after the bytes
///                     that form a multibyte character.
///
/// @return Unescaped string if it is a multibyte character, NULL if no
///         multibyte character was found. Returns a static buffer, always one
///         and the same.
const char *mb_unescape(const char **const pp)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  static char buf[6];
  size_t buf_idx = 0;
  uint8_t *str = (uint8_t *)(*pp);

  // Must translate K_SPECIAL KS_SPECIAL KE_FILLER to K_SPECIAL.
  // Maximum length of a utf-8 character is 4 bytes.
  for (size_t str_idx = 0; str[str_idx] != NUL && buf_idx < 4; str_idx++) {
    if (str[str_idx] == K_SPECIAL
        && str[str_idx + 1] == KS_SPECIAL
        && str[str_idx + 2] == KE_FILLER) {
      buf[buf_idx++] = (char)K_SPECIAL;
      str_idx += 2;
    } else if (str[str_idx] == K_SPECIAL) {
      break;  // A special key can't be a multibyte char.
    } else {
      buf[buf_idx++] = (char)str[str_idx];
    }
    buf[buf_idx] = NUL;

    // Return a multi-byte character if it's found.  An illegal sequence
    // will result in a 1 here.
    if (utf_ptr2len(buf) > 1) {
      *pp = (const char *)str + str_idx + 1;
      return buf;
    }

    // Bail out quickly for ASCII.
    if ((uint8_t)buf[0] < 128) {
      break;
    }
  }
  return NULL;
}

/// Skip the Vim specific head of a 'encoding' name.
char *enc_skip(char *p)
{
  if (strncmp(p, "2byte-", 6) == 0) {
    return p + 6;
  }
  if (strncmp(p, "8bit-", 5) == 0) {
    return p + 5;
  }
  return p;
}

/// Find the canonical name for encoding "enc".
/// When the name isn't recognized, returns "enc" itself, but with all lower
/// case characters and '_' replaced with '-'.
///
/// @return  an allocated string.
char *enc_canonize(char *enc)
  FUNC_ATTR_NONNULL_RET
{
  if (strcmp(enc, "default") == 0) {
    // Use the default encoding as found by set_init_1().
    return xstrdup(fenc_default);
  }

  // copy "enc" to allocated memory, with room for two '-'
  char *r = xmalloc(strlen(enc) + 3);
  // Make it all lower case and replace '_' with '-'.
  char *p = r;
  for (char *s = enc; *s != NUL; s++) {
    if (*s == '_') {
      *p++ = '-';
    } else {
      *p++ = (char)TOLOWER_ASC(*s);
    }
  }
  *p = NUL;

  // Skip "2byte-" and "8bit-".
  p = enc_skip(r);

  // Change "microsoft-cp" to "cp".  Used in some spell files.
  if (strncmp(p, "microsoft-cp", 12) == 0) {
    STRMOVE(p, p + 10);
  }

  // "iso8859" -> "iso-8859"
  if (strncmp(p, "iso8859", 7) == 0) {
    STRMOVE(p + 4, p + 3);
    p[3] = '-';
  }

  // "iso-8859n" -> "iso-8859-n"
  if (strncmp(p, "iso-8859", 8) == 0 && p[8] != '-') {
    STRMOVE(p + 9, p + 8);
    p[8] = '-';
  }

  // "latin-N" -> "latinN"
  if (strncmp(p, "latin-", 6) == 0) {
    STRMOVE(p + 5, p + 6);
  }

  int i;
  if (enc_canon_search(p) >= 0) {
    // canonical name can be used unmodified
    if (p != r) {
      STRMOVE(r, p);
    }
  } else if ((i = enc_alias_search(p)) >= 0) {
    // alias recognized, get canonical name
    xfree(r);
    r = xstrdup(enc_canon_table[i].name);
  }
  return r;
}

/// Search for an encoding alias of "name".
/// Returns -1 when not found.
static int enc_alias_search(const char *name)
{
  for (int i = 0; enc_alias_table[i].name != NULL; i++) {
    if (strcmp(name, enc_alias_table[i].name) == 0) {
      return enc_alias_table[i].canon;
    }
  }
  return -1;
}

#ifdef HAVE_LANGINFO_H
# include <langinfo.h>
#endif

// Get the canonicalized encoding of the current locale.
// Returns an allocated string when successful, NULL when not.
char *enc_locale(void)
{
  int i;
  char buf[50];

  const char *s;
#ifdef HAVE_NL_LANGINFO_CODESET
  if (!(s = nl_langinfo(CODESET)) || *s == NUL)
#endif
  {
    if (!(s = setlocale(LC_CTYPE, NULL)) || *s == NUL) {
      if ((s = os_getenv("LC_ALL"))) {
        if ((s = os_getenv("LC_CTYPE"))) {
          s = os_getenv("LANG");
        }
      }
    }
  }

  if (!s) {
    return NULL;
  }

  // The most generic locale format is:
  // language[_territory][.codeset][@modifier][+special][,[sponsor][_revision]]
  // If there is a '.' remove the part before it.
  // if there is something after the codeset, remove it.
  // Make the name lowercase and replace '_' with '-'.
  // Exception: "ja_JP.EUC" == "euc-jp", "zh_CN.EUC" = "euc-cn",
  // "ko_KR.EUC" == "euc-kr"
  const char *p = vim_strchr(s, '.');
  if (p != NULL) {
    if (p > s + 2 && !STRNICMP(p + 1, "EUC", 3)
        && !isalnum((uint8_t)p[4]) && p[4] != '-' && p[-3] == '_') {
      // Copy "XY.EUC" to "euc-XY" to buf[10].
      memmove(buf, "euc-", 4);
      buf[4] = (char)(ASCII_ISALNUM(p[-2]) ? TOLOWER_ASC(p[-2]) : 0);
      buf[5] = (char)(ASCII_ISALNUM(p[-1]) ? TOLOWER_ASC(p[-1]) : 0);
      buf[6] = NUL;
    } else {
      s = p + 1;
      goto enc_locale_copy_enc;
    }
  } else {
enc_locale_copy_enc:
    for (i = 0; i < (int)sizeof(buf) - 1 && s[i] != NUL; i++) {
      if (s[i] == '_' || s[i] == '-') {
        buf[i] = '-';
      } else if (ASCII_ISALNUM((uint8_t)s[i])) {
        buf[i] = (char)TOLOWER_ASC(s[i]);
      } else {
        break;
      }
    }
    buf[i] = NUL;
  }

  return enc_canonize(buf);
}

// Call iconv_open() with a check if iconv() works properly (there are broken
// versions).
// Returns (void *)-1 if failed.
// (should return iconv_t, but that causes problems with prototypes).
void *my_iconv_open(char *to, char *from)
{
#define ICONV_TESTLEN 400
  char tobuf[ICONV_TESTLEN];
  static WorkingStatus iconv_working = kUnknown;

  if (iconv_working == kBroken) {
    return (void *)-1;          // detected a broken iconv() previously
  }
  iconv_t fd = iconv_open(enc_skip(to), enc_skip(from));

  if (fd != (iconv_t)-1 && iconv_working == kUnknown) {
    // Do a dummy iconv() call to check if it actually works.  There is a
    // version of iconv() on Linux that is broken.  We can't ignore it,
    // because it's wide-spread.  The symptoms are that after outputting
    // the initial shift state the "to" pointer is NULL and conversion
    // stops for no apparent reason after about 8160 characters.
    char *p = tobuf;
    size_t tolen = ICONV_TESTLEN;
    iconv(fd, NULL, NULL, &p, &tolen);
    if (p == NULL) {
      iconv_working = kBroken;
      iconv_close(fd);
      fd = (iconv_t)-1;
    } else {
      iconv_working = kWorking;
    }
  }

  return (void *)fd;
}

// Convert the string "str[slen]" with iconv().
// If "unconvlenp" is not NULL handle the string ending in an incomplete
// sequence and set "*unconvlenp" to the length of it.
// Returns the converted string in allocated memory.  NULL for an error.
// If resultlenp is not NULL, sets it to the result length in bytes.
static char *iconv_string(const vimconv_T *const vcp, const char *str, size_t slen,
                          size_t *unconvlenp, size_t *resultlenp)
{
  char *to;
  size_t len = 0;
  size_t done = 0;
  char *result = NULL;

  const char *from = str;
  size_t fromlen = slen;
  while (true) {
    if (len == 0 || ICONV_ERRNO == ICONV_E2BIG) {
      // Allocate enough room for most conversions.  When re-allocating
      // increase the buffer size.
      len = len + fromlen * 2 + 40;
      char *p = xmalloc(len);
      if (done > 0) {
        memmove(p, result, done);
      }
      xfree(result);
      result = p;
    }

    to = result + done;
    size_t tolen = len - done - 2;
    // Avoid a warning for systems with a wrong iconv() prototype by
    // casting the second argument to void *.
    if (iconv(vcp->vc_fd, (void *)&from, &fromlen, &to, &tolen) != SIZE_MAX) {
      // Finished, append a NUL.
      *to = NUL;
      break;
    }

    // Check both ICONV_EINVAL and EINVAL, because the dynamically loaded
    // iconv library may use one of them.
    if (!vcp->vc_fail && unconvlenp != NULL
        && (ICONV_ERRNO == ICONV_EINVAL || ICONV_ERRNO == EINVAL)) {
      // Handle an incomplete sequence at the end.
      *to = NUL;
      *unconvlenp = fromlen;
      break;
    } else if (!vcp->vc_fail
               && (ICONV_ERRNO == ICONV_EILSEQ || ICONV_ERRNO == EILSEQ
                   || ICONV_ERRNO == ICONV_EINVAL || ICONV_ERRNO == EINVAL)) {
      // Check both ICONV_EILSEQ and EILSEQ, because the dynamically loaded
      // iconv library may use one of them.

      // Can't convert: insert a '?' and skip a character.  This assumes
      // conversion from 'encoding' to something else.  In other
      // situations we don't know what to skip anyway.
      *to++ = '?';
      if (utf_ptr2cells(from) > 1) {
        *to++ = '?';
      }
      int l = utfc_ptr2len_len(from, (int)fromlen);
      from += l;
      fromlen -= (size_t)l;
    } else if (ICONV_ERRNO != ICONV_E2BIG) {
      // conversion failed
      XFREE_CLEAR(result);
      break;
    }
    // Not enough room or skipping illegal sequence.
    done = (size_t)(to - result);
  }

  if (resultlenp != NULL && result != NULL) {
    *resultlenp = (size_t)(to - result);
  }
  return result;
}

/// iconv() function
void f_iconv(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  vimconv_T vimconv;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  const char *const str = tv_get_string(&argvars[0]);
  char buf1[NUMBUFLEN];
  char *const from = enc_canonize(enc_skip((char *)tv_get_string_buf(&argvars[1], buf1)));
  char buf2[NUMBUFLEN];
  char *const to = enc_canonize(enc_skip((char *)tv_get_string_buf(&argvars[2], buf2)));
  vimconv.vc_type = CONV_NONE;
  convert_setup(&vimconv, from, to);

  // If the encodings are equal, no conversion needed.
  if (vimconv.vc_type == CONV_NONE) {
    rettv->vval.v_string = xstrdup(str);
  } else {
    rettv->vval.v_string = string_convert(&vimconv, (char *)str, NULL);
  }

  convert_setup(&vimconv, NULL, NULL);
  xfree(from);
  xfree(to);
}

/// Setup "vcp" for conversion from "from" to "to".
/// The names must have been made canonical with enc_canonize().
/// vcp->vc_type must have been initialized to CONV_NONE.
/// Note: cannot be used for conversion from/to ucs-2 and ucs-4 (will use utf-8
/// instead).
/// Afterwards invoke with "from" and "to" equal to NULL to cleanup.
///
/// @return  FAIL when conversion is not supported, OK otherwise.
int convert_setup(vimconv_T *vcp, char *from, char *to)
{
  return convert_setup_ext(vcp, from, true, to, true);
}

/// As convert_setup(), but only when from_unicode_is_utf8 is true will all
/// "from" unicode charsets be considered utf-8.  Same for "to".
int convert_setup_ext(vimconv_T *vcp, char *from, bool from_unicode_is_utf8, char *to,
                      bool to_unicode_is_utf8)
{
  int from_is_utf8;
  int to_is_utf8;

  // Reset to no conversion.
  if (vcp->vc_type == CONV_ICONV && vcp->vc_fd != (iconv_t)-1) {
    iconv_close(vcp->vc_fd);
  }
  *vcp = (vimconv_T)MBYTE_NONE_CONV;

  // No conversion when one of the names is empty or they are equal.
  if (from == NULL || *from == NUL || to == NULL || *to == NUL
      || strcmp(from, to) == 0) {
    return OK;
  }

  int from_prop = enc_canon_props(from);
  int to_prop = enc_canon_props(to);
  if (from_unicode_is_utf8) {
    from_is_utf8 = from_prop & ENC_UNICODE;
  } else {
    from_is_utf8 = from_prop == ENC_UNICODE;
  }
  if (to_unicode_is_utf8) {
    to_is_utf8 = to_prop & ENC_UNICODE;
  } else {
    to_is_utf8 = to_prop == ENC_UNICODE;
  }

  if ((from_prop & ENC_LATIN1) && to_is_utf8) {
    // Internal latin1 -> utf-8 conversion.
    vcp->vc_type = CONV_TO_UTF8;
    vcp->vc_factor = 2;         // up to twice as long
  } else if ((from_prop & ENC_LATIN9) && to_is_utf8) {
    // Internal latin9 -> utf-8 conversion.
    vcp->vc_type = CONV_9_TO_UTF8;
    vcp->vc_factor = 3;         // up to three as long (euro sign)
  } else if (from_is_utf8 && (to_prop & ENC_LATIN1)) {
    // Internal utf-8 -> latin1 conversion.
    vcp->vc_type = CONV_TO_LATIN1;
  } else if (from_is_utf8 && (to_prop & ENC_LATIN9)) {
    // Internal utf-8 -> latin9 conversion.
    vcp->vc_type = CONV_TO_LATIN9;
  } else {
    // Use iconv() for conversion.
    vcp->vc_fd = (iconv_t)my_iconv_open(to_is_utf8 ? "utf-8" : to,
                                        from_is_utf8 ? "utf-8" : from);
    if (vcp->vc_fd != (iconv_t)-1) {
      vcp->vc_type = CONV_ICONV;
      vcp->vc_factor = 4;       // could be longer too...
    }
  }
  if (vcp->vc_type == CONV_NONE) {
    return FAIL;
  }

  return OK;
}

/// Convert text "ptr[*lenp]" according to "vcp".
/// Returns the result in allocated memory and sets "*lenp".
/// When "lenp" is NULL, use NUL terminated strings.
/// Illegal chars are often changed to "?", unless vcp->vc_fail is set.
/// When something goes wrong, NULL is returned and "*lenp" is unchanged.
char *string_convert(const vimconv_T *const vcp, char *ptr, size_t *lenp)
{
  return string_convert_ext(vcp, ptr, lenp, NULL);
}

// Like string_convert(), but when "unconvlenp" is not NULL and there are is
// an incomplete sequence at the end it is not converted and "*unconvlenp" is
// set to the number of remaining bytes.
char *string_convert_ext(const vimconv_T *const vcp, char *ptr, size_t *lenp, size_t *unconvlenp)
{
  uint8_t *retval = NULL;
  uint8_t *d;
  int c;

  size_t len;
  if (lenp == NULL) {
    len = strlen(ptr);
  } else {
    len = *lenp;
  }
  if (len == 0) {
    return xstrdup("");
  }

  switch (vcp->vc_type) {
  case CONV_TO_UTF8:            // latin1 to utf-8 conversion
    retval = xmalloc(len * 2 + 1);
    d = retval;
    for (size_t i = 0; i < len; i++) {
      c = (uint8_t)ptr[i];
      if (c < 0x80) {
        *d++ = (uint8_t)c;
      } else {
        *d++ = (uint8_t)(0xc0 + (uint8_t)((unsigned)c >> 6));
        *d++ = (uint8_t)(0x80 + (c & 0x3f));
      }
    }
    *d = NUL;
    if (lenp != NULL) {
      *lenp = (size_t)(d - retval);
    }
    break;

  case CONV_9_TO_UTF8:          // latin9 to utf-8 conversion
    retval = xmalloc(len * 3 + 1);
    d = retval;
    for (size_t i = 0; i < len; i++) {
      c = (uint8_t)ptr[i];
      switch (c) {
      case 0xa4:
        c = 0x20ac; break;                 // euro
      case 0xa6:
        c = 0x0160; break;                 // S hat
      case 0xa8:
        c = 0x0161; break;                 // S -hat
      case 0xb4:
        c = 0x017d; break;                 // Z hat
      case 0xb8:
        c = 0x017e; break;                 // Z -hat
      case 0xbc:
        c = 0x0152; break;                 // OE
      case 0xbd:
        c = 0x0153; break;                 // oe
      case 0xbe:
        c = 0x0178; break;                 // Y
      }
      d += utf_char2bytes(c, (char *)d);
    }
    *d = NUL;
    if (lenp != NULL) {
      *lenp = (size_t)(d - retval);
    }
    break;

  case CONV_TO_LATIN1:          // utf-8 to latin1 conversion
  case CONV_TO_LATIN9:          // utf-8 to latin9 conversion
    retval = xmalloc(len + 1);
    d = retval;
    for (size_t i = 0; i < len; i++) {
      int l = utf_ptr2len_len(ptr + i, (int)(len - i));
      if (l == 0) {
        *d++ = NUL;
      } else if (l == 1) {
        uint8_t l_w = utf8len_tab_zero[(uint8_t)ptr[i]];

        if (l_w == 0) {
          // Illegal utf-8 byte cannot be converted
          xfree(retval);
          return NULL;
        }
        if (unconvlenp != NULL && l_w > len - i) {
          // Incomplete sequence at the end.
          *unconvlenp = len - i;
          break;
        }
        *d++ = (uint8_t)ptr[i];
      } else {
        c = utf_ptr2char(ptr + i);
        if (vcp->vc_type == CONV_TO_LATIN9) {
          switch (c) {
          case 0x20ac:
            c = 0xa4; break;                     // euro
          case 0x0160:
            c = 0xa6; break;                     // S hat
          case 0x0161:
            c = 0xa8; break;                     // S -hat
          case 0x017d:
            c = 0xb4; break;                     // Z hat
          case 0x017e:
            c = 0xb8; break;                     // Z -hat
          case 0x0152:
            c = 0xbc; break;                     // OE
          case 0x0153:
            c = 0xbd; break;                     // oe
          case 0x0178:
            c = 0xbe; break;                     // Y
          case 0xa4:
          case 0xa6:
          case 0xa8:
          case 0xb4:
          case 0xb8:
          case 0xbc:
          case 0xbd:
          case 0xbe:
            c = 0x100; break;                   // not in latin9
          }
        }
        if (!utf_iscomposing(c)) {              // skip composing chars
          if (c < 0x100) {
            *d++ = (uint8_t)c;
          } else if (vcp->vc_fail) {
            xfree(retval);
            return NULL;
          } else {
            *d++ = 0xbf;
            if (utf_char2cells(c) > 1) {
              *d++ = '?';
            }
          }
        }
        i += (size_t)l - 1;
      }
    }
    *d = NUL;
    if (lenp != NULL) {
      *lenp = (size_t)(d - retval);
    }
    break;

  case CONV_ICONV:  // conversion with vcp->vc_fd
    retval = (uint8_t *)iconv_string(vcp, ptr, len, unconvlenp, lenp);
    break;
  }

  return (char *)retval;
}

/// Table set by setcellwidths().
typedef struct {
  int64_t first;
  int64_t last;
  char width;
} cw_interval_T;

static cw_interval_T *cw_table = NULL;
static size_t cw_table_size = 0;

/// Return the value of the cellwidth table for the character `c`.
///
/// @param c The source character.
/// @return 1 or 2 when `c` is in the cellwidth table, 0 if not.
static int cw_value(int c)
{
  if (cw_table == NULL) {
    return 0;
  }

  // first quick check for Latin1 etc. characters
  if (c < cw_table[0].first) {
    return 0;
  }

  // binary search in table
  int bot = 0;
  int top = (int)cw_table_size - 1;
  while (top >= bot) {
    int mid = (bot + top) / 2;
    if (cw_table[mid].last < c) {
      bot = mid + 1;
    } else if (cw_table[mid].first > c) {
      top = mid - 1;
    } else {
      return cw_table[mid].width;
    }
  }
  return 0;
}

static int tv_nr_compare(const void *a1, const void *a2)
{
  const listitem_T *const li1 = tv_list_first(*(const list_T **)a1);
  const listitem_T *const li2 = tv_list_first(*(const list_T **)a2);
  const varnumber_T n1 = TV_LIST_ITEM_TV(li1)->vval.v_number;
  const varnumber_T n2 = TV_LIST_ITEM_TV(li2)->vval.v_number;

  return n1 == n2 ? 0 : n1 > n2 ? 1 : -1;
}

/// "setcellwidths()" function
void f_setcellwidths(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (argvars[0].v_type != VAR_LIST || argvars[0].vval.v_list == NULL) {
    emsg(_(e_listreq));
    return;
  }
  const list_T *const l = argvars[0].vval.v_list;
  if (tv_list_len(l) == 0) {
    // Clearing the table.
    xfree(cw_table);
    cw_table = NULL;
    cw_table_size = 0;
    return;
  }

  // Note: use list_T instead of listitem_T so that TV_LIST_ITEM_NEXT can be used properly below.
  const list_T **ptrs = xmalloc(sizeof(const list_T *) * (size_t)tv_list_len(l));

  // Check that all entries are a list with three numbers, the range is
  // valid and the cell width is valid.
  int item = 0;
  TV_LIST_ITER_CONST(l, li, {
    const typval_T *const li_tv = TV_LIST_ITEM_TV(li);

    if (li_tv->v_type != VAR_LIST || li_tv->vval.v_list == NULL) {
      semsg(_(e_list_item_nr_is_not_list), item);
      xfree((void *)ptrs);
      return;
    }

    const list_T *const li_l = li_tv->vval.v_list;
    ptrs[item] = li_l;
    const listitem_T *lili = tv_list_first(li_l);
    int i;
    varnumber_T n1;
    for (i = 0; lili != NULL; lili = TV_LIST_ITEM_NEXT(li_l, lili), i++) {
      const typval_T *const lili_tv = TV_LIST_ITEM_TV(lili);
      if (lili_tv->v_type != VAR_NUMBER) {
        break;
      }
      if (i == 0) {
        n1 = lili_tv->vval.v_number;
        if (n1 < 0x80) {
          emsg(_(e_only_values_of_0x80_and_higher_supported));
          xfree((void *)ptrs);
          return;
        }
      } else if (i == 1 && lili_tv->vval.v_number < n1) {
        semsg(_(e_list_item_nr_range_invalid), item);
        xfree((void *)ptrs);
        return;
      } else if (i == 2 && (lili_tv->vval.v_number < 1 || lili_tv->vval.v_number > 2)) {
        semsg(_(e_list_item_nr_cell_width_invalid), item);
        xfree((void *)ptrs);
        return;
      }
    }

    if (i != 3) {
      semsg(_(e_list_item_nr_does_not_contain_3_numbers), item);
      xfree((void *)ptrs);
      return;
    }

    item++;
  });

  // Sort the list on the first number.
  qsort((void *)ptrs, (size_t)tv_list_len(l), sizeof(const list_T *), tv_nr_compare);

  cw_interval_T *table = xmalloc(sizeof(cw_interval_T) * (size_t)tv_list_len(l));

  // Store the items in the new table.
  for (item = 0; item < tv_list_len(l); item++) {
    const list_T *const li_l = ptrs[item];
    const listitem_T *lili = tv_list_first(li_l);
    const varnumber_T n1 = TV_LIST_ITEM_TV(lili)->vval.v_number;
    if (item > 0 && n1 <= table[item - 1].last) {
      semsg(_(e_overlapping_ranges_for_nr), (size_t)n1);
      xfree((void *)ptrs);
      xfree(table);
      return;
    }
    table[item].first = n1;
    lili = TV_LIST_ITEM_NEXT(li_l, lili);
    table[item].last = TV_LIST_ITEM_TV(lili)->vval.v_number;
    lili = TV_LIST_ITEM_NEXT(li_l, lili);
    table[item].width = (char)TV_LIST_ITEM_TV(lili)->vval.v_number;
  }

  xfree((void *)ptrs);

  cw_interval_T *const cw_table_save = cw_table;
  const size_t cw_table_size_save = cw_table_size;
  cw_table = table;
  cw_table_size = (size_t)tv_list_len(l);

  // Check that the new value does not conflict with 'listchars' or
  // 'fillchars'.
  const char *const error = check_chars_options();
  if (error != NULL) {
    emsg(_(error));
    cw_table = cw_table_save;
    cw_table_size = cw_table_size_save;
    xfree(table);
    return;
  }

  xfree(cw_table_save);
  changed_window_setting_all();
  redraw_all_later(UPD_NOT_VALID);
}

/// "getcellwidths()" function
void f_getcellwidths(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, (ptrdiff_t)cw_table_size);

  for (size_t i = 0; i < cw_table_size; i++) {
    list_T *entry = tv_list_alloc(3);
    tv_list_append_number(entry, (varnumber_T)cw_table[i].first);
    tv_list_append_number(entry, (varnumber_T)cw_table[i].last);
    tv_list_append_number(entry, (varnumber_T)cw_table[i].width);

    tv_list_append_list(rettv->vval.v_list, entry);
  }
}

void f_charclass(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || argvars[0].vval.v_string == NULL) {
    return;
  }
  rettv->vval.v_number = mb_get_class(argvars[0].vval.v_string);
}

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// encoding options.
char *get_encoding_name(expand_T *xp FUNC_ATTR_UNUSED, int idx)
{
  if (idx >= (int)ARRAY_SIZE(enc_canon_table)) {
    return NULL;
  }

  return (char *)enc_canon_table[idx].name;
}

/// Compare strings
///
/// @param[in]  ic  True if case is to be ignored.
///
/// @return 0 if s1 == s2, <0 if s1 < s2, >0 if s1 > s2.
int mb_strcmp_ic(bool ic, const char *s1, const char *s2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (ic ? mb_stricmp(s1, s2) : strcmp(s1, s2));
}
