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

    if (eap->forceit && *arg == NUL && !curbuf->b_help) {
      emsg(_("E478: Don't panic!"));
      return;
    }

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

  // When no argument given go to the index.
  if (*arg == NUL) {
    arg = "help.txt";
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
      semsg(_("E661: Sorry, no '%s' help for %s"), lang, arg);
    } else {
      semsg(_("E149: Sorry, no help for %s"), arg);
    }
    if (n != FAIL) {
      FreeWild(num_matches, matches);
    }
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
        smsg(0, _("Sorry, help file \"%s\" not found"), p_hf);
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

  do_tag(tag, DT_HELP, 1, false, true);

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
  Error err = ERROR_INIT;
  MAXSIZE_TEMP_ARRAY(args, 1);

  ADD_C(args, CSTR_AS_OBJ(arg));

  Object res = NLUA_EXEC_STATIC("return require'vim._core.help'.escape_subject(...)",
                                args, kRetObject, NULL, &err);

  if (ERROR_SET(&err)) {
    emsg_multiline(err.msg, "lua_error", HLF_E, true);
    api_clear_error(&err);
    return FAIL;
  }
  api_clear_error(&err);

  assert(res.type == kObjectTypeString);
  xstrlcpy(IObuff, res.data.string.data, sizeof(IObuff));
  api_free_object(res);

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
  Error err = ERROR_INIT;
  Object res = NLUA_EXEC_STATIC("return require'vim._core.help'.local_additions()",
                                (Array)ARRAY_DICT_INIT, kRetNilBool, NULL, &err);
  if (ERROR_SET(&err)) {
    emsg_multiline(err.msg, "lua_error", HLF_E, true);
  }
  api_free_object(res);
  api_clear_error(&err);
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

/// Generate tags in one help directory
///
/// @param dir  Path to the doc directory
/// @param ext  Suffix of the help files (".txt", ".itx", ".frx", etc.)
/// @param tagname  Name of the tags file ("tags" for English, "tags-fr" for
///                 French)
/// @param add_help_tags  Whether to add the "help-tags" tag
/// @param ignore_writeerr  ignore write error
static void helptags_one(char *dir, const char *ext, const char *tagfname, bool add_help_tags,
                         bool ignore_writeerr)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T ga;
  int filecount;
  char **files;
  char *s;

  // Find all *.txt files.
  size_t dirlen = xstrlcpy(NameBuff, dir, sizeof(NameBuff));
  if (dirlen >= MAXPATHL
      || xstrlcat(NameBuff, "/**/*", sizeof(NameBuff)) >= MAXPATHL  // NOLINT
      || xstrlcat(NameBuff, ext, sizeof(NameBuff)) >= MAXPATHL) {
    emsg(_(e_fnametoolong));
    return;
  }

  // Note: We cannot just do `&NameBuff` because it is a statically sized array
  //       so `NameBuff == &NameBuff` according to C semantics.
  char *buff_list[1] = { NameBuff };
  const int res = gen_expand_wildcards(1, buff_list, &filecount, &files,
                                       EW_FILE|EW_SILENT);
  if (res == FAIL || filecount == 0) {
    if (!got_int) {
      semsg(_("E151: No match: %s"), NameBuff);
    }
    if (res != FAIL) {
      FreeWild(filecount, files);
    }
    return;
  }

  // Open the tags file for writing.
  // Do this before scanning through all the files.
  memcpy(NameBuff, dir, dirlen + 1);
  if (!add_pathsep(NameBuff)
      || xstrlcat(NameBuff, tagfname, sizeof(NameBuff)) >= MAXPATHL) {
    emsg(_(e_fnametoolong));
    return;
  }

  FILE *const fd_tags = os_fopen(NameBuff, "w");
  if (fd_tags == NULL) {
    if (!ignore_writeerr) {
      semsg(_("E152: Cannot open %s for writing"), NameBuff);
    }
    FreeWild(filecount, files);
    return;
  }

  // If using the "++t" argument or generating tags for "$VIMRUNTIME/doc"
  // add the "help-tags" tag.
  ga_init(&ga, (int)sizeof(char *), 100);
  if (add_help_tags
      || path_full_compare("$VIMRUNTIME/doc", dir, false, true) == kEqualFiles) {
    size_t s_len = 18 + strlen(tagfname);
    s = xmalloc(s_len);
    snprintf(s, s_len, "help-tags\t%s\t1\n", tagfname);
    GA_APPEND(char *, &ga, s);
  }

  // Go over all the files and extract the tags.
  for (int fi = 0; fi < filecount && !got_int; fi++) {
    FILE *const fd = os_fopen(files[fi], "r");
    if (fd == NULL) {
      semsg(_("E153: Unable to open %s for reading"), files[fi]);
      continue;
    }
    const char *const fname = files[fi] + dirlen + 1;

    bool in_example = false;
    while (!vim_fgets(IObuff, IOSIZE, fd) && !got_int) {
      if (in_example) {
        // skip over example; a non-white in the first column ends it
        if (vim_strchr(" \t\n\r", (uint8_t)IObuff[0])) {
          continue;
        }
        in_example = false;
      }
      char *p1 = vim_strchr(IObuff, '*');       // find first '*'
      while (p1 != NULL) {
        char *p2 = strchr(p1 + 1, '*');  // Find second '*'.
        if (p2 != NULL && p2 > p1 + 1) {         // Skip "*" and "**".
          for (s = p1 + 1; s < p2; s++) {
            if (*s == ' ' || *s == '\t' || *s == '|') {
              break;
            }
          }

          // Only accept a *tag* when it consists of valid
          // characters, there is white space before it and is
          // followed by a white character or end-of-line.
          if (s == p2
              && (p1 == IObuff || p1[-1] == ' ' || p1[-1] == '\t')
              && (vim_strchr(" \t\n\r", (uint8_t)s[1]) != NULL
                  || s[1] == NUL)) {
            *p2 = NUL;
            p1++;
            size_t s_len = (size_t)(p2 - p1) + strlen(fname) + 2;
            s = xmalloc(s_len);
            GA_APPEND(char *, &ga, s);
            snprintf(s, s_len, "%s\t%s", p1, fname);

            // find next '*'
            p2 = vim_strchr(p2 + 1, '*');
          }
        }
        p1 = p2;
      }
      size_t off = strlen(IObuff);
      if (off >= 2 && IObuff[off - 1] == '\n') {
        off -= 2;
        while (off > 0 && (ASCII_ISLOWER(IObuff[off]) || ascii_isdigit(IObuff[off]))) {
          off--;
        }
        if (IObuff[off] == '>' && (off == 0 || IObuff[off - 1] == ' ')) {
          in_example = true;
        }
      }
      line_breakcheck();
    }

    fclose(fd);
  }

  FreeWild(filecount, files);

  if (!got_int && ga.ga_data != NULL) {
    // Sort the tags.
    sort_strings(ga.ga_data, ga.ga_len);

    // Check for duplicates.
    for (int i = 1; i < ga.ga_len; i++) {
      char *p1 = ((char **)ga.ga_data)[i - 1];
      char *p2 = ((char **)ga.ga_data)[i];
      while (*p1 == *p2) {
        if (*p2 == '\t') {
          *p2 = NUL;
          vim_snprintf(NameBuff, MAXPATHL,
                       _("E154: Duplicate tag \"%s\" in file %s/%s"),
                       ((char **)ga.ga_data)[i], dir, p2 + 1);
          emsg(NameBuff);
          *p2 = '\t';
          break;
        }
        p1++;
        p2++;
      }
    }

    // Write the tags into the file.
    for (int i = 0; i < ga.ga_len; i++) {
      s = ((char **)ga.ga_data)[i];
      if (strncmp(s, "help-tags\t", 10) == 0) {
        // help-tags entry was added in formatted form
        fputs(s, fd_tags);
      } else {
        fprintf(fd_tags, "%s\t/" "*", s);
        for (char *p1 = s; *p1 != '\t'; p1++) {
          // insert backslash before '\\' and '/'
          if (*p1 == '\\' || *p1 == '/') {
            putc('\\', fd_tags);
          }
          putc(*p1, fd_tags);
        }
        fprintf(fd_tags, "*\n");
      }
    }
  }

  GA_DEEP_CLEAR_PTR(&ga);
  fclose(fd_tags);          // there is no check for an error...
}

/// Generate tags in one help directory, taking care of translations.
static void do_helptags(char *dirname, bool add_help_tags, bool ignore_writeerr)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T ga;
  char lang[2];
  char ext[5];
  char fname[8];
  int filecount;
  char **files;

  // Get a list of all files in the help directory and in subdirectories.
  xstrlcpy(NameBuff, dirname, sizeof(NameBuff));
  if (!add_pathsep(NameBuff)
      || xstrlcat(NameBuff, "**", sizeof(NameBuff)) >= MAXPATHL) {
    emsg(_(e_fnametoolong));
    return;
  }

  // Note: We cannot just do `&NameBuff` because it is a statically sized array
  //       so `NameBuff == &NameBuff` according to C semantics.
  char *buff_list[1] = { NameBuff };
  if (gen_expand_wildcards(1, buff_list, &filecount, &files,
                           EW_FILE|EW_SILENT) == FAIL
      || filecount == 0) {
    semsg(_("E151: No match: %s"), NameBuff);
    return;
  }

  // Go over all files in the directory to find out what languages are
  // present.
  int j;
  ga_init(&ga, 1, 10);
  for (int i = 0; i < filecount; i++) {
    int len = (int)strlen(files[i]);
    if (len <= 4) {
      continue;
    }

    if (STRICMP(files[i] + len - 4, ".txt") == 0) {
      // ".txt" -> language "en"
      lang[0] = 'e';
      lang[1] = 'n';
    } else if (files[i][len - 4] == '.'
               && ASCII_ISALPHA(files[i][len - 3])
               && ASCII_ISALPHA(files[i][len - 2])
               && TOLOWER_ASC(files[i][len - 1]) == 'x') {
      // ".abx" -> language "ab"
      lang[0] = (char)TOLOWER_ASC(files[i][len - 3]);
      lang[1] = (char)TOLOWER_ASC(files[i][len - 2]);
    } else {
      continue;
    }

    // Did we find this language already?
    for (j = 0; j < ga.ga_len; j += 2) {
      if (strncmp(lang, ((char *)ga.ga_data) + j, 2) == 0) {
        break;
      }
    }
    if (j == ga.ga_len) {
      // New language, add it.
      ga_grow(&ga, 2);
      ((char *)ga.ga_data)[ga.ga_len++] = lang[0];
      ((char *)ga.ga_data)[ga.ga_len++] = lang[1];
    }
  }

  // Loop over the found languages to generate a tags file for each one.
  for (j = 0; j < ga.ga_len; j += 2) {
    STRCPY(fname, "tags-xx");
    fname[5] = ((char *)ga.ga_data)[j];
    fname[6] = ((char *)ga.ga_data)[j + 1];
    if (fname[5] == 'e' && fname[6] == 'n') {
      // English is an exception: use ".txt" and "tags".
      fname[4] = NUL;
      STRCPY(ext, ".txt");
    } else {
      // Language "ab" uses ".abx" and "tags-ab".
      STRCPY(ext, ".xxx");
      ext[1] = fname[5];
      ext[2] = fname[6];
    }
    helptags_one(dirname, ext, fname, add_help_tags, ignore_writeerr);
  }

  ga_clear(&ga);
  FreeWild(filecount, files);
}

static bool helptags_cb(int num_fnames, char **fnames, bool all, void *cookie)
  FUNC_ATTR_NONNULL_ALL
{
  for (int i = 0; i < num_fnames; i++) {
    do_helptags(fnames[i], *(bool *)cookie, true);
    if (!all) {
      return true;
    }
  }

  return num_fnames > 0;
}

/// ":helptags"
void ex_helptags(exarg_T *eap)
{
  expand_T xpc;
  bool add_help_tags = false;

  // Check for ":helptags ++t {dir}".
  if (strncmp(eap->arg, "++t", 3) == 0 && ascii_iswhite(eap->arg[3])) {
    add_help_tags = true;
    eap->arg = skipwhite(eap->arg + 3);
  }

  if (strcmp(eap->arg, "ALL") == 0) {
    do_in_path(p_rtp, "", "doc", DIP_ALL + DIP_DIR, helptags_cb, &add_help_tags);
  } else {
    ExpandInit(&xpc);
    xpc.xp_context = EXPAND_DIRECTORIES;
    char *dirname =
      ExpandOne(&xpc, eap->arg, NULL, WILD_LIST_NOTFOUND|WILD_SILENT, WILD_EXPAND_FREE);
    if (dirname == NULL || !os_isdir(dirname)) {
      semsg(_("E150: Not a directory: %s"), eap->arg);
    } else {
      do_helptags(dirname, add_help_tags, false);
    }
    xfree(dirname);
  }
}
