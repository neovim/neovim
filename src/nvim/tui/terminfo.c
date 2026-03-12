// Built-in fallback terminfo entries.

#include <stdbool.h>
#include <string.h>

#ifdef HAVE_UNIBILIUM
# include <unibilium.h>
#endif

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/memory.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/terminfo_builtin.h"

#ifdef __FreeBSD__
# include "nvim/os/os.h"
#endif

typedef struct {
  long nums[20];
  char *strings[20];
  size_t offset;
} TPSTACK;

#include "tui/terminfo.c.generated.h"

bool terminfo_is_term_family(const char *term, const char *family)
{
  if (!term) {
    return false;
  }
  size_t tlen = strlen(term);
  size_t flen = strlen(family);
  return tlen >= flen
         && 0 == memcmp(term, family, flen)
         // Per commentary in terminfo, minus is the only valid suffix separator.
         // The screen terminfo may have a terminal name like screen.xterm. By making
         // the dot(.) a valid separator, such terminal names will also be the
         // terminal family of the screen.
         && (NUL == term[flen] || '-' == term[flen] || '.' == term[flen]);
}

bool terminfo_is_bsd_console(const char *term)
{
#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) \
  || defined(__DragonFly__)
  if (strequal(term, "vt220")         // OpenBSD
      || strequal(term, "vt100")) {   // NetBSD
    return true;
  }
# if defined(__FreeBSD__)
  // FreeBSD console sets TERM=xterm, but it does not support xterm features
  // like cursor-shaping. Assume that TERM=xterm is degraded. #8644
  return strequal(term, "xterm") && os_env_exists("XTERM_VERSION", true);
# endif
#endif
  return false;
}

/// Loads a built-in terminfo db when we (unibilium) failed to load a terminfo
/// record from the environment (termcap systems, unrecognized $TERM, …).
/// We do not attempt to detect xterm pretenders here.
///
/// @param term $TERM value
/// @param[out,static] termname decided builtin 'term' name
/// @return [allocated] terminfo structure
const TerminfoEntry *terminfo_from_builtin(const char *term, char **termname)
{
  if (strequal(term, "ghostty") || strequal(term, "xterm-ghostty")) {
    *termname = "ghostty";
    return &ghostty_terminfo;
  } else if (terminfo_is_term_family(term, "xterm")) {
    *termname = "xterm";
    return &xterm_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "screen")) {
    *termname = "screen";
    return &screen_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "tmux")) {
    *termname = "tmux";
    return &tmux_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "rxvt")) {
    *termname = "rxvt";
    return &rxvt_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "putty")) {
    *termname = "putty";
    return &putty_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "linux")) {
    *termname = "linux";
    return &linux_16colour_terminfo;
  } else if (terminfo_is_term_family(term, "interix")) {
    *termname = "interix";
    return &interix_8colour_terminfo;
  } else if (terminfo_is_term_family(term, "iterm")
             || terminfo_is_term_family(term, "iterm2")
             || terminfo_is_term_family(term, "iTerm.app")
             || terminfo_is_term_family(term, "iTerm2.app")) {
    *termname = "iterm";
    return &iterm_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "st")) {
    *termname = "st";
    return &st_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "gnome")
             || terminfo_is_term_family(term, "vte")) {
    *termname = "vte";
    return &vte_256colour_terminfo;
  } else if (terminfo_is_term_family(term, "cygwin")) {
    *termname = "cygwin";
    return &cygwin_terminfo;
  } else if (terminfo_is_term_family(term, "win32con")) {
    *termname = "win32con";
    return &win32con_terminfo;
  } else if (terminfo_is_term_family(term, "conemu")) {
    *termname = "conemu";
    return &conemu_terminfo;
  } else if (terminfo_is_term_family(term, "vtpcon")) {
    *termname = "vtpcon";
    return &vtpcon_terminfo;
  } else {
    *termname = "ansi";
    return &ansi_terminfo;
  }
}

bool terminfo_from_database(TerminfoEntry *ti, char *termname, Arena *arena)
{
#ifdef HAVE_UNIBILIUM
  unibi_term *ut = unibi_from_term(termname);
  if (!ut) {
    return false;
  }

  ti->bce = unibi_get_bool(ut, unibi_back_color_erase);
  ti->max_colors = unibi_get_num(ut, unibi_max_colors);
  ti->lines = unibi_get_num(ut, unibi_lines);
  ti->columns = unibi_get_num(ut, unibi_columns);

  // Check for Tc or RGB
  ti->has_Tc_or_RGB = false;
  ti->Su = false;
  for (size_t i = 0; i < unibi_count_ext_bool(ut); i++) {
    const char *n = unibi_get_ext_bool_name(ut, i);
    if (n && (!strcmp(n, "Tc") || !strcmp(n, "RGB"))) {
      ti->has_Tc_or_RGB = true;
    } else if (n && !strcmp(n, "Su")) {
      ti->Su = true;
    }
  }

  static const enum unibi_string uni_ids[] = {
# define X(name) unibi_##name,
    XLIST_TERMINFO_BUILTIN
# undef X
  };

  for (size_t i = 0; i < ARRAY_SIZE(uni_ids); i++) {
    const char *val = unibi_get_str(ut, uni_ids[i]);
    ti->defs[i] = val ? arena_strdup(arena, val) : NULL;
  }

  static const char *uni_ext[] = {
# define X(informal_name, terminfo_name) #terminfo_name,
    XLIST_TERMINFO_EXT
# undef X
  };

  size_t max = unibi_count_ext_str(ut);
  for (size_t i = 0; i < ARRAY_SIZE(uni_ext); i++) {
    const char *name = uni_ext[i];
    for (size_t val = 0; val < max; val++) {
      const char *n = unibi_get_ext_str_name(ut, val);
      if (n && strequal(n, name)) {
        const char *data = unibi_get_ext_str(ut, val);
        ti->defs[kTermExtOffset + i] = data ? arena_strdup(arena, data) : NULL;
        break;
      }
    }
  }

# define X(name) { unibi_key_##name, unibi_string_begin_ },
# define Y(name) { unibi_key_##name, unibi_key_s##name },
  static const enum unibi_string uni_keys[][2] = {
    XYLIST_TERMINFO_KEYS
  };
# undef X
# undef Y

  for (size_t i = 0; i < ARRAY_SIZE(uni_keys); i++) {
    const char *val = unibi_get_str(ut, uni_keys[i][0]);
    if (val) {
      ti->keys[i][0] = arena_strdup(arena, val);
      if (uni_keys[i][1] != unibi_string_begin_) {
        const char *sval = unibi_get_str(ut, uni_keys[i][1]);
        ti->keys[i][1] = sval ? arena_strdup(arena, sval) : NULL;
      }
    }
  }

  static const enum unibi_string uni_fkeys[] = {
# define X(name) unibi_key_##name,
    XLIST_TERMINFO_FKEYS
# undef X
  };

  for (size_t i = 0; i < ARRAY_SIZE(uni_fkeys); i++) {
    const char *val = unibi_get_str(ut, uni_fkeys[i]);
    ti->f_keys[i] = val ? arena_strdup(arena, val) : NULL;
  }

  unibi_destroy(ut);
  return true;
#else
  return false;
#endif
}

static const char *fmt(bool val)
{
  return val ? "true" : "false";
}

/// Dumps termcap info to the messages area.
/// Serves a similar purpose as Vim `:set termcap` (removed in Nvim).
///
/// @return allocated string
String terminfo_info_msg(const TerminfoEntry *ti, const char *termname, bool from_db)
{
  StringBuilder data = KV_INITIAL_VALUE;

  kv_printf(data, "&term: %s\n", termname);
  if (from_db) {
    kv_printf(data, "using terminfo database\n");
  } else {
    kv_printf(data, "using builtin terminfo\n");
  }
  kv_printf(data, "\n");

  kv_printf(data, "Boolean capabilities:\n");
  kv_printf(data, "  back_color_erase: %s\n", fmt(ti->bce));
  kv_printf(data, "  truecolor ('Tc' or 'RGB'): %s\n", fmt(ti->has_Tc_or_RGB));
  kv_printf(data, "  extended underline ('Su'): %s\n", fmt(ti->Su));
  kv_printf(data, "\n");

  kv_printf(data, "Numeric capabilities: (-1 for unknown)\n");
  kv_printf(data, "  lines: %d\n", ti->lines);
  kv_printf(data, "  columns: %d\n", ti->columns);
  kv_printf(data, "  max_colors: %d\n", ti->columns);
  kv_printf(data, "\n");

  kv_printf(data, "String capabilities:\n");

  static const char *string_names[] = {
#define X(name) #name,
    XLIST_TERMINFO_BUILTIN
#undef X
#define X(internal_name, terminfo_name) (#internal_name " (" #terminfo_name ")"),
    XLIST_TERMINFO_EXT
#undef X
  };

  for (size_t i = 0; i < ARRAY_SIZE(string_names); i++) {
    const char *s = ti->defs[i];
    if (s) {
      kv_printf(data, "  %-31s = ", string_names[i]);
      // Most of these strings will contain escape sequences.
      kv_transstr(&data, s, false);
      kv_push(data, '\n');
    }
  }

  static const char *key_names[] = {
#define X(name) #name,
#define Y(name) #name,
    XYLIST_TERMINFO_KEYS
#undef X
#undef Y
  };

  for (size_t i = 0 + 1; i < ARRAY_SIZE(key_names); i++) {
    const char *s = ti->keys[i][0];
    if (s) {
      kv_printf(data, "  key_%-27s = ", key_names[i]);
      kv_transstr(&data, s, false);
      const char *ss = ti->keys[i][1];
      if (ss) {
        kv_printf(data, ", key_s%s = ", key_names[i]);
        kv_transstr(&data, ss, false);
      }
      kv_push(data, '\n');
    }
  }

  static const char *fkey_names[] = {
#define X(name) #name,
    XLIST_TERMINFO_FKEYS
#undef X
  };

  for (size_t i = 0 + 1; i < ARRAY_SIZE(fkey_names); i++) {
    const char *s = ti->f_keys[i];
    if (s) {
      kv_printf(data, "  key_%-27s = ", fkey_names[i]);
      kv_transstr(&data, s, false);
      kv_push(data, '\n');
    }
  }

  kv_push(data, NUL);
  return cbuf_as_string(data.items, data.size - 1);
}

// The implementation of terminfo_fmt() is based on NetBSD libterminfo,
// with full license reproduced below

// Copyright (c) 2009, 2011, 2013 The NetBSD Foundation, Inc.
//
// This code is derived from software contributed to The NetBSD Foundation
// by Roy Marples.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// nvim modifications:
// - use typesafe param args instead of va_args and piss
// - caller provides the output buffer
// - static variables are not preserved

static int push(long num, char *string, TPSTACK *stack)
{
  if (stack->offset >= ARRAY_SIZE(stack->nums)) {
    return -1;
  }
  stack->nums[stack->offset] = num;
  stack->strings[stack->offset] = string;
  stack->offset++;
  return 0;
}

static int pop(long *num, char **string, TPSTACK *stack)
{
  if (stack->offset == 0) {
    if (num) {
      *num = 0;
    }
    if (string) {
      *string = NULL;
    }
    return -1;
  }
  stack->offset--;
  if (num) {
    *num = stack->nums[stack->offset];
  }
  if (string) {
    *string = stack->strings[stack->offset];
  }
  return 0;
}

static bool ochar(char **buf, const char *buf_end, int c)
{
  if (c == 0) {
    c = 0200;
  }
  // Check we have space and a terminator
  if (buf_end - *buf < 2) {
    return 0;
  }
  *(*buf)++ = (char)c;
  return 1;
}

static bool onum(char **buf, const char *buf_end, const char *fmt, int num, size_t len)
{
  const size_t LONG_STR_MAX = 21;
  len = MAX(len, LONG_STR_MAX);

  if (buf_end - *buf < (ssize_t)(len + 2)) {
    return 0;
  }
  int l = snprintf(*buf, len + 2, fmt, num);
  if (l == -1) {
    return 0;
  }
  *buf += l;
  return true;
}

/// @return number of chars printed or 0 for any error
size_t terminfo_fmt(char *buf_start, char *buf_end, const char *str, TPVAR params[9])
{
  char c, fmt[64], *fp, *ostr;
  long val, val2;
  long dnums[26];  // dynamic variables a-z, not preserved
  long snums[26];  // static variables a-z, not preserved EITHER HAHA
  memset(dnums, 0, sizeof snums);
  memset(snums, 0, sizeof snums);

  char *buf = buf_start;

  size_t l, width, precision, olen;
  TPSTACK stack;
  unsigned done, dot, minus;

  memset(&stack, 0, sizeof(stack));
  while ((c = *str++) != '\0') {
    if (c != '%' || (c = *str++) == '%') {
      if (c == '\0') {
        break;
      }
      if (!ochar(&buf, buf_end, c)) {
        return false;
      }
      continue;
    }

    // Handle formatting.
    fp = fmt;
    *fp++ = '%';
    done = dot = minus = 0;
    width = precision = 0;
    val = 0;
    while (done == 0 && (size_t)(fp - fmt) < sizeof(fmt)) {
      switch (c) {
      case 'c':
      case 's':
        *fp++ = c;
        done = 1;
        break;
      case 'd':
      case 'o':
      case 'x':
      case 'X':
        *fp++ = 'l';
        *fp++ = c;
        done = 1;
        break;
      case '#':
      case ' ':
        *fp++ = c;
        break;
      case '.':
        *fp++ = c;
        if (dot == 0) {
          dot = 1;
          width = (size_t)val;
        } else {
          done = 2;
        }
        val = 0;
        break;
      case ':':
        minus = 1;
        break;
      case '-':
        if (minus) {
          *fp++ = c;
        } else {
          done = 1;
        }
        break;
      default:
        if (isdigit((unsigned char)c)) {
          val = (val * 10) + (c - '0');
          if (val > 10000) {
            done = 2;
          } else {
            *fp++ = c;
          }
        } else {
          done = 1;
        }
      }
      if (done == 0) {
        c = *str++;
      }
    }
    if (done == 2) {
      // Found an error in the format
      fp = fmt + 1;
      *fp = *str;
      olen = 0;
    } else {
      if (dot == 0) {
        width = (size_t)val;
      } else {
        precision = (size_t)val;
      }
      olen = MAX(width, precision);
    }
    *fp++ = '\0';

    // Handle commands
    switch (c) {
    case 'c':
      pop(&val, NULL, &stack);
      if (!ochar(&buf, buf_end, (unsigned char)val)) {
        return false;
      }
      break;
    case 's':
      pop(NULL, &ostr, &stack);
      if (ostr != NULL) {
        int r;

        l = strlen(ostr);
        if (l < olen) {
          l = olen;
        }
        if ((size_t)(buf_end - buf) < (l + 1)) {
          return false;
        }
        r = snprintf(buf, l + 1,
                     fmt, ostr);
        if (r != -1) {
          buf += (size_t)r;
        }
      }
      break;
    case 'l':
      pop(NULL, &ostr, &stack);
      if (ostr == NULL) {
        l = 0;
      } else {
        l = strlen(ostr);
      }
      push((long)l, NULL, &stack);
      break;
    case 'd':
    case 'o':
    case 'x':
    case 'X':
      pop(&val, NULL, &stack);
      if (onum(&buf, buf_end, fmt, (int)val, olen) == 0) {
        return 0;
      }
      break;
    case 'p':
      if (*str < '1' || *str > '9') {
        break;
      }
      l = (size_t)(*str++ - '1');
      if (push(params[l].num, params[l].string, &stack)) {
        return 0;
      }
      break;
    case 'P':
      pop(&val, NULL, &stack);
      if (*str >= 'a' && *str <= 'z') {
        dnums[*str - 'a'] = val;
      } else if (*str >= 'A' && *str <= 'Z') {
        snums[*str - 'A'] = val;
      }
      break;
    case 'g':
      if (*str >= 'a' && *str <= 'z') {
        if (push(dnums[*str - 'a'], NULL, &stack)) {
          return 0;
        }
      } else if (*str >= 'A' && *str <= 'Z') {
        if (push(snums[*str - 'A'], NULL, &stack)) {
          return 0;
        }
      }
      break;
    case 'i':
      params[0].num++;
      params[1].num++;
      break;
    case '\'':
      if (push((long)(unsigned char)(*str++), NULL, &stack)) {
        return 0;
      }
      while (*str != '\0' && *str != '\'') {
        str++;
      }
      if (*str == '\'') {
        str++;
      }
      break;
    case '{':
      val = 0;
      for (; isdigit((unsigned char)(*str)); str++) {
        val = (val * 10) + (*str - '0');
      }
      if (push(val, NULL, &stack)) {
        return 0;
      }
      while (*str != '\0' && *str != '}') {
        str++;
      }
      if (*str == '}') {
        str++;
      }
      break;
    case '+':
    case '-':
    case '*':
    case '/':
    case 'm':
    case 'A':
    case 'O':
    case '&':
    case '|':
    case '^':
    case '=':
    case '<':
    case '>':
      pop(&val, NULL, &stack);
      pop(&val2, NULL, &stack);
      switch (c) {
      case '+':
        val = val + val2;
        break;
      case '-':
        val = val2 - val;
        break;
      case '*':
        val = val * val2;
        break;
      case '/':
        val = val ? val2 / val : 0;
        break;
      case 'm':
        val = val ? val2 % val : 0;
        break;
      case 'A':
        val = val && val2;
        break;
      case 'O':
        val = val || val2;
        break;
      case '&':
        val = val & val2;
        break;
      case '|':
        val = val | val2;
        break;
      case '^':
        val = val ^ val2;
        break;
      case '=':
        val = val == val2;
        break;
      case '<':
        val = val2 < val;
        break;
      case '>':
        val = val2 > val;
        break;
      }
      if (push(val, NULL, &stack)) {
        return 0;
      }
      break;
    case '!':
    case '~':
      pop(&val, NULL, &stack);
      switch (c) {
      case '!':
        val = !val;
        break;
      case '~':
        val = ~val;
        break;
      }
      if (push(val, NULL, &stack)) {
        return 0;
      }
      break;
    case '?':  // if
      break;
    case 't':  // then
      pop(&val, NULL, &stack);
      if (val == 0) {
        l = 0;
        for (; *str != '\0'; str++) {
          if (*str != '%') {
            continue;
          }
          str++;
          if (*str == '?') {
            l++;
          } else if (*str == ';') {
            if (l > 0) {
              l--;
            } else {
              str++;
              break;
            }
          } else if (*str == 'e' && l == 0) {
            str++;
            break;
          }
        }
      }
      break;
    case 'e':  // else
      l = 0;
      for (; *str != '\0'; str++) {
        if (*str != '%') {
          continue;
        }
        str++;
        if (*str == '?') {
          l++;
        } else if (*str == ';') {
          if (l > 0) {
            l--;
          } else {
            str++;
            break;
          }
        }
      }
      break;
    case ';':  // fi
      break;
    }
  }
  return (size_t)(buf - buf_start);
}
