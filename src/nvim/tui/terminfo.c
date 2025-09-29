// Built-in fallback terminfo entries.

#include <stdbool.h>
#include <string.h>
#include <unibilium.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/memory.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/terminfo_defs.h"

#ifdef __FreeBSD__
# include "nvim/os/os.h"
#endif

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
/// @param[out,allocated] termname decided builtin 'term' name
/// @return [allocated] terminfo structure
static const NeoTerminfo *terminfo_builtin(const char *term, char **termname)
{
// #define doit(name) *neo = &NEW__##name; return unibi_from_mem((const char *)name, sizeof name);
#define doit(name) return &NEW__##name;
  if (terminfo_is_term_family(term, "xterm")) {
    *termname = xstrdup("builtin_xterm");
    doit(xterm_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "screen")) {
    *termname = xstrdup("builtin_screen");
    doit(screen_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "tmux")) {
    *termname = xstrdup("builtin_tmux");
    doit(tmux_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "rxvt")) {
    *termname = xstrdup("builtin_rxvt");
    doit(rxvt_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "putty")) {
    *termname = xstrdup("builtin_putty");
    doit(putty_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "linux")) {
    *termname = xstrdup("builtin_linux");
    doit(linux_16colour_terminfo);
  } else if (terminfo_is_term_family(term, "interix")) {
    *termname = xstrdup("builtin_interix");
    doit(interix_8colour_terminfo);
  } else if (terminfo_is_term_family(term, "iterm")
             || terminfo_is_term_family(term, "iterm2")
             || terminfo_is_term_family(term, "iTerm.app")
             || terminfo_is_term_family(term, "iTerm2.app")) {
    *termname = xstrdup("builtin_iterm");
    doit(iterm_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "st")) {
    *termname = xstrdup("builtin_st");
    doit(st_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "gnome")
             || terminfo_is_term_family(term, "vte")) {
    *termname = xstrdup("builtin_vte");
    doit(vte_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "cygwin")) {
    *termname = xstrdup("builtin_cygwin");
    doit(cygwin_terminfo);
  } else if (terminfo_is_term_family(term, "win32con")) {
    *termname = xstrdup("builtin_win32con");
    doit(win32con_terminfo);
  } else if (terminfo_is_term_family(term, "conemu")) {
    *termname = xstrdup("builtin_conemu");
    doit(conemu_terminfo);
  } else if (terminfo_is_term_family(term, "vtpcon")) {
    *termname = xstrdup("builtin_vtpcon");
    doit(vtpcon_terminfo);
  } else {
    *termname = xstrdup("builtin_ansi");
    doit(ansi_terminfo);
  }
}

static ssize_t unibi_find_ext_str(unibi_term *ut, const char *name)
{
  size_t max = unibi_count_ext_str(ut);
  for (size_t i = 0; i < max; i++) {
    const char *n = unibi_get_ext_str_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (ssize_t)i;
    }
  }
  return -1;
}

static int unibi_find_ext_bool(unibi_term *ut, const char *name)
{
  size_t max = unibi_count_ext_bool(ut);
  for (size_t i = 0; i < max; i++) {
    const char *n = unibi_get_ext_bool_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (int)i;
    }
  }
  return -1;
}

/// @param term $TERM value
/// @param[out,allocated] termname decided builtin 'term' name
/// @return [allocated] terminfo structure
const NeoTerminfo *terminfo_from_builtin(const char *term, char **termname)
{
  const NeoTerminfo *ti = terminfo_builtin(term, termname);
  if (*termname == NULL) {
    *termname = xstrdup("builtin_?");
  }
  return ti;
}

bool terminfo_from_unibilium(NeoTerminfo *ti, char *termname) {
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
  for (size_t i = 0; i < unibi_count_ext_bool(ut); i++) {
    const char *n = unibi_get_ext_bool_name(ut, i);
    if (n && (!strcmp(n, "Tc") || !strcmp(n, "RGB"))) {
      ti->has_Tc_or_RGB = true;
      break;
    }
  }

  static const enum unibi_string uni_ids[] = {
#define X(name) unibi_##name,
    XLIST_TERMINFO_BUILTIN
#undef X
  };

  for (size_t i = 0; i < ARRAY_SIZE(uni_ids); i++) {
    const char *val = unibi_get_str(ut, uni_ids[i]);
    ti->defs[i] = val ? xstrdup(val) : NULL;
  }

  static const char *uni_ext[] = {
#define X(informal_name, terminfo_name) #terminfo_name ,
    XLIST_TERMINFO_EXT
#undef X
  };

  for (size_t i = 0; i < ARRAY_SIZE(uni_ext); i++) {
    ssize_t val = unibi_find_ext_str(ut, uni_ext[i]);
    ti->defs[kTermExtOffset + i] = val >= 0 ? xstrdup(unibi_get_ext_str(ut, (size_t)val)) : NULL;
  }
  

  unibi_destroy(ut);
  return true;
}

/// Dumps termcap info to the messages area.
/// Serves a similar purpose as Vim `:set termcap` (removed in Nvim).
///
/// @note adapted from unibilium unibi-dump.c
/// @return allocated string
String terminfo_info_msg(const unibi_term *ut, const char *termname)
{
  StringBuilder data = KV_INITIAL_VALUE;

  kv_printf(data, "&term: %s\n", termname);
  kv_printf(data, "Description: %s\n", unibi_get_name(ut));
  const char **a = unibi_get_aliases(ut);
  if (*a) {
    kv_printf(data, "Aliases: ");
    do {
      kv_printf(data, "%s%s\n", *a, a[1] ? " | " : "");
      a++;
    } while (*a);
  }

  kv_printf(data, "Boolean capabilities:\n");
  for (enum unibi_boolean i = unibi_boolean_begin_ + 1;
       i < unibi_boolean_end_; i++) {
    kv_printf(data, "  %-25s %-10s = %s\n", unibi_name_bool(i),
              unibi_short_name_bool(i),
              unibi_get_bool(ut, i) ? "true" : "false");
  }

  kv_printf(data, "Numeric capabilities:\n");
  for (enum unibi_numeric i = unibi_numeric_begin_ + 1;
       i < unibi_numeric_end_; i++) {
    int n = unibi_get_num(ut, i);  // -1 means "empty"
    kv_printf(data, "  %-25s %-10s = %d\n", unibi_name_num(i),
              unibi_short_name_num(i), n);
  }

  kv_printf(data, "String capabilities:\n");
  for (enum unibi_string i = unibi_string_begin_ + 1;
       i < unibi_string_end_; i++) {
    const char *s = unibi_get_str(ut, i);
    if (s) {
      kv_printf(data, "  %-25s %-10s = ", unibi_name_str(i),
                unibi_short_name_str(i));
      // Most of these strings will contain escape sequences.
      kv_transstr(&data, s, false);
      kv_push(data, '\n');
    }
  }

  if (unibi_count_ext_bool(ut)) {
    kv_printf(data, "Extended boolean capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_bool(ut); i++) {
      kv_printf(data, "  %-25s = %s\n",
                unibi_get_ext_bool_name(ut, i),
                unibi_get_ext_bool(ut, i) ? "true" : "false");
    }
  }

  if (unibi_count_ext_num(ut)) {
    kv_printf(data, "Extended numeric capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_num(ut); i++) {
      kv_printf(data, "  %-25s = %d\n",
                unibi_get_ext_num_name(ut, i),
                unibi_get_ext_num(ut, i));
    }
  }

  if (unibi_count_ext_str(ut)) {
    kv_printf(data, "Extended string capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_str(ut); i++) {
      kv_printf(data, "  %-25s = ", unibi_get_ext_str_name(ut, i));
      // NOTE: unibi_get_ext_str(ut, i) might be NULL, as termcap
      // might include junk data on mac os. kv_transstr will handle this.
      kv_transstr(&data, unibi_get_ext_str(ut, i), false);
      kv_push(data, '\n');
    }
  }
  kv_push(data, NUL);

  return cbuf_as_string(data.items, data.size - 1);
}
