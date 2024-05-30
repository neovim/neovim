// Code to handle tags and the tag stack

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/help.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/input.h"
#include "nvim/insexpand.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

// Structure to hold pointers to various items in a tag line.
typedef struct {
  // filled in by parse_tag_line():
  char *tagname;        // start of tag name (skip "file:")
  char *tagname_end;    // char after tag name
  char *fname;          // first char of file name
  char *fname_end;      // char after file name
  char *command;        // first char of command
  // filled in by parse_match():
  char *command_end;    // first char after command
  char *tag_fname;      // file name of the tags file. This is used
  // when 'tr' is set.
  char *tagkind;          // "kind:" value
  char *tagkind_end;      // end of tagkind
  char *user_data;        // user_data string
  char *user_data_end;    // end of user_data
  linenr_T tagline;       // "line:" value
} tagptrs_T;

// Structure to hold info about the tag pattern being used.
typedef struct {
  char *pat;            // the pattern
  int len;              // length of pat[]
  char *head;           // start of pattern head
  int headlen;          // length of head[]
  regmatch_T regmatch;  // regexp program, may be NULL
} pat_T;

// The matching tags are first stored in one of the hash tables.  In
// which one depends on the priority of the match.
// ht_match[] is used to find duplicates, ga_match[] to keep them in sequence.
// At the end, the matches from ga_match[] are concatenated, to make a list
// sorted on priority.
enum {
  MT_ST_CUR = 0,  // static match in current file
  MT_GL_CUR = 1,  // global match in current file
  MT_GL_OTH = 2,  // global match in other file
  MT_ST_OTH = 3,  // static match in other file
  MT_IC_OFF = 4,  // add for icase match
  MT_RE_OFF = 8,  // add for regexp match
  MT_MASK = 7,    // mask for printing priority
  MT_COUNT = 16,
};

static char *mt_names[MT_COUNT/2] =
{ "FSC", "F C", "F  ", "FS ", " SC", "  C", "   ", " S " };

#define NOTAGFILE       99              // return value for jumpto_tag
static char *nofile_fname = NULL;       // fname for NOTAGFILE error

/// Return values used when reading lines from a tags file.
typedef enum {
  TAGS_READ_SUCCESS = 1,
  TAGS_READ_EOF,
  TAGS_READ_IGNORE,
} tags_read_status_T;

/// States used during a tags search
typedef enum {
  TS_START,         ///< at start of file
  TS_LINEAR,        ///< linear searching forward, till EOF
  TS_BINARY,        ///< binary searching
  TS_SKIP_BACK,     ///< skipping backwards
  TS_STEP_FORWARD,  ///< stepping forwards
} tagsearch_state_T;

/// Binary search file offsets in a tags file
typedef struct {
  off_T low_offset;        ///< offset for first char of first line that
                           ///< could match
  off_T high_offset;       ///< offset of char after last line that could
                           ///< match
  off_T curr_offset;       ///< Current file offset in search range
  off_T curr_offset_used;  ///< curr_offset used when skipping back
  off_T match_offset;      ///< Where the binary search found a tag
  int low_char;            ///< first char at low_offset
  int high_char;           ///< first char at high_offset
} tagsearch_info_T;

/// Return values used when matching tags against a pattern.
typedef enum {
  TAG_MATCH_SUCCESS = 1,
  TAG_MATCH_FAIL,
  TAG_MATCH_STOP,
  TAG_MATCH_NEXT,
} tagmatch_status_T;

/// Arguments used for matching tags read from a tags file against a pattern.
typedef struct {
  int matchoff;      ///< tag match offset
  bool match_re;     ///< true if the tag matches a regexp
  bool match_no_ic;  ///< true if the tag matches with case
  bool has_re;       ///< regular expression used
  bool sortic;       ///< tags file sorted ignoring case (foldcase)
  bool sort_error;   ///< tags file not sorted
} findtags_match_args_T;

/// State information used during a tag search
typedef struct {
  tagsearch_state_T state;       ///< tag search state
  bool stop_searching;           ///< stop when match found or error
  pat_T *orgpat;                 ///< holds unconverted pattern info
  char *lbuf;                    ///< line buffer
  int lbuf_size;                 ///< length of lbuf
  char *tag_fname;               ///< name of the tag file
  FILE *fp;                      ///< current tags file pointer
  int flags;                     ///< flags used for tag search
  int tag_file_sorted;           ///< !_TAG_FILE_SORTED value
  bool get_searchpat;            ///< used for 'showfulltag'
  bool help_only;                ///< only search for help tags
  bool did_open;                 ///< did open a tag file
  int mincount;                  ///< MAXCOL: find all matches
                                 ///< other: minimal number of matches
  bool linear;                   ///< do a linear search
  vimconv_T vimconv;
  char help_lang[3];             ///< lang of current tags file
  int help_pri;                  ///< help language priority
  char *help_lang_find;          ///< lang to be found
  bool is_txt;                   ///< flag of file extension
  int match_count;               ///< number of matches found
  garray_T ga_match[MT_COUNT];   ///< stores matches in sequence
  hashtab_T ht_match[MT_COUNT];  ///< stores matches by key
} findtags_state_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tag.c.generated.h"
#endif

static const char e_tag_stack_empty[]
  = N_("E73: Tag stack empty");
static const char e_tag_not_found_str[]
  = N_("E426: Tag not found: %s");
static const char e_at_bottom_of_tag_stack[]
  = N_("E555: At bottom of tag stack");
static const char e_at_top_of_tag_stack[]
  = N_("E556: At top of tag stack");
static const char e_cannot_modify_tag_stack_within_tagfunc[]
  = N_("E986: Cannot modify the tag stack within tagfunc");
static const char e_invalid_return_value_from_tagfunc[]
  = N_("E987: Invalid return value from tagfunc");
static const char e_window_unexpectedly_close_while_searching_for_tags[]
  = N_("E1299: Window unexpectedly closed while searching for tags");

static char *tagmatchname = NULL;   // name of last used tag

// Tag for preview window is remembered separately, to avoid messing up the
// normal tagstack.
static taggy_T ptag_entry = { NULL, INIT_FMARK, 0, 0, NULL };

static bool tfu_in_use = false;  // disallow recursive call of tagfunc
static Callback tfu_cb;          // 'tagfunc' callback function

// Used instead of NUL to separate tag fields in the growarrays.
#define TAG_SEP 0x02

/// Reads the 'tagfunc' option value and convert that to a callback value.
/// Invoked when the 'tagfunc' option is set. The option value can be a name of
/// a function (string), or function(<name>) or funcref(<name>) or a lambda.
const char *did_set_tagfunc(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;

  callback_free(&tfu_cb);
  callback_free(&buf->b_tfu_cb);

  if (*buf->b_p_tfu == NUL) {
    return NULL;
  }

  if (option_set_callback_func(buf->b_p_tfu, &tfu_cb) == FAIL) {
    return e_invarg;
  }

  callback_copy(&buf->b_tfu_cb, &tfu_cb);
  return NULL;
}

#if defined(EXITFREE)
void free_tagfunc_option(void)
{
  callback_free(&tfu_cb);
}
#endif

/// Mark the global 'tagfunc' callback with "copyID" so that it is not garbage
/// collected.
bool set_ref_in_tagfunc(int copyID)
{
  return set_ref_in_callback(&tfu_cb, copyID, NULL, NULL);
}

/// Copy the global 'tagfunc' callback function to the buffer-local 'tagfunc'
/// callback for 'buf'.
void set_buflocal_tfu_callback(buf_T *buf)
{
  callback_free(&buf->b_tfu_cb);
  if (tfu_cb.type != kCallbackNone) {
    callback_copy(&buf->b_tfu_cb, &tfu_cb);
  }
}

/// Jump to tag; handling of tag commands and tag stack
///
/// *tag != NUL: ":tag {tag}", jump to new tag, add to tag stack
///
/// type == DT_TAG:      ":tag [tag]", jump to newer position or same tag again
/// type == DT_HELP:     like DT_TAG, but don't use regexp.
/// type == DT_POP:      ":pop" or CTRL-T, jump to old position
/// type == DT_NEXT:     jump to next match of same tag
/// type == DT_PREV:     jump to previous match of same tag
/// type == DT_FIRST:    jump to first match of same tag
/// type == DT_LAST:     jump to last match of same tag
/// type == DT_SELECT:   ":tselect [tag]", select tag from a list of all matches
/// type == DT_JUMP:     ":tjump [tag]", jump to tag or select tag from a list
/// type == DT_LTAG:     use location list for displaying tag matches
/// type == DT_FREE:     free cached matches
///
/// @param tag  tag (pattern) to jump to
/// @param forceit  :ta with !
/// @param verbose  print "tag not found" message
void do_tag(char *tag, int type, int count, int forceit, bool verbose)
{
  taggy_T *tagstack = curwin->w_tagstack;
  int tagstackidx = curwin->w_tagstackidx;
  int tagstacklen = curwin->w_tagstacklen;
  int cur_match = 0;
  int cur_fnum = curbuf->b_fnum;
  int oldtagstackidx = tagstackidx;
  int prevtagstackidx = tagstackidx;
  bool new_tag = false;
  bool no_regexp = false;
  int error_cur_match = 0;
  bool save_pos = false;
  fmark_T saved_fmark;
  int new_num_matches;
  char **new_matches;
  bool use_tagstack;
  bool skip_msg = false;
  char *buf_ffname = curbuf->b_ffname;  // name for priority computation
  bool use_tfu = true;
  char *tofree = NULL;

  // remember the matches for the last used tag
  static int num_matches = 0;
  static int max_num_matches = 0;             // limit used for match search
  static char **matches = NULL;
  static int flags;

#ifdef EXITFREE
  if (type == DT_FREE) {
    // remove the list of matches
    FreeWild(num_matches, matches);
    num_matches = 0;
    return;
  }
#endif

  if (tfu_in_use) {
    emsg(_(e_cannot_modify_tag_stack_within_tagfunc));
    return;
  }

  if (postponed_split == 0 && !check_can_set_curbuf_forceit(forceit)) {
    return;
  }

  if (type == DT_HELP) {
    type = DT_TAG;
    no_regexp = true;
    use_tfu = false;
  }

  int prev_num_matches = num_matches;
  free_string_option(nofile_fname);
  nofile_fname = NULL;

  clearpos(&saved_fmark.mark);          // shutup gcc 4.0
  saved_fmark.fnum = 0;

  // Don't add a tag to the tagstack if 'tagstack' has been reset.
  assert(tag != NULL);
  if (!p_tgst && *tag != NUL) {
    use_tagstack = false;
    new_tag = true;
    if (g_do_tagpreview != 0) {
      tagstack_clear_entry(&ptag_entry);
      ptag_entry.tagname = xstrdup(tag);
    }
  } else {
    if (g_do_tagpreview != 0) {
      use_tagstack = false;
    } else {
      use_tagstack = true;
    }

    // new pattern, add to the tag stack
    if (*tag != NUL
        && (type == DT_TAG || type == DT_SELECT || type == DT_JUMP
            || type == DT_LTAG)) {
      if (g_do_tagpreview != 0) {
        if (ptag_entry.tagname != NULL
            && strcmp(ptag_entry.tagname, tag) == 0) {
          // Jumping to same tag: keep the current match, so that
          // the CursorHold autocommand example works.
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else {
          tagstack_clear_entry(&ptag_entry);
          ptag_entry.tagname = xstrdup(tag);
        }
      } else {
        // If the last used entry is not at the top, delete all tag
        // stack entries above it.
        while (tagstackidx < tagstacklen) {
          tagstack_clear_entry(&tagstack[--tagstacklen]);
        }

        // if the tagstack is full: remove oldest entry
        if (++tagstacklen > TAGSTACKSIZE) {
          tagstacklen = TAGSTACKSIZE;
          tagstack_clear_entry(&tagstack[0]);
          for (int i = 1; i < tagstacklen; i++) {
            tagstack[i - 1] = tagstack[i];
          }
          tagstack[--tagstackidx].user_data = NULL;
        }

        // put the tag name in the tag stack
        tagstack[tagstackidx].tagname = xstrdup(tag);

        curwin->w_tagstacklen = tagstacklen;

        save_pos = true;                // save the cursor position below
      }

      new_tag = true;
    } else {
      if (g_do_tagpreview != 0 ? ptag_entry.tagname == NULL
                               : tagstacklen == 0) {
        // empty stack
        emsg(_(e_tag_stack_empty));
        goto end_do_tag;
      }

      if (type == DT_POP) {             // go to older position
        const bool old_KeyTyped = KeyTyped;
        if ((tagstackidx -= count) < 0) {
          emsg(_(e_at_bottom_of_tag_stack));
          if (tagstackidx + count == 0) {
            // We did [num]^T from the bottom of the stack
            tagstackidx = 0;
            goto end_do_tag;
          }
          // We weren't at the bottom of the stack, so jump all the
          // way to the bottom now.
          tagstackidx = 0;
        } else if (tagstackidx >= tagstacklen) {        // count == 0?
          emsg(_(e_at_top_of_tag_stack));
          goto end_do_tag;
        }

        // Make a copy of the fmark, autocommands may invalidate the
        // tagstack before it's used.
        saved_fmark = tagstack[tagstackidx].fmark;
        if (saved_fmark.fnum != curbuf->b_fnum) {
          // Jump to other file. If this fails (e.g. because the
          // file was changed) keep original position in tag stack.
          if (buflist_getfile(saved_fmark.fnum, saved_fmark.mark.lnum,
                              GETF_SETMARK, forceit) == FAIL) {
            tagstackidx = oldtagstackidx;              // back to old posn
            goto end_do_tag;
          }
          // A BufReadPost autocommand may jump to the '" mark, but
          // we don't what that here.
          curwin->w_cursor.lnum = saved_fmark.mark.lnum;
        } else {
          setpcmark();
          curwin->w_cursor.lnum = saved_fmark.mark.lnum;
        }
        curwin->w_cursor.col = saved_fmark.mark.col;
        curwin->w_set_curswant = true;
        check_cursor(curwin);
        if ((fdo_flags & FDO_TAG) && old_KeyTyped) {
          foldOpenCursor();
        }

        // remove the old list of matches
        FreeWild(num_matches, matches);
        num_matches = 0;
        tag_freematch();
        goto end_do_tag;
      }

      if (type == DT_TAG
          || type == DT_LTAG) {
        if (g_do_tagpreview != 0) {
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else {
          // ":tag" (no argument): go to newer pattern
          save_pos = true;              // save the cursor position below
          if ((tagstackidx += count - 1) >= tagstacklen) {
            // Beyond the last one, just give an error message and
            // go to the last one.  Don't store the cursor
            // position.
            tagstackidx = tagstacklen - 1;
            emsg(_(e_at_top_of_tag_stack));
            save_pos = false;
          } else if (tagstackidx < 0) {         // must have been count == 0
            emsg(_(e_at_bottom_of_tag_stack));
            tagstackidx = 0;
            goto end_do_tag;
          }
          cur_match = tagstack[tagstackidx].cur_match;
          cur_fnum = tagstack[tagstackidx].cur_fnum;
        }
        new_tag = true;
      } else {                                // go to other matching tag
        // Save index for when selection is cancelled.
        prevtagstackidx = tagstackidx;

        if (g_do_tagpreview != 0) {
          cur_match = ptag_entry.cur_match;
          cur_fnum = ptag_entry.cur_fnum;
        } else {
          if (--tagstackidx < 0) {
            tagstackidx = 0;
          }
          cur_match = tagstack[tagstackidx].cur_match;
          cur_fnum = tagstack[tagstackidx].cur_fnum;
        }
        switch (type) {
        case DT_FIRST:
          cur_match = count - 1; break;
        case DT_SELECT:
        case DT_JUMP:
        case DT_LAST:
          cur_match = MAXCOL - 1; break;
        case DT_NEXT:
          cur_match += count; break;
        case DT_PREV:
          cur_match -= count; break;
        }
        if (cur_match >= MAXCOL) {
          cur_match = MAXCOL - 1;
        } else if (cur_match < 0) {
          emsg(_("E425: Cannot go before first matching tag"));
          skip_msg = true;
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
    } else {
      // For ":tag [arg]" or ":tselect" remember position before the jump.
      saved_fmark = tagstack[tagstackidx].fmark;
      if (save_pos) {
        tagstack[tagstackidx].fmark.mark = curwin->w_cursor;
        tagstack[tagstackidx].fmark.fnum = curbuf->b_fnum;
      }

      // Curwin will change in the call to jumpto_tag() if ":stag" was
      // used or an autocommand jumps to another window; store value of
      // tagstackidx now.
      curwin->w_tagstackidx = tagstackidx;
      if (type != DT_SELECT && type != DT_JUMP) {
        curwin->w_tagstack[tagstackidx].cur_match = cur_match;
        curwin->w_tagstack[tagstackidx].cur_fnum = cur_fnum;
      }
    }
  }

  // When not using the current buffer get the name of buffer "cur_fnum".
  // Makes sure that the tag order doesn't change when using a remembered
  // position for "cur_match".
  if (cur_fnum != curbuf->b_fnum) {
    buf_T *buf = buflist_findnr(cur_fnum);

    if (buf != NULL) {
      buf_ffname = buf->b_ffname;
    }
  }

  // Repeat searching for tags, when a file has not been found.
  while (true) {
    char *name;

    // When desired match not found yet, try to find it (and others).
    if (use_tagstack) {
      // make a copy, the tagstack may change in 'tagfunc'
      name = xstrdup(tagstack[tagstackidx].tagname);
      xfree(tofree);
      tofree = name;
    } else if (g_do_tagpreview != 0) {
      name = ptag_entry.tagname;
    } else {
      name = tag;
    }
    bool other_name = (tagmatchname == NULL || strcmp(tagmatchname, name) != 0);
    if (new_tag
        || (cur_match >= num_matches && max_num_matches != MAXCOL)
        || other_name) {
      if (other_name) {
        xfree(tagmatchname);
        tagmatchname = xstrdup(name);
      }

      if (type == DT_SELECT || type == DT_JUMP
          || type == DT_LTAG) {
        cur_match = MAXCOL - 1;
      }
      if (type == DT_TAG) {
        max_num_matches = MAXCOL;
      } else {
        max_num_matches = cur_match + 1;
      }

      // when the argument starts with '/', use it as a regexp
      if (!no_regexp && *name == '/') {
        flags = TAG_REGEXP;
        name++;
      } else {
        flags = TAG_NOIC;
      }

      if (verbose) {
        flags |= TAG_VERBOSE;
      }
      if (!use_tfu) {
        flags |= TAG_NO_TAGFUNC;
      }

      if (find_tags(name, &new_num_matches, &new_matches, flags,
                    max_num_matches, buf_ffname) == OK
          && new_num_matches < max_num_matches) {
        max_num_matches = MAXCOL;  // If less than max_num_matches
                                   // found: all matches found.
      }

      // A tag function may do anything, which may cause various
      // information to become invalid.  At least check for the tagstack
      // to still be the same.
      if (tagstack != curwin->w_tagstack) {
        emsg(_(e_window_unexpectedly_close_while_searching_for_tags));
        FreeWild(new_num_matches, new_matches);
        break;
      }

      // If there already were some matches for the same name, move them
      // to the start.  Avoids that the order changes when using
      // ":tnext" and jumping to another file.
      if (!new_tag && !other_name) {
        int idx = 0;
        tagptrs_T tagp, tagp2;

        // Find the position of each old match in the new list.  Need
        // to use parse_match() to find the tag line.
        for (int j = 0; j < num_matches; j++) {
          parse_match(matches[j], &tagp);
          for (int i = idx; i < new_num_matches; i++) {
            parse_match(new_matches[i], &tagp2);
            if (strcmp(tagp.tagname, tagp2.tagname) == 0) {
              char *p = new_matches[i];
              for (int k = i; k > idx; k--) {
                new_matches[k] = new_matches[k - 1];
              }
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
      if (verbose) {
        semsg(_(e_tag_not_found_str), name);
      }
      g_do_tagpreview = 0;
    } else {
      bool ask_for_selection = false;

      if (type == DT_TAG && *tag != NUL) {
        // If a count is supplied to the ":tag <name>" command, then
        // jump to count'th matching tag.
        cur_match = count > 0 ? count - 1 : 0;
      } else if (type == DT_SELECT || (type == DT_JUMP && num_matches > 1)) {
        print_tag_list(new_tag, use_tagstack, num_matches, matches);
        ask_for_selection = true;
      } else if (type == DT_LTAG) {
        if (add_llist_tags(tag, num_matches, matches) == FAIL) {
          goto end_do_tag;
        }

        cur_match = 0;                  // Jump to the first tag
      }

      if (ask_for_selection) {
        // Ask to select a tag from the list.
        int i = prompt_for_number(NULL);
        if (i <= 0 || i > num_matches || got_int) {
          // no valid choice: don't change anything
          if (use_tagstack) {
            tagstack[tagstackidx].fmark = saved_fmark;
            tagstackidx = prevtagstackidx;
          }
          break;
        }
        cur_match = i - 1;
      }

      if (cur_match >= num_matches) {
        // Avoid giving this error when a file wasn't found and we're
        // looking for a match in another file, which wasn't found.
        // There will be an emsg("file doesn't exist") below then.
        if ((type == DT_NEXT || type == DT_FIRST)
            && nofile_fname == NULL) {
          if (num_matches == 1) {
            emsg(_("E427: There is only one matching tag"));
          } else {
            emsg(_("E428: Cannot go beyond last matching tag"));
          }
          skip_msg = true;
        }
        cur_match = num_matches - 1;
      }
      if (use_tagstack) {
        tagptrs_T tagp2;

        tagstack[tagstackidx].cur_match = cur_match;
        tagstack[tagstackidx].cur_fnum = cur_fnum;

        // store user-provided data originating from tagfunc
        if (use_tfu && parse_match(matches[cur_match], &tagp2) == OK
            && tagp2.user_data) {
          XFREE_CLEAR(tagstack[tagstackidx].user_data);
          tagstack[tagstackidx].user_data =
            xmemdupz(tagp2.user_data, (size_t)(tagp2.user_data_end - tagp2.user_data));
        }

        tagstackidx++;
      } else if (g_do_tagpreview != 0) {
        ptag_entry.cur_match = cur_match;
        ptag_entry.cur_fnum = cur_fnum;
      }

      // Only when going to try the next match, report that the previous
      // file didn't exist.  Otherwise an emsg() is given below.
      if (nofile_fname != NULL && error_cur_match != cur_match) {
        smsg(0, _("File \"%s\" does not exist"), nofile_fname);
      }

      bool ic = (matches[cur_match][0] & MT_IC_OFF);
      if (type != DT_TAG && type != DT_SELECT && type != DT_JUMP
          && (num_matches > 1 || ic)
          && !skip_msg) {
        // Give an indication of the number of matching tags
        snprintf(IObuff, sizeof(IObuff), _("tag %d of %d%s"),
                 cur_match + 1,
                 num_matches,
                 max_num_matches != MAXCOL ? _(" or more") : "");
        if (ic) {
          xstrlcat(IObuff, _("  Using tag with different case!"), IOSIZE);
        }
        if ((num_matches > prev_num_matches || new_tag)
            && num_matches > 1) {
          msg(IObuff, ic ? HL_ATTR(HLF_W) : 0);
          msg_scroll = true;  // Don't overwrite this message.
        } else {
          give_warning(IObuff, ic);
        }
        if (ic && !msg_scrolled && msg_silent == 0) {
          ui_flush();
          os_delay(1007, true);
        }
      }

      // Let the SwapExists event know what tag we are jumping to.
      vim_snprintf(IObuff, IOSIZE, ":ta %s\r", name);
      set_vim_var_string(VV_SWAPCOMMAND, IObuff, -1);

      // Jump to the desired match.
      int i = jumpto_tag(matches[cur_match], forceit, true);

      set_vim_var_string(VV_SWAPCOMMAND, NULL, -1);

      if (i == NOTAGFILE) {
        // File not found: try again with another matching tag
        if ((type == DT_PREV && cur_match > 0)
            || ((type == DT_TAG || type == DT_NEXT
                 || type == DT_FIRST)
                && (max_num_matches != MAXCOL
                    || cur_match < num_matches - 1))) {
          error_cur_match = cur_match;
          if (use_tagstack) {
            tagstackidx--;
          }
          if (type == DT_PREV) {
            cur_match--;
          } else {
            type = DT_NEXT;
            cur_match++;
          }
          continue;
        }
        semsg(_("E429: File \"%s\" does not exist"), nofile_fname);
      } else {
        // We may have jumped to another window, check that
        // tagstackidx is still valid.
        if (use_tagstack && tagstackidx > curwin->w_tagstacklen) {
          tagstackidx = curwin->w_tagstackidx;
        }
      }
    }
    break;
  }

end_do_tag:
  // Only store the new index when using the tagstack and it's valid.
  if (use_tagstack && tagstackidx <= curwin->w_tagstacklen) {
    curwin->w_tagstackidx = tagstackidx;
  }
  postponed_split = 0;          // don't split next time
  g_do_tagpreview = 0;          // don't do tag preview next time
  xfree(tofree);
}

// List all the matching tags.
static void print_tag_list(bool new_tag, bool use_tagstack, int num_matches, char **matches)
{
  taggy_T *tagstack = curwin->w_tagstack;
  int tagstackidx = curwin->w_tagstackidx;
  tagptrs_T tagp;

  // Assume that the first match indicates how long the tags can
  // be, and align the file names to that.
  parse_match(matches[0], &tagp);
  int taglen = (int)(tagp.tagname_end - tagp.tagname + 2);
  if (taglen < 18) {
    taglen = 18;
  }
  if (taglen > Columns - 25) {
    taglen = MAXCOL;
  }
  if (msg_col == 0) {
    msg_didout = false;     // overwrite previous message
  }
  msg_start();
  msg_puts_attr(_("  # pri kind tag"), HL_ATTR(HLF_T));
  msg_clr_eos();
  taglen_advance(taglen);
  msg_puts_attr(_("file\n"), HL_ATTR(HLF_T));

  for (int i = 0; i < num_matches && !got_int; i++) {
    parse_match(matches[i], &tagp);
    if (!new_tag && (
                     (g_do_tagpreview != 0
                      && i == ptag_entry.cur_match)
                     || (use_tagstack
                         && i == tagstack[tagstackidx].cur_match))) {
      *IObuff = '>';
    } else {
      *IObuff = ' ';
    }
    vim_snprintf(IObuff + 1, IOSIZE - 1,
                 "%2d %s ", i + 1,
                 mt_names[matches[i][0] & MT_MASK]);
    msg_puts(IObuff);
    if (tagp.tagkind != NULL) {
      msg_outtrans_len(tagp.tagkind, (int)(tagp.tagkind_end - tagp.tagkind), 0);
    }
    msg_advance(13);
    msg_outtrans_len(tagp.tagname, (int)(tagp.tagname_end - tagp.tagname), HL_ATTR(HLF_T));
    msg_putchar(' ');
    taglen_advance(taglen);

    // Find out the actual file name. If it is long, truncate
    // it and put "..." in the middle
    const char *p = tag_full_fname(&tagp);
    if (p != NULL) {
      msg_outtrans(p, HL_ATTR(HLF_D));
      XFREE_CLEAR(p);
    }
    if (msg_col > 0) {
      msg_putchar('\n');
    }
    if (got_int) {
      break;
    }
    msg_advance(15);

    // print any extra fields
    const char *command_end = tagp.command_end;
    if (command_end != NULL) {
      p = command_end + 3;
      while (*p && *p != '\r' && *p != '\n') {
        while (*p == TAB) {
          p++;
        }

        // skip "file:" without a value (static tag)
        if (strncmp(p, "file:", 5) == 0 && ascii_isspace(p[5])) {
          p += 5;
          continue;
        }
        // skip "kind:<kind>" and "<kind>"
        if (p == tagp.tagkind
            || (p + 5 == tagp.tagkind
                && strncmp(p, "kind:", 5) == 0)) {
          p = tagp.tagkind_end;
          continue;
        }
        // print all other extra fields
        int attr = HL_ATTR(HLF_CM);
        while (*p && *p != '\r' && *p != '\n') {
          if (msg_col + ptr2cells(p) >= Columns) {
            msg_putchar('\n');
            if (got_int) {
              break;
            }
            msg_advance(15);
          }
          p = msg_outtrans_one(p, attr);
          if (*p == TAB) {
            msg_puts_attr(" ", attr);
            break;
          }
          if (*p == ':') {
            attr = 0;
          }
        }
      }
      if (msg_col > 15) {
        msg_putchar('\n');
        if (got_int) {
          break;
        }
        msg_advance(15);
      }
    } else {
      for (p = tagp.command;
           *p && *p != '\r' && *p != '\n';
           p++) {}
      command_end = p;
    }

    // Put the info (in several lines) at column 15.
    // Don't display "/^" and "?^".
    p = tagp.command;
    if (*p == '/' || *p == '?') {
      p++;
      if (*p == '^') {
        p++;
      }
    }
    // Remove leading whitespace from pattern
    while (p != command_end && ascii_isspace(*p)) {
      p++;
    }

    while (p != command_end) {
      if (msg_col + (*p == TAB ? 1 : ptr2cells(p)) > Columns) {
        msg_putchar('\n');
      }
      if (got_int) {
        break;
      }
      msg_advance(15);

      // skip backslash used for escaping a command char or
      // a backslash
      if (*p == '\\' && (*(p + 1) == *tagp.command
                         || *(p + 1) == '\\')) {
        p++;
      }

      if (*p == TAB) {
        msg_putchar(' ');
        p++;
      } else {
        p = msg_outtrans_one(p, 0);
      }

      // don't display the "$/;\"" and "$?;\""
      if (p == command_end - 2 && *p == '$'
          && *(p + 1) == *tagp.command) {
        break;
      }
      // don't display matching '/' or '?'
      if (p == command_end - 1 && *p == *tagp.command
          && (*p == '/' || *p == '?')) {
        break;
      }
    }
    if (msg_col) {
      msg_putchar('\n');
    }
    os_breakcheck();
  }
  if (got_int) {
    got_int = false;        // only stop the listing
  }
}

/// Add the matching tags to the location list for the current
/// window.
static int add_llist_tags(char *tag, int num_matches, char **matches)
{
  char tag_name[128 + 1];
  tagptrs_T tagp;

  char *fname = xmalloc(MAXPATHL + 1);
  char *cmd = xmalloc(CMDBUFFSIZE + 1);
  list_T *list = tv_list_alloc(0);

  for (int i = 0; i < num_matches; i++) {
    dict_T *dict;

    parse_match(matches[i], &tagp);

    // Save the tag name
    int len = (int)(tagp.tagname_end - tagp.tagname);
    if (len > 128) {
      len = 128;
    }
    xmemcpyz(tag_name, tagp.tagname, (size_t)len);
    tag_name[len] = NUL;

    // Save the tag file name
    char *p = tag_full_fname(&tagp);
    if (p == NULL) {
      continue;
    }
    xstrlcpy(fname, p, MAXPATHL);
    XFREE_CLEAR(p);

    // Get the line number or the search pattern used to locate
    // the tag.
    linenr_T lnum = 0;
    if (isdigit((uint8_t)(*tagp.command))) {
      // Line number is used to locate the tag
      lnum = atoi(tagp.command);
    } else {
      // Search pattern is used to locate the tag

      // Locate the end of the command
      char *cmd_start = tagp.command;
      char *cmd_end = tagp.command_end;
      if (cmd_end == NULL) {
        for (p = tagp.command;
             *p && *p != '\r' && *p != '\n'; p++) {}
        cmd_end = p;
      }

      // Now, cmd_end points to the character after the
      // command. Adjust it to point to the last
      // character of the command.
      cmd_end--;

      // Skip the '/' and '?' characters at the
      // beginning and end of the search pattern.
      if (*cmd_start == '/' || *cmd_start == '?') {
        cmd_start++;
      }

      if (*cmd_end == '/' || *cmd_end == '?') {
        cmd_end--;
      }

      len = 0;
      cmd[0] = NUL;

      // If "^" is present in the tag search pattern, then
      // copy it first.
      if (*cmd_start == '^') {
        STRCPY(cmd, "^");
        cmd_start++;
        len++;
      }

      // Precede the tag pattern with \V to make it very
      // nomagic.
      STRCAT(cmd, "\\V");
      len += 2;

      int cmd_len = (int)(cmd_end - cmd_start + 1);
      if (cmd_len > (CMDBUFFSIZE - 5)) {
        cmd_len = CMDBUFFSIZE - 5;
      }
      snprintf(cmd + len, (size_t)(CMDBUFFSIZE + 1 - len),
               "%.*s", cmd_len, cmd_start);
      len += cmd_len;

      if (cmd[len - 1] == '$') {
        // Replace '$' at the end of the search pattern
        // with '\$'
        cmd[len - 1] = '\\';
        cmd[len] = '$';
        len++;
      }

      cmd[len] = NUL;
    }

    dict = tv_dict_alloc();
    tv_list_append_dict(list, dict);

    tv_dict_add_str(dict, S_LEN("text"), tag_name);
    tv_dict_add_str(dict, S_LEN("filename"), fname);
    tv_dict_add_nr(dict, S_LEN("lnum"), lnum);
    if (lnum == 0) {
      tv_dict_add_str(dict, S_LEN("pattern"), cmd);
    }
  }

  vim_snprintf(IObuff, IOSIZE, "ltag %s", tag);
  set_errorlist(curwin, list, ' ', IObuff, NULL);

  tv_list_free(list);
  XFREE_CLEAR(fname);
  XFREE_CLEAR(cmd);

  return OK;
}

// Free cached tags.
void tag_freematch(void)
{
  XFREE_CLEAR(tagmatchname);
}

static void taglen_advance(int l)
{
  if (l == MAXCOL) {
    msg_putchar('\n');
    msg_advance(24);
  } else {
    msg_advance(13 + l);
  }
}

// Print the tag stack
void do_tags(exarg_T *eap)
{
  taggy_T *tagstack = curwin->w_tagstack;
  int tagstackidx = curwin->w_tagstackidx;
  int tagstacklen = curwin->w_tagstacklen;

  // Highlight title
  msg_puts_title(_("\n  # TO tag         FROM line  in file/text"));
  for (int i = 0; i < tagstacklen; i++) {
    if (tagstack[i].tagname != NULL) {
      char *name = fm_getname(&(tagstack[i].fmark), 30);
      if (name == NULL) {           // file name not available
        continue;
      }

      msg_putchar('\n');
      vim_snprintf(IObuff, IOSIZE, "%c%2d %2d %-15s %5" PRIdLINENR "  ",
                   i == tagstackidx ? '>' : ' ',
                   i + 1,
                   tagstack[i].cur_match + 1,
                   tagstack[i].tagname,
                   tagstack[i].fmark.mark.lnum);
      msg_outtrans(IObuff, 0);
      msg_outtrans(name, tagstack[i].fmark.fnum == curbuf->b_fnum ? HL_ATTR(HLF_D) : 0);
      xfree(name);
    }
  }
  if (tagstackidx == tagstacklen) {     // idx at top of stack
    msg_puts("\n>");
  }
}

// Compare two strings, for length "len", ignoring case the ASCII way.
// return 0 for match, < 0 for smaller, > 0 for bigger
// Make sure case is folded to uppercase in comparison (like for 'sort -f')
static int tag_strnicmp(char *s1, char *s2, size_t len)
{
  while (len > 0) {
    int i = TOUPPER_ASC((uint8_t)(*s1)) - TOUPPER_ASC((uint8_t)(*s2));
    if (i != 0) {
      return i;                         // this character different
    }
    if (*s1 == NUL) {
      break;                            // strings match until NUL
    }
    s1++;
    s2++;
    len--;
  }
  return 0;                             // strings match
}

// Extract info from the tag search pattern "pats->pat".
static void prepare_pats(pat_T *pats, bool has_re)
{
  pats->head = pats->pat;
  pats->headlen = pats->len;
  if (has_re) {
    // When the pattern starts with '^' or "\\<", binary searching can be
    // used (much faster).
    if (pats->pat[0] == '^') {
      pats->head = pats->pat + 1;
    } else if (pats->pat[0] == '\\' && pats->pat[1] == '<') {
      pats->head = pats->pat + 2;
    }
    if (pats->head == pats->pat) {
      pats->headlen = 0;
    } else {
      for (pats->headlen = 0; pats->head[pats->headlen] != NUL; pats->headlen++) {
        if (vim_strchr(magic_isset() ? ".[~*\\$" : "\\$",
                       (uint8_t)pats->head[pats->headlen]) != NULL) {
          break;
        }
      }
    }
    if (p_tl != 0 && pats->headlen > p_tl) {    // adjust for 'taglength'
      pats->headlen = (int)p_tl;
    }
  }

  if (has_re) {
    pats->regmatch.regprog = vim_regcomp(pats->pat, magic_isset() ? RE_MAGIC : 0);
  } else {
    pats->regmatch.regprog = NULL;
  }
}

/// Call the user-defined function to generate a list of tags used by
/// find_tags().
///
/// Return OK if at least 1 tag has been successfully found,
/// NOTDONE if the function returns v:null, and FAIL otherwise.
///
/// @param pat  pattern supplied to the user-defined function
/// @param ga  the tags will be placed here
/// @param match_count  here the number of tags found will be placed
/// @param flags  flags from find_tags (TAG_*)
/// @param buf_ffname  name of buffer for priority
static int find_tagfunc_tags(char *pat, garray_T *ga, int *match_count, int flags, char *buf_ffname)
{
  int ntags = 0;
  typval_T args[4];
  typval_T rettv;
  char flagString[4];
  taggy_T *tag = NULL;

  if (curwin->w_tagstacklen > 0) {
    if (curwin->w_tagstackidx == curwin->w_tagstacklen) {
      tag = &curwin->w_tagstack[curwin->w_tagstackidx - 1];
    } else {
      tag = &curwin->w_tagstack[curwin->w_tagstackidx];
    }
  }

  if (*curbuf->b_p_tfu == NUL || curbuf->b_tfu_cb.type == kCallbackNone) {
    return FAIL;
  }

  args[0].v_type = VAR_STRING;
  args[0].vval.v_string = pat;
  args[1].v_type = VAR_STRING;
  args[1].vval.v_string = flagString;

  // create 'info' dict argument
  dict_T *const d = tv_dict_alloc_lock(VAR_FIXED);
  if (tag != NULL && tag->user_data != NULL) {
    tv_dict_add_str(d, S_LEN("user_data"), tag->user_data);
  }
  if (buf_ffname != NULL) {
    tv_dict_add_str(d, S_LEN("buf_ffname"), buf_ffname);
  }

  d->dv_refcount++;
  args[2].v_type = VAR_DICT;
  args[2].vval.v_dict = d;

  args[3].v_type = VAR_UNKNOWN;

  vim_snprintf(flagString, sizeof(flagString),
               "%s%s%s",
               g_tag_at_cursor ? "c" : "",
               flags & TAG_INS_COMP ? "i" : "",
               flags & TAG_REGEXP ? "r" : "");

  pos_T save_pos = curwin->w_cursor;
  int result = callback_call(&curbuf->b_tfu_cb, 3, args, &rettv);
  curwin->w_cursor = save_pos;  // restore the cursor position
  d->dv_refcount--;

  if (result == FAIL) {
    return FAIL;
  }
  if (rettv.v_type == VAR_SPECIAL && rettv.vval.v_special == kSpecialVarNull) {
    tv_clear(&rettv);
    return NOTDONE;
  }
  if (rettv.v_type != VAR_LIST || !rettv.vval.v_list) {
    tv_clear(&rettv);
    emsg(_(e_invalid_return_value_from_tagfunc));
    return FAIL;
  }
  list_T *taglist = rettv.vval.v_list;

  TV_LIST_ITER_CONST(taglist, li, {
    char *res_name;
    char *res_fname;
    char *res_cmd;
    char *res_kind;
    bool has_extra = false;
    int name_only = flags & TAG_NAMES;

    if (TV_LIST_ITEM_TV(li)->v_type != VAR_DICT) {
      emsg(_(e_invalid_return_value_from_tagfunc));
      break;
    }

    size_t len = 2;
    res_name = NULL;
    res_fname = NULL;
    res_cmd = NULL;
    res_kind = NULL;

    TV_DICT_ITER(TV_LIST_ITEM_TV(li)->vval.v_dict, di, {
      const char *dict_key = di->di_key;
      typval_T *tv = &di->di_tv;

      if (tv->v_type != VAR_STRING || tv->vval.v_string == NULL) {
        continue;
      }

      len += strlen(tv->vval.v_string) + 1;   // Space for "\tVALUE"
      if (!strcmp(dict_key, "name")) {
        res_name = tv->vval.v_string;
        continue;
      }
      if (!strcmp(dict_key, "filename")) {
        res_fname = tv->vval.v_string;
        continue;
      }
      if (!strcmp(dict_key, "cmd")) {
        res_cmd = tv->vval.v_string;
        continue;
      }
      has_extra = true;
      if (!strcmp(dict_key, "kind")) {
        res_kind = tv->vval.v_string;
        continue;
      }
      // Other elements will be stored as "\tKEY:VALUE"
      // Allocate space for the key and the colon
      len += strlen(dict_key) + 1;
    });

    if (has_extra) {
      len += 2;  // need space for ;"
    }

    if (!res_name || !res_fname || !res_cmd) {
      emsg(_(e_invalid_return_value_from_tagfunc));
      break;
    }

    char *const mfp = name_only ? xstrdup(res_name) : xmalloc(len + 2);

    if (!name_only) {
      char *p = mfp;

      *p++ = MT_GL_OTH + 1;   // mtt
      *p++ = TAG_SEP;     // no tag file name

      STRCPY(p, res_name);
      p += strlen(p);

      *p++ = TAB;
      STRCPY(p, res_fname);
      p += strlen(p);

      *p++ = TAB;
      STRCPY(p, res_cmd);
      p += strlen(p);

      if (has_extra) {
        STRCPY(p, ";\"");
        p += strlen(p);

        if (res_kind) {
          *p++ = TAB;
          STRCPY(p, res_kind);
          p += strlen(p);
        }

        TV_DICT_ITER(TV_LIST_ITEM_TV(li)->vval.v_dict, di, {
          const char *dict_key = di->di_key;
          typval_T *tv = &di->di_tv;
          if (tv->v_type != VAR_STRING || tv->vval.v_string == NULL) {
            continue;
          }

          if (!strcmp(dict_key, "name")) {
            continue;
          }
          if (!strcmp(dict_key, "filename")) {
            continue;
          }
          if (!strcmp(dict_key, "cmd")) {
            continue;
          }
          if (!strcmp(dict_key, "kind")) {
            continue;
          }

          *p++ = TAB;
          STRCPY(p, dict_key);
          p += strlen(p);
          STRCPY(p, ":");
          p += strlen(p);
          STRCPY(p, tv->vval.v_string);
          p += strlen(p);
        });
      }
    }

    // Add all matches because tagfunc should do filtering.
    ga_grow(ga, 1);
    ((char **)(ga->ga_data))[ga->ga_len++] = (char *)mfp;
    ntags++;
    result = OK;
  });

  tv_clear(&rettv);

  *match_count = ntags;
  return result;
}

/// Initialize the state used by find_tags()
static void findtags_state_init(findtags_state_T *st, char *pat, int flags, int mincount)
{
  st->tag_fname = xmalloc(MAXPATHL + 1);
  st->fp = NULL;
  st->orgpat = xmalloc(sizeof(pat_T));
  st->orgpat->pat = pat;
  st->orgpat->len = (int)strlen(pat);
  st->orgpat->regmatch.regprog = NULL;
  st->flags = flags;
  st->tag_file_sorted = NUL;
  st->help_lang_find = NULL;
  st->is_txt = false;
  st->did_open = false;
  st->help_only = (flags & TAG_HELP);
  st->get_searchpat = false;
  st->help_lang[0] = NUL;
  st->help_pri = 0;
  st->mincount = mincount;
  st->lbuf_size = LSIZE;
  st->lbuf = xmalloc((size_t)st->lbuf_size);
  st->match_count = 0;
  st->stop_searching = false;

  for (int mtt = 0; mtt < MT_COUNT; mtt++) {
    ga_init(&st->ga_match[mtt], sizeof(char *), 100);
    hash_init(&st->ht_match[mtt]);
  }
}

/// Free the state used by find_tags()
static void findtags_state_free(findtags_state_T *st)
{
  xfree(st->tag_fname);
  xfree(st->lbuf);
  vim_regfree(st->orgpat->regmatch.regprog);
  xfree(st->orgpat);
}

/// Initialize the language and priority used for searching tags in a Vim help
/// file.
/// Returns true to process the help file for tags and false to skip the file.
static bool findtags_in_help_init(findtags_state_T *st)
{
  int i;

  // Keep "en" as the language if the file extension is ".txt"
  if (st->is_txt) {
    STRCPY(st->help_lang, "en");
  } else {
    // Prefer help tags according to 'helplang'.  Put the two-letter
    // language name in help_lang[].
    i = (int)strlen(st->tag_fname);
    if (i > 3 && st->tag_fname[i - 3] == '-') {
      xmemcpyz(st->help_lang, st->tag_fname + i - 2, 2);
    } else {
      STRCPY(st->help_lang, "en");
    }
  }
  // When searching for a specific language skip tags files for other
  // languages.
  if (st->help_lang_find != NULL
      && STRICMP(st->help_lang, st->help_lang_find) != 0) {
    return false;
  }

  // For CTRL-] in a help file prefer a match with the same language.
  if ((st->flags & TAG_KEEP_LANG)
      && st->help_lang_find == NULL
      && curbuf->b_fname != NULL
      && (i = (int)strlen(curbuf->b_fname)) > 4
      && curbuf->b_fname[i - 1] == 'x'
      && curbuf->b_fname[i - 4] == '.'
      && STRNICMP(curbuf->b_fname + i - 3, st->help_lang, 2) == 0) {
    st->help_pri = 0;
  } else {
    st->help_pri = 1;
    char *s;
    for (s = p_hlg; *s != NUL; s++) {
      if (STRNICMP(s, st->help_lang, 2) == 0) {
        break;
      }
      st->help_pri++;
      if ((s = vim_strchr(s, ',')) == NULL) {
        break;
      }
    }
    if (s == NULL || *s == NUL) {
      // Language not in 'helplang': use last, prefer English, unless
      // found already.
      st->help_pri++;
      if (STRICMP(st->help_lang, "en") != 0) {
        st->help_pri++;
      }
    }
  }

  return true;
}

/// Use the function set in 'tagfunc' (if configured and enabled) to get the
/// tags.
/// Return OK if at least 1 tag has been successfully found, NOTDONE if the
/// 'tagfunc' is not used or the 'tagfunc' returns v:null and FAIL otherwise.
static int findtags_apply_tfu(findtags_state_T *st, char *pat, char *buf_ffname)
{
  const bool use_tfu = ((st->flags & TAG_NO_TAGFUNC) == 0);

  if (!use_tfu || tfu_in_use || *curbuf->b_p_tfu == NUL) {
    return NOTDONE;
  }

  tfu_in_use = true;
  int retval = find_tagfunc_tags(pat, st->ga_match, &st->match_count,
                                 st->flags, buf_ffname);
  tfu_in_use = false;

  return retval;
}

/// Read the next line from a tags file.
/// Returns TAGS_READ_SUCCESS if a tags line is successfully read and should be
/// processed.
/// Returns TAGS_READ_EOF if the end of file is reached.
/// Returns TAGS_READ_IGNORE if the current line should be ignored (used when
/// reached end of a emacs included tags file)
static tags_read_status_T findtags_get_next_line(findtags_state_T *st, tagsearch_info_T *sinfo_p)
{
  bool eof;

  // For binary search: compute the next offset to use.
  if (st->state == TS_BINARY) {
    off_T offset = sinfo_p->low_offset + ((sinfo_p->high_offset - sinfo_p->low_offset) / 2);
    if (offset == sinfo_p->curr_offset) {
      return TAGS_READ_EOF;  // End the binary search without a match.
    } else {
      sinfo_p->curr_offset = offset;
    }
  } else if (st->state == TS_SKIP_BACK) {
    // Skipping back (after a match during binary search).
    sinfo_p->curr_offset -= st->lbuf_size * 2;
    if (sinfo_p->curr_offset < 0) {
      sinfo_p->curr_offset = 0;
      fseek(st->fp, 0, SEEK_SET);
      st->state = TS_STEP_FORWARD;
    }
  }

  // When jumping around in the file, first read a line to find the
  // start of the next line.
  if (st->state == TS_BINARY || st->state == TS_SKIP_BACK) {
    // Adjust the search file offset to the correct position
    sinfo_p->curr_offset_used = sinfo_p->curr_offset;
    vim_ignored = vim_fseek(st->fp, sinfo_p->curr_offset, SEEK_SET);
    eof = vim_fgets(st->lbuf, st->lbuf_size, st->fp);
    if (!eof && sinfo_p->curr_offset != 0) {
      sinfo_p->curr_offset = vim_ftell(st->fp);
      if (sinfo_p->curr_offset == sinfo_p->high_offset) {
        // oops, gone a bit too far; try from low offset
        vim_ignored = vim_fseek(st->fp, sinfo_p->low_offset, SEEK_SET);
        sinfo_p->curr_offset = sinfo_p->low_offset;
      }
      eof = vim_fgets(st->lbuf, st->lbuf_size, st->fp);
    }
    // skip empty and blank lines
    while (!eof && vim_isblankline(st->lbuf)) {
      sinfo_p->curr_offset = vim_ftell(st->fp);
      eof = vim_fgets(st->lbuf, st->lbuf_size, st->fp);
    }
    if (eof) {
      // Hit end of file.  Skip backwards.
      st->state = TS_SKIP_BACK;
      sinfo_p->match_offset = vim_ftell(st->fp);
      sinfo_p->curr_offset = sinfo_p->curr_offset_used;
      return TAGS_READ_IGNORE;
    }
  } else {
    // Not jumping around in the file: Read the next line.

    // skip empty and blank lines
    do {
      eof = vim_fgets(st->lbuf, st->lbuf_size, st->fp);
    } while (!eof && vim_isblankline(st->lbuf));

    if (eof) {
      return TAGS_READ_EOF;
    }
  }

  return TAGS_READ_SUCCESS;
}

/// Parse a tags file header line in "st->lbuf".
/// Returns true if the current line in st->lbuf is not a tags header line and
/// should be parsed as a regular tag line. Returns false if the line is a
/// header line and the next header line should be read.
static bool findtags_hdr_parse(findtags_state_T *st)
{
  // Header lines in a tags file start with "!_TAG_"
  if (strncmp(st->lbuf, "!_TAG_", 6) != 0) {
    // Non-header item before the header, e.g. "!" itself.
    return true;
  }

  // Process the header line.
  if (strncmp(st->lbuf, "!_TAG_FILE_SORTED\t", 18) == 0) {
    st->tag_file_sorted = (uint8_t)st->lbuf[18];
  }
  if (strncmp(st->lbuf, "!_TAG_FILE_ENCODING\t", 20) == 0) {
    // Prepare to convert every line from the specified encoding to
    // 'encoding'.
    char *p;
    for (p = st->lbuf + 20; *p > ' ' && *p < 127; p++) {}
    *p = NUL;
    convert_setup(&st->vimconv, st->lbuf + 20, p_enc);
  }

  // Read the next line.  Unrecognized flags are ignored.
  return false;
}

/// Handler to initialize the state when starting to process a new tags file.
/// Called in the TS_START state when finding tags from a tags file.
/// Returns true if the line read from the tags file should be parsed and
/// false if the line should be ignored.
static bool findtags_start_state_handler(findtags_state_T *st, bool *sortic,
                                         tagsearch_info_T *sinfo_p)
{
  const bool noic = (st->flags & TAG_NOIC);

  // The header ends when the line sorts below "!_TAG_".  When case is
  // folded lower case letters sort before "_".
  if (strncmp(st->lbuf, "!_TAG_", 6) <= 0
      || (st->lbuf[0] == '!' && ASCII_ISLOWER(st->lbuf[1]))) {
    return findtags_hdr_parse(st);
  }

  // Headers ends.

  // When there is no tag head, or ignoring case, need to do a
  // linear search.
  // When no "!_TAG_" is found, default to binary search.  If
  // the tag file isn't sorted, the second loop will find it.
  // When "!_TAG_FILE_SORTED" found: start binary search if
  // flag set.
  if (st->linear) {
    st->state = TS_LINEAR;
  } else if (st->tag_file_sorted == NUL) {
    st->state = TS_BINARY;
  } else if (st->tag_file_sorted == '1') {
    st->state = TS_BINARY;
  } else if (st->tag_file_sorted == '2') {
    st->state = TS_BINARY;
    *sortic = true;
    st->orgpat->regmatch.rm_ic = (p_ic || !noic);
  } else {
    st->state = TS_LINEAR;
  }

  if (st->state == TS_BINARY && st->orgpat->regmatch.rm_ic && !*sortic) {
    // Binary search won't work for ignoring case, use linear
    // search.
    st->linear = true;
    st->state = TS_LINEAR;
  }

  // When starting a binary search, get the size of the file and
  // compute the first offset.
  if (st->state == TS_BINARY) {
    if (vim_fseek(st->fp, 0, SEEK_END) != 0) {
      // can't seek, don't use binary search
      st->state = TS_LINEAR;
    } else {
      // Get the tag file size.
      // Don't use lseek(), it doesn't work
      // properly on MacOS Catalina.
      const off_T filesize = vim_ftell(st->fp);
      vim_ignored = vim_fseek(st->fp, 0, SEEK_SET);

      // Calculate the first read offset in the file.  Start
      // the search in the middle of the file.
      sinfo_p->low_offset = 0;
      sinfo_p->low_char = 0;
      sinfo_p->high_offset = filesize;
      sinfo_p->curr_offset = 0;
      sinfo_p->high_char = 0xff;
    }
    return false;
  }

  return true;
}

/// Parse a tag line read from a tags file.
/// Also compares the tag name in "tagpp->tagname" with a search pattern in
/// "st->orgpat->head" as a quick check if the tag may match.
/// Returns:
/// - TAG_MATCH_SUCCESS if the tag may match
/// - TAG_MATCH_FAIL if the tag doesn't match
/// - TAG_MATCH_NEXT to look for the next matching tag (used in a binary search)
/// - TAG_MATCH_STOP if all the tags are processed without a match.
/// Uses the values in "margs" for doing the comparison.
static tagmatch_status_T findtags_parse_line(findtags_state_T *st, tagptrs_T *tagpp,
                                             findtags_match_args_T *margs,
                                             tagsearch_info_T *sinfo_p)
{
  int status;

  // Figure out where the different strings are in this line.
  // For "normal" tags: Do a quick check if the tag matches.
  // This speeds up tag searching a lot!
  if (st->orgpat->headlen) {
    CLEAR_FIELD(*tagpp);
    tagpp->tagname = st->lbuf;
    tagpp->tagname_end = vim_strchr(st->lbuf, TAB);
    if (tagpp->tagname_end == NULL) {
      // Corrupted tag line.
      return TAG_MATCH_FAIL;
    }

    // Skip this line if the length of the tag is different and
    // there is no regexp, or the tag is too short.
    int cmplen = (int)(tagpp->tagname_end - tagpp->tagname);
    if (p_tl != 0 && cmplen > p_tl) {  // adjust for 'taglength'
      cmplen = (int)p_tl;
    }
    if ((st->flags & TAG_REGEXP) && st->orgpat->headlen < cmplen) {
      cmplen = st->orgpat->headlen;
    } else if (st->state == TS_LINEAR && st->orgpat->headlen != cmplen) {
      return TAG_MATCH_NEXT;
    }

    if (st->state == TS_BINARY) {
      int tagcmp;
      // Simplistic check for unsorted tags file.
      int i = (uint8_t)tagpp->tagname[0];
      if (margs->sortic) {
        i = TOUPPER_ASC(tagpp->tagname[0]);
      }
      if (i < sinfo_p->low_char || i > sinfo_p->high_char) {
        margs->sort_error = true;
      }

      // Compare the current tag with the searched tag.
      if (margs->sortic) {
        tagcmp = tag_strnicmp(tagpp->tagname, st->orgpat->head,
                              (size_t)cmplen);
      } else {
        tagcmp = strncmp(tagpp->tagname, st->orgpat->head, (size_t)cmplen);
      }

      // A match with a shorter tag means to search forward.
      // A match with a longer tag means to search backward.
      if (tagcmp == 0) {
        if (cmplen < st->orgpat->headlen) {
          tagcmp = -1;
        } else if (cmplen > st->orgpat->headlen) {
          tagcmp = 1;
        }
      }

      if (tagcmp == 0) {
        // We've located the tag, now skip back and search
        // forward until the first matching tag is found.
        st->state = TS_SKIP_BACK;
        sinfo_p->match_offset = sinfo_p->curr_offset;
        return TAG_MATCH_NEXT;
      }
      if (tagcmp < 0) {
        sinfo_p->curr_offset = vim_ftell(st->fp);
        if (sinfo_p->curr_offset < sinfo_p->high_offset) {
          sinfo_p->low_offset = sinfo_p->curr_offset;
          if (margs->sortic) {
            sinfo_p->low_char = TOUPPER_ASC(tagpp->tagname[0]);
          } else {
            sinfo_p->low_char = (uint8_t)tagpp->tagname[0];
          }
          return TAG_MATCH_NEXT;
        }
      }
      if (tagcmp > 0 && sinfo_p->curr_offset != sinfo_p->high_offset) {
        sinfo_p->high_offset = sinfo_p->curr_offset;
        if (margs->sortic) {
          sinfo_p->high_char = TOUPPER_ASC(tagpp->tagname[0]);
        } else {
          sinfo_p->high_char = (uint8_t)tagpp->tagname[0];
        }
        return TAG_MATCH_NEXT;
      }

      // No match yet and are at the end of the binary search.
      return TAG_MATCH_STOP;
    } else if (st->state == TS_SKIP_BACK) {
      assert(cmplen >= 0);
      if (mb_strnicmp(tagpp->tagname, st->orgpat->head, (size_t)cmplen) != 0) {
        st->state = TS_STEP_FORWARD;
      } else {
        // Have to skip back more.  Restore the curr_offset
        // used, otherwise we get stuck at a long line.
        sinfo_p->curr_offset = sinfo_p->curr_offset_used;
      }
      return TAG_MATCH_NEXT;
    } else if (st->state == TS_STEP_FORWARD) {
      assert(cmplen >= 0);
      if (mb_strnicmp(tagpp->tagname, st->orgpat->head, (size_t)cmplen) != 0) {
        if ((off_T)vim_ftell(st->fp) > sinfo_p->match_offset) {
          return TAG_MATCH_STOP;      // past last match
        } else {
          return TAG_MATCH_NEXT;      // before first match
        }
      }
    } else {
      // skip this match if it can't match
      assert(cmplen >= 0);
      if (mb_strnicmp(tagpp->tagname, st->orgpat->head, (size_t)cmplen) != 0) {
        return TAG_MATCH_NEXT;
      }
    }

    // Can be a matching tag, isolate the file name and command.
    tagpp->fname = tagpp->tagname_end + 1;
    tagpp->fname_end = vim_strchr(tagpp->fname, TAB);
    if (tagpp->fname_end == NULL) {
      status = FAIL;
    } else {
      tagpp->command = tagpp->fname_end + 1;
      status = OK;
    }
  } else {
    status = parse_tag_line(st->lbuf, tagpp);
  }

  if (status == FAIL) {
    return TAG_MATCH_FAIL;
  }

  return TAG_MATCH_SUCCESS;
}

/// Initialize the structure used for tag matching.
static void findtags_matchargs_init(findtags_match_args_T *margs, int flags)
{
  margs->matchoff = 0;                        // match offset
  margs->match_re = false;                    // match with regexp
  margs->match_no_ic = false;                 // matches with case
  margs->has_re = (flags & TAG_REGEXP);       // regexp used
  margs->sortic = false;                      // tag file sorted in nocase
  margs->sort_error = false;                  // tags file not sorted
}

/// Compares the tag name in "tagpp->tagname" with a search pattern in
/// "st->orgpat->pat".
/// Returns true if the tag matches, false if the tag doesn't match.
/// Uses the values in "margs" for doing the comparison.
static bool findtags_match_tag(findtags_state_T *st, tagptrs_T *tagpp, findtags_match_args_T *margs)
{
  bool match = false;

  // First try matching with the pattern literally (also when it is
  // a regexp).
  int cmplen = (int)(tagpp->tagname_end - tagpp->tagname);
  if (p_tl != 0 && cmplen > p_tl) {           // adjust for 'taglength'
    cmplen = (int)p_tl;
  }
  // if tag length does not match, don't try comparing
  if (st->orgpat->len != cmplen) {
    match = false;
  } else {
    if (st->orgpat->regmatch.rm_ic) {
      assert(cmplen >= 0);
      match = mb_strnicmp(tagpp->tagname, st->orgpat->pat, (size_t)cmplen) == 0;
      if (match) {
        margs->match_no_ic = strncmp(tagpp->tagname, st->orgpat->pat, (size_t)cmplen) == 0;
      }
    } else {
      match = strncmp(tagpp->tagname, st->orgpat->pat, (size_t)cmplen) == 0;
    }
  }

  // Has a regexp: Also find tags matching regexp.
  margs->match_re = false;
  if (!match && st->orgpat->regmatch.regprog != NULL) {
    char cc = *tagpp->tagname_end;
    *tagpp->tagname_end = NUL;
    match = vim_regexec(&st->orgpat->regmatch, tagpp->tagname, 0);
    if (match) {
      margs->matchoff = (int)(st->orgpat->regmatch.startp[0] - tagpp->tagname);
      if (st->orgpat->regmatch.rm_ic) {
        st->orgpat->regmatch.rm_ic = false;
        margs->match_no_ic = vim_regexec(&st->orgpat->regmatch,
                                         tagpp->tagname, 0);
        st->orgpat->regmatch.rm_ic = true;
      }
    }
    *tagpp->tagname_end = cc;
    margs->match_re = true;
  }

  return match;
}

/// Convert the encoding of a line read from a tags file in "st->lbuf".
/// Converting the pattern from 'enc' to the tags file encoding doesn't work,
/// because characters are not recognized. The converted line is saved in
/// st->lbuf.
static void findtags_string_convert(findtags_state_T *st)
{
  char *conv_line = string_convert(&st->vimconv, st->lbuf, NULL);
  if (conv_line == NULL) {
    return;
  }

  // Copy or swap lbuf and conv_line.
  int len = (int)strlen(conv_line) + 1;
  if (len > st->lbuf_size) {
    xfree(st->lbuf);
    st->lbuf = conv_line;
    st->lbuf_size = len;
  } else {
    STRCPY(st->lbuf, conv_line);
    xfree(conv_line);
  }
}

/// Add a matching tag found in a tags file to st->ht_match and st->ga_match.
static void findtags_add_match(findtags_state_T *st, tagptrs_T *tagpp, findtags_match_args_T *margs,
                               char *buf_ffname, hash_T *hash)
{
  const bool name_only = (st->flags & TAG_NAMES);
  int mtt;
  size_t len = 0;
  size_t mfp_size = 0;
  bool is_current;             // file name matches
  bool is_static;              // current tag line is static
  char *mfp;

  // Decide in which array to store this match.
  is_current = test_for_current(tagpp->fname, tagpp->fname_end,
                                st->tag_fname, buf_ffname);
  is_static = test_for_static(tagpp);

  // Decide in which of the sixteen tables to store this match.
  if (is_static) {
    if (is_current) {
      mtt = MT_ST_CUR;
    } else {
      mtt = MT_ST_OTH;
    }
  } else {
    if (is_current) {
      mtt = MT_GL_CUR;
    } else {
      mtt = MT_GL_OTH;
    }
  }
  if (st->orgpat->regmatch.rm_ic && !margs->match_no_ic) {
    mtt += MT_IC_OFF;
  }
  if (margs->match_re) {
    mtt += MT_RE_OFF;
  }

  // Add the found match in ht_match[mtt] and ga_match[mtt].
  // Store the info we need later, which depends on the kind of
  // tags we are dealing with.
  if (st->help_only) {
#define ML_EXTRA 3
    // Append the help-heuristic number after the tagname, for
    // sorting it later.  The heuristic is ignored for
    // detecting duplicates.
    // The format is {tagname}@{lang}NUL{heuristic}NUL
    *tagpp->tagname_end = NUL;
    len = (size_t)(tagpp->tagname_end - tagpp->tagname);
    mfp_size = sizeof(char) + len + 10 + ML_EXTRA + 1;
    mfp = xmalloc(mfp_size);

    char *p = mfp;
    STRCPY(p, tagpp->tagname);
    p[len] = '@';
    STRCPY(p + len + 1, st->help_lang);
    snprintf(p + len + 1 + ML_EXTRA, mfp_size - (len + 1 + ML_EXTRA), "%06d",
             help_heuristic(tagpp->tagname,
                            margs->match_re ? margs->matchoff : 0,
                            !margs->match_no_ic) + st->help_pri);

    *tagpp->tagname_end = TAB;
  } else if (name_only) {
    if (st->get_searchpat) {
      char *temp_end = tagpp->command;

      if (*temp_end == '/') {
        while (*temp_end && *temp_end != '\r'
               && *temp_end != '\n'
               && *temp_end != '$') {
          temp_end++;
        }
      }

      if (tagpp->command + 2 < temp_end) {
        len = (size_t)(temp_end - tagpp->command - 2);
        mfp = xmalloc(len + 2);
        xmemcpyz(mfp, tagpp->command + 2, len);
      } else {
        mfp = NULL;
      }
      st->get_searchpat = false;
    } else {
      len = (size_t)(tagpp->tagname_end - tagpp->tagname);
      mfp = xmalloc(sizeof(char) + len + 1);
      xmemcpyz(mfp, tagpp->tagname, len);

      // if wanted, re-read line to get long form too
      if (State & MODE_INSERT) {
        st->get_searchpat = p_sft;
      }
    }
  } else {
    size_t tag_fname_len = strlen(st->tag_fname);
    // Save the tag in a buffer.
    // Use 0x02 to separate fields (Can't use NUL, because the
    // hash key is terminated by NUL).
    // Emacs tag: <mtt><tag_fname><0x02><ebuf><0x02><lbuf><NUL>
    // other tag: <mtt><tag_fname><0x02><0x02><lbuf><NUL>
    // without Emacs tags: <mtt><tag_fname><0x02><lbuf><NUL>
    // Here <mtt> is the "mtt" value plus 1 to avoid NUL.
    len = tag_fname_len + strlen(st->lbuf) + 3;
    mfp = xmalloc(sizeof(char) + len + 1);
    char *p = mfp;
    p[0] = (char)(mtt + 1);
    STRCPY(p + 1, st->tag_fname);
#ifdef BACKSLASH_IN_FILENAME
    // Ignore differences in slashes, avoid adding
    // both path/file and path\file.
    slash_adjust(p + 1);
#endif
    p[tag_fname_len + 1] = TAG_SEP;
    char *s = p + 1 + tag_fname_len + 1;
    STRCPY(s, st->lbuf);
  }

  if (mfp != NULL) {
    hashitem_T *hi;

    // Don't add identical matches.
    // "mfp" is used as a hash key, there is a NUL byte to end
    // the part that matters for comparing, more bytes may
    // follow after it.  E.g. help tags store the priority
    // after the NUL.
    *hash = hash_hash(mfp);
    hi = hash_lookup(&st->ht_match[mtt], mfp, strlen(mfp), *hash);
    if (HASHITEM_EMPTY(hi)) {
      hash_add_item(&st->ht_match[mtt], hi, mfp, *hash);
      GA_APPEND(char *, &st->ga_match[mtt], mfp);
      st->match_count++;
    } else {
      // duplicate tag, drop it
      xfree(mfp);
    }
  }
}

/// Read and get all the tags from file st->tag_fname.
/// Sets "st->stop_searching" to true to stop searching for additional tags.
static void findtags_get_all_tags(findtags_state_T *st, findtags_match_args_T *margs,
                                  char *buf_ffname)
{
  tagptrs_T tagp;
  tagsearch_info_T search_info;
  hash_T hash = 0;

  // This is only to avoid a compiler warning for using search_info
  // uninitialised.
  CLEAR_FIELD(search_info);

  // Read and parse the lines in the file one by one
  while (true) {
    // check for CTRL-C typed, more often when jumping around
    if (st->state == TS_BINARY || st->state == TS_SKIP_BACK) {
      line_breakcheck();
    } else {
      fast_breakcheck();
    }
    if ((st->flags & TAG_INS_COMP)) {   // Double brackets for gcc
      ins_compl_check_keys(30, false);
    }
    if (got_int || ins_compl_interrupted()) {
      st->stop_searching = true;
      break;
    }
    // When mincount is TAG_MANY, stop when enough matches have been
    // found (for completion).
    if (st->mincount == TAG_MANY && st->match_count >= TAG_MANY) {
      st->stop_searching = true;
      break;
    }
    if (st->get_searchpat) {
      goto line_read_in;
    }

    int retval = (int)findtags_get_next_line(st, &search_info);
    if (retval == TAGS_READ_IGNORE) {
      continue;
    }
    if (retval == TAGS_READ_EOF) {
      break;
    }

line_read_in:

    if (st->vimconv.vc_type != CONV_NONE) {
      findtags_string_convert(st);
    }

    // When still at the start of the file, check for Emacs tags file
    // format, and for "not sorted" flag.
    if (st->state == TS_START) {
      if (!findtags_start_state_handler(st, &margs->sortic, &search_info)) {
        continue;
      }
    }

    // When the line is too long the NUL will not be in the
    // last-but-one byte (see vim_fgets()).
    // Has been reported for Mozilla JS with extremely long names.
    // In that case we need to increase lbuf_size.
    if (st->lbuf[st->lbuf_size - 2] != NUL) {
      st->lbuf_size *= 2;
      xfree(st->lbuf);
      st->lbuf = xmalloc((size_t)st->lbuf_size);

      if (st->state == TS_STEP_FORWARD || st->state == TS_LINEAR) {
        // Seek to the same position to read the same line again
        vim_ignored = vim_fseek(st->fp, search_info.curr_offset, SEEK_SET);
      }
      // this will try the same thing again, make sure the offset is
      // different
      search_info.curr_offset = 0;
      continue;
    }

    retval = (int)findtags_parse_line(st, &tagp, margs, &search_info);
    if (retval == TAG_MATCH_NEXT) {
      continue;
    }
    if (retval == TAG_MATCH_STOP) {
      break;
    }
    if (retval == TAG_MATCH_FAIL) {
      semsg(_("E431: Format error in tags file \"%s\""), st->tag_fname);
      semsg(_("Before byte %" PRId64), (int64_t)vim_ftell(st->fp));
      st->stop_searching = true;
      return;
    }

    // If a match is found, add it to ht_match[] and ga_match[].
    if (findtags_match_tag(st, &tagp, margs)) {
      findtags_add_match(st, &tagp, margs, buf_ffname, &hash);
    }
  }  // forever
}

/// Search for tags matching "st->orgpat.pat" in the "st->tag_fname" tags file.
/// Information needed to search for the tags is in the "st" state structure.
/// The matching tags are returned in "st". If an error is encountered, then
/// "st->stop_searching" is set to true.
static void findtags_in_file(findtags_state_T *st, int flags, char *buf_ffname)
{
  findtags_match_args_T margs;

  st->vimconv.vc_type = CONV_NONE;
  st->tag_file_sorted = NUL;
  st->fp = NULL;
  findtags_matchargs_init(&margs, st->flags);

  // A file that doesn't exist is silently ignored.  Only when not a
  // single file is found, an error message is given (further on).
  if (curbuf->b_help) {
    if (!findtags_in_help_init(st)) {
      return;
    }
  }

  st->fp = os_fopen(st->tag_fname, "r");
  if (st->fp == NULL) {
    return;
  }

  if (p_verbose >= 5) {
    verbose_enter();
    smsg(0, _("Searching tags file %s"), st->tag_fname);
    verbose_leave();
  }
  st->did_open = true;   // remember that we found at least one file

  st->state = TS_START;  // we're at the start of the file

  // Read and parse the lines in the file one by one
  findtags_get_all_tags(st, &margs, buf_ffname);

  if (st->fp != NULL) {
    fclose(st->fp);
    st->fp = NULL;
  }
  if (st->vimconv.vc_type != CONV_NONE) {
    convert_setup(&st->vimconv, NULL, NULL);
  }

  if (margs.sort_error) {
    semsg(_("E432: Tags file not sorted: %s"), st->tag_fname);
  }

  // Stop searching if sufficient tags have been found.
  if (st->match_count >= st->mincount) {
    st->stop_searching = true;
  }
}

/// Copy the tags found by find_tags() to "matchesp".
/// Returns the number of matches copied.
static int findtags_copy_matches(findtags_state_T *st, char ***matchesp)
{
  const bool name_only = (st->flags & TAG_NAMES);
  char **matches;

  if (st->match_count > 0) {
    matches = xmalloc((size_t)st->match_count * sizeof(char *));
  } else {
    matches = NULL;
  }
  st->match_count = 0;
  for (int mtt = 0; mtt < MT_COUNT; mtt++) {
    for (int i = 0; i < st->ga_match[mtt].ga_len; i++) {
      char *mfp = ((char **)(st->ga_match[mtt].ga_data))[i];
      if (matches == NULL) {
        xfree(mfp);
      } else {
        if (!name_only) {
          // Change mtt back to zero-based.
          *mfp = (char)(*mfp - 1);

          // change the TAG_SEP back to NUL
          for (char *p = mfp + 1; *p != NUL; p++) {
            if (*p == TAG_SEP) {
              *p = NUL;
            }
          }
        }
        matches[st->match_count++] = mfp;
      }
    }

    ga_clear(&st->ga_match[mtt]);
    hash_clear(&st->ht_match[mtt]);
  }

  *matchesp = matches;
  return st->match_count;
}

/// find_tags() - search for tags in tags files
///
/// Return FAIL if search completely failed (*num_matches will be 0, *matchesp
/// will be NULL), OK otherwise.
///
/// There is a priority in which type of tag is recognized.
///
///  6.  A static or global tag with a full matching tag for the current file.
///  5.  A global tag with a full matching tag for another file.
///  4.  A static tag with a full matching tag for another file.
///  3.  A static or global tag with an ignore-case matching tag for the
///      current file.
///  2.  A global tag with an ignore-case matching tag for another file.
///  1.  A static tag with an ignore-case matching tag for another file.
///
/// Tags in an emacs-style tags file are always global.
///
/// flags:
/// TAG_HELP       only search for help tags
/// TAG_NAMES      only return name of tag
/// TAG_REGEXP     use "pat" as a regexp
/// TAG_NOIC       don't always ignore case
/// TAG_KEEP_LANG  keep language
/// TAG_NO_TAGFUNC do not call the 'tagfunc' function
///
/// @param pat  pattern to search for
/// @param num_matches  return: number of matches found
/// @param matchesp  return: array of matches found
/// @param mincount  MAXCOL: find all matches
///                  other: minimal number of matches
/// @param buf_ffname  name of buffer for priority
int find_tags(char *pat, int *num_matches, char ***matchesp, int flags, int mincount,
              char *buf_ffname)
{
  findtags_state_T st;
  tagname_T tn;                         // info for get_tagfname()
  int first_file;                       // trying first tag file
  int retval = FAIL;                    // return value

  int i;
  char *saved_pat = NULL;                // copy of pat[]

  int findall = (mincount == MAXCOL || mincount == TAG_MANY);  // find all matching tags
  bool has_re = (flags & TAG_REGEXP);            // regexp used
  int noic = (flags & TAG_NOIC);
  int verbose = (flags & TAG_VERBOSE);
  int save_p_ic = p_ic;

  // uncrustify:off

  // Change the value of 'ignorecase' according to 'tagcase' for the
  // duration of this function.
  switch (curbuf->b_tc_flags ? curbuf->b_tc_flags : tc_flags) {
  case TC_FOLLOWIC: break;
  case TC_IGNORE:
    p_ic = true;
    break;
  case TC_MATCH:
    p_ic = false;
    break;
  case TC_FOLLOWSCS:
    p_ic = ignorecase(pat);
    break;
  case TC_SMART:
    p_ic = ignorecase_opt(pat, true, true);
    break;
  default:
    abort();
  }

  // uncrustify:on

  int help_save = curbuf->b_help;

  findtags_state_init(&st, pat, flags, mincount);

  // Initialize a few variables
  if (st.help_only) {                           // want tags from help file
    curbuf->b_help = true;                      // will be restored later
  }

  if (curbuf->b_help) {
    // When "@ab" is specified use only the "ab" language, otherwise
    // search all languages.
    if (st.orgpat->len > 3 && pat[st.orgpat->len - 3] == '@'
        && ASCII_ISALPHA(pat[st.orgpat->len - 2])
        && ASCII_ISALPHA(pat[st.orgpat->len - 1])) {
      saved_pat = xstrnsave(pat, (size_t)st.orgpat->len - 3);
      st.help_lang_find = &pat[st.orgpat->len - 2];
      st.orgpat->pat = saved_pat;
      st.orgpat->len -= 3;
    }
  }
  if (p_tl != 0 && st.orgpat->len > p_tl) {  // adjust for 'taglength'
    st.orgpat->len = (int)p_tl;
  }

  int save_emsg_off = emsg_off;
  emsg_off = true;    // don't want error for invalid RE here
  prepare_pats(st.orgpat, has_re);
  emsg_off = save_emsg_off;
  if (has_re && st.orgpat->regmatch.regprog == NULL) {
    goto findtag_end;
  }

  retval = findtags_apply_tfu(&st, pat, buf_ffname);
  if (retval != NOTDONE) {
    goto findtag_end;
  }

  // re-initialize the default return value
  retval = FAIL;

  // Set a flag if the file extension is .txt
  if ((flags & TAG_KEEP_LANG)
      && st.help_lang_find == NULL
      && curbuf->b_fname != NULL
      && (i = (int)strlen(curbuf->b_fname)) > 4
      && STRICMP(curbuf->b_fname + i - 4, ".txt") == 0) {
    st.is_txt = true;
  }

  // When finding a specified number of matches, first try with matching
  // case, so binary search can be used, and try ignore-case matches in a
  // second loop.
  // When finding all matches, 'tagbsearch' is off, or there is no fixed
  // string to look for, ignore case right away to avoid going though the
  // tags files twice.
  // When the tag file is case-fold sorted, it is either one or the other.
  // Only ignore case when TAG_NOIC not used or 'ignorecase' set.
  st.orgpat->regmatch.rm_ic = ((p_ic || !noic)
                               && (findall || st.orgpat->headlen == 0 || !p_tbs));
  for (int round = 1; round <= 2; round++) {
    st.linear = (st.orgpat->headlen == 0 || !p_tbs || round == 2);

    // Try tag file names from tags option one by one.
    for (first_file = true;
         get_tagfname(&tn, first_file, st.tag_fname) == OK;
         first_file = false) {
      findtags_in_file(&st, flags, buf_ffname);
      if (st.stop_searching) {
        retval = OK;
        break;
      }
    }   // end of for-each-file loop

    tagname_free(&tn);

    // stop searching when already did a linear search, or when TAG_NOIC
    // used, and 'ignorecase' not set or already did case-ignore search
    if (st.stop_searching || st.linear || (!p_ic && noic)
        || st.orgpat->regmatch.rm_ic) {
      break;
    }

    // try another time while ignoring case
    st.orgpat->regmatch.rm_ic = true;
  }

  if (!st.stop_searching) {
    if (!st.did_open && verbose) {  // never opened any tags file
      emsg(_("E433: No tags file"));
    }
    retval = OK;                // It's OK even when no tag found
  }

findtag_end:
  findtags_state_free(&st);

  // Move the matches from the ga_match[] arrays into one list of
  // matches.  When retval == FAIL, free the matches.
  if (retval == FAIL) {
    st.match_count = 0;
  }

  *num_matches = findtags_copy_matches(&st, matchesp);

  curbuf->b_help = help_save;
  xfree(saved_pat);

  p_ic = save_p_ic;

  return retval;
}

static garray_T tag_fnames = GA_EMPTY_INIT_VALUE;

// Callback function for finding all "tags" and "tags-??" files in
// 'runtimepath' doc directories.
static bool found_tagfile_cb(int num_fnames, char **fnames, bool all, void *cookie)
{
  for (int i = 0; i < num_fnames; i++) {
    char *const tag_fname = xstrdup(fnames[i]);

#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(tag_fname);
#endif
    simplify_filename(tag_fname);
    GA_APPEND(char *, &tag_fnames, tag_fname);

    if (!all) {
      break;
    }
  }

  return num_fnames > 0;
}

#if defined(EXITFREE)
void free_tag_stuff(void)
{
  ga_clear_strings(&tag_fnames);
  do_tag(NULL, DT_FREE, 0, 0, 0);
  tag_freematch();

  tagstack_clear_entry(&ptag_entry);
}

#endif

/// Get the next name of a tag file from the tag file list.
/// For help files, use "tags" file only.
///
/// @param tnp  holds status info
/// @param first  true when first file name is wanted
/// @param buf  pointer to buffer of MAXPATHL chars
///
/// @return  FAIL if no more tag file names, OK otherwise.
int get_tagfname(tagname_T *tnp, int first, char *buf)
{
  char *fname = NULL;

  if (first) {
    CLEAR_POINTER(tnp);
  }

  if (curbuf->b_help) {
    // For help files it's done in a completely different way:
    // Find "doc/tags" and "doc/tags-??" in all directories in
    // 'runtimepath'.
    if (first) {
      ga_clear_strings(&tag_fnames);
      ga_init(&tag_fnames, (int)sizeof(char *), 10);
      do_in_runtimepath("doc/tags doc/tags-??", DIP_ALL,
                        found_tagfile_cb, NULL);
    }

    if (tnp->tn_hf_idx >= tag_fnames.ga_len) {
      // Not found in 'runtimepath', use 'helpfile', if it exists and
      // wasn't used yet, replacing "help.txt" with "tags".
      if (tnp->tn_hf_idx > tag_fnames.ga_len || *p_hf == NUL) {
        return FAIL;
      }
      tnp->tn_hf_idx++;
      STRCPY(buf, p_hf);
      STRCPY(path_tail(buf), "tags");
#ifdef BACKSLASH_IN_FILENAME
      slash_adjust(buf);
#endif
      simplify_filename(buf);

      for (int i = 0; i < tag_fnames.ga_len; i++) {
        if (strcmp(buf, ((char **)(tag_fnames.ga_data))[i]) == 0) {
          return FAIL;  // avoid duplicate file names
        }
      }
    } else {
      xstrlcpy(buf, ((char **)(tag_fnames.ga_data))[tnp->tn_hf_idx++], MAXPATHL);
    }
    return OK;
  }

  if (first) {
    // Init.  We make a copy of 'tags', because autocommands may change
    // the value without notifying us.
    tnp->tn_tags = xstrdup((*curbuf->b_p_tags != NUL) ? curbuf->b_p_tags : p_tags);
    tnp->tn_np = tnp->tn_tags;
  }

  // Loop until we have found a file name that can be used.
  // There are two states:
  // tnp->tn_did_filefind_init == false: setup for next part in 'tags'.
  // tnp->tn_did_filefind_init == true: find next file in this part.
  while (true) {
    if (tnp->tn_did_filefind_init) {
      fname = vim_findfile(tnp->tn_search_ctx);
      if (fname != NULL) {
        break;
      }

      tnp->tn_did_filefind_init = false;
    } else {
      char *filename = NULL;

      // Stop when used all parts of 'tags'.
      if (*tnp->tn_np == NUL) {
        vim_findfile_cleanup(tnp->tn_search_ctx);
        tnp->tn_search_ctx = NULL;
        return FAIL;
      }

      // Copy next file name into buf.
      buf[0] = NUL;
      copy_option_part(&tnp->tn_np, buf, MAXPATHL - 1, " ,");

      char *r_ptr = vim_findfile_stopdir(buf);
      // move the filename one char forward and truncate the
      // filepath with a NUL
      filename = path_tail(buf);
      STRMOVE(filename + 1, filename);
      *filename++ = NUL;

      tnp->tn_search_ctx = vim_findfile_init(buf, filename,
                                             r_ptr, 100,
                                             false,                   // don't free visited list
                                             FINDFILE_FILE,           // we search for a file
                                             tnp->tn_search_ctx, true, curbuf->b_ffname);
      if (tnp->tn_search_ctx != NULL) {
        tnp->tn_did_filefind_init = true;
      }
    }
  }

  STRCPY(buf, fname);
  xfree(fname);
  return OK;
}

// Free the contents of a tagname_T that was filled by get_tagfname().
void tagname_free(tagname_T *tnp)
{
  xfree(tnp->tn_tags);
  vim_findfile_cleanup(tnp->tn_search_ctx);
  tnp->tn_search_ctx = NULL;
  ga_clear_strings(&tag_fnames);
}

/// Parse one line from the tags file. Find start/end of tag name, start/end of
/// file name and start of search pattern.
///
/// If is_etag is true, tagp->fname and tagp->fname_end are not set.
///
/// @param lbuf  line to be parsed
///
/// @return  FAIL if there is a format error in this line, OK otherwise.
static int parse_tag_line(char *lbuf, tagptrs_T *tagp)
{
  // Isolate the tagname, from lbuf up to the first white
  tagp->tagname = lbuf;
  char *p = vim_strchr(lbuf, TAB);
  if (p == NULL) {
    return FAIL;
  }
  tagp->tagname_end = p;

  // Isolate file name, from first to second white space
  if (*p != NUL) {
    p++;
  }
  tagp->fname = p;
  p = vim_strchr(p, TAB);
  if (p == NULL) {
    return FAIL;
  }
  tagp->fname_end = p;

  // find start of search command, after second white space
  if (*p != NUL) {
    p++;
  }
  if (*p == NUL) {
    return FAIL;
  }
  tagp->command = p;

  return OK;
}

// Check if tagname is a static tag
//
// Static tags produced by the older ctags program have the format:
//      'file:tag  file  /pattern'.
// This is only recognized when both occurrence of 'file' are the same, to
// avoid recognizing "string::string" or ":exit".
//
// Static tags produced by the new ctags program have the format:
//      'tag  file  /pattern/;"<Tab>file:'          "
//
// Return true if it is a static tag and adjust *tagname to the real tag.
// Return false if it is not a static tag.
static bool test_for_static(tagptrs_T *tagp)
{
  // Check for new style static tag ":...<Tab>file:[<Tab>...]"
  char *p = tagp->command;
  while ((p = vim_strchr(p, '\t')) != NULL) {
    p++;
    if (strncmp(p, "file:", 5) == 0) {
      return true;
    }
  }

  return false;
}

/// @return  the length of a matching tag line.
static size_t matching_line_len(const char *const lbuf)
{
  const char *p = lbuf + 1;

  // does the same thing as parse_match()
  p += strlen(p) + 1;
  return (size_t)(p - lbuf) + strlen(p);
}

/// Parse a line from a matching tag.  Does not change the line itself.
///
/// The line that we get looks like this:
/// Emacs tag: <mtt><tag_fname><NUL><ebuf><NUL><lbuf>
/// other tag: <mtt><tag_fname><NUL><NUL><lbuf>
/// without Emacs tags: <mtt><tag_fname><NUL><lbuf>
///
/// @param lbuf  input: matching line
/// @param tagp  output: pointers into the line
///
/// @return  OK or FAIL.
static int parse_match(char *lbuf, tagptrs_T *tagp)
{
  tagp->tag_fname = lbuf + 1;
  lbuf += strlen(tagp->tag_fname) + 2;

  // Find search pattern and the file name for non-etags.
  int retval = parse_tag_line(lbuf, tagp);

  tagp->tagkind = NULL;
  tagp->user_data = NULL;
  tagp->tagline = 0;
  tagp->command_end = NULL;

  if (retval != OK) {
    return retval;
  }

  // Try to find a kind field: "kind:<kind>" or just "<kind>"
  char *p = tagp->command;
  if (find_extra(&p) == OK) {
    tagp->command_end = p;
    if (p > tagp->command && p[-1] == '|') {
      tagp->command_end = p - 1;  // drop trailing bar
    }
    p += 2;  // skip ";\""
    if (*p++ == TAB) {
      // Accept ASCII alphabetic kind characters and any multi-byte
      // character.
      while (ASCII_ISALPHA(*p) || utfc_ptr2len(p) > 1) {
        if (strncmp(p, "kind:", 5) == 0) {
          tagp->tagkind = p + 5;
        } else if (strncmp(p, "user_data:", 10) == 0) {
          tagp->user_data = p + 10;
        } else if (strncmp(p, "line:", 5) == 0) {
          tagp->tagline = atoi(p + 5);
        }
        if (tagp->tagkind != NULL && tagp->user_data != NULL) {
          break;
        }

        char *pc = vim_strchr(p, ':');
        char *pt = vim_strchr(p, '\t');
        if (pc == NULL || (pt != NULL && pc > pt)) {
          tagp->tagkind = p;
        }
        if (pt == NULL) {
          break;
        }
        p = pt;
        MB_PTR_ADV(p);
      }
    }
  }
  if (tagp->tagkind != NULL) {
    for (p = tagp->tagkind;
         *p && *p != '\t' && *p != '\r' && *p != '\n';
         MB_PTR_ADV(p)) {}
    tagp->tagkind_end = p;
  }
  if (tagp->user_data != NULL) {
    for (p = tagp->user_data;
         *p && *p != '\t' && *p != '\r' && *p != '\n';
         MB_PTR_ADV(p)) {}
    tagp->user_data_end = p;
  }
  return retval;
}

// Find out the actual file name of a tag.  Concatenate the tags file name
// with the matching tag file name.
// Returns an allocated string.
static char *tag_full_fname(tagptrs_T *tagp)
{
  char c = *tagp->fname_end;
  *tagp->fname_end = NUL;
  char *fullname = expand_tag_fname(tagp->fname, tagp->tag_fname, false);
  *tagp->fname_end = c;

  return fullname;
}

/// Jump to a tag that has been found in one of the tag files
///
/// @param lbuf_arg  line from the tags file for this tag
/// @param forceit  :ta with !
/// @param keep_help  keep help flag
///
/// @return  OK for success, NOTAGFILE when file not found, FAIL otherwise.
static int jumpto_tag(const char *lbuf_arg, int forceit, bool keep_help)
{
  if (postponed_split == 0 && !check_can_set_curbuf_forceit(forceit)) {
    return FAIL;
  }

  char *pbuf_end;
  char *tofree_fname = NULL;
  tagptrs_T tagp;
  int retval = FAIL;
  int getfile_result = GETFILE_UNUSED;
  int search_options;
  win_T *curwin_save = NULL;
  char *full_fname = NULL;
  const bool old_KeyTyped = KeyTyped;       // getting the file may reset it
  const int l_g_do_tagpreview = g_do_tagpreview;
  const size_t len = matching_line_len(lbuf_arg) + 1;
  char *lbuf = xmalloc(len);
  memmove(lbuf, lbuf_arg, len);

  char *pbuf = xmalloc(LSIZE);  // search pattern buffer

  // parse the match line into the tagp structure
  if (parse_match(lbuf, &tagp) == FAIL) {
    tagp.fname_end = NULL;
    goto erret;
  }

  // truncate the file name, so it can be used as a string
  *tagp.fname_end = NUL;
  char *fname = tagp.fname;

  // copy the command to pbuf[], remove trailing CR/NL
  char *str = tagp.command;
  for (pbuf_end = pbuf; *str && *str != '\n' && *str != '\r';) {
    *pbuf_end++ = *str++;
    if (pbuf_end - pbuf + 1 >= LSIZE) {
      break;
    }
  }
  *pbuf_end = NUL;

  {
    // Remove the "<Tab>fieldname:value" stuff; we don't need it here.
    str = pbuf;
    if (find_extra(&str) == OK) {
      pbuf_end = str;
      *pbuf_end = NUL;
    }
  }

  // Expand file name, when needed (for environment variables).
  // If 'tagrelative' option set, may change file name.
  fname = expand_tag_fname(fname, tagp.tag_fname, true);
  tofree_fname = fname;         // free() it later

  // Check if the file with the tag exists before abandoning the current
  // file.  Also accept a file name for which there is a matching BufReadCmd
  // autocommand event (e.g., http://sys/file).
  if (!os_path_exists(fname)
      && !has_autocmd(EVENT_BUFREADCMD, fname, NULL)) {
    retval = NOTAGFILE;
    xfree(nofile_fname);
    nofile_fname = xstrdup(fname);
    goto erret;
  }

  RedrawingDisabled++;

  if (l_g_do_tagpreview != 0) {
    postponed_split = 0;        // don't split again below
    curwin_save = curwin;       // Save current window

    // If we are reusing a window, we may change dir when
    // entering it (autocommands) so turn the tag filename
    // into a fullpath
    if (!curwin->w_p_pvw) {
      full_fname = FullName_save(fname, false);
      fname = full_fname;

      // Make the preview window the current window.
      // Open a preview window when needed.
      prepare_tagpreview(true);
    }
  }

  // If it was a CTRL-W CTRL-] command split window now.  For ":tab tag"
  // open a new tab page.
  if (postponed_split && (swb_flags & (SWB_USEOPEN | SWB_USETAB))) {
    buf_T *const existing_buf = buflist_findname_exp(fname);

    if (existing_buf != NULL) {
      // If 'switchbuf' is set jump to the window containing "buf".
      if (swbuf_goto_win_with_buf(existing_buf) != NULL) {
        // We've switched to the buffer, the usual loading of the file
        // must be skipped.
        getfile_result = GETFILE_SAME_FILE;
      }
    }
  }
  if (getfile_result == GETFILE_UNUSED
      && (postponed_split || cmdmod.cmod_tab != 0)) {
    if (win_split(postponed_split > 0 ? postponed_split : 0,
                  postponed_split_flags) == FAIL) {
      RedrawingDisabled--;
      goto erret;
    }
    RESET_BINDING(curwin);
  }

  if (keep_help) {
    // A :ta from a help file will keep the b_help flag set.  For ":ptag"
    // we need to use the flag from the window where we came from.
    if (l_g_do_tagpreview != 0) {
      keep_help_flag = bt_help(curwin_save->w_buffer);
    } else {
      keep_help_flag = curbuf->b_help;
    }
  }

  if (getfile_result == GETFILE_UNUSED) {
    // Careful: getfile() may trigger autocommands and call jumpto_tag()
    // recursively.
    getfile_result = getfile(0, fname, NULL, true, 0, forceit);
  }
  keep_help_flag = false;

  if (GETFILE_SUCCESS(getfile_result)) {    // got to the right file
    curwin->w_set_curswant = true;
    postponed_split = 0;

    const optmagic_T save_magic_overruled = magic_overruled;
    magic_overruled = OPTION_MAGIC_OFF;  // always execute with 'nomagic'
    // Save value of no_hlsearch, jumping to a tag is not a real search
    const bool save_no_hlsearch = no_hlsearch;

    // If 'cpoptions' contains 't', store the search pattern for the "n"
    // command.  If 'cpoptions' does not contain 't', the search pattern
    // is not stored.
    if (vim_strchr(p_cpo, CPO_TAGPAT) != NULL) {
      search_options = 0;
    } else {
      search_options = SEARCH_KEEP;
    }

    // If the command is a search, try here.
    //
    // Reset 'smartcase' for the search, since the search pattern was not
    // typed by the user.
    // Only use do_search() when there is a full search command, without
    // anything following.
    str = pbuf;
    if (pbuf[0] == '/' || pbuf[0] == '?') {
      str = skip_regexp(pbuf + 1, pbuf[0], false) + 1;
    }
    if (str > pbuf_end - 1) {   // search command with nothing following
      size_t pbuflen = (size_t)(pbuf_end - pbuf);

      bool save_p_ws = p_ws;
      int save_p_ic = p_ic;
      int save_p_scs = p_scs;
      p_ws = true;              // need 'wrapscan' for backward searches
      p_ic = false;             // don't ignore case now
      p_scs = false;
      linenr_T save_lnum = curwin->w_cursor.lnum;
      if (tagp.tagline > 0) {
        // start search before line from "line:" field
        curwin->w_cursor.lnum = tagp.tagline - 1;
      } else {
        // start search before first line
        curwin->w_cursor.lnum = 0;
      }
      if (do_search(NULL, pbuf[0], pbuf[0], pbuf + 1, pbuflen - 1, 1,
                    search_options, NULL)) {
        retval = OK;
      } else {
        int found = 1;

        // try again, ignore case now
        p_ic = true;
        if (!do_search(NULL, pbuf[0], pbuf[0], pbuf + 1, pbuflen - 1, 1,
                       search_options, NULL)) {
          // Failed to find pattern, take a guess: "^func  ("
          found = 2;
          test_for_static(&tagp);
          char cc = *tagp.tagname_end;
          *tagp.tagname_end = NUL;
          pbuflen = (size_t)snprintf(pbuf, LSIZE, "^%s\\s\\*(", tagp.tagname);
          if (!do_search(NULL, '/', '/', pbuf, pbuflen, 1, search_options, NULL)) {
            // Guess again: "^char * \<func  ("
            pbuflen = (size_t)snprintf(pbuf, LSIZE, "^\\[#a-zA-Z_]\\.\\*\\<%s\\s\\*(",
                                       tagp.tagname);
            if (!do_search(NULL, '/', '/', pbuf, pbuflen, 1, search_options, NULL)) {
              found = 0;
            }
          }
          *tagp.tagname_end = cc;
        }
        if (found == 0) {
          emsg(_("E434: Can't find tag pattern"));
          curwin->w_cursor.lnum = save_lnum;
        } else {
          // Only give a message when really guessed, not when 'ic'
          // is set and match found while ignoring case.
          if (found == 2 || !save_p_ic) {
            msg(_("E435: Couldn't find tag, just guessing!"), 0);
            if (!msg_scrolled && msg_silent == 0) {
              ui_flush();
              os_delay(1010, true);
            }
          }
          retval = OK;
        }
      }
      p_ws = save_p_ws;
      p_ic = save_p_ic;
      p_scs = save_p_scs;

      // A search command may have positioned the cursor beyond the end
      // of the line.  May need to correct that here.
      check_cursor(curwin);
    } else {
      const int save_secure = secure;

      // Setup the sandbox for executing the command from the tags file.
      secure = 1;
      sandbox++;
      curwin->w_cursor.lnum = 1;  // start command in line 1
      do_cmdline_cmd(pbuf);
      retval = OK;

      // When the command has done something that is not allowed make sure
      // the error message can be seen.
      if (secure == 2) {
        wait_return(true);
      }
      secure = save_secure;
      sandbox--;
    }

    magic_overruled = save_magic_overruled;
    // restore no_hlsearch when keeping the old search pattern
    if (search_options) {
      set_no_hlsearch(save_no_hlsearch);
    }

    // Return OK if jumped to another file (at least we found the file!).
    if (getfile_result == GETFILE_OPEN_OTHER) {
      retval = OK;
    }

    if (retval == OK) {
      // For a help buffer: Put the cursor line at the top of the window,
      // the help subject will be below it.
      if (curbuf->b_help) {
        set_topline(curwin, curwin->w_cursor.lnum);
      }
      if ((fdo_flags & FDO_TAG) && old_KeyTyped) {
        foldOpenCursor();
      }
    }

    if (l_g_do_tagpreview != 0
        && curwin != curwin_save && win_valid(curwin_save)) {
      // Return cursor to where we were
      validate_cursor(curwin);
      redraw_later(curwin, UPD_VALID);
      win_enter(curwin_save, true);
    }

    RedrawingDisabled--;
  } else {
    RedrawingDisabled--;
    if (postponed_split) {              // close the window
      win_close(curwin, false, false);
      postponed_split = 0;
    }
  }

erret:
  g_do_tagpreview = 0;  // For next time
  xfree(lbuf);
  xfree(pbuf);
  xfree(tofree_fname);
  xfree(full_fname);

  return retval;
}

/// If "expand" is true, expand wildcards in fname.
/// If 'tagrelative' option set, change fname (name of file containing tag)
/// according to tag_fname (name of tag file containing fname).
///
/// @return  a pointer to allocated memory.
static char *expand_tag_fname(char *fname, char *const tag_fname, const bool expand)
{
  char *p;
  char *expanded_fname = NULL;
  expand_T xpc;

  // Expand file name (for environment variables) when needed.
  if (expand && path_has_wildcard(fname)) {
    ExpandInit(&xpc);
    xpc.xp_context = EXPAND_FILES;
    expanded_fname = ExpandOne(&xpc, fname, NULL,
                               WILD_LIST_NOTFOUND|WILD_SILENT, WILD_EXPAND_FREE);
    if (expanded_fname != NULL) {
      fname = expanded_fname;
    }
  }

  char *retval;
  if ((p_tr || curbuf->b_help)
      && !vim_isAbsName(fname)
      && (p = path_tail(tag_fname)) != tag_fname) {
    retval = xmalloc(MAXPATHL);
    STRCPY(retval, tag_fname);
    xstrlcpy(retval + (p - tag_fname), fname, (size_t)(MAXPATHL - (p - tag_fname)));
    // Translate names like "src/a/../b/file.c" into "src/b/file.c".
    simplify_filename(retval);
  } else {
    retval = xstrdup(fname);
  }

  xfree(expanded_fname);

  return retval;
}

/// Check if we have a tag for the buffer with name "buf_ffname".
/// This is a bit slow, because of the full path compare in path_full_compare().
///
/// @return  true if tag for file "fname" if tag file "tag_fname" is for current
///          file.
static int test_for_current(char *fname, char *fname_end, char *tag_fname, char *buf_ffname)
{
  int retval = false;

  if (buf_ffname != NULL) {     // if the buffer has a name
    char c;
    {
      c = *fname_end;
      *fname_end = NUL;
    }
    char *fullname = expand_tag_fname(fname, tag_fname, true);
    retval = (path_full_compare(fullname, buf_ffname, true, true) & kEqualFiles);
    xfree(fullname);
    *fname_end = c;
  }

  return retval;
}

// Find the end of the tagaddress.
// Return OK if ";\"" is following, FAIL otherwise.
static int find_extra(char **pp)
{
  char *str = *pp;
  char first_char = **pp;

  // Repeat for addresses separated with ';'
  while (true) {
    if (ascii_isdigit(*str)) {
      str = skipdigits(str + 1);
    } else if (*str == '/' || *str == '?') {
      str = skip_regexp(str + 1, *str, false);
      if (*str != first_char) {
        str = NULL;
      } else {
        str++;
      }
    } else {
      // not a line number or search string, look for terminator.
      str = strstr(str, "|;\"");
      if (str != NULL) {
        str++;
        break;
      }
    }
    if (str == NULL || *str != ';'
        || !(ascii_isdigit(str[1]) || str[1] == '/' || str[1] == '?')) {
      break;
    }
    str++;  // skip ';'
    first_char = *str;
  }

  if (str != NULL && strncmp(str, ";\"", 2) == 0) {
    *pp = str;
    return OK;
  }
  return FAIL;
}

//
// Free a single entry in a tag stack
//
static void tagstack_clear_entry(taggy_T *item)
{
  XFREE_CLEAR(item->tagname);
  XFREE_CLEAR(item->user_data);
}

/// @param tagnames  expand tag names
int expand_tags(bool tagnames, char *pat, int *num_file, char ***file)
{
  int extra_flag;
  size_t name_buf_size = 100;
  tagptrs_T t_p;
  int ret;

  char *name_buf = xmalloc(name_buf_size);

  if (tagnames) {
    extra_flag = TAG_NAMES;
  } else {
    extra_flag = 0;
  }
  if (pat[0] == '/') {
    ret = find_tags(pat + 1, num_file, file,
                    TAG_REGEXP | extra_flag | TAG_VERBOSE | TAG_NO_TAGFUNC,
                    TAG_MANY, curbuf->b_ffname);
  } else {
    ret = find_tags(pat, num_file, file,
                    TAG_REGEXP | extra_flag | TAG_VERBOSE | TAG_NO_TAGFUNC | TAG_NOIC,
                    TAG_MANY, curbuf->b_ffname);
  }
  if (ret == OK && !tagnames) {
    // Reorganize the tags for display and matching as strings of:
    // "<tagname>\0<kind>\0<filename>\0"
    for (int i = 0; i < *num_file; i++) {
      size_t len;

      parse_match((*file)[i], &t_p);
      len = (size_t)(t_p.tagname_end - t_p.tagname);
      if (len > name_buf_size - 3) {
        name_buf_size = len + 3;
        char *buf = xrealloc(name_buf, name_buf_size);
        name_buf = buf;
      }

      memmove(name_buf, t_p.tagname, len);
      name_buf[len++] = 0;
      name_buf[len++] = (t_p.tagkind != NULL && *t_p.tagkind)
                        ? *t_p.tagkind : 'f';
      name_buf[len++] = 0;
      memmove((*file)[i] + len, t_p.fname, (size_t)(t_p.fname_end - t_p.fname));
      (*file)[i][len + (size_t)(t_p.fname_end - t_p.fname)] = 0;
      memmove((*file)[i], name_buf, len);
    }
  }
  xfree(name_buf);
  return ret;
}

/// Add a tag field to the dictionary "dict".
/// Return OK or FAIL.
///
/// @param start  start of the value
/// @param end  after the value; can be NULL
static int add_tag_field(dict_T *dict, const char *field_name, const char *start, const char *end)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  int len = 0;

  // Check that the field name doesn't exist yet.
  if (tv_dict_find(dict, field_name, -1) != NULL) {
    if (p_verbose > 0) {
      verbose_enter();
      smsg(0, _("Duplicate field name: %s"), field_name);
      verbose_leave();
    }
    return FAIL;
  }
  char *buf = xmalloc(MAXPATHL);
  if (start != NULL) {
    if (end == NULL) {
      end = start + strlen(start);
      while (end > start && (end[-1] == '\r' || end[-1] == '\n')) {
        end--;
      }
    }
    len = (int)(end - start);
    if (len > MAXPATHL - 1) {
      len = MAXPATHL - 1;
    }
    xmemcpyz(buf, start, (size_t)len);
  }
  buf[len] = NUL;
  int retval = tv_dict_add_str(dict, field_name, strlen(field_name), buf);
  xfree(buf);
  return retval;
}

/// Add the tags matching the specified pattern "pat" to the list "list"
/// as a dictionary. Use "buf_fname" for priority, unless NULL.
int get_tags(list_T *list, char *pat, char *buf_fname)
{
  int num_matches;
  char **matches;
  tagptrs_T tp;

  int ret = find_tags(pat, &num_matches, &matches, TAG_REGEXP | TAG_NOIC, MAXCOL, buf_fname);
  if (ret != OK || num_matches <= 0) {
    return ret;
  }

  for (int i = 0; i < num_matches; i++) {
    if (parse_match(matches[i], &tp) == FAIL) {
      xfree(matches[i]);
      continue;
    }

    bool is_static = test_for_static(&tp);

    // Skip pseudo-tag lines.
    if (strncmp(tp.tagname, "!_TAG_", 6) == 0) {
      xfree(matches[i]);
      continue;
    }

    dict_T *dict = tv_dict_alloc();
    tv_list_append_dict(list, dict);

    char *full_fname = tag_full_fname(&tp);
    if (add_tag_field(dict, "name", tp.tagname, tp.tagname_end) == FAIL
        || add_tag_field(dict, "filename", full_fname, NULL) == FAIL
        || add_tag_field(dict, "cmd", tp.command, tp.command_end) == FAIL
        || add_tag_field(dict, "kind", tp.tagkind,
                         tp.tagkind ? tp.tagkind_end : NULL) == FAIL
        || tv_dict_add_nr(dict, S_LEN("static"), is_static) == FAIL) {
      ret = FAIL;
    }

    xfree(full_fname);

    if (tp.command_end != NULL) {
      for (char *p = tp.command_end + 3;
           *p != NUL && *p != '\n' && *p != '\r';
           MB_PTR_ADV(p)) {
        if (p == tp.tagkind
            || (p + 5 == tp.tagkind && strncmp(p, "kind:", 5) == 0)) {
          // skip "kind:<kind>" and "<kind>"
          p = tp.tagkind_end - 1;
        } else if (strncmp(p, "file:", 5) == 0) {
          // skip "file:" (static tag)
          p += 4;
        } else if (!ascii_iswhite(*p)) {
          int len;

          // Add extra field as a dict entry.  Fields are
          // separated by Tabs.
          char *n = p;
          while (*p != NUL && *p >= ' ' && *p < 127 && *p != ':') {
            p++;
          }
          len = (int)(p - n);
          if (*p == ':' && len > 0) {
            char *s = ++p;
            while (*p != NUL && (uint8_t)(*p) >= ' ') {
              p++;
            }
            n[len] = NUL;
            if (add_tag_field(dict, n, s, p) == FAIL) {
              ret = FAIL;
            }
            n[len] = ':';
          } else {
            // Skip field without colon.
            while (*p != NUL && (uint8_t)(*p) >= ' ') {
              p++;
            }
          }
          if (*p == NUL) {
            break;
          }
        }
      }
    }

    xfree(matches[i]);
  }
  xfree(matches);
  return ret;
}

// Return information about 'tag' in dict 'retdict'.
static void get_tag_details(taggy_T *tag, dict_T *retdict)
{
  tv_dict_add_str(retdict, S_LEN("tagname"), tag->tagname);
  tv_dict_add_nr(retdict, S_LEN("matchnr"), tag->cur_match + 1);
  tv_dict_add_nr(retdict, S_LEN("bufnr"), tag->cur_fnum);
  if (tag->user_data) {
    tv_dict_add_str(retdict, S_LEN("user_data"), tag->user_data);
  }

  list_T *pos = tv_list_alloc(4);
  tv_dict_add_list(retdict, S_LEN("from"), pos);

  fmark_T *fmark = &tag->fmark;
  tv_list_append_number(pos,
                        (varnumber_T)(fmark->fnum != -1 ? fmark->fnum : 0));
  tv_list_append_number(pos, (varnumber_T)fmark->mark.lnum);
  tv_list_append_number(pos, (varnumber_T)(fmark->mark.col == MAXCOL
                                           ? MAXCOL : fmark->mark.col + 1));
  tv_list_append_number(pos, (varnumber_T)fmark->mark.coladd);
}

// Return the tag stack entries of the specified window 'wp' in dictionary
// 'retdict'.
void get_tagstack(win_T *wp, dict_T *retdict)
{
  tv_dict_add_nr(retdict, S_LEN("length"), wp->w_tagstacklen);
  tv_dict_add_nr(retdict, S_LEN("curidx"), wp->w_tagstackidx + 1);
  list_T *l = tv_list_alloc(2);
  tv_dict_add_list(retdict, S_LEN("items"), l);

  for (int i = 0; i < wp->w_tagstacklen; i++) {
    dict_T *d = tv_dict_alloc();
    tv_list_append_dict(l, d);
    get_tag_details(&wp->w_tagstack[i], d);
  }
}

// Free all the entries in the tag stack of the specified window
static void tagstack_clear(win_T *wp)
{
  // Free the current tag stack
  for (int i = 0; i < wp->w_tagstacklen; i++) {
    tagstack_clear_entry(&wp->w_tagstack[i]);
  }
  wp->w_tagstacklen = 0;
  wp->w_tagstackidx = 0;
}

// Remove the oldest entry from the tag stack and shift the rest of
// the entries to free up the top of the stack.
static void tagstack_shift(win_T *wp)
{
  taggy_T *tagstack = wp->w_tagstack;
  tagstack_clear_entry(&tagstack[0]);
  for (int i = 1; i < wp->w_tagstacklen; i++) {
    tagstack[i - 1] = tagstack[i];
  }
  wp->w_tagstacklen--;
}

/// Push a new item to the tag stack
static void tagstack_push_item(win_T *wp, char *tagname, int cur_fnum, int cur_match, pos_T mark,
                               int fnum, char *user_data)
{
  taggy_T *tagstack = wp->w_tagstack;
  int idx = wp->w_tagstacklen;  // top of the stack

  // if the tagstack is full: remove the oldest entry
  if (idx >= TAGSTACKSIZE) {
    tagstack_shift(wp);
    idx = TAGSTACKSIZE - 1;
  }

  wp->w_tagstacklen++;
  tagstack[idx].tagname = tagname;
  tagstack[idx].cur_fnum = cur_fnum;
  tagstack[idx].cur_match = cur_match;
  if (tagstack[idx].cur_match < 0) {
    tagstack[idx].cur_match = 0;
  }
  tagstack[idx].fmark.mark = mark;
  tagstack[idx].fmark.fnum = fnum;
  tagstack[idx].user_data = user_data;
}

/// Add a list of items to the tag stack in the specified window
static void tagstack_push_items(win_T *wp, list_T *l)
{
  dictitem_T *di;
  char *tagname;
  pos_T mark;
  int fnum;

  // Add one entry at a time to the tag stack
  for (listitem_T *li = tv_list_first(l); li != NULL; li = TV_LIST_ITEM_NEXT(l, li)) {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_DICT
        || TV_LIST_ITEM_TV(li)->vval.v_dict == NULL) {
      continue;  // Skip non-dict items
    }
    dict_T *itemdict = TV_LIST_ITEM_TV(li)->vval.v_dict;

    // parse 'from' for the cursor position before the tag jump
    if ((di = tv_dict_find(itemdict, "from", -1)) == NULL) {
      continue;
    }
    if (list2fpos(&di->di_tv, &mark, &fnum, NULL, false) != OK) {
      continue;
    }
    if ((tagname = tv_dict_get_string(itemdict, "tagname", true)) == NULL) {
      continue;
    }

    if (mark.col > 0) {
      mark.col--;
    }
    tagstack_push_item(wp,
                       tagname,
                       (int)tv_dict_get_number(itemdict, "bufnr"),
                       (int)tv_dict_get_number(itemdict, "matchnr") - 1,
                       mark, fnum,
                       tv_dict_get_string(itemdict, "user_data", true));
  }
}

// Set the current index in the tag stack. Valid values are between 0
// and the stack length (inclusive).
static void tagstack_set_curidx(win_T *wp, int curidx)
{
  wp->w_tagstackidx = curidx;
  if (wp->w_tagstackidx < 0) {  // sanity check
    wp->w_tagstackidx = 0;
  }
  if (wp->w_tagstackidx > wp->w_tagstacklen) {
    wp->w_tagstackidx = wp->w_tagstacklen;
  }
}

// Set the tag stack entries of the specified window.
// 'action' is set to one of:
//    'a' for append
//    'r' for replace
//    't' for truncate
int set_tagstack(win_T *wp, const dict_T *d, int action)
  FUNC_ATTR_NONNULL_ARG(1)
{
  dictitem_T *di;
  list_T *l = NULL;

  // not allowed to alter the tag stack entries from inside tagfunc
  if (tfu_in_use) {
    emsg(_(e_cannot_modify_tag_stack_within_tagfunc));
    return FAIL;
  }

  if ((di = tv_dict_find(d, "items", -1)) != NULL) {
    if (di->di_tv.v_type != VAR_LIST) {
      emsg(_(e_listreq));
      return FAIL;
    }
    l = di->di_tv.vval.v_list;
  }

  if ((di = tv_dict_find(d, "curidx", -1)) != NULL) {
    tagstack_set_curidx(wp, (int)tv_get_number(&di->di_tv) - 1);
  }

  if (action == 't') {  // truncate the stack
    taggy_T *const tagstack = wp->w_tagstack;
    const int tagstackidx = wp->w_tagstackidx;
    int tagstacklen = wp->w_tagstacklen;

    // delete all the tag stack entries above the current entry
    while (tagstackidx < tagstacklen) {
      tagstack_clear_entry(&tagstack[--tagstacklen]);
    }
    wp->w_tagstacklen = tagstacklen;
  }

  if (l != NULL) {
    if (action == 'r') {  // replace the stack
      tagstack_clear(wp);
    }

    tagstack_push_items(wp, l);
    // set the current index after the last entry
    wp->w_tagstackidx = wp->w_tagstacklen;
  }

  return OK;
}
