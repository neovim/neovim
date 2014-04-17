 // Various routines dealing with allocation and deallocation of memory.

#include <stdlib.h>
#include <string.h>

#include "vim.h"
#include "misc2.h"
#include "file_search.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "mark.h"
#include "mbyte.h"
#include "memfile.h"
#include "memline.h"
#include "memory.h"
#include "message.h"
#include "misc1.h"
#include "move.h"
#include "option.h"
#include "ops.h"
#include "os_unix.h"
#include "path.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "spell.h"
#include "syntax.h"
#include "tag.h"
#include "term.h"
#include "ui.h"
#include "window.h"
#include "os/os.h"

static void try_to_free_memory();
static void *xmallocz(size_t size);

/// Allocates (len + 1) bytes of memory, duplicates `len` bytes of
/// `data` to the allocated memory, zero terminates the allocated memory,
/// and returns a pointer to the allocated memory. If the allocation fails,
/// the program dies.
///
/// @see {xmalloc}
/// @param data Pointer to the data that will be copied
/// @param len number of bytes that will be copied
static void *xmemdupz(const void *data, size_t len);

/*
 * Note: if unsigned is 16 bits we can only allocate up to 64K with alloc().
 * Use lalloc for larger blocks.
 */
char_u *alloc(unsigned size)
{
  return lalloc((long_u)size, TRUE);
}

/*
 * Allocate memory and set all bytes to zero.
 */
char_u *alloc_clear(unsigned size)
{
  return (char_u *)xcalloc(1, (size_t)size);
}

/// Try to free memory. Used when trying to recover from out of memory errors.
/// @see {xmalloc}
static void try_to_free_memory()
{
  static bool trying_to_free = false;
  // avoid recursive calls
  if (trying_to_free)
    return;
  trying_to_free = true;

  // free any scrollback text
  clear_sb_text();
  // Try to save all buffers and release as many blocks as possible
  mf_release_all();
  // cleanup recursive lists/dicts
  garbage_collect();

  trying_to_free = false;
}

void *xmalloc(size_t size)
{
  void *ret = malloc(size);

  if (!ret && !size)
    ret = malloc(1);

  if (!ret) {
    try_to_free_memory();
    ret = malloc(size);
    if (!ret && !size)
      ret = malloc(1);
    if (!ret) {
      OUT_STR("Vim: Error: Out of memory.\n");
      preserve_exit();
    }
  }

  return ret;
}

void *xcalloc(size_t count, size_t size)
{
  void *ret = calloc(count, size);

  if (!ret && (!count || !size))
    ret = calloc(1, 1);

  if (!ret) {
    try_to_free_memory();
    ret = calloc(count, size);
    if (!ret && (!count || !size))
      ret = calloc(1, 1);
    if (!ret) {
      OUT_STR("Vim: Error: Out of memory.\n");
      preserve_exit();
    }
  }

  return ret;
}

void *xrealloc(void *ptr, size_t size)
{
  void *ret = realloc(ptr, size);

  if (!ret && !size)
    ret = realloc(ptr, 1);

  if (!ret) {
    try_to_free_memory();
    ret = realloc(ptr, size);
    if (!ret && !size)
      ret = realloc(ptr, 1);
    if (!ret) {
      OUT_STR("Vim: Error: Out of memory.\n");
      preserve_exit();
    }
  }

  return ret;
}

char * xstrdup(const char *str)
{
  char *ret = strdup(str);

  if (!ret) {
    try_to_free_memory();
    ret = strdup(str);
    if (!ret) {
      OUT_STR("Vim: Error: Out of memory.\n");
      preserve_exit();
    }
  }

  return ret;
}

char *xstrndup(const char *str, size_t len)
{
  char *p = memchr(str, '\0', len);
  return xmemdupz(str, p ? (size_t)(p - str) : len);
}


char_u *lalloc(long_u size, int message)
{
  return (char_u *)xmalloc((size_t)size);
}

/*
 * Avoid repeating the error message many times (they take 1 second each).
 * Did_outofmem_msg is reset when a character is read.
 */
void do_outofmem_msg(long_u size)
{
  if (!did_outofmem_msg) {
    /* Don't hide this message */
    emsg_silent = 0;

    /* Must come first to avoid coming back here when printing the error
     * message fails, e.g. when setting v:errmsg. */
    did_outofmem_msg = TRUE;

    EMSGN(_("E342: Out of memory!  (allocating %lu bytes)"), size);
  }
}

#if defined(EXITFREE) || defined(PROTO)

/*
 * Free everything that we allocated.
 * Can be used to detect memory leaks, e.g., with ccmalloc.
 * NOTE: This is tricky!  Things are freed that functions depend on.  Don't be
 * surprised if Vim crashes...
 * Some things can't be freed, esp. things local to a library function.
 */
void free_all_mem(void)
{
  buf_T       *buf, *nextbuf;
  static int entered = FALSE;

  /* When we cause a crash here it is caught and Vim tries to exit cleanly.
   * Don't try freeing everything again. */
  if (entered)
    return;
  entered = TRUE;

  block_autocmds();         /* don't want to trigger autocommands here */

  /* Close all tabs and windows.  Reset 'equalalways' to avoid redraws. */
  p_ea = FALSE;
  if (first_tabpage->tp_next != NULL)
    do_cmdline_cmd((char_u *)"tabonly!");
  if (firstwin != lastwin)
    do_cmdline_cmd((char_u *)"only!");

  /* Free all spell info. */
  spell_free_all();

  /* Clear user commands (before deleting buffers). */
  ex_comclear(NULL);

  /* Clear menus. */
  do_cmdline_cmd((char_u *)"aunmenu *");
  do_cmdline_cmd((char_u *)"menutranslate clear");

  /* Clear mappings, abbreviations, breakpoints. */
  do_cmdline_cmd((char_u *)"lmapclear");
  do_cmdline_cmd((char_u *)"xmapclear");
  do_cmdline_cmd((char_u *)"mapclear");
  do_cmdline_cmd((char_u *)"mapclear!");
  do_cmdline_cmd((char_u *)"abclear");
  do_cmdline_cmd((char_u *)"breakdel *");
  do_cmdline_cmd((char_u *)"profdel *");
  do_cmdline_cmd((char_u *)"set keymap=");

  free_titles();
  free_findfile();

  /* Obviously named calls. */
  free_all_autocmds();
  clear_termcodes();
  free_all_options();
  free_all_marks();
  alist_clear(&global_alist);
  free_homedir();
  free_users();
  free_search_patterns();
  free_old_sub();
  free_last_insert();
  free_prev_shellcmd();
  free_regexp_stuff();
  free_tag_stuff();
  free_cd_dir();
  free_signs();
  set_expr_line(NULL);
  diff_clear(curtab);
  clear_sb_text();            /* free any scrollback text */

  /* Free some global vars. */
  vim_free(last_cmdline);
  vim_free(new_last_cmdline);
  set_keep_msg(NULL, 0);

  /* Clear cmdline history. */
  p_hi = 0;
  init_history();

  {
    win_T       *win;
    tabpage_T   *tab;

    qf_free_all(NULL);
    /* Free all location lists */
    FOR_ALL_TAB_WINDOWS(tab, win)
    qf_free_all(win);
  }

  /* Close all script inputs. */
  close_all_scripts();

  /* Destroy all windows.  Must come before freeing buffers. */
  win_free_all();

  /* Free all buffers.  Reset 'autochdir' to avoid accessing things that
   * were freed already. */
  p_acd = FALSE;
  for (buf = firstbuf; buf != NULL; ) {
    nextbuf = buf->b_next;
    close_buffer(NULL, buf, DOBUF_WIPE, FALSE);
    if (buf_valid(buf))
      buf = nextbuf;            /* didn't work, try next one */
    else
      buf = firstbuf;
  }

  free_cmdline_buf();

  /* Clear registers. */
  clear_registers();
  ResetRedobuff();
  ResetRedobuff();


  /* highlight info */
  free_highlight();

  reset_last_sourcing();

  free_tabpage(first_tabpage);
  first_tabpage = NULL;

# ifdef UNIX
  /* Machine-specific free. */
  mch_free_mem();
# endif

  /* message history */
  for (;; )
    if (delete_first_msg() == FAIL)
      break;

  eval_clear();

  free_termoptions();

  /* screenlines (can't display anything now!) */
  free_screenlines();

  clear_hl_tables();

  vim_free(NameBuff);
}

#endif

static void *xmallocz(size_t size)
{
  size_t total_size = size + 1;
  void *ret;

  if (total_size < size) {
    OUT_STR("Vim: Data too large to fit into virtual memory space\n");
    preserve_exit();
  }

  ret = xmalloc(total_size);
  ((char*)ret)[size] = 0;

  return ret;
}

static void *xmemdupz(const void *data, size_t len)
{
  return memcpy(xmallocz(len), data, len);
}

