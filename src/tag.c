/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * Code to handle tags and the tag stack
 */

#include "vim.h"
#include "tag.h"
#include "buffer.h"
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "if_cscope.h"
#include "mark.h"
#include "mbyte.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "file_search.h"
#include "garray.h"
#include "move.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "term.h"
#include "ui.h"
#include "window.h"

/*
 * Structure to hold pointers to various items in a tag line.
 */
typedef struct tag_pointers {
  /* filled in by parse_tag_line(): */
  char_u      *tagname;         /* start of tag name (skip "file:") */
  char_u      *tagname_end;     /* char after tag name */
  char_u      *fname;           /* first char of file name */
  char_u      *fname_end;       /* char after file name */
  char_u      *command;         /* first char of command */
  /* filled in by parse_match(): */
  char_u      *command_end;     /* first char after command */
  char_u      *tag_fname;       /* file name of the tags file */
  char_u      *tagkind;         /* "kind:" value */
  char_u      *tagkind_end;     /* end of tagkind */
} tagptrs_T;

/*
 * The matching tags are first stored in ga_match[].  In which one depends on
 * the priority of the match.
 * At the end, the matches from ga_match[] are concatenated, to make a list
 * sorted on priority.
 */
#define MT_ST_CUR       0               /* static match in current file */
#define MT_GL_CUR       1               /* global match in current file */
#define MT_GL_OTH       2               /* global match in other file */
#define MT_ST_OTH       3               /* static match in other file */
#define MT_IC_ST_CUR    4               /* icase static match in current file */
#define MT_IC_GL_CUR    5               /* icase global match in current file */
#define MT_IC_GL_OTH    6               /* icase global match in other file */
#define MT_IC_ST_OTH    7               /* icase static match in other file */
#define MT_IC_OFF       4               /* add for icase match */
#define MT_RE_OFF       8               /* add for regexp match */
#define MT_MASK         7               /* mask for printing priority */
#define MT_COUNT        16

static char     *mt_names[MT_COUNT/2] =
{"FSC", "F C", "F  ", "FS ", " SC", "  C", "   ", " S "};

#define NOTAGFILE       99              /* return value for jumpto_tag */
static char_u   *nofile_fname = NULL;   /* fname for NOTAGFILE error */

static void taglen_advance(int l);

static int jumpto_tag(char_u *lbuf, int forceit, int keep_help);
static int parse_tag_line(char_u *lbuf, tagptrs_T *tagp);
static int test_for_static(tagptrs_T *);
static int parse_match(char_u *lbuf, tagptrs_T *tagp);
static char_u *tag_full_fname(tagptrs_T *tagp);
static char_u *expand_tag_fname(char_u *fname, char_u *tag_fname,
                                int expand);
static int test_for_current(char_u *, char_u *, char_u *, char_u *);
static int find_extra(char_u **pp);

static char_u *bottommsg = (char_u *)N_("E555: at bottom of tag stack");
static char_u *topmsg = (char_u *)N_("E556: at top of tag stack");

static char_u   *tagmatchname = NULL;   /* name of last used tag */

/*
 * We use ftello() here, if available.  It returns off_t instead of long,
 * which helps if long is 32 bit and off_t is 64 bit.
 * We assume that when fseeko() is available then ftello() is too.
 */
#ifdef HAVE_FSEEKO
# define ftell ftello
#endif

/*
 * Tag for preview window is remembered separately, to avoid messing up the
 * normal tagstack.
 */
static taggy_T ptag_entry = {NULL, {INIT_POS_T(0, 0, 0), 0}, 0, 0};

/*
 * Jump to tag; handling of tag commands and tag stack
 *
 * *tag != NUL: ":tag {tag}", jump to new tag, add to tag stack
 *
 * type == DT_TAG:	":tag [tag]", jump to newer position or same tag again
 * type == DT_HELP:	like DT_TAG, but don't use regexp.
 * type == DT_POP:	":pop" or CTRL-T, jump to old position
 * type == DT_NEXT:	jump to next match of same tag
 * type == DT_PREV:	jump to previous match of same tag
 * type == DT_FIRST:	jump to first match of same tag
 * type == DT_LAST:	jump to last match of same tag
 * type == DT_SELECT:	":tselect [tag]", select tag from a list of all matches
 * type == DT_JUMP:	":tjump [tag]", jump to tag or select tag from a list
 * type == DT_CSCOPE:	use cscope to find the tag
 * type == DT_LTAG:	use location list for displaying tag matches
 * type == DT_FREE:	free cached matches
 *
 * for cscope, returns TRUE if we jumped to tag or aborted, FALSE otherwise
 */
int 
do_tag (
    char_u *tag,               /* tag (pattern) to jump to */
    int type,
    int count,
    int forceit,                    /* :ta with ! */
    int verbose                    /* print "tag not found" message */
)
{
  taggy_T     *tagstack = curwin->w_tagstack;
  int tagstackidx = curwin->w_tagstackidx;
  int tagstacklen = curwin->w_tagstacklen;
  int cur_match = 0;
  int cur_fnum = curbuf->b_fnum;
  int oldtagstackidx = tagstackidx;
  int prevtagstackidx = tagstackidx;
  int prev_num_matches;
  int new_tag = FALSE;
  int other_name;
  int i, j, k;
  int idx;
  int ic;
  char_u      *p;
  char_u      *name;
  int no_regexp = FALSE;
  int error_cur_match = 0;
  char_u      *command_end;
  int save_pos = FALSE;
  fmark_T saved_fmark;
  int taglen;
  int jumped_to_tag = FALSE;
  tagptrs_T tagp, tagp2;
  int new_num_matches;
  char_u      **new_matches;
  int attr;
  int use_tagstack;
  int skip_msg = FALSE;
  char_u      *buf_ffname = curbuf->b_ffname;       /* name to use for
                                                       priority computation */

  /* remember the matches for the last used tag */
  static int num_matches = 0;
  static int max_num_matches = 0;             /* limit used for match search */
  static char_u       **matches = NULL;
  static int flags;

#ifdef EXITFREE
  if (type == DT_FREE) {
    /* remove the list of matches */
    FreeWild(num_matches, matches);
    cs_free_tags();
    num_matches = 0;
    return FALSE;
  }
#endif

  if (type == DT_HELP) {
    type = DT_TAG;
    no_regexp = TRUE;
  }

  prev_num_matches = num_matches;
  free_string_option(nofile_fname);
  nofile_fname = NULL;

  clearpos(&saved_fmark.mark);          /* shutup gcc 4.0 */
  saved_fmark.fnum = 0;

  /*
   * Don't add a tag to the tagstack if 'tagstack' has been reset.
   */
  if ((!p_tgst && *tag != NUL)) {
    use_tagstack = FALSE;
    new_tag = TRUE;
  } else   {
    if (g_do_tagpreview != 0)
      use_tagstack = FALSE;
    else
      use_tagstack = TRUE;

    /* new pattern, add to the tag stack */
    if (*tag != NUL
        && (type == DT_TAG || type == DT_SELECT || type == DT_JUMP
            || type == DT_LTAG
            || type == DT_CSCOPE
            )) {
      if (g_do_tagpreview != 0) {
        if (ptag_entry.tagname != NULL
            && STRCMP(ptag_entry.tagname, tag) == 0) {
          /* Jumping to same tag: keep the current match, so that
           * the CursorHold autocommand example works. */
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else   {
          vim_free(ptag_entry.tagname);
          if ((ptag_entry.tagname = vim_strsave(tag)) == NULL)
            goto end_do_tag;
        }
      } else   {
        /*
         * If the last used entry is not at the top, delete all tag
         * stack entries above it.
         */
        while (tagstackidx < tagstacklen)
          vim_free(tagstack[--tagstacklen].tagname);

        /* if the tagstack is full: remove oldest entry */
        if (++tagstacklen > TAGSTACKSIZE) {
          tagstacklen = TAGSTACKSIZE;
          vim_free(tagstack[0].tagname);
          for (i = 1; i < tagstacklen; ++i)
            tagstack[i - 1] = tagstack[i];
          --tagstackidx;
        }

        /*
         * put the tag name in the tag stack
         */
        if ((tagstack[tagstackidx].tagname = vim_strsave(tag)) == NULL) {
          curwin->w_tagstacklen = tagstacklen - 1;
          goto end_do_tag;
        }
        curwin->w_tagstacklen = tagstacklen;

        save_pos = TRUE;                /* save the cursor position below */
      }

      new_tag = TRUE;
    } else   {
      if (
        g_do_tagpreview != 0 ? ptag_entry.tagname == NULL :
        tagstacklen == 0) {
        /* empty stack */
        EMSG(_(e_tagstack));
        goto end_do_tag;
      }

      if (type == DT_POP) {             /* go to older position */
        int old_KeyTyped = KeyTyped;
        if ((tagstackidx -= count) < 0) {
          EMSG(_(bottommsg));
          if (tagstackidx + count == 0) {
            /* We did [num]^T from the bottom of the stack */
            tagstackidx = 0;
            goto end_do_tag;
          }
          /* We weren't at the bottom of the stack, so jump all the
           * way to the bottom now.
           */
          tagstackidx = 0;
        } else if (tagstackidx >= tagstacklen)   {      /* count == 0? */
          EMSG(_(topmsg));
          goto end_do_tag;
        }

        /* Make a copy of the fmark, autocommands may invalidate the
         * tagstack before it's used. */
        saved_fmark = tagstack[tagstackidx].fmark;
        if (saved_fmark.fnum != curbuf->b_fnum) {
          /*
           * Jump to other file. If this fails (e.g. because the
           * file was changed) keep original position in tag stack.
           */
          if (buflist_getfile(saved_fmark.fnum, saved_fmark.mark.lnum,
                  GETF_SETMARK, forceit) == FAIL) {
            tagstackidx = oldtagstackidx;              /* back to old posn */
            goto end_do_tag;
          }
          /* An BufReadPost autocommand may jump to the '" mark, but
           * we don't what that here. */
          curwin->w_cursor.lnum = saved_fmark.mark.lnum;
        } else   {
          setpcmark();
          curwin->w_cursor.lnum = saved_fmark.mark.lnum;
        }
        curwin->w_cursor.col = saved_fmark.mark.col;
        curwin->w_set_curswant = TRUE;
        check_cursor();
        if ((fdo_flags & FDO_TAG) && old_KeyTyped)
          foldOpenCursor();

        /* remove the old list of matches */
        FreeWild(num_matches, matches);
        cs_free_tags();
        num_matches = 0;
        tag_freematch();
        goto end_do_tag;
      }

      if (type == DT_TAG
          || type == DT_LTAG
          ) {
        if (g_do_tagpreview != 0) {
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else   {
          /* ":tag" (no argument): go to newer pattern */
          save_pos = TRUE;              /* save the cursor position below */
          if ((tagstackidx += count - 1) >= tagstacklen) {
            /*
             * Beyond the last one, just give an error message and
             * go to the last one.  Don't store the cursor
             * position.
             */
            tagstackidx = tagstacklen - 1;
            EMSG(_(topmsg));
            save_pos = FALSE;
          } else if (tagstackidx < 0)   {       /* must have been count == 0 */
            EMSG(_(bottommsg));
            tagstackidx = 0;
            goto end_do_tag;
          }
          cur_match = tagstack[tagstackidx].cur_match;
          cur_fnum = tagstack[tagstackidx].cur_fnum;
        }
        new_tag = TRUE;
      } else   {                                /* go to other matching tag */
        /* Save index for when selection is cancelled. */
        prevtagstackidx = tagstackidx;

        if (g_do_tagpreview != 0) {
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else   {
          if (--tagstackidx < 0)
            tagstackidx = 0;
          cur_match = tagstack[tagstackidx].cur_match;
          cur_fnum = tagstack[tagstackidx].cur_fnum;
        }
        switch (type) {
        case DT_FIRST: cur_match = count - 1; break;
        case DT_SELECT:
        case DT_JUMP:
        case DT_CSCOPE:
        case DT_LAST:  cur_match = MAXCOL - 1; break;
        case DT_NEXT:  cur_match += count; break;
        case DT_PREV:  cur_match -= count; break;
        }
        if (cur_match >= MAXCOL)
          cur_match = MAXCOL - 1;
        else if (cur_match < 0) {
          EMSG(_("E425: Cannot go before first matching tag"));
          skip_msg = TRUE;
          cur_match = 0;
          cur_fnum = curbuf->b_fnum;
        }
      }
    }

    if (g_do_tagpreview != 0) {
      if (type != DT_SELECT && type != DT_JUMP) {
        ptag_entry.cur_match = cur_match;
        ptag_entry.cur_fnum = cur_fnum;
      }
    } else   {
      /*
       * For ":tag [arg]" or ":tselect" remember position before the jump.
       */
      saved_fmark = tagstack[tagstackidx].fmark;
      if (save_pos) {
        tagstack[tagstackidx].fmark.mark = curwin->w_cursor;
        tagstack[tagstackidx].fmark.fnum = curbuf->b_fnum;
      }

      /* Curwin will change in the call to jumpto_tag() if ":stag" was
       * used or an autocommand jumps to another window; store value of
       * tagstackidx now. */
      curwin->w_tagstackidx = tagstackidx;
      if (type != DT_SELECT && type != DT_JUMP) {
        curwin->w_tagstack[tagstackidx].cur_match = cur_match;
        curwin->w_tagstack[tagstackidx].cur_fnum = cur_fnum;
      }
    }
  }

  /* When not using the current buffer get the name of buffer "cur_fnum".
   * Makes sure that the tag order doesn't change when using a remembered
   * position for "cur_match". */
  if (cur_fnum != curbuf->b_fnum) {
    buf_T *buf = buflist_findnr(cur_fnum);

    if (buf != NULL)
      buf_ffname = buf->b_ffname;
  }

  /*
   * Repeat searching for tags, when a file has not been found.
   */
  for (;; ) {
    /*
     * When desired match not found yet, try to find it (and others).
     */
    if (use_tagstack)
      name = tagstack[tagstackidx].tagname;
    else if (g_do_tagpreview != 0)
      name = ptag_entry.tagname;
    else
      name = tag;
    other_name = (tagmatchname == NULL || STRCMP(tagmatchname, name) != 0);
    if (new_tag
        || (cur_match >= num_matches && max_num_matches != MAXCOL)
        || other_name) {
      if (other_name) {
        vim_free(tagmatchname);
        tagmatchname = vim_strsave(name);
      }

      /*
       * If a count is supplied to the ":tag <name>" command, then
       * jump to count'th matching tag.
       */
      if (type == DT_TAG && *tag != NUL && count > 0)
        cur_match = count - 1;

      if (type == DT_SELECT || type == DT_JUMP
          || type == DT_LTAG
          )
        cur_match = MAXCOL - 1;
      max_num_matches = cur_match + 1;

      /* when the argument starts with '/', use it as a regexp */
      if (!no_regexp && *name == '/') {
        flags = TAG_REGEXP;
        ++name;
      } else
        flags = TAG_NOIC;

      if (type == DT_CSCOPE)
        flags = TAG_CSCOPE;
      if (verbose)
        flags |= TAG_VERBOSE;
      if (find_tags(name, &new_num_matches, &new_matches, flags,
              max_num_matches, buf_ffname) == OK
          && new_num_matches < max_num_matches)
        max_num_matches = MAXCOL;         /* If less than max_num_matches
                                             found: all matches found. */

      /* If there already were some matches for the same name, move them
       * to the start.  Avoids that the order changes when using
       * ":tnext" and jumping to another file. */
      if (!new_tag && !other_name) {
        /* Find the position of each old match in the new list.  Need
         * to use parse_match() to find the tag line. */
        idx = 0;
        for (j = 0; j < num_matches; ++j) {
          parse_match(matches[j], &tagp);
          for (i = idx; i < new_num_matches; ++i) {
            parse_match(new_matches[i], &tagp2);
            if (STRCMP(tagp.tagname, tagp2.tagname) == 0) {
              p = new_matches[i];
              for (k = i; k > idx; --k)
                new_matches[k] = new_matches[k - 1];
              new_matches[idx++] = p;
              break;
            }
          }
        }
      }
      FreeWild(num_matches, matches);
      num_matches = new_num_matches;
      matches = new_matches;
    }

    if (num_matches <= 0) {
      if (verbose)
        EMSG2(_("E426: tag not found: %s"), name);
      g_do_tagpreview = 0;
    } else   {
      int ask_for_selection = FALSE;

      if (type == DT_CSCOPE && num_matches > 1) {
        cs_print_tags();
        ask_for_selection = TRUE;
      } else if (type == DT_SELECT ||
                 (type == DT_JUMP && num_matches > 1))        {
        /*
         * List all the matching tags.
         * Assume that the first match indicates how long the tags can
         * be, and align the file names to that.
         */
        parse_match(matches[0], &tagp);
        taglen = (int)(tagp.tagname_end - tagp.tagname + 2);
        if (taglen < 18)
          taglen = 18;
        if (taglen > Columns - 25)
          taglen = MAXCOL;
        if (msg_col == 0)
          msg_didout = FALSE;           /* overwrite previous message */
        msg_start();
        MSG_PUTS_ATTR(_("  # pri kind tag"), hl_attr(HLF_T));
        msg_clr_eos();
        taglen_advance(taglen);
        MSG_PUTS_ATTR(_("file\n"), hl_attr(HLF_T));

        for (i = 0; i < num_matches && !got_int; ++i) {
          parse_match(matches[i], &tagp);
          if (!new_tag && (
                (g_do_tagpreview != 0
                 && i == ptag_entry.cur_match) ||
                (use_tagstack
                 && i == tagstack[tagstackidx].cur_match)))
            *IObuff = '>';
          else
            *IObuff = ' ';
          vim_snprintf((char *)IObuff + 1, IOSIZE - 1,
              "%2d %s ", i + 1,
              mt_names[matches[i][0] & MT_MASK]);
          msg_puts(IObuff);
          if (tagp.tagkind != NULL)
            msg_outtrans_len(tagp.tagkind,
                (int)(tagp.tagkind_end - tagp.tagkind));
          msg_advance(13);
          msg_outtrans_len_attr(tagp.tagname,
              (int)(tagp.tagname_end - tagp.tagname),
              hl_attr(HLF_T));
          msg_putchar(' ');
          taglen_advance(taglen);

          /* Find out the actual file name. If it is long, truncate
           * it and put "..." in the middle */
          p = tag_full_fname(&tagp);
          if (p != NULL) {
            msg_puts_long_attr(p, hl_attr(HLF_D));
            vim_free(p);
          }
          if (msg_col > 0)
            msg_putchar('\n');
          if (got_int)
            break;
          msg_advance(15);

          /* print any extra fields */
          command_end = tagp.command_end;
          if (command_end != NULL) {
            p = command_end + 3;
            while (*p && *p != '\r' && *p != '\n') {
              while (*p == TAB)
                ++p;

              /* skip "file:" without a value (static tag) */
              if (STRNCMP(p, "file:", 5) == 0
                  && vim_isspace(p[5])) {
                p += 5;
                continue;
              }
              /* skip "kind:<kind>" and "<kind>" */
              if (p == tagp.tagkind
                  || (p + 5 == tagp.tagkind
                      && STRNCMP(p, "kind:", 5) == 0)) {
                p = tagp.tagkind_end;
                continue;
              }
              /* print all other extra fields */
              attr = hl_attr(HLF_CM);
              while (*p && *p != '\r' && *p != '\n') {
                if (msg_col + ptr2cells(p) >= Columns) {
                  msg_putchar('\n');
                  if (got_int)
                    break;
                  msg_advance(15);
                }
                p = msg_outtrans_one(p, attr);
                if (*p == TAB) {
                  msg_puts_attr((char_u *)" ", attr);
                  break;
                }
                if (*p == ':')
                  attr = 0;
              }
            }
            if (msg_col > 15) {
              msg_putchar('\n');
              if (got_int)
                break;
              msg_advance(15);
            }
          } else   {
            for (p = tagp.command;
                 *p && *p != '\r' && *p != '\n'; ++p)
              ;
            command_end = p;
          }

          /*
           * Put the info (in several lines) at column 15.
           * Don't display "/^" and "?^".
           */
          p = tagp.command;
          if (*p == '/' || *p == '?') {
            ++p;
            if (*p == '^')
              ++p;
          }
          /* Remove leading whitespace from pattern */
          while (p != command_end && vim_isspace(*p))
            ++p;

          while (p != command_end) {
            if (msg_col + (*p == TAB ? 1 : ptr2cells(p)) > Columns)
              msg_putchar('\n');
            if (got_int)
              break;
            msg_advance(15);

            /* skip backslash used for escaping command char */
            if (*p == '\\' && *(p + 1) == *tagp.command)
              ++p;

            if (*p == TAB) {
              msg_putchar(' ');
              ++p;
            } else
              p = msg_outtrans_one(p, 0);

            /* don't display the "$/;\"" and "$?;\"" */
            if (p == command_end - 2 && *p == '$'
                && *(p + 1) == *tagp.command)
              break;
            /* don't display matching '/' or '?' */
            if (p == command_end - 1 && *p == *tagp.command
                && (*p == '/' || *p == '?'))
              break;
          }
          if (msg_col)
            msg_putchar('\n');
          ui_breakcheck();
        }
        if (got_int)
          got_int = FALSE;              /* only stop the listing */
        ask_for_selection = TRUE;
      } else if (type == DT_LTAG)   {
        list_T  *list;
        char_u tag_name[128 + 1];
        char_u  *fname;
        char_u  *cmd;

        /*
         * Add the matching tags to the location list for the current
         * window.
         */

        fname = alloc(MAXPATHL + 1);
        cmd = alloc(CMDBUFFSIZE + 1);
        list = list_alloc();
        if (list == NULL || fname == NULL || cmd == NULL) {
          vim_free(cmd);
          vim_free(fname);
          if (list != NULL)
            list_free(list, TRUE);
          goto end_do_tag;
        }

        for (i = 0; i < num_matches; ++i) {
          int len, cmd_len;
          long lnum;
          dict_T  *dict;

          parse_match(matches[i], &tagp);

          /* Save the tag name */
          len = (int)(tagp.tagname_end - tagp.tagname);
          if (len > 128)
            len = 128;
          vim_strncpy(tag_name, tagp.tagname, len);
          tag_name[len] = NUL;

          /* Save the tag file name */
          p = tag_full_fname(&tagp);
          if (p == NULL)
            continue;
          vim_strncpy(fname, p, MAXPATHL);
          vim_free(p);

          /*
           * Get the line number or the search pattern used to locate
           * the tag.
           */
          lnum = 0;
          if (isdigit(*tagp.command))
            /* Line number is used to locate the tag */
            lnum = atol((char *)tagp.command);
          else {
            char_u *cmd_start, *cmd_end;

            /* Search pattern is used to locate the tag */

            /* Locate the end of the command */
            cmd_start = tagp.command;
            cmd_end = tagp.command_end;
            if (cmd_end == NULL) {
              for (p = tagp.command;
                   *p && *p != '\r' && *p != '\n'; ++p)
                ;
              cmd_end = p;
            }

            /*
             * Now, cmd_end points to the character after the
             * command. Adjust it to point to the last
             * character of the command.
             */
            cmd_end--;

            /*
             * Skip the '/' and '?' characters at the
             * beginning and end of the search pattern.
             */
            if (*cmd_start == '/' || *cmd_start == '?')
              cmd_start++;

            if (*cmd_end == '/' || *cmd_end == '?')
              cmd_end--;

            len = 0;
            cmd[0] = NUL;

            /*
             * If "^" is present in the tag search pattern, then
             * copy it first.
             */
            if (*cmd_start == '^') {
              STRCPY(cmd, "^");
              cmd_start++;
              len++;
            }

            /*
             * Precede the tag pattern with \V to make it very
             * nomagic.
             */
            STRCAT(cmd, "\\V");
            len += 2;

            cmd_len = (int)(cmd_end - cmd_start + 1);
            if (cmd_len > (CMDBUFFSIZE - 5))
              cmd_len = CMDBUFFSIZE - 5;
            STRNCAT(cmd, cmd_start, cmd_len);
            len += cmd_len;

            if (cmd[len - 1] == '$') {
              /*
               * Replace '$' at the end of the search pattern
               * with '\$'
               */
              cmd[len - 1] = '\\';
              cmd[len] = '$';
              len++;
            }

            cmd[len] = NUL;
          }

          if ((dict = dict_alloc()) == NULL)
            continue;
          if (list_append_dict(list, dict) == FAIL) {
            vim_free(dict);
            continue;
          }

          dict_add_nr_str(dict, "text", 0L, tag_name);
          dict_add_nr_str(dict, "filename", 0L, fname);
          dict_add_nr_str(dict, "lnum", lnum, NULL);
          if (lnum == 0)
            dict_add_nr_str(dict, "pattern", 0L, cmd);
        }

        vim_snprintf((char *)IObuff, IOSIZE, "ltag %s", tag);
        set_errorlist(curwin, list, ' ', IObuff);

        list_free(list, TRUE);
        vim_free(fname);
        vim_free(cmd);

        cur_match = 0;                  /* Jump to the first tag */
      }

      if (ask_for_selection == TRUE) {
        /*
         * Ask to select a tag from the list.
         */
        i = prompt_for_number(NULL);
        if (i <= 0 || i > num_matches || got_int) {
          /* no valid choice: don't change anything */
          if (use_tagstack) {
            tagstack[tagstackidx].fmark = saved_fmark;
            tagstackidx = prevtagstackidx;
          }
          cs_free_tags();
          jumped_to_tag = TRUE;
          break;
        }
        cur_match = i - 1;
      }

      if (cur_match >= num_matches) {
        /* Avoid giving this error when a file wasn't found and we're
         * looking for a match in another file, which wasn't found.
         * There will be an EMSG("file doesn't exist") below then. */
        if ((type == DT_NEXT || type == DT_FIRST)
            && nofile_fname == NULL) {
          if (num_matches == 1)
            EMSG(_("E427: There is only one matching tag"));
          else
            EMSG(_("E428: Cannot go beyond last matching tag"));
          skip_msg = TRUE;
        }
        cur_match = num_matches - 1;
      }
      if (use_tagstack) {
        tagstack[tagstackidx].cur_match = cur_match;
        tagstack[tagstackidx].cur_fnum = cur_fnum;
        ++tagstackidx;
      } else if (g_do_tagpreview != 0)   {
        ptag_entry.cur_match = cur_match;
        ptag_entry.cur_fnum = cur_fnum;
      }

      /*
       * Only when going to try the next match, report that the previous
       * file didn't exist.  Otherwise an EMSG() is given below.
       */
      if (nofile_fname != NULL && error_cur_match != cur_match)
        smsg((char_u *)_("File \"%s\" does not exist"), nofile_fname);


      ic = (matches[cur_match][0] & MT_IC_OFF);
      if (type != DT_SELECT && type != DT_JUMP
          && type != DT_CSCOPE
          && (num_matches > 1 || ic)
          && !skip_msg) {
        /* Give an indication of the number of matching tags */
        sprintf((char *)IObuff, _("tag %d of %d%s"),
            cur_match + 1,
            num_matches,
            max_num_matches != MAXCOL ? _(" or more") : "");
        if (ic)
          STRCAT(IObuff, _("  Using tag with different case!"));
        if ((num_matches > prev_num_matches || new_tag)
            && num_matches > 1) {
          if (ic)
            msg_attr(IObuff, hl_attr(HLF_W));
          else
            msg(IObuff);
          msg_scroll = TRUE;            /* don't overwrite this message */
        } else
          give_warning(IObuff, ic);
        if (ic && !msg_scrolled && msg_silent == 0) {
          out_flush();
          ui_delay(1000L, TRUE);
        }
      }

      /* Let the SwapExists event know what tag we are jumping to. */
      vim_snprintf((char *)IObuff, IOSIZE, ":ta %s\r", name);
      set_vim_var_string(VV_SWAPCOMMAND, IObuff, -1);

      /*
       * Jump to the desired match.
       */
      i = jumpto_tag(matches[cur_match], forceit, type != DT_CSCOPE);

      set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);

      if (i == NOTAGFILE) {
        /* File not found: try again with another matching tag */
        if ((type == DT_PREV && cur_match > 0)
            || ((type == DT_TAG || type == DT_NEXT
                 || type == DT_FIRST)
                && (max_num_matches != MAXCOL
                    || cur_match < num_matches - 1))) {
          error_cur_match = cur_match;
          if (use_tagstack)
            --tagstackidx;
          if (type == DT_PREV)
            --cur_match;
          else {
            type = DT_NEXT;
            ++cur_match;
          }
          continue;
        }
        EMSG2(_("E429: File \"%s\" does not exist"), nofile_fname);
      } else   {
        /* We may have jumped to another window, check that
         * tagstackidx is still valid. */
        if (use_tagstack && tagstackidx > curwin->w_tagstacklen)
          tagstackidx = curwin->w_tagstackidx;
        jumped_to_tag = TRUE;
      }
    }
    break;
  }

end_do_tag:
  /* Only store the new index when using the tagstack and it's valid. */
  if (use_tagstack && tagstackidx <= curwin->w_tagstacklen)
    curwin->w_tagstackidx = tagstackidx;
  postponed_split = 0;          /* don't split next time */

  return jumped_to_tag;
}

/*
 * Free cached tags.
 */
void tag_freematch(void)          {
  vim_free(tagmatchname);
  tagmatchname = NULL;
}

static void taglen_advance(int l)
{
  if (l == MAXCOL) {
    msg_putchar('\n');
    msg_advance(24);
  } else
    msg_advance(13 + l);
}

/*
 * Print the tag stack
 */
void do_tags(exarg_T *eap)
{
  int i;
  char_u      *name;
  taggy_T     *tagstack = curwin->w_tagstack;
  int tagstackidx = curwin->w_tagstackidx;
  int tagstacklen = curwin->w_tagstacklen;

  /* Highlight title */
  MSG_PUTS_TITLE(_("\n  # TO tag         FROM line  in file/text"));
  for (i = 0; i < tagstacklen; ++i) {
    if (tagstack[i].tagname != NULL) {
      name = fm_getname(&(tagstack[i].fmark), 30);
      if (name == NULL)             /* file name not available */
        continue;

      msg_putchar('\n');
      sprintf((char *)IObuff, "%c%2d %2d %-15s %5ld  ",
          i == tagstackidx ? '>' : ' ',
          i + 1,
          tagstack[i].cur_match + 1,
          tagstack[i].tagname,
          tagstack[i].fmark.mark.lnum);
      msg_outtrans(IObuff);
      msg_outtrans_attr(name, tagstack[i].fmark.fnum == curbuf->b_fnum
          ? hl_attr(HLF_D) : 0);
      vim_free(name);
    }
    out_flush();                    /* show one line at a time */
  }
  if (tagstackidx == tagstacklen)       /* idx at top of stack */
    MSG_PUTS("\n>");
}

/* When not using a CR for line separator, use vim_fgets() to read tag lines.
 * For the Mac use tag_fgets().  It can handle any line separator, but is much
 * slower than vim_fgets().
 */
#ifndef USE_CR
# define tag_fgets vim_fgets
#endif

static int tag_strnicmp(char_u *s1, char_u *s2, size_t len);

/*
 * Compare two strings, for length "len", ignoring case the ASCII way.
 * return 0 for match, < 0 for smaller, > 0 for bigger
 * Make sure case is folded to uppercase in comparison (like for 'sort -f')
 */
static int tag_strnicmp(char_u *s1, char_u *s2, size_t len)
{
  int i;

  while (len > 0) {
    i = (int)TOUPPER_ASC(*s1) - (int)TOUPPER_ASC(*s2);
    if (i != 0)
      return i;                         /* this character different */
    if (*s1 == NUL)
      break;                            /* strings match until NUL */
    ++s1;
    ++s2;
    --len;
  }
  return 0;                             /* strings match */
}

/*
 * Structure to hold info about the tag pattern being used.
 */
typedef struct {
  char_u      *pat;             /* the pattern */
  int len;                      /* length of pat[] */
  char_u      *head;            /* start of pattern head */
  int headlen;                  /* length of head[] */
  regmatch_T regmatch;          /* regexp program, may be NULL */
} pat_T;

static void prepare_pats(pat_T *pats, int has_re);

/*
 * Extract info from the tag search pattern "pats->pat".
 */
static void prepare_pats(pat_T *pats, int has_re)
{
  pats->head = pats->pat;
  pats->headlen = pats->len;
  if (has_re) {
    /* When the pattern starts with '^' or "\\<", binary searching can be
     * used (much faster). */
    if (pats->pat[0] == '^')
      pats->head = pats->pat + 1;
    else if (pats->pat[0] == '\\' && pats->pat[1] == '<')
      pats->head = pats->pat + 2;
    if (pats->head == pats->pat)
      pats->headlen = 0;
    else
      for (pats->headlen = 0; pats->head[pats->headlen] != NUL;
           ++pats->headlen)
        if (vim_strchr((char_u *)(p_magic ? ".[~*\\$" : "\\$"),
                pats->head[pats->headlen]) != NULL)
          break;
    if (p_tl != 0 && pats->headlen > p_tl)      /* adjust for 'taglength' */
      pats->headlen = p_tl;
  }

  if (has_re)
    pats->regmatch.regprog = vim_regcomp(pats->pat, p_magic ? RE_MAGIC : 0);
  else
    pats->regmatch.regprog = NULL;
}

/*
 * find_tags() - search for tags in tags files
 *
 * Return FAIL if search completely failed (*num_matches will be 0, *matchesp
 * will be NULL), OK otherwise.
 *
 * There is a priority in which type of tag is recognized.
 *
 *  6.	A static or global tag with a full matching tag for the current file.
 *  5.	A global tag with a full matching tag for another file.
 *  4.	A static tag with a full matching tag for another file.
 *  3.	A static or global tag with an ignore-case matching tag for the
 *	current file.
 *  2.	A global tag with an ignore-case matching tag for another file.
 *  1.	A static tag with an ignore-case matching tag for another file.
 *
 * Tags in an emacs-style tags file are always global.
 *
 * flags:
 * TAG_HELP	  only search for help tags
 * TAG_NAMES	  only return name of tag
 * TAG_REGEXP	  use "pat" as a regexp
 * TAG_NOIC	  don't always ignore case
 * TAG_KEEP_LANG  keep language
 */
int 
find_tags (
    char_u *pat,                       /* pattern to search for */
    int *num_matches,               /* return: number of matches found */
    char_u ***matchesp,                /* return: array of matches found */
    int flags,
    int mincount,                           /*  MAXCOL: find all matches
                                             other: minimal number of matches */
    char_u *buf_ffname                /* name of buffer for priority */
)
{
  FILE       *fp;
  char_u     *lbuf;                     /* line buffer */
  int lbuf_size = LSIZE;                /* length of lbuf */
  char_u     *tag_fname;                /* name of tag file */
  tagname_T tn;                         /* info for get_tagfname() */
  int first_file;                       /* trying first tag file */
  tagptrs_T tagp;
  int did_open = FALSE;                 /* did open a tag file */
  int stop_searching = FALSE;           /* stop when match found or error */
  int retval = FAIL;                    /* return value */
  int is_static;                        /* current tag line is static */
  int is_current;                       /* file name matches */
  int eof = FALSE;                      /* found end-of-file */
  char_u      *p;
  char_u      *s;
  int i;
  int tag_file_sorted = NUL;            /* !_TAG_FILE_SORTED value */
  struct tag_search_info        /* Binary search file offsets */
  {
    off_t low_offset;           /* offset for first char of first line that
                                   could match */
    off_t high_offset;          /* offset of char after last line that could
                                   match */
    off_t curr_offset;          /* Current file offset in search range */
    off_t curr_offset_used;       /* curr_offset used when skipping back */
    off_t match_offset;         /* Where the binary search found a tag */
    int low_char;               /* first char at low_offset */
    int high_char;              /* first char at high_offset */
  } search_info;
  off_t filesize;
  int tagcmp;
  off_t offset;
  int round;
  enum {
    TS_START,                   /* at start of file */
    TS_LINEAR                   /* linear searching forward, till EOF */
    , TS_BINARY,                /* binary searching */
    TS_SKIP_BACK,               /* skipping backwards */
    TS_STEP_FORWARD             /* stepping forwards */
  }   state;                    /* Current search state */

  int cmplen;
  int match;                    /* matches */
  int match_no_ic = 0;          /* matches with rm_ic == FALSE */
  int match_re;                 /* match with regexp */
  int matchoff = 0;
  int save_emsg_off;


  struct match_found {
    int len;                    /* nr of chars of match[] to be compared */
    char_u match[1];            /* actually longer */
  } *mfp, *mfp2;
  garray_T ga_match[MT_COUNT];
  int match_count = 0;                          /* number of matches found */
  char_u      **matches;
  int mtt;
  int help_save;
  int help_pri = 0;
  char_u      *help_lang_find = NULL;           /* lang to be found */
  char_u help_lang[3];                          /* lang of current tags file */
  char_u      *saved_pat = NULL;                /* copy of pat[] */

  pat_T orgpat;                         /* holds unconverted pattern info */
  vimconv_T vimconv;

  int findall = (mincount == MAXCOL || mincount == TAG_MANY);
  /* find all matching tags */
  int sort_error = FALSE;                       /* tags file not sorted */
  int linear;                                   /* do a linear search */
  int sortic = FALSE;                           /* tag file sorted in nocase */
  int line_error = FALSE;                       /* syntax error */
  int has_re = (flags & TAG_REGEXP);            /* regexp used */
  int help_only = (flags & TAG_HELP);
  int name_only = (flags & TAG_NAMES);
  int noic = (flags & TAG_NOIC);
  int get_it_again = FALSE;
  int use_cscope = (flags & TAG_CSCOPE);
  int verbose = (flags & TAG_VERBOSE);

  help_save = curbuf->b_help;
  orgpat.pat = pat;
  vimconv.vc_type = CONV_NONE;

  /*
   * Allocate memory for the buffers that are used
   */
  lbuf = alloc(lbuf_size);
  tag_fname = alloc(MAXPATHL + 1);
  for (mtt = 0; mtt < MT_COUNT; ++mtt)
    ga_init2(&ga_match[mtt], (int)sizeof(struct match_found *), 100);

  /* check for out of memory situation */
  if (lbuf == NULL || tag_fname == NULL
      )
    goto findtag_end;

  STRCPY(tag_fname, "from cscope");             /* for error messages */

  /*
   * Initialize a few variables
   */
  if (help_only)                                /* want tags from help file */
    curbuf->b_help = TRUE;                      /* will be restored later */

  orgpat.len = (int)STRLEN(pat);
  if (curbuf->b_help) {
    /* When "@ab" is specified use only the "ab" language, otherwise
     * search all languages. */
    if (orgpat.len > 3 && pat[orgpat.len - 3] == '@'
        && ASCII_ISALPHA(pat[orgpat.len - 2])
        && ASCII_ISALPHA(pat[orgpat.len - 1])) {
      saved_pat = vim_strnsave(pat, orgpat.len - 3);
      if (saved_pat != NULL) {
        help_lang_find = &pat[orgpat.len - 2];
        orgpat.pat = saved_pat;
        orgpat.len -= 3;
      }
    }
  }
  if (p_tl != 0 && orgpat.len > p_tl)           /* adjust for 'taglength' */
    orgpat.len = p_tl;

  save_emsg_off = emsg_off;
  emsg_off = TRUE;    /* don't want error for invalid RE here */
  prepare_pats(&orgpat, has_re);
  emsg_off = save_emsg_off;
  if (has_re && orgpat.regmatch.regprog == NULL)
    goto findtag_end;

  /* This is only to avoid a compiler warning for using search_info
   * uninitialised. */
  vim_memset(&search_info, 0, (size_t)1);

  /*
   * When finding a specified number of matches, first try with matching
   * case, so binary search can be used, and try ignore-case matches in a
   * second loop.
   * When finding all matches, 'tagbsearch' is off, or there is no fixed
   * string to look for, ignore case right away to avoid going though the
   * tags files twice.
   * When the tag file is case-fold sorted, it is either one or the other.
   * Only ignore case when TAG_NOIC not used or 'ignorecase' set.
   */
  orgpat.regmatch.rm_ic = ((p_ic || !noic)
                           && (findall || orgpat.headlen == 0 || !p_tbs));
  for (round = 1; round <= 2; ++round) {
    linear = (orgpat.headlen == 0 || !p_tbs || round == 2);

    /*
     * Try tag file names from tags option one by one.
     */
    for (first_file = TRUE;
         use_cscope ||
         get_tagfname(&tn, first_file, tag_fname) == OK;
         first_file = FALSE) {
      /*
       * A file that doesn't exist is silently ignored.  Only when not a
       * single file is found, an error message is given (further on).
       */
      if (use_cscope)
        fp = NULL;          /* avoid GCC warning */
      else {
        if (curbuf->b_help) {
          /* Prefer help tags according to 'helplang'.  Put the
           * two-letter language name in help_lang[]. */
          i = (int)STRLEN(tag_fname);
          if (i > 3 && tag_fname[i - 3] == '-')
            STRCPY(help_lang, tag_fname + i - 2);
          else
            STRCPY(help_lang, "en");

          /* When searching for a specific language skip tags files
           * for other languages. */
          if (help_lang_find != NULL
              && STRICMP(help_lang, help_lang_find) != 0)
            continue;

          /* For CTRL-] in a help file prefer a match with the same
           * language. */
          if ((flags & TAG_KEEP_LANG)
              && help_lang_find == NULL
              && curbuf->b_fname != NULL
              && (i = (int)STRLEN(curbuf->b_fname)) > 4
              && curbuf->b_fname[i - 1] == 'x'
              && curbuf->b_fname[i - 4] == '.'
              && STRNICMP(curbuf->b_fname + i - 3, help_lang, 2) == 0)
            help_pri = 0;
          else {
            help_pri = 1;
            for (s = p_hlg; *s != NUL; ++s) {
              if (STRNICMP(s, help_lang, 2) == 0)
                break;
              ++help_pri;
              if ((s = vim_strchr(s, ',')) == NULL)
                break;
            }
            if (s == NULL || *s == NUL) {
              /* Language not in 'helplang': use last, prefer English,
               * unless found already. */
              ++help_pri;
              if (STRICMP(help_lang, "en") != 0)
                ++help_pri;
            }
          }
        }

        if ((fp = mch_fopen((char *)tag_fname, "r")) == NULL)
          continue;

        if (p_verbose >= 5) {
          verbose_enter();
          smsg((char_u *)_("Searching tags file %s"), tag_fname);
          verbose_leave();
        }
      }
      did_open = TRUE;      /* remember that we found at least one file */

      state = TS_START;     /* we're at the start of the file */

      /*
       * Read and parse the lines in the file one by one
       */
      for (;; ) {
        line_breakcheck();          /* check for CTRL-C typed */
        if ((flags & TAG_INS_COMP))     /* Double brackets for gcc */
          ins_compl_check_keys(30);
        if (got_int || compl_interrupted) {
          stop_searching = TRUE;
          break;
        }
        /* When mincount is TAG_MANY, stop when enough matches have been
         * found (for completion). */
        if (mincount == TAG_MANY && match_count >= TAG_MANY) {
          stop_searching = TRUE;
          retval = OK;
          break;
        }
        if (get_it_again)
          goto line_read_in;
        /*
         * For binary search: compute the next offset to use.
         */
        if (state == TS_BINARY) {
          offset = search_info.low_offset + ((search_info.high_offset
                                              - search_info.low_offset) / 2);
          if (offset == search_info.curr_offset)
            break;              /* End the binary search without a match. */
          else
            search_info.curr_offset = offset;
        }
        /*
         * Skipping back (after a match during binary search).
         */
        else if (state == TS_SKIP_BACK) {
          search_info.curr_offset -= LSIZE * 2;
          if (search_info.curr_offset < 0) {
            search_info.curr_offset = 0;
            rewind(fp);
            state = TS_STEP_FORWARD;
          }
        }

        /*
         * When jumping around in the file, first read a line to find the
         * start of the next line.
         */
        if (state == TS_BINARY || state == TS_SKIP_BACK) {
          /* Adjust the search file offset to the correct position */
          search_info.curr_offset_used = search_info.curr_offset;
#ifdef HAVE_FSEEKO
          fseeko(fp, search_info.curr_offset, SEEK_SET);
#else
          fseek(fp, (long)search_info.curr_offset, SEEK_SET);
#endif
          eof = tag_fgets(lbuf, LSIZE, fp);
          if (!eof && search_info.curr_offset != 0) {
            /* The explicit cast is to work around a bug in gcc 3.4.2
             * (repeated below). */
            search_info.curr_offset = ftell(fp);
            if (search_info.curr_offset == search_info.high_offset) {
              /* oops, gone a bit too far; try from low offset */
#ifdef HAVE_FSEEKO
              fseeko(fp, search_info.low_offset, SEEK_SET);
#else
              fseek(fp, (long)search_info.low_offset, SEEK_SET);
#endif
              search_info.curr_offset = search_info.low_offset;
            }
            eof = tag_fgets(lbuf, LSIZE, fp);
          }
          /* skip empty and blank lines */
          while (!eof && vim_isblankline(lbuf)) {
            search_info.curr_offset = ftell(fp);
            eof = tag_fgets(lbuf, LSIZE, fp);
          }
          if (eof) {
            /* Hit end of file.  Skip backwards. */
            state = TS_SKIP_BACK;
            search_info.match_offset = ftell(fp);
            search_info.curr_offset = search_info.curr_offset_used;
            continue;
          }
        }
        /*
         * Not jumping around in the file: Read the next line.
         */
        else {
          /* skip empty and blank lines */
          do {
            if (use_cscope)
              eof = cs_fgets(lbuf, LSIZE);
            else
              eof = tag_fgets(lbuf, LSIZE, fp);
          } while (!eof && vim_isblankline(lbuf));

          if (eof) {
            break;                                  /* end of file */
          }
        }
line_read_in:

        if (vimconv.vc_type != CONV_NONE) {
          char_u  *conv_line;
          int len;

          /* Convert every line.  Converting the pattern from 'enc' to
           * the tags file encoding doesn't work, because characters are
           * not recognized. */
          conv_line = string_convert(&vimconv, lbuf, NULL);
          if (conv_line != NULL) {
            /* Copy or swap lbuf and conv_line. */
            len = (int)STRLEN(conv_line) + 1;
            if (len > lbuf_size) {
              vim_free(lbuf);
              lbuf = conv_line;
              lbuf_size = len;
            } else   {
              STRCPY(lbuf, conv_line);
              vim_free(conv_line);
            }
          }
        }



        /*
         * When still at the start of the file, check for Emacs tags file
         * format, and for "not sorted" flag.
         */
        if (state == TS_START) {
          /* The header ends when the line sorts below "!_TAG_".  When
           * case is folded lower case letters sort before "_". */
          if (STRNCMP(lbuf, "!_TAG_", 6) <= 0
              || (lbuf[0] == '!' && ASCII_ISLOWER(lbuf[1]))) {
            if (STRNCMP(lbuf, "!_TAG_", 6) != 0)
              /* Non-header item before the header, e.g. "!" itself.
               */
              goto parse_line;

            /*
             * Read header line.
             */
            if (STRNCMP(lbuf, "!_TAG_FILE_SORTED\t", 18) == 0)
              tag_file_sorted = lbuf[18];
            if (STRNCMP(lbuf, "!_TAG_FILE_ENCODING\t", 20) == 0) {
              /* Prepare to convert every line from the specified
               * encoding to 'encoding'. */
              for (p = lbuf + 20; *p > ' ' && *p < 127; ++p)
                ;
              *p = NUL;
              convert_setup(&vimconv, lbuf + 20, p_enc);
            }

            /* Read the next line.  Unrecognized flags are ignored. */
            continue;
          }

          /* Headers ends. */

          /*
           * When there is no tag head, or ignoring case, need to do a
           * linear search.
           * When no "!_TAG_" is found, default to binary search.  If
           * the tag file isn't sorted, the second loop will find it.
           * When "!_TAG_FILE_SORTED" found: start binary search if
           * flag set.
           * For cscope, it's always linear.
           */
          if (linear || use_cscope)
            state = TS_LINEAR;
          else if (tag_file_sorted == NUL)
            state = TS_BINARY;
          else if (tag_file_sorted == '1')
            state = TS_BINARY;
          else if (tag_file_sorted == '2') {
            state = TS_BINARY;
            sortic = TRUE;
            orgpat.regmatch.rm_ic = (p_ic || !noic);
          } else
            state = TS_LINEAR;

          if (state == TS_BINARY && orgpat.regmatch.rm_ic && !sortic) {
            /* Binary search won't work for ignoring case, use linear
             * search. */
            linear = TRUE;
            state = TS_LINEAR;
          }

          /*
           * When starting a binary search, get the size of the file and
           * compute the first offset.
           */
          if (state == TS_BINARY) {
            /* Get the tag file size (don't use mch_fstat(), it's not
             * portable). */
            if ((filesize = lseek(fileno(fp),
                     (off_t)0L, SEEK_END)) <= 0)
              state = TS_LINEAR;
            else {
              lseek(fileno(fp), (off_t)0L, SEEK_SET);

              /* Calculate the first read offset in the file.  Start
               * the search in the middle of the file. */
              search_info.low_offset = 0;
              search_info.low_char = 0;
              search_info.high_offset = filesize;
              search_info.curr_offset = 0;
              search_info.high_char = 0xff;
            }
            continue;
          }
        }

parse_line:
        /*
         * Figure out where the different strings are in this line.
         * For "normal" tags: Do a quick check if the tag matches.
         * This speeds up tag searching a lot!
         */
        if (orgpat.headlen
            ) {
          tagp.tagname = lbuf;
#ifdef FEAT_TAG_ANYWHITE
          tagp.tagname_end = skiptowhite(lbuf);
          if (*tagp.tagname_end == NUL)
#else
          tagp.tagname_end = vim_strchr(lbuf, TAB);
          if (tagp.tagname_end == NULL)
#endif
          {
            if (vim_strchr(lbuf, NL) == NULL) {
              /* Truncated line, ignore it.  Has been reported for
               * Mozilla JS with extremely long names. */
              if (p_verbose >= 5) {
                verbose_enter();
                MSG(_("Ignoring long line in tags file"));
                verbose_leave();
              }
              if (state != TS_LINEAR) {
                /* Avoid getting stuck. */
                linear = TRUE;
                state = TS_LINEAR;
# ifdef HAVE_FSEEKO
                fseeko(fp, search_info.low_offset, SEEK_SET);
# else
                fseek(fp, (long)search_info.low_offset, SEEK_SET);
# endif
              }
              continue;
            }

            /* Corrupted tag line. */
            line_error = TRUE;
            break;
          }

          /*
           * Check for old style static tag: "file:tag file .."
           */
          tagp.fname = NULL;
          for (p = lbuf; p < tagp.tagname_end; ++p) {
            if (*p == ':') {
              if (tagp.fname == NULL)
#ifdef FEAT_TAG_ANYWHITE
                tagp.fname = skipwhite(tagp.tagname_end);
#else
                tagp.fname = tagp.tagname_end + 1;
#endif
              if (       fnamencmp(lbuf, tagp.fname, p - lbuf) == 0
#ifdef FEAT_TAG_ANYWHITE
                         && vim_iswhite(tagp.fname[p - lbuf])
#else
                         && tagp.fname[p - lbuf] == TAB
#endif
                         ) {
                /* found one */
                tagp.tagname = p + 1;
                break;
              }
            }
          }

          /*
           * Skip this line if the length of the tag is different and
           * there is no regexp, or the tag is too short.
           */
          cmplen = (int)(tagp.tagname_end - tagp.tagname);
          if (p_tl != 0 && cmplen > p_tl)           /* adjust for 'taglength' */
            cmplen = p_tl;
          if (has_re && orgpat.headlen < cmplen)
            cmplen = orgpat.headlen;
          else if (state == TS_LINEAR && orgpat.headlen != cmplen)
            continue;

          if (state == TS_BINARY) {
            /*
             * Simplistic check for unsorted tags file.
             */
            i = (int)tagp.tagname[0];
            if (sortic)
              i = (int)TOUPPER_ASC(tagp.tagname[0]);
            if (i < search_info.low_char || i > search_info.high_char)
              sort_error = TRUE;

            /*
             * Compare the current tag with the searched tag.
             */
            if (sortic)
              tagcmp = tag_strnicmp(tagp.tagname, orgpat.head,
                  (size_t)cmplen);
            else
              tagcmp = STRNCMP(tagp.tagname, orgpat.head, cmplen);

            /*
             * A match with a shorter tag means to search forward.
             * A match with a longer tag means to search backward.
             */
            if (tagcmp == 0) {
              if (cmplen < orgpat.headlen)
                tagcmp = -1;
              else if (cmplen > orgpat.headlen)
                tagcmp = 1;
            }

            if (tagcmp == 0) {
              /* We've located the tag, now skip back and search
               * forward until the first matching tag is found.
               */
              state = TS_SKIP_BACK;
              search_info.match_offset = search_info.curr_offset;
              continue;
            }
            if (tagcmp < 0) {
              search_info.curr_offset = ftell(fp);
              if (search_info.curr_offset < search_info.high_offset) {
                search_info.low_offset = search_info.curr_offset;
                if (sortic)
                  search_info.low_char =
                    TOUPPER_ASC(tagp.tagname[0]);
                else
                  search_info.low_char = tagp.tagname[0];
                continue;
              }
            }
            if (tagcmp > 0
                && search_info.curr_offset != search_info.high_offset) {
              search_info.high_offset = search_info.curr_offset;
              if (sortic)
                search_info.high_char =
                  TOUPPER_ASC(tagp.tagname[0]);
              else
                search_info.high_char = tagp.tagname[0];
              continue;
            }

            /* No match yet and are at the end of the binary search. */
            break;
          } else if (state == TS_SKIP_BACK)   {
            if (MB_STRNICMP(tagp.tagname, orgpat.head, cmplen) != 0)
              state = TS_STEP_FORWARD;
            else
              /* Have to skip back more.  Restore the curr_offset
               * used, otherwise we get stuck at a long line. */
              search_info.curr_offset = search_info.curr_offset_used;
            continue;
          } else if (state == TS_STEP_FORWARD)   {
            if (MB_STRNICMP(tagp.tagname, orgpat.head, cmplen) != 0) {
              if ((off_t)ftell(fp) > search_info.match_offset)
                break;                  /* past last match */
              else
                continue;               /* before first match */
            }
          } else
          /* skip this match if it can't match */
          if (MB_STRNICMP(tagp.tagname, orgpat.head, cmplen) != 0)
            continue;

          /*
           * Can be a matching tag, isolate the file name and command.
           */
          if (tagp.fname == NULL)
#ifdef FEAT_TAG_ANYWHITE
            tagp.fname = skipwhite(tagp.tagname_end);
#else
            tagp.fname = tagp.tagname_end + 1;
#endif
#ifdef FEAT_TAG_ANYWHITE
          tagp.fname_end = skiptowhite(tagp.fname);
          tagp.command = skipwhite(tagp.fname_end);
          if (*tagp.command == NUL)
#else
          tagp.fname_end = vim_strchr(tagp.fname, TAB);
          tagp.command = tagp.fname_end + 1;
          if (tagp.fname_end == NULL)
#endif
            i = FAIL;
          else
            i = OK;
        } else
          i = parse_tag_line(lbuf,
              &tagp);
        if (i == FAIL) {
          line_error = TRUE;
          break;
        }

        /*
         * First try matching with the pattern literally (also when it is
         * a regexp).
         */
        cmplen = (int)(tagp.tagname_end - tagp.tagname);
        if (p_tl != 0 && cmplen > p_tl)             /* adjust for 'taglength' */
          cmplen = p_tl;
        /* if tag length does not match, don't try comparing */
        if (orgpat.len != cmplen)
          match = FALSE;
        else {
          if (orgpat.regmatch.rm_ic) {
            match = (MB_STRNICMP(tagp.tagname, orgpat.pat, cmplen) == 0);
            if (match)
              match_no_ic = (STRNCMP(tagp.tagname, orgpat.pat,
                                 cmplen) == 0);
          } else
            match = (STRNCMP(tagp.tagname, orgpat.pat, cmplen) == 0);
        }

        /*
         * Has a regexp: Also find tags matching regexp.
         */
        match_re = FALSE;
        if (!match && orgpat.regmatch.regprog != NULL) {
          int cc;

          cc = *tagp.tagname_end;
          *tagp.tagname_end = NUL;
          match = vim_regexec(&orgpat.regmatch, tagp.tagname, (colnr_T)0);
          if (match) {
            matchoff = (int)(orgpat.regmatch.startp[0] - tagp.tagname);
            if (orgpat.regmatch.rm_ic) {
              orgpat.regmatch.rm_ic = FALSE;
              match_no_ic = vim_regexec(&orgpat.regmatch, tagp.tagname,
                  (colnr_T)0);
              orgpat.regmatch.rm_ic = TRUE;
            }
          }
          *tagp.tagname_end = cc;
          match_re = TRUE;
        }

        /*
         * If a match is found, add it to ga_match[].
         */
        if (match) {
          if (use_cscope) {
            /* Don't change the ordering, always use the same table. */
            mtt = MT_GL_OTH;
          } else   {
            /* Decide in which array to store this match. */
            is_current = test_for_current(
                tagp.fname, tagp.fname_end, tag_fname,
                buf_ffname);
            {
              if (tagp.tagname != lbuf)
                is_static = TRUE;               /* detected static tag before */
              else
                is_static = test_for_static(&tagp);
            }

            /* decide in which of the sixteen tables to store this
             * match */
            if (is_static) {
              if (is_current)
                mtt = MT_ST_CUR;
              else
                mtt = MT_ST_OTH;
            } else   {
              if (is_current)
                mtt = MT_GL_CUR;
              else
                mtt = MT_GL_OTH;
            }
            if (orgpat.regmatch.rm_ic && !match_no_ic)
              mtt += MT_IC_OFF;
            if (match_re)
              mtt += MT_RE_OFF;
          }

          /*
           * Add the found match in ga_match[mtt], avoiding duplicates.
           * Store the info we need later, which depends on the kind of
           * tags we are dealing with.
           */
          if (ga_grow(&ga_match[mtt], 1) == OK) {
            int len;

            if (help_only) {
# define ML_EXTRA 3
              /*
               * Append the help-heuristic number after the
               * tagname, for sorting it later.
               */
              *tagp.tagname_end = NUL;
              len = (int)(tagp.tagname_end - tagp.tagname);
              mfp = (struct match_found *)
                    alloc((int)sizeof(struct match_found) + len
                  + 10 + ML_EXTRA);
              if (mfp != NULL) {
                /* "len" includes the language and the NUL, but
                 * not the priority. */
                mfp->len = len + ML_EXTRA + 1;
#define ML_HELP_LEN 6
                p = mfp->match;
                STRCPY(p, tagp.tagname);
                p[len] = '@';
                STRCPY(p + len + 1, help_lang);
                sprintf((char *)p + len + 1 + ML_EXTRA, "%06d",
                    help_heuristic(tagp.tagname,
                        match_re ? matchoff : 0, !match_no_ic)
                    + help_pri
                    );
              }
              *tagp.tagname_end = TAB;
            } else if (name_only)   {
              if (get_it_again) {
                char_u *temp_end = tagp.command;

                if (*temp_end == '/')
                  while (*temp_end && *temp_end != '\r'
                         && *temp_end != '\n'
                         && *temp_end != '$')
                    temp_end++;

                if (tagp.command + 2 < temp_end) {
                  len = (int)(temp_end - tagp.command - 2);
                  mfp = (struct match_found *)alloc(
                      (int)sizeof(struct match_found) + len);
                  if (mfp != NULL) {
                    mfp->len = len + 1;                 /* include the NUL */
                    p = mfp->match;
                    vim_strncpy(p, tagp.command + 2, len);
                  }
                } else
                  mfp = NULL;
                get_it_again = FALSE;
              } else   {
                len = (int)(tagp.tagname_end - tagp.tagname);
                mfp = (struct match_found *)alloc(
                    (int)sizeof(struct match_found) + len);
                if (mfp != NULL) {
                  mfp->len = len + 1;               /* include the NUL */
                  p = mfp->match;
                  vim_strncpy(p, tagp.tagname, len);
                }

                /* if wanted, re-read line to get long form too */
                if (State & INSERT)
                  get_it_again = p_sft;
              }
            } else   {
              /* Save the tag in a buffer.
               * Emacs tag: <mtt><tag_fname><NUL><ebuf><NUL><lbuf>
               * other tag: <mtt><tag_fname><NUL><NUL><lbuf>
               * without Emacs tags: <mtt><tag_fname><NUL><lbuf>
               */
              len = (int)STRLEN(tag_fname)
                    + (int)STRLEN(lbuf) + 3;
              mfp = (struct match_found *)alloc(
                  (int)sizeof(struct match_found) + len);
              if (mfp != NULL) {
                mfp->len = len;
                p = mfp->match;
                p[0] = mtt;
                STRCPY(p + 1, tag_fname);
#ifdef BACKSLASH_IN_FILENAME
                /* Ignore differences in slashes, avoid adding
                 * both path/file and path\file. */
                slash_adjust(p + 1);
#endif
                s = p + 1 + STRLEN(tag_fname) + 1;
                STRCPY(s, lbuf);
              }
            }

            if (mfp != NULL) {
              /*
               * Don't add identical matches.
               * This can take a lot of time when finding many
               * matches, check for CTRL-C now and then.
               * Add all cscope tags, because they are all listed.
               */
              if (use_cscope)
                i = -1;
              else
                for (i = ga_match[mtt].ga_len; --i >= 0 && !got_int; ) {
                  mfp2 = ((struct match_found **)
                          (ga_match[mtt].ga_data))[i];
                  if (mfp2->len == mfp->len
                      && vim_memcmp(mfp2->match, mfp->match,
                          (size_t)mfp->len) == 0)
                    break;
                  line_breakcheck();
                }
              if (i < 0) {
                ((struct match_found **)(ga_match[mtt].ga_data))
                [ga_match[mtt].ga_len++] = mfp;
                ++match_count;
              } else
                vim_free(mfp);
            }
          } else   {    /* Out of memory! Just forget about the rest. */
            retval = OK;
            stop_searching = TRUE;
            break;
          }
        }
        if (use_cscope && eof)
          break;
      }   /* forever */

      if (line_error) {
        EMSG2(_("E431: Format error in tags file \"%s\""), tag_fname);
        if (!use_cscope)
          EMSGN(_("Before byte %ld"), (long)ftell(fp));
        stop_searching = TRUE;
        line_error = FALSE;
      }

      if (!use_cscope)
        fclose(fp);
      if (vimconv.vc_type != CONV_NONE)
        convert_setup(&vimconv, NULL, NULL);

      tag_file_sorted = NUL;
      if (sort_error) {
        EMSG2(_("E432: Tags file not sorted: %s"), tag_fname);
        sort_error = FALSE;
      }

      /*
       * Stop searching if sufficient tags have been found.
       */
      if (match_count >= mincount) {
        retval = OK;
        stop_searching = TRUE;
      }

      if (stop_searching || use_cscope)
        break;

    }   /* end of for-each-file loop */

    if (!use_cscope)
      tagname_free(&tn);

    /* stop searching when already did a linear search, or when TAG_NOIC
     * used, and 'ignorecase' not set or already did case-ignore search */
    if (stop_searching || linear || (!p_ic && noic) || orgpat.regmatch.rm_ic)
      break;
    if (use_cscope)
      break;
    orgpat.regmatch.rm_ic = TRUE;       /* try another time while ignoring case */
  }

  if (!stop_searching) {
    if (!did_open && verbose)           /* never opened any tags file */
      EMSG(_("E433: No tags file"));
    retval = OK;                /* It's OK even when no tag found */
  }

findtag_end:
  vim_free(lbuf);
  vim_regfree(orgpat.regmatch.regprog);
  vim_free(tag_fname);

  /*
   * Move the matches from the ga_match[] arrays into one list of
   * matches.  When retval == FAIL, free the matches.
   */
  if (retval == FAIL)
    match_count = 0;

  if (match_count > 0)
    matches = (char_u **)lalloc((long_u)(match_count * sizeof(char_u *)),
        TRUE);
  else
    matches = NULL;
  match_count = 0;
  for (mtt = 0; mtt < MT_COUNT; ++mtt) {
    for (i = 0; i < ga_match[mtt].ga_len; ++i) {
      mfp = ((struct match_found **)(ga_match[mtt].ga_data))[i];
      if (matches == NULL)
        vim_free(mfp);
      else {
        /* To avoid allocating memory again we turn the struct
         * match_found into a string.  For help the priority was not
         * included in the length. */
        mch_memmove(mfp, mfp->match,
            (size_t)(mfp->len + (help_only ? ML_HELP_LEN : 0)));
        matches[match_count++] = (char_u *)mfp;
      }
    }
    ga_clear(&ga_match[mtt]);
  }

  *matchesp = matches;
  *num_matches = match_count;

  curbuf->b_help = help_save;
  vim_free(saved_pat);

  return retval;
}

static garray_T tag_fnames = GA_EMPTY;
static void found_tagfile_cb(char_u *fname, void *cookie);

/*
 * Callback function for finding all "tags" and "tags-??" files in
 * 'runtimepath' doc directories.
 */
static void found_tagfile_cb(char_u *fname, void *cookie)
{
  if (ga_grow(&tag_fnames, 1) == OK)
    ((char_u **)(tag_fnames.ga_data))[tag_fnames.ga_len++] =
      vim_strsave(fname);
}

#if defined(EXITFREE) || defined(PROTO)
void free_tag_stuff(void)          {
  ga_clear_strings(&tag_fnames);
  do_tag(NULL, DT_FREE, 0, 0, 0);
  tag_freematch();

  if (ptag_entry.tagname) {
    vim_free(ptag_entry.tagname);
    ptag_entry.tagname = NULL;
  }
}

#endif

/*
 * Get the next name of a tag file from the tag file list.
 * For help files, use "tags" file only.
 *
 * Return FAIL if no more tag file names, OK otherwise.
 */
int 
get_tagfname (
    tagname_T *tnp,       /* holds status info */
    int first,              /* TRUE when first file name is wanted */
    char_u *buf       /* pointer to buffer of MAXPATHL chars */
)
{
  char_u              *fname = NULL;
  char_u              *r_ptr;

  if (first)
    vim_memset(tnp, 0, sizeof(tagname_T));

  if (curbuf->b_help) {
    /*
     * For help files it's done in a completely different way:
     * Find "doc/tags" and "doc/tags-??" in all directories in
     * 'runtimepath'.
     */
    if (first) {
      ga_clear_strings(&tag_fnames);
      ga_init2(&tag_fnames, (int)sizeof(char_u *), 10);
      do_in_runtimepath((char_u *)
          "doc/tags doc/tags-??"
          , TRUE, found_tagfile_cb, NULL);
    }

    if (tnp->tn_hf_idx >= tag_fnames.ga_len) {
      /* Not found in 'runtimepath', use 'helpfile', if it exists and
       * wasn't used yet, replacing "help.txt" with "tags". */
      if (tnp->tn_hf_idx > tag_fnames.ga_len || *p_hf == NUL)
        return FAIL;
      ++tnp->tn_hf_idx;
      STRCPY(buf, p_hf);
      STRCPY(gettail(buf), "tags");
    } else
      vim_strncpy(buf, ((char_u **)(tag_fnames.ga_data))[
            tnp->tn_hf_idx++], MAXPATHL - 1);
    return OK;
  }

  if (first) {
    /* Init.  We make a copy of 'tags', because autocommands may change
     * the value without notifying us. */
    tnp->tn_tags = vim_strsave((*curbuf->b_p_tags != NUL)
        ? curbuf->b_p_tags : p_tags);
    if (tnp->tn_tags == NULL)
      return FAIL;
    tnp->tn_np = tnp->tn_tags;
  }

  /*
   * Loop until we have found a file name that can be used.
   * There are two states:
   * tnp->tn_did_filefind_init == FALSE: setup for next part in 'tags'.
   * tnp->tn_did_filefind_init == TRUE: find next file in this part.
   */
  for (;; ) {
    if (tnp->tn_did_filefind_init) {
      fname = vim_findfile(tnp->tn_search_ctx);
      if (fname != NULL)
        break;

      tnp->tn_did_filefind_init = FALSE;
    } else   {
      char_u  *filename = NULL;

      /* Stop when used all parts of 'tags'. */
      if (*tnp->tn_np == NUL) {
        vim_findfile_cleanup(tnp->tn_search_ctx);
        tnp->tn_search_ctx = NULL;
        return FAIL;
      }

      /*
       * Copy next file name into buf.
       */
      buf[0] = NUL;
      (void)copy_option_part(&tnp->tn_np, buf, MAXPATHL - 1, " ,");

      r_ptr = vim_findfile_stopdir(buf);
      /* move the filename one char forward and truncate the
       * filepath with a NUL */
      filename = gettail(buf);
      STRMOVE(filename + 1, filename);
      *filename++ = NUL;

      tnp->tn_search_ctx = vim_findfile_init(buf, filename,
          r_ptr, 100,
          FALSE,                   /* don't free visited list */
          FINDFILE_FILE,           /* we search for a file */
          tnp->tn_search_ctx, TRUE, curbuf->b_ffname);
      if (tnp->tn_search_ctx != NULL)
        tnp->tn_did_filefind_init = TRUE;
    }
  }

  STRCPY(buf, fname);
  vim_free(fname);
  return OK;
}

/*
 * Free the contents of a tagname_T that was filled by get_tagfname().
 */
void tagname_free(tagname_T *tnp)
{
  vim_free(tnp->tn_tags);
  vim_findfile_cleanup(tnp->tn_search_ctx);
  tnp->tn_search_ctx = NULL;
  ga_clear_strings(&tag_fnames);
}

/*
 * Parse one line from the tags file. Find start/end of tag name, start/end of
 * file name and start of search pattern.
 *
 * If is_etag is TRUE, tagp->fname and tagp->fname_end are not set.
 *
 * Return FAIL if there is a format error in this line, OK otherwise.
 */
static int 
parse_tag_line (
    char_u *lbuf,              /* line to be parsed */
    tagptrs_T *tagp
)
{
  char_u      *p;

  /* Isolate the tagname, from lbuf up to the first white */
  tagp->tagname = lbuf;
#ifdef FEAT_TAG_ANYWHITE
  p = skiptowhite(lbuf);
#else
  p = vim_strchr(lbuf, TAB);
  if (p == NULL)
    return FAIL;
#endif
  tagp->tagname_end = p;

  /* Isolate file name, from first to second white space */
#ifdef FEAT_TAG_ANYWHITE
  p = skipwhite(p);
#else
  if (*p != NUL)
    ++p;
#endif
  tagp->fname = p;
#ifdef FEAT_TAG_ANYWHITE
  p = skiptowhite(p);
#else
  p = vim_strchr(p, TAB);
  if (p == NULL)
    return FAIL;
#endif
  tagp->fname_end = p;

  /* find start of search command, after second white space */
#ifdef FEAT_TAG_ANYWHITE
  p = skipwhite(p);
#else
  if (*p != NUL)
    ++p;
#endif
  if (*p == NUL)
    return FAIL;
  tagp->command = p;

  return OK;
}

/*
 * Check if tagname is a static tag
 *
 * Static tags produced by the older ctags program have the format:
 *	'file:tag  file  /pattern'.
 * This is only recognized when both occurrence of 'file' are the same, to
 * avoid recognizing "string::string" or ":exit".
 *
 * Static tags produced by the new ctags program have the format:
 *	'tag  file  /pattern/;"<Tab>file:'	    "
 *
 * Return TRUE if it is a static tag and adjust *tagname to the real tag.
 * Return FALSE if it is not a static tag.
 */
static int test_for_static(tagptrs_T *tagp)
{
  char_u      *p;

  int len;

  /*
   * Check for old style static tag: "file:tag file .."
   */
  len = (int)(tagp->fname_end - tagp->fname);
  p = tagp->tagname + len;
  if (       p < tagp->tagname_end
             && *p == ':'
             && fnamencmp(tagp->tagname, tagp->fname, len) == 0) {
    tagp->tagname = p + 1;
    return TRUE;
  }

  /*
   * Check for new style static tag ":...<Tab>file:[<Tab>...]"
   */
  p = tagp->command;
  while ((p = vim_strchr(p, '\t')) != NULL) {
    ++p;
    if (STRNCMP(p, "file:", 5) == 0)
      return TRUE;
  }

  return FALSE;
}

/*
 * Parse a line from a matching tag.  Does not change the line itself.
 *
 * The line that we get looks like this:
 * Emacs tag: <mtt><tag_fname><NUL><ebuf><NUL><lbuf>
 * other tag: <mtt><tag_fname><NUL><NUL><lbuf>
 * without Emacs tags: <mtt><tag_fname><NUL><lbuf>
 *
 * Return OK or FAIL.
 */
static int 
parse_match (
    char_u *lbuf,          /* input: matching line */
    tagptrs_T *tagp          /* output: pointers into the line */
)
{
  int retval;
  char_u      *p;
  char_u      *pc, *pt;

  tagp->tag_fname = lbuf + 1;
  lbuf += STRLEN(tagp->tag_fname) + 2;

  /* Find search pattern and the file name for non-etags. */
  retval = parse_tag_line(lbuf,
      tagp);

  tagp->tagkind = NULL;
  tagp->command_end = NULL;

  if (retval == OK) {
    /* Try to find a kind field: "kind:<kind>" or just "<kind>"*/
    p = tagp->command;
    if (find_extra(&p) == OK) {
      tagp->command_end = p;
      p += 2;           /* skip ";\"" */
      if (*p++ == TAB)
        while (ASCII_ISALPHA(*p)) {
          if (STRNCMP(p, "kind:", 5) == 0) {
            tagp->tagkind = p + 5;
            break;
          }
          pc = vim_strchr(p, ':');
          pt = vim_strchr(p, '\t');
          if (pc == NULL || (pt != NULL && pc > pt)) {
            tagp->tagkind = p;
            break;
          }
          if (pt == NULL)
            break;
          p = pt + 1;
        }
    }
    if (tagp->tagkind != NULL) {
      for (p = tagp->tagkind;
           *p && *p != '\t' && *p != '\r' && *p != '\n'; ++p)
        ;
      tagp->tagkind_end = p;
    }
  }
  return retval;
}

/*
 * Find out the actual file name of a tag.  Concatenate the tags file name
 * with the matching tag file name.
 * Returns an allocated string or NULL (out of memory).
 */
static char_u *tag_full_fname(tagptrs_T *tagp)
{
  char_u      *fullname;
  int c;

  {
    c = *tagp->fname_end;
    *tagp->fname_end = NUL;
  }
  fullname = expand_tag_fname(tagp->fname, tagp->tag_fname, FALSE);

  *tagp->fname_end = c;

  return fullname;
}

/*
 * Jump to a tag that has been found in one of the tag files
 *
 * returns OK for success, NOTAGFILE when file not found, FAIL otherwise.
 */
static int 
jumpto_tag (
    char_u *lbuf,              /* line from the tags file for this tag */
    int forceit,                    /* :ta with ! */
    int keep_help                  /* keep help flag (FALSE for cscope) */
)
{
  int save_secure;
  int save_magic;
  int save_p_ws, save_p_scs, save_p_ic;
  linenr_T save_lnum;
  int csave = 0;
  char_u      *str;
  char_u      *pbuf;                    /* search pattern buffer */
  char_u      *pbuf_end;
  char_u      *tofree_fname = NULL;
  char_u      *fname;
  tagptrs_T tagp;
  int retval = FAIL;
  int getfile_result;
  int search_options;
  int save_no_hlsearch;
  win_T       *curwin_save = NULL;
  char_u      *full_fname = NULL;
  int old_KeyTyped = KeyTyped;              /* getting the file may reset it */

  pbuf = alloc(LSIZE);

  /* parse the match line into the tagp structure */
  if (pbuf == NULL || parse_match(lbuf, &tagp) == FAIL) {
    tagp.fname_end = NULL;
    goto erret;
  }

  /* truncate the file name, so it can be used as a string */
  csave = *tagp.fname_end;
  *tagp.fname_end = NUL;
  fname = tagp.fname;

  /* copy the command to pbuf[], remove trailing CR/NL */
  str = tagp.command;
  for (pbuf_end = pbuf; *str && *str != '\n' && *str != '\r'; ) {
    *pbuf_end++ = *str++;
  }
  *pbuf_end = NUL;

  {
    /*
     * Remove the "<Tab>fieldname:value" stuff; we don't need it here.
     */
    str = pbuf;
    if (find_extra(&str) == OK) {
      pbuf_end = str;
      *pbuf_end = NUL;
    }
  }

  /*
   * Expand file name, when needed (for environment variables).
   * If 'tagrelative' option set, may change file name.
   */
  fname = expand_tag_fname(fname, tagp.tag_fname, TRUE);
  if (fname == NULL)
    goto erret;
  tofree_fname = fname;         /* free() it later */

  /*
   * Check if the file with the tag exists before abandoning the current
   * file.  Also accept a file name for which there is a matching BufReadCmd
   * autocommand event (e.g., http://sys/file).
   */
  if (mch_getperm(fname) < 0
      && !has_autocmd(EVENT_BUFREADCMD, fname, NULL)
      ) {
    retval = NOTAGFILE;
    vim_free(nofile_fname);
    nofile_fname = vim_strsave(fname);
    if (nofile_fname == NULL)
      nofile_fname = empty_option;
    goto erret;
  }

  ++RedrawingDisabled;


  if (g_do_tagpreview != 0) {
    postponed_split = 0;        /* don't split again below */
    curwin_save = curwin;       /* Save current window */

    /*
     * If we are reusing a window, we may change dir when
     * entering it (autocommands) so turn the tag filename
     * into a fullpath
     */
    if (!curwin->w_p_pvw) {
      full_fname = FullName_save(fname, FALSE);
      fname = full_fname;

      /*
       * Make the preview window the current window.
       * Open a preview window when needed.
       */
      prepare_tagpreview(TRUE);
    }
  }

  /* If it was a CTRL-W CTRL-] command split window now.  For ":tab tag"
   * open a new tab page. */
  if (postponed_split || cmdmod.tab != 0) {
    win_split(postponed_split > 0 ? postponed_split : 0,
        postponed_split_flags);
    RESET_BINDING(curwin);
  }

  if (keep_help) {
    /* A :ta from a help file will keep the b_help flag set.  For ":ptag"
     * we need to use the flag from the window where we came from. */
    if (g_do_tagpreview != 0)
      keep_help_flag = curwin_save->w_buffer->b_help;
    else
      keep_help_flag = curbuf->b_help;
  }
  getfile_result = getfile(0, fname, NULL, TRUE, (linenr_T)0, forceit);
  keep_help_flag = FALSE;

  if (getfile_result <= 0) {            /* got to the right file */
    curwin->w_set_curswant = TRUE;
    postponed_split = 0;

    save_secure = secure;
    secure = 1;
#ifdef HAVE_SANDBOX
    ++sandbox;
#endif
    save_magic = p_magic;
    p_magic = FALSE;            /* always execute with 'nomagic' */
    /* Save value of no_hlsearch, jumping to a tag is not a real search */
    save_no_hlsearch = no_hlsearch;

    /*
     * If 'cpoptions' contains 't', store the search pattern for the "n"
     * command.  If 'cpoptions' does not contain 't', the search pattern
     * is not stored.
     */
    if (vim_strchr(p_cpo, CPO_TAGPAT) != NULL)
      search_options = 0;
    else
      search_options = SEARCH_KEEP;

    /*
     * If the command is a search, try here.
     *
     * Reset 'smartcase' for the search, since the search pattern was not
     * typed by the user.
     * Only use do_search() when there is a full search command, without
     * anything following.
     */
    str = pbuf;
    if (pbuf[0] == '/' || pbuf[0] == '?')
      str = skip_regexp(pbuf + 1, pbuf[0], FALSE, NULL) + 1;
    if (str > pbuf_end - 1) {   /* search command with nothing following */
      save_p_ws = p_ws;
      save_p_ic = p_ic;
      save_p_scs = p_scs;
      p_ws = TRUE;              /* need 'wrapscan' for backward searches */
      p_ic = FALSE;             /* don't ignore case now */
      p_scs = FALSE;
      save_lnum = curwin->w_cursor.lnum;
      curwin->w_cursor.lnum = 0;        /* start search before first line */
      if (do_search(NULL, pbuf[0], pbuf + 1, (long)1,
              search_options, NULL))
        retval = OK;
      else {
        int found = 1;
        int cc;

        /*
         * try again, ignore case now
         */
        p_ic = TRUE;
        if (!do_search(NULL, pbuf[0], pbuf + 1, (long)1,
                search_options, NULL)) {
          /*
           * Failed to find pattern, take a guess: "^func  ("
           */
          found = 2;
          (void)test_for_static(&tagp);
          cc = *tagp.tagname_end;
          *tagp.tagname_end = NUL;
          sprintf((char *)pbuf, "^%s\\s\\*(", tagp.tagname);
          if (!do_search(NULL, '/', pbuf, (long)1,
                  search_options, NULL)) {
            /* Guess again: "^char * \<func  (" */
            sprintf((char *)pbuf, "^\\[#a-zA-Z_]\\.\\*\\<%s\\s\\*(",
                tagp.tagname);
            if (!do_search(NULL, '/', pbuf, (long)1,
                    search_options, NULL))
              found = 0;
          }
          *tagp.tagname_end = cc;
        }
        if (found == 0) {
          EMSG(_("E434: Can't find tag pattern"));
          curwin->w_cursor.lnum = save_lnum;
        } else   {
          /*
           * Only give a message when really guessed, not when 'ic'
           * is set and match found while ignoring case.
           */
          if (found == 2 || !save_p_ic) {
            MSG(_("E435: Couldn't find tag, just guessing!"));
            if (!msg_scrolled && msg_silent == 0) {
              out_flush();
              ui_delay(1000L, TRUE);
            }
          }
          retval = OK;
        }
      }
      p_ws = save_p_ws;
      p_ic = save_p_ic;
      p_scs = save_p_scs;

      /* A search command may have positioned the cursor beyond the end
       * of the line.  May need to correct that here. */
      check_cursor();
    } else   {
      curwin->w_cursor.lnum = 1;                /* start command in line 1 */
      do_cmdline_cmd(pbuf);
      retval = OK;
    }

    /*
     * When the command has done something that is not allowed make sure
     * the error message can be seen.
     */
    if (secure == 2)
      wait_return(TRUE);
    secure = save_secure;
    p_magic = save_magic;
#ifdef HAVE_SANDBOX
    --sandbox;
#endif
    /* restore no_hlsearch when keeping the old search pattern */
    if (search_options) {
      SET_NO_HLSEARCH(save_no_hlsearch);
    }

    /* Return OK if jumped to another file (at least we found the file!). */
    if (getfile_result == -1)
      retval = OK;

    if (retval == OK) {
      /*
       * For a help buffer: Put the cursor line at the top of the window,
       * the help subject will be below it.
       */
      if (curbuf->b_help)
        set_topline(curwin, curwin->w_cursor.lnum);
      if ((fdo_flags & FDO_TAG) && old_KeyTyped)
        foldOpenCursor();
    }

    if (g_do_tagpreview != 0
        && curwin != curwin_save && win_valid(curwin_save)) {
      /* Return cursor to where we were */
      validate_cursor();
      redraw_later(VALID);
      win_enter(curwin_save, TRUE);
    }

    --RedrawingDisabled;
  } else   {
    --RedrawingDisabled;
    if (postponed_split) {              /* close the window */
      win_close(curwin, FALSE);
      postponed_split = 0;
    }
  }

erret:
  g_do_tagpreview = 0;   /* For next time */
  if (tagp.fname_end != NULL)
    *tagp.fname_end = csave;
  vim_free(pbuf);
  vim_free(tofree_fname);
  vim_free(full_fname);

  return retval;
}

/*
 * If "expand" is TRUE, expand wildcards in fname.
 * If 'tagrelative' option set, change fname (name of file containing tag)
 * according to tag_fname (name of tag file containing fname).
 * Returns a pointer to allocated memory (or NULL when out of memory).
 */
static char_u *expand_tag_fname(char_u *fname, char_u *tag_fname, int expand)
{
  char_u      *p;
  char_u      *retval;
  char_u      *expanded_fname = NULL;
  expand_T xpc;

  /*
   * Expand file name (for environment variables) when needed.
   */
  if (expand && mch_has_wildcard(fname)) {
    ExpandInit(&xpc);
    xpc.xp_context = EXPAND_FILES;
    expanded_fname = ExpandOne(&xpc, (char_u *)fname, NULL,
        WILD_LIST_NOTFOUND|WILD_SILENT, WILD_EXPAND_FREE);
    if (expanded_fname != NULL)
      fname = expanded_fname;
  }

  if ((p_tr || curbuf->b_help)
      && !vim_isAbsName(fname)
      && (p = gettail(tag_fname)) != tag_fname) {
    retval = alloc(MAXPATHL);
    if (retval != NULL) {
      STRCPY(retval, tag_fname);
      vim_strncpy(retval + (p - tag_fname), fname,
          MAXPATHL - (p - tag_fname) - 1);
      /*
       * Translate names like "src/a/../b/file.c" into "src/b/file.c".
       */
      simplify_filename(retval);
    }
  } else
    retval = vim_strsave(fname);

  vim_free(expanded_fname);

  return retval;
}

/*
 * Converts a file name into a canonical form. It simplifies a file name into
 * its simplest form by stripping out unneeded components, if any.  The
 * resulting file name is simplified in place and will either be the same
 * length as that supplied, or shorter.
 */
void simplify_filename(char_u *filename)
{
  int components = 0;
  char_u      *p, *tail, *start;
  int stripping_disabled = FALSE;
  int relative = TRUE;

  p = filename;
#ifdef BACKSLASH_IN_FILENAME
  if (p[1] == ':')          /* skip "x:" */
    p += 2;
#endif

  if (vim_ispathsep(*p)) {
    relative = FALSE;
    do
      ++p;
    while (vim_ispathsep(*p));
  }
  start = p;        /* remember start after "c:/" or "/" or "///" */

  do {
    /* At this point "p" is pointing to the char following a single "/"
     * or "p" is at the "start" of the (absolute or relative) path name. */
    if (vim_ispathsep(*p))
      STRMOVE(p, p + 1);                /* remove duplicate "/" */
    else if (p[0] == '.' && (vim_ispathsep(p[1]) || p[1] == NUL)) {
      if (p == start && relative)
        p += 1 + (p[1] != NUL);         /* keep single "." or leading "./" */
      else {
        /* Strip "./" or ".///".  If we are at the end of the file name
         * and there is no trailing path separator, either strip "/." if
         * we are after "start", or strip "." if we are at the beginning
         * of an absolute path name . */
        tail = p + 1;
        if (p[1] != NUL)
          while (vim_ispathsep(*tail))
            mb_ptr_adv(tail);
        else if (p > start)
          --p;                          /* strip preceding path separator */
        STRMOVE(p, tail);
      }
    } else if (p[0] == '.' && p[1] == '.' &&
               (vim_ispathsep(p[2]) || p[2] == NUL)) {
      /* Skip to after ".." or "../" or "..///". */
      tail = p + 2;
      while (vim_ispathsep(*tail))
        mb_ptr_adv(tail);

      if (components > 0) {             /* strip one preceding component */
        int do_strip = FALSE;
        char_u saved_char;
        struct stat st;

        /* Don't strip for an erroneous file name. */
        if (!stripping_disabled) {
          /* If the preceding component does not exist in the file
           * system, we strip it.  On Unix, we don't accept a symbolic
           * link that refers to a non-existent file. */
          saved_char = p[-1];
          p[-1] = NUL;
#ifdef UNIX
          if (mch_lstat((char *)filename, &st) < 0)
#else
          if (mch_stat((char *)filename, &st) < 0)
#endif
            do_strip = TRUE;
          p[-1] = saved_char;

          --p;
          /* Skip back to after previous '/'. */
          while (p > start && !after_pathsep(start, p))
            mb_ptr_back(start, p);

          if (!do_strip) {
            /* If the component exists in the file system, check
             * that stripping it won't change the meaning of the
             * file name.  First get information about the
             * unstripped file name.  This may fail if the component
             * to strip is not a searchable directory (but a regular
             * file, for instance), since the trailing "/.." cannot
             * be applied then.  We don't strip it then since we
             * don't want to replace an erroneous file name by
             * a valid one, and we disable stripping of later
             * components. */
            saved_char = *tail;
            *tail = NUL;
            if (mch_stat((char *)filename, &st) >= 0)
              do_strip = TRUE;
            else
              stripping_disabled = TRUE;
            *tail = saved_char;
#ifdef UNIX
            if (do_strip) {
              struct stat new_st;

              /* On Unix, the check for the unstripped file name
               * above works also for a symbolic link pointing to
               * a searchable directory.  But then the parent of
               * the directory pointed to by the link must be the
               * same as the stripped file name.  (The latter
               * exists in the file system since it is the
               * component's parent directory.) */
              if (p == start && relative)
                (void)mch_stat(".", &new_st);
              else {
                saved_char = *p;
                *p = NUL;
                (void)mch_stat((char *)filename, &new_st);
                *p = saved_char;
              }

              if (new_st.st_ino != st.st_ino ||
                  new_st.st_dev != st.st_dev) {
                do_strip = FALSE;
                /* We don't disable stripping of later
                 * components since the unstripped path name is
                 * still valid. */
              }
            }
#endif
          }
        }

        if (!do_strip) {
          /* Skip the ".." or "../" and reset the counter for the
           * components that might be stripped later on. */
          p = tail;
          components = 0;
        } else   {
          /* Strip previous component.  If the result would get empty
           * and there is no trailing path separator, leave a single
           * "." instead.  If we are at the end of the file name and
           * there is no trailing path separator and a preceding
           * component is left after stripping, strip its trailing
           * path separator as well. */
          if (p == start && relative && tail[-1] == '.') {
            *p++ = '.';
            *p = NUL;
          } else   {
            if (p > start && tail[-1] == '.')
              --p;
            STRMOVE(p, tail);                   /* strip previous component */
          }

          --components;
        }
      } else if (p == start && !relative)       /* leading "/.." or "/../" */
        STRMOVE(p, tail);                       /* strip ".." or "../" */
      else {
        if (p == start + 2 && p[-2] == '.') {           /* leading "./../" */
          STRMOVE(p - 2, p);                            /* strip leading "./" */
          tail -= 2;
        }
        p = tail;                       /* skip to char after ".." or "../" */
      }
    } else   {
      ++components;                     /* simple path component */
      p = getnextcomp(p);
    }
  } while (*p != NUL);
}

/*
 * Check if we have a tag for the buffer with name "buf_ffname".
 * This is a bit slow, because of the full path compare in fullpathcmp().
 * Return TRUE if tag for file "fname" if tag file "tag_fname" is for current
 * file.
 */
static int test_for_current(char_u *fname, char_u *fname_end, char_u *tag_fname, char_u *buf_ffname)
{
  int c;
  int retval = FALSE;
  char_u  *fullname;

  if (buf_ffname != NULL) {     /* if the buffer has a name */
    {
      c = *fname_end;
      *fname_end = NUL;
    }
    fullname = expand_tag_fname(fname, tag_fname, TRUE);
    if (fullname != NULL) {
      retval = (fullpathcmp(fullname, buf_ffname, TRUE) & FPC_SAME);
      vim_free(fullname);
    }
    *fname_end = c;
  }

  return retval;
}

/*
 * Find the end of the tagaddress.
 * Return OK if ";\"" is following, FAIL otherwise.
 */
static int find_extra(char_u **pp)
{
  char_u      *str = *pp;

  /* Repeat for addresses separated with ';' */
  for (;; ) {
    if (VIM_ISDIGIT(*str))
      str = skipdigits(str);
    else if (*str == '/' || *str == '?') {
      str = skip_regexp(str + 1, *str, FALSE, NULL);
      if (*str != **pp)
        str = NULL;
      else
        ++str;
    } else
      str = NULL;
    if (str == NULL || *str != ';'
        || !(VIM_ISDIGIT(str[1]) || str[1] == '/' || str[1] == '?'))
      break;
    ++str;      /* skip ';' */
  }

  if (str != NULL && STRNCMP(str, ";\"", 2) == 0) {
    *pp = str;
    return OK;
  }
  return FAIL;
}

int 
expand_tags (
    int tagnames,                   /* expand tag names */
    char_u *pat,
    int *num_file,
    char_u ***file
)
{
  int i;
  int c;
  int tagnmflag;
  char_u tagnm[100];
  tagptrs_T t_p;
  int ret;

  if (tagnames)
    tagnmflag = TAG_NAMES;
  else
    tagnmflag = 0;
  if (pat[0] == '/')
    ret = find_tags(pat + 1, num_file, file,
        TAG_REGEXP | tagnmflag | TAG_VERBOSE,
        TAG_MANY, curbuf->b_ffname);
  else
    ret = find_tags(pat, num_file, file,
        TAG_REGEXP | tagnmflag | TAG_VERBOSE | TAG_NOIC,
        TAG_MANY, curbuf->b_ffname);
  if (ret == OK && !tagnames) {
    /* Reorganize the tags for display and matching as strings of:
     * "<tagname>\0<kind>\0<filename>\0"
     */
    for (i = 0; i < *num_file; i++) {
      parse_match((*file)[i], &t_p);
      c = (int)(t_p.tagname_end - t_p.tagname);
      mch_memmove(tagnm, t_p.tagname, (size_t)c);
      tagnm[c++] = 0;
      tagnm[c++] = (t_p.tagkind != NULL && *t_p.tagkind)
                   ? *t_p.tagkind : 'f';
      tagnm[c++] = 0;
      mch_memmove((*file)[i] + c, t_p.fname, t_p.fname_end - t_p.fname);
      (*file)[i][c + (t_p.fname_end - t_p.fname)] = 0;
      mch_memmove((*file)[i], tagnm, (size_t)c);
    }
  }
  return ret;
}

static int add_tag_field(dict_T *dict, char *field_name, char_u *start,
                         char_u *end);

/*
 * Add a tag field to the dictionary "dict".
 * Return OK or FAIL.
 */
static int 
add_tag_field (
    dict_T *dict,
    char *field_name,
    char_u *start,                 /* start of the value */
    char_u *end                   /* after the value; can be NULL */
)
{
  char_u      *buf;
  int len = 0;
  int retval;

  /* check that the field name doesn't exist yet */
  if (dict_find(dict, (char_u *)field_name, -1) != NULL) {
    if (p_verbose > 0) {
      verbose_enter();
      smsg((char_u *)_("Duplicate field name: %s"), field_name);
      verbose_leave();
    }
    return FAIL;
  }
  buf = alloc(MAXPATHL);
  if (buf == NULL)
    return FAIL;
  if (start != NULL) {
    if (end == NULL) {
      end = start + STRLEN(start);
      while (end > start && (end[-1] == '\r' || end[-1] == '\n'))
        --end;
    }
    len = (int)(end - start);
    if (len > MAXPATHL - 1)
      len = MAXPATHL - 1;
    vim_strncpy(buf, start, len);
  }
  buf[len] = NUL;
  retval = dict_add_nr_str(dict, field_name, 0L, buf);
  vim_free(buf);
  return retval;
}

/*
 * Add the tags matching the specified pattern to the list "list"
 * as a dictionary
 */
int get_tags(list_T *list, char_u *pat)
{
  int num_matches, i, ret;
  char_u      **matches, *p;
  char_u      *full_fname;
  dict_T      *dict;
  tagptrs_T tp;
  long is_static;

  ret = find_tags(pat, &num_matches, &matches,
      TAG_REGEXP | TAG_NOIC, (int)MAXCOL, NULL);
  if (ret == OK && num_matches > 0) {
    for (i = 0; i < num_matches; ++i) {
      parse_match(matches[i], &tp);
      is_static = test_for_static(&tp);

      /* Skip pseudo-tag lines. */
      if (STRNCMP(tp.tagname, "!_TAG_", 6) == 0)
        continue;

      if ((dict = dict_alloc()) == NULL)
        ret = FAIL;
      if (list_append_dict(list, dict) == FAIL)
        ret = FAIL;

      full_fname = tag_full_fname(&tp);
      if (add_tag_field(dict, "name", tp.tagname, tp.tagname_end) == FAIL
          || add_tag_field(dict, "filename", full_fname,
              NULL) == FAIL
          || add_tag_field(dict, "cmd", tp.command,
              tp.command_end) == FAIL
          || add_tag_field(dict, "kind", tp.tagkind,
              tp.tagkind_end) == FAIL
          || dict_add_nr_str(dict, "static", is_static, NULL) == FAIL)
        ret = FAIL;

      vim_free(full_fname);

      if (tp.command_end != NULL) {
        for (p = tp.command_end + 3;
             *p != NUL && *p != '\n' && *p != '\r'; ++p) {
          if (p == tp.tagkind || (p + 5 == tp.tagkind
                                  && STRNCMP(p, "kind:", 5) == 0))
            /* skip "kind:<kind>" and "<kind>" */
            p = tp.tagkind_end - 1;
          else if (STRNCMP(p, "file:", 5) == 0)
            /* skip "file:" (static tag) */
            p += 4;
          else if (!vim_iswhite(*p)) {
            char_u  *s, *n;
            int len;

            /* Add extra field as a dict entry.  Fields are
             * separated by Tabs. */
            n = p;
            while (*p != NUL && *p >= ' ' && *p < 127 && *p != ':')
              ++p;
            len = (int)(p - n);
            if (*p == ':' && len > 0) {
              s = ++p;
              while (*p != NUL && *p >= ' ')
                ++p;
              n[len] = NUL;
              if (add_tag_field(dict, (char *)n, s, p) == FAIL)
                ret = FAIL;
              n[len] = ':';
            } else
              /* Skip field without colon. */
              while (*p != NUL && *p >= ' ')
                ++p;
            if (*p == NUL)
              break;
          }
        }
      }

      vim_free(matches[i]);
    }
    vim_free(matches);
  }
  return ret;
}
