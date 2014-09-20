#include <stdbool.h>
#include <errno.h>
#include <string.h>
#include <inttypes.h>

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/globals.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/path.h"
#include "nvim/memory.h"
#include "nvim/undo.h"
#include "nvim/misc1.h"

#include "nvim/title.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "title.c.generated.h"
#endif


// Manage the

static char_u *lasttitle = NULL;
static char_u *lasticon = NULL;

static int build_title(void);
static void build_default_title(char_u *buf, int maxlen);
static void build_as_stl(char_u *out, size_t outlen, char_u *fmt, int maxwidth, char *setting);
static int build_icon(void);
static void build_default_icon(char_u *i_str);
static int should_update_title(char_u *str, char_u **last);

# if defined(EXITFREE) || defined(PROTO)
void free_titles(void)
{
  free(lasttitle);
  free(lasticon);
}
# endif

// Put current window title back using lasttitle
// & lasticon (used after calling a shell)
void force_update_title(void)
{
  mch_settitle(lasttitle, lasticon);
}

// Rebuild title and icon from current settings,
// redrawing if any changes occured
void maketitle(void)
{
  int need_redraw;

  if (!redrawing()) {
    // Postpone updating the title when 'lazyredraw' is set.
    need_maketitle = true;
    return;
  }

  need_maketitle = false;
  need_redraw = false;
  need_redraw |= build_title();
  need_redraw |= build_icon();

  if (need_redraw) {
    force_update_title();
  }
}

// Build title and place it into lasttitle,
// if lasttitle is changed return true, otherwise false
static int build_title(void)
{
  char_u *t_str = NULL;
  int maxlen = 0;
  char_u buf[IOSIZE];

  if (!p_title && lasttitle == NULL)
    return false;

  if (p_title) {
    if (p_titlelen > 0) {
      maxlen = (int)p_titlelen * (int)Columns / 100;
      if (maxlen < 10) {
        maxlen = 10;
      }
    }

    t_str = buf;
    if (*p_titlestring != NUL) {
      if (stl_syntax & STL_IN_TITLE) {
        build_as_stl(t_str, sizeof(buf), p_titlestring, maxlen, "titlestring");
      } else {
        t_str = p_titlestring;
      }
    } else {
      build_default_title(t_str, maxlen);
    }
  }

  return should_update_title(t_str, &lasttitle);
}

// Build a title into buf with the format:
// "fname + (path) (1 of 2) - VIM"
static void build_default_title(char_u *buf, int maxlen)
{
  char_u *p;
  int off;

#define SPACE_FOR_FNAME (IOSIZE - 100)
#define SPACE_FOR_DIR   (IOSIZE - 20)
#define SPACE_FOR_ARGNR (IOSIZE - 10)  // at least room for " - VIM"
  if (curbuf->b_fname == NULL) {
    STRLCPY(buf, _("[No Name]"), SPACE_FOR_FNAME + 1);
  } else {
    p = transstr(path_tail(curbuf->b_fname));
    STRLCPY(buf, p, SPACE_FOR_FNAME + 1);
    free(p);
  }

  switch (bufIsChanged(curbuf)
      + (curbuf->b_p_ro * 2)
      + (!curbuf->b_p_ma * 4)) {
    case 1: STRCAT(buf, " +"); break;
    case 2: STRCAT(buf, " ="); break;
    case 3: STRCAT(buf, " =+"); break;
    case 4:
    case 6: STRCAT(buf, " -"); break;
    case 5:
    case 7: STRCAT(buf, " -+"); break;
  }

  if (curbuf->b_fname != NULL) {
    // Get path of file, replace home dir with ~
    off = (int)STRLEN(buf);
    buf[off++] = ' ';
    buf[off++] = '(';
    home_replace(curbuf, curbuf->b_ffname,
        buf + off, SPACE_FOR_DIR - off, true);
#ifdef BACKSLASH_IN_FILENAME
    // avoid "c:/name" to be reduced to "c"
    if (isalpha(buf[off]) && buf[off + 1] == ':')
      off += 2;
#endif
    // remove the file name
    p = path_tail_with_sep(buf + off);
    if (p == buf + off) {
      // must be a help buffer
      STRLCPY(buf + off, _("help"), SPACE_FOR_DIR - off);
    } else {
      *p = NUL;
    }

    // Translate unprintable chars and concatenate.  Keep some
    // room for the server name.  When there is no room (very long
    // file name) use (...).
    if (off < SPACE_FOR_DIR) {
      p = transstr(buf + off);
      STRLCPY(buf + off, p, SPACE_FOR_DIR - off + 1);
      free(p);
    } else {
      STRLCPY(buf + off, "...", SPACE_FOR_ARGNR - off + 1);
    }
    STRCAT(buf, ")");
  }

  append_arg_number(curwin, buf, SPACE_FOR_ARGNR, false);

  STRCAT(buf, " - VIM");

  if (maxlen > 0) {
    // make it shorter by removing a bit in the middle
    if (vim_strsize(buf) > maxlen) {
      trunc_string(buf, buf, maxlen, IOSIZE);
    }
  }
}

// Build title or icon using a statusline format, using
// a sandbox if the setting was set insecurely
static void build_as_stl(
    char_u *out,
    size_t outlen,
    char_u *fmt,
    int maxwidth,
    char *setting
)
{
  int use_sandbox = false;
  int save_called_emsg = called_emsg;

  use_sandbox = was_set_insecurely((char_u *)setting, 0);
  called_emsg = false;
  build_stl_str_hl(curwin, out, outlen, fmt,
      use_sandbox, 0, maxwidth, NULL, NULL);
  if (called_emsg) {
    set_string_option_direct((char_u *)setting, -1,
        (char_u *)"", OPT_FREE, SID_ERROR);
  }
  called_emsg |= save_called_emsg;
}

// Build icon and place it into lasticon,
// if lasticon is changed return true, otherwise false
static int build_icon(void)
{
  char_u *i_str = NULL;
  char_u buf[IOSIZE];

  if (p_icon) {
    i_str = buf;
    if (*p_iconstring != NUL) {
      if (stl_syntax & STL_IN_ICON) {
        build_as_stl(i_str, sizeof(buf), p_iconstring, 0, "iconstring");
      } else {
        i_str = p_iconstring;
      }
    } else {
      build_default_icon(i_str);
    }
    return should_update_title(i_str, &lasticon);
  }

  return false;
}

// Build an icon from the current buffer's special name
// or filename, trucating at 100 bytes
static void build_default_icon(char_u *i_str)
{
  int len;
  char_u *i_name;

  if (buf_spname(curbuf) != NULL) {
    i_name = buf_spname(curbuf);
  } else {                        /* use file name only in icon */
    i_name = path_tail(curbuf->b_ffname);
  }
  *i_str = NUL;
  /* Truncate name at 100 bytes. */
  len = (int)STRLEN(i_name);
  if (len > 100) {
    len -= 100;
    if (has_mbyte) {
      len += (*mb_tail_off)(i_name, i_name + len) + 1;
    }
    i_name += len;
  }
  STRCPY(i_str, i_name);
  trans_characters(i_str, IOSIZE);
}

static int should_update_title(char_u *str, char_u **last)
{
  if ((str == NULL) != (*last == NULL)
      || (str != NULL && *last != NULL && STRCMP(str, *last) != 0)) {
    free(*last);
    if (str == NULL) {
      *last = NULL;
    } else {
      *last = vim_strsave(str);
    }
    return true;
  }
  return false;
}
