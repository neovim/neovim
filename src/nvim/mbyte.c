// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// mbyte.c: Code specifically for handling multi-byte characters.
/// Multibyte extensions partly by Sung-Hoon Baek
///
/// The encoding used in nvim is always UTF-8. "enc_utf8" and "has_mbyte" is
/// thus always true. "enc_dbcs" is always zero. The 'encoding' option is
/// read-only and always reads "utf-8".
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

#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/eval.h"
#include "nvim/path.h"
#include "nvim/iconv.h"
#include "nvim/mbyte.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/os/os.h"
#include "nvim/arabic.h"
#include "nvim/mark.h"

typedef struct {
  int rangeStart;
  int rangeEnd;
  int step;
  int offset;
} convertStruct;

struct interval {
  long first;
  long last;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.c.generated.h"
# include "unicode_tables.generated.h"
#endif

char_u e_loadlib[] = "E370: Could not load library %s";
char_u e_loadfunc[] = "E448: Could not load library function %s";

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

/*
 * Canonical encoding names and their properties.
 * "iso-8859-n" is handled by enc_canonize() directly.
 */
static struct
{   const char *name;   int prop;              int codepage; }
enc_canon_table[] =
{
#define IDX_LATIN_1     0
  {"latin1",          ENC_8BIT + ENC_LATIN1,  1252},
#define IDX_ISO_2       1
  {"iso-8859-2",      ENC_8BIT,               0},
#define IDX_ISO_3       2
  {"iso-8859-3",      ENC_8BIT,               0},
#define IDX_ISO_4       3
  {"iso-8859-4",      ENC_8BIT,               0},
#define IDX_ISO_5       4
  {"iso-8859-5",      ENC_8BIT,               0},
#define IDX_ISO_6       5
  {"iso-8859-6",      ENC_8BIT,               0},
#define IDX_ISO_7       6
  {"iso-8859-7",      ENC_8BIT,               0},
#define IDX_ISO_8       7
  {"iso-8859-8",      ENC_8BIT,               0},
#define IDX_ISO_9       8
  {"iso-8859-9",      ENC_8BIT,               0},
#define IDX_ISO_10      9
  {"iso-8859-10",     ENC_8BIT,               0},
#define IDX_ISO_11      10
  {"iso-8859-11",     ENC_8BIT,               0},
#define IDX_ISO_13      11
  {"iso-8859-13",     ENC_8BIT,               0},
#define IDX_ISO_14      12
  {"iso-8859-14",     ENC_8BIT,               0},
#define IDX_ISO_15      13
  {"iso-8859-15",     ENC_8BIT + ENC_LATIN9,  0},
#define IDX_KOI8_R      14
  {"koi8-r",          ENC_8BIT,               0},
#define IDX_KOI8_U      15
  {"koi8-u",          ENC_8BIT,               0},
#define IDX_UTF8        16
  {"utf-8",           ENC_UNICODE,            0},
#define IDX_UCS2        17
  {"ucs-2",           ENC_UNICODE + ENC_ENDIAN_B + ENC_2BYTE, 0},
#define IDX_UCS2LE      18
  {"ucs-2le",         ENC_UNICODE + ENC_ENDIAN_L + ENC_2BYTE, 0},
#define IDX_UTF16       19
  {"utf-16",          ENC_UNICODE + ENC_ENDIAN_B + ENC_2WORD, 0},
#define IDX_UTF16LE     20
  {"utf-16le",        ENC_UNICODE + ENC_ENDIAN_L + ENC_2WORD, 0},
#define IDX_UCS4        21
  {"ucs-4",           ENC_UNICODE + ENC_ENDIAN_B + ENC_4BYTE, 0},
#define IDX_UCS4LE      22
  {"ucs-4le",         ENC_UNICODE + ENC_ENDIAN_L + ENC_4BYTE, 0},

  /* For debugging DBCS encoding on Unix. */
#define IDX_DEBUG       23
  {"debug",           ENC_DBCS,               DBCS_DEBUG},
#define IDX_EUC_JP      24
  {"euc-jp",          ENC_DBCS,               DBCS_JPNU},
#define IDX_SJIS        25
  {"sjis",            ENC_DBCS,               DBCS_JPN},
#define IDX_EUC_KR      26
  {"euc-kr",          ENC_DBCS,               DBCS_KORU},
#define IDX_EUC_CN      27
  {"euc-cn",          ENC_DBCS,               DBCS_CHSU},
#define IDX_EUC_TW      28
  {"euc-tw",          ENC_DBCS,               DBCS_CHTU},
#define IDX_BIG5        29
  {"big5",            ENC_DBCS,               DBCS_CHT},

  /* MS-DOS and MS-Windows codepages are included here, so that they can be
   * used on Unix too.  Most of them are similar to ISO-8859 encodings, but
   * not exactly the same. */
#define IDX_CP437       30
  {"cp437",           ENC_8BIT,               437},   /* like iso-8859-1 */
#define IDX_CP737       31
  {"cp737",           ENC_8BIT,               737},   /* like iso-8859-7 */
#define IDX_CP775       32
  {"cp775",           ENC_8BIT,               775},   /* Baltic */
#define IDX_CP850       33
  {"cp850",           ENC_8BIT,               850},   /* like iso-8859-4 */
#define IDX_CP852       34
  {"cp852",           ENC_8BIT,               852},   /* like iso-8859-1 */
#define IDX_CP855       35
  {"cp855",           ENC_8BIT,               855},   /* like iso-8859-2 */
#define IDX_CP857       36
  {"cp857",           ENC_8BIT,               857},   /* like iso-8859-5 */
#define IDX_CP860       37
  {"cp860",           ENC_8BIT,               860},   /* like iso-8859-9 */
#define IDX_CP861       38
  {"cp861",           ENC_8BIT,               861},   /* like iso-8859-1 */
#define IDX_CP862       39
  {"cp862",           ENC_8BIT,               862},   /* like iso-8859-1 */
#define IDX_CP863       40
  {"cp863",           ENC_8BIT,               863},   /* like iso-8859-8 */
#define IDX_CP865       41
  {"cp865",           ENC_8BIT,               865},   /* like iso-8859-1 */
#define IDX_CP866       42
  {"cp866",           ENC_8BIT,               866},   /* like iso-8859-5 */
#define IDX_CP869       43
  {"cp869",           ENC_8BIT,               869},   /* like iso-8859-7 */
#define IDX_CP874       44
  {"cp874",           ENC_8BIT,               874},   /* Thai */
#define IDX_CP932       45
  {"cp932",           ENC_DBCS,               DBCS_JPN},
#define IDX_CP936       46
  {"cp936",           ENC_DBCS,               DBCS_CHS},
#define IDX_CP949       47
  {"cp949",           ENC_DBCS,               DBCS_KOR},
#define IDX_CP950       48
  {"cp950",           ENC_DBCS,               DBCS_CHT},
#define IDX_CP1250      49
  {"cp1250",          ENC_8BIT,               1250},   /* Czech, Polish, etc. */
#define IDX_CP1251      50
  {"cp1251",          ENC_8BIT,               1251},   /* Cyrillic */
  /* cp1252 is considered to be equal to latin1 */
#define IDX_CP1253      51
  {"cp1253",          ENC_8BIT,               1253},   /* Greek */
#define IDX_CP1254      52
  {"cp1254",          ENC_8BIT,               1254},   /* Turkish */
#define IDX_CP1255      53
  {"cp1255",          ENC_8BIT,               1255},   /* Hebrew */
#define IDX_CP1256      54
  {"cp1256",          ENC_8BIT,               1256},   /* Arabic */
#define IDX_CP1257      55
  {"cp1257",          ENC_8BIT,               1257},   /* Baltic */
#define IDX_CP1258      56
  {"cp1258",          ENC_8BIT,               1258},   /* Vietnamese */

#define IDX_MACROMAN    57
  {"macroman",        ENC_8BIT + ENC_MACROMAN, 0},      /* Mac OS */
#define IDX_HPROMAN8    58
  {"hp-roman8",       ENC_8BIT,               0},       /* HP Roman8 */
#define IDX_COUNT       59
};

/*
 * Aliases for encoding names.
 */
static struct
{   const char *name; int canon; }
enc_alias_table[] =
{
  {"ansi",            IDX_LATIN_1},
  {"iso-8859-1",      IDX_LATIN_1},
  {"latin2",          IDX_ISO_2},
  {"latin3",          IDX_ISO_3},
  {"latin4",          IDX_ISO_4},
  {"cyrillic",        IDX_ISO_5},
  {"arabic",          IDX_ISO_6},
  {"greek",           IDX_ISO_7},
  {"hebrew",          IDX_ISO_8},
  {"latin5",          IDX_ISO_9},
  {"turkish",         IDX_ISO_9},   /* ? */
  {"latin6",          IDX_ISO_10},
  {"nordic",          IDX_ISO_10},   /* ? */
  {"thai",            IDX_ISO_11},   /* ? */
  {"latin7",          IDX_ISO_13},
  {"latin8",          IDX_ISO_14},
  {"latin9",          IDX_ISO_15},
  {"utf8",            IDX_UTF8},
  {"unicode",         IDX_UCS2},
  {"ucs2",            IDX_UCS2},
  {"ucs2be",          IDX_UCS2},
  {"ucs-2be",         IDX_UCS2},
  {"ucs2le",          IDX_UCS2LE},
  {"utf16",           IDX_UTF16},
  {"utf16be",         IDX_UTF16},
  {"utf-16be",        IDX_UTF16},
  {"utf16le",         IDX_UTF16LE},
  {"ucs4",            IDX_UCS4},
  {"ucs4be",          IDX_UCS4},
  {"ucs-4be",         IDX_UCS4},
  {"ucs4le",          IDX_UCS4LE},
  {"utf32",           IDX_UCS4},
  {"utf-32",          IDX_UCS4},
  {"utf32be",         IDX_UCS4},
  {"utf-32be",        IDX_UCS4},
  {"utf32le",         IDX_UCS4LE},
  {"utf-32le",        IDX_UCS4LE},
  {"932",             IDX_CP932},
  {"949",             IDX_CP949},
  {"936",             IDX_CP936},
  {"gbk",             IDX_CP936},
  {"950",             IDX_CP950},
  {"eucjp",           IDX_EUC_JP},
  {"unix-jis",        IDX_EUC_JP},
  {"ujis",            IDX_EUC_JP},
  {"shift-jis",       IDX_SJIS},
  {"pck",             IDX_SJIS},        /* Sun: PCK */
  {"euckr",           IDX_EUC_KR},
  {"5601",            IDX_EUC_KR},      /* Sun: KS C 5601 */
  {"euccn",           IDX_EUC_CN},
  {"gb2312",          IDX_EUC_CN},
  {"euctw",           IDX_EUC_TW},
  {"japan",           IDX_EUC_JP},
  {"korea",           IDX_EUC_KR},
  {"prc",             IDX_EUC_CN},
  {"chinese",         IDX_EUC_CN},
  {"taiwan",          IDX_EUC_TW},
  {"cp950",           IDX_BIG5},
  {"950",             IDX_BIG5},
  {"mac",             IDX_MACROMAN},
  {"mac-roman",       IDX_MACROMAN},
  {NULL,              0}
};

/*
 * Find encoding "name" in the list of canonical encoding names.
 * Returns -1 if not found.
 */
static int enc_canon_search(const char_u *name)
{
  int i;

  for (i = 0; i < IDX_COUNT; ++i)
    if (STRCMP(name, enc_canon_table[i].name) == 0)
      return i;
  return -1;
}



/*
 * Find canonical encoding "name" in the list and return its properties.
 * Returns 0 if not found.
 */
int enc_canon_props(const char_u *name)
{
  int i;

  i = enc_canon_search(name);
  if (i >= 0)
    return enc_canon_table[i].prop;
  if (STRNCMP(name, "2byte-", 6) == 0)
    return ENC_DBCS;
  if (STRNCMP(name, "8bit-", 5) == 0 || STRNCMP(name, "iso-8859-", 9) == 0)
    return ENC_8BIT;
  return 0;
}

/*
 * Return the size of the BOM for the current buffer:
 * 0 - no BOM
 * 2 - UCS-2 or UTF-16 BOM
 * 4 - UCS-4 BOM
 * 3 - UTF-8 BOM
 */
int bomb_size(void)
{
  int n = 0;

  if (curbuf->b_p_bomb && !curbuf->b_p_bin) {
    if (*curbuf->b_p_fenc == NUL
        || STRCMP(curbuf->b_p_fenc, "utf-8") == 0) {
      n = 3;
    } else if (STRNCMP(curbuf->b_p_fenc, "ucs-2", 5) == 0
               || STRNCMP(curbuf->b_p_fenc, "utf-16", 6) == 0) {
      n = 2;
    } else if (STRNCMP(curbuf->b_p_fenc, "ucs-4", 5) == 0) {
      n = 4;
    }
  }
  return n;
}

/*
 * Remove all BOM from "s" by moving remaining text.
 */
void remove_bom(char_u *s)
{
  char *p = (char *)s;

  while ((p = strchr(p, 0xef)) != NULL) {
    if ((uint8_t)p[1] == 0xbb && (uint8_t)p[2] == 0xbf) {
      STRMOVE(p, p + 3);
    } else {
      p++;
    }
  }
}

/*
 * Get class of pointer:
 * 0 for blank or NUL
 * 1 for punctuation
 * 2 for an (ASCII) word character
 * >2 for other word characters
 */
int mb_get_class(const char_u *p)
{
  return mb_get_class_tab(p, curbuf->b_chartab);
}

int mb_get_class_tab(const char_u *p, const uint64_t *const chartab)
{
  if (MB_BYTE2LEN(p[0]) == 1) {
    if (p[0] == NUL || ascii_iswhite(p[0])) {
      return 0;
    }
    if (vim_iswordc_tab(p[0], chartab)) {
      return 2;
    }
    return 1;
  }
  return utf_class(utf_ptr2char(p));
}

/*
 * Return true if "c" is in "table".
 */
static bool intable(const struct interval *table, size_t n_items, int c)
{
  int mid, bot, top;

  /* first quick check for Latin1 etc. characters */
  if (c < table[0].first)
    return false;

  /* binary search in table */
  bot = 0;
  top = (int)(n_items - 1);
  while (top >= bot) {
    mid = (bot + top) / 2;
    if (table[mid].last < c)
      bot = mid + 1;
    else if (table[mid].first > c)
      top = mid - 1;
    else
      return true;
  }
  return false;
}

/*
 * For UTF-8 character "c" return 2 for a double-width character, 1 for others.
 * Returns 4 or 6 for an unprintable character.
 * Is only correct for characters >= 0x80.
 * When p_ambw is "double", return 2 for a character with East Asian Width
 * class 'A'(mbiguous).
 */
int utf_char2cells(int c)
{
  if (c >= 0x100) {
#ifdef USE_WCHAR_FUNCTIONS
    /*
     * Assume the library function wcwidth() works better than our own
     * stuff.  It should return 1 for ambiguous width chars!
     */
    int n = wcwidth(c);

    if (n < 0)
      return 6;                 /* unprintable, displays <xxxx> */
    if (n > 1)
      return n;
#else
    if (!utf_printable(c))
      return 6;                 /* unprintable, displays <xxxx> */
    if (intable(doublewidth, ARRAY_SIZE(doublewidth), c))
      return 2;
#endif
    if (p_emoji && intable(emoji_width, ARRAY_SIZE(emoji_width), c)) {
      return 2;
    }
  }
  /* Characters below 0x100 are influenced by 'isprint' option */
  else if (c >= 0x80 && !vim_isprintc(c))
    return 4;                   /* unprintable, displays <xx> */

  if (c >= 0x80 && *p_ambw == 'd' && intable(ambiguous, ARRAY_SIZE(ambiguous), c))
    return 2;

  return 1;
}

/// Return the number of display cells character at "*p" occupies.
/// This doesn't take care of unprintable characters, use ptr2cells() for that.
int utf_ptr2cells(const char_u *p)
{
  int c;

  /* Need to convert to a wide character. */
  if (*p >= 0x80) {
    c = utf_ptr2char(p);
    /* An illegal byte is displayed as <xx>. */
    if (utf_ptr2len(p) == 1 || c == NUL)
      return 4;
    /* If the char is ASCII it must be an overlong sequence. */
    if (c < 0x80)
      return char2cells(c);
    return utf_char2cells(c);
  }
  return 1;
}

/// Like utf_ptr2cells(), but limit string length to "size".
/// For an empty string or truncated character returns 1.
int utf_ptr2cells_len(const char_u *p, int size)
{
  int c;

  /* Need to convert to a wide character. */
  if (size > 0 && *p >= 0x80) {
    if (utf_ptr2len_len(p, size) < utf8len_tab[*p])
      return 1;        /* truncated */
    c = utf_ptr2char(p);
    /* An illegal byte is displayed as <xx>. */
    if (utf_ptr2len(p) == 1 || c == NUL)
      return 4;
    /* If the char is ASCII it must be an overlong sequence. */
    if (c < 0x80)
      return char2cells(c);
    return utf_char2cells(c);
  }
  return 1;
}

/// Calculate the number of cells occupied by string `str`.
///
/// @param str The source string, may not be NULL, must be a NUL-terminated
///            string.
/// @return The number of cells occupied by string `str`
size_t mb_string2cells(const char_u *str)
{
  size_t clen = 0;

  for (const char_u *p = str; *p != NUL; p += (*mb_ptr2len)(p)) {
    clen += (*mb_ptr2cells)(p);
  }

  return clen;
}

/// Return number of display cells for char at ScreenLines[off].
/// We make sure that the offset used is less than "max_off".
int utf_off2cells(unsigned off, unsigned max_off)
{
  return (off + 1 < max_off && ScreenLines[off + 1][0] == 0) ? 2 : 1;
}

/// Convert a UTF-8 byte sequence to a wide character
///
/// If the sequence is illegal or truncated by a NUL then the first byte is
/// returned. Does not include composing characters for obvious reasons.
///
/// @param[in]  p  String to convert.
///
/// @return Unicode codepoint or byte value.
int utf_ptr2char(const char_u *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (p[0] < 0x80) {  // Be quick for ASCII.
    return p[0];
  }

  const uint8_t len = utf8len_tab_zero[p[0]];
  if (len > 1 && (p[1] & 0xc0) == 0x80) {
    if (len == 2) {
      return ((p[0] & 0x1f) << 6) + (p[1] & 0x3f);
    }
    if ((p[2] & 0xc0) == 0x80) {
      if (len == 3) {
        return (((p[0] & 0x0f) << 12) + ((p[1] & 0x3f) << 6)
                + (p[2] & 0x3f));
      }
      if ((p[3] & 0xc0) == 0x80) {
        if (len == 4) {
          return (((p[0] & 0x07) << 18) + ((p[1] & 0x3f) << 12)
                  + ((p[2] & 0x3f) << 6) + (p[3] & 0x3f));
        }
        if ((p[4] & 0xc0) == 0x80) {
          if (len == 5) {
            return (((p[0] & 0x03) << 24) + ((p[1] & 0x3f) << 18)
                    + ((p[2] & 0x3f) << 12) + ((p[3] & 0x3f) << 6)
                    + (p[4] & 0x3f));
          }
          if ((p[5] & 0xc0) == 0x80 && len == 6) {
            return (((p[0] & 0x01) << 30) + ((p[1] & 0x3f) << 24)
                    + ((p[2] & 0x3f) << 18) + ((p[3] & 0x3f) << 12)
                    + ((p[4] & 0x3f) << 6) + (p[5] & 0x3f));
          }
        }
      }
    }
  }
  // Illegal value: just return the first byte.
  return p[0];
}

/*
 * Convert a UTF-8 byte sequence to a wide character.
 * String is assumed to be terminated by NUL or after "n" bytes, whichever
 * comes first.
 * The function is safe in the sense that it never accesses memory beyond the
 * first "n" bytes of "s".
 *
 * On success, returns decoded codepoint, advances "s" to the beginning of
 * next character and decreases "n" accordingly.
 *
 * If end of string was reached, returns 0 and, if "n" > 0, advances "s" past
 * NUL byte.
 *
 * If byte sequence is illegal or incomplete, returns -1 and does not advance
 * "s".
 */
static int utf_safe_read_char_adv(const char_u **s, size_t *n)
{
  int c;

  if (*n == 0)   /* end of buffer */
    return 0;

  uint8_t k = utf8len_tab_zero[**s];

  if (k == 1) {
    /* ASCII character or NUL */
    (*n)--;
    return *(*s)++;
  }

  if (k <= *n) {
    /* We have a multibyte sequence and it isn't truncated by buffer
     * limits so utf_ptr2char() is safe to use. Or the first byte is
     * illegal (k=0), and it's also safe to use utf_ptr2char(). */
    c = utf_ptr2char(*s);

    /* On failure, utf_ptr2char() returns the first byte, so here we
     * check equality with the first byte. The only non-ASCII character
     * which equals the first byte of its own UTF-8 representation is
     * U+00C3 (UTF-8: 0xC3 0x83), so need to check that special case too.
     * It's safe even if n=1, else we would have k=2 > n. */
    if (c != (int)(**s) || (c == 0xC3 && (*s)[1] == 0x83)) {
      /* byte sequence was successfully decoded */
      *s += k;
      *n -= k;
      return c;
    }
  }

  /* byte sequence is incomplete or illegal */
  return -1;
}

/*
 * Get character at **pp and advance *pp to the next character.
 * Note: composing characters are skipped!
 */
int mb_ptr2char_adv(const char_u **const pp)
{
  int c;

  c = (*mb_ptr2char)(*pp);
  *pp += (*mb_ptr2len)(*pp);
  return c;
}

/*
 * Get character at **pp and advance *pp to the next character.
 * Note: composing characters are returned as separate characters.
 */
int mb_cptr2char_adv(const char_u **pp)
{
  int c;

  c = (*mb_ptr2char)(*pp);
  *pp += utf_ptr2len(*pp);
  return c;
}

/*
 * Check if the character pointed to by "p2" is a composing character when it
 * comes after "p1".  For Arabic sometimes "ab" is replaced with "c", which
 * behaves like a composing character.
 */
bool utf_composinglike(const char_u *p1, const char_u *p2)
{
  int c2;

  c2 = utf_ptr2char(p2);
  if (utf_iscomposing(c2))
    return true;
  if (!arabic_maycombine(c2))
    return false;
  return arabic_combine(utf_ptr2char(p1), c2);
}

/// Convert a UTF-8 string to a wide character
///
/// Also gets up to #MAX_MCO composing characters.
///
/// @param[out]  pcc  Location where to store composing characters. Must have
///                   space at least for #MAX_MCO + 1 elements.
///
/// @return leading character.
int utfc_ptr2char(const char_u *p, int *pcc)
{
  int len;
  int c;
  int cc;
  int i = 0;

  c = utf_ptr2char(p);
  len = utf_ptr2len(p);

  /* Only accept a composing char when the first char isn't illegal. */
  if ((len > 1 || *p < 0x80)
      && p[len] >= 0x80
      && UTF_COMPOSINGLIKE(p, p + len)) {
    cc = utf_ptr2char(p + len);
    for (;; ) {
      pcc[i++] = cc;
      if (i == MAX_MCO)
        break;
      len += utf_ptr2len(p + len);
      if (p[len] < 0x80 || !utf_iscomposing(cc = utf_ptr2char(p + len)))
        break;
    }
  }

  if (i < MAX_MCO)      /* last composing char must be 0 */
    pcc[i] = 0;

  return c;
}

/*
 * Convert a UTF-8 byte string to a wide character.  Also get up to MAX_MCO
 * composing characters.  Use no more than p[maxlen].
 *
 * @param [out] pcc: composing chars, last one is 0
 */
int utfc_ptr2char_len(const char_u *p, int *pcc, int maxlen)
{
#define IS_COMPOSING(s1, s2, s3) \
  (i == 0 ? UTF_COMPOSINGLIKE((s1), (s2)) : utf_iscomposing((s3)))

  assert(maxlen > 0);

  int i = 0;

  int len = utf_ptr2len_len(p, maxlen);
  // Is it safe to use utf_ptr2char()?
  bool safe = len > 1 && len <= maxlen;
  int c = safe ? utf_ptr2char(p) : *p;

  // Only accept a composing char when the first char isn't illegal.
  if ((safe || c < 0x80) && len < maxlen && p[len] >= 0x80) {
    for (; i < MAX_MCO; i++) {
      int len_cc = utf_ptr2len_len(p + len, maxlen - len);
      safe = len_cc > 1 && len_cc <= maxlen - len;
      if (!safe || (pcc[i] = utf_ptr2char(p + len)) < 0x80
          || !IS_COMPOSING(p, p + len, pcc[i])) {
        break;
      }
      len += len_cc;
    }
  }

  if (i < MAX_MCO) {
    // last composing char must be 0
    pcc[i] = 0;
  }

  return c;
#undef ISCOMPOSING
}

/// Get the length of a UTF-8 byte sequence representing a single codepoint
///
/// @param[in]  p  UTF-8 string.
///
/// @return Sequence length, 0 for empty string and 1 for non-UTF-8 byte
///         sequence.
int utf_ptr2len(const char_u *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
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

/*
 * Return length of UTF-8 character, obtained from the first byte.
 * "b" must be between 0 and 255!
 * Returns 1 for an invalid first byte value.
 */
int utf_byte2len(int b)
{
  return utf8len_tab[b];
}

/*
 * Get the length of UTF-8 byte sequence "p[size]".  Does not include any
 * following composing characters.
 * Returns 1 for "".
 * Returns 1 for an illegal byte sequence (also in incomplete byte seq.).
 * Returns number > "size" for an incomplete byte sequence.
 * Never returns zero.
 */
int utf_ptr2len_len(const char_u *p, int size)
{
  int len;
  int i;
  int m;

  len = utf8len_tab[*p];
  if (len == 1)
    return 1;           /* NUL, ascii or illegal lead byte */
  if (len > size)
    m = size;           /* incomplete byte sequence. */
  else
    m = len;
  for (i = 1; i < m; ++i)
    if ((p[i] & 0xc0) != 0x80)
      return 1;
  return len;
}

/// Return the number of bytes occupied by a UTF-8 character in a string
///
/// This includes following composing characters.
int utfc_ptr2len(const char_u *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  uint8_t b0 = (uint8_t)(*p);

  if (b0 == NUL) {
    return 0;
  }
  if (b0 < 0x80 && p[1] < 0x80) {  // be quick for ASCII
    return 1;
  }

  // Skip over first UTF-8 char, stopping at a NUL byte.
  int len = utf_ptr2len(p);

  // Check for illegal byte.
  if (len == 1 && b0 >= 0x80) {
    return 1;
  }

  // Check for composing characters.  We can handle only the first six, but
  // skip all of them (otherwise the cursor would get stuck).
  int prevlen = 0;
  for (;;) {
    if (p[len] < 0x80 || !UTF_COMPOSINGLIKE(p + prevlen, p + len)) {
      return len;
    }

    // Skip over composing char.
    prevlen = len;
    len += utf_ptr2len(p + len);
  }
}

/*
 * Return the number of bytes the UTF-8 encoding of the character at "p[size]"
 * takes.  This includes following composing characters.
 * Returns 0 for an empty string.
 * Returns 1 for an illegal char or an incomplete byte sequence.
 */
int utfc_ptr2len_len(const char_u *p, int size)
{
  int len;
  int prevlen;

  if (size < 1 || *p == NUL)
    return 0;
  if (p[0] < 0x80 && (size == 1 || p[1] < 0x80))   /* be quick for ASCII */
    return 1;

  /* Skip over first UTF-8 char, stopping at a NUL byte. */
  len = utf_ptr2len_len(p, size);

  /* Check for illegal byte and incomplete byte sequence. */
  if ((len == 1 && p[0] >= 0x80) || len > size)
    return 1;

  /*
   * Check for composing characters.  We can handle only the first six, but
   * skip all of them (otherwise the cursor would get stuck).
   */
  prevlen = 0;
  while (len < size) {
    int len_next_char;

    if (p[len] < 0x80)
      break;

    /*
     * Next character length should not go beyond size to ensure that
     * UTF_COMPOSINGLIKE(...) does not read beyond size.
     */
    len_next_char = utf_ptr2len_len(p + len, size - len);
    if (len_next_char > size - len)
      break;

    if (!UTF_COMPOSINGLIKE(p + prevlen, p + len))
      break;

    /* Skip over composing char */
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
/// @param c character to convert to \p buf
/// @param[out] buf UTF-8 string generated from \p c, does not add \0
/// @return Number of bytes (1-6). Does not include composing characters.
int utf_char2bytes(const int c, char_u *const buf)
{
  if (c < 0x80) {  // 7 bits
    buf[0] = c;
    return 1;
  } else if (c < 0x800) {  // 11 bits
    buf[0] = 0xc0 + ((unsigned)c >> 6);
    buf[1] = 0x80 + (c & 0x3f);
    return 2;
  } else if (c < 0x10000) {  // 16 bits
    buf[0] = 0xe0 + ((unsigned)c >> 12);
    buf[1] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[2] = 0x80 + (c & 0x3f);
    return 3;
  } else if (c < 0x200000) {  // 21 bits
    buf[0] = 0xf0 + ((unsigned)c >> 18);
    buf[1] = 0x80 + (((unsigned)c >> 12) & 0x3f);
    buf[2] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[3] = 0x80 + (c & 0x3f);
    return 4;
  } else if (c < 0x4000000) {  // 26 bits
    buf[0] = 0xf8 + ((unsigned)c >> 24);
    buf[1] = 0x80 + (((unsigned)c >> 18) & 0x3f);
    buf[2] = 0x80 + (((unsigned)c >> 12) & 0x3f);
    buf[3] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[4] = 0x80 + (c & 0x3f);
    return 5;
  } else {  // 31 bits
    buf[0] = 0xfc + ((unsigned)c >> 30);
    buf[1] = 0x80 + (((unsigned)c >> 24) & 0x3f);
    buf[2] = 0x80 + (((unsigned)c >> 18) & 0x3f);
    buf[3] = 0x80 + (((unsigned)c >> 12) & 0x3f);
    buf[4] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[5] = 0x80 + (c & 0x3f);
    return 6;
  }
}

/*
 * Return true if "c" is a composing UTF-8 character.  This means it will be
 * drawn on top of the preceding character.
 * Based on code from Markus Kuhn.
 */
bool utf_iscomposing(int c)
{
  return intable(combining, ARRAY_SIZE(combining), c);
}

/*
 * Return true for characters that can be displayed in a normal way.
 * Only for characters of 0x100 and above!
 */
bool utf_printable(int c)
{
#ifdef USE_WCHAR_FUNCTIONS
  /*
   * Assume the iswprint() library function works better than our own stuff.
   */
  return iswprint(c);
#else
  /* Sorted list of non-overlapping intervals.
   * 0xd800-0xdfff is reserved for UTF-16, actually illegal. */
  static struct interval nonprint[] =
  {
    {0x070f, 0x070f}, {0x180b, 0x180e}, {0x200b, 0x200f}, {0x202a, 0x202e},
    {0x206a, 0x206f}, {0xd800, 0xdfff}, {0xfeff, 0xfeff}, {0xfff9, 0xfffb},
    {0xfffe, 0xffff}
  };

  return !intable(nonprint, ARRAY_SIZE(nonprint), c);
#endif
}

/*
 * Get class of a Unicode character.
 * 0: white space
 * 1: punctuation
 * 2 or bigger: some class of word character.
 */
int utf_class(int c)
{
  /* sorted list of non-overlapping intervals */
  static struct clinterval {
    unsigned int first;
    unsigned int last;
    unsigned int class;
  } classes[] =
  {
    {0x037e, 0x037e, 1},                /* Greek question mark */
    {0x0387, 0x0387, 1},                /* Greek ano teleia */
    {0x055a, 0x055f, 1},                /* Armenian punctuation */
    {0x0589, 0x0589, 1},                /* Armenian full stop */
    {0x05be, 0x05be, 1},
    {0x05c0, 0x05c0, 1},
    {0x05c3, 0x05c3, 1},
    {0x05f3, 0x05f4, 1},
    {0x060c, 0x060c, 1},
    {0x061b, 0x061b, 1},
    {0x061f, 0x061f, 1},
    {0x066a, 0x066d, 1},
    {0x06d4, 0x06d4, 1},
    {0x0700, 0x070d, 1},                /* Syriac punctuation */
    {0x0964, 0x0965, 1},
    {0x0970, 0x0970, 1},
    {0x0df4, 0x0df4, 1},
    {0x0e4f, 0x0e4f, 1},
    {0x0e5a, 0x0e5b, 1},
    {0x0f04, 0x0f12, 1},
    {0x0f3a, 0x0f3d, 1},
    {0x0f85, 0x0f85, 1},
    {0x104a, 0x104f, 1},                /* Myanmar punctuation */
    {0x10fb, 0x10fb, 1},                /* Georgian punctuation */
    {0x1361, 0x1368, 1},                /* Ethiopic punctuation */
    {0x166d, 0x166e, 1},                /* Canadian Syl. punctuation */
    {0x1680, 0x1680, 0},
    {0x169b, 0x169c, 1},
    {0x16eb, 0x16ed, 1},
    {0x1735, 0x1736, 1},
    {0x17d4, 0x17dc, 1},                /* Khmer punctuation */
    {0x1800, 0x180a, 1},                /* Mongolian punctuation */
    {0x2000, 0x200b, 0},                /* spaces */
    {0x200c, 0x2027, 1},                /* punctuation and symbols */
    {0x2028, 0x2029, 0},
    {0x202a, 0x202e, 1},                /* punctuation and symbols */
    {0x202f, 0x202f, 0},
    {0x2030, 0x205e, 1},                /* punctuation and symbols */
    {0x205f, 0x205f, 0},
    {0x2060, 0x27ff, 1},                /* punctuation and symbols */
    {0x2070, 0x207f, 0x2070},           /* superscript */
    {0x2080, 0x2094, 0x2080},           /* subscript */
    {0x20a0, 0x27ff, 1},                /* all kinds of symbols */
    {0x2800, 0x28ff, 0x2800},           /* braille */
    {0x2900, 0x2998, 1},                /* arrows, brackets, etc. */
    {0x29d8, 0x29db, 1},
    {0x29fc, 0x29fd, 1},
    {0x2e00, 0x2e7f, 1},                /* supplemental punctuation */
    {0x3000, 0x3000, 0},                /* ideographic space */
    {0x3001, 0x3020, 1},                /* ideographic punctuation */
    {0x3030, 0x3030, 1},
    {0x303d, 0x303d, 1},
    {0x3040, 0x309f, 0x3040},           /* Hiragana */
    {0x30a0, 0x30ff, 0x30a0},           /* Katakana */
    {0x3300, 0x9fff, 0x4e00},           /* CJK Ideographs */
    {0xac00, 0xd7a3, 0xac00},           /* Hangul Syllables */
    {0xf900, 0xfaff, 0x4e00},           /* CJK Ideographs */
    {0xfd3e, 0xfd3f, 1},
    {0xfe30, 0xfe6b, 1},                /* punctuation forms */
    {0xff00, 0xff0f, 1},                /* half/fullwidth ASCII */
    {0xff1a, 0xff20, 1},                /* half/fullwidth ASCII */
    {0xff3b, 0xff40, 1},                /* half/fullwidth ASCII */
    {0xff5b, 0xff65, 1},                /* half/fullwidth ASCII */
    {0x20000, 0x2a6df, 0x4e00},         /* CJK Ideographs */
    {0x2a700, 0x2b73f, 0x4e00},         /* CJK Ideographs */
    {0x2b740, 0x2b81f, 0x4e00},         /* CJK Ideographs */
    {0x2f800, 0x2fa1f, 0x4e00},         /* CJK Ideographs */
  };
  int bot = 0;
  int top = ARRAY_SIZE(classes) - 1;
  int mid;

  /* First quick check for Latin1 characters, use 'iskeyword'. */
  if (c < 0x100) {
    if (c == ' ' || c == '\t' || c == NUL || c == 0xa0)
      return 0;             /* blank */
    if (vim_iswordc(c))
      return 2;             /* word character */
    return 1;               /* punctuation */
  }

  /* binary search in table */
  while (top >= bot) {
    mid = (bot + top) / 2;
    if (classes[mid].last < (unsigned int)c)
      bot = mid + 1;
    else if (classes[mid].first > (unsigned int)c)
      top = mid - 1;
    else
      return (int)classes[mid].class;
  }

  // emoji
  if (intable(emoji_all, ARRAY_SIZE(emoji_all), c)) {
    return 3;
  }

  /* most other characters are "word" characters */
  return 2;
}

bool utf_ambiguous_width(int c)
{
  return c >= 0x80 && (intable(ambiguous, ARRAY_SIZE(ambiguous), c)
                       || intable(emoji_all, ARRAY_SIZE(emoji_all), c));
}

/*
 * Generic conversion function for case operations.
 * Return the converted equivalent of "a", which is a UCS-4 character.  Use
 * the given conversion "table".  Uses binary search on "table".
 */
static int utf_convert(int a, const convertStruct *const table, size_t n_items)
{
  size_t start, mid, end;   /* indices into table */

  start = 0;
  end = n_items;
  while (start < end) {
    /* need to search further */
    mid = (end + start) / 2;
    if (table[mid].rangeEnd < a)
      start = mid + 1;
    else
      end = mid;
  }
  if (start < n_items
      && table[start].rangeStart <= a
      && a <= table[start].rangeEnd
      && (a - table[start].rangeStart) % table[start].step == 0)
    return a + table[start].offset;
  else
    return a;
}

/*
 * Return the folded-case equivalent of "a", which is a UCS-4 character.  Uses
 * simple case folding.
 */
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
  /* If 'casemap' contains "keepascii" use ASCII style toupper(). */
  if (a < 128 && (cmp_flags & CMP_KEEPASCII))
    return TOUPPER_ASC(a);

#if defined(__STDC_ISO_10646__)
  /* If towupper() is available and handles Unicode, use it. */
  if (!(cmp_flags & CMP_INTERNAL))
    return towupper(a);
#endif

  /* For characters below 128 use locale sensitive toupper(). */
  if (a < 128)
    return TOUPPER_LOC(a);

  /* For any other characters use the above mapping table. */
  return utf_convert(a, toUpper, ARRAY_SIZE(toUpper));
}

bool mb_islower(int a)
{
  // German sharp s is lower case but has no upper case equivalent.
  return (mb_toupper(a) != a) || a == 0xdf;
}

/// Return the lower-case equivalent of "a", which is a UCS-4 character.  Use
/// simple case folding.
int mb_tolower(int a)
{
  /* If 'casemap' contains "keepascii" use ASCII style tolower(). */
  if (a < 128 && (cmp_flags & CMP_KEEPASCII))
    return TOLOWER_ASC(a);

#if defined(__STDC_ISO_10646__)
  /* If towlower() is available and handles Unicode, use it. */
  if (!(cmp_flags & CMP_INTERNAL))
    return towlower(a);
#endif

  /* For characters below 128 use locale sensitive tolower(). */
  if (a < 128)
    return TOLOWER_LOC(a);

  /* For any other characters use the above mapping table. */
  return utf_convert(a, toLower, ARRAY_SIZE(toLower));
}

bool mb_isupper(int a)
{
  return mb_tolower(a) != a;
}

static int utf_strnicmp(const char_u *s1, const char_u *s2, size_t n1,
                        size_t n2)
{
  int c1, c2, cdiff;
  char_u buffer[6];

  for (;; ) {
    c1 = utf_safe_read_char_adv(&s1, &n1);
    c2 = utf_safe_read_char_adv(&s2, &n2);

    if (c1 <= 0 || c2 <= 0)
      break;

    if (c1 == c2)
      continue;

    cdiff = utf_fold(c1) - utf_fold(c2);
    if (cdiff != 0)
      return cdiff;
  }

  /* some string ended or has an incomplete/illegal character sequence */

  if (c1 == 0 || c2 == 0) {
    /* some string ended. shorter string is smaller */
    if (c1 == 0 && c2 == 0)
      return 0;
    return c1 == 0 ? -1 : 1;
  }

  /* Continue with bytewise comparison to produce some result that
   * would make comparison operations involving this function transitive.
   *
   * If only one string had an error, comparison should be made with
   * folded version of the other string. In this case it is enough
   * to fold just one character to determine the result of comparison. */

  if (c1 != -1 && c2 == -1) {
    n1 = utf_char2bytes(utf_fold(c1), buffer);
    s1 = buffer;
  } else if (c2 != -1 && c1 == -1) {
    n2 = utf_char2bytes(utf_fold(c2), buffer);
    s2 = buffer;
  }

  while (n1 > 0 && n2 > 0 && *s1 != NUL && *s2 != NUL) {
    cdiff = (int)(*s1) - (int)(*s2);
    if (cdiff != 0)
      return cdiff;

    s1++;
    s2++;
    n1--;
    n2--;
  }

  if (n1 > 0 && *s1 == NUL)
    n1 = 0;
  if (n2 > 0 && *s2 == NUL)
    n2 = 0;

  if (n1 == 0 && n2 == 0)
    return 0;
  return n1 == 0 ? -1 : 1;
}

#ifdef WIN32
#ifndef CP_UTF8
# define CP_UTF8 65001  /* magic number from winnls.h */
#endif

/// Reassigns `strw` to a new, allocated pointer to a UTF16 string.
int utf8_to_utf16(const char *str, wchar_t **strw)
  FUNC_ATTR_NONNULL_ALL
{
  ssize_t wchar_len = 0;

  // Compute the length needed to store the converted widechar string.
  wchar_len = MultiByteToWideChar(CP_UTF8,
                                  0,     // dwFlags: must be 0 for utf8
                                  str,   // lpMultiByteStr: string to convert
                                  -1,    // -1 => process up to NUL
                                  NULL,  // lpWideCharStr: converted string
                                  0);    // 0  => return length, don't convert
  if (wchar_len == 0) {
    return GetLastError();
  }

  ssize_t buf_sz = wchar_len * sizeof(wchar_t);

  if (buf_sz == 0) {
    *strw = NULL;
    return 0;
  }

  char *buf = xmalloc(buf_sz);
  char *pos = buf;

  int r = MultiByteToWideChar(CP_UTF8,
                              0,
                              str,
                              -1,
                              (wchar_t *)pos,
                              wchar_len);
  assert(r == wchar_len);
  if (r != wchar_len) {
    EMSG2("MultiByteToWideChar failed: %d", r);
  }
  *strw = (wchar_t *)pos;

  return 0;
}

/// Reassigns `str` to a new, allocated pointer to a UTF8 string.
int utf16_to_utf8(const wchar_t *strw, char **str)
  FUNC_ATTR_NONNULL_ALL
{
  // Compute the space required to store the string as UTF-8.
  DWORD utf8_len = WideCharToMultiByte(CP_UTF8,
                                       0,
                                       strw,
                                       -1,
                                       NULL,
                                       0,
                                       NULL,
                                       NULL);
  if (utf8_len == 0) {
    return GetLastError();
  }

  *str = xmallocz(utf8_len);

  // Convert to UTF-8.
  utf8_len = WideCharToMultiByte(CP_UTF8,
                                 0,
                                 strw,
                                 -1,
                                 *str,
                                 utf8_len,
                                 NULL,
                                 NULL);
  if (utf8_len == 0) {
    free(*str);
    *str = NULL;
    return GetLastError();
  }
  (*str)[utf8_len] = '\0';

  return 0;
}

#endif

/*
 * Version of strnicmp() that handles multi-byte characters.
 * Needed for Big5, Shift-JIS and UTF-8 encoding.  Other DBCS encodings can
 * probably use strnicmp(), because there are no ASCII characters in the
 * second byte.
 * Returns zero if s1 and s2 are equal (ignoring case), the difference between
 * two characters otherwise.
 */
int mb_strnicmp(const char_u *s1, const char_u *s2, const size_t nn)
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
  return mb_strnicmp((const char_u *)s1, (const char_u *)s2, MAXCOL);
}

/*
 * "g8": show bytes of the UTF-8 char under the cursor.  Doesn't matter what
 * 'encoding' has been set to.
 */
void show_utf8(void)
{
  int len;
  int rlen = 0;
  char_u      *line;
  int clen;
  int i;

  /* Get the byte length of the char under the cursor, including composing
   * characters. */
  line = get_cursor_pos_ptr();
  len = utfc_ptr2len(line);
  if (len == 0) {
    MSG("NUL");
    return;
  }

  clen = 0;
  for (i = 0; i < len; ++i) {
    if (clen == 0) {
      /* start of (composing) character, get its length */
      if (i > 0) {
        STRCPY(IObuff + rlen, "+ ");
        rlen += 2;
      }
      clen = utf_ptr2len(line + i);
    }
    sprintf((char *)IObuff + rlen, "%02x ",
        (line[i] == NL) ? NUL : line[i]);          /* NUL is stored as NL */
    --clen;
    rlen += (int)STRLEN(IObuff + rlen);
    if (rlen > IOSIZE - 20)
      break;
  }

  msg(IObuff);
}

/// Return offset from "p" to the first byte of the character it points into.
/// If "p" points to the NUL at the end of the string return 0.
/// Returns 0 when already at the first byte of a character.
int utf_head_off(const char_u *base, const char_u *p)
{
  int c;
  int len;

  if (*p < 0x80)                /* be quick for ASCII */
    return 0;

  /* Skip backwards over trailing bytes: 10xx.xxxx
   * Skip backwards again if on a composing char. */
  const char_u *q;
  for (q = p;; --q) {
    /* Move s to the last byte of this char. */
    const char_u *s;
    for (s = q; (s[1] & 0xc0) == 0x80; ++s) {}

    /* Move q to the first byte of this char. */
    while (q > base && (*q & 0xc0) == 0x80)
      --q;
    /* Check for illegal sequence. Do allow an illegal byte after where we
     * started. */
    len = utf8len_tab[*q];
    if (len != (int)(s - q + 1) && len != (int)(p - q + 1))
      return 0;

    if (q <= base)
      break;

    c = utf_ptr2char(q);
    if (utf_iscomposing(c))
      continue;

    if (arabic_maycombine(c)) {
      /* Advance to get a sneak-peak at the next char */
      const char_u *j = q;
      --j;
      /* Move j to the first byte of this char. */
      while (j > base && (*j & 0xc0) == 0x80)
        --j;
      if (arabic_combine(utf_ptr2char(j), c))
        continue;
    }
    break;
  }

  return (int)(p - q);
}

/// Copy a character, advancing the pointers
///
/// @param[in,out]  fp  Source of the character to copy.
/// @param[in,out]  tp  Destination to copy to.
void mb_copy_char(const char_u **const fp, char_u **const tp)
{
  const size_t l = (size_t)utfc_ptr2len(*fp);

  memmove(*tp, *fp, l);
  *tp += l;
  *fp += l;
}

/*
 * Return the offset from "p" to the first byte of a character.  When "p" is
 * at the start of a character 0 is returned, otherwise the offset to the next
 * character.  Can start anywhere in a stream of bytes.
 */
int mb_off_next(char_u *base, char_u *p)
{
  int i;
  int j;

  if (*p < 0x80) {              // be quick for ASCII
    return 0;
  }

  // Find the next character that isn't 10xx.xxxx
  for (i = 0; (p[i] & 0xc0) == 0x80; i++) {}
  if (i > 0) {
    // Check for illegal sequence.
    for (j = 0; p - j > base; j++) {
      if ((p[-j] & 0xc0) != 0x80) {
        break;
      }
    }
    if (utf8len_tab[p[-j]] != i + j) {
      return 0;
    }
  }
  return i;
}

/*
 * Return the offset from "p" to the last byte of the character it points
 * into.  Can start anywhere in a stream of bytes.
 */
int mb_tail_off(char_u *base, char_u *p)
{
  int i;
  int j;

  if (*p == NUL)
    return 0;

  // Find the last character that is 10xx.xxxx
  for (i = 0; (p[i + 1] & 0xc0) == 0x80; i++) {}

  // Check for illegal sequence.
  for (j = 0; p - j > base; j++) {
    if ((p[-j] & 0xc0) != 0x80) {
      break;
    }
  }

  if (utf8len_tab[p[-j]] != i + j + 1) {
    return 0;
  }
  return i;
}

/*
 * Find the next illegal byte sequence.
 */
void utf_find_illegal(void)
{
  pos_T pos = curwin->w_cursor;
  char_u      *p;
  int len;
  vimconv_T vimconv;
  char_u      *tofree = NULL;

  vimconv.vc_type = CONV_NONE;
  if (enc_canon_props(curbuf->b_p_fenc) & ENC_8BIT) {
    // 'encoding' is "utf-8" but we are editing a 8-bit encoded file,
    // possibly a utf-8 file with illegal bytes.  Setup for conversion
    // from utf-8 to 'fileencoding'.
    convert_setup(&vimconv, p_enc, curbuf->b_p_fenc);
  }

  curwin->w_cursor.coladd = 0;
  for (;; ) {
    p = get_cursor_pos_ptr();
    if (vimconv.vc_type != CONV_NONE) {
      xfree(tofree);
      tofree = string_convert(&vimconv, p, NULL);
      if (tofree == NULL)
        break;
      p = tofree;
    }

    while (*p != NUL) {
      /* Illegal means that there are not enough trail bytes (checked by
       * utf_ptr2len()) or too many of them (overlong sequence). */
      len = utf_ptr2len(p);
      if (*p >= 0x80 && (len == 1
            || utf_char2len(utf_ptr2char(p)) != len)) {
        if (vimconv.vc_type == CONV_NONE)
          curwin->w_cursor.col += (colnr_T)(p - get_cursor_pos_ptr());
        else {
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
    if (curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count)
      break;
    ++curwin->w_cursor.lnum;
    curwin->w_cursor.col = 0;
  }

  /* didn't find it: don't move and beep */
  curwin->w_cursor = pos;
  beep_flush();

theend:
  xfree(tofree);
  convert_setup(&vimconv, NULL, NULL);
}

/*
 * If the cursor moves on an trail byte, set the cursor on the lead byte.
 * Thus it moves left if necessary.
 */
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
    char_u *p = ml_get_buf(win->w_buffer, win->w_cursor.lnum, false);
    colnr_T len = (colnr_T)STRLEN(p);

    // Empty line or invalid column?
    if (len == 0 || oldcol < 0) {
      win->w_cursor.col = 0;
    } else {
      // Cursor column too big for line?
      if (oldcol > len) {
        win->w_cursor.col = len - 1;
      }
      // Move the cursor to the head byte.
      win->w_cursor.col -= (*mb_head_off)(p, p + win->w_cursor.col);
    }

    // Reset `coladd` when the cursor would be on the right half of a
    // double-wide character.
    if (win->w_cursor.coladd == 1 && p[win->w_cursor.col] != TAB
        && vim_isprintc((*mb_ptr2char)(p + win->w_cursor.col))
        && ptr2cells(p + win->w_cursor.col) > 1) {
      win->w_cursor.coladd = 0;
    }
  }
}

/*
 * Return a pointer to the character before "*p", if there is one.
 */
char_u * mb_prevptr(
    char_u *line,           /* start of the string */
    char_u *p
    )
{
  if (p > line) {
    MB_PTR_BACK(line, p);
  }
  return p;
}

/*
 * Return the character length of "str".  Each multi-byte character (with
 * following composing characters) counts as one.
 */
int mb_charlen(char_u *str)
{
  char_u      *p = str;
  int count;

  if (p == NULL)
    return 0;

  for (count = 0; *p != NUL; count++)
    p += (*mb_ptr2len)(p);

  return count;
}

/*
 * Like mb_charlen() but for a string with specified length.
 */
int mb_charlen_len(char_u *str, int len)
{
  char_u      *p = str;
  int count;

  for (count = 0; *p != NUL && p < str + len; count++)
    p += (*mb_ptr2len)(p);

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

  // Must translate K_SPECIAL KS_SPECIAL KE_FILLER to K_SPECIAL and CSI
  // KS_EXTRA KE_CSI to CSI.
  // Maximum length of a utf-8 character is 4 bytes.
  for (size_t str_idx = 0; str[str_idx] != NUL && buf_idx < 4; str_idx++) {
    if (str[str_idx] == K_SPECIAL
        && str[str_idx + 1] == KS_SPECIAL
        && str[str_idx + 2] == KE_FILLER) {
      buf[buf_idx++] = (char)K_SPECIAL;
      str_idx += 2;
    } else if ((str[str_idx] == K_SPECIAL)
               && str[str_idx + 1] == KS_EXTRA
               && str[str_idx + 2] == KE_CSI) {
      buf[buf_idx++] = (char)CSI;
      str_idx += 2;
    } else if (str[str_idx] == K_SPECIAL) {
      break;  // A special key can't be a multibyte char.
    } else {
      buf[buf_idx++] = (char)str[str_idx];
    }
    buf[buf_idx] = NUL;

    // Return a multi-byte character if it's found.  An illegal sequence
    // will result in a 1 here.
    if (utf_ptr2len((const char_u *)buf) > 1) {
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

/*
 * Return true if the character at "row"/"col" on the screen is the left side
 * of a double-width character.
 * Caller must make sure "row" and "col" are not invalid!
 */
bool mb_lefthalve(int row, int col)
{
  return (*mb_off2cells)(LineOffset[row] + col,
      LineOffset[row] + screen_Columns) > 1;
}

/*
 * Correct a position on the screen, if it's the right half of a double-wide
 * char move it to the left half.  Returns the corrected column.
 */
int mb_fix_col(int col, int row)
{
  col = check_col(col);
  row = check_row(row);
  if (ScreenLines != NULL && col > 0
      && ScreenLines[LineOffset[row] + col][0] == 0) {
    return col - 1;
  }
  return col;
}


/*
 * Skip the Vim specific head of a 'encoding' name.
 */
char_u * enc_skip(char_u *p)
{
  if (STRNCMP(p, "2byte-", 6) == 0)
    return p + 6;
  if (STRNCMP(p, "8bit-", 5) == 0)
    return p + 5;
  return p;
}

/*
 * Find the canonical name for encoding "enc".
 * When the name isn't recognized, returns "enc" itself, but with all lower
 * case characters and '_' replaced with '-'.
 * Returns an allocated string.
 */
char_u *enc_canonize(char_u *enc) FUNC_ATTR_NONNULL_RET
{
  char_u      *p, *s;
  int i;

  if (STRCMP(enc, "default") == 0) {
    // Use the default encoding as found by set_init_1().
    return vim_strsave(fenc_default);
  }

  /* copy "enc" to allocated memory, with room for two '-' */
  char_u *r = xmalloc(STRLEN(enc) + 3);
  /* Make it all lower case and replace '_' with '-'. */
  p = r;
  for (s = enc; *s != NUL; ++s) {
    if (*s == '_')
      *p++ = '-';
    else
      *p++ = TOLOWER_ASC(*s);
  }
  *p = NUL;

  /* Skip "2byte-" and "8bit-". */
  p = enc_skip(r);

  /* Change "microsoft-cp" to "cp".  Used in some spell files. */
  if (STRNCMP(p, "microsoft-cp", 12) == 0)
    STRMOVE(p, p + 10);

  /* "iso8859" -> "iso-8859" */
  if (STRNCMP(p, "iso8859", 7) == 0) {
    STRMOVE(p + 4, p + 3);
    p[3] = '-';
  }

  /* "iso-8859n" -> "iso-8859-n" */
  if (STRNCMP(p, "iso-8859", 8) == 0 && p[8] != '-') {
    STRMOVE(p + 9, p + 8);
    p[8] = '-';
  }

  /* "latin-N" -> "latinN" */
  if (STRNCMP(p, "latin-", 6) == 0)
    STRMOVE(p + 5, p + 6);

  if (enc_canon_search(p) >= 0) {
    /* canonical name can be used unmodified */
    if (p != r)
      STRMOVE(r, p);
  } else if ((i = enc_alias_search(p)) >= 0) {
    /* alias recognized, get canonical name */
    xfree(r);
    r = vim_strsave((char_u *)enc_canon_table[i].name);
  }
  return r;
}

/*
 * Search for an encoding alias of "name".
 * Returns -1 when not found.
 */
static int enc_alias_search(char_u *name)
{
  int i;

  for (i = 0; enc_alias_table[i].name != NULL; ++i)
    if (STRCMP(name, enc_alias_table[i].name) == 0)
      return enc_alias_table[i].canon;
  return -1;
}


#ifdef HAVE_LANGINFO_H
# include <langinfo.h>
#endif

/*
 * Get the canonicalized encoding of the current locale.
 * Returns an allocated string when successful, NULL when not.
 */
char_u * enc_locale(void)
{
  int i;
  char buf[50];

  const char *s;
# ifdef HAVE_NL_LANGINFO_CODESET
  if (!(s = nl_langinfo(CODESET)) || *s == NUL)
# endif
  {
#  if defined(HAVE_LOCALE_H)
    if (!(s = setlocale(LC_CTYPE, NULL)) || *s == NUL)
#  endif
    {
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
  const char *p = (char *)vim_strchr((char_u *)s, '.');
  if (p != NULL) {
    if (p > s + 2 && !STRNICMP(p + 1, "EUC", 3)
        && !isalnum((int)p[4]) && p[4] != '-' && p[-3] == '_') {
      // Copy "XY.EUC" to "euc-XY" to buf[10].
      memmove(buf, "euc-", 4);
      buf[4] = (ASCII_ISALNUM(p[-2]) ? TOLOWER_ASC(p[-2]) : 0);
      buf[5] = (ASCII_ISALNUM(p[-1]) ? TOLOWER_ASC(p[-1]) : 0);
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
        buf[i] = TOLOWER_ASC(s[i]);
      } else {
        break;
      }
    }
    buf[i] = NUL;
  }

  return enc_canonize((char_u *)buf);
}

# if defined(USE_ICONV)


/*
 * Call iconv_open() with a check if iconv() works properly (there are broken
 * versions).
 * Returns (void *)-1 if failed.
 * (should return iconv_t, but that causes problems with prototypes).
 */
void * my_iconv_open(char_u *to, char_u *from)
{
  iconv_t fd;
#define ICONV_TESTLEN 400
  char_u tobuf[ICONV_TESTLEN];
  char        *p;
  size_t tolen;
  static WorkingStatus iconv_working = kUnknown;

  if (iconv_working == kBroken)
    return (void *)-1;          /* detected a broken iconv() previously */

#ifdef DYNAMIC_ICONV
  // Check if the iconv.dll can be found.
  if (!iconv_enabled(true)) {
    return (void *)-1;
  }
#endif

  fd = iconv_open((char *)enc_skip(to), (char *)enc_skip(from));

  if (fd != (iconv_t)-1 && iconv_working == kUnknown) {
    /*
     * Do a dummy iconv() call to check if it actually works.  There is a
     * version of iconv() on Linux that is broken.  We can't ignore it,
     * because it's wide-spread.  The symptoms are that after outputting
     * the initial shift state the "to" pointer is NULL and conversion
     * stops for no apparent reason after about 8160 characters.
     */
    p = (char *)tobuf;
    tolen = ICONV_TESTLEN;
    (void)iconv(fd, NULL, NULL, &p, &tolen);
    if (p == NULL) {
      iconv_working = kBroken;
      iconv_close(fd);
      fd = (iconv_t)-1;
    } else
      iconv_working = kWorking;
  }

  return (void *)fd;
}

/*
 * Convert the string "str[slen]" with iconv().
 * If "unconvlenp" is not NULL handle the string ending in an incomplete
 * sequence and set "*unconvlenp" to the length of it.
 * Returns the converted string in allocated memory.  NULL for an error.
 * If resultlenp is not NULL, sets it to the result length in bytes.
 */
static char_u *iconv_string(const vimconv_T *const vcp, char_u *str,
                            size_t slen, size_t *unconvlenp, size_t *resultlenp)
{
  const char  *from;
  size_t fromlen;
  char        *to;
  size_t tolen;
  size_t len = 0;
  size_t done = 0;
  char_u      *result = NULL;
  char_u      *p;
  int l;

  from = (char *)str;
  fromlen = slen;
  for (;; ) {
    if (len == 0 || ICONV_ERRNO == ICONV_E2BIG) {
      /* Allocate enough room for most conversions.  When re-allocating
       * increase the buffer size. */
      len = len + fromlen * 2 + 40;
      p = xmalloc(len);
      if (done > 0)
        memmove(p, result, done);
      xfree(result);
      result = p;
    }

    to = (char *)result + done;
    tolen = len - done - 2;
    /* Avoid a warning for systems with a wrong iconv() prototype by
     * casting the second argument to void *. */
    if (iconv(vcp->vc_fd, (void *)&from, &fromlen, &to, &tolen) != SIZE_MAX) {
      /* Finished, append a NUL. */
      *to = NUL;
      break;
    }

    /* Check both ICONV_EINVAL and EINVAL, because the dynamically loaded
     * iconv library may use one of them. */
    if (!vcp->vc_fail && unconvlenp != NULL
        && (ICONV_ERRNO == ICONV_EINVAL || ICONV_ERRNO == EINVAL)) {
      /* Handle an incomplete sequence at the end. */
      *to = NUL;
      *unconvlenp = fromlen;
      break;
    }
    /* Check both ICONV_EILSEQ and EILSEQ, because the dynamically loaded
     * iconv library may use one of them. */
    else if (!vcp->vc_fail
        && (ICONV_ERRNO == ICONV_EILSEQ || ICONV_ERRNO == EILSEQ
          || ICONV_ERRNO == ICONV_EINVAL || ICONV_ERRNO == EINVAL)) {
      /* Can't convert: insert a '?' and skip a character.  This assumes
       * conversion from 'encoding' to something else.  In other
       * situations we don't know what to skip anyway. */
      *to++ = '?';
      if ((*mb_ptr2cells)((char_u *)from) > 1)
        *to++ = '?';
      l = utfc_ptr2len_len((const char_u *)from, (int)fromlen);
      from += l;
      fromlen -= l;
    } else if (ICONV_ERRNO != ICONV_E2BIG) {
      /* conversion failed */
      xfree(result);
      result = NULL;
      break;
    }
    /* Not enough room or skipping illegal sequence. */
    done = to - (char *)result;
  }

  if (resultlenp != NULL && result != NULL)
    *resultlenp = (size_t)(to - (char *)result);
  return result;
}

#  if defined(DYNAMIC_ICONV)
/*
 * Dynamically load the "iconv.dll" on Win32.
 */

#ifndef DYNAMIC_ICONV       /* just generating prototypes */
# define HINSTANCE int
#endif
static HINSTANCE hIconvDLL = 0;
static HINSTANCE hMsvcrtDLL = 0;

#  ifndef DYNAMIC_ICONV_DLL
#   define DYNAMIC_ICONV_DLL "iconv.dll"
#   define DYNAMIC_ICONV_DLL_ALT "libiconv-2.dll"
#  endif
#  ifndef DYNAMIC_MSVCRT_DLL
#   define DYNAMIC_MSVCRT_DLL "msvcrt.dll"
#  endif

/*
 * Get the address of 'funcname' which is imported by 'hInst' DLL.
 */
static void * get_iconv_import_func(HINSTANCE hInst,
    const char *funcname)
{
  PBYTE pImage = (PBYTE)hInst;
  PIMAGE_DOS_HEADER pDOS = (PIMAGE_DOS_HEADER)hInst;
  PIMAGE_NT_HEADERS pPE;
  PIMAGE_IMPORT_DESCRIPTOR pImpDesc;
  PIMAGE_THUNK_DATA pIAT;                   /* Import Address Table */
  PIMAGE_THUNK_DATA pINT;                   /* Import Name Table */
  PIMAGE_IMPORT_BY_NAME pImpName;

  if (pDOS->e_magic != IMAGE_DOS_SIGNATURE)
    return NULL;
  pPE = (PIMAGE_NT_HEADERS)(pImage + pDOS->e_lfanew);
  if (pPE->Signature != IMAGE_NT_SIGNATURE)
    return NULL;
  pImpDesc = (PIMAGE_IMPORT_DESCRIPTOR)(pImage
      + pPE->OptionalHeader.DataDirectory[
      IMAGE_DIRECTORY_ENTRY_IMPORT]
      .VirtualAddress);
  for (; pImpDesc->FirstThunk; ++pImpDesc) {
    if (!pImpDesc->OriginalFirstThunk)
      continue;
    pIAT = (PIMAGE_THUNK_DATA)(pImage + pImpDesc->FirstThunk);
    pINT = (PIMAGE_THUNK_DATA)(pImage + pImpDesc->OriginalFirstThunk);
    for (; pIAT->u1.Function; ++pIAT, ++pINT) {
      if (IMAGE_SNAP_BY_ORDINAL(pINT->u1.Ordinal))
        continue;
      pImpName = (PIMAGE_IMPORT_BY_NAME)(pImage
          + (UINT_PTR)(pINT->u1.AddressOfData));
      if (strcmp(pImpName->Name, funcname) == 0)
        return (void *)pIAT->u1.Function;
    }
  }
  return NULL;
}

// Load library "name".
HINSTANCE vimLoadLib(char *name)
{
  HINSTANCE dll = NULL;

  // NOTE: Do not use mch_dirname() and mch_chdir() here, they may call
  //       vimLoadLib() recursively, which causes a stack overflow.
  wchar_t old_dirw[MAXPATHL];

  // Path to exe dir.
  char *buf = xstrdup((char *)get_vim_var_str(VV_PROGPATH));
  // ptrdiff_t len = ;
  // assert(len > 0);
  buf[path_tail_with_sep(buf) - buf] = '\0';

  if (GetCurrentDirectoryW(MAXPATHL, old_dirw) != 0) {
    // Change directory to where the executable is, both to make
    // sure we find a .dll there and to avoid looking for a .dll
    // in the current directory.
    SetCurrentDirectory((LPCSTR)buf);
    // TODO(justinmk): use uv_dlopen instead. see os_libcall
    dll = LoadLibrary(name);
    SetCurrentDirectoryW(old_dirw);
  }

  return dll;
}


/*
 * Try opening the iconv.dll and return TRUE if iconv() can be used.
 */
bool iconv_enabled(bool verbose)
{
  if (hIconvDLL != 0 && hMsvcrtDLL != 0)
    return true;
  hIconvDLL = vimLoadLib(DYNAMIC_ICONV_DLL);
  if (hIconvDLL == 0)           /* sometimes it's called libiconv.dll */
    hIconvDLL = vimLoadLib(DYNAMIC_ICONV_DLL_ALT);
  if (hIconvDLL != 0)
    hMsvcrtDLL = vimLoadLib(DYNAMIC_MSVCRT_DLL);
  if (hIconvDLL == 0 || hMsvcrtDLL == 0) {
    /* Only give the message when 'verbose' is set, otherwise it might be
     * done whenever a conversion is attempted. */
    if (verbose && p_verbose > 0) {
      verbose_enter();
      EMSG2(_(e_loadlib),
          hIconvDLL == 0 ? DYNAMIC_ICONV_DLL : DYNAMIC_MSVCRT_DLL);
      verbose_leave();
    }
    iconv_end();
    return false;
  }

  iconv       = (void *)GetProcAddress(hIconvDLL, "libiconv");
  iconv_open  = (void *)GetProcAddress(hIconvDLL, "libiconv_open");
  iconv_close = (void *)GetProcAddress(hIconvDLL, "libiconv_close");
  iconvctl    = (void *)GetProcAddress(hIconvDLL, "libiconvctl");
  iconv_errno = get_iconv_import_func(hIconvDLL, "_errno");
  if (iconv_errno == NULL)
    iconv_errno = (void *)GetProcAddress(hMsvcrtDLL, "_errno");
  if (iconv == NULL || iconv_open == NULL || iconv_close == NULL
      || iconvctl == NULL || iconv_errno == NULL) {
    iconv_end();
    if (verbose && p_verbose > 0) {
      verbose_enter();
      EMSG2(_(e_loadfunc), "for libiconv");
      verbose_leave();
    }
    return false;
  }
  return true;
}

void iconv_end(void)
{
  if (hIconvDLL != 0) {
    // TODO(justinmk): use uv_dlclose instead.
    FreeLibrary(hIconvDLL);
  }
  if (hMsvcrtDLL != 0) {
    FreeLibrary(hMsvcrtDLL);
  }
  hIconvDLL = 0;
  hMsvcrtDLL = 0;
}

#  endif /* DYNAMIC_ICONV */
# endif /* USE_ICONV */




/*
 * Setup "vcp" for conversion from "from" to "to".
 * The names must have been made canonical with enc_canonize().
 * vcp->vc_type must have been initialized to CONV_NONE.
 * Note: cannot be used for conversion from/to ucs-2 and ucs-4 (will use utf-8
 * instead).
 * Afterwards invoke with "from" and "to" equal to NULL to cleanup.
 * Return FAIL when conversion is not supported, OK otherwise.
 */
int convert_setup(vimconv_T *vcp, char_u *from, char_u *to)
{
  return convert_setup_ext(vcp, from, true, to, true);
}

/*
 * As convert_setup(), but only when from_unicode_is_utf8 is TRUE will all
 * "from" unicode charsets be considered utf-8.  Same for "to".
 */
int convert_setup_ext(vimconv_T *vcp, char_u *from, bool from_unicode_is_utf8,
                      char_u *to, bool to_unicode_is_utf8)
{
  int from_prop;
  int to_prop;
  int from_is_utf8;
  int to_is_utf8;

  /* Reset to no conversion. */
# ifdef USE_ICONV
  if (vcp->vc_type == CONV_ICONV && vcp->vc_fd != (iconv_t)-1)
    iconv_close(vcp->vc_fd);
# endif
  *vcp = (vimconv_T)MBYTE_NONE_CONV;

  /* No conversion when one of the names is empty or they are equal. */
  if (from == NULL || *from == NUL || to == NULL || *to == NUL
      || STRCMP(from, to) == 0)
    return OK;

  from_prop = enc_canon_props(from);
  to_prop = enc_canon_props(to);
  if (from_unicode_is_utf8)
    from_is_utf8 = from_prop & ENC_UNICODE;
  else
    from_is_utf8 = from_prop == ENC_UNICODE;
  if (to_unicode_is_utf8)
    to_is_utf8 = to_prop & ENC_UNICODE;
  else
    to_is_utf8 = to_prop == ENC_UNICODE;

  if ((from_prop & ENC_LATIN1) && to_is_utf8) {
    /* Internal latin1 -> utf-8 conversion. */
    vcp->vc_type = CONV_TO_UTF8;
    vcp->vc_factor = 2;         /* up to twice as long */
  } else if ((from_prop & ENC_LATIN9) && to_is_utf8) {
    /* Internal latin9 -> utf-8 conversion. */
    vcp->vc_type = CONV_9_TO_UTF8;
    vcp->vc_factor = 3;         /* up to three as long (euro sign) */
  } else if (from_is_utf8 && (to_prop & ENC_LATIN1)) {
    /* Internal utf-8 -> latin1 conversion. */
    vcp->vc_type = CONV_TO_LATIN1;
  } else if (from_is_utf8 && (to_prop & ENC_LATIN9)) {
    /* Internal utf-8 -> latin9 conversion. */
    vcp->vc_type = CONV_TO_LATIN9;
  }
# ifdef USE_ICONV
  else {
    /* Use iconv() for conversion. */
    vcp->vc_fd = (iconv_t)my_iconv_open(
        to_is_utf8 ? (char_u *)"utf-8" : to,
        from_is_utf8 ? (char_u *)"utf-8" : from);
    if (vcp->vc_fd != (iconv_t)-1) {
      vcp->vc_type = CONV_ICONV;
      vcp->vc_factor = 4;       /* could be longer too... */
    }
  }
# endif
  if (vcp->vc_type == CONV_NONE)
    return FAIL;

  return OK;
}

/*
 * Convert text "ptr[*lenp]" according to "vcp".
 * Returns the result in allocated memory and sets "*lenp".
 * When "lenp" is NULL, use NUL terminated strings.
 * Illegal chars are often changed to "?", unless vcp->vc_fail is set.
 * When something goes wrong, NULL is returned and "*lenp" is unchanged.
 */
char_u *string_convert(const vimconv_T *const vcp, char_u *ptr, size_t *lenp)
{
  return string_convert_ext(vcp, ptr, lenp, NULL);
}

/*
 * Like string_convert(), but when "unconvlenp" is not NULL and there are is
 * an incomplete sequence at the end it is not converted and "*unconvlenp" is
 * set to the number of remaining bytes.
 */
char_u * string_convert_ext(const vimconv_T *const vcp, char_u *ptr,
                            size_t *lenp, size_t *unconvlenp)
{
  char_u      *retval = NULL;
  char_u      *d;
  int l;
  int c;

  size_t len;
  if (lenp == NULL)
    len = STRLEN(ptr);
  else
    len = *lenp;
  if (len == 0)
    return vim_strsave((char_u *)"");

  switch (vcp->vc_type) {
    case CONV_TO_UTF8:            /* latin1 to utf-8 conversion */
      retval = xmalloc(len * 2 + 1);
      d = retval;
      for (size_t i = 0; i < len; ++i) {
        c = ptr[i];
        if (c < 0x80)
          *d++ = c;
        else {
          *d++ = 0xc0 + ((unsigned)c >> 6);
          *d++ = 0x80 + (c & 0x3f);
        }
      }
      *d = NUL;
      if (lenp != NULL)
        *lenp = (size_t)(d - retval);
      break;

    case CONV_9_TO_UTF8:          /* latin9 to utf-8 conversion */
      retval = xmalloc(len * 3 + 1);
      d = retval;
      for (size_t i = 0; i < len; ++i) {
        c = ptr[i];
        switch (c) {
          case 0xa4: c = 0x20ac; break;                 /* euro */
          case 0xa6: c = 0x0160; break;                 /* S hat */
          case 0xa8: c = 0x0161; break;                 /* S -hat */
          case 0xb4: c = 0x017d; break;                 /* Z hat */
          case 0xb8: c = 0x017e; break;                 /* Z -hat */
          case 0xbc: c = 0x0152; break;                 /* OE */
          case 0xbd: c = 0x0153; break;                 /* oe */
          case 0xbe: c = 0x0178; break;                 /* Y */
        }
        d += utf_char2bytes(c, d);
      }
      *d = NUL;
      if (lenp != NULL)
        *lenp = (size_t)(d - retval);
      break;

    case CONV_TO_LATIN1:          /* utf-8 to latin1 conversion */
    case CONV_TO_LATIN9:          /* utf-8 to latin9 conversion */
      retval = xmalloc(len + 1);
      d = retval;
      for (size_t i = 0; i < len; ++i) {
        l = utf_ptr2len_len(ptr + i, len - i);
        if (l == 0)
          *d++ = NUL;
        else if (l == 1) {
          uint8_t l_w = utf8len_tab_zero[ptr[i]];

          if (l_w == 0) {
            /* Illegal utf-8 byte cannot be converted */
            xfree(retval);
            return NULL;
          }
          if (unconvlenp != NULL && l_w > len - i) {
            /* Incomplete sequence at the end. */
            *unconvlenp = len - i;
            break;
          }
          *d++ = ptr[i];
        } else {
          c = utf_ptr2char(ptr + i);
          if (vcp->vc_type == CONV_TO_LATIN9)
            switch (c) {
              case 0x20ac: c = 0xa4; break;                     /* euro */
              case 0x0160: c = 0xa6; break;                     /* S hat */
              case 0x0161: c = 0xa8; break;                     /* S -hat */
              case 0x017d: c = 0xb4; break;                     /* Z hat */
              case 0x017e: c = 0xb8; break;                     /* Z -hat */
              case 0x0152: c = 0xbc; break;                     /* OE */
              case 0x0153: c = 0xbd; break;                     /* oe */
              case 0x0178: c = 0xbe; break;                     /* Y */
              case 0xa4:
              case 0xa6:
              case 0xa8:
              case 0xb4:
              case 0xb8:
              case 0xbc:
              case 0xbd:
              case 0xbe: c = 0x100; break;                   /* not in latin9 */
            }
          if (!utf_iscomposing(c)) {              /* skip composing chars */
            if (c < 0x100)
              *d++ = c;
            else if (vcp->vc_fail) {
              xfree(retval);
              return NULL;
            } else {
              *d++ = 0xbf;
              if (utf_char2cells(c) > 1)
                *d++ = '?';
            }
          }
          i += l - 1;
        }
      }
      *d = NUL;
      if (lenp != NULL)
        *lenp = (size_t)(d - retval);
      break;

# ifdef USE_ICONV
    case CONV_ICONV:              /* conversion with vcp->vc_fd */
      retval = iconv_string(vcp, ptr, len, unconvlenp, lenp);
      break;
# endif
  }

  return retval;
}

// Check bounds for column number
static int check_col(int col)
{
  if (col < 0)
    return 0;
  if (col >= screen_Columns)
    return screen_Columns - 1;
  return col;
}

// Check bounds for row number
static int check_row(int row)
{
  if (row < 0)
    return 0;
  if (row >= screen_Rows)
    return screen_Rows - 1;
  return row;
}
