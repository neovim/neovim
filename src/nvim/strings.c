// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <math.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/charset.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/gettext.h"
#include "nvim/macros.h"
#include "nvim/math.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/plines.h"
#include "nvim/strings.h"
#include "nvim/types.h"
#include "nvim/vim.h"

/// Copy up to `len` bytes of `string` into newly allocated memory and
/// terminate with a NUL. The allocated memory always has size `len + 1`, even
/// when `string` is shorter.
char *xstrnsave(const char *string, size_t len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  return strncpy(xmallocz(len), string, len);  // NOLINT(runtime/printf)
}

// Same as vim_strsave(), but any characters found in esc_chars are preceded
// by a backslash.
char *vim_strsave_escaped(const char *string, const char *esc_chars)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  return vim_strsave_escaped_ext(string, esc_chars, '\\', false);
}

// Same as vim_strsave_escaped(), but when "bsl" is true also escape
// characters where rem_backslash() would remove the backslash.
// Escape the characters with "cc".
char *vim_strsave_escaped_ext(const char *string, const char *esc_chars, char cc, bool bsl)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  // First count the number of backslashes required.
  // Then allocate the memory and insert them.
  size_t length = 1;                    // count the trailing NUL
  for (const char *p = string; *p; p++) {
    const size_t l = (size_t)(utfc_ptr2len(p));
    if (l > 1) {
      length += l;                      // count a multibyte char
      p += l - 1;
      continue;
    }
    if (vim_strchr(esc_chars, (uint8_t)(*p)) != NULL || (bsl && rem_backslash(p))) {
      length++;                         // count a backslash
    }
    length++;                           // count an ordinary char
  }

  char *escaped_string = xmalloc(length);
  char *p2 = escaped_string;
  for (const char *p = string; *p; p++) {
    const size_t l = (size_t)(utfc_ptr2len(p));
    if (l > 1) {
      memcpy(p2, p, l);
      p2 += l;
      p += l - 1;                     // skip multibyte char
      continue;
    }
    if (vim_strchr(esc_chars, (uint8_t)(*p)) != NULL || (bsl && rem_backslash(p))) {
      *p2++ = cc;
    }
    *p2++ = *p;
  }
  *p2 = NUL;

  return escaped_string;
}

/// Save a copy of an unquoted string
///
/// Turns string like `a\bc"def\"ghi\\\n"jkl` into `a\bcdef"ghi\\njkl`, for use
/// in shell_build_argv: the only purpose of backslash is making next character
/// be treated literally inside the double quotes, if this character is
/// backslash or quote.
///
/// @param[in]  string  String to copy.
/// @param[in]  length  Length of the string to copy.
///
/// @return [allocated] Copy of the string.
char *vim_strnsave_unquoted(const char *const string, const size_t length)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
#define ESCAPE_COND(p, inquote, string_end) \
  (*(p) == '\\' && (inquote) && (p) + 1 < (string_end) && ((p)[1] == '\\' || (p)[1] == '"'))
  size_t ret_length = 0;
  bool inquote = false;
  const char *const string_end = string + length;
  for (const char *p = string; p < string_end; p++) {
    if (*p == '"') {
      inquote = !inquote;
    } else if (ESCAPE_COND(p, inquote, string_end)) {
      ret_length++;
      p++;
    } else {
      ret_length++;
    }
  }

  char *const ret = xmallocz(ret_length);
  char *rp = ret;
  inquote = false;
  for (const char *p = string; p < string_end; p++) {
    if (*p == '"') {
      inquote = !inquote;
    } else if (ESCAPE_COND(p, inquote, string_end)) {
      *rp++ = *(++p);
    } else {
      *rp++ = *p;
    }
  }
#undef ESCAPE_COND

  return ret;
}

/// Escape "string" for use as a shell argument with system().
/// This uses single quotes, except when we know we need to use double quotes
/// (MS-Windows without 'shellslash' set).
/// Escape a newline, depending on the 'shell' option.
/// When "do_special" is true also replace "!", "%", "#" and things starting
/// with "<" like "<cfile>".
/// When "do_newline" is false do not escape newline unless it is csh shell.
///
/// @return  the result in allocated memory.
char *vim_strsave_shellescape(const char *string, bool do_special, bool do_newline)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char *d;
  char *escaped_string;
  size_t l;
  int csh_like;
  bool fish_like;

  // Only csh and similar shells expand '!' within single quotes.  For sh and
  // the like we must not put a backslash before it, it will be taken
  // literally.  If do_special is set the '!' will be escaped twice.
  // Csh also needs to have "\n" escaped twice when do_special is set.
  csh_like = csh_like_shell();

  // Fish shell uses '\' as an escape character within single quotes, so '\'
  // itself must be escaped to get a literal '\'.
  fish_like = fish_like_shell();

  // First count the number of extra bytes required.
  size_t length = strlen(string) + 3;       // two quotes and a trailing NUL
  for (const char *p = string; *p != NUL; MB_PTR_ADV(p)) {
#ifdef MSWIN
    if (!p_ssl) {
      if (*p == '"') {
        length++;                       // " -> ""
      }
    } else
#endif
    if (*p == '\'') {
      length += 3;                      // ' => '\''
    }
    if ((*p == '\n' && (csh_like || do_newline))
        || (*p == '!' && (csh_like || do_special))) {
      length++;                         // insert backslash
      if (csh_like && do_special) {
        length++;                       // insert backslash
      }
    }
    if (do_special && find_cmdline_var(p, &l) >= 0) {
      length++;                         // insert backslash
      p += l - 1;
    }
    if (*p == '\\' && fish_like) {
      length++;  // insert backslash
    }
  }

  // Allocate memory for the result and fill it.
  escaped_string = xmalloc(length);
  d = escaped_string;

  // add opening quote
#ifdef MSWIN
  if (!p_ssl) {
    *d++ = '"';
  } else
#endif
  *d++ = '\'';

  for (const char *p = string; *p != NUL;) {
#ifdef MSWIN
    if (!p_ssl) {
      if (*p == '"') {
        *d++ = '"';
        *d++ = '"';
        p++;
        continue;
      }
    } else
#endif
    if (*p == '\'') {
      *d++ = '\'';
      *d++ = '\\';
      *d++ = '\'';
      *d++ = '\'';
      p++;
      continue;
    }
    if ((*p == '\n' && (csh_like || do_newline))
        || (*p == '!' && (csh_like || do_special))) {
      *d++ = '\\';
      if (csh_like && do_special) {
        *d++ = '\\';
      }
      *d++ = *p++;
      continue;
    }
    if (do_special && find_cmdline_var(p, &l) >= 0) {
      *d++ = '\\';                    // insert backslash
      while (--l != SIZE_MAX) {  // copy the var
        *d++ = *p++;
      }
      continue;
    }
    if (*p == '\\' && fish_like) {
      *d++ = '\\';
      *d++ = *p++;
      continue;
    }

    mb_copy_char(&p, &d);
  }

  // add terminating quote and finish with a NUL
#ifdef MSWIN
  if (!p_ssl) {
    *d++ = '"';
  } else
#endif
  *d++ = '\'';
  *d = NUL;

  return escaped_string;
}

// Like vim_strsave(), but make all characters uppercase.
// This uses ASCII lower-to-upper case translation, language independent.
char *vim_strsave_up(const char *string)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char *p1;

  p1 = xstrdup(string);
  vim_strup(p1);
  return p1;
}

/// Like xstrnsave(), but make all characters uppercase.
/// This uses ASCII lower-to-upper case translation, language independent.
char *vim_strnsave_up(const char *string, size_t len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char *p1 = xstrnsave(string, len);
  vim_strup(p1);
  return p1;
}

// ASCII lower-to-upper case translation, language independent.
void vim_strup(char *p)
  FUNC_ATTR_NONNULL_ALL
{
  uint8_t c;
  while ((c = (uint8_t)(*p)) != NUL) {
    *p++ = (char)(uint8_t)(c < 'a' || c > 'z' ? c : c - 0x20);
  }
}

/// Make given string all upper-case or all lower-case
///
/// Handles multi-byte characters as good as possible.
///
/// @param[in]  orig  Input string.
/// @param[in]  upper If true make uppercase, otherwise lowercase
///
/// @return [allocated] upper-cased string.
char *strcase_save(const char *const orig, bool upper)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char *res = xstrdup(orig);

  char *p = res;
  while (*p != NUL) {
    int c = utf_ptr2char(p);
    int l = utf_ptr2len(p);
    if (c == 0) {
      // overlong sequence, use only the first byte
      c = (uint8_t)(*p);
      l = 1;
    }
    int uc = upper ? mb_toupper(c) : mb_tolower(c);

    // Reallocate string when byte count changes.  This is rare,
    // thus it's OK to do another malloc()/free().
    int newl = utf_char2len(uc);
    if (newl != l) {
      // TODO(philix): use xrealloc() in strcase_save()
      char *s = xmalloc(strlen(res) + (size_t)(1 + newl - l));
      memcpy(s, res, (size_t)(p - res));
      STRCPY(s + (p - res) + newl, p + l);
      p = s + (p - res);
      xfree(res);
      res = s;
    }

    utf_char2bytes(uc, p);
    p += newl;
  }

  return res;
}

// delete spaces at the end of a string
void del_trailing_spaces(char *ptr)
  FUNC_ATTR_NONNULL_ALL
{
  char *q;

  q = ptr + strlen(ptr);
  while (--q > ptr && ascii_iswhite(q[0]) && q[-1] != '\\' && q[-1] != Ctrl_V) {
    *q = NUL;
  }
}

#if !defined(HAVE_STRNLEN)
size_t xstrnlen(const char *s, size_t n)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const char *end = memchr(s, '\0', n);
  if (end == NULL) {
    return n;
  }
  return (size_t)(end - s);
}
#endif

#if (!defined(HAVE_STRCASECMP) && !defined(HAVE_STRICMP))
// Compare two strings, ignoring case, using current locale.
// Doesn't work for multi-byte characters.
// return 0 for match, < 0 for smaller, > 0 for bigger
int vim_stricmp(const char *s1, const char *s2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  int i;

  while (true) {
    i = (int)TOLOWER_LOC((uint8_t)(*s1)) - (int)TOLOWER_LOC((uint8_t)(*s2));
    if (i != 0) {
      return i;                             // this character different
    }
    if (*s1 == NUL) {
      break;                                // strings match until NUL
    }
    s1++;
    s2++;
  }
  return 0;                                 // strings match
}
#endif

#if (!defined(HAVE_STRNCASECMP) && !defined(HAVE_STRNICMP))
// Compare two strings, for length "len", ignoring case, using current locale.
// Doesn't work for multi-byte characters.
// return 0 for match, < 0 for smaller, > 0 for bigger
int vim_strnicmp(const char *s1, const char *s2, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  int i;

  while (len > 0) {
    i = (int)TOLOWER_LOC((uint8_t)(*s1)) - (int)TOLOWER_LOC((uint8_t)(*s2));
    if (i != 0) {
      return i;                             // this character different
    }
    if (*s1 == NUL) {
      break;                                // strings match until NUL
    }
    s1++;
    s2++;
    len--;
  }
  return 0;                                 // strings match
}
#endif

/// strchr() version which handles multibyte strings
///
/// @param[in]  string  String to search in.
/// @param[in]  c  Character to search for.
///
/// @return Pointer to the first byte of the found character in string or NULL
///         if it was not found or character is invalid. NUL character is never
///         found, use `strlen()` instead.
char *vim_strchr(const char *const string, const int c)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (c <= 0) {
    return NULL;
  } else if (c < 0x80) {
    return strchr(string, c);
  } else {
    char u8char[MB_MAXBYTES + 1];
    const int len = utf_char2bytes(c, u8char);
    u8char[len] = NUL;
    return strstr(string, u8char);
  }
}

// Sort an array of strings.

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "strings.c.generated.h"
#endif
static int sort_compare(const void *s1, const void *s2)
  FUNC_ATTR_NONNULL_ALL
{
  return strcmp(*(char **)s1, *(char **)s2);
}

void sort_strings(char **files, int count)
{
  qsort((void *)files, (size_t)count, sizeof(char *), sort_compare);
}

// Return true if string "s" contains a non-ASCII character (128 or higher).
// When "s" is NULL false is returned.
bool has_non_ascii(const char *s)
  FUNC_ATTR_PURE
{
  const char *p;

  if (s != NULL) {
    for (p = s; *p != NUL; p++) {
      if ((uint8_t)(*p) >= 128) {
        return true;
      }
    }
  }
  return false;
}

/// Return true if string "s" contains a non-ASCII character (128 or higher).
/// When "s" is NULL false is returned.
bool has_non_ascii_len(const char *const s, const size_t len)
  FUNC_ATTR_PURE
{
  if (s != NULL) {
    for (size_t i = 0; i < len; i++) {
      if ((uint8_t)s[i] >= 128) {
        return true;
      }
    }
  }
  return false;
}

/// Concatenate two strings and return the result in allocated memory.
char *concat_str(const char *restrict str1, const char *restrict str2)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  size_t l = strlen(str1);
  char *dest = xmalloc(l + strlen(str2) + 1);
  STRCPY(dest, str1);
  STRCPY(dest + l, str2);
  return dest;
}

static const char *const e_printf =
  N_("E766: Insufficient arguments for printf()");

/// Get number argument from idxp entry in tvs
///
/// Will give an error message for Vimscript entry with invalid type or for insufficient entries.
///
/// @param[in]  tvs  List of Vimscript values. List is terminated by VAR_UNKNOWN value.
/// @param[in,out]  idxp  Index in a list. Will be incremented. Indexing starts at 1.
///
/// @return Number value or 0 in case of error.
static varnumber_T tv_nr(typval_T *tvs, int *idxp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int idx = *idxp - 1;
  varnumber_T n = 0;

  if (tvs[idx].v_type == VAR_UNKNOWN) {
    emsg(_(e_printf));
  } else {
    (*idxp)++;
    bool err = false;
    n = tv_get_number_chk(&tvs[idx], &err);
    if (err) {
      n = 0;
    }
  }
  return n;
}

/// Get string argument from idxp entry in tvs
///
/// Will give an error message for Vimscript entry with invalid type or for
/// insufficient entries.
///
/// @param[in]  tvs  List of Vimscript values. List is terminated by VAR_UNKNOWN
///                  value.
/// @param[in,out]  idxp  Index in a list. Will be incremented.
/// @param[out]  tofree  If the idxp entry in tvs is not a String or a Number,
///                      it will be converted to String in the same format
///                      as ":echo" and stored in "*tofree". The caller must
///                      free "*tofree".
///
/// @return String value or NULL in case of error.
static const char *tv_str(typval_T *tvs, int *idxp, char **const tofree)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int idx = *idxp - 1;
  const char *s = NULL;

  if (tvs[idx].v_type == VAR_UNKNOWN) {
    emsg(_(e_printf));
  } else {
    (*idxp)++;
    if (tvs[idx].v_type == VAR_STRING || tvs[idx].v_type == VAR_NUMBER) {
      s = tv_get_string_chk(&tvs[idx]);
      *tofree = NULL;
    } else {
      s = *tofree = encode_tv2echo(&tvs[idx], NULL);
    }
  }
  return s;
}

/// Get pointer argument from the next entry in tvs
///
/// Will give an error message for Vimscript entry with invalid type or for
/// insufficient entries.
///
/// @param[in]  tvs  List of typval_T values.
/// @param[in,out]  idxp  Pointer to the index of the current value.
///
/// @return Pointer stored in typval_T or NULL.
static const void *tv_ptr(const typval_T *const tvs, int *const idxp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
#define OFF(attr) offsetof(union typval_vval_union, attr)
  STATIC_ASSERT(OFF(v_string) == OFF(v_list)  // -V568
                && OFF(v_string) == OFF(v_dict)
                && OFF(v_string) == OFF(v_partial)
                && sizeof(tvs[0].vval.v_string) == sizeof(tvs[0].vval.v_list)
                && sizeof(tvs[0].vval.v_string) == sizeof(tvs[0].vval.v_dict)
                && sizeof(tvs[0].vval.v_string) == sizeof(tvs[0].vval.v_partial),
                "Strings, dictionaries, lists and partials are expected to be pointers, "
                "so that all three of them can be accessed via v_string");
#undef OFF
  const int idx = *idxp - 1;
  if (tvs[idx].v_type == VAR_UNKNOWN) {
    emsg(_(e_printf));
    return NULL;
  }
  (*idxp)++;
  return tvs[idx].vval.v_string;
}

/// Get float argument from idxp entry in tvs
///
/// Will give an error message for Vimscript entry with invalid type or for
/// insufficient entries.
///
/// @param[in]  tvs  List of Vimscript values. List is terminated by VAR_UNKNOWN value.
/// @param[in,out]  idxp  Index in a list. Will be incremented.
///
/// @return Floating-point value or zero in case of error.
static float_T tv_float(typval_T *const tvs, int *const idxp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int idx = *idxp - 1;
  float_T f = 0;

  if (tvs[idx].v_type == VAR_UNKNOWN) {
    emsg(_(e_printf));
  } else {
    (*idxp)++;
    if (tvs[idx].v_type == VAR_FLOAT) {
      f = tvs[idx].vval.v_float;
    } else if (tvs[idx].v_type == VAR_NUMBER) {
      f = (float_T)tvs[idx].vval.v_number;
    } else {
      emsg(_("E807: Expected Float argument for printf()"));
    }
  }
  return f;
}

// This code was included to provide a portable vsnprintf() and snprintf().
// Some systems may provide their own, but we always use this one for
// consistency.
//
// This code is based on snprintf.c - a portable implementation of snprintf
// by Mark Martinec <mark.martinec@ijs.si>, Version 2.2, 2000-10-06.
// Included with permission.  It was heavily modified to fit in Vim.
// The original code, including useful comments, can be found here:
//
//     http://www.ijs.si/software/snprintf/
//
// This snprintf() only supports the following conversion specifiers:
// s, c, b, B, d, u, o, x, X, p  (and synonyms: i, D, U, O - see below)
// with flags: '-', '+', ' ', '0' and '#'.
// An asterisk is supported for field width as well as precision.
//
// Limited support for floating point was added: 'f', 'e', 'E', 'g', 'G'.
//
// Length modifiers 'h' (short int), 'l' (long int) and "ll" (long long int) are
// supported.
//
// The locale is not used, the string is used as a byte string.  This is only
// relevant for double-byte encodings where the second byte may be '%'.
//
// It is permitted for "str_m" to be zero, and it is permitted to specify NULL
// pointer for resulting string argument if "str_m" is zero (as per ISO C99).
//
// The return value is the number of characters which would be generated
// for the given input, excluding the trailing NUL. If this value
// is greater or equal to "str_m", not all characters from the result
// have been stored in str, output bytes beyond the ("str_m"-1) -th character
// are discarded. If "str_m" is greater than zero it is guaranteed
// the resulting string will be NUL-terminated.

// vim_vsnprintf_typval() can be invoked with either "va_list" or a list of
// "typval_T".  When the latter is not used it must be NULL.

/// Append a formatted value to the string
///
/// @see vim_vsnprintf_typval().
int vim_snprintf_add(char *str, size_t str_m, const char *fmt, ...)
  FUNC_ATTR_PRINTF(3, 4)
{
  const size_t len = strlen(str);
  size_t space;

  if (str_m <= len) {
    space = 0;
  } else {
    space = str_m - len;
  }
  va_list ap;
  va_start(ap, fmt);
  const int str_l = vim_vsnprintf(str + len, space, fmt, ap);
  va_end(ap);
  return str_l;
}

/// Write formatted value to the string
///
/// @param[out]  str  String to write to.
/// @param[in]  str_m  String length.
/// @param[in]  fmt  String format.
///
/// @return Number of bytes excluding NUL byte that would be written to the
///         string if str_m was greater or equal to the return value.
int vim_snprintf(char *str, size_t str_m, const char *fmt, ...)
  FUNC_ATTR_PRINTF(3, 4)
{
  va_list ap;
  va_start(ap, fmt);
  const int str_l = vim_vsnprintf(str, str_m, fmt, ap);
  va_end(ap);
  return str_l;
}

// Return the representation of infinity for printf() function:
// "-inf", "inf", "+inf", " inf", "-INF", "INF", "+INF" or " INF".
static const char *infinity_str(bool positive, char fmt_spec, int force_sign,
                                int space_for_positive)
{
  static const char *table[] = {
    "-inf", "inf", "+inf", " inf",
    "-INF", "INF", "+INF", " INF"
  };
  int idx = positive * (1 + force_sign + force_sign * space_for_positive);
  if (ASCII_ISUPPER(fmt_spec)) {
    idx += 4;
  }
  return table[idx];
}

int vim_vsnprintf(char *str, size_t str_m, const char *fmt, va_list ap)
{
  return vim_vsnprintf_typval(str, str_m, fmt, ap, NULL);
}

/// Write formatted value to the string
///
/// @param[out]  str  String to write to.
/// @param[in]  str_m  String length.
/// @param[in]  fmt  String format.
/// @param[in]  ap  Values that should be formatted. Ignored if tvs is not NULL.
/// @param[in]  tvs  Values that should be formatted, for printf() Vimscript
///                  function. Must be NULL in other cases.
///
/// @return Number of bytes excluding NUL byte that would be written to the
///         string if str_m was greater or equal to the return value.
int vim_vsnprintf_typval(char *str, size_t str_m, const char *fmt, va_list ap, typval_T *const tvs)
{
  size_t str_l = 0;
  bool str_avail = str_l < str_m;
  const char *p = fmt;
  int arg_idx = 1;

  if (!p) {
    p = "";
  }
  while (*p) {
    if (*p != '%') {
      // copy up to the next '%' or NUL without any changes
      size_t n = (size_t)(xstrchrnul(p + 1, '%') - p);
      if (str_avail) {
        size_t avail = str_m - str_l;
        memmove(str + str_l, p, MIN(n, avail));
        str_avail = n < avail;
      }
      p += n;
      assert(n <= SIZE_MAX - str_l);
      str_l += n;
    } else {
      size_t min_field_width = 0, precision = 0;
      int zero_padding = 0, precision_specified = 0, justify_left = 0;
      int alternate_form = 0, force_sign = 0;

      // if both ' ' and '+' flags appear, ' ' flag should be ignored
      int space_for_positive = 1;

      // allowed values: \0, h, l, 2 (for ll), z, L
      char length_modifier = '\0';

      // temporary buffer for simple numeric->string conversion
#define TMP_LEN 350    // 1e308 seems reasonable as the maximum printable
      char tmp[TMP_LEN];

      // string address in case of string argument
      const char *str_arg = NULL;

      // natural field width of arg without padding and sign
      size_t str_arg_l;

      // unsigned char argument value (only defined for c conversion);
      // standard explicitly states the char argument for the c
      // conversion is unsigned
      unsigned char uchar_arg;

      // number of zeros to be inserted for numeric conversions as
      // required by the precision or minimal field width
      size_t number_of_zeros_to_pad = 0;

      // index into tmp where zero padding is to be inserted
      size_t zero_padding_insertion_ind = 0;

      // current conversion specifier character
      char fmt_spec = '\0';

      // buffer for 's' and 'S' specs
      char *tofree = NULL;

      p++;  // skip '%'

      // parse flags
      while (true) {
        switch (*p) {
        case '0':
          zero_padding = 1; p++; continue;
        case '-':
          justify_left = 1; p++; continue;
        // if both '0' and '-' flags appear, '0' should be ignored
        case '+':
          force_sign = 1; space_for_positive = 0; p++; continue;
        case ' ':
          force_sign = 1; p++; continue;
        // if both ' ' and '+' flags appear, ' ' should be ignored
        case '#':
          alternate_form = 1; p++; continue;
        case '\'':
          p++; continue;
        default:
          break;
        }
        break;
      }

      // parse field width
      if (*p == '*') {
        p++;
        const int j = tvs ? (int)tv_nr(tvs, &arg_idx) : va_arg(ap, int);
        if (j >= 0) {
          min_field_width = (size_t)j;
        } else {
          min_field_width = (size_t)-j;
          justify_left = 1;
        }
      } else if (ascii_isdigit((int)(*p))) {
        // size_t could be wider than unsigned int; make sure we treat
        // argument like common implementations do
        unsigned uj = (unsigned)(*p++ - '0');

        while (ascii_isdigit((int)(*p))) {
          uj = 10 * uj + (unsigned)(*p++ - '0');
        }
        min_field_width = uj;
      }

      // parse precision
      if (*p == '.') {
        p++;
        precision_specified = 1;
        if (*p == '*') {
          const int j = tvs ? (int)tv_nr(tvs, &arg_idx) : va_arg(ap, int);
          p++;
          if (j >= 0) {
            precision = (size_t)j;
          } else {
            precision_specified = 0;
            precision = 0;
          }
        } else if (ascii_isdigit((int)(*p))) {
          // size_t could be wider than unsigned int; make sure we
          // treat argument like common implementations do
          unsigned uj = (unsigned)(*p++ - '0');

          while (ascii_isdigit((int)(*p))) {
            uj = 10 * uj + (unsigned)(*p++ - '0');
          }
          precision = uj;
        }
      }

      // parse 'h', 'l', 'll' and 'z' length modifiers
      if (*p == 'h' || *p == 'l' || *p == 'z') {
        length_modifier = *p;
        p++;
        if (length_modifier == 'l' && *p == 'l') {  // ll, encoded as 2
          length_modifier = '2';
          p++;
        }
      }

      fmt_spec = *p;

      // common synonyms
      switch (fmt_spec) {
      case 'i':
        fmt_spec = 'd'; break;
      case 'D':
        fmt_spec = 'd'; length_modifier = 'l'; break;
      case 'U':
        fmt_spec = 'u'; length_modifier = 'l'; break;
      case 'O':
        fmt_spec = 'o'; length_modifier = 'l'; break;
      default:
        break;
      }

      switch (fmt_spec) {
      case 'b':
      case 'B':
      case 'd':
      case 'u':
      case 'o':
      case 'x':
      case 'X':
        if (tvs && length_modifier == '\0') {
          length_modifier = '2';
        }
      }

      // get parameter value, do initial processing
      switch (fmt_spec) {
      // '%' and 'c' behave similar to 's' regarding flags and field widths
      case '%':
      case 'c':
      case 's':
      case 'S':
        str_arg_l = 1;
        switch (fmt_spec) {
        case '%':
          str_arg = p;
          break;

        case 'c': {
          const int j = tvs ? (int)tv_nr(tvs, &arg_idx) : va_arg(ap, int);
          // standard demands unsigned char
          uchar_arg = (unsigned char)j;
          str_arg = (char *)&uchar_arg;
          break;
        }

        case 's':
        case 'S':
          str_arg = tvs ? tv_str(tvs, &arg_idx, &tofree)
                        : va_arg(ap, const char *);
          if (!str_arg) {
            str_arg = "[NULL]";
            str_arg_l = 6;
          } else if (!precision_specified) {
            // make sure not to address string beyond the specified
            // precision
            str_arg_l = strlen(str_arg);
          } else if (precision == 0) {
            // truncate string if necessary as requested by precision
            str_arg_l = 0;
          } else {
            // memchr on HP does not like n > 2^31
            // TODO(elmart): check if this still holds / is relevant
            str_arg_l = (size_t)((char *)xmemscan(str_arg,
                                                  NUL,
                                                  MIN(precision,
                                                      0x7fffffff))
                                 - str_arg);
          }
          if (fmt_spec == 'S') {
            const char *p1;
            size_t i;

            for (i = 0, p1 = str_arg; *p1; p1 += utfc_ptr2len(p1)) {
              size_t cell = (size_t)utf_ptr2cells(p1);
              if (precision_specified && i + cell > precision) {
                break;
              }
              i += cell;
            }

            str_arg_l = (size_t)(p1 - str_arg);
            if (min_field_width != 0) {
              min_field_width += str_arg_l - i;
            }
          }
          break;

        default:
          break;
        }
        break;

      case 'd':
      case 'u':
      case 'b':
      case 'B':
      case 'o':
      case 'x':
      case 'X':
      case 'p': {
        // u, b, B, o, x, X and p conversion specifiers imply
        // the value is unsigned; d implies a signed value

        // 0 if numeric argument is zero (or if pointer is NULL for 'p'),
        // +1 if greater than zero (or non NULL for 'p'),
        // -1 if negative (unsigned argument is never negative)
        int arg_sign = 0;

        intmax_t arg = 0;
        uintmax_t uarg = 0;

        // only defined for p conversion
        const void *ptr_arg = NULL;

        if (fmt_spec == 'p') {
          ptr_arg = tvs ? tv_ptr(tvs, &arg_idx) : va_arg(ap, void *);
          if (ptr_arg) {
            arg_sign = 1;
          }
        } else if (fmt_spec == 'd') {
          // signed
          switch (length_modifier) {
          case '\0':
            arg = (int)(tvs ? tv_nr(tvs, &arg_idx) : va_arg(ap, int));
            break;
          case 'h':
            // char and short arguments are passed as int16_t
            arg = (int16_t)(tvs ? tv_nr(tvs, &arg_idx) : va_arg(ap, int));
            break;
          case 'l':
            arg = (tvs ? (long)tv_nr(tvs, &arg_idx) : va_arg(ap, long));
            break;
          case '2':
            arg = (
                   tvs
                    ? (long long)tv_nr(tvs, &arg_idx)  // NOLINT (runtime/int)
                    : va_arg(ap, long long));  // NOLINT (runtime/int)
            break;
          case 'z':
            arg = (tvs ? (ptrdiff_t)tv_nr(tvs, &arg_idx) : va_arg(ap, ptrdiff_t));
            break;
          }
          if (arg > 0) {
            arg_sign = 1;
          } else if (arg < 0) {
            arg_sign = -1;
          }
        } else {
          // unsigned
          switch (length_modifier) {
          case '\0':
            uarg = (unsigned)(tvs ? tv_nr(tvs, &arg_idx) : va_arg(ap, unsigned));
            break;
          case 'h':
            uarg = (uint16_t)(tvs ? tv_nr(tvs, &arg_idx) : va_arg(ap, unsigned));
            break;
          case 'l':
            uarg = (tvs ? (unsigned long)tv_nr(tvs, &arg_idx) : va_arg(ap, unsigned long));
            break;
          case '2':
            uarg = (uintmax_t)(unsigned long long)(  // NOLINT (runtime/int)
                                                     tvs
                    ? ((unsigned long long)  // NOLINT (runtime/int)
                       tv_nr(tvs, &arg_idx))
                    : va_arg(ap, unsigned long long));  // NOLINT (runtime/int)
            break;
          case 'z':
            uarg = (tvs ? (size_t)tv_nr(tvs, &arg_idx) : va_arg(ap, size_t));
            break;
          }
          arg_sign = (uarg != 0);
        }

        str_arg = tmp;
        str_arg_l = 0;

        // For d, i, u, o, x, and X conversions, if precision is specified,
        // '0' flag should be ignored. This is so with Solaris 2.6, Digital
        // UNIX 4.0, HPUX 10, Linux, FreeBSD, NetBSD; but not with Perl.
        if (precision_specified) {
          zero_padding = 0;
        }

        if (fmt_spec == 'd') {
          if (force_sign && arg_sign >= 0) {
            tmp[str_arg_l++] = space_for_positive ? ' ' : '+';
          }
          // leave negative numbers for snprintf to handle, to
          // avoid handling tricky cases like (short int)-32768
        } else if (alternate_form) {
          if (arg_sign != 0 && (fmt_spec == 'x' || fmt_spec == 'X'
                                || fmt_spec == 'b' || fmt_spec == 'B')) {
            tmp[str_arg_l++] = '0';
            tmp[str_arg_l++] = fmt_spec;
          }
          // alternate form should have no effect for p * conversion, but ...
        }

        zero_padding_insertion_ind = str_arg_l;
        if (!precision_specified) {
          precision = 1;  // default precision is 1
        }
        if (precision == 0 && arg_sign == 0) {
          // when zero value is formatted with an explicit precision 0,
          // resulting formatted string is empty (d, i, u, b, B, o, x, X, p)
        } else {
          switch (fmt_spec) {
          case 'p':    // pointer
            str_arg_l += (size_t)snprintf(tmp + str_arg_l,
                                          sizeof(tmp) - str_arg_l,
                                          "%p", ptr_arg);
            break;
          case 'd':    // signed
            str_arg_l += (size_t)snprintf(tmp + str_arg_l,
                                          sizeof(tmp) - str_arg_l,
                                          "%" PRIdMAX, arg);
            break;
          case 'b':
          case 'B': {  // binary
            size_t bits = 0;
            for (bits = sizeof(uintmax_t) * 8; bits > 0; bits--) {
              if ((uarg >> (bits - 1)) & 0x1) {
                break;
              }
            }

            while (bits > 0) {
              tmp[str_arg_l++] = ((uarg >> --bits) & 0x1) ? '1' : '0';
            }
            break;
          }
          default: {  // unsigned
            // construct a simple format string for snprintf
            char f[] = "%" PRIuMAX;
            f[sizeof("%" PRIuMAX) - 1 - 1] = fmt_spec;
            assert(PRIuMAX[sizeof(PRIuMAX) - 1 - 1] == 'u');
            str_arg_l += (size_t)snprintf(tmp + str_arg_l,
                                          sizeof(tmp) - str_arg_l,
                                          f, uarg);
            break;
          }
          }
          assert(str_arg_l < sizeof(tmp));

          // include the optional minus sign and possible "0x" in the region
          // before the zero padding insertion point
          if (zero_padding_insertion_ind < str_arg_l
              && tmp[zero_padding_insertion_ind] == '-') {
            zero_padding_insertion_ind++;
          }
          if (zero_padding_insertion_ind + 1 < str_arg_l
              && tmp[zero_padding_insertion_ind] == '0'
              && (tmp[zero_padding_insertion_ind + 1] == 'x'
                  || tmp[zero_padding_insertion_ind + 1] == 'X'
                  || tmp[zero_padding_insertion_ind + 1] == 'b'
                  || tmp[zero_padding_insertion_ind + 1] == 'B')) {
            zero_padding_insertion_ind += 2;
          }
        }

        {
          size_t num_of_digits = str_arg_l - zero_padding_insertion_ind;

          if (alternate_form && fmt_spec == 'o'
              // unless zero is already the first character
              && !(zero_padding_insertion_ind < str_arg_l
                   && tmp[zero_padding_insertion_ind] == '0')) {
            // assure leading zero for alternate-form octal numbers
            if (!precision_specified
                || precision < num_of_digits + 1) {
              // precision is increased to force the first character to be
              // zero, except if a zero value is formatted with an explicit
              // precision of zero
              precision = num_of_digits + 1;
            }
          }
          // zero padding to specified precision?
          if (num_of_digits < precision) {
            number_of_zeros_to_pad = precision - num_of_digits;
          }
        }
        // zero padding to specified minimal field width?
        if (!justify_left && zero_padding) {
          const int n = (int)(min_field_width - (str_arg_l
                                                 + number_of_zeros_to_pad));
          if (n > 0) {
            number_of_zeros_to_pad += (size_t)n;
          }
        }
        break;
      }

      case 'f':
      case 'F':
      case 'e':
      case 'E':
      case 'g':
      case 'G': {
        // floating point
        char format[40];
        int remove_trailing_zeroes = false;

        double f = tvs ? tv_float(tvs, &arg_idx) : va_arg(ap, double);
        double abs_f = f < 0 ? -f : f;

        if (fmt_spec == 'g' || fmt_spec == 'G') {
          // can't use %g directly, cause it prints "1.0" as "1"
          if ((abs_f >= 0.001 && abs_f < 10000000.0) || abs_f == 0.0) {
            fmt_spec = ASCII_ISUPPER(fmt_spec) ? 'F' : 'f';
          } else {
            fmt_spec = fmt_spec == 'g' ? 'e' : 'E';
          }
          remove_trailing_zeroes = true;
        }

        if (xisinf(f)
            || (strchr("fF", fmt_spec) != NULL && abs_f > 1.0e307)) {
          xstrlcpy(tmp, infinity_str(f > 0.0, fmt_spec,
                                     force_sign, space_for_positive),
                   sizeof(tmp));
          str_arg_l = strlen(tmp);
          zero_padding = 0;
        } else if (xisnan(f)) {
          // Not a number: nan or NAN
          memmove(tmp, ASCII_ISUPPER(fmt_spec) ? "NAN" : "nan", 4);
          str_arg_l = 3;
          zero_padding = 0;
        } else {
          // Regular float number
          format[0] = '%';
          size_t l = 1;
          if (force_sign) {
            format[l++] = space_for_positive ? ' ' : '+';
          }
          if (precision_specified) {
            size_t max_prec = TMP_LEN - 10;

            // make sure we don't get more digits than we have room for
            if ((fmt_spec == 'f' || fmt_spec == 'F') && abs_f > 1.0) {
              max_prec -= (size_t)log10(abs_f);
            }
            if (precision > max_prec) {
              precision = max_prec;
            }
            l += (size_t)snprintf(format + l, sizeof(format) - l, ".%d",
                                  (int)precision);
          }

          // Cast to char to avoid a conversion warning on Ubuntu 12.04.
          assert(l + 1 < sizeof(format));
          format[l] = (char)(fmt_spec == 'F' ? 'f' : fmt_spec);
          format[l + 1] = NUL;

          str_arg_l = (size_t)snprintf(tmp, sizeof(tmp), format, f);
          assert(str_arg_l < sizeof(tmp));

          if (remove_trailing_zeroes) {
            int i;
            char *tp;

            // using %g or %G: remove superfluous zeroes
            if (fmt_spec == 'f' || fmt_spec == 'F') {
              tp = tmp + str_arg_l - 1;
            } else {
              tp = vim_strchr(tmp, fmt_spec == 'e' ? 'e' : 'E');
              if (tp) {
                // remove superfluous '+' and leading zeroes from exponent
                if (tp[1] == '+') {
                  // change "1.0e+07" to "1.0e07"
                  STRMOVE(tp + 1, tp + 2);
                  str_arg_l--;
                }
                i = (tp[1] == '-') ? 2 : 1;
                while (tp[i] == '0') {
                  // change "1.0e07" to "1.0e7"
                  STRMOVE(tp + i, tp + i + 1);
                  str_arg_l--;
                }
                tp--;
              }
            }

            if (tp != NULL && !precision_specified) {
              // remove trailing zeroes, but keep the one just after a dot
              while (tp > tmp + 2 && *tp == '0' && tp[-1] != '.') {
                STRMOVE(tp, tp + 1);
                tp--;
                str_arg_l--;
              }
            }
          } else {
            // Be consistent: some printf("%e") use 1.0e+12 and some
            // 1.0e+012; remove one zero in the last case.
            char *tp = vim_strchr(tmp, fmt_spec == 'e' ? 'e' : 'E');
            if (tp && (tp[1] == '+' || tp[1] == '-') && tp[2] == '0'
                && ascii_isdigit(tp[3]) && ascii_isdigit(tp[4])) {
              STRMOVE(tp + 2, tp + 3);
              str_arg_l--;
            }
          }
        }
        if (zero_padding && min_field_width > str_arg_l
            && (tmp[0] == '-' || force_sign)) {
          // Padding 0's should be inserted after the sign.
          number_of_zeros_to_pad = min_field_width - str_arg_l;
          zero_padding_insertion_ind = 1;
        }
        str_arg = tmp;
        break;
      }

      default:
        // unrecognized conversion specifier, keep format string as-is
        zero_padding = 0;  // turn zero padding off for non-numeric conversion
        justify_left = 1;
        min_field_width = 0;  // reset flags

        // discard the unrecognized conversion, just keep
        // the unrecognized conversion character
        str_arg = p;
        str_arg_l = 0;
        if (*p) {
          str_arg_l++;  // include invalid conversion specifier
        }
        // unchanged if not at end-of-string
        break;
      }

      if (*p) {
        p++;  // step over the just processed conversion specifier
      }

      // insert padding to the left as requested by min_field_width;
      // this does not include the zero padding in case of numerical conversions
      if (!justify_left) {
        assert(str_arg_l <= SIZE_MAX - number_of_zeros_to_pad);
        if (min_field_width > str_arg_l + number_of_zeros_to_pad) {
          // left padding with blank or zero
          size_t pn = min_field_width - (str_arg_l + number_of_zeros_to_pad);
          if (str_avail) {
            size_t avail = str_m - str_l;
            memset(str + str_l, zero_padding ? '0' : ' ', MIN(pn, avail));
            str_avail = pn < avail;
          }
          assert(pn <= SIZE_MAX - str_l);
          str_l += pn;
        }
      }

      // zero padding as requested by the precision or by the minimal
      // field width for numeric conversions required?
      if (number_of_zeros_to_pad == 0) {
        // will not copy first part of numeric right now,
        // force it to be copied later in its entirety
        zero_padding_insertion_ind = 0;
      } else {
        // insert first part of numerics (sign or '0x') before zero padding
        if (zero_padding_insertion_ind > 0) {
          size_t zn = zero_padding_insertion_ind;
          if (str_avail) {
            size_t avail = str_m - str_l;
            memmove(str + str_l, str_arg, MIN(zn, avail));
            str_avail = zn < avail;
          }
          assert(zn <= SIZE_MAX - str_l);
          str_l += zn;
        }

        // insert zero padding as requested by precision or min field width
        size_t zn = number_of_zeros_to_pad;
        if (str_avail) {
          size_t avail = str_m - str_l;
          memset(str + str_l, '0', MIN(zn, avail));
          str_avail = zn < avail;
        }
        assert(zn <= SIZE_MAX - str_l);
        str_l += zn;
      }

      // insert formatted string
      // (or as-is conversion specifier for unknown conversions)
      if (str_arg_l > zero_padding_insertion_ind) {
        size_t sn = str_arg_l - zero_padding_insertion_ind;
        if (str_avail) {
          size_t avail = str_m - str_l;
          memmove(str + str_l,
                  str_arg + zero_padding_insertion_ind,
                  MIN(sn, avail));
          str_avail = sn < avail;
        }
        assert(sn <= SIZE_MAX - str_l);
        str_l += sn;
      }

      // insert right padding
      if (justify_left) {
        assert(str_arg_l <= SIZE_MAX - number_of_zeros_to_pad);
        if (min_field_width > str_arg_l + number_of_zeros_to_pad) {
          // right blank padding to the field width
          size_t pn = min_field_width - (str_arg_l + number_of_zeros_to_pad);
          if (str_avail) {
            size_t avail = str_m - str_l;
            memset(str + str_l, ' ', MIN(pn, avail));
            str_avail = pn < avail;
          }
          assert(pn <= SIZE_MAX - str_l);
          str_l += pn;
        }
      }

      xfree(tofree);
    }
  }

  if (str_m > 0) {
    // make sure the string is nul-terminated even at the expense of
    // overwriting the last character (shouldn't happen, but just in case)
    str[str_l <= str_m - 1 ? str_l : str_m - 1] = '\0';
  }

  if (tvs && tvs[arg_idx - 1].v_type != VAR_UNKNOWN) {
    emsg(_("E767: Too many arguments to printf()"));
  }

  // return the number of characters formatted (excluding trailing nul
  // character); that is, the number of characters that would have been
  // written to the buffer if it were large enough.
  return (int)str_l;
}

int kv_do_printf(StringBuilder *str, const char *fmt, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  size_t remaining = str->capacity - str->size;

  va_list ap;
  va_start(ap, fmt);
  int printed = vsnprintf(str->items ? str->items + str->size : NULL, remaining, fmt, ap);
  va_end(ap);

  if (printed < 0) {
    return -1;
  }

  // printed string didn't fit, resize and try again
  if ((size_t)printed >= remaining) {
    kv_ensure_space(*str, (size_t)printed + 1);  // include space for NUL terminator at the end
    assert(str->items != NULL);
    va_start(ap, fmt);
    printed = vsnprintf(str->items + str->size, str->capacity - str->size, fmt, ap);
    va_end(ap);
    if (printed < 0) {
      return -1;
    }
  }

  str->size += (size_t)printed;
  return printed;
}

/// Reverse text into allocated memory.
///
/// @return  the allocated string.
char *reverse_text(char *s)
  FUNC_ATTR_NONNULL_RET
{
  // Reverse the pattern.
  size_t len = strlen(s);
  char *rev = xmalloc(len + 1);
  size_t rev_i = len;
  for (size_t s_i = 0; s_i < len; s_i++) {
    const int mb_len = utfc_ptr2len(s + s_i);
    rev_i -= (size_t)mb_len;
    memmove(rev + rev_i, s + s_i, (size_t)mb_len);
    s_i += (size_t)mb_len - 1;
  }
  rev[len] = NUL;

  return rev;
}

/// Replace all occurrences of "what" with "rep" in "src". If no replacement happens then NULL is
/// returned otherwise return a newly allocated string.
///
/// @param[in] src  Source text
/// @param[in] what Substring to replace
/// @param[in] rep  Substring to replace with
///
/// @return [allocated] Copy of the string.
char *strrep(const char *src, const char *what, const char *rep)
{
  const char *pos = src;
  size_t whatlen = strlen(what);

  // Count occurrences
  size_t count = 0;
  while ((pos = strstr(pos, what)) != NULL) {
    count++;
    pos += whatlen;
  }

  if (count == 0) {
    return NULL;
  }

  size_t replen = strlen(rep);
  char *ret = xmalloc(strlen(src) + count * (replen - whatlen) + 1);
  char *ptr = ret;
  while ((pos = strstr(src, what)) != NULL) {
    size_t idx = (size_t)(pos - src);
    memcpy(ptr, src, idx);
    ptr += idx;
    STRCPY(ptr, rep);
    ptr += replen;
    src = pos + whatlen;
  }

  // Copy remaining
  STRCPY(ptr, src);

  return ret;
}

/// Implementation of "byteidx()" and "byteidxcomp()" functions
static void byteidx_common(typval_T *argvars, typval_T *rettv, int comp)
{
  rettv->vval.v_number = -1;

  const char *const str = tv_get_string_chk(&argvars[0]);
  varnumber_T idx = tv_get_number_chk(&argvars[1], NULL);
  if (str == NULL || idx < 0) {
    return;
  }

  varnumber_T utf16idx = false;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    bool error = false;
    utf16idx = tv_get_bool_chk(&argvars[2], &error);
    if (error) {
      return;
    }
    if (utf16idx < 0 || utf16idx > 1) {
      semsg(_(e_using_number_as_bool_nr), utf16idx);
      return;
    }
  }

  int (*ptr2len)(const char *);
  if (comp) {
    ptr2len = utf_ptr2len;
  } else {
    ptr2len = utfc_ptr2len;
  }

  const char *t = str;
  for (; idx > 0; idx--) {
    if (*t == NUL) {  // EOL reached.
      return;
    }
    if (utf16idx) {
      const int clen = ptr2len(t);
      const int c = (clen > 1) ? utf_ptr2char(t) : *t;
      if (c > 0xFFFF) {
        idx--;
      }
    }
    if (idx > 0) {
      t += ptr2len(t);
    }
  }
  rettv->vval.v_number = (varnumber_T)(t - str);
}

/// "byteidx()" function
void f_byteidx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  byteidx_common(argvars, rettv, false);
}

/// "byteidxcomp()" function
void f_byteidxcomp(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  byteidx_common(argvars, rettv, true);
}

/// "charidx()" function
void f_charidx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_number_arg(argvars, 1) == FAIL
      || tv_check_for_opt_bool_arg(argvars, 2) == FAIL
      || (argvars[2].v_type != VAR_UNKNOWN
          && tv_check_for_opt_bool_arg(argvars, 3) == FAIL)) {
    return;
  }

  const char *const str = tv_get_string_chk(&argvars[0]);
  varnumber_T idx = tv_get_number_chk(&argvars[1], NULL);
  if (str == NULL || idx < 0) {
    return;
  }

  varnumber_T countcc = false;
  varnumber_T utf16idx = false;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    countcc = tv_get_bool(&argvars[2]);
    if (argvars[3].v_type != VAR_UNKNOWN) {
      utf16idx = tv_get_bool(&argvars[3]);
    }
  }

  int (*ptr2len)(const char *);
  if (countcc) {
    ptr2len = utf_ptr2len;
  } else {
    ptr2len = utfc_ptr2len;
  }

  const char *p;
  int len;
  for (p = str, len = 0; utf16idx ? idx >= 0 : p <= str + idx; len++) {
    if (*p == NUL) {
      // If the index is exactly the number of bytes or utf-16 code units
      // in the string then return the length of the string in characters.
      if (utf16idx ? (idx == 0) : (p == (str + idx))) {
        rettv->vval.v_number = len;
      }
      return;
    }
    if (utf16idx) {
      idx--;
      const int clen = ptr2len(p);
      const int c = (clen > 1) ? utf_ptr2char(p) : *p;
      if (c > 0xFFFF) {
        idx--;
      }
    }
    p += ptr2len(p);
  }

  rettv->vval.v_number = len > 0 ? len - 1 : 0;
}

/// "str2list()" function
void f_str2list(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, kListLenUnknown);
  const char *p = tv_get_string(&argvars[0]);

  for (; *p != NUL; p += utf_ptr2len(p)) {
    tv_list_append_number(rettv->vval.v_list, utf_ptr2char(p));
  }
}

/// "str2nr()" function
void f_str2nr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int base = 10;
  int what = 0;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    base = (int)tv_get_number(&argvars[1]);
    if (base != 2 && base != 8 && base != 10 && base != 16) {
      emsg(_(e_invarg));
      return;
    }
    if (argvars[2].v_type != VAR_UNKNOWN && tv_get_bool(&argvars[2])) {
      what |= STR2NR_QUOTE;
    }
  }

  char *p = skipwhite(tv_get_string(&argvars[0]));
  bool isneg = (*p == '-');
  if (*p == '+' || *p == '-') {
    p = skipwhite(p + 1);
  }
  switch (base) {
  case 2:
    what |= STR2NR_BIN | STR2NR_FORCE;
    break;
  case 8:
    what |= STR2NR_OCT | STR2NR_OOCT | STR2NR_FORCE;
    break;
  case 16:
    what |= STR2NR_HEX | STR2NR_FORCE;
    break;
  }
  varnumber_T n;
  vim_str2nr(p, NULL, NULL, what, &n, NULL, 0, false, NULL);
  // Text after the number is silently ignored.
  if (isneg) {
    rettv->vval.v_number = -n;
  } else {
    rettv->vval.v_number = n;
  }
}

/// "strgetchar()" function
void f_strgetchar(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  const char *const str = tv_get_string_chk(&argvars[0]);
  if (str == NULL) {
    return;
  }
  bool error = false;
  varnumber_T charidx = tv_get_number_chk(&argvars[1], &error);
  if (error) {
    return;
  }

  const size_t len = strlen(str);
  size_t byteidx = 0;

  while (charidx >= 0 && byteidx < len) {
    if (charidx == 0) {
      rettv->vval.v_number = utf_ptr2char(str + byteidx);
      break;
    }
    charidx--;
    byteidx += (size_t)utf_ptr2len(str + byteidx);
  }
}

/// "stridx()" function
void f_stridx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  char buf[NUMBUFLEN];
  const char *const needle = tv_get_string_chk(&argvars[1]);
  const char *haystack = tv_get_string_buf_chk(&argvars[0], buf);
  const char *const haystack_start = haystack;
  if (needle == NULL || haystack == NULL) {
    return;  // Type error; errmsg already given.
  }

  if (argvars[2].v_type != VAR_UNKNOWN) {
    bool error = false;

    const ptrdiff_t start_idx = (ptrdiff_t)tv_get_number_chk(&argvars[2],
                                                             &error);
    if (error || start_idx >= (ptrdiff_t)strlen(haystack)) {
      return;
    }
    if (start_idx >= 0) {
      haystack += start_idx;
    }
  }

  const char *pos = strstr(haystack, needle);
  if (pos != NULL) {
    rettv->vval.v_number = (varnumber_T)(pos - haystack_start);
  }
}

/// "string()" function
void f_string(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = encode_tv2string(&argvars[0], NULL);
}

/// "strlen()" function
void f_strlen(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = (varnumber_T)strlen(tv_get_string(&argvars[0]));
}

static void strchar_common(typval_T *argvars, typval_T *rettv, bool skipcc)
{
  const char *s = tv_get_string(&argvars[0]);
  varnumber_T len = 0;
  int (*func_mb_ptr2char_adv)(const char **pp);

  func_mb_ptr2char_adv = skipcc ? mb_ptr2char_adv : mb_cptr2char_adv;
  while (*s != NUL) {
    func_mb_ptr2char_adv(&s);
    len++;
  }
  rettv->vval.v_number = len;
}

/// "strcharlen()" function
void f_strcharlen(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  strchar_common(argvars, rettv, true);
}

/// "strchars()" function
void f_strchars(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  varnumber_T skipcc = false;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    bool error = false;
    skipcc = tv_get_bool_chk(&argvars[1], &error);
    if (error) {
      return;
    }
    if (skipcc < 0 || skipcc > 1) {
      semsg(_(e_using_number_as_bool_nr), skipcc);
      return;
    }
  }

  strchar_common(argvars, rettv, skipcc);
}

/// "strutf16len()" function
void f_strutf16len(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_opt_bool_arg(argvars, 1) == FAIL) {
    return;
  }

  varnumber_T countcc = false;
  if (argvars[1].v_type != VAR_UNKNOWN) {
    countcc = tv_get_bool(&argvars[1]);
  }

  const char *s = tv_get_string(&argvars[0]);
  varnumber_T len = 0;
  int (*func_mb_ptr2char_adv)(const char **pp);

  func_mb_ptr2char_adv = countcc ? mb_cptr2char_adv : mb_ptr2char_adv;
  while (*s != NUL) {
    const int ch = func_mb_ptr2char_adv(&s);
    if (ch > 0xFFFF) {
      len++;
    }
    len++;
  }
  rettv->vval.v_number = len;
}

/// "strdisplaywidth()" function
void f_strdisplaywidth(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const s = tv_get_string(&argvars[0]);
  int col = 0;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    col = (int)tv_get_number(&argvars[1]);
  }

  rettv->vval.v_number = (varnumber_T)(linetabsize_col(col, (char *)s) - col);
}

/// "strwidth()" function
void f_strwidth(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const s = tv_get_string(&argvars[0]);

  rettv->vval.v_number = (varnumber_T)mb_string2cells(s);
}

/// "strcharpart()" function
void f_strcharpart(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *const p = tv_get_string(&argvars[0]);
  const size_t slen = strlen(p);

  int nbyte = 0;
  varnumber_T skipcc = false;
  bool error = false;
  varnumber_T nchar = tv_get_number_chk(&argvars[1], &error);
  if (!error) {
    if (argvars[2].v_type != VAR_UNKNOWN
        && argvars[3].v_type != VAR_UNKNOWN) {
      skipcc = tv_get_bool_chk(&argvars[3], &error);
      if (error) {
        return;
      }
      if (skipcc < 0 || skipcc > 1) {
        semsg(_(e_using_number_as_bool_nr), skipcc);
        return;
      }
    }

    if (nchar > 0) {
      while (nchar > 0 && (size_t)nbyte < slen) {
        if (skipcc) {
          nbyte += utfc_ptr2len(p + nbyte);
        } else {
          nbyte += utf_ptr2len(p + nbyte);
        }
        nchar--;
      }
    } else {
      nbyte = (int)nchar;
    }
  }
  int len = 0;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    int charlen = (int)tv_get_number(&argvars[2]);
    while (charlen > 0 && nbyte + len < (int)slen) {
      int off = nbyte + len;

      if (off < 0) {
        len += 1;
      } else {
        if (skipcc) {
          len += utfc_ptr2len(p + off);
        } else {
          len += utf_ptr2len(p + off);
        }
      }
      charlen--;
    }
  } else {
    len = (int)slen - nbyte;    // default: all bytes that are available.
  }

  // Only return the overlap between the specified part and the actual
  // string.
  if (nbyte < 0) {
    len += nbyte;
    nbyte = 0;
  } else if ((size_t)nbyte > slen) {
    nbyte = (int)slen;
  }
  if (len < 0) {
    len = 0;
  } else if (nbyte + len > (int)slen) {
    len = (int)slen - nbyte;
  }

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = xstrndup(p + nbyte, (size_t)len);
}

/// "strpart()" function
void f_strpart(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  bool error = false;

  const char *const p = tv_get_string(&argvars[0]);
  const size_t slen = strlen(p);

  varnumber_T n = tv_get_number_chk(&argvars[1], &error);
  varnumber_T len;
  if (error) {
    len = 0;
  } else if (argvars[2].v_type != VAR_UNKNOWN) {
    len = tv_get_number(&argvars[2]);
  } else {
    len = (varnumber_T)slen - n;  // Default len: all bytes that are available.
  }

  // Only return the overlap between the specified part and the actual
  // string.
  if (n < 0) {
    len += n;
    n = 0;
  } else if (n > (varnumber_T)slen) {
    n = (varnumber_T)slen;
  }
  if (len < 0) {
    len = 0;
  } else if (n + len > (varnumber_T)slen) {
    len = (varnumber_T)slen - n;
  }

  if (argvars[2].v_type != VAR_UNKNOWN && argvars[3].v_type != VAR_UNKNOWN) {
    int off;

    // length in characters
    for (off = (int)n; off < (int)slen && len > 0; len--) {
      off += utfc_ptr2len(p + off);
    }
    len = off - n;
  }

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = xmemdupz(p + n, (size_t)len);
}

/// "strridx()" function
void f_strridx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf[NUMBUFLEN];
  const char *const needle = tv_get_string_chk(&argvars[1]);
  const char *const haystack = tv_get_string_buf_chk(&argvars[0], buf);

  rettv->vval.v_number = -1;
  if (needle == NULL || haystack == NULL) {
    return;  // Type error; errmsg already given.
  }

  const size_t haystack_len = strlen(haystack);
  ptrdiff_t end_idx;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    // Third argument: upper limit for index.
    end_idx = (ptrdiff_t)tv_get_number_chk(&argvars[2], NULL);
    if (end_idx < 0) {
      return;  // Can never find a match.
    }
  } else {
    end_idx = (ptrdiff_t)haystack_len;
  }

  const char *lastmatch = NULL;
  if (*needle == NUL) {
    // Empty string matches past the end.
    lastmatch = haystack + end_idx;
  } else {
    for (const char *rest = haystack; *rest != NUL; rest++) {
      rest = strstr(rest, needle);
      if (rest == NULL || rest > haystack + end_idx) {
        break;
      }
      lastmatch = rest;
    }
  }

  if (lastmatch != NULL) {
    rettv->vval.v_number = (varnumber_T)(lastmatch - haystack);
  }
}

/// "strtrans()" function
void f_strtrans(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = transstr(tv_get_string(&argvars[0]), true);
}

/// "utf16idx()" function
///
/// Converts a byte or character offset in a string to the corresponding UTF-16
/// code unit offset.
void f_utf16idx(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  if (tv_check_for_string_arg(argvars, 0) == FAIL
      || tv_check_for_opt_number_arg(argvars, 1) == FAIL
      || tv_check_for_opt_bool_arg(argvars, 2) == FAIL
      || (argvars[2].v_type != VAR_UNKNOWN
          && tv_check_for_opt_bool_arg(argvars, 3) == FAIL)) {
    return;
  }

  const char *const str = tv_get_string_chk(&argvars[0]);
  varnumber_T idx = tv_get_number_chk(&argvars[1], NULL);
  if (str == NULL || idx < 0) {
    return;
  }

  varnumber_T countcc = false;
  varnumber_T charidx = false;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    countcc = tv_get_bool(&argvars[2]);
    if (argvars[3].v_type != VAR_UNKNOWN) {
      charidx = tv_get_bool(&argvars[3]);
    }
  }

  int (*ptr2len)(const char *);
  if (countcc) {
    ptr2len = utf_ptr2len;
  } else {
    ptr2len = utfc_ptr2len;
  }

  const char *p;
  int len;
  int utf16idx = 0;
  for (p = str, len = 0; charidx ? idx >= 0 : p <= str + idx; len++) {
    if (*p == NUL) {
      // If the index is exactly the number of bytes or characters in the
      // string then return the length of the string in utf-16 code units.
      if (charidx ? (idx == 0) : (p == (str + idx))) {
        rettv->vval.v_number = len;
      }
      return;
    }
    utf16idx = len;
    const int clen = ptr2len(p);
    const int c = (clen > 1) ? utf_ptr2char(p) : *p;
    if (c > 0xFFFF) {
      len++;
    }
    p += ptr2len(p);
    if (charidx) {
      idx--;
    }
  }

  rettv->vval.v_number = utf16idx;
}

/// "tolower(string)" function
void f_tolower(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = strcase_save(tv_get_string(&argvars[0]), false);
}

/// "toupper(string)" function
void f_toupper(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = strcase_save(tv_get_string(&argvars[0]), true);
}

/// "tr(string, fromstr, tostr)" function
void f_tr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf[NUMBUFLEN];
  char buf2[NUMBUFLEN];

  const char *in_str = tv_get_string(&argvars[0]);
  const char *fromstr = tv_get_string_buf_chk(&argvars[1], buf);
  const char *tostr = tv_get_string_buf_chk(&argvars[2], buf2);

  // Default return value: empty string.
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (fromstr == NULL || tostr == NULL) {
    return;  // Type error; errmsg already given.
  }
  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);

  // fromstr and tostr have to contain the same number of chars.
  bool first = true;
  while (*in_str != NUL) {
    const char *cpstr = in_str;
    const int inlen = utfc_ptr2len(in_str);
    int cplen = inlen;
    int idx = 0;
    int fromlen;
    for (const char *p = fromstr; *p != NUL; p += fromlen) {
      fromlen = utfc_ptr2len(p);
      if (fromlen == inlen && strncmp(in_str, p, (size_t)inlen) == 0) {
        int tolen;
        for (p = tostr; *p != NUL; p += tolen) {
          tolen = utfc_ptr2len(p);
          if (idx-- == 0) {
            cplen = tolen;
            cpstr = p;
            break;
          }
        }
        if (*p == NUL) {  // tostr is shorter than fromstr.
          goto error;
        }
        break;
      }
      idx++;
    }

    if (first && cpstr == in_str) {
      // Check that fromstr and tostr have the same number of
      // (multi-byte) characters.  Done only once when a character
      // of in_str doesn't appear in fromstr.
      first = false;
      int tolen;
      for (const char *p = tostr; *p != NUL; p += tolen) {
        tolen = utfc_ptr2len(p);
        idx--;
      }
      if (idx != 0) {
        goto error;
      }
    }

    ga_grow(&ga, cplen);
    memmove((char *)ga.ga_data + ga.ga_len, cpstr, (size_t)cplen);
    ga.ga_len += cplen;

    in_str += inlen;
  }

  // add a terminating NUL
  ga_append(&ga, NUL);

  rettv->vval.v_string = ga.ga_data;
  return;
error:
  semsg(_(e_invarg2), fromstr);
  ga_clear(&ga);
}

/// "trim({expr})" function
void f_trim(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf1[NUMBUFLEN];
  char buf2[NUMBUFLEN];
  const char *head = tv_get_string_buf_chk(&argvars[0], buf1);
  const char *mask = NULL;
  const char *prev;
  const char *p;
  int dir = 0;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (head == NULL) {
    return;
  }

  if (tv_check_for_opt_string_arg(argvars, 1) == FAIL) {
    return;
  }

  if (argvars[1].v_type == VAR_STRING) {
    mask = tv_get_string_buf_chk(&argvars[1], buf2);
    if (argvars[2].v_type != VAR_UNKNOWN) {
      bool error = false;
      // leading or trailing characters to trim
      dir = (int)tv_get_number_chk(&argvars[2], &error);
      if (error) {
        return;
      }
      if (dir < 0 || dir > 2) {
        semsg(_(e_invarg2), tv_get_string(&argvars[2]));
        return;
      }
    }
  }

  int c1;
  if (dir == 0 || dir == 1) {
    // Trim leading characters
    while (*head != NUL) {
      c1 = utf_ptr2char(head);
      if (mask == NULL) {
        if (c1 > ' ' && c1 != 0xa0) {
          break;
        }
      } else {
        for (p = mask; *p != NUL; MB_PTR_ADV(p)) {
          if (c1 == utf_ptr2char(p)) {
            break;
          }
        }
        if (*p == NUL) {
          break;
        }
      }
      MB_PTR_ADV(head);
    }
  }

  const char *tail = head + strlen(head);
  if (dir == 0 || dir == 2) {
    // Trim trailing characters
    for (; tail > head; tail = prev) {
      prev = tail;
      MB_PTR_BACK(head, prev);
      c1 = utf_ptr2char(prev);
      if (mask == NULL) {
        if (c1 > ' ' && c1 != 0xa0) {
          break;
        }
      } else {
        for (p = mask; *p != NUL; MB_PTR_ADV(p)) {
          if (c1 == utf_ptr2char(p)) {
            break;
          }
        }
        if (*p == NUL) {
          break;
        }
      }
    }
  }
  rettv->vval.v_string = xstrnsave(head, (size_t)(tail - head));
}
