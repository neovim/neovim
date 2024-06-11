// File searching functions for 'path', 'tags' and 'cdpath' options.
//
// External visible functions:
//   vim_findfile_init()          creates/initialises the search context
//   vim_findfile_free_visited()  free list of visited files/dirs of search
//                                context
//   vim_findfile()               find a file in the search context
//   vim_findfile_cleanup()       cleanup/free search context created by
//                                vim_findfile_init()
//
// All static functions and variables start with 'ff_'
//
// In general it works like this:
// First you create yourself a search context by calling vim_findfile_init().
// It is possible to give a search context from a previous call to
// vim_findfile_init(), so it can be reused. After this you call vim_findfile()
// until you are satisfied with the result or it returns NULL. On every call it
// returns the next file which matches the conditions given to
// vim_findfile_init(). If it doesn't find a next file it returns NULL.
//
// It is possible to call vim_findfile_init() again to reinitialise your search
// with some new parameters. Don't forget to pass your old search context to
// it, so it can reuse it and especially reuse the list of already visited
// directories. If you want to delete the list of already visited directories
// simply call vim_findfile_free_visited().
//
// When you are done call vim_findfile_cleanup() to free the search context.
//
// The function vim_findfile_init() has a long comment, which describes the
// needed parameters.
//
//
//
// ATTENTION:
// ==========
// We use an allocated search context, these functions are NOT thread-safe!!!!!
//
// To minimize parameter passing (or because I'm too lazy), only the
// external visible functions get a search context as a parameter. This is
// then assigned to a static global, which is used throughout the local
// functions.

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/file_search.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/strings.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

static char *ff_expand_buffer = NULL;  // used for expanding filenames

// type for the directory search stack
typedef struct ff_stack {
  struct ff_stack *ffs_prev;

  // the fix part (no wildcards) and the part containing the wildcards
  // of the search path
  char *ffs_fix_path;
  char *ffs_wc_path;

  // files/dirs found in the above directory, matched by the first wildcard
  // of wc_part
  char **ffs_filearray;
  int ffs_filearray_size;
  int ffs_filearray_cur;                  // needed for partly handled dirs

  // to store status of partly handled directories
  // 0: we work on this directory for the first time
  // 1: this directory was partly searched in an earlier step
  int ffs_stage;

  // How deep are we in the directory tree?
  // Counts backward from value of level parameter to vim_findfile_init
  int ffs_level;

  // Did we already expand '**' to an empty string?
  int ffs_star_star_empty;
} ff_stack_T;

// type for already visited directories or files.
typedef struct ff_visited {
  struct ff_visited *ffv_next;

  // Visited directories are different if the wildcard string are
  // different. So we have to save it.
  char *ffv_wc_path;

  // use FileID for comparison (needed because of links), else use filename.
  bool file_id_valid;
  FileID file_id;
  // The memory for this struct is allocated according to the length of
  // ffv_fname.
  char ffv_fname[];
} ff_visited_T;

// We might have to manage several visited lists during a search.
// This is especially needed for the tags option. If tags is set to:
//      "./++/tags,./++/TAGS,++/tags"  (replace + with *)
// So we have to do 3 searches:
//   1) search from the current files directory downward for the file "tags"
//   2) search from the current files directory downward for the file "TAGS"
//   3) search from Vims current directory downwards for the file "tags"
// As you can see, the first and the third search are for the same file, so for
// the third search we can use the visited list of the first search. For the
// second search we must start from an empty visited list.
// The struct ff_visited_list_hdr is used to manage a linked list of already
// visited lists.
typedef struct ff_visited_list_hdr {
  struct ff_visited_list_hdr *ffvl_next;

  // the filename the attached visited list is for
  char *ffvl_filename;

  ff_visited_T *ffvl_visited_list;
} ff_visited_list_hdr_T;

// '**' can be expanded to several directory levels.
// Set the default maximum depth.
#define FF_MAX_STAR_STAR_EXPAND 30

// The search context:
//   ffsc_stack_ptr:    the stack for the dirs to search
//   ffsc_visited_list: the currently active visited list
//   ffsc_dir_visited_list: the currently active visited list for search dirs
//   ffsc_visited_lists_list: the list of all visited lists
//   ffsc_dir_visited_lists_list: the list of all visited lists for search dirs
//   ffsc_file_to_search:     the file to search for
//   ffsc_start_dir:    the starting directory, if search path was relative
//   ffsc_fix_path:     the fix part of the given path (without wildcards)
//                      Needed for upward search.
//   ffsc_wc_path:      the part of the given path containing wildcards
//   ffsc_level:        how many levels of dirs to search downwards
//   ffsc_stopdirs_v:   array of stop directories for upward search
//   ffsc_find_what:    FINDFILE_BOTH, FINDFILE_DIR or FINDFILE_FILE
//   ffsc_tagfile:      searching for tags file, don't use 'suffixesadd'
typedef struct {
  ff_stack_T *ffsc_stack_ptr;
  ff_visited_list_hdr_T *ffsc_visited_list;
  ff_visited_list_hdr_T *ffsc_dir_visited_list;
  ff_visited_list_hdr_T *ffsc_visited_lists_list;
  ff_visited_list_hdr_T *ffsc_dir_visited_lists_list;
  char *ffsc_file_to_search;
  char *ffsc_start_dir;
  char *ffsc_fix_path;
  char *ffsc_wc_path;
  int ffsc_level;
  char **ffsc_stopdirs_v;
  int ffsc_find_what;
  int ffsc_tagfile;
} ff_search_ctx_T;

// locally needed functions

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.c.generated.h"
#endif

static const char e_path_too_long_for_completion[]
  = N_("E854: Path too long for completion");

/// Initialization routine for vim_findfile().
///
/// Returns the newly allocated search context or NULL if an error occurred.
///
/// Don't forget to clean up by calling vim_findfile_cleanup() if you are done
/// with the search context.
///
/// Find the file 'filename' in the directory 'path'.
/// The parameter 'path' may contain wildcards. If so only search 'level'
/// directories deep. The parameter 'level' is the absolute maximum and is
/// not related to restricts given to the '**' wildcard. If 'level' is 100
/// and you use '**200' vim_findfile() will stop after 100 levels.
///
/// 'filename' cannot contain wildcards!  It is used as-is, no backslashes to
/// escape special characters.
///
/// If 'stopdirs' is not NULL and nothing is found downward, the search is
/// restarted on the next higher directory level. This is repeated until the
/// start-directory of a search is contained in 'stopdirs'. 'stopdirs' has the
/// format ";*<dirname>*\(;<dirname>\)*;\=$".
///
/// If the 'path' is relative, the starting dir for the search is either VIM's
/// current dir or if the path starts with "./" the current files dir.
/// If the 'path' is absolute, the starting dir is that part of the path before
/// the first wildcard.
///
/// Upward search is only done on the starting dir.
///
/// If 'free_visited' is true the list of already visited files/directories is
/// cleared. Set this to false if you just want to search from another
/// directory, but want to be sure that no directory from a previous search is
/// searched again. This is useful if you search for a file at different places.
/// The list of visited files/dirs can also be cleared with the function
/// vim_findfile_free_visited().
///
/// Set the parameter 'find_what' to FINDFILE_DIR if you want to search for
/// directories only, FINDFILE_FILE for files only, FINDFILE_BOTH for both.
///
/// A search context returned by a previous call to vim_findfile_init() can be
/// passed in the parameter "search_ctx_arg".  This context is reused and
/// reinitialized with the new parameters.  The list of already visited
/// directories from this context is only deleted if the parameter
/// "free_visited" is true.  Be aware that the passed "search_ctx_arg" is freed
/// if the reinitialization fails.
///
/// If you don't have a search context from a previous call "search_ctx_arg"
/// must be NULL.
///
/// This function silently ignores a few errors, vim_findfile() will have
/// limited functionality then.
///
/// @param tagfile  expanding names of tags files
/// @param rel_fname  file name to use for "."
void *vim_findfile_init(char *path, char *filename, char *stopdirs, int level, int free_visited,
                        int find_what, void *search_ctx_arg, int tagfile, char *rel_fname)
{
  ff_stack_T *sptr;
  ff_search_ctx_T *search_ctx;

  // If a search context is given by the caller, reuse it, else allocate a
  // new one.
  if (search_ctx_arg != NULL) {
    search_ctx = search_ctx_arg;
  } else {
    search_ctx = xcalloc(1, sizeof(ff_search_ctx_T));
  }
  search_ctx->ffsc_find_what = find_what;
  search_ctx->ffsc_tagfile = tagfile;

  // clear the search context, but NOT the visited lists
  ff_clear(search_ctx);

  // clear visited list if wanted
  if (free_visited == true) {
    vim_findfile_free_visited(search_ctx);
  } else {
    // Reuse old visited lists. Get the visited list for the given
    // filename. If no list for the current filename exists, creates a new
    // one.
    search_ctx->ffsc_visited_list = ff_get_visited_list(filename,
                                                        &search_ctx->ffsc_visited_lists_list);
    if (search_ctx->ffsc_visited_list == NULL) {
      goto error_return;
    }
    search_ctx->ffsc_dir_visited_list = ff_get_visited_list(filename,
                                                            &search_ctx->ffsc_dir_visited_lists_list);
    if (search_ctx->ffsc_dir_visited_list == NULL) {
      goto error_return;
    }
  }

  if (ff_expand_buffer == NULL) {
    ff_expand_buffer = xmalloc(MAXPATHL);
  }

  // Store information on starting dir now if path is relative.
  // If path is absolute, we do that later.
  if (path[0] == '.'
      && (vim_ispathsep(path[1]) || path[1] == NUL)
      && (!tagfile || vim_strchr(p_cpo, CPO_DOTTAG) == NULL)
      && rel_fname != NULL) {
    size_t len = (size_t)(path_tail(rel_fname) - rel_fname);

    if (!vim_isAbsName(rel_fname) && len + 1 < MAXPATHL) {
      // Make the start dir an absolute path name.
      xmemcpyz(ff_expand_buffer, rel_fname, len);
      search_ctx->ffsc_start_dir = FullName_save(ff_expand_buffer, false);
    } else {
      search_ctx->ffsc_start_dir = xmemdupz(rel_fname, len);
    }
    if (*++path != NUL) {
      path++;
    }
  } else if (*path == NUL || !vim_isAbsName(path)) {
#ifdef BACKSLASH_IN_FILENAME
    // "c:dir" needs "c:" to be expanded, otherwise use current dir
    if (*path != NUL && path[1] == ':') {
      char drive[3];

      drive[0] = path[0];
      drive[1] = ':';
      drive[2] = NUL;
      if (vim_FullName(drive, ff_expand_buffer, MAXPATHL, true) == FAIL) {
        goto error_return;
      }
      path += 2;
    } else
#endif
    if (os_dirname(ff_expand_buffer, MAXPATHL) == FAIL) {
      goto error_return;
    }

    search_ctx->ffsc_start_dir = xstrdup(ff_expand_buffer);

#ifdef BACKSLASH_IN_FILENAME
    // A path that starts with "/dir" is relative to the drive, not to the
    // directory (but not for "//machine/dir").  Only use the drive name.
    if ((*path == '/' || *path == '\\')
        && path[1] != path[0]
        && search_ctx->ffsc_start_dir[1] == ':') {
      search_ctx->ffsc_start_dir[2] = NUL;
    }
#endif
  }

  // If stopdirs are given, split them into an array of pointers.
  // If this fails (mem allocation), there is no upward search at all or a
  // stop directory is not recognized -> continue silently.
  // If stopdirs just contains a ";" or is empty,
  // search_ctx->ffsc_stopdirs_v will only contain a  NULL pointer. This
  // is handled as unlimited upward search.  See function
  // ff_path_in_stoplist() for details.
  if (stopdirs != NULL) {
    char *walker = stopdirs;

    while (*walker == ';') {
      walker++;
    }

    size_t dircount = 1;
    search_ctx->ffsc_stopdirs_v = xmalloc(sizeof(char *));

    do {
      char *helper;
      void *ptr;

      helper = walker;
      ptr = xrealloc(search_ctx->ffsc_stopdirs_v,
                     (dircount + 1) * sizeof(char *));
      search_ctx->ffsc_stopdirs_v = ptr;
      walker = vim_strchr(walker, ';');
      if (walker) {
        assert(walker - helper >= 0);
        search_ctx->ffsc_stopdirs_v[dircount - 1] = xstrnsave(helper, (size_t)(walker - helper));
        walker++;
      } else {
        // this might be "", which means ascent till top of directory tree.
        search_ctx->ffsc_stopdirs_v[dircount - 1] = xstrdup(helper);
      }

      dircount++;
    } while (walker != NULL);
    search_ctx->ffsc_stopdirs_v[dircount - 1] = NULL;
  }

  search_ctx->ffsc_level = level;

  // split into:
  //  -fix path
  //  -wildcard_stuff (might be NULL)
  char *wc_part = vim_strchr(path, '*');
  if (wc_part != NULL) {
    int64_t llevel;
    int len;
    char *errpt;

    // save the fix part of the path
    assert(wc_part - path >= 0);
    search_ctx->ffsc_fix_path = xstrnsave(path, (size_t)(wc_part - path));

    // copy wc_path and add restricts to the '**' wildcard.
    // The octet after a '**' is used as a (binary) counter.
    // So '**3' is transposed to '**^C' ('^C' is ASCII value 3)
    // or '**76' is transposed to '**N'( 'N' is ASCII value 76).
    // If no restrict is given after '**' the default is used.
    // Due to this technique the path looks awful if you print it as a
    // string.
    len = 0;
    while (*wc_part != NUL) {
      if (len + 5 >= MAXPATHL) {
        emsg(_(e_path_too_long_for_completion));
        break;
      }
      if (strncmp(wc_part, S_LEN("**")) == 0) {
        ff_expand_buffer[len++] = *wc_part++;
        ff_expand_buffer[len++] = *wc_part++;

        llevel = strtol(wc_part, &errpt, 10);
        if (errpt != wc_part && llevel > 0 && llevel < 255) {
          ff_expand_buffer[len++] = (char)llevel;
        } else if (errpt != wc_part && llevel == 0) {
          // restrict is 0 -> remove already added '**'
          len -= 2;
        } else {
          ff_expand_buffer[len++] = FF_MAX_STAR_STAR_EXPAND;
        }
        wc_part = errpt;
        if (*wc_part != NUL && !vim_ispathsep(*wc_part)) {
          semsg(_(
                 "E343: Invalid path: '**[number]' must be at the end of the path or be followed by '%s'."),
                PATHSEPSTR);
          goto error_return;
        }
      } else {
        ff_expand_buffer[len++] = *wc_part++;
      }
    }
    ff_expand_buffer[len] = NUL;
    search_ctx->ffsc_wc_path = xstrdup(ff_expand_buffer);
  } else {
    search_ctx->ffsc_fix_path = xstrdup(path);
  }

  if (search_ctx->ffsc_start_dir == NULL) {
    // store the fix part as startdir.
    // This is needed if the parameter path is fully qualified.
    search_ctx->ffsc_start_dir = xstrdup(search_ctx->ffsc_fix_path);
    search_ctx->ffsc_fix_path[0] = NUL;
  }

  // create an absolute path
  if (strlen(search_ctx->ffsc_start_dir)
      + strlen(search_ctx->ffsc_fix_path) + 3 >= MAXPATHL) {
    emsg(_(e_path_too_long_for_completion));
    goto error_return;
  }
  STRCPY(ff_expand_buffer, search_ctx->ffsc_start_dir);
  add_pathsep(ff_expand_buffer);
  {
    size_t eb_len = strlen(ff_expand_buffer);
    char *buf = xmalloc(eb_len + strlen(search_ctx->ffsc_fix_path) + 1);

    STRCPY(buf, ff_expand_buffer);
    STRCPY(buf + eb_len, search_ctx->ffsc_fix_path);
    if (os_isdir(buf)) {
      strcat(ff_expand_buffer, search_ctx->ffsc_fix_path);
      add_pathsep(ff_expand_buffer);
    } else {
      char *p = path_tail(search_ctx->ffsc_fix_path);
      char *wc_path = NULL;
      char *temp = NULL;
      int len = 0;

      if (p > search_ctx->ffsc_fix_path) {
        // do not add '..' to the path and start upwards searching
        len = (int)(p - search_ctx->ffsc_fix_path) - 1;
        if ((len >= 2 && strncmp(search_ctx->ffsc_fix_path, S_LEN("..")) == 0)
            && (len == 2 || search_ctx->ffsc_fix_path[2] == PATHSEP)) {
          xfree(buf);
          goto error_return;
        }
        xstrlcat(ff_expand_buffer, search_ctx->ffsc_fix_path, eb_len + (size_t)len + 1);
        add_pathsep(ff_expand_buffer);
      } else {
        len = (int)strlen(search_ctx->ffsc_fix_path);
      }

      if (search_ctx->ffsc_wc_path != NULL) {
        wc_path = xstrdup(search_ctx->ffsc_wc_path);
        temp = xmalloc(strlen(search_ctx->ffsc_wc_path)
                       + strlen(search_ctx->ffsc_fix_path + len)
                       + 1);
        STRCPY(temp, search_ctx->ffsc_fix_path + len);
        strcat(temp, search_ctx->ffsc_wc_path);
        xfree(search_ctx->ffsc_wc_path);
        xfree(wc_path);
        search_ctx->ffsc_wc_path = temp;
      }
    }
    xfree(buf);
  }

  sptr = ff_create_stack_element(ff_expand_buffer, search_ctx->ffsc_wc_path, level, 0);

  ff_push(search_ctx, sptr);
  search_ctx->ffsc_file_to_search = xstrdup(filename);
  return search_ctx;

error_return:
  // We clear the search context now!
  // Even when the caller gave us a (perhaps valid) context we free it here,
  // as we might have already destroyed it.
  vim_findfile_cleanup(search_ctx);
  return NULL;
}

/// @return  the stopdir string.  Check that ';' is not escaped.
char *vim_findfile_stopdir(char *buf)
{
  for (; *buf != NUL && *buf != ';' && (buf[0] != '\\' || buf[1] != ';'); buf++) {}
  char *dst = buf;
  if (*buf == ';') {
    goto is_semicolon;
  }
  if (*buf == NUL) {
    goto is_nul;
  }
  goto start;
  while (*buf != NUL && *buf != ';') {
    if (buf[0] == '\\' && buf[1] == ';') {
start:
      // Overwrite the escape char.
      *dst++ = ';';
      buf += 2;
    } else {
      *dst++ = *buf++;
    }
  }
  assert(dst < buf);
  *dst = NUL;
  if (*buf == ';') {
is_semicolon:
    *buf = NUL;
    buf++;
  } else {  // if (*buf == NUL)
is_nul:
    buf = NULL;
  }
  return buf;
}

/// Clean up the given search context. Can handle a NULL pointer.
void vim_findfile_cleanup(void *ctx)
{
  if (ctx == NULL) {
    return;
  }

  vim_findfile_free_visited(ctx);
  ff_clear(ctx);
  xfree(ctx);
}

/// Find a file in a search context.
/// The search context was created with vim_findfile_init() above.
///
/// To get all matching files call this function until you get NULL.
///
/// If the passed search_context is NULL, NULL is returned.
///
/// The search algorithm is depth first. To change this replace the
/// stack with a list (don't forget to leave partly searched directories on the
/// top of the list).
///
/// @return  a pointer to an allocated file name or,
///          NULL if nothing found.
char *vim_findfile(void *search_ctx_arg)
{
  char *rest_of_wildcards;
  char *path_end = NULL;
  ff_stack_T *stackp = NULL;
  size_t len;
  char *p;
  char *suf;

  if (search_ctx_arg == NULL) {
    return NULL;
  }

  ff_search_ctx_T *search_ctx = (ff_search_ctx_T *)search_ctx_arg;

  // filepath is used as buffer for various actions and as the storage to
  // return a found filename.
  char *file_path = xmalloc(MAXPATHL);

  // store the end of the start dir -- needed for upward search
  if (search_ctx->ffsc_start_dir != NULL) {
    path_end = &search_ctx->ffsc_start_dir[strlen(search_ctx->ffsc_start_dir)];
  }

  // upward search loop
  while (true) {
    // downward search loop
    while (true) {
      // check if user wants to stop the search
      os_breakcheck();
      if (got_int) {
        break;
      }

      // get directory to work on from stack
      stackp = ff_pop(search_ctx);
      if (stackp == NULL) {
        break;
      }

      // TODO(vim): decide if we leave this test in
      //
      // GOOD: don't search a directory(-tree) twice.
      // BAD:  - check linked list for every new directory entered.
      //       - check for double files also done below
      //
      // Here we check if we already searched this directory.
      // We already searched a directory if:
      // 1) The directory is the same.
      // 2) We would use the same wildcard string.
      //
      // Good if you have links on same directory via several ways
      //  or you have selfreferences in directories (e.g. SuSE Linux 6.3:
      //  /etc/rc.d/init.d is linked to /etc/rc.d -> endless loop)
      //
      // This check is only needed for directories we work on for the
      // first time (hence stackp->ff_filearray == NULL)
      if (stackp->ffs_filearray == NULL
          && ff_check_visited(&search_ctx->ffsc_dir_visited_list->ffvl_visited_list,
                              stackp->ffs_fix_path, stackp->ffs_wc_path) == FAIL) {
#ifdef FF_VERBOSE
        if (p_verbose >= 5) {
          verbose_enter_scroll();
          smsg(0, "Already Searched: %s (%s)",
               stackp->ffs_fix_path, stackp->ffs_wc_path);
          msg_puts("\n");  // don't overwrite this either
          verbose_leave_scroll();
        }
#endif
        ff_free_stack_element(stackp);
        continue;
#ifdef FF_VERBOSE
      } else if (p_verbose >= 5) {
        verbose_enter_scroll();
        smsg(0, "Searching: %s (%s)",
             stackp->ffs_fix_path, stackp->ffs_wc_path);
        msg_puts("\n");  // don't overwrite this either
        verbose_leave_scroll();
#endif
      }

      // check depth
      if (stackp->ffs_level <= 0) {
        ff_free_stack_element(stackp);
        continue;
      }

      file_path[0] = NUL;

      // If no filearray till now expand wildcards
      // The function expand_wildcards() can handle an array of paths
      // and all possible expands are returned in one array. We use this
      // to handle the expansion of '**' into an empty string.
      if (stackp->ffs_filearray == NULL) {
        char *dirptrs[2];

        // we use filepath to build the path expand_wildcards() should expand.
        dirptrs[0] = file_path;
        dirptrs[1] = NULL;

        // if we have a start dir copy it in
        if (!vim_isAbsName(stackp->ffs_fix_path)
            && search_ctx->ffsc_start_dir) {
          if (strlen(search_ctx->ffsc_start_dir) + 1 >= MAXPATHL) {
            ff_free_stack_element(stackp);
            goto fail;
          }
          STRCPY(file_path, search_ctx->ffsc_start_dir);
          if (!add_pathsep(file_path)) {
            ff_free_stack_element(stackp);
            goto fail;
          }
        }

        // append the fix part of the search path
        if (strlen(file_path) + strlen(stackp->ffs_fix_path) + 1 >= MAXPATHL) {
          ff_free_stack_element(stackp);
          goto fail;
        }
        strcat(file_path, stackp->ffs_fix_path);
        if (!add_pathsep(file_path)) {
          ff_free_stack_element(stackp);
          goto fail;
        }

        rest_of_wildcards = stackp->ffs_wc_path;
        if (*rest_of_wildcards != NUL) {
          len = strlen(file_path);
          if (strncmp(rest_of_wildcards, S_LEN("**")) == 0) {
            // pointer to the restrict byte
            // The restrict byte is not a character!
            p = rest_of_wildcards + 2;

            if (*p > 0) {
              (*p)--;
              if (len + 1 >= MAXPATHL) {
                ff_free_stack_element(stackp);
                goto fail;
              }
              file_path[len++] = '*';
            }

            if (*p == 0) {
              // remove '**<numb> from wildcards
              STRMOVE(rest_of_wildcards, rest_of_wildcards + 3);
            } else {
              rest_of_wildcards += 3;
            }

            if (stackp->ffs_star_star_empty == 0) {
              // if not done before, expand '**' to empty
              stackp->ffs_star_star_empty = 1;
              dirptrs[1] = stackp->ffs_fix_path;
            }
          }

          // Here we copy until the next path separator or the end of
          // the path. If we stop at a path separator, there is
          // still something else left. This is handled below by
          // pushing every directory returned from expand_wildcards()
          // on the stack again for further search.
          while (*rest_of_wildcards
                 && !vim_ispathsep(*rest_of_wildcards)) {
            if (len + 1 >= MAXPATHL) {
              ff_free_stack_element(stackp);
              goto fail;
            }
            file_path[len++] = *rest_of_wildcards++;
          }

          file_path[len] = NUL;
          if (vim_ispathsep(*rest_of_wildcards)) {
            rest_of_wildcards++;
          }
        }

        // Expand wildcards like "*" and "$VAR".
        // If the path is a URL don't try this.
        if (path_with_url(dirptrs[0])) {
          stackp->ffs_filearray = xmalloc(sizeof(char *));
          stackp->ffs_filearray[0] = xstrdup(dirptrs[0]);
          stackp->ffs_filearray_size = 1;
        } else {
          // Add EW_NOTWILD because the expanded path may contain
          // wildcard characters that are to be taken literally.
          // This is a bit of a hack.
          expand_wildcards((dirptrs[1] == NULL) ? 1 : 2, dirptrs,
                           &stackp->ffs_filearray_size,
                           &stackp->ffs_filearray,
                           EW_DIR|EW_ADDSLASH|EW_SILENT|EW_NOTWILD);
        }

        stackp->ffs_filearray_cur = 0;
        stackp->ffs_stage = 0;
      } else {
        rest_of_wildcards = &stackp->ffs_wc_path[strlen(stackp->ffs_wc_path)];
      }

      if (stackp->ffs_stage == 0) {
        // this is the first time we work on this directory
        if (*rest_of_wildcards == NUL) {
          // We don't have further wildcards to expand, so we have to
          // check for the final file now.
          for (int i = stackp->ffs_filearray_cur; i < stackp->ffs_filearray_size; i++) {
            if (!path_with_url(stackp->ffs_filearray[i])
                && !os_isdir(stackp->ffs_filearray[i])) {
              continue;                 // not a directory
            }
            // prepare the filename to be checked for existence below
            if (strlen(stackp->ffs_filearray[i]) + 1
                + strlen(search_ctx->ffsc_file_to_search) >= MAXPATHL) {
              ff_free_stack_element(stackp);
              goto fail;
            }
            STRCPY(file_path, stackp->ffs_filearray[i]);
            if (!add_pathsep(file_path)) {
              ff_free_stack_element(stackp);
              goto fail;
            }
            strcat(file_path, search_ctx->ffsc_file_to_search);

            // Try without extra suffix and then with suffixes
            // from 'suffixesadd'.
            len = strlen(file_path);
            if (search_ctx->ffsc_tagfile) {
              suf = "";
            } else {
              suf = curbuf->b_p_sua;
            }
            while (true) {
              // if file exists and we didn't already find it
              if ((path_with_url(file_path)
                   || (os_path_exists(file_path)
                       && (search_ctx->ffsc_find_what == FINDFILE_BOTH
                           || ((search_ctx->ffsc_find_what == FINDFILE_DIR)
                               == os_isdir(file_path)))))
#ifndef FF_VERBOSE
                  && (ff_check_visited(&search_ctx->ffsc_visited_list->ffvl_visited_list,
                                       file_path, "") == OK)
#endif
                  ) {
#ifdef FF_VERBOSE
                if (ff_check_visited(&search_ctx->ffsc_visited_list->ffvl_visited_list,
                                     file_path, "") == FAIL) {
                  if (p_verbose >= 5) {
                    verbose_enter_scroll();
                    smsg(0, "Already: %s", file_path);
                    msg_puts("\n");  // don't overwrite this either
                    verbose_leave_scroll();
                  }
                  continue;
                }
#endif

                // push dir to examine rest of subdirs later
                assert(i < INT_MAX);
                stackp->ffs_filearray_cur = i + 1;
                ff_push(search_ctx, stackp);

                if (!path_with_url(file_path)) {
                  simplify_filename(file_path);
                }
                if (os_dirname(ff_expand_buffer, MAXPATHL) == OK) {
                  p = path_shorten_fname(file_path, ff_expand_buffer);
                  if (p != NULL) {
                    STRMOVE(file_path, p);
                  }
                }
#ifdef FF_VERBOSE
                if (p_verbose >= 5) {
                  verbose_enter_scroll();
                  smsg(0, "HIT: %s", file_path);
                  msg_puts("\n");  // don't overwrite this either
                  verbose_leave_scroll();
                }
#endif
                return file_path;
              }

              // Not found or found already, try next suffix.
              if (*suf == NUL) {
                break;
              }
              assert(MAXPATHL >= len);
              copy_option_part(&suf, file_path + len, MAXPATHL - len, ",");
            }
          }
        } else {
          // still wildcards left, push the directories for further search
          for (int i = stackp->ffs_filearray_cur; i < stackp->ffs_filearray_size; i++) {
            if (!os_isdir(stackp->ffs_filearray[i])) {
              continue;                 // not a directory
            }
            ff_push(search_ctx,
                    ff_create_stack_element(stackp->ffs_filearray[i],
                                            rest_of_wildcards,
                                            stackp->ffs_level - 1, 0));
          }
        }
        stackp->ffs_filearray_cur = 0;
        stackp->ffs_stage = 1;
      }

      // if wildcards contains '**' we have to descent till we reach the
      // leaves of the directory tree.
      if (strncmp(stackp->ffs_wc_path, S_LEN("**")) == 0) {
        for (int i = stackp->ffs_filearray_cur;
             i < stackp->ffs_filearray_size; i++) {
          if (path_fnamecmp(stackp->ffs_filearray[i],
                            stackp->ffs_fix_path) == 0) {
            continue;             // don't repush same directory
          }
          if (!os_isdir(stackp->ffs_filearray[i])) {
            continue;               // not a directory
          }
          ff_push(search_ctx,
                  ff_create_stack_element(stackp->ffs_filearray[i],
                                          stackp->ffs_wc_path, stackp->ffs_level - 1, 1));
        }
      }

      // we are done with the current directory
      ff_free_stack_element(stackp);
    }

    // If we reached this, we didn't find anything downwards.
    // Let's check if we should do an upward search.
    if (search_ctx->ffsc_start_dir
        && search_ctx->ffsc_stopdirs_v != NULL && !got_int) {
      ff_stack_T *sptr;

      // is the last starting directory in the stop list?
      if (ff_path_in_stoplist(search_ctx->ffsc_start_dir,
                              (int)(path_end - search_ctx->ffsc_start_dir),
                              search_ctx->ffsc_stopdirs_v)) {
        break;
      }

      // cut of last dir
      while (path_end > search_ctx->ffsc_start_dir && vim_ispathsep(*path_end)) {
        path_end--;
      }
      while (path_end > search_ctx->ffsc_start_dir && !vim_ispathsep(path_end[-1])) {
        path_end--;
      }
      *path_end = 0;
      path_end--;

      if (*search_ctx->ffsc_start_dir == 0) {
        break;
      }

      if (strlen(search_ctx->ffsc_start_dir) + 1
          + strlen(search_ctx->ffsc_fix_path) >= MAXPATHL) {
        goto fail;
      }
      STRCPY(file_path, search_ctx->ffsc_start_dir);
      if (!add_pathsep(file_path)) {
        goto fail;
      }
      strcat(file_path, search_ctx->ffsc_fix_path);

      // create a new stack entry
      sptr = ff_create_stack_element(file_path,
                                     search_ctx->ffsc_wc_path, search_ctx->ffsc_level, 0);
      ff_push(search_ctx, sptr);
    } else {
      break;
    }
  }

fail:
  xfree(file_path);
  return NULL;
}

/// Free the list of lists of visited files and directories
/// Can handle it if the passed search_context is NULL;
void vim_findfile_free_visited(void *search_ctx_arg)
{
  if (search_ctx_arg == NULL) {
    return;
  }

  ff_search_ctx_T *search_ctx = (ff_search_ctx_T *)search_ctx_arg;
  vim_findfile_free_visited_list(&search_ctx->ffsc_visited_lists_list);
  vim_findfile_free_visited_list(&search_ctx->ffsc_dir_visited_lists_list);
}

static void vim_findfile_free_visited_list(ff_visited_list_hdr_T **list_headp)
{
  ff_visited_list_hdr_T *vp;

  while (*list_headp != NULL) {
    vp = (*list_headp)->ffvl_next;
    ff_free_visited_list((*list_headp)->ffvl_visited_list);

    xfree((*list_headp)->ffvl_filename);
    xfree(*list_headp);
    *list_headp = vp;
  }
  *list_headp = NULL;
}

static void ff_free_visited_list(ff_visited_T *vl)
{
  ff_visited_T *vp;

  while (vl != NULL) {
    vp = vl->ffv_next;
    xfree(vl->ffv_wc_path);
    xfree(vl);
    vl = vp;
  }
  vl = NULL;
}

/// @return  the already visited list for the given filename. If none is found it
///          allocates a new one.
static ff_visited_list_hdr_T *ff_get_visited_list(char *filename,
                                                  ff_visited_list_hdr_T **list_headp)
{
  ff_visited_list_hdr_T *retptr = NULL;

  // check if a visited list for the given filename exists
  if (*list_headp != NULL) {
    retptr = *list_headp;
    while (retptr != NULL) {
      if (path_fnamecmp(filename, retptr->ffvl_filename) == 0) {
#ifdef FF_VERBOSE
        if (p_verbose >= 5) {
          verbose_enter_scroll();
          smsg(0, "ff_get_visited_list: FOUND list for %s", filename);
          msg_puts("\n");  // don't overwrite this either
          verbose_leave_scroll();
        }
#endif
        return retptr;
      }
      retptr = retptr->ffvl_next;
    }
  }

#ifdef FF_VERBOSE
  if (p_verbose >= 5) {
    verbose_enter_scroll();
    smsg(0, "ff_get_visited_list: new list for %s", filename);
    msg_puts("\n");  // don't overwrite this either
    verbose_leave_scroll();
  }
#endif

  // if we reach this we didn't find a list and we have to allocate new list
  retptr = xmalloc(sizeof(*retptr));

  retptr->ffvl_visited_list = NULL;
  retptr->ffvl_filename = xstrdup(filename);
  retptr->ffvl_next = *list_headp;
  *list_headp = retptr;

  return retptr;
}

/// Check if two wildcard paths are equal.
/// They are equal if:
///  - both paths are NULL
///  - they have the same length
///  - char by char comparison is OK
///  - the only differences are in the counters behind a '**', so
///    '**\20' is equal to '**\24'
static bool ff_wc_equal(char *s1, char *s2)
{
  int i, j;
  int prev1 = NUL;
  int prev2 = NUL;

  if (s1 == s2) {
    return true;
  }

  if (s1 == NULL || s2 == NULL) {
    return false;
  }

  for (i = 0, j = 0; s1[i] != NUL && s2[j] != NUL;) {
    int c1 = utf_ptr2char(s1 + i);
    int c2 = utf_ptr2char(s2 + j);

    if ((p_fic ? mb_tolower(c1) != mb_tolower(c2) : c1 != c2)
        && (prev1 != '*' || prev2 != '*')) {
      return false;
    }
    prev2 = prev1;
    prev1 = c1;

    i += utfc_ptr2len(s1 + i);
    j += utfc_ptr2len(s2 + j);
  }
  return s1[i] == s2[j];
}

/// maintains the list of already visited files and dirs
///
/// @return  FAIL if the given file/dir is already in the list or,
///          OK if it is newly added
static int ff_check_visited(ff_visited_T **visited_list, char *fname, char *wc_path)
{
  ff_visited_T *vp;
  bool url = false;

  FileID file_id;
  // For a URL we only compare the name, otherwise we compare the
  // device/inode.
  if (path_with_url(fname)) {
    xstrlcpy(ff_expand_buffer, fname, MAXPATHL);
    url = true;
  } else {
    ff_expand_buffer[0] = NUL;
    if (!os_fileid(fname, &file_id)) {
      return FAIL;
    }
  }

  // check against list of already visited files
  for (vp = *visited_list; vp != NULL; vp = vp->ffv_next) {
    if ((url && path_fnamecmp(vp->ffv_fname, ff_expand_buffer) == 0)
        || (!url && vp->file_id_valid
            && os_fileid_equal(&(vp->file_id), &file_id))) {
      // are the wildcard parts equal
      if (ff_wc_equal(vp->ffv_wc_path, wc_path)) {
        // already visited
        return FAIL;
      }
    }
  }

  // New file/dir.  Add it to the list of visited files/dirs.
  vp = xmalloc(offsetof(ff_visited_T, ffv_fname) + strlen(ff_expand_buffer) + 1);

  if (!url) {
    vp->file_id_valid = true;
    vp->file_id = file_id;
    vp->ffv_fname[0] = NUL;
  } else {
    vp->file_id_valid = false;
    STRCPY(vp->ffv_fname, ff_expand_buffer);
  }

  if (wc_path != NULL) {
    vp->ffv_wc_path = xstrdup(wc_path);
  } else {
    vp->ffv_wc_path = NULL;
  }

  vp->ffv_next = *visited_list;
  *visited_list = vp;

  return OK;
}

/// create stack element from given path pieces
static ff_stack_T *ff_create_stack_element(char *fix_part, char *wc_part, int level,
                                           int star_star_empty)
{
  ff_stack_T *stack = xmalloc(sizeof(ff_stack_T));

  stack->ffs_prev = NULL;
  stack->ffs_filearray = NULL;
  stack->ffs_filearray_size = 0;
  stack->ffs_filearray_cur = 0;
  stack->ffs_stage = 0;
  stack->ffs_level = level;
  stack->ffs_star_star_empty = star_star_empty;

  // the following saves NULL pointer checks in vim_findfile
  if (fix_part == NULL) {
    fix_part = "";
  }
  stack->ffs_fix_path = xstrdup(fix_part);

  if (wc_part == NULL) {
    wc_part = "";
  }
  stack->ffs_wc_path = xstrdup(wc_part);

  return stack;
}

/// Push a dir on the directory stack.
static void ff_push(ff_search_ctx_T *search_ctx, ff_stack_T *stack_ptr)
{
  // check for NULL pointer, not to return an error to the user, but
  // to prevent a crash
  if (stack_ptr == NULL) {
    return;
  }

  stack_ptr->ffs_prev = search_ctx->ffsc_stack_ptr;
  search_ctx->ffsc_stack_ptr = stack_ptr;
}

/// Pop a dir from the directory stack.
///
/// @return  NULL if stack is empty.
static ff_stack_T *ff_pop(ff_search_ctx_T *search_ctx)
{
  ff_stack_T *sptr = search_ctx->ffsc_stack_ptr;
  if (search_ctx->ffsc_stack_ptr != NULL) {
    search_ctx->ffsc_stack_ptr = search_ctx->ffsc_stack_ptr->ffs_prev;
  }

  return sptr;
}

/// free the given stack element
static void ff_free_stack_element(ff_stack_T *const stack_ptr)
{
  if (stack_ptr == NULL) {
    return;
  }

  // free handles possible NULL pointers
  xfree(stack_ptr->ffs_fix_path);
  xfree(stack_ptr->ffs_wc_path);

  if (stack_ptr->ffs_filearray != NULL) {
    FreeWild(stack_ptr->ffs_filearray_size, stack_ptr->ffs_filearray);
  }

  xfree(stack_ptr);
}

/// Clear the search context, but NOT the visited list.
static void ff_clear(ff_search_ctx_T *search_ctx)
{
  ff_stack_T *sptr;

  // clear up stack
  while ((sptr = ff_pop(search_ctx)) != NULL) {
    ff_free_stack_element(sptr);
  }

  xfree(search_ctx->ffsc_file_to_search);
  xfree(search_ctx->ffsc_start_dir);
  xfree(search_ctx->ffsc_fix_path);
  xfree(search_ctx->ffsc_wc_path);

  if (search_ctx->ffsc_stopdirs_v != NULL) {
    int i = 0;

    while (search_ctx->ffsc_stopdirs_v[i] != NULL) {
      xfree(search_ctx->ffsc_stopdirs_v[i]);
      i++;
    }
    xfree(search_ctx->ffsc_stopdirs_v);
  }
  search_ctx->ffsc_stopdirs_v = NULL;

  // reset everything
  search_ctx->ffsc_file_to_search = NULL;
  search_ctx->ffsc_start_dir = NULL;
  search_ctx->ffsc_fix_path = NULL;
  search_ctx->ffsc_wc_path = NULL;
  search_ctx->ffsc_level = 0;
}

/// check if the given path is in the stopdirs
///
/// @return  true if yes else false
static bool ff_path_in_stoplist(char *path, int path_len, char **stopdirs_v)
{
  // eat up trailing path separators, except the first
  while (path_len > 1 && vim_ispathsep(path[path_len - 1])) {
    path_len--;
  }

  // if no path consider it as match
  if (path_len == 0) {
    return true;
  }

  for (int i = 0; stopdirs_v[i] != NULL; i++) {
    if ((int)strlen(stopdirs_v[i]) > path_len) {
      // match for parent directory. So '/home' also matches
      // '/home/rks'. Check for PATHSEP in stopdirs_v[i], else
      // '/home/r' would also match '/home/rks'
      if (path_fnamencmp(stopdirs_v[i], path, (size_t)path_len) == 0
          && vim_ispathsep(stopdirs_v[i][path_len])) {
        return true;
      }
    } else {
      if (path_fnamecmp(stopdirs_v[i], path) == 0) {
        return true;
      }
    }
  }
  return false;
}

/// Find the file name "ptr[len]" in the path.  Also finds directory names.
///
/// On the first call set the parameter 'first' to true to initialize
/// the search.  For repeating calls to false.
///
/// Repeating calls will return other files called 'ptr[len]' from the path.
///
/// Only on the first call 'ptr' and 'len' are used.  For repeating calls they
/// don't need valid values.
///
/// If nothing found on the first call the option FNAME_MESS will issue the
/// message:
///          'Can't find file "<file>" in path'
/// On repeating calls:
///          'No more file "<file>" found in path'
///
/// options:
/// FNAME_MESS       give error message when not found
///
/// Uses NameBuff[]!
///
/// @param ptr  file name
/// @param len  length of file name
/// @param first  use count'th matching file name
/// @param rel_fname  file name searching relative to
/// @param[in,out] file_to_find  modified copy of file name
/// @param[in,out] search_ctx  state of the search
///
/// @return  an allocated string for the file name.  NULL for error.
char *find_file_in_path(char *ptr, size_t len, int options, int first, char *rel_fname,
                        char **file_to_find, char **search_ctx)
{
  return find_file_in_path_option(ptr, len, options, first,
                                  (*curbuf->b_p_path == NUL
                                   ? p_path
                                   : curbuf->b_p_path),
                                  FINDFILE_BOTH, rel_fname, curbuf->b_p_sua,
                                  file_to_find, search_ctx);
}

#if defined(EXITFREE)
void free_findfile(void)
{
  XFREE_CLEAR(ff_expand_buffer);
}
#endif

/// Find the directory name "ptr[len]" in the path.
///
/// options:
/// FNAME_MESS       give error message when not found
/// FNAME_UNESC      unescape backslashes
///
/// Uses NameBuff[]!
///
/// @param ptr  file name
/// @param len  length of file name
/// @param rel_fname  file name searching relative to
/// @param[in,out] file_to_find  modified copy of file name
/// @param[in,out] search_ctx  state of the search
///
/// @return  an allocated string for the file name.  NULL for error.
char *find_directory_in_path(char *ptr, size_t len, int options, char *rel_fname,
                             char **file_to_find, char **search_ctx)
{
  return find_file_in_path_option(ptr, len, options, true, p_cdpath,
                                  FINDFILE_DIR, rel_fname, "",
                                  file_to_find, search_ctx);
}

/// @param ptr  file name
/// @param len  length of file name
/// @param first  use count'th matching file name
/// @param path_option  p_path or p_cdpath
/// @param find_what  FINDFILE_FILE, _DIR or _BOTH
/// @param rel_fname  file name we are looking relative to.
/// @param suffixes  list of suffixes, 'suffixesadd' option
/// @param[in,out] file_to_find  modified copy of file name
/// @param[in,out] search_ctx_arg  state of the search
char *find_file_in_path_option(char *ptr, size_t len, int options, int first, char *path_option,
                               int find_what, char *rel_fname, char *suffixes, char **file_to_find,
                               char **search_ctx_arg)
{
  ff_search_ctx_T **search_ctx = (ff_search_ctx_T **)search_ctx_arg;
  static char *dir;
  static bool did_findfile_init = false;
  char *file_name = NULL;
  char *buf = NULL;

  if (rel_fname != NULL && path_with_url(rel_fname)) {
    // Do not attempt to search "relative" to a URL. #6009
    rel_fname = NULL;
  }

  if (first == true) {
    if (len == 0) {
      return NULL;
    }

    // copy file name into NameBuff, expanding environment variables
    char save_char = ptr[len];
    ptr[len] = NUL;
    expand_env_esc(ptr, NameBuff, MAXPATHL, false, true, NULL);
    ptr[len] = save_char;

    xfree(*file_to_find);
    *file_to_find = xstrdup(NameBuff);
    if (options & FNAME_UNESC) {
      // Change all "\ " to " ".
      for (ptr = *file_to_find; *ptr != NUL; ptr++) {
        if (ptr[0] == '\\' && ptr[1] == ' ') {
          memmove(ptr, ptr + 1, strlen(ptr));
        }
      }
    }
  }

  bool rel_to_curdir = ((*file_to_find)[0] == '.'
                        && ((*file_to_find)[1] == NUL
                            || vim_ispathsep((*file_to_find)[1])
                            || ((*file_to_find)[1] == '.'
                                && ((*file_to_find)[2] == NUL
                                    || vim_ispathsep((*file_to_find)[2])))));
  if (vim_isAbsName(*file_to_find)
      // "..", "../path", "." and "./path": don't use the path_option
      || rel_to_curdir
#if defined(MSWIN)
      // handle "\tmp" as absolute path
      || vim_ispathsep((*file_to_find)[0])
      // handle "c:name" as absolute path
      || ((*file_to_find)[0] != NUL && (*file_to_find)[1] == ':')
#endif
      ) {
    // Absolute path, no need to use "path_option".
    // If this is not a first call, return NULL.  We already returned a
    // filename on the first call.
    if (first == true) {
      if (path_with_url(*file_to_find)) {
        file_name = xstrdup(*file_to_find);
        goto theend;
      }

      // When FNAME_REL flag given first use the directory of the file.
      // Otherwise or when this fails use the current directory.
      for (int run = 1; run <= 2; run++) {
        size_t l = strlen(*file_to_find);
        if (run == 1
            && rel_to_curdir
            && (options & FNAME_REL)
            && rel_fname != NULL
            && strlen(rel_fname) + l < MAXPATHL) {
          STRCPY(NameBuff, rel_fname);
          STRCPY(path_tail(NameBuff), *file_to_find);
          l = strlen(NameBuff);
        } else {
          STRCPY(NameBuff, *file_to_find);
          run = 2;
        }

        // When the file doesn't exist, try adding parts of 'suffixesadd'.
        buf = suffixes;
        while (true) {
          if ((os_path_exists(NameBuff)
               && (find_what == FINDFILE_BOTH
                   || ((find_what == FINDFILE_DIR)
                       == os_isdir(NameBuff))))) {
            file_name = xstrdup(NameBuff);
            goto theend;
          }
          if (*buf == NUL) {
            break;
          }
          assert(MAXPATHL >= l);
          copy_option_part(&buf, NameBuff + l, MAXPATHL - l, ",");
        }
      }
    }
  } else {
    // Loop over all paths in the 'path' or 'cdpath' option.
    // When "first" is set, first setup to the start of the option.
    // Otherwise continue to find the next match.
    if (first == true) {
      // vim_findfile_free_visited can handle a possible NULL pointer
      vim_findfile_free_visited(*search_ctx);
      dir = path_option;
      did_findfile_init = false;
    }

    while (true) {
      if (did_findfile_init) {
        file_name = vim_findfile(*search_ctx);
        if (file_name != NULL) {
          break;
        }

        did_findfile_init = false;
      } else {
        char *r_ptr;

        if (dir == NULL || *dir == NUL) {
          // We searched all paths of the option, now we can free the search context.
          vim_findfile_cleanup(*search_ctx);
          *search_ctx = NULL;
          break;
        }

        buf = xmalloc(MAXPATHL);

        // copy next path
        buf[0] = 0;
        copy_option_part(&dir, buf, MAXPATHL, " ,");

        // get the stopdir string
        r_ptr = vim_findfile_stopdir(buf);
        *search_ctx = vim_findfile_init(buf, *file_to_find,
                                        r_ptr, 100, false, find_what,
                                        *search_ctx, false, rel_fname);
        if (*search_ctx != NULL) {
          did_findfile_init = true;
        }
        xfree(buf);
      }
    }
  }
  if (file_name == NULL && (options & FNAME_MESS)) {
    if (first == true) {
      if (find_what == FINDFILE_DIR) {
        semsg(_("E344: Can't find directory \"%s\" in cdpath"), *file_to_find);
      } else {
        semsg(_("E345: Can't find file \"%s\" in path"), *file_to_find);
      }
    } else {
      if (find_what == FINDFILE_DIR) {
        semsg(_("E346: No more directory \"%s\" found in cdpath"), *file_to_find);
      } else {
        semsg(_("E347: No more file \"%s\" found in path"), *file_to_find);
      }
    }
  }

theend:
  return file_name;
}

void do_autocmd_dirchanged(char *new_dir, CdScope scope, CdCause cause, bool pre)
{
  static bool recursive = false;

  event_T event = pre ? EVENT_DIRCHANGEDPRE : EVENT_DIRCHANGED;

  if (recursive || !has_event(event)) {
    // No autocommand was defined or we changed
    // the directory from this autocommand.
    return;
  }

  recursive = true;

  save_v_event_T save_v_event;
  dict_T *dict = get_v_event(&save_v_event);
  char buf[8];

  switch (scope) {
  case kCdScopeGlobal:
    snprintf(buf, sizeof(buf), "global");
    break;
  case kCdScopeTabpage:
    snprintf(buf, sizeof(buf), "tabpage");
    break;
  case kCdScopeWindow:
    snprintf(buf, sizeof(buf), "window");
    break;
  case kCdScopeInvalid:
    // Should never happen.
    abort();
  }

#ifdef BACKSLASH_IN_FILENAME
  char new_dir_buf[MAXPATHL];
  STRCPY(new_dir_buf, new_dir);
  slash_adjust(new_dir_buf);
  new_dir = new_dir_buf;
#endif

  if (pre) {
    tv_dict_add_str(dict, S_LEN("directory"), new_dir);
  } else {
    tv_dict_add_str(dict, S_LEN("cwd"), new_dir);
  }
  tv_dict_add_str(dict, S_LEN("scope"), buf);
  tv_dict_add_bool(dict, S_LEN("changed_window"), cause == kCdCauseWindow);
  tv_dict_set_keys_readonly(dict);

  switch (cause) {
  case kCdCauseManual:
  case kCdCauseWindow:
    break;
  case kCdCauseAuto:
    snprintf(buf, sizeof(buf), "auto");
    break;
  case kCdCauseOther:
    // Should never happen.
    abort();
  }

  apply_autocmds(event, buf, new_dir, false, curbuf);

  restore_v_event(dict, &save_v_event);

  recursive = false;
}

/// Change to a file's directory.
/// Caller must call shorten_fnames()!
///
/// @return  OK or FAIL
int vim_chdirfile(char *fname, CdCause cause)
{
  char dir[MAXPATHL];

  xstrlcpy(dir, fname, MAXPATHL);
  *path_tail_with_sep(dir) = NUL;

  if (os_dirname(NameBuff, sizeof(NameBuff)) != OK) {
    NameBuff[0] = NUL;
  }

  if (pathcmp(dir, NameBuff, -1) == 0) {
    // nothing to do
    return OK;
  }

  if (cause != kCdCauseOther) {
    do_autocmd_dirchanged(dir, kCdScopeWindow, cause, true);
  }

  if (os_chdir(dir) != 0) {
    return FAIL;
  }

  if (cause != kCdCauseOther) {
    do_autocmd_dirchanged(dir, kCdScopeWindow, cause, false);
  }

  return OK;
}

/// Change directory to "new_dir". Search 'cdpath' for relative directory names.
int vim_chdir(char *new_dir)
{
  char *file_to_find = NULL;
  char *search_ctx = NULL;
  char *dir_name = find_directory_in_path(new_dir, strlen(new_dir), FNAME_MESS,
                                          curbuf->b_ffname, &file_to_find, &search_ctx);
  xfree(file_to_find);
  vim_findfile_cleanup(search_ctx);
  if (dir_name == NULL) {
    return -1;
  }

  int r = os_chdir(dir_name);
  xfree(dir_name);
  return r;
}
