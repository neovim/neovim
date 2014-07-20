 // Various routines dealing with allocation and deallocation of memory.

#include <errno.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/misc2.h"
#include "nvim/file_search.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/ops.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/term.h"
#include "nvim/ui.h"
#include "nvim/window.h"
#include "nvim/os/os.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.c.generated.h"
#endif

/// Try to free memory. Used when trying to recover from out of memory errors.
/// @see {xmalloc}
static void try_to_free_memory(void)
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

/// malloc() wrapper
///
/// try_malloc() is a malloc() wrapper that tries to free some memory before
/// trying again.
///
/// @see {try_to_free_memory}
/// @param size
/// @return pointer to allocated space. NULL if out of memory
void *try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1)
{
  void *ret = malloc(size);

  if (!ret && !size) {
    ret = malloc(1);
  }
  if (!ret) {
    try_to_free_memory();
    ret = malloc(size);
    if (!ret && !size) {
      ret = malloc(1);
    }
  }
  return ret;
}

/// try_malloc() wrapper that shows an out-of-memory error message to the user
/// before returning NULL
///
/// @see {try_malloc}
/// @param size
/// @return pointer to allocated space. NULL if out of memory
void *verbose_try_malloc(size_t size) FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1)
{
  void *ret = try_malloc(size);
  if (!ret) {
    do_outofmem_msg(size);
  }
  return ret;
}

/// malloc() wrapper that never returns NULL
///
/// xmalloc() succeeds or gracefully aborts when out of memory.
/// Before aborting try to free some memory and call malloc again.
///
/// @see {try_to_free_memory}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmalloc(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(1) FUNC_ATTR_NONNULL_RET
{
  void *ret = try_malloc(size);

  if (!ret) {
    OUT_STR("Vim: Error: Out of memory.\n");
    preserve_exit();
  }
  return ret;
}

/// calloc() wrapper
///
/// @see {xmalloc}
/// @param count
/// @param size
/// @return pointer to allocated space. Never NULL
void *xcalloc(size_t count, size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE_PROD(1, 2) FUNC_ATTR_NONNULL_RET
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

/// realloc() wrapper
///
/// @see {xmalloc}
/// @param size
/// @return pointer to reallocated space. Never NULL
void *xrealloc(void *ptr, size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET
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

/// xmalloc() wrapper that allocates size + 1 bytes and zeroes the last byte
///
/// @see {xmalloc}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmallocz(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
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

/// Allocates (len + 1) bytes of memory, duplicates `len` bytes of
/// `data` to the allocated memory, zero terminates the allocated memory,
/// and returns a pointer to the allocated memory. If the allocation fails,
/// the program dies.
///
/// @see {xmalloc}
/// @param data Pointer to the data that will be copied
/// @param len number of bytes that will be copied
void *xmemdupz(const void *data, size_t len)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ALL
{
  return memcpy(xmallocz(len), data, len);
}

/// The xstpcpy() function shall copy the string pointed to by src (including
/// the terminating NUL character) into the array pointed to by dst.
///
/// The xstpcpy() function shall return a pointer to the terminating NUL
/// character copied into the dst buffer. This is the only difference with
/// strcpy(), which returns dst.
///
/// WARNING: If copying takes place between objects that overlap, the behavior is
/// undefined.
///
/// This is the Neovim version of stpcpy(3) as defined in POSIX 2008. We
/// don't require that supported platforms implement POSIX 2008, so we
/// implement our own version.
///
/// @param dst
/// @param src
char *xstpcpy(char *restrict dst, const char *restrict src)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const size_t len = strlen(src);
  return (char *)memcpy(dst, src, len + 1) + len;
}

/// The xstpncpy() function shall copy not more than n bytes (bytes that follow
/// a NUL character are not copied) from the array pointed to by src to the
/// array pointed to by dst.
///
/// If a NUL character is written to the destination, the xstpncpy() function
/// shall return the address of the first such NUL character. Otherwise, it
/// shall return &dst[maxlen].
///
/// WARNING: If copying takes place between objects that overlap, the behavior is
/// undefined.
///
/// WARNING: xstpncpy will ALWAYS write maxlen bytes. If src is shorter than
/// maxlen, zeroes will be written to the remaining bytes.
///
/// TODO(aktau): I don't see a good reason to have this last behaviour, and
/// it is potentially wasteful. Could we perhaps deviate from the standard
/// and not zero the rest of the buffer?
///
/// @param dst
/// @param src
/// @param maxlen
char *xstpncpy(char *restrict dst, const char *restrict src, size_t maxlen)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
    const char *p = memchr(src, '\0', maxlen);
    if (p) {
        size_t srclen = (size_t)(p - src);
        memcpy(dst, src, srclen);
        memset(dst + srclen, 0, maxlen - srclen);
        return dst + srclen;
    } else {
        memcpy(dst, src, maxlen);
        return dst + maxlen;
    }
}

/// xstrlcpy - Copy a %NUL terminated string into a sized buffer
///
/// Compatible with *BSD strlcpy: the result is always a valid
/// NUL-terminated string that fits in the buffer (unless,
/// of course, the buffer size is zero). It does not pad
/// out the result like strncpy() does.
///
/// @param dst Where to copy the string to
/// @param src Where to copy the string from
/// @param size Size of destination buffer
/// @return Length of the source string (i.e.: strlen(src))
size_t xstrlcpy(char *restrict dst, const char *restrict src, size_t size)
{
    size_t ret = strlen(src);

    if (size) {
        size_t len = (ret >= size) ? size - 1 : ret;
        memcpy(dst, src, len);
        dst[len] = '\0';
    }

    return ret;
}

/// strdup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char *xstrdup(const char *str)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
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

/// strndup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char *xstrndup(const char *str, size_t len)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  char *p = memchr(str, '\0', len);
  return xmemdupz(str, p ? (size_t)(p - str) : len);
}

/// Duplicates a chunk of memory using xmalloc
///
/// @see {xmalloc}
/// @param data pointer to the chunk
/// @param len size of the chunk
/// @return a pointer
void *xmemdup(const void *data, size_t len)
  FUNC_ATTR_MALLOC FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return memcpy(xmalloc(len), data, len);
}

/*
 * Avoid repeating the error message many times (they take 1 second each).
 * Did_outofmem_msg is reset when a character is read.
 */
void do_outofmem_msg(size_t size)
{
  if (!did_outofmem_msg) {
    /* Don't hide this message */
    emsg_silent = 0;

    /* Must come first to avoid coming back here when printing the error
     * message fails, e.g. when setting v:errmsg. */
    did_outofmem_msg = TRUE;

    EMSGU(_("E342: Out of memory!  (allocating %" PRIu64 " bytes)"), size);
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
  static bool entered = false;

  /* When we cause a crash here it is caught and Vim tries to exit cleanly.
   * Don't try freeing everything again. */
  if (entered)
    return;
  entered = true;

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
  free(last_cmdline);
  free(new_last_cmdline);
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
}

#endif

