/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 * Multibyte extensions partly by Sung-Hoon Baek
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * mbyte.c: Code specifically for handling multi-byte characters.
 *
 * The encoding used in the core is set with 'encoding'.  When 'encoding' is
 * changed, the following four variables are set (for speed).
 * Currently these types of character encodings are supported:
 *
 * "enc_dbcs"	    When non-zero it tells the type of double byte character
 *		    encoding (Chinese, Korean, Japanese, etc.).
 *		    The cell width on the display is equal to the number of
 *		    bytes.  (exception: DBCS_JPNU with first byte 0x8e)
 *		    Recognizing the first or second byte is difficult, it
 *		    requires checking a byte sequence from the start.
 * "enc_utf8"	    When TRUE use Unicode characters in UTF-8 encoding.
 *		    The cell width on the display needs to be determined from
 *		    the character value.
 *		    Recognizing bytes is easy: 0xxx.xxxx is a single-byte
 *		    char, 10xx.xxxx is a trailing byte, 11xx.xxxx is a leading
 *		    byte of a multi-byte character.
 *		    To make things complicated, up to six composing characters
 *		    are allowed.  These are drawn on top of the first char.
 *		    For most editing the sequence of bytes with composing
 *		    characters included is considered to be one character.
 * "enc_unicode"    When 2 use 16-bit Unicode characters (or UTF-16).
 *		    When 4 use 32-but Unicode characters.
 *		    Internally characters are stored in UTF-8 encoding to
 *		    avoid NUL bytes.  Conversion happens when doing I/O.
 *		    "enc_utf8" will also be TRUE.
 *
 * "has_mbyte" is set when "enc_dbcs" or "enc_utf8" is non-zero.
 *
 * If none of these is TRUE, 8-bit bytes are used for a character.  The
 * encoding isn't currently specified (TODO).
 *
 * 'encoding' specifies the encoding used in the core.  This is in registers,
 * text manipulation, buffers, etc.  Conversion has to be done when characters
 * in another encoding are received or send:
 *
 *		       clipboard
 *			   ^
 *			   | (2)
 *			   V
 *		   +---------------+
 *	      (1)  |		   | (3)
 *  keyboard ----->|	 core	   |-----> display
 *		   |		   |
 *		   +---------------+
 *			   ^
 *			   | (4)
 *			   V
 *			 file
 *
 * (1) Typed characters arrive in the current locale.  Conversion is to be
 *     done when 'encoding' is different from 'termencoding'.
 * (2) Text will be made available with the encoding specified with
 *     'encoding'.  If this is not sufficient, system-specific conversion
 *     might be required.
 * (3) For the GUI the correct font must be selected, no conversion done.
 *     Otherwise, conversion is to be done when 'encoding' differs from
 *     'termencoding'.  (Different in the GTK+ 2 port -- 'termencoding'
 *     is always used for both input and output and must always be set to
 *     "utf-8".  gui_mch_init() does this automatically.)
 * (4) The encoding of the file is specified with 'fileencoding'.  Conversion
 *     is to be done when it's different from 'encoding'.
 *
 * The viminfo file is a special case: Only text is converted, not file names.
 * Vim scripts may contain an ":encoding" command.  This has an effect for
 * some commands, like ":menutrans"
 */

#include "vim.h"
#include "mbyte.h"
#include "charset.h"
#include "fileio.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "option.h"
#include "screen.h"
#include "spell.h"
#include "ui.h"

# define WINBYTE BYTE




#ifdef HAVE_WCHAR_H
# include <wchar.h>
#endif



static int enc_canon_search(char_u *name);
static int dbcs_char2len(int c);
static int dbcs_char2bytes(int c, char_u *buf);
static int dbcs_ptr2len(char_u *p);
static int dbcs_ptr2len_len(char_u *p, int size);
static int utf_ptr2cells_len(char_u *p, int size);
static int dbcs_char2cells(int c);
static int dbcs_ptr2cells_len(char_u *p, int size);
static int dbcs_ptr2char(char_u *p);
static int utf_safe_read_char_adv(char_u **s, size_t *n);

/*
 * Lookup table to quickly get the length in bytes of a UTF-8 character from
 * the first byte of a UTF-8 string.
 * Bytes which are illegal when used as the first byte have a 1.
 * The NUL byte has length 1.
 */
static char utf8len_tab[256] =
{
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,6,6,1,1,
};

/*
 * Like utf8len_tab above, but using a zero for illegal lead bytes.
 */
static char utf8len_tab_zero[256] =
{
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,6,6,0,0,
};

/*
 * XIM often causes trouble.  Define XIM_DEBUG to get a log of XIM callbacks
 * in the "xim.log" file.
 */
/* #define XIM_DEBUG */
#ifdef XIM_DEBUG
static void xim_log(char *s, ...)                 {
  va_list arglist;
  static FILE *fd = NULL;

  if (fd == (FILE *)-1)
    return;
  if (fd == NULL) {
    fd = mch_fopen("xim.log", "w");
    if (fd == NULL) {
      EMSG("Cannot open xim.log");
      fd = (FILE *)-1;
      return;
    }
  }

  va_start(arglist, s);
  vfprintf(fd, s, arglist);
  va_end(arglist);
}

#endif


/*
 * Canonical encoding names and their properties.
 * "iso-8859-n" is handled by enc_canonize() directly.
 */
static struct
{   char *name;         int prop;               int codepage; }
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
#define IDX_DECMCS      58
  {"dec-mcs",         ENC_8BIT,               0},       /* DEC MCS */
#define IDX_HPROMAN8    59
  {"hp-roman8",       ENC_8BIT,               0},       /* HP Roman8 */
#define IDX_COUNT       60
};

/*
 * Aliases for encoding names.
 */
static struct
{   char *name;         int canon; }
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

#ifndef CP_UTF8
# define CP_UTF8 65001  /* magic number from winnls.h */
#endif

/*
 * Find encoding "name" in the list of canonical encoding names.
 * Returns -1 if not found.
 */
static int enc_canon_search(char_u *name)
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
int enc_canon_props(char_u *name)
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
 * Set up for using multi-byte characters.
 * Called in three cases:
 * - by main() to initialize (p_enc == NULL)
 * - by set_init_1() after 'encoding' was set to its default.
 * - by do_set() when 'encoding' has been set.
 * p_enc must have been passed through enc_canonize() already.
 * Sets the "enc_unicode", "enc_utf8", "enc_dbcs" and "has_mbyte" flags.
 * Fills mb_bytelen_tab[] and returns NULL when there are no problems.
 * When there is something wrong: Returns an error message and doesn't change
 * anything.
 */
char_u * mb_init()              {
  int i;
  int idx;
  int n;
  int enc_dbcs_new = 0;
#if defined(USE_ICONV) && !defined(WIN3264) && !defined(WIN32UNIX) \
  && !defined(MACOS)
# define LEN_FROM_CONV
  vimconv_T vimconv;
  char_u      *p;
#endif

  if (p_enc == NULL) {
    /* Just starting up: set the whole table to one's. */
    for (i = 0; i < 256; ++i)
      mb_bytelen_tab[i] = 1;
    input_conv.vc_type = CONV_NONE;
    input_conv.vc_factor = 1;
    output_conv.vc_type = CONV_NONE;
    return NULL;
  } else if (STRNCMP(p_enc, "8bit-", 5) == 0
      || STRNCMP(p_enc, "iso-8859-", 9) == 0) {
    /* Accept any "8bit-" or "iso-8859-" name. */
    enc_unicode = 0;
    enc_utf8 = FALSE;
  } else if (STRNCMP(p_enc, "2byte-", 6) == 0)   {
    /* Unix: accept any "2byte-" name, assume current locale. */
    enc_dbcs_new = DBCS_2BYTE;
  } else if ((idx = enc_canon_search(p_enc)) >= 0)   {
    i = enc_canon_table[idx].prop;
    if (i & ENC_UNICODE) {
      /* Unicode */
      enc_utf8 = TRUE;
      if (i & (ENC_2BYTE | ENC_2WORD))
        enc_unicode = 2;
      else if (i & ENC_4BYTE)
        enc_unicode = 4;
      else
        enc_unicode = 0;
    } else if (i & ENC_DBCS)   {
      /* 2byte, handle below */
      enc_dbcs_new = enc_canon_table[idx].codepage;
    } else   {
      /* Must be 8-bit. */
      enc_unicode = 0;
      enc_utf8 = FALSE;
    }
  } else    /* Don't know what encoding this is, reject it. */
    return e_invarg;

  if (enc_dbcs_new != 0) {
    enc_unicode = 0;
    enc_utf8 = FALSE;
  }
  enc_dbcs = enc_dbcs_new;
  has_mbyte = (enc_dbcs != 0 || enc_utf8);


  /* Detect an encoding that uses latin1 characters. */
  enc_latin1like = (enc_utf8 || STRCMP(p_enc, "latin1") == 0
      || STRCMP(p_enc, "iso-8859-15") == 0);

  /*
   * Set the function pointers.
   */
  if (enc_utf8) {
    mb_ptr2len = utfc_ptr2len;
    mb_ptr2len_len = utfc_ptr2len_len;
    mb_char2len = utf_char2len;
    mb_char2bytes = utf_char2bytes;
    mb_ptr2cells = utf_ptr2cells;
    mb_ptr2cells_len = utf_ptr2cells_len;
    mb_char2cells = utf_char2cells;
    mb_off2cells = utf_off2cells;
    mb_ptr2char = utf_ptr2char;
    mb_head_off = utf_head_off;
  } else if (enc_dbcs != 0)   {
    mb_ptr2len = dbcs_ptr2len;
    mb_ptr2len_len = dbcs_ptr2len_len;
    mb_char2len = dbcs_char2len;
    mb_char2bytes = dbcs_char2bytes;
    mb_ptr2cells = dbcs_ptr2cells;
    mb_ptr2cells_len = dbcs_ptr2cells_len;
    mb_char2cells = dbcs_char2cells;
    mb_off2cells = dbcs_off2cells;
    mb_ptr2char = dbcs_ptr2char;
    mb_head_off = dbcs_head_off;
  } else   {
    mb_ptr2len = latin_ptr2len;
    mb_ptr2len_len = latin_ptr2len_len;
    mb_char2len = latin_char2len;
    mb_char2bytes = latin_char2bytes;
    mb_ptr2cells = latin_ptr2cells;
    mb_ptr2cells_len = latin_ptr2cells_len;
    mb_char2cells = latin_char2cells;
    mb_off2cells = latin_off2cells;
    mb_ptr2char = latin_ptr2char;
    mb_head_off = latin_head_off;
  }

  /*
   * Fill the mb_bytelen_tab[] for MB_BYTE2LEN().
   */
#ifdef LEN_FROM_CONV
  /* When 'encoding' is different from the current locale mblen() won't
   * work.  Use conversion to "utf-8" instead. */
  vimconv.vc_type = CONV_NONE;
  if (enc_dbcs) {
    p = enc_locale();
    if (p == NULL || STRCMP(p, p_enc) != 0) {
      convert_setup(&vimconv, p_enc, (char_u *)"utf-8");
      vimconv.vc_fail = TRUE;
    }
    vim_free(p);
  }
#endif

  for (i = 0; i < 256; ++i) {
    /* Our own function to reliably check the length of UTF-8 characters,
     * independent of mblen(). */
    if (enc_utf8)
      n = utf8len_tab[i];
    else if (enc_dbcs == 0)
      n = 1;
    else {
# if defined(MACOS) || defined(__amigaos4__)
      /*
       * if mblen() is not available, character which MSB is turned on
       * are treated as leading byte character. (note : This assumption
       * is not always true.)
       */
      n = (i & 0x80) ? 2 : 1;
# else
      char buf[MB_MAXBYTES + 1];
      if (i == NUL)             /* just in case mblen() can't handle "" */
        n = 1;
      else {
        buf[0] = i;
        buf[1] = 0;
#ifdef LEN_FROM_CONV
        if (vimconv.vc_type != CONV_NONE) {
          /*
           * string_convert() should fail when converting the first
           * byte of a double-byte character.
           */
          p = string_convert(&vimconv, (char_u *)buf, NULL);
          if (p != NULL) {
            vim_free(p);
            n = 1;
          } else
            n = 2;
        } else
#endif
        {
          /*
           * mblen() should return -1 for invalid (means the leading
           * multibyte) character.  However there are some platforms
           * where mblen() returns 0 for invalid character.
           * Therefore, following condition includes 0.
           */
          ignored = mblen(NULL, 0);             /* First reset the state. */
          if (mblen(buf, (size_t)1) <= 0)
            n = 2;
          else
            n = 1;
        }
      }
# endif
    }

    mb_bytelen_tab[i] = n;
  }

#ifdef LEN_FROM_CONV
  convert_setup(&vimconv, NULL, NULL);
#endif

  /* The cell width depends on the type of multi-byte characters. */
  (void)init_chartab();

  /* When enc_utf8 is set or reset, (de)allocate ScreenLinesUC[] */
  screenalloc(FALSE);

  /* When using Unicode, set default for 'fileencodings'. */
  if (enc_utf8 && !option_was_set((char_u *)"fencs"))
    set_string_option_direct((char_u *)"fencs", -1,
        (char_u *)"ucs-bom,utf-8,default,latin1", OPT_FREE, 0);

#ifdef HAVE_WORKING_LIBINTL
  /* GNU gettext 0.10.37 supports this feature: set the codeset used for
   * translated messages independently from the current locale. */
  (void)bind_textdomain_codeset(VIMPACKAGE,
      enc_utf8 ? "utf-8" : (char *)p_enc);
#endif


  /* Fire an autocommand to let people do custom font setup. This must be
   * after Vim has been setup for the new encoding. */
  apply_autocmds(EVENT_ENCODINGCHANGED, NULL, (char_u *)"", FALSE, curbuf);

  /* Need to reload spell dictionaries */
  spell_reload();

  return NULL;
}

/*
 * Return the size of the BOM for the current buffer:
 * 0 - no BOM
 * 2 - UCS-2 or UTF-16 BOM
 * 4 - UCS-4 BOM
 * 3 - UTF-8 BOM
 */
int bomb_size()         {
  int n = 0;

  if (curbuf->b_p_bomb && !curbuf->b_p_bin) {
    if (*curbuf->b_p_fenc == NUL) {
      if (enc_utf8) {
        if (enc_unicode != 0)
          n = enc_unicode;
        else
          n = 3;
      }
    } else if (STRCMP(curbuf->b_p_fenc, "utf-8") == 0)
      n = 3;
    else if (STRNCMP(curbuf->b_p_fenc, "ucs-2", 5) == 0
        || STRNCMP(curbuf->b_p_fenc, "utf-16", 6) == 0)
      n = 2;
    else if (STRNCMP(curbuf->b_p_fenc, "ucs-4", 5) == 0)
      n = 4;
  }
  return n;
}

/*
 * Remove all BOM from "s" by moving remaining text.
 */
void remove_bom(char_u *s)
{
  if (enc_utf8) {
    char_u *p = s;

    while ((p = vim_strbyte(p, 0xef)) != NULL) {
      if (p[1] == 0xbb && p[2] == 0xbf)
        STRMOVE(p, p + 3);
      else
        ++p;
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
int mb_get_class(char_u *p)
{
  return mb_get_class_buf(p, curbuf);
}

int mb_get_class_buf(char_u *p, buf_T *buf)
{
  if (MB_BYTE2LEN(p[0]) == 1) {
    if (p[0] == NUL || vim_iswhite(p[0]))
      return 0;
    if (vim_iswordc_buf(p[0], buf))
      return 2;
    return 1;
  }
  if (enc_dbcs != 0 && p[0] != NUL && p[1] != NUL)
    return dbcs_class(p[0], p[1]);
  if (enc_utf8)
    return utf_class(utf_ptr2char(p));
  return 0;
}

/*
 * Get class of a double-byte character.  This always returns 3 or bigger.
 * TODO: Should return 1 for punctuation.
 */
int dbcs_class(unsigned lead, unsigned trail)
{
  switch (enc_dbcs) {
    /* please add classify routine for your language in here */

    case DBCS_JPNU:       /* ? */
    case DBCS_JPN:
      {
        /* JIS code classification */
        unsigned char lb = lead;
        unsigned char tb = trail;

        /* convert process code to JIS */
        /*
         * XXX: Code page identification can not use with all
         *	    system! So, some other encoding information
         *	    will be needed.
         *	    In japanese: SJIS,EUC,UNICODE,(JIS)
         *	    Note that JIS-code system don't use as
         *	    process code in most system because it uses
         *	    escape sequences(JIS is context depend encoding).
         */
        /* assume process code is JAPANESE-EUC */
        lb &= 0x7f;
        tb &= 0x7f;
        /* exceptions */
        switch (lb << 8 | tb) {
          case 0x2121:                 /* ZENKAKU space */
            return 0;
          case 0x2122:                 /* TOU-TEN (Japanese comma) */
          case 0x2123:                 /* KU-TEN (Japanese period) */
          case 0x2124:                 /* ZENKAKU comma */
          case 0x2125:                 /* ZENKAKU period */
            return 1;
          case 0x213c:                 /* prolongedsound handled as KATAKANA */
            return 13;
        }
        /* sieved by KU code */
        switch (lb) {
          case 0x21:
          case 0x22:
            /* special symbols */
            return 10;
          case 0x23:
            /* alpha-numeric */
            return 11;
          case 0x24:
            /* hiragana */
            return 12;
          case 0x25:
            /* katakana */
            return 13;
          case 0x26:
            /* greek */
            return 14;
          case 0x27:
            /* russian */
            return 15;
          case 0x28:
            /* lines */
            return 16;
          default:
            /* kanji */
            return 17;
        }
      }

    case DBCS_KORU:       /* ? */
    case DBCS_KOR:
      {
        /* KS code classification */
        unsigned char c1 = lead;
        unsigned char c2 = trail;

        /*
         * 20 : Hangul
         * 21 : Hanja
         * 22 : Symbols
         * 23 : Alpha-numeric/Roman Letter (Full width)
         * 24 : Hangul Letter(Alphabet)
         * 25 : Roman Numeral/Greek Letter
         * 26 : Box Drawings
         * 27 : Unit Symbols
         * 28 : Circled/Parenthesized Letter
         * 29 : Hiragana/Katakana
         * 30 : Cyrillic Letter
         */

        if (c1 >= 0xB0 && c1 <= 0xC8)
          /* Hangul */
          return 20;

        else if (c1 >= 0xCA && c1 <= 0xFD)
          /* Hanja */
          return 21;
        else switch (c1) {
          case 0xA1:
          case 0xA2:
            /* Symbols */
            return 22;
          case 0xA3:
            /* Alpha-numeric */
            return 23;
          case 0xA4:
            /* Hangul Letter(Alphabet) */
            return 24;
          case 0xA5:
            /* Roman Numeral/Greek Letter */
            return 25;
          case 0xA6:
            /* Box Drawings */
            return 26;
          case 0xA7:
            /* Unit Symbols */
            return 27;
          case 0xA8:
          case 0xA9:
            if (c2 <= 0xAF)
              return 25;                    /* Roman Letter */
            else if (c2 >= 0xF6)
              return 22;                    /* Symbols */
            else
              /* Circled/Parenthesized Letter */
              return 28;
          case 0xAA:
          case 0xAB:
            /* Hiragana/Katakana */
            return 29;
          case 0xAC:
            /* Cyrillic Letter */
            return 30;
        }
      }
    default:
      break;
  }
  return 3;
}

/*
 * mb_char2len() function pointer.
 * Return length in bytes of character "c".
 * Returns 1 for a single-byte character.
 */
int latin_char2len(int c)
{
  return 1;
}

static int dbcs_char2len(int c)
{
  if (c >= 0x100)
    return 2;
  return 1;
}

/*
 * mb_char2bytes() function pointer.
 * Convert a character to its bytes.
 * Returns the length in bytes.
 */
int latin_char2bytes(int c, char_u *buf)
{
  buf[0] = c;
  return 1;
}

static int dbcs_char2bytes(int c, char_u *buf)
{
  if (c >= 0x100) {
    buf[0] = (unsigned)c >> 8;
    buf[1] = c;
    /* Never use a NUL byte, it causes lots of trouble.  It's an invalid
     * character anyway. */
    if (buf[1] == NUL)
      buf[1] = '\n';
    return 2;
  }
  buf[0] = c;
  return 1;
}

/*
 * mb_ptr2len() function pointer.
 * Get byte length of character at "*p" but stop at a NUL.
 * For UTF-8 this includes following composing characters.
 * Returns 0 when *p is NUL.
 */
int latin_ptr2len(char_u *p)
{
  return MB_BYTE2LEN(*p);
}

static int dbcs_ptr2len(char_u *p)
{
  int len;

  /* Check if second byte is not missing. */
  len = MB_BYTE2LEN(*p);
  if (len == 2 && p[1] == NUL)
    len = 1;
  return len;
}

/*
 * mb_ptr2len_len() function pointer.
 * Like mb_ptr2len(), but limit to read "size" bytes.
 * Returns 0 for an empty string.
 * Returns 1 for an illegal char or an incomplete byte sequence.
 */
int latin_ptr2len_len(char_u *p, int size)
{
  if (size < 1 || *p == NUL)
    return 0;
  return 1;
}

static int dbcs_ptr2len_len(char_u *p, int size)
{
  int len;

  if (size < 1 || *p == NUL)
    return 0;
  if (size == 1)
    return 1;
  /* Check that second byte is not missing. */
  len = MB_BYTE2LEN(*p);
  if (len == 2 && p[1] == NUL)
    len = 1;
  return len;
}

struct interval {
  long first;
  long last;
};
static int intable(struct interval *table, size_t size, int c);

/*
 * Return TRUE if "c" is in "table[size / sizeof(struct interval)]".
 */
static int intable(struct interval *table, size_t size, int c)
{
  int mid, bot, top;

  /* first quick check for Latin1 etc. characters */
  if (c < table[0].first)
    return FALSE;

  /* binary search in table */
  bot = 0;
  top = (int)(size / sizeof(struct interval) - 1);
  while (top >= bot) {
    mid = (bot + top) / 2;
    if (table[mid].last < c)
      bot = mid + 1;
    else if (table[mid].first > c)
      top = mid - 1;
    else
      return TRUE;
  }
  return FALSE;
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
  /* Sorted list of non-overlapping intervals of East Asian double width
   * characters, generated with ../runtime/tools/unicode.vim. */
  static struct interval doublewidth[] =
  {
    {0x1100, 0x115f},
    {0x11a3, 0x11a7},
    {0x11fa, 0x11ff},
    {0x2329, 0x232a},
    {0x2e80, 0x2e99},
    {0x2e9b, 0x2ef3},
    {0x2f00, 0x2fd5},
    {0x2ff0, 0x2ffb},
    {0x3000, 0x3029},
    {0x3030, 0x303e},
    {0x3041, 0x3096},
    {0x309b, 0x30ff},
    {0x3105, 0x312d},
    {0x3131, 0x318e},
    {0x3190, 0x31b7},
    {0x31c0, 0x31e3},
    {0x31f0, 0x321e},
    {0x3220, 0x3247},
    {0x3250, 0x32fe},
    {0x3300, 0x4dbf},
    {0x4e00, 0xa48c},
    {0xa490, 0xa4c6},
    {0xa960, 0xa97c},
    {0xac00, 0xd7a3},
    {0xd7b0, 0xd7c6},
    {0xd7cb, 0xd7fb},
    {0xf900, 0xfaff},
    {0xfe10, 0xfe19},
    {0xfe30, 0xfe52},
    {0xfe54, 0xfe66},
    {0xfe68, 0xfe6b},
    {0xff01, 0xff60},
    {0xffe0, 0xffe6},
    {0x1f200, 0x1f200},
    {0x1f210, 0x1f231},
    {0x1f240, 0x1f248},
    {0x20000, 0x2fffd},
    {0x30000, 0x3fffd}
  };
  /* Sorted list of non-overlapping intervals of East Asian Ambiguous
   * characters, generated with ../runtime/tools/unicode.vim. */
  static struct interval ambiguous[] =
  {
    {0x00a1, 0x00a1},
    {0x00a4, 0x00a4},
    {0x00a7, 0x00a8},
    {0x00aa, 0x00aa},
    {0x00ad, 0x00ae},
    {0x00b0, 0x00b4},
    {0x00b6, 0x00ba},
    {0x00bc, 0x00bf},
    {0x00c6, 0x00c6},
    {0x00d0, 0x00d0},
    {0x00d7, 0x00d8},
    {0x00de, 0x00e1},
    {0x00e6, 0x00e6},
    {0x00e8, 0x00ea},
    {0x00ec, 0x00ed},
    {0x00f0, 0x00f0},
    {0x00f2, 0x00f3},
    {0x00f7, 0x00fa},
    {0x00fc, 0x00fc},
    {0x00fe, 0x00fe},
    {0x0101, 0x0101},
    {0x0111, 0x0111},
    {0x0113, 0x0113},
    {0x011b, 0x011b},
    {0x0126, 0x0127},
    {0x012b, 0x012b},
    {0x0131, 0x0133},
    {0x0138, 0x0138},
    {0x013f, 0x0142},
    {0x0144, 0x0144},
    {0x0148, 0x014b},
    {0x014d, 0x014d},
    {0x0152, 0x0153},
    {0x0166, 0x0167},
    {0x016b, 0x016b},
    {0x01ce, 0x01ce},
    {0x01d0, 0x01d0},
    {0x01d2, 0x01d2},
    {0x01d4, 0x01d4},
    {0x01d6, 0x01d6},
    {0x01d8, 0x01d8},
    {0x01da, 0x01da},
    {0x01dc, 0x01dc},
    {0x0251, 0x0251},
    {0x0261, 0x0261},
    {0x02c4, 0x02c4},
    {0x02c7, 0x02c7},
    {0x02c9, 0x02cb},
    {0x02cd, 0x02cd},
    {0x02d0, 0x02d0},
    {0x02d8, 0x02db},
    {0x02dd, 0x02dd},
    {0x02df, 0x02df},
    {0x0391, 0x03a1},
    {0x03a3, 0x03a9},
    {0x03b1, 0x03c1},
    {0x03c3, 0x03c9},
    {0x0401, 0x0401},
    {0x0410, 0x044f},
    {0x0451, 0x0451},
    {0x2010, 0x2010},
    {0x2013, 0x2016},
    {0x2018, 0x2019},
    {0x201c, 0x201d},
    {0x2020, 0x2022},
    {0x2024, 0x2027},
    {0x2030, 0x2030},
    {0x2032, 0x2033},
    {0x2035, 0x2035},
    {0x203b, 0x203b},
    {0x203e, 0x203e},
    {0x2074, 0x2074},
    {0x207f, 0x207f},
    {0x2081, 0x2084},
    {0x20ac, 0x20ac},
    {0x2103, 0x2103},
    {0x2105, 0x2105},
    {0x2109, 0x2109},
    {0x2113, 0x2113},
    {0x2116, 0x2116},
    {0x2121, 0x2122},
    {0x2126, 0x2126},
    {0x212b, 0x212b},
    {0x2153, 0x2154},
    {0x215b, 0x215e},
    {0x2160, 0x216b},
    {0x2170, 0x2179},
    {0x2189, 0x2189},
    {0x2190, 0x2199},
    {0x21b8, 0x21b9},
    {0x21d2, 0x21d2},
    {0x21d4, 0x21d4},
    {0x21e7, 0x21e7},
    {0x2200, 0x2200},
    {0x2202, 0x2203},
    {0x2207, 0x2208},
    {0x220b, 0x220b},
    {0x220f, 0x220f},
    {0x2211, 0x2211},
    {0x2215, 0x2215},
    {0x221a, 0x221a},
    {0x221d, 0x2220},
    {0x2223, 0x2223},
    {0x2225, 0x2225},
    {0x2227, 0x222c},
    {0x222e, 0x222e},
    {0x2234, 0x2237},
    {0x223c, 0x223d},
    {0x2248, 0x2248},
    {0x224c, 0x224c},
    {0x2252, 0x2252},
    {0x2260, 0x2261},
    {0x2264, 0x2267},
    {0x226a, 0x226b},
    {0x226e, 0x226f},
    {0x2282, 0x2283},
    {0x2286, 0x2287},
    {0x2295, 0x2295},
    {0x2299, 0x2299},
    {0x22a5, 0x22a5},
    {0x22bf, 0x22bf},
    {0x2312, 0x2312},
    {0x2460, 0x24e9},
    {0x24eb, 0x254b},
    {0x2550, 0x2573},
    {0x2580, 0x258f},
    {0x2592, 0x2595},
    {0x25a0, 0x25a1},
    {0x25a3, 0x25a9},
    {0x25b2, 0x25b3},
    {0x25b6, 0x25b7},
    {0x25bc, 0x25bd},
    {0x25c0, 0x25c1},
    {0x25c6, 0x25c8},
    {0x25cb, 0x25cb},
    {0x25ce, 0x25d1},
    {0x25e2, 0x25e5},
    {0x25ef, 0x25ef},
    {0x2605, 0x2606},
    {0x2609, 0x2609},
    {0x260e, 0x260f},
    {0x2614, 0x2615},
    {0x261c, 0x261c},
    {0x261e, 0x261e},
    {0x2640, 0x2640},
    {0x2642, 0x2642},
    {0x2660, 0x2661},
    {0x2663, 0x2665},
    {0x2667, 0x266a},
    {0x266c, 0x266d},
    {0x266f, 0x266f},
    {0x269e, 0x269f},
    {0x26be, 0x26bf},
    {0x26c4, 0x26cd},
    {0x26cf, 0x26e1},
    {0x26e3, 0x26e3},
    {0x26e8, 0x26ff},
    {0x273d, 0x273d},
    {0x2757, 0x2757},
    {0x2776, 0x277f},
    {0x2b55, 0x2b59},
    {0x3248, 0x324f},
    {0xe000, 0xf8ff},
    {0xfffd, 0xfffd},
    {0x1f100, 0x1f10a},
    {0x1f110, 0x1f12d},
    {0x1f131, 0x1f131},
    {0x1f13d, 0x1f13d},
    {0x1f13f, 0x1f13f},
    {0x1f142, 0x1f142},
    {0x1f146, 0x1f146},
    {0x1f14a, 0x1f14e},
    {0x1f157, 0x1f157},
    {0x1f15f, 0x1f15f},
    {0x1f179, 0x1f179},
    {0x1f17b, 0x1f17c},
    {0x1f17f, 0x1f17f},
    {0x1f18a, 0x1f18d},
    {0x1f190, 0x1f190},
    {0xf0000, 0xffffd},
    {0x100000, 0x10fffd}
  };

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
    if (intable(doublewidth, sizeof(doublewidth), c))
      return 2;
#endif
  }
  /* Characters below 0x100 are influenced by 'isprint' option */
  else if (c >= 0x80 && !vim_isprintc(c))
    return 4;                   /* unprintable, displays <xx> */

  if (c >= 0x80 && *p_ambw == 'd' && intable(ambiguous, sizeof(ambiguous), c))
    return 2;

  return 1;
}

/*
 * mb_ptr2cells() function pointer.
 * Return the number of display cells character at "*p" occupies.
 * This doesn't take care of unprintable characters, use ptr2cells() for that.
 */
int latin_ptr2cells(char_u *p)
{
  return 1;
}

int utf_ptr2cells(char_u *p)
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

int dbcs_ptr2cells(char_u *p)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && *p == 0x8e)
    return 1;
  return MB_BYTE2LEN(*p);
}

/*
 * mb_ptr2cells_len() function pointer.
 * Like mb_ptr2cells(), but limit string length to "size".
 * For an empty string or truncated character returns 1.
 */
int latin_ptr2cells_len(char_u *p, int size)
{
  return 1;
}

static int utf_ptr2cells_len(char_u *p, int size)
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

static int dbcs_ptr2cells_len(char_u *p, int size)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (size <= 1 || (enc_dbcs == DBCS_JPNU && *p == 0x8e))
    return 1;
  return MB_BYTE2LEN(*p);
}

/*
 * mb_char2cells() function pointer.
 * Return the number of display cells character "c" occupies.
 * Only takes care of multi-byte chars, not "^C" and such.
 */
int latin_char2cells(int c)
{
  return 1;
}

static int dbcs_char2cells(int c)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && ((unsigned)c >> 8) == 0x8e)
    return 1;
  /* use the first byte */
  return MB_BYTE2LEN((unsigned)c >> 8);
}

/*
 * Return the number of cells occupied by string "p".
 * Stop at a NUL character.  When "len" >= 0 stop at character "p[len]".
 */
int mb_string2cells(char_u *p, int len)
{
  int i;
  int clen = 0;

  for (i = 0; (len < 0 || i < len) && p[i] != NUL; i += (*mb_ptr2len)(p + i))
    clen += (*mb_ptr2cells)(p + i);
  return clen;
}

/*
 * mb_off2cells() function pointer.
 * Return number of display cells for char at ScreenLines[off].
 * We make sure that the offset used is less than "max_off".
 */
int latin_off2cells(unsigned off, unsigned max_off)
{
  return 1;
}

int dbcs_off2cells(unsigned off, unsigned max_off)
{
  /* never check beyond end of the line */
  if (off >= max_off)
    return 1;

  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && ScreenLines[off] == 0x8e)
    return 1;
  return MB_BYTE2LEN(ScreenLines[off]);
}

int utf_off2cells(unsigned off, unsigned max_off)
{
  return (off + 1 < max_off && ScreenLines[off + 1] == 0) ? 2 : 1;
}

/*
 * mb_ptr2char() function pointer.
 * Convert a byte sequence into a character.
 */
int latin_ptr2char(char_u *p)
{
  return *p;
}

static int dbcs_ptr2char(char_u *p)
{
  if (MB_BYTE2LEN(*p) > 1 && p[1] != NUL)
    return (p[0] << 8) + p[1];
  return *p;
}

/*
 * Convert a UTF-8 byte sequence to a wide character.
 * If the sequence is illegal or truncated by a NUL the first byte is
 * returned.
 * Does not include composing characters, of course.
 */
int utf_ptr2char(char_u *p)
{
  int len;

  if (p[0] < 0x80)      /* be quick for ASCII */
    return p[0];

  len = utf8len_tab_zero[p[0]];
  if (len > 1 && (p[1] & 0xc0) == 0x80) {
    if (len == 2)
      return ((p[0] & 0x1f) << 6) + (p[1] & 0x3f);
    if ((p[2] & 0xc0) == 0x80) {
      if (len == 3)
        return ((p[0] & 0x0f) << 12) + ((p[1] & 0x3f) << 6)
          + (p[2] & 0x3f);
      if ((p[3] & 0xc0) == 0x80) {
        if (len == 4)
          return ((p[0] & 0x07) << 18) + ((p[1] & 0x3f) << 12)
            + ((p[2] & 0x3f) << 6) + (p[3] & 0x3f);
        if ((p[4] & 0xc0) == 0x80) {
          if (len == 5)
            return ((p[0] & 0x03) << 24) + ((p[1] & 0x3f) << 18)
              + ((p[2] & 0x3f) << 12) + ((p[3] & 0x3f) << 6)
              + (p[4] & 0x3f);
          if ((p[5] & 0xc0) == 0x80 && len == 6)
            return ((p[0] & 0x01) << 30) + ((p[1] & 0x3f) << 24)
              + ((p[2] & 0x3f) << 18) + ((p[3] & 0x3f) << 12)
              + ((p[4] & 0x3f) << 6) + (p[5] & 0x3f);
        }
      }
    }
  }
  /* Illegal value, just return the first byte */
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
static int utf_safe_read_char_adv(char_u **s, size_t *n)
{
  int c, k;

  if (*n == 0)   /* end of buffer */
    return 0;

  k = utf8len_tab_zero[**s];

  if (k == 1) {
    /* ASCII character or NUL */
    (*n)--;
    return *(*s)++;
  }

  if ((size_t)k <= *n) {
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
int mb_ptr2char_adv(char_u **pp)
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
int mb_cptr2char_adv(char_u **pp)
{
  int c;

  c = (*mb_ptr2char)(*pp);
  if (enc_utf8)
    *pp += utf_ptr2len(*pp);
  else
    *pp += (*mb_ptr2len)(*pp);
  return c;
}

/*
 * Check whether we are dealing with Arabic combining characters.
 * Note: these are NOT really composing characters!
 */
int arabic_combine(
    int one,                    /* first character */
    int two                     /* character just after "one" */
    )
{
  if (one == a_LAM)
    return arabic_maycombine(two);
  return FALSE;
}

/*
 * Check whether we are dealing with a character that could be regarded as an
 * Arabic combining character, need to check the character before this.
 */
int arabic_maycombine(int two)
{
  if (p_arshape && !p_tbidi)
    return two == a_ALEF_MADDA
      || two == a_ALEF_HAMZA_ABOVE
      || two == a_ALEF_HAMZA_BELOW
      || two == a_ALEF;
  return FALSE;
}

/*
 * Check if the character pointed to by "p2" is a composing character when it
 * comes after "p1".  For Arabic sometimes "ab" is replaced with "c", which
 * behaves like a composing character.
 */
int utf_composinglike(char_u *p1, char_u *p2)
{
  int c2;

  c2 = utf_ptr2char(p2);
  if (utf_iscomposing(c2))
    return TRUE;
  if (!arabic_maycombine(c2))
    return FALSE;
  return arabic_combine(utf_ptr2char(p1), c2);
}

/*
 * Convert a UTF-8 byte string to a wide character.  Also get up to MAX_MCO
 * composing characters.
 */
int utfc_ptr2char(
    char_u      *p,
    int         *pcc        /* return: composing chars, last one is 0 */
    )
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
 */
int utfc_ptr2char_len(
    char_u      *p,
    int         *pcc,       /* return: composing chars, last one is 0 */
    int maxlen
    )
{
  int len;
  int c;
  int cc;
  int i = 0;

  c = utf_ptr2char(p);
  len = utf_ptr2len_len(p, maxlen);
  /* Only accept a composing char when the first char isn't illegal. */
  if ((len > 1 || *p < 0x80)
      && len < maxlen
      && p[len] >= 0x80
      && UTF_COMPOSINGLIKE(p, p + len)) {
    cc = utf_ptr2char(p + len);
    for (;; ) {
      pcc[i++] = cc;
      if (i == MAX_MCO)
        break;
      len += utf_ptr2len_len(p + len, maxlen - len);
      if (len >= maxlen
          || p[len] < 0x80
          || !utf_iscomposing(cc = utf_ptr2char(p + len)))
        break;
    }
  }

  if (i < MAX_MCO)      /* last composing char must be 0 */
    pcc[i] = 0;

  return c;
}

/*
 * Convert the character at screen position "off" to a sequence of bytes.
 * Includes the composing characters.
 * "buf" must at least have the length MB_MAXBYTES + 1.
 * Only to be used when ScreenLinesUC[off] != 0.
 * Returns the produced number of bytes.
 */
int utfc_char2bytes(int off, char_u *buf)
{
  int len;
  int i;

  len = utf_char2bytes(ScreenLinesUC[off], buf);
  for (i = 0; i < Screen_mco; ++i) {
    if (ScreenLinesC[i][off] == 0)
      break;
    len += utf_char2bytes(ScreenLinesC[i][off], buf + len);
  }
  return len;
}

/*
 * Get the length of a UTF-8 byte sequence, not including any following
 * composing characters.
 * Returns 0 for "".
 * Returns 1 for an illegal byte sequence.
 */
int utf_ptr2len(char_u *p)
{
  int len;
  int i;

  if (*p == NUL)
    return 0;
  len = utf8len_tab[*p];
  for (i = 1; i < len; ++i)
    if ((p[i] & 0xc0) != 0x80)
      return 1;
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
int utf_ptr2len_len(char_u *p, int size)
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

/*
 * Return the number of bytes the UTF-8 encoding of the character at "p" takes.
 * This includes following composing characters.
 */
int utfc_ptr2len(char_u *p)
{
  int len;
  int b0 = *p;
  int prevlen;

  if (b0 == NUL)
    return 0;
  if (b0 < 0x80 && p[1] < 0x80)         /* be quick for ASCII */
    return 1;

  /* Skip over first UTF-8 char, stopping at a NUL byte. */
  len = utf_ptr2len(p);

  /* Check for illegal byte. */
  if (len == 1 && b0 >= 0x80)
    return 1;

  /*
   * Check for composing characters.  We can handle only the first six, but
   * skip all of them (otherwise the cursor would get stuck).
   */
  prevlen = 0;
  for (;; ) {
    if (p[len] < 0x80 || !UTF_COMPOSINGLIKE(p + prevlen, p + len))
      return len;

    /* Skip over composing char */
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
int utfc_ptr2len_len(char_u *p, int size)
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

/*
 * Return the number of bytes the UTF-8 encoding of character "c" takes.
 * This does not include composing characters.
 */
int utf_char2len(int c)
{
  if (c < 0x80)
    return 1;
  if (c < 0x800)
    return 2;
  if (c < 0x10000)
    return 3;
  if (c < 0x200000)
    return 4;
  if (c < 0x4000000)
    return 5;
  return 6;
}

/*
 * Convert Unicode character "c" to UTF-8 string in "buf[]".
 * Returns the number of bytes.
 * This does not include composing characters.
 */
int utf_char2bytes(int c, char_u *buf)
{
  if (c < 0x80) {               /* 7 bits */
    buf[0] = c;
    return 1;
  }
  if (c < 0x800) {              /* 11 bits */
    buf[0] = 0xc0 + ((unsigned)c >> 6);
    buf[1] = 0x80 + (c & 0x3f);
    return 2;
  }
  if (c < 0x10000) {            /* 16 bits */
    buf[0] = 0xe0 + ((unsigned)c >> 12);
    buf[1] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[2] = 0x80 + (c & 0x3f);
    return 3;
  }
  if (c < 0x200000) {           /* 21 bits */
    buf[0] = 0xf0 + ((unsigned)c >> 18);
    buf[1] = 0x80 + (((unsigned)c >> 12) & 0x3f);
    buf[2] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[3] = 0x80 + (c & 0x3f);
    return 4;
  }
  if (c < 0x4000000) {          /* 26 bits */
    buf[0] = 0xf8 + ((unsigned)c >> 24);
    buf[1] = 0x80 + (((unsigned)c >> 18) & 0x3f);
    buf[2] = 0x80 + (((unsigned)c >> 12) & 0x3f);
    buf[3] = 0x80 + (((unsigned)c >> 6) & 0x3f);
    buf[4] = 0x80 + (c & 0x3f);
    return 5;
  }
  /* 31 bits */
  buf[0] = 0xfc + ((unsigned)c >> 30);
  buf[1] = 0x80 + (((unsigned)c >> 24) & 0x3f);
  buf[2] = 0x80 + (((unsigned)c >> 18) & 0x3f);
  buf[3] = 0x80 + (((unsigned)c >> 12) & 0x3f);
  buf[4] = 0x80 + (((unsigned)c >> 6) & 0x3f);
  buf[5] = 0x80 + (c & 0x3f);
  return 6;
}

/*
 * Return TRUE if "c" is a composing UTF-8 character.  This means it will be
 * drawn on top of the preceding character.
 * Based on code from Markus Kuhn.
 */
int utf_iscomposing(int c)
{
  /* Sorted list of non-overlapping intervals.
   * Generated by ../runtime/tools/unicode.vim. */
  static struct interval combining[] =
  {
    {0x0300, 0x036f},
    {0x0483, 0x0489},
    {0x0591, 0x05bd},
    {0x05bf, 0x05bf},
    {0x05c1, 0x05c2},
    {0x05c4, 0x05c5},
    {0x05c7, 0x05c7},
    {0x0610, 0x061a},
    {0x064b, 0x065e},
    {0x0670, 0x0670},
    {0x06d6, 0x06dc},
    {0x06de, 0x06e4},
    {0x06e7, 0x06e8},
    {0x06ea, 0x06ed},
    {0x0711, 0x0711},
    {0x0730, 0x074a},
    {0x07a6, 0x07b0},
    {0x07eb, 0x07f3},
    {0x0816, 0x0819},
    {0x081b, 0x0823},
    {0x0825, 0x0827},
    {0x0829, 0x082d},
    {0x0900, 0x0903},
    {0x093c, 0x093c},
    {0x093e, 0x094e},
    {0x0951, 0x0955},
    {0x0962, 0x0963},
    {0x0981, 0x0983},
    {0x09bc, 0x09bc},
    {0x09be, 0x09c4},
    {0x09c7, 0x09c8},
    {0x09cb, 0x09cd},
    {0x09d7, 0x09d7},
    {0x09e2, 0x09e3},
    {0x0a01, 0x0a03},
    {0x0a3c, 0x0a3c},
    {0x0a3e, 0x0a42},
    {0x0a47, 0x0a48},
    {0x0a4b, 0x0a4d},
    {0x0a51, 0x0a51},
    {0x0a70, 0x0a71},
    {0x0a75, 0x0a75},
    {0x0a81, 0x0a83},
    {0x0abc, 0x0abc},
    {0x0abe, 0x0ac5},
    {0x0ac7, 0x0ac9},
    {0x0acb, 0x0acd},
    {0x0ae2, 0x0ae3},
    {0x0b01, 0x0b03},
    {0x0b3c, 0x0b3c},
    {0x0b3e, 0x0b44},
    {0x0b47, 0x0b48},
    {0x0b4b, 0x0b4d},
    {0x0b56, 0x0b57},
    {0x0b62, 0x0b63},
    {0x0b82, 0x0b82},
    {0x0bbe, 0x0bc2},
    {0x0bc6, 0x0bc8},
    {0x0bca, 0x0bcd},
    {0x0bd7, 0x0bd7},
    {0x0c01, 0x0c03},
    {0x0c3e, 0x0c44},
    {0x0c46, 0x0c48},
    {0x0c4a, 0x0c4d},
    {0x0c55, 0x0c56},
    {0x0c62, 0x0c63},
    {0x0c82, 0x0c83},
    {0x0cbc, 0x0cbc},
    {0x0cbe, 0x0cc4},
    {0x0cc6, 0x0cc8},
    {0x0cca, 0x0ccd},
    {0x0cd5, 0x0cd6},
    {0x0ce2, 0x0ce3},
    {0x0d02, 0x0d03},
    {0x0d3e, 0x0d44},
    {0x0d46, 0x0d48},
    {0x0d4a, 0x0d4d},
    {0x0d57, 0x0d57},
    {0x0d62, 0x0d63},
    {0x0d82, 0x0d83},
    {0x0dca, 0x0dca},
    {0x0dcf, 0x0dd4},
    {0x0dd6, 0x0dd6},
    {0x0dd8, 0x0ddf},
    {0x0df2, 0x0df3},
    {0x0e31, 0x0e31},
    {0x0e34, 0x0e3a},
    {0x0e47, 0x0e4e},
    {0x0eb1, 0x0eb1},
    {0x0eb4, 0x0eb9},
    {0x0ebb, 0x0ebc},
    {0x0ec8, 0x0ecd},
    {0x0f18, 0x0f19},
    {0x0f35, 0x0f35},
    {0x0f37, 0x0f37},
    {0x0f39, 0x0f39},
    {0x0f3e, 0x0f3f},
    {0x0f71, 0x0f84},
    {0x0f86, 0x0f87},
    {0x0f90, 0x0f97},
    {0x0f99, 0x0fbc},
    {0x0fc6, 0x0fc6},
    {0x102b, 0x103e},
    {0x1056, 0x1059},
    {0x105e, 0x1060},
    {0x1062, 0x1064},
    {0x1067, 0x106d},
    {0x1071, 0x1074},
    {0x1082, 0x108d},
    {0x108f, 0x108f},
    {0x109a, 0x109d},
    {0x135f, 0x135f},
    {0x1712, 0x1714},
    {0x1732, 0x1734},
    {0x1752, 0x1753},
    {0x1772, 0x1773},
    {0x17b6, 0x17d3},
    {0x17dd, 0x17dd},
    {0x180b, 0x180d},
    {0x18a9, 0x18a9},
    {0x1920, 0x192b},
    {0x1930, 0x193b},
    {0x19b0, 0x19c0},
    {0x19c8, 0x19c9},
    {0x1a17, 0x1a1b},
    {0x1a55, 0x1a5e},
    {0x1a60, 0x1a7c},
    {0x1a7f, 0x1a7f},
    {0x1b00, 0x1b04},
    {0x1b34, 0x1b44},
    {0x1b6b, 0x1b73},
    {0x1b80, 0x1b82},
    {0x1ba1, 0x1baa},
    {0x1c24, 0x1c37},
    {0x1cd0, 0x1cd2},
    {0x1cd4, 0x1ce8},
    {0x1ced, 0x1ced},
    {0x1cf2, 0x1cf2},
    {0x1dc0, 0x1de6},
    {0x1dfd, 0x1dff},
    {0x20d0, 0x20f0},
    {0x2cef, 0x2cf1},
    {0x2de0, 0x2dff},
    {0x302a, 0x302f},
    {0x3099, 0x309a},
    {0xa66f, 0xa672},
    {0xa67c, 0xa67d},
    {0xa6f0, 0xa6f1},
    {0xa802, 0xa802},
    {0xa806, 0xa806},
    {0xa80b, 0xa80b},
    {0xa823, 0xa827},
    {0xa880, 0xa881},
    {0xa8b4, 0xa8c4},
    {0xa8e0, 0xa8f1},
    {0xa926, 0xa92d},
    {0xa947, 0xa953},
    {0xa980, 0xa983},
    {0xa9b3, 0xa9c0},
    {0xaa29, 0xaa36},
    {0xaa43, 0xaa43},
    {0xaa4c, 0xaa4d},
    {0xaa7b, 0xaa7b},
    {0xaab0, 0xaab0},
    {0xaab2, 0xaab4},
    {0xaab7, 0xaab8},
    {0xaabe, 0xaabf},
    {0xaac1, 0xaac1},
    {0xabe3, 0xabea},
    {0xabec, 0xabed},
    {0xfb1e, 0xfb1e},
    {0xfe00, 0xfe0f},
    {0xfe20, 0xfe26},
    {0x101fd, 0x101fd},
    {0x10a01, 0x10a03},
    {0x10a05, 0x10a06},
    {0x10a0c, 0x10a0f},
    {0x10a38, 0x10a3a},
    {0x10a3f, 0x10a3f},
    {0x11080, 0x11082},
    {0x110b0, 0x110ba},
    {0x1d165, 0x1d169},
    {0x1d16d, 0x1d172},
    {0x1d17b, 0x1d182},
    {0x1d185, 0x1d18b},
    {0x1d1aa, 0x1d1ad},
    {0x1d242, 0x1d244},
    {0xe0100, 0xe01ef}
  };

  return intable(combining, sizeof(combining), c);
}

/*
 * Return TRUE for characters that can be displayed in a normal way.
 * Only for characters of 0x100 and above!
 */
int utf_printable(int c)
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

  return !intable(nonprint, sizeof(nonprint), c);
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
  int top = sizeof(classes) / sizeof(struct clinterval) - 1;
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

  /* most other characters are "word" characters */
  return 2;
}

/*
 * Code for Unicode case-dependent operations.  Based on notes in
 * http://www.unicode.org/Public/UNIDATA/CaseFolding.txt
 * This code uses simple case folding, not full case folding.
 * Last updated for Unicode 5.2.
 */

/*
 * The following tables are built by ../runtime/tools/unicode.vim.
 * They must be in numeric order, because we use binary search.
 * An entry such as {0x41,0x5a,1,32} means that Unicode characters in the
 * range from 0x41 to 0x5a inclusive, stepping by 1, are changed to
 * folded/upper/lower by adding 32.
 */
typedef struct {
  int rangeStart;
  int rangeEnd;
  int step;
  int offset;
} convertStruct;

static convertStruct foldCase[] =
{
  {0x41,0x5a,1,32},
  {0xb5,0xb5,-1,775},
  {0xc0,0xd6,1,32},
  {0xd8,0xde,1,32},
  {0x100,0x12e,2,1},
  {0x132,0x136,2,1},
  {0x139,0x147,2,1},
  {0x14a,0x176,2,1},
  {0x178,0x178,-1,-121},
  {0x179,0x17d,2,1},
  {0x17f,0x17f,-1,-268},
  {0x181,0x181,-1,210},
  {0x182,0x184,2,1},
  {0x186,0x186,-1,206},
  {0x187,0x187,-1,1},
  {0x189,0x18a,1,205},
  {0x18b,0x18b,-1,1},
  {0x18e,0x18e,-1,79},
  {0x18f,0x18f,-1,202},
  {0x190,0x190,-1,203},
  {0x191,0x191,-1,1},
  {0x193,0x193,-1,205},
  {0x194,0x194,-1,207},
  {0x196,0x196,-1,211},
  {0x197,0x197,-1,209},
  {0x198,0x198,-1,1},
  {0x19c,0x19c,-1,211},
  {0x19d,0x19d,-1,213},
  {0x19f,0x19f,-1,214},
  {0x1a0,0x1a4,2,1},
  {0x1a6,0x1a6,-1,218},
  {0x1a7,0x1a7,-1,1},
  {0x1a9,0x1a9,-1,218},
  {0x1ac,0x1ac,-1,1},
  {0x1ae,0x1ae,-1,218},
  {0x1af,0x1af,-1,1},
  {0x1b1,0x1b2,1,217},
  {0x1b3,0x1b5,2,1},
  {0x1b7,0x1b7,-1,219},
  {0x1b8,0x1bc,4,1},
  {0x1c4,0x1c4,-1,2},
  {0x1c5,0x1c5,-1,1},
  {0x1c7,0x1c7,-1,2},
  {0x1c8,0x1c8,-1,1},
  {0x1ca,0x1ca,-1,2},
  {0x1cb,0x1db,2,1},
  {0x1de,0x1ee,2,1},
  {0x1f1,0x1f1,-1,2},
  {0x1f2,0x1f4,2,1},
  {0x1f6,0x1f6,-1,-97},
  {0x1f7,0x1f7,-1,-56},
  {0x1f8,0x21e,2,1},
  {0x220,0x220,-1,-130},
  {0x222,0x232,2,1},
  {0x23a,0x23a,-1,10795},
  {0x23b,0x23b,-1,1},
  {0x23d,0x23d,-1,-163},
  {0x23e,0x23e,-1,10792},
  {0x241,0x241,-1,1},
  {0x243,0x243,-1,-195},
  {0x244,0x244,-1,69},
  {0x245,0x245,-1,71},
  {0x246,0x24e,2,1},
  {0x345,0x345,-1,116},
  {0x370,0x372,2,1},
  {0x376,0x376,-1,1},
  {0x386,0x386,-1,38},
  {0x388,0x38a,1,37},
  {0x38c,0x38c,-1,64},
  {0x38e,0x38f,1,63},
  {0x391,0x3a1,1,32},
  {0x3a3,0x3ab,1,32},
  {0x3c2,0x3c2,-1,1},
  {0x3cf,0x3cf,-1,8},
  {0x3d0,0x3d0,-1,-30},
  {0x3d1,0x3d1,-1,-25},
  {0x3d5,0x3d5,-1,-15},
  {0x3d6,0x3d6,-1,-22},
  {0x3d8,0x3ee,2,1},
  {0x3f0,0x3f0,-1,-54},
  {0x3f1,0x3f1,-1,-48},
  {0x3f4,0x3f4,-1,-60},
  {0x3f5,0x3f5,-1,-64},
  {0x3f7,0x3f7,-1,1},
  {0x3f9,0x3f9,-1,-7},
  {0x3fa,0x3fa,-1,1},
  {0x3fd,0x3ff,1,-130},
  {0x400,0x40f,1,80},
  {0x410,0x42f,1,32},
  {0x460,0x480,2,1},
  {0x48a,0x4be,2,1},
  {0x4c0,0x4c0,-1,15},
  {0x4c1,0x4cd,2,1},
  {0x4d0,0x524,2,1},
  {0x531,0x556,1,48},
  {0x10a0,0x10c5,1,7264},
  {0x1e00,0x1e94,2,1},
  {0x1e9b,0x1e9b,-1,-58},
  {0x1e9e,0x1e9e,-1,-7615},
  {0x1ea0,0x1efe,2,1},
  {0x1f08,0x1f0f,1,-8},
  {0x1f18,0x1f1d,1,-8},
  {0x1f28,0x1f2f,1,-8},
  {0x1f38,0x1f3f,1,-8},
  {0x1f48,0x1f4d,1,-8},
  {0x1f59,0x1f5f,2,-8},
  {0x1f68,0x1f6f,1,-8},
  {0x1f88,0x1f8f,1,-8},
  {0x1f98,0x1f9f,1,-8},
  {0x1fa8,0x1faf,1,-8},
  {0x1fb8,0x1fb9,1,-8},
  {0x1fba,0x1fbb,1,-74},
  {0x1fbc,0x1fbc,-1,-9},
  {0x1fbe,0x1fbe,-1,-7173},
  {0x1fc8,0x1fcb,1,-86},
  {0x1fcc,0x1fcc,-1,-9},
  {0x1fd8,0x1fd9,1,-8},
  {0x1fda,0x1fdb,1,-100},
  {0x1fe8,0x1fe9,1,-8},
  {0x1fea,0x1feb,1,-112},
  {0x1fec,0x1fec,-1,-7},
  {0x1ff8,0x1ff9,1,-128},
  {0x1ffa,0x1ffb,1,-126},
  {0x1ffc,0x1ffc,-1,-9},
  {0x2126,0x2126,-1,-7517},
  {0x212a,0x212a,-1,-8383},
  {0x212b,0x212b,-1,-8262},
  {0x2132,0x2132,-1,28},
  {0x2160,0x216f,1,16},
  {0x2183,0x2183,-1,1},
  {0x24b6,0x24cf,1,26},
  {0x2c00,0x2c2e,1,48},
  {0x2c60,0x2c60,-1,1},
  {0x2c62,0x2c62,-1,-10743},
  {0x2c63,0x2c63,-1,-3814},
  {0x2c64,0x2c64,-1,-10727},
  {0x2c67,0x2c6b,2,1},
  {0x2c6d,0x2c6d,-1,-10780},
  {0x2c6e,0x2c6e,-1,-10749},
  {0x2c6f,0x2c6f,-1,-10783},
  {0x2c70,0x2c70,-1,-10782},
  {0x2c72,0x2c75,3,1},
  {0x2c7e,0x2c7f,1,-10815},
  {0x2c80,0x2ce2,2,1},
  {0x2ceb,0x2ced,2,1},
  {0xa640,0xa65e,2,1},
  {0xa662,0xa66c,2,1},
  {0xa680,0xa696,2,1},
  {0xa722,0xa72e,2,1},
  {0xa732,0xa76e,2,1},
  {0xa779,0xa77b,2,1},
  {0xa77d,0xa77d,-1,-35332},
  {0xa77e,0xa786,2,1},
  {0xa78b,0xa78b,-1,1},
  {0xff21,0xff3a,1,32},
  {0x10400,0x10427,1,40}
};

static int utf_convert(int a, convertStruct table[], int tableSize);
static int utf_strnicmp(char_u *s1, char_u *s2, size_t n1, size_t n2);

/*
 * Generic conversion function for case operations.
 * Return the converted equivalent of "a", which is a UCS-4 character.  Use
 * the given conversion "table".  Uses binary search on "table".
 */
static int utf_convert(int a, convertStruct *table, int tableSize)
{
  int start, mid, end;   /* indices into table */
  int entries = tableSize / sizeof(convertStruct);

  start = 0;
  end = entries;
  while (start < end) {
    /* need to search further */
    mid = (end + start) / 2;
    if (table[mid].rangeEnd < a)
      start = mid + 1;
    else
      end = mid;
  }
  if (start < entries
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
  return utf_convert(a, foldCase, (int)sizeof(foldCase));
}

static convertStruct toLower[] =
{
  {0x41,0x5a,1,32},
  {0xc0,0xd6,1,32},
  {0xd8,0xde,1,32},
  {0x100,0x12e,2,1},
  {0x130,0x130,-1,-199},
  {0x132,0x136,2,1},
  {0x139,0x147,2,1},
  {0x14a,0x176,2,1},
  {0x178,0x178,-1,-121},
  {0x179,0x17d,2,1},
  {0x181,0x181,-1,210},
  {0x182,0x184,2,1},
  {0x186,0x186,-1,206},
  {0x187,0x187,-1,1},
  {0x189,0x18a,1,205},
  {0x18b,0x18b,-1,1},
  {0x18e,0x18e,-1,79},
  {0x18f,0x18f,-1,202},
  {0x190,0x190,-1,203},
  {0x191,0x191,-1,1},
  {0x193,0x193,-1,205},
  {0x194,0x194,-1,207},
  {0x196,0x196,-1,211},
  {0x197,0x197,-1,209},
  {0x198,0x198,-1,1},
  {0x19c,0x19c,-1,211},
  {0x19d,0x19d,-1,213},
  {0x19f,0x19f,-1,214},
  {0x1a0,0x1a4,2,1},
  {0x1a6,0x1a6,-1,218},
  {0x1a7,0x1a7,-1,1},
  {0x1a9,0x1a9,-1,218},
  {0x1ac,0x1ac,-1,1},
  {0x1ae,0x1ae,-1,218},
  {0x1af,0x1af,-1,1},
  {0x1b1,0x1b2,1,217},
  {0x1b3,0x1b5,2,1},
  {0x1b7,0x1b7,-1,219},
  {0x1b8,0x1bc,4,1},
  {0x1c4,0x1c4,-1,2},
  {0x1c5,0x1c5,-1,1},
  {0x1c7,0x1c7,-1,2},
  {0x1c8,0x1c8,-1,1},
  {0x1ca,0x1ca,-1,2},
  {0x1cb,0x1db,2,1},
  {0x1de,0x1ee,2,1},
  {0x1f1,0x1f1,-1,2},
  {0x1f2,0x1f4,2,1},
  {0x1f6,0x1f6,-1,-97},
  {0x1f7,0x1f7,-1,-56},
  {0x1f8,0x21e,2,1},
  {0x220,0x220,-1,-130},
  {0x222,0x232,2,1},
  {0x23a,0x23a,-1,10795},
  {0x23b,0x23b,-1,1},
  {0x23d,0x23d,-1,-163},
  {0x23e,0x23e,-1,10792},
  {0x241,0x241,-1,1},
  {0x243,0x243,-1,-195},
  {0x244,0x244,-1,69},
  {0x245,0x245,-1,71},
  {0x246,0x24e,2,1},
  {0x370,0x372,2,1},
  {0x376,0x376,-1,1},
  {0x386,0x386,-1,38},
  {0x388,0x38a,1,37},
  {0x38c,0x38c,-1,64},
  {0x38e,0x38f,1,63},
  {0x391,0x3a1,1,32},
  {0x3a3,0x3ab,1,32},
  {0x3cf,0x3cf,-1,8},
  {0x3d8,0x3ee,2,1},
  {0x3f4,0x3f4,-1,-60},
  {0x3f7,0x3f7,-1,1},
  {0x3f9,0x3f9,-1,-7},
  {0x3fa,0x3fa,-1,1},
  {0x3fd,0x3ff,1,-130},
  {0x400,0x40f,1,80},
  {0x410,0x42f,1,32},
  {0x460,0x480,2,1},
  {0x48a,0x4be,2,1},
  {0x4c0,0x4c0,-1,15},
  {0x4c1,0x4cd,2,1},
  {0x4d0,0x524,2,1},
  {0x531,0x556,1,48},
  {0x10a0,0x10c5,1,7264},
  {0x1e00,0x1e94,2,1},
  {0x1e9e,0x1e9e,-1,-7615},
  {0x1ea0,0x1efe,2,1},
  {0x1f08,0x1f0f,1,-8},
  {0x1f18,0x1f1d,1,-8},
  {0x1f28,0x1f2f,1,-8},
  {0x1f38,0x1f3f,1,-8},
  {0x1f48,0x1f4d,1,-8},
  {0x1f59,0x1f5f,2,-8},
  {0x1f68,0x1f6f,1,-8},
  {0x1f88,0x1f8f,1,-8},
  {0x1f98,0x1f9f,1,-8},
  {0x1fa8,0x1faf,1,-8},
  {0x1fb8,0x1fb9,1,-8},
  {0x1fba,0x1fbb,1,-74},
  {0x1fbc,0x1fbc,-1,-9},
  {0x1fc8,0x1fcb,1,-86},
  {0x1fcc,0x1fcc,-1,-9},
  {0x1fd8,0x1fd9,1,-8},
  {0x1fda,0x1fdb,1,-100},
  {0x1fe8,0x1fe9,1,-8},
  {0x1fea,0x1feb,1,-112},
  {0x1fec,0x1fec,-1,-7},
  {0x1ff8,0x1ff9,1,-128},
  {0x1ffa,0x1ffb,1,-126},
  {0x1ffc,0x1ffc,-1,-9},
  {0x2126,0x2126,-1,-7517},
  {0x212a,0x212a,-1,-8383},
  {0x212b,0x212b,-1,-8262},
  {0x2132,0x2132,-1,28},
  {0x2160,0x216f,1,16},
  {0x2183,0x2183,-1,1},
  {0x24b6,0x24cf,1,26},
  {0x2c00,0x2c2e,1,48},
  {0x2c60,0x2c60,-1,1},
  {0x2c62,0x2c62,-1,-10743},
  {0x2c63,0x2c63,-1,-3814},
  {0x2c64,0x2c64,-1,-10727},
  {0x2c67,0x2c6b,2,1},
  {0x2c6d,0x2c6d,-1,-10780},
  {0x2c6e,0x2c6e,-1,-10749},
  {0x2c6f,0x2c6f,-1,-10783},
  {0x2c70,0x2c70,-1,-10782},
  {0x2c72,0x2c75,3,1},
  {0x2c7e,0x2c7f,1,-10815},
  {0x2c80,0x2ce2,2,1},
  {0x2ceb,0x2ced,2,1},
  {0xa640,0xa65e,2,1},
  {0xa662,0xa66c,2,1},
  {0xa680,0xa696,2,1},
  {0xa722,0xa72e,2,1},
  {0xa732,0xa76e,2,1},
  {0xa779,0xa77b,2,1},
  {0xa77d,0xa77d,-1,-35332},
  {0xa77e,0xa786,2,1},
  {0xa78b,0xa78b,-1,1},
  {0xff21,0xff3a,1,32},
  {0x10400,0x10427,1,40}
};

static convertStruct toUpper[] =
{
  {0x61,0x7a,1,-32},
  {0xb5,0xb5,-1,743},
  {0xe0,0xf6,1,-32},        /* 0xdf (German sharp s) is not upper-cased */
  {0xf8,0xfe,1,-32},
  {0xff,0xff,-1,121},
  {0x101,0x12f,2,-1},
  {0x131,0x131,-1,-232},
  {0x133,0x137,2,-1},
  {0x13a,0x148,2,-1},
  {0x14b,0x177,2,-1},
  {0x17a,0x17e,2,-1},
  {0x17f,0x17f,-1,-300},
  {0x180,0x180,-1,195},
  {0x183,0x185,2,-1},
  {0x188,0x18c,4,-1},
  {0x192,0x192,-1,-1},
  {0x195,0x195,-1,97},
  {0x199,0x199,-1,-1},
  {0x19a,0x19a,-1,163},
  {0x19e,0x19e,-1,130},
  {0x1a1,0x1a5,2,-1},
  {0x1a8,0x1ad,5,-1},
  {0x1b0,0x1b4,4,-1},
  {0x1b6,0x1b9,3,-1},
  {0x1bd,0x1bd,-1,-1},
  {0x1bf,0x1bf,-1,56},
  {0x1c5,0x1c5,-1,-1},
  {0x1c6,0x1c6,-1,-2},
  {0x1c8,0x1c8,-1,-1},
  {0x1c9,0x1c9,-1,-2},
  {0x1cb,0x1cb,-1,-1},
  {0x1cc,0x1cc,-1,-2},
  {0x1ce,0x1dc,2,-1},
  {0x1dd,0x1dd,-1,-79},
  {0x1df,0x1ef,2,-1},
  {0x1f2,0x1f2,-1,-1},
  {0x1f3,0x1f3,-1,-2},
  {0x1f5,0x1f9,4,-1},
  {0x1fb,0x21f,2,-1},
  {0x223,0x233,2,-1},
  {0x23c,0x23c,-1,-1},
  {0x23f,0x240,1,10815},
  {0x242,0x247,5,-1},
  {0x249,0x24f,2,-1},
  {0x250,0x250,-1,10783},
  {0x251,0x251,-1,10780},
  {0x252,0x252,-1,10782},
  {0x253,0x253,-1,-210},
  {0x254,0x254,-1,-206},
  {0x256,0x257,1,-205},
  {0x259,0x259,-1,-202},
  {0x25b,0x25b,-1,-203},
  {0x260,0x260,-1,-205},
  {0x263,0x263,-1,-207},
  {0x268,0x268,-1,-209},
  {0x269,0x269,-1,-211},
  {0x26b,0x26b,-1,10743},
  {0x26f,0x26f,-1,-211},
  {0x271,0x271,-1,10749},
  {0x272,0x272,-1,-213},
  {0x275,0x275,-1,-214},
  {0x27d,0x27d,-1,10727},
  {0x280,0x283,3,-218},
  {0x288,0x288,-1,-218},
  {0x289,0x289,-1,-69},
  {0x28a,0x28b,1,-217},
  {0x28c,0x28c,-1,-71},
  {0x292,0x292,-1,-219},
  {0x345,0x345,-1,84},
  {0x371,0x373,2,-1},
  {0x377,0x377,-1,-1},
  {0x37b,0x37d,1,130},
  {0x3ac,0x3ac,-1,-38},
  {0x3ad,0x3af,1,-37},
  {0x3b1,0x3c1,1,-32},
  {0x3c2,0x3c2,-1,-31},
  {0x3c3,0x3cb,1,-32},
  {0x3cc,0x3cc,-1,-64},
  {0x3cd,0x3ce,1,-63},
  {0x3d0,0x3d0,-1,-62},
  {0x3d1,0x3d1,-1,-57},
  {0x3d5,0x3d5,-1,-47},
  {0x3d6,0x3d6,-1,-54},
  {0x3d7,0x3d7,-1,-8},
  {0x3d9,0x3ef,2,-1},
  {0x3f0,0x3f0,-1,-86},
  {0x3f1,0x3f1,-1,-80},
  {0x3f2,0x3f2,-1,7},
  {0x3f5,0x3f5,-1,-96},
  {0x3f8,0x3fb,3,-1},
  {0x430,0x44f,1,-32},
  {0x450,0x45f,1,-80},
  {0x461,0x481,2,-1},
  {0x48b,0x4bf,2,-1},
  {0x4c2,0x4ce,2,-1},
  {0x4cf,0x4cf,-1,-15},
  {0x4d1,0x525,2,-1},
  {0x561,0x586,1,-48},
  {0x1d79,0x1d79,-1,35332},
  {0x1d7d,0x1d7d,-1,3814},
  {0x1e01,0x1e95,2,-1},
  {0x1e9b,0x1e9b,-1,-59},
  {0x1ea1,0x1eff,2,-1},
  {0x1f00,0x1f07,1,8},
  {0x1f10,0x1f15,1,8},
  {0x1f20,0x1f27,1,8},
  {0x1f30,0x1f37,1,8},
  {0x1f40,0x1f45,1,8},
  {0x1f51,0x1f57,2,8},
  {0x1f60,0x1f67,1,8},
  {0x1f70,0x1f71,1,74},
  {0x1f72,0x1f75,1,86},
  {0x1f76,0x1f77,1,100},
  {0x1f78,0x1f79,1,128},
  {0x1f7a,0x1f7b,1,112},
  {0x1f7c,0x1f7d,1,126},
  {0x1f80,0x1f87,1,8},
  {0x1f90,0x1f97,1,8},
  {0x1fa0,0x1fa7,1,8},
  {0x1fb0,0x1fb1,1,8},
  {0x1fb3,0x1fb3,-1,9},
  {0x1fbe,0x1fbe,-1,-7205},
  {0x1fc3,0x1fc3,-1,9},
  {0x1fd0,0x1fd1,1,8},
  {0x1fe0,0x1fe1,1,8},
  {0x1fe5,0x1fe5,-1,7},
  {0x1ff3,0x1ff3,-1,9},
  {0x214e,0x214e,-1,-28},
  {0x2170,0x217f,1,-16},
  {0x2184,0x2184,-1,-1},
  {0x24d0,0x24e9,1,-26},
  {0x2c30,0x2c5e,1,-48},
  {0x2c61,0x2c61,-1,-1},
  {0x2c65,0x2c65,-1,-10795},
  {0x2c66,0x2c66,-1,-10792},
  {0x2c68,0x2c6c,2,-1},
  {0x2c73,0x2c76,3,-1},
  {0x2c81,0x2ce3,2,-1},
  {0x2cec,0x2cee,2,-1},
  {0x2d00,0x2d25,1,-7264},
  {0xa641,0xa65f,2,-1},
  {0xa663,0xa66d,2,-1},
  {0xa681,0xa697,2,-1},
  {0xa723,0xa72f,2,-1},
  {0xa733,0xa76f,2,-1},
  {0xa77a,0xa77c,2,-1},
  {0xa77f,0xa787,2,-1},
  {0xa78c,0xa78c,-1,-1},
  {0xff41,0xff5a,1,-32},
  {0x10428,0x1044f,1,-40}
};

/*
 * Return the upper-case equivalent of "a", which is a UCS-4 character.  Use
 * simple case folding.
 */
int utf_toupper(int a)
{
  /* If 'casemap' contains "keepascii" use ASCII style toupper(). */
  if (a < 128 && (cmp_flags & CMP_KEEPASCII))
    return TOUPPER_ASC(a);

#if defined(HAVE_TOWUPPER) && defined(__STDC_ISO_10646__)
  /* If towupper() is available and handles Unicode, use it. */
  if (!(cmp_flags & CMP_INTERNAL))
    return towupper(a);
#endif

  /* For characters below 128 use locale sensitive toupper(). */
  if (a < 128)
    return TOUPPER_LOC(a);

  /* For any other characters use the above mapping table. */
  return utf_convert(a, toUpper, (int)sizeof(toUpper));
}

int utf_islower(int a)
{
  /* German sharp s is lower case but has no upper case equivalent. */
  return (utf_toupper(a) != a) || a == 0xdf;
}

/*
 * Return the lower-case equivalent of "a", which is a UCS-4 character.  Use
 * simple case folding.
 */
int utf_tolower(int a)
{
  /* If 'casemap' contains "keepascii" use ASCII style tolower(). */
  if (a < 128 && (cmp_flags & CMP_KEEPASCII))
    return TOLOWER_ASC(a);

#if defined(HAVE_TOWLOWER) && defined(__STDC_ISO_10646__)
  /* If towlower() is available and handles Unicode, use it. */
  if (!(cmp_flags & CMP_INTERNAL))
    return towlower(a);
#endif

  /* For characters below 128 use locale sensitive tolower(). */
  if (a < 128)
    return TOLOWER_LOC(a);

  /* For any other characters use the above mapping table. */
  return utf_convert(a, toLower, (int)sizeof(toLower));
}

int utf_isupper(int a)
{
  return utf_tolower(a) != a;
}

static int utf_strnicmp(char_u *s1, char_u *s2, size_t n1, size_t n2)
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
  } else if (c2 != -1 && c1 == -1)   {
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

/*
 * Version of strnicmp() that handles multi-byte characters.
 * Needed for Big5, Shift-JIS and UTF-8 encoding.  Other DBCS encodings can
 * probably use strnicmp(), because there are no ASCII characters in the
 * second byte.
 * Returns zero if s1 and s2 are equal (ignoring case), the difference between
 * two characters otherwise.
 */
int mb_strnicmp(char_u *s1, char_u *s2, size_t nn)
{
  int i, l;
  int cdiff;
  int n = (int)nn;

  if (enc_utf8) {
    return utf_strnicmp(s1, s2, nn, nn);
  } else   {
    for (i = 0; i < n; i += l) {
      if (s1[i] == NUL && s2[i] == NUL)         /* both strings end */
        return 0;

      l = (*mb_ptr2len)(s1 + i);
      if (l <= 1) {
        /* Single byte: first check normally, then with ignore case. */
        if (s1[i] != s2[i]) {
          cdiff = MB_TOLOWER(s1[i]) - MB_TOLOWER(s2[i]);
          if (cdiff != 0)
            return cdiff;
        }
      } else   {
        /* For non-Unicode multi-byte don't ignore case. */
        if (l > n - i)
          l = n - i;
        cdiff = STRNCMP(s1 + i, s2 + i, l);
        if (cdiff != 0)
          return cdiff;
      }
    }
  }
  return 0;
}

/*
 * "g8": show bytes of the UTF-8 char under the cursor.  Doesn't matter what
 * 'encoding' has been set to.
 */
void show_utf8()          {
  int len;
  int rlen = 0;
  char_u      *line;
  int clen;
  int i;

  /* Get the byte length of the char under the cursor, including composing
   * characters. */
  line = ml_get_cursor();
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

/*
 * mb_head_off() function pointer.
 * Return offset from "p" to the first byte of the character it points into.
 * If "p" points to the NUL at the end of the string return 0.
 * Returns 0 when already at the first byte of a character.
 */
int latin_head_off(char_u *base, char_u *p)
{
  return 0;
}

int dbcs_head_off(char_u *base, char_u *p)
{
  char_u      *q;

  /* It can't be a trailing byte when not using DBCS, at the start of the
   * string or the previous byte can't start a double-byte. */
  if (p <= base || MB_BYTE2LEN(p[-1]) == 1 || *p == NUL)
    return 0;

  /* This is slow: need to start at the base and go forward until the
   * byte we are looking for.  Return 1 when we went past it, 0 otherwise. */
  q = base;
  while (q < p)
    q += dbcs_ptr2len(q);
  return (q == p) ? 0 : 1;
}

/*
 * Special version of dbcs_head_off() that works for ScreenLines[], where
 * single-width DBCS_JPNU characters are stored separately.
 */
int dbcs_screen_head_off(char_u *base, char_u *p)
{
  char_u      *q;

  /* It can't be a trailing byte when not using DBCS, at the start of the
   * string or the previous byte can't start a double-byte.
   * For euc-jp an 0x8e byte in the previous cell always means we have a
   * lead byte in the current cell. */
  if (p <= base
      || (enc_dbcs == DBCS_JPNU && p[-1] == 0x8e)
      || MB_BYTE2LEN(p[-1]) == 1
      || *p == NUL)
    return 0;

  /* This is slow: need to start at the base and go forward until the
   * byte we are looking for.  Return 1 when we went past it, 0 otherwise.
   * For DBCS_JPNU look out for 0x8e, which means the second byte is not
   * stored as the next byte. */
  q = base;
  while (q < p) {
    if (enc_dbcs == DBCS_JPNU && *q == 0x8e)
      ++q;
    else
      q += dbcs_ptr2len(q);
  }
  return (q == p) ? 0 : 1;
}

int utf_head_off(char_u *base, char_u *p)
{
  char_u      *q;
  char_u      *s;
  int c;
  int len;
  char_u      *j;

  if (*p < 0x80)                /* be quick for ASCII */
    return 0;

  /* Skip backwards over trailing bytes: 10xx.xxxx
   * Skip backwards again if on a composing char. */
  for (q = p;; --q) {
    /* Move s to the last byte of this char. */
    for (s = q; (s[1] & 0xc0) == 0x80; ++s)
      ;
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
      j = q;
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

/*
 * Copy a character from "*fp" to "*tp" and advance the pointers.
 */
void mb_copy_char(char_u **fp, char_u **tp)
{
  int l = (*mb_ptr2len)(*fp);

  mch_memmove(*tp, *fp, (size_t)l);
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

  if (enc_utf8) {
    if (*p < 0x80)              /* be quick for ASCII */
      return 0;

    /* Find the next character that isn't 10xx.xxxx */
    for (i = 0; (p[i] & 0xc0) == 0x80; ++i)
      ;
    if (i > 0) {
      /* Check for illegal sequence. */
      for (j = 0; p - j > base; ++j)
        if ((p[-j] & 0xc0) != 0x80)
          break;
      if (utf8len_tab[p[-j]] != i + j)
        return 0;
    }
    return i;
  }

  /* Only need to check if we're on a trail byte, it doesn't matter if we
   * want the offset to the next or current character. */
  return (*mb_head_off)(base, p);
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

  if (enc_utf8) {
    /* Find the last character that is 10xx.xxxx */
    for (i = 0; (p[i + 1] & 0xc0) == 0x80; ++i)
      ;
    /* Check for illegal sequence. */
    for (j = 0; p - j > base; ++j)
      if ((p[-j] & 0xc0) != 0x80)
        break;
    if (utf8len_tab[p[-j]] != i + j + 1)
      return 0;
    return i;
  }

  /* It can't be the first byte if a double-byte when not using DBCS, at the
   * end of the string or the byte can't start a double-byte. */
  if (enc_dbcs == 0 || p[1] == NUL || MB_BYTE2LEN(*p) == 1)
    return 0;

  /* Return 1 when on the lead byte, 0 when on the tail byte. */
  return 1 - dbcs_head_off(base, p);
}

/*
 * Find the next illegal byte sequence.
 */
void utf_find_illegal()          {
  pos_T pos = curwin->w_cursor;
  char_u      *p;
  int len;
  vimconv_T vimconv;
  char_u      *tofree = NULL;

  vimconv.vc_type = CONV_NONE;
  if (enc_utf8 && (enc_canon_props(curbuf->b_p_fenc) & ENC_8BIT)) {
    /* 'encoding' is "utf-8" but we are editing a 8-bit encoded file,
     * possibly a utf-8 file with illegal bytes.  Setup for conversion
     * from utf-8 to 'fileencoding'. */
    convert_setup(&vimconv, p_enc, curbuf->b_p_fenc);
  }

  curwin->w_cursor.coladd = 0;
  for (;; ) {
    p = ml_get_cursor();
    if (vimconv.vc_type != CONV_NONE) {
      vim_free(tofree);
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
          curwin->w_cursor.col += (colnr_T)(p - ml_get_cursor());
        else {
          int l;

          len = (int)(p - tofree);
          for (p = ml_get_cursor(); *p != NUL && len-- > 0; p += l) {
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
  vim_free(tofree);
  convert_setup(&vimconv, NULL, NULL);
}

/*
 * If the cursor moves on an trail byte, set the cursor on the lead byte.
 * Thus it moves left if necessary.
 * Return TRUE when the cursor was adjusted.
 */
void mb_adjust_cursor()          {
  mb_adjustpos(curbuf, &curwin->w_cursor);
}

/*
 * Adjust position "*lp" to point to the first byte of a multi-byte character.
 * If it points to a tail byte it's moved backwards to the head byte.
 */
void mb_adjustpos(buf_T *buf, pos_T *lp)
{
  char_u      *p;

  if (lp->col > 0
      || lp->coladd > 1
     ) {
    p = ml_get_buf(buf, lp->lnum, FALSE);
    lp->col -= (*mb_head_off)(p, p + lp->col);
    /* Reset "coladd" when the cursor would be on the right half of a
     * double-wide character. */
    if (lp->coladd == 1
        && p[lp->col] != TAB
        && vim_isprintc((*mb_ptr2char)(p + lp->col))
        && ptr2cells(p + lp->col) > 1)
      lp->coladd = 0;
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
  if (p > line)
    mb_ptr_back(line, p);
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

/*
 * Try to un-escape a multi-byte character.
 * Used for the "to" and "from" part of a mapping.
 * Return the un-escaped string if it is a multi-byte character, and advance
 * "pp" to just after the bytes that formed it.
 * Return NULL if no multi-byte char was found.
 */
char_u * mb_unescape(char_u **pp)
{
  static char_u buf[6];
  int n;
  int m = 0;
  char_u              *str = *pp;

  /* Must translate K_SPECIAL KS_SPECIAL KE_FILLER to K_SPECIAL and CSI
   * KS_EXTRA KE_CSI to CSI.
   * Maximum length of a utf-8 character is 4 bytes. */
  for (n = 0; str[n] != NUL && m < 4; ++n) {
    if (str[n] == K_SPECIAL
        && str[n + 1] == KS_SPECIAL
        && str[n + 2] == KE_FILLER) {
      buf[m++] = K_SPECIAL;
      n += 2;
    } else if ((str[n] == K_SPECIAL
          )
        && str[n + 1] == KS_EXTRA
        && str[n + 2] == (int)KE_CSI) {
      buf[m++] = CSI;
      n += 2;
    } else if (str[n] == K_SPECIAL
        )
      break;                    /* a special key can't be a multibyte char */
    else
      buf[m++] = str[n];
    buf[m] = NUL;

    /* Return a multi-byte character if it's found.  An illegal sequence
     * will result in a 1 here. */
    if ((*mb_ptr2len)(buf) > 1) {
      *pp = str + n + 1;
      return buf;
    }

    /* Bail out quickly for ASCII. */
    if (buf[0] < 128)
      break;
  }
  return NULL;
}

/*
 * Return TRUE if the character at "row"/"col" on the screen is the left side
 * of a double-width character.
 * Caller must make sure "row" and "col" are not invalid!
 */
int mb_lefthalve(int row, int col)
{
  if (composing_hangul)
    return TRUE;
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
  if (has_mbyte && ScreenLines != NULL && col > 0
      && ((enc_dbcs
          && ScreenLines[LineOffset[row] + col] != NUL
          && dbcs_screen_head_off(ScreenLines + LineOffset[row],
            ScreenLines + LineOffset[row] + col))
        || (enc_utf8 && ScreenLines[LineOffset[row] + col] == 0)))
    return col - 1;
  return col;
}

static int enc_alias_search(char_u *name);

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
 * Returns an allocated string.  NULL for out-of-memory.
 */
char_u * enc_canonize(char_u *enc)
{
  char_u      *r;
  char_u      *p, *s;
  int i;

  if (STRCMP(enc, "default") == 0) {
    /* Use the default encoding as it's found by set_init_1(). */
    r = get_encoding_default();
    if (r == NULL)
      r = (char_u *)"latin1";
    return vim_strsave(r);
  }

  /* copy "enc" to allocated memory, with room for two '-' */
  r = alloc((unsigned)(STRLEN(enc) + 3));
  if (r != NULL) {
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
    } else if ((i = enc_alias_search(p)) >= 0)   {
      /* alias recognized, get canonical name */
      vim_free(r);
      r = vim_strsave((char_u *)enc_canon_table[i].name);
    }
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
char_u * enc_locale()              {
  char        *s;
  char        *p;
  int i;
  char buf[50];
# ifdef HAVE_NL_LANGINFO_CODESET
  if ((s = nl_langinfo(CODESET)) == NULL || *s == NUL)
# endif
#  if defined(HAVE_LOCALE_H) || defined(X_LOCALE)
    if ((s = setlocale(LC_CTYPE, NULL)) == NULL || *s == NUL)
#  endif
      if ((s = getenv("LC_ALL")) == NULL || *s == NUL)
        if ((s = getenv("LC_CTYPE")) == NULL || *s == NUL)
          s = getenv("LANG");

  if (s == NULL || *s == NUL)
    return FAIL;

  /* The most generic locale format is:
   * language[_territory][.codeset][@modifier][+special][,[sponsor][_revision]]
   * If there is a '.' remove the part before it.
   * if there is something after the codeset, remove it.
   * Make the name lowercase and replace '_' with '-'.
   * Exception: "ja_JP.EUC" == "euc-jp", "zh_CN.EUC" = "euc-cn",
   * "ko_KR.EUC" == "euc-kr"
   */
  if ((p = (char *)vim_strchr((char_u *)s, '.')) != NULL) {
    if (p > s + 2 && STRNICMP(p + 1, "EUC", 3) == 0
        && !isalnum((int)p[4]) && p[4] != '-' && p[-3] == '_') {
      /* copy "XY.EUC" to "euc-XY" to buf[10] */
      STRCPY(buf + 10, "euc-");
      buf[14] = p[-2];
      buf[15] = p[-1];
      buf[16] = 0;
      s = buf + 10;
    } else
      s = p + 1;
  }
  for (i = 0; s[i] != NUL && i < (int)sizeof(buf) - 1; ++i) {
    if (s[i] == '_' || s[i] == '-')
      buf[i] = '-';
    else if (isalnum((int)s[i]))
      buf[i] = TOLOWER_ASC(s[i]);
    else
      break;
  }
  buf[i] = NUL;

  return enc_canonize((char_u *)buf);
}

# if defined(USE_ICONV) || defined(PROTO)

static char_u *
iconv_string(vimconv_T *vcp, char_u *str, int slen, int *unconvlenp,
             int *resultlenp);

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
  static int iconv_ok = -1;

  if (iconv_ok == FALSE)
    return (void *)-1;          /* detected a broken iconv() previously */

#ifdef DYNAMIC_ICONV
  /* Check if the iconv.dll can be found. */
  if (!iconv_enabled(TRUE))
    return (void *)-1;
#endif

  fd = iconv_open((char *)enc_skip(to), (char *)enc_skip(from));

  if (fd != (iconv_t)-1 && iconv_ok == -1) {
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
      iconv_ok = FALSE;
      iconv_close(fd);
      fd = (iconv_t)-1;
    } else
      iconv_ok = TRUE;
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
static char_u * iconv_string(vimconv_T *vcp, char_u *str, int slen, int *unconvlenp, int *resultlenp)
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
      p = alloc((unsigned)len);
      if (p != NULL && done > 0)
        mch_memmove(p, result, done);
      vim_free(result);
      result = p;
      if (result == NULL)       /* out of memory */
        break;
    }

    to = (char *)result + done;
    tolen = len - done - 2;
    /* Avoid a warning for systems with a wrong iconv() prototype by
     * casting the second argument to void *. */
    if (iconv(vcp->vc_fd, (void *)&from, &fromlen, &to, &tolen)
        != (size_t)-1) {
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
      *unconvlenp = (int)fromlen;
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
      if (enc_utf8)
        l = utfc_ptr2len_len((char_u *)from, (int)fromlen);
      else {
        l = (*mb_ptr2len)((char_u *)from);
        if (l > (int)fromlen)
          l = (int)fromlen;
      }
      from += l;
      fromlen -= l;
    } else if (ICONV_ERRNO != ICONV_E2BIG)   {
      /* conversion failed */
      vim_free(result);
      result = NULL;
      break;
    }
    /* Not enough room or skipping illegal sequence. */
    done = to - (char *)result;
  }

  if (resultlenp != NULL && result != NULL)
    *resultlenp = (int)(to - (char *)result);
  return result;
}

#  if defined(DYNAMIC_ICONV) || defined(PROTO)
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
#   define DYNAMIC_ICONV_DLL_ALT "libiconv.dll"
#  endif
#  ifndef DYNAMIC_MSVCRT_DLL
#   define DYNAMIC_MSVCRT_DLL "msvcrt.dll"
#  endif

/*
 * Get the address of 'funcname' which is imported by 'hInst' DLL.
 */
static void * get_iconv_import_func(HINSTANCE hInst,
    const char *funcname)                   {
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

/*
 * Try opening the iconv.dll and return TRUE if iconv() can be used.
 */
int iconv_enabled(int verbose)
{
  if (hIconvDLL != 0 && hMsvcrtDLL != 0)
    return TRUE;
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
    return FALSE;
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
    return FALSE;
  }
  return TRUE;
}

void iconv_end()          {
  /* Don't use iconv() when inputting or outputting characters. */
  if (input_conv.vc_type == CONV_ICONV)
    convert_setup(&input_conv, NULL, NULL);
  if (output_conv.vc_type == CONV_ICONV)
    convert_setup(&output_conv, NULL, NULL);

  if (hIconvDLL != 0)
    FreeLibrary(hIconvDLL);
  if (hMsvcrtDLL != 0)
    FreeLibrary(hMsvcrtDLL);
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
int convert_setup(vcp, from, to)
  vimconv_T   *vcp;
  char_u      *from;
  char_u      *to;
{
  return convert_setup_ext(vcp, from, TRUE, to, TRUE);
}

/*
 * As convert_setup(), but only when from_unicode_is_utf8 is TRUE will all
 * "from" unicode charsets be considered utf-8.  Same for "to".
 */
int convert_setup_ext(vcp, from, from_unicode_is_utf8, to, to_unicode_is_utf8)
  vimconv_T   *vcp;
  char_u      *from;
  int from_unicode_is_utf8;
  char_u      *to;
  int to_unicode_is_utf8;
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
  vcp->vc_type = CONV_NONE;
  vcp->vc_factor = 1;
  vcp->vc_fail = FALSE;

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
  } else if ((from_prop & ENC_LATIN9) && to_is_utf8)   {
    /* Internal latin9 -> utf-8 conversion. */
    vcp->vc_type = CONV_9_TO_UTF8;
    vcp->vc_factor = 3;         /* up to three as long (euro sign) */
  } else if (from_is_utf8 && (to_prop & ENC_LATIN1))   {
    /* Internal utf-8 -> latin1 conversion. */
    vcp->vc_type = CONV_TO_LATIN1;
  } else if (from_is_utf8 && (to_prop & ENC_LATIN9))   {
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

#if defined(FEAT_GUI) || defined(AMIGA) || defined(WIN3264) \
  || defined(MSDOS) || defined(PROTO)
/*
 * Do conversion on typed input characters in-place.
 * The input and output are not NUL terminated!
 * Returns the length after conversion.
 */
int convert_input(ptr, len, maxlen)
  char_u      *ptr;
  int len;
  int maxlen;
{
  return convert_input_safe(ptr, len, maxlen, NULL, NULL);
}
#endif

/*
 * Like convert_input(), but when there is an incomplete byte sequence at the
 * end return that as an allocated string in "restp" and set "*restlenp" to
 * the length.  If "restp" is NULL it is not used.
 */
int convert_input_safe(ptr, len, maxlen, restp, restlenp)
  char_u      *ptr;
  int len;
  int maxlen;
  char_u      **restp;
  int         *restlenp;
{
  char_u      *d;
  int dlen = len;
  int unconvertlen = 0;

  d = string_convert_ext(&input_conv, ptr, &dlen,
      restp == NULL ? NULL : &unconvertlen);
  if (d != NULL) {
    if (dlen <= maxlen) {
      if (unconvertlen > 0) {
        /* Move the unconverted characters to allocated memory. */
        *restp = alloc(unconvertlen);
        if (*restp != NULL)
          mch_memmove(*restp, ptr + len - unconvertlen, unconvertlen);
        *restlenp = unconvertlen;
      }
      mch_memmove(ptr, d, dlen);
    } else
      /* result is too long, keep the unconverted text (the caller must
       * have done something wrong!) */
      dlen = len;
    vim_free(d);
  }
  return dlen;
}

/*
 * Convert text "ptr[*lenp]" according to "vcp".
 * Returns the result in allocated memory and sets "*lenp".
 * When "lenp" is NULL, use NUL terminated strings.
 * Illegal chars are often changed to "?", unless vcp->vc_fail is set.
 * When something goes wrong, NULL is returned and "*lenp" is unchanged.
 */
char_u * string_convert(vcp, ptr, lenp)
  vimconv_T   *vcp;
  char_u      *ptr;
  int         *lenp;
{
  return string_convert_ext(vcp, ptr, lenp, NULL);
}

/*
 * Like string_convert(), but when "unconvlenp" is not NULL and there are is
 * an incomplete sequence at the end it is not converted and "*unconvlenp" is
 * set to the number of remaining bytes.
 */
char_u * string_convert_ext(vcp, ptr, lenp, unconvlenp)
  vimconv_T   *vcp;
  char_u      *ptr;
  int         *lenp;
  int         *unconvlenp;
{
  char_u      *retval = NULL;
  char_u      *d;
  int len;
  int i;
  int l;
  int c;

  if (lenp == NULL)
    len = (int)STRLEN(ptr);
  else
    len = *lenp;
  if (len == 0)
    return vim_strsave((char_u *)"");

  switch (vcp->vc_type) {
    case CONV_TO_UTF8:            /* latin1 to utf-8 conversion */
      retval = alloc(len * 2 + 1);
      if (retval == NULL)
        break;
      d = retval;
      for (i = 0; i < len; ++i) {
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
        *lenp = (int)(d - retval);
      break;

    case CONV_9_TO_UTF8:          /* latin9 to utf-8 conversion */
      retval = alloc(len * 3 + 1);
      if (retval == NULL)
        break;
      d = retval;
      for (i = 0; i < len; ++i) {
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
        *lenp = (int)(d - retval);
      break;

    case CONV_TO_LATIN1:          /* utf-8 to latin1 conversion */
    case CONV_TO_LATIN9:          /* utf-8 to latin9 conversion */
      retval = alloc(len + 1);
      if (retval == NULL)
        break;
      d = retval;
      for (i = 0; i < len; ++i) {
        l = utf_ptr2len_len(ptr + i, len - i);
        if (l == 0)
          *d++ = NUL;
        else if (l == 1) {
          int l_w = utf8len_tab_zero[ptr[i]];

          if (l_w == 0) {
            /* Illegal utf-8 byte cannot be converted */
            vim_free(retval);
            return NULL;
          }
          if (unconvlenp != NULL && l_w > len - i) {
            /* Incomplete sequence at the end. */
            *unconvlenp = len - i;
            break;
          }
          *d++ = ptr[i];
        } else   {
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
              vim_free(retval);
              return NULL;
            } else   {
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
        *lenp = (int)(d - retval);
      break;

# ifdef MACOS_CONVERT
    case CONV_MAC_LATIN1:
      retval = mac_string_convert(ptr, len, lenp, vcp->vc_fail,
          'm', 'l', unconvlenp);
      break;

    case CONV_LATIN1_MAC:
      retval = mac_string_convert(ptr, len, lenp, vcp->vc_fail,
          'l', 'm', unconvlenp);
      break;

    case CONV_MAC_UTF8:
      retval = mac_string_convert(ptr, len, lenp, vcp->vc_fail,
          'm', 'u', unconvlenp);
      break;

    case CONV_UTF8_MAC:
      retval = mac_string_convert(ptr, len, lenp, vcp->vc_fail,
          'u', 'm', unconvlenp);
      break;
# endif

# ifdef USE_ICONV
    case CONV_ICONV:              /* conversion with output_conv.vc_fd */
      retval = iconv_string(vcp, ptr, len, unconvlenp, lenp);
      break;
# endif
  }

  return retval;
}
