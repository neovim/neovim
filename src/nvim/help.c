// help.c: functions for Vim help

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/extmark_defs.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/help.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#include "help.c.generated.h"

/// ":help": open a read-only window on a help file
/// ":help!": DWIM parse the best match at cursor
void ex_help(exarg_T *eap)
{
  char *arg;
  FILE *helpfd;          // file descriptor of help file
  win_T *wp;
  int num_matches;
  char **matches;
  int empty_fnum = 0;
  int alt_fnum = 0;
  const bool old_KeyTyped = KeyTyped;

  if (eap != NULL) {
    // A ":help" command ends at the first LF, or at a '|' that is
    // followed by some text.  Set nextcmd to the following command.
    for (arg = eap->arg; *arg; arg++) {
      if (*arg == '\n' || *arg == '\r'
          || (*arg == '|' && arg[1] != NUL && arg[1] != '|')) {
        *arg++ = NUL;
        eap->nextcmd = arg;
        break;
      }
    }
    arg = eap->arg;

    if (eap->skip) {        // not executing commands
      return;
    }
  } else {
    arg = "";
  }

  // remove trailing blanks
  char *p = arg + strlen(arg) - 1;
  while (p > arg && ascii_iswhite(*p) && p[-1] != '\\') {
    *p-- = NUL;
  }

  // Check for a specified language
  char *lang = check_help_lang(arg);

  // ":help!" (bang, no args).
  bool helpbang = (eap != NULL && eap->forceit && *arg == NUL);

  // When no argument given go to the index.
  if (*arg == NUL && !helpbang) {
    arg = "help.txt";
  }

  // ":help!" (bang, no args): DWIM help, resolve best tag at cursor via Lua.
  char *allocated_arg = NULL;
  if (helpbang) {
    typval_T no_args[] = { { .v_type = VAR_UNKNOWN } };
    typval_T rettv;
    nlua_call_typval("vim._core.help", "resolve_tag", no_args, &rettv);
    if (rettv.v_type == VAR_STRING && rettv.vval.v_string != NULL && *rettv.vval.v_string != NUL) {
      allocated_arg = rettv.vval.v_string;  // takes ownership
      arg = allocated_arg;
    } else {
      tv_clear(&rettv);
      emsg(_(e_noident));
      return;
    }
  }

  // Check if there is a match for the argument.
  int n = find_help_tags(arg, &num_matches, &matches, eap != NULL && eap->forceit);

  int i = 0;
  if (n != FAIL && lang != NULL) {
    // Find first item with the requested language.
    for (i = 0; i < num_matches; i++) {
      int len = (int)strlen(matches[i]);
      if (len > 3 && matches[i][len - 3] == '@'
          && STRICMP(matches[i] + len - 2, lang) == 0) {
        break;
      }
    }
  }
  if (i >= num_matches || n == FAIL) {
    if (lang != NULL) {
      semsg(_("E661: No '%s' help for %s"), lang, arg);
    } else {
      semsg(_("E149: No help for %s"), arg);
    }
    if (n != FAIL) {
      FreeWild(num_matches, matches);
    }
    xfree(allocated_arg);
    return;
  }

  // The first match (in the requested language) is the best match.
  char *tag = xstrdup(matches[i]);
  FreeWild(num_matches, matches);

  // Re-use an existing help window or open a new one.
  // Always open a new one for ":tab help".
  if (!bt_help(curwin->w_buffer) || cmdmod.cmod_tab != 0) {
    if (cmdmod.cmod_tab != 0) {
      wp = NULL;
    } else {
      wp = NULL;
      FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
        if (bt_help(wp2->w_buffer) && !wp2->w_config.hide && wp2->w_config.focusable) {
          wp = wp2;
          break;
        }
      }
    }
    if (wp != NULL && wp->w_buffer->b_nwindows > 0) {
      win_enter(wp, true);
    } else {
      // There is no help window yet.
      // Try to open the file specified by the "helpfile" option.
      if ((helpfd = os_fopen(p_hf, READBIN)) == NULL) {
        smsg(0, _("Help file \"%s\" not found"), p_hf);
        goto erret;
      }
      fclose(helpfd);

      // Split off help window; put it at far top if no position
      // specified, the current window is vertically split and
      // narrow.
      n = WSP_HELP;
      if (cmdmod.cmod_split == 0 && curwin->w_width != Columns
          && curwin->w_width < 80) {
        n |= p_sb ? WSP_BOT : WSP_TOP;
      }
      if (win_split(0, n) == FAIL) {
        goto erret;
      }

      if (curwin->w_height < p_hh) {
        win_setheight((int)p_hh);
      }

      // Open help file (do_ecmd() will set b_help flag, readfile() will
      // set b_p_ro flag).
      // Set the alternate file to the previously edited file.
      alt_fnum = curbuf->b_fnum;
      do_ecmd(0, NULL, NULL, NULL, ECMD_LASTL,
              ECMD_HIDE + ECMD_SET_HELP,
              NULL);  // buffer is still open, don't store info

      if ((cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
        curwin->w_alt_fnum = alt_fnum;
      }
      empty_fnum = curbuf->b_fnum;
    }
  }

  restart_edit = 0;               // don't want insert mode in help file

  // Restore KeyTyped, setting 'filetype=help' may reset it.
  // It is needed for do_tag top open folds under the cursor.
  KeyTyped = old_KeyTyped;

  do_tag(NULL, tag, DT_HELP, 1, false, true);

  // Delete the empty buffer if we're not using it.  Careful: autocommands
  // may have jumped to another window, check that the buffer is not in a
  // window.
  if (empty_fnum != 0 && curbuf->b_fnum != empty_fnum) {
    buf_T *buf = buflist_findnr(empty_fnum);
    if (buf != NULL && buf->b_nwindows == 0) {
      wipe_buffer(buf, true);
    }
  }

  // keep the previous alternate file
  if (alt_fnum != 0 && curwin->w_alt_fnum == empty_fnum
      && (cmdmod.cmod_flags & CMOD_KEEPALT) == 0) {
    curwin->w_alt_fnum = alt_fnum;
  }

erret:
  xfree(tag);
  xfree(allocated_arg);
}

/// ":helpclose": Close one help window
void ex_helpclose(exarg_T *eap)
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (bt_help(win->w_buffer)) {
      win_close(win, false, eap->forceit);
      return;
    }
  }
}

/// In an argument search for a language specifiers in the form "@xx".
/// Changes the "@" to NUL if found, and returns a pointer to "xx".
///
/// @return  NULL if not found.
char *check_help_lang(char *arg)
{
  int len = (int)strlen(arg);

  if (len >= 3 && arg[len - 3] == '@' && ASCII_ISALPHA(arg[len - 2])
      && ASCII_ISALPHA(arg[len - 1])) {
    arg[len - 3] = NUL;                 // remove the '@'
    return arg + len - 2;
  }
  return NULL;
}

/// Return a heuristic indicating how well the given string matches.  The
/// smaller the number, the better the match.  This is the order of priorities,
/// from best match to worst match:
///      - Match with least alphanumeric characters is better.
///      - Match with least total characters is better.
///      - Match towards the start is better.
///      - Match starting with "+" is worse (feature instead of command)
/// Assumption is made that the matched_string passed has already been found to
/// match some string for which help is requested.  webb.
///
/// @param offset      offset for match
/// @param wrong_case  no matching case
///
/// @return  a heuristic indicating how well the given string matches.
int help_heuristic(char *matched_string, int offset, bool wrong_case)
  FUNC_ATTR_PURE
{
  int num_letters = 0;
  for (char *p = matched_string; *p; p++) {
    if (ASCII_ISALNUM(*p)) {
      num_letters++;
    }
  }

  // Multiply the number of letters by 100 to give it a much bigger
  // weighting than the number of characters.
  // If there only is a match while ignoring case, add 5000.
  // If the match starts in the middle of a word, add 10000 to put it
  // somewhere in the last half.
  // If the match is more than 2 chars from the start, multiply by 200 to
  // put it after matches at the start.
  if (offset > 0
      && ASCII_ISALNUM(matched_string[offset])
      && ASCII_ISALNUM(matched_string[offset - 1])) {
    offset += 10000;
  } else if (offset > 2) {
    offset *= 200;
  }
  if (wrong_case) {
    offset += 5000;
  }
  // Features are less interesting than the subjects themselves, but "+"
  // alone is not a feature.
  if (matched_string[0] == '+' && matched_string[1] != NUL) {
    offset += 100;
  }
  return 100 * num_letters + (int)strlen(matched_string) + offset;
}

/// Compare functions for qsort() below, that checks the help heuristics number
/// that has been put after the tagname by find_tags().
static int help_compare(const void *s1, const void *s2)
{
  char *p1 = *(char **)s1 + strlen(*(char **)s1) + 1;
  char *p2 = *(char **)s2 + strlen(*(char **)s2) + 1;

  // Compare by help heuristic number first.
  int cmp = strcmp(p1, p2);
  if (cmp != 0) {
    return cmp;
  }

  // Compare by strings as tie-breaker when same heuristic number.
  return strcmp(*(char **)s1, *(char **)s2);
}

/// Find all help tags matching "arg", sort them and return in matches[], with
/// the number of matches in num_matches.
/// The matches will be sorted with a "best" match algorithm.
/// When "keep_lang" is true try keeping the language of the current buffer.
int find_help_tags(const char *arg, int *num_matches, char ***matches, bool keep_lang)
{
  typval_T tv_args[] = {
    { .v_type = VAR_STRING, .vval.v_string = (char *)arg },
    { .v_type = VAR_UNKNOWN },
  };
  typval_T rettv;
  nlua_call_typval("vim._core.help", "escape_subject", tv_args, &rettv);
  if (rettv.v_type != VAR_STRING || rettv.vval.v_string == NULL) {
    tv_clear(&rettv);
    return FAIL;
  }
  xstrlcpy(IObuff, rettv.vval.v_string, sizeof(IObuff));
  tv_clear(&rettv);

  *matches = NULL;
  *num_matches = 0;
  int flags = TAG_HELP | TAG_REGEXP | TAG_NAMES | TAG_VERBOSE | TAG_NO_TAGFUNC;
  if (keep_lang) {
    flags |= TAG_KEEP_LANG;
  }
  if (find_tags(IObuff, num_matches, matches, flags, MAXCOL, NULL) == OK
      && *num_matches > 0) {
    // Sort the matches found on the heuristic number that is after the
    // tag name.
    qsort((void *)(*matches), (size_t)(*num_matches),
          sizeof(char *), help_compare);
    // Delete more than TAG_MANY to reduce the size of the listing.
    while (*num_matches > TAG_MANY) {
      xfree((*matches)[--*num_matches]);
    }
  }
  return OK;
}

/// Cleanup matches for help tags:
/// Remove "@ab" if the top of 'helplang' is "ab" and the language of the first
/// tag matches it.  Otherwise remove "@en" if "en" is the only language.
void cleanup_help_tags(int num_file, char **file)
{
  char buf[4];
  char *p = buf;

  if (p_hlg[0] != NUL && (p_hlg[0] != 'e' || p_hlg[1] != 'n')) {
    *p++ = '@';
    *p++ = p_hlg[0];
    *p++ = p_hlg[1];
  }
  *p = NUL;

  for (int i = 0; i < num_file; i++) {
    int len = (int)strlen(file[i]) - 3;
    if (len <= 0) {
      continue;
    }
    if (strcmp(file[i] + len, "@en") == 0) {
      // Sorting on priority means the same item in another language may
      // be anywhere.  Search all items for a match up to the "@en".
      int j;
      for (j = 0; j < num_file; j++) {
        if (j != i
            && (int)strlen(file[j]) == len + 3
            && strncmp(file[i], file[j], (size_t)len + 1) == 0) {
          break;
        }
      }
      if (j == num_file) {
        // item only exists with @en, remove it
        file[i][len] = NUL;
      }
    }
  }

  if (*buf != NUL) {
    for (int i = 0; i < num_file; i++) {
      int len = (int)strlen(file[i]) - 3;
      if (len <= 0) {
        continue;
      }
      if (strcmp(file[i] + len, buf) == 0) {
        // remove the default language
        file[i][len] = NUL;
      }
    }
  }
}

/// Called when starting to edit a buffer for a help file.
void prepare_help_buffer(void)
{
  curbuf->b_help = true;
  set_option_direct(kOptBuftype, STATIC_CSTR_AS_OPTVAL("help"), OPT_LOCAL, 0);

  // Always set these options after jumping to a help tag, because the
  // user may have an autocommand that gets in the way.
  // Accept all ASCII chars for keywords, except ' ', '*', '"', '|', and
  // latin1 word characters (for translated help files).
  // Only set it when needed, buf_init_chartab() is some work.
  char *p = "!-~,^*,^|,^\",192-255";
  if (strcmp(curbuf->b_p_isk, p) != 0) {
    set_option_direct(kOptIskeyword, CSTR_AS_OPTVAL(p), OPT_LOCAL, 0);
    check_buf_options(curbuf);
    buf_init_chartab(curbuf, false);
  }

  // Don't use the global foldmethod.
  set_option_direct(kOptFoldmethod, STATIC_CSTR_AS_OPTVAL("manual"), OPT_LOCAL, 0);

  curbuf->b_p_ts = 8;         // 'tabstop' is 8.
  curwin->w_p_list = false;   // No list mode.

  curbuf->b_p_ma = false;     // Not modifiable.
  curbuf->b_p_bin = false;    // Reset 'bin' before reading file.
  curwin->w_p_nu = 0;         // No line numbers.
  curwin->w_p_rnu = 0;        // No relative line numbers.
  RESET_BINDING(curwin);      // No scroll or cursor binding.
  curwin->w_p_arab = false;   // No arabic mode.
  curwin->w_p_rl = false;     // Help window is left-to-right.
  curwin->w_p_fen = false;    // No folding in the help window.
  curwin->w_p_diff = false;   // No 'diff'.
  curwin->w_p_spell = false;  // No spell checking.

  set_buflisted(false);
}

/// Populate *local-additions* in help.txt
void get_local_additions(void)
{
  typval_T no_args[] = { { .v_type = VAR_UNKNOWN } };
  nlua_call_typval("vim._core.help", "local_additions", no_args, NULL);
}

/// ":exusage"
void ex_exusage(exarg_T *eap)
{
  do_cmdline_cmd("help ex-cmd-index");
}

/// ":viusage"
void ex_viusage(exarg_T *eap)
{
  do_cmdline_cmd("help normal-index");
}

/// ":helptags"
void ex_helptags(exarg_T *eap)
{
  bool add_help_tags = false;

  // Check for ++t in ":helptags ++t {dir}".
  if (strncmp(eap->arg, "++t", 3) == 0 && ascii_iswhite(eap->arg[3])) {
    add_help_tags = true;
    eap->arg = skipwhite(eap->arg + 3);
  }

  MAXSIZE_TEMP_ARRAY(args, 2);

  bool is_all = strcmp(eap->arg, "ALL") == 0;
  ADD_C(args, is_all ? NIL : CSTR_AS_OBJ(eap->arg));

  ADD_C(args, BOOLEAN_OBJ(add_help_tags));

  Error err = ERROR_INIT;
  NLUA_EXEC_STATIC("require('vim._core.help').gen_tags(...)", args,
                   kRetNilBool, NULL, &err);

  if (ERROR_SET(&err)) {
    emsg(err.msg);
  }
}
