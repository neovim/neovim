#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/strings.h"
#include "nvim/misc2.h"
#include "nvim/file_search.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/ops.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"

/*
 * Copy "string" into newly allocated memory.
 */
char_u *vim_strsave(const char_u *string)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  return (char_u *)xstrdup((char *)string);
}

/*
 * Copy up to "len" bytes of "string" into newly allocated memory and
 * terminate with a NUL.
 * The allocated memory always has size "len + 1", also when "string" is
 * shorter.
 */
char_u *vim_strnsave(const char_u *string, size_t len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  return (char_u *)strncpy(xmallocz(len), (char *)string, len);
}

/*
 * Same as vim_strsave(), but any characters found in esc_chars are preceded
 * by a backslash.
 */
char_u *vim_strsave_escaped(const char_u *string, const char_u *esc_chars)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  return vim_strsave_escaped_ext(string, esc_chars, '\\', false);
}

/*
 * Same as vim_strsave_escaped(), but when "bsl" is true also escape
 * characters where rem_backslash() would remove the backslash.
 * Escape the characters with "cc".
 */
char_u *vim_strsave_escaped_ext(const char_u *string, const char_u *esc_chars,
                                char_u cc, bool bsl)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  /*
   * First count the number of backslashes required.
   * Then allocate the memory and insert them.
   */
  size_t length = 1;                    // count the trailing NUL
  for (const char_u *p = string; *p; p++) {
    size_t l;
    if (has_mbyte && (l = (size_t)(*mb_ptr2len)(p)) > 1) {
      length += l;                      // count a multibyte char
      p += l - 1;
      continue;
    }
    if (vim_strchr(esc_chars, *p) != NULL || (bsl && rem_backslash(p)))
      ++length;                         /* count a backslash */
    ++length;                           /* count an ordinary char */
  }

  char_u *escaped_string = xmalloc(length);
  char_u *p2 = escaped_string;
  for (const char_u *p = string; *p; p++) {
    size_t l;
    if (has_mbyte && (l = (size_t)(*mb_ptr2len)(p)) > 1) {
      memcpy(p2, p, l);
      p2 += l;
      p += l - 1;                     /* skip multibyte char  */
      continue;
    }
    if (vim_strchr(esc_chars, *p) != NULL || (bsl && rem_backslash(p)))
      *p2++ = cc;
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
  (*p == '\\' && inquote && p + 1 < string_end && (p[1] == '\\' || p[1] == '"'))
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

/*
 * Escape "string" for use as a shell argument with system().
 * This uses single quotes, except when we know we need to use double quotes
 * (MS-Windows without 'shellslash' set).
 * Escape a newline, depending on the 'shell' option.
 * When "do_special" is true also replace "!", "%", "#" and things starting
 * with "<" like "<cfile>".
 * When "do_newline" is false do not escape newline unless it is csh shell.
 * Returns the result in allocated memory.
 */
char_u *vim_strsave_shellescape(const char_u *string,
                                bool do_special, bool do_newline)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char_u      *d;
  char_u      *escaped_string;
  size_t l;
  int csh_like;

  /* Only csh and similar shells expand '!' within single quotes.  For sh and
   * the like we must not put a backslash before it, it will be taken
   * literally.  If do_special is set the '!' will be escaped twice.
   * Csh also needs to have "\n" escaped twice when do_special is set. */
  csh_like = csh_like_shell();

  /* First count the number of extra bytes required. */
  size_t length = STRLEN(string) + 3;       // two quotes and a trailing NUL
  for (const char_u *p = string; *p != NUL; mb_ptr_adv(p)) {
    if (*p == '\'')
      length += 3;                      /* ' => '\'' */
    if ((*p == '\n' && (csh_like || do_newline))
        || (*p == '!' && (csh_like || do_special))) {
      ++length;                         /* insert backslash */
      if (csh_like && do_special)
        ++length;                       /* insert backslash */
    }
    if (do_special && find_cmdline_var(p, &l) >= 0) {
      ++length;                         /* insert backslash */
      p += l - 1;
    }
  }

  /* Allocate memory for the result and fill it. */
  escaped_string = xmalloc(length);
  d = escaped_string;

  /* add opening quote */
  *d++ = '\'';

  for (const char_u *p = string; *p != NUL; ) {
    if (*p == '\'') {
      *d++ = '\'';
      *d++ = '\\';
      *d++ = '\'';
      *d++ = '\'';
      ++p;
      continue;
    }
    if ((*p == '\n' && (csh_like || do_newline))
        || (*p == '!' && (csh_like || do_special))) {
      *d++ = '\\';
      if (csh_like && do_special)
        *d++ = '\\';
      *d++ = *p++;
      continue;
    }
    if (do_special && find_cmdline_var(p, &l) >= 0) {
      *d++ = '\\';                    /* insert backslash */
      while (--l != SIZE_MAX)                /* copy the var */
        *d++ = *p++;
      continue;
    }

    MB_COPY_CHAR(p, d);
  }

  /* add terminating quote and finish with a NUL */
  *d++ = '\'';
  *d = NUL;

  return escaped_string;
}

/*
 * Like vim_strsave(), but make all characters uppercase.
 * This uses ASCII lower-to-upper case translation, language independent.
 */
char_u *vim_strsave_up(const char_u *string)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char_u *p1;

  p1 = vim_strsave(string);
  vim_strup(p1);
  return p1;
}

/*
 * Like vim_strnsave(), but make all characters uppercase.
 * This uses ASCII lower-to-upper case translation, language independent.
 */
char_u *vim_strnsave_up(const char_u *string, size_t len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char_u *p1 = vim_strnsave(string, len);
  vim_strup(p1);
  return p1;
}

/*
 * ASCII lower-to-upper case translation, language independent.
 */
void vim_strup(char_u *p)
  FUNC_ATTR_NONNULL_ALL
{
  char_u c;
  while ((c = *p) != NUL) {
    *p++ = (char_u)(c < 'a' || c > 'z' ? c : c - 0x20);
  }
}

/*
 * Make string "s" all upper-case and return it in allocated memory.
 * Handles multi-byte characters as well as possible.
 */
char_u *strup_save(const char_u *orig)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  char_u *res = vim_strsave(orig);

  char_u *p = res;
  while (*p != NUL) {
    int l;

    if (enc_utf8) {
      int c = utf_ptr2char(p);
      int uc = utf_toupper(c);

      /* Reallocate string when byte count changes.  This is rare,
       * thus it's OK to do another malloc()/free(). */
      l = utf_ptr2len(p);
      int newl = utf_char2len(uc);
      if (newl != l) {
        // TODO(philix): use xrealloc() in strup_save()
        char_u *s = xmalloc(STRLEN(res) + (size_t)(1 + newl - l));
        memcpy(s, res, (size_t)(p - res));
        STRCPY(s + (p - res) + newl, p + l);
        p = s + (p - res);
        xfree(res);
        res = s;
      }

      utf_char2bytes(uc, p);
      p += newl;
    } else if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1)
      p += l;                 /* skip multi-byte character */
    else {
      *p = (char_u) TOUPPER_LOC(*p);  // note that toupper() can be a macro
      p++;
    }
  }

  return res;
}

/*
 * delete spaces at the end of a string
 */
void del_trailing_spaces(char_u *ptr)
  FUNC_ATTR_NONNULL_ALL
{
  char_u      *q;

  q = ptr + STRLEN(ptr);
  while (--q > ptr && ascii_iswhite(q[0]) && q[-1] != '\\' && q[-1] != Ctrl_V)
    *q = NUL;
}

/*
 * Like strcat(), but make sure the result fits in "tosize" bytes and is
 * always NUL terminated.
 */
void vim_strcat(char_u *restrict to, const char_u *restrict from,
                size_t tosize)
  FUNC_ATTR_NONNULL_ALL
{
  size_t tolen = STRLEN(to);
  size_t fromlen = STRLEN(from);

  if (tolen + fromlen + 1 > tosize) {
    memcpy(to + tolen, from, tosize - tolen - 1);
    to[tosize - 1] = NUL;
  } else
    STRCPY(to + tolen, from);
}

#if (!defined(HAVE_STRCASECMP) && !defined(HAVE_STRICMP))
/*
 * Compare two strings, ignoring case, using current locale.
 * Doesn't work for multi-byte characters.
 * return 0 for match, < 0 for smaller, > 0 for bigger
 */
int vim_stricmp(const char *s1, const char *s2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  int i;

  for (;; ) {
    i = (int)TOLOWER_LOC(*s1) - (int)TOLOWER_LOC(*s2);
    if (i != 0)
      return i;                             /* this character different */
    if (*s1 == NUL)
      break;                                /* strings match until NUL */
    ++s1;
    ++s2;
  }
  return 0;                                 /* strings match */
}
#endif

#if (!defined(HAVE_STRNCASECMP) && !defined(HAVE_STRNICMP))
/*
 * Compare two strings, for length "len", ignoring case, using current locale.
 * Doesn't work for multi-byte characters.
 * return 0 for match, < 0 for smaller, > 0 for bigger
 */
int vim_strnicmp(const char *s1, const char *s2, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  int i;

  while (len > 0) {
    i = (int)TOLOWER_LOC(*s1) - (int)TOLOWER_LOC(*s2);
    if (i != 0)
      return i;                             /* this character different */
    if (*s1 == NUL)
      break;                                /* strings match until NUL */
    ++s1;
    ++s2;
    --len;
  }
  return 0;                                 /* strings match */
}
#endif

/*
 * Version of strchr() and strrchr() that handle unsigned char strings
 * with characters from 128 to 255 correctly.  It also doesn't return a
 * pointer to the NUL at the end of the string.
 */
char_u *vim_strchr(const char_u *string, int c)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  int b;

  const char_u *p = string;
  if (enc_utf8 && c >= 0x80) {
    while (*p != NUL) {
      int l = (*mb_ptr2len)(p);

      // Avoid matching an illegal byte here.
      if (l > 1 && utf_ptr2char(p) == c) {
        return (char_u *) p;
      }
      p += l;
    }
    return NULL;
  }
  if (enc_dbcs != 0 && c > 255) {
    int n2 = c & 0xff;

    c = ((unsigned)c >> 8) & 0xff;
    while ((b = *p) != NUL) {
      if (b == c && p[1] == n2)
        return (char_u *) p;
      p += (*mb_ptr2len)(p);
    }
    return NULL;
  }
  if (has_mbyte) {
    while ((b = *p) != NUL) {
      if (b == c)
        return (char_u *) p;
      p += (*mb_ptr2len)(p);
    }
    return NULL;
  }
  while ((b = *p) != NUL) {
    if (b == c)
      return (char_u *) p;
    ++p;
  }
  return NULL;
}

/*
 * Version of strchr() that only works for bytes and handles unsigned char
 * strings with characters above 128 correctly. It also doesn't return a
 * pointer to the NUL at the end of the string.
 */
char_u *vim_strbyte(const char_u *string, int c)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const char_u *p = string;

  while (*p != NUL) {
    if (*p == c)
      return (char_u *) p;
    ++p;
  }
  return NULL;
}

/*
 * Search for last occurrence of "c" in "string".
 * Return NULL if not found.
 * Does not handle multi-byte char for "c"!
 */
char_u *vim_strrchr(const char_u *string, int c)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const char_u *retval = NULL;
  const char_u *p = string;

  while (*p) {
    if (*p == c)
      retval = p;
    mb_ptr_adv(p);
  }
  return (char_u *) retval;
}

/*
 * Sort an array of strings.
 */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "strings.c.generated.h"
#endif
static int sort_compare(const void *s1, const void *s2)
  FUNC_ATTR_NONNULL_ALL
{
  return STRCMP(*(char **)s1, *(char **)s2);
}

void sort_strings(char_u **files, int count)
{
  qsort((void *)files, (size_t)count, sizeof(char_u *), sort_compare);
}

/*
 * Return true if string "s" contains a non-ASCII character (128 or higher).
 * When "s" is NULL false is returned.
 */
bool has_non_ascii(const char_u *s)
  FUNC_ATTR_PURE
{
  const char_u *p;

  if (s != NULL)
    for (p = s; *p != NUL; ++p)
      if (*p >= 128)
        return true;
  return false;
}

/// Return true if string "s" contains a non-ASCII character (128 or higher).
/// When "s" is NULL false is returned.
bool has_non_ascii_len(const char *const s, const size_t len)
  FUNC_ATTR_PURE
{
  if (s != NULL) {
    for (size_t i = 0; i < len; i++) {
      if ((uint8_t) s[i] >= 128) {
        return true;
      }
    }
  }
  return false;
}

/*
 * Concatenate two strings and return the result in allocated memory.
 */
char_u *concat_str(const char_u *restrict str1, const char_u *restrict str2)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  size_t l = STRLEN(str1);
  char_u *dest = xmalloc(l + STRLEN(str2) + 1);
  STRCPY(dest, str1);
  STRCPY(dest + l, str2);
  return dest;
}

