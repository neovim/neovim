// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Built-in fallback terminfo entries.

#include <stdbool.h>
#include <string.h>

#include <unibilium.h>

#include "nvim/log.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/terminfo_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/terminfo.c.generated.h"
#endif

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
    && ('\0' == term[flen] || '-' == term[flen]);
}

/// Loads a built-in terminfo db when we (unibilium) failed to load a terminfo
/// record from the environment (termcap systems, unrecognized $TERM, …).
/// We do not attempt to detect xterm pretenders here.
///
/// @param term $TERM value
/// @param[out,allocated] termname decided builtin 'term' name
/// @return [allocated] terminfo structure
static unibi_term *terminfo_builtin(const char *term, char **termname)
{
  if (terminfo_is_term_family(term, "xterm")) {
    *termname = xstrdup("builtin_xterm");
    return unibi_from_mem((const char *)xterm_256colour_terminfo,
                          sizeof xterm_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "screen")) {
    *termname = xstrdup("builtin_screen");
    return unibi_from_mem((const char *)screen_256colour_terminfo,
                          sizeof screen_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "tmux")) {
    *termname = xstrdup("builtin_tmux");
    return unibi_from_mem((const char *)tmux_256colour_terminfo,
                          sizeof tmux_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "rxvt")) {
    *termname = xstrdup("builtin_rxvt");
    return unibi_from_mem((const char *)rxvt_256colour_terminfo,
                          sizeof rxvt_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "putty")) {
    *termname = xstrdup("builtin_putty");
    return unibi_from_mem((const char *)putty_256colour_terminfo,
                          sizeof putty_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "linux")) {
    *termname = xstrdup("builtin_linux");
    return unibi_from_mem((const char *)linux_16colour_terminfo,
                          sizeof linux_16colour_terminfo);
  } else if (terminfo_is_term_family(term, "interix")) {
    *termname = xstrdup("builtin_interix");
    return unibi_from_mem((const char *)interix_8colour_terminfo,
                          sizeof interix_8colour_terminfo);
  } else if (terminfo_is_term_family(term, "iterm")
             || terminfo_is_term_family(term, "iterm2")
             || terminfo_is_term_family(term, "iTerm.app")
             || terminfo_is_term_family(term, "iTerm2.app")) {
    *termname = xstrdup("builtin_iterm");
    return unibi_from_mem((const char *)iterm_256colour_terminfo,
                          sizeof iterm_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "st")) {
    *termname = xstrdup("builtin_st");
    return unibi_from_mem((const char *)st_256colour_terminfo,
                          sizeof st_256colour_terminfo);
  } else if (terminfo_is_term_family(term, "gnome")
             || terminfo_is_term_family(term, "vte")) {
    *termname = xstrdup("builtin_vte");
    return unibi_from_mem((const char *)vte_256colour_terminfo,
                          sizeof vte_256colour_terminfo);
  } else {
    *termname = xstrdup("builtin_ansi");
    return unibi_from_mem((const char *)ansi_terminfo,
                          sizeof ansi_terminfo);
  }
}

/// @param term $TERM value
/// @param[out,allocated] termname decided builtin 'term' name
/// @return [allocated] terminfo structure
unibi_term *terminfo_from_builtin(const char *term, char **termname)
{
  unibi_term *ut = terminfo_builtin(term, termname);
  if (*termname == NULL) {
    *termname = xstrdup("builtin_?");
  }
  // Disable BCE by default (for built-in terminfos). #7624
  // https://github.com/kovidgoyal/kitty/issues/160#issuecomment-346470545
  unibi_set_bool(ut, unibi_back_color_erase, false);
  return ut;
}

/// Dumps termcap info to the messages area.
/// Serves a similar purpose as Vim `:set termcap` (removed in Nvim).
///
/// @note adapted from unibilium unibi-dump.c
void terminfo_info_msg(const unibi_term *const ut)
{
  if (exiting) {
    return;
  }
  msg_puts_title("\n\n--- Terminal info --- {{{\n");

  char *term;
  get_tty_option("term", &term);
  msg_printf_attr(0, "&term: %s\n", term);
  msg_printf_attr(0, "Description: %s\n", unibi_get_name(ut));
  const char **a = unibi_get_aliases(ut);
  if (*a) {
    msg_puts("Aliases: ");
    do {
      msg_printf_attr(0, "%s%s\n", *a, a[1] ? " | " : "");
      a++;
    } while (*a);
  }

  msg_puts("Boolean capabilities:\n");
  for (enum unibi_boolean i = unibi_boolean_begin_ + 1;
       i < unibi_boolean_end_; i++) {
    msg_printf_attr(0, "  %-25s %-10s = %s\n", unibi_name_bool(i),
                    unibi_short_name_bool(i),
                    unibi_get_bool(ut, i) ? "true" : "false");
  }

  msg_puts("Numeric capabilities:\n");
  for (enum unibi_numeric i = unibi_numeric_begin_ + 1;
       i < unibi_numeric_end_; i++) {
    int n = unibi_get_num(ut, i);  // -1 means "empty"
    msg_printf_attr(0, "  %-25s %-10s = %hd\n", unibi_name_num(i),
                    unibi_short_name_num(i), n);
  }

  msg_puts("String capabilities:\n");
  for (enum unibi_string i = unibi_string_begin_ + 1;
       i < unibi_string_end_; i++) {
    const char *s = unibi_get_str(ut, i);
    if (s) {
      msg_printf_attr(0, "  %-25s %-10s = ", unibi_name_str(i),
                      unibi_short_name_str(i));
      // Most of these strings will contain escape sequences.
      msg_outtrans_special((char_u *)s, false);
      msg_putchar('\n');
    }
  }

  if (unibi_count_ext_bool(ut)) {
    msg_puts("Extended boolean capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_bool(ut); i++) {
      msg_printf_attr(0, "  %-25s = %s\n",
                      unibi_get_ext_bool_name(ut, i),
                      unibi_get_ext_bool(ut, i) ? "true" : "false");
    }
  }

  if (unibi_count_ext_num(ut)) {
    msg_puts("Extended numeric capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_num(ut); i++) {
      msg_printf_attr(0, "  %-25s = %hd\n",
                      unibi_get_ext_num_name(ut, i),
                      unibi_get_ext_num(ut, i));
    }
  }

  if (unibi_count_ext_str(ut)) {
    msg_puts("Extended string capabilities:\n");
    for (size_t i = 0; i < unibi_count_ext_str(ut); i++) {
      msg_printf_attr(0, "  %-25s = ", unibi_get_ext_str_name(ut, i));
      msg_outtrans_special((char_u *)unibi_get_ext_str(ut, i), false);
      msg_putchar('\n');
    }
  }

  msg_puts("}}}\n");
  xfree(term);
}
