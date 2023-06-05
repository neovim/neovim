// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Various routines dealing with allocation and deallocation of memory.

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "nvim/api/extmark.h"
#include "nvim/arglist.h"
#include "nvim/ascii.h"
#include "nvim/buffer_updates.h"
#include "nvim/context.h"
#include "nvim/decoration_provider.h"
#include "nvim/eval.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_group.h"
#include "nvim/insexpand.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/mapping.h"
#include "nvim/memfile.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/sign.h"
#include "nvim/ui.h"
#include "nvim/usercmd.h"
#include "nvim/vim.h"

#ifdef UNIT_TESTING
# define malloc(size) mem_malloc(size)
# define calloc(count, size) mem_calloc(count, size)
# define realloc(ptr, size) mem_realloc(ptr, size)
# define free(ptr) mem_free(ptr)
MemMalloc mem_malloc = &malloc;
MemFree mem_free = &free;
MemCalloc mem_calloc = &calloc;
MemRealloc mem_realloc = &realloc;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memory.c.generated.h"
#endif

#ifdef EXITFREE
bool entered_free_all_mem = false;
#endif

/// Try to free memory. Used when trying to recover from out of memory errors.
/// @see {xmalloc}
void try_to_free_memory(void)
{
  static bool trying_to_free = false;
  // avoid recursive calls
  if (trying_to_free) {
    return;
  }
  trying_to_free = true;

  // free any scrollback text
  clear_sb_text(true);
  // Try to save all buffers and release as many blocks as possible
  mf_release_all();

  arena_free_reuse_blks();

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
  size_t allocated_size = size ? size : 1;
  void *ret = malloc(allocated_size);
  if (!ret) {
    try_to_free_memory();
    ret = malloc(allocated_size);
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
    preserve_exit(e_outofmem);
  }
  return ret;
}

/// free() wrapper that delegates to the backing memory manager
///
/// @note Use XFREE_CLEAR() instead, if possible.
void xfree(void *ptr)
{
  free(ptr);
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
  size_t allocated_count = count && size ? count : 1;
  size_t allocated_size = count && size ? size : 1;
  void *ret = calloc(allocated_count, allocated_size);
  if (!ret) {
    try_to_free_memory();
    ret = calloc(allocated_count, allocated_size);
    if (!ret) {
      preserve_exit(e_outofmem);
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
  size_t allocated_size = size ? size : 1;
  void *ret = realloc(ptr, allocated_size);
  if (!ret) {
    try_to_free_memory();
    ret = realloc(ptr, allocated_size);
    if (!ret) {
      preserve_exit(e_outofmem);
    }
  }
  return ret;
}

/// xmalloc() wrapper that allocates size + 1 bytes and zeroes the last byte
///
/// Commonly used to allocate strings, e.g. `char *s = xmallocz(len)`.
///
/// @see {xmalloc}
/// @param size
/// @return pointer to allocated space. Never NULL
void *xmallocz(size_t size)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t total_size = size + 1;
  if (total_size < size) {
    preserve_exit(_("Vim: Data too large to fit into virtual memory space\n"));
  }

  void *ret = xmalloc(total_size);
  ((char *)ret)[size] = 0;

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

/// A version of strchr() that returns a pointer to the terminating NUL if it
/// doesn't find `c`.
///
/// @param str The string to search.
/// @param c   The char to look for.
/// @returns a pointer to the first instance of `c`, or to the NUL terminator
///          if not found.
char *xstrchrnul(const char *str, char c)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  char *p = strchr(str, c);
  return p ? p : (char *)(str + strlen(str));
}

/// A version of memchr() that returns a pointer one past the end
/// if it doesn't find `c`.
///
/// @param addr The address of the memory object.
/// @param c    The char to look for.
/// @param size The size of the memory object.
/// @returns a pointer to the first instance of `c`, or one past the end if not
///          found.
void *xmemscan(const void *addr, char c, size_t size)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  char *p = memchr(addr, c, size);
  return p ? p : (char *)addr + size;
}

/// Replaces every instance of `c` with `x`.
///
/// @warning Will read past `str + strlen(str)` if `c == NUL`.
///
/// @param str A NUL-terminated string.
/// @param c   The unwanted byte.
/// @param x   The replacement.
void strchrsub(char *str, char c, char x)
  FUNC_ATTR_NONNULL_ALL
{
  assert(c != '\0');
  while ((str = strchr(str, c))) {
    *str++ = x;
  }
}

/// Replaces every instance of `c` with `x`.
///
/// @param data An object in memory. May contain NULs.
/// @param c    The unwanted byte.
/// @param x    The replacement.
/// @param len  The length of data.
void memchrsub(void *data, char c, char x, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  char *p = data, *end = (char *)data + len;
  while ((p = memchr(p, c, (size_t)(end - p)))) {
    *p++ = x;
  }
}

/// Counts the number of occurrences of `c` in `str`.
///
/// @warning Unsafe if `c == NUL`.
///
/// @param str Pointer to the string to search.
/// @param c   The byte to search for.
/// @returns the number of occurrences of `c` in `str`.
size_t strcnt(const char *str, char c)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  assert(c != 0);
  size_t cnt = 0;
  while ((str = strchr(str, c))) {
    cnt++;
    str++;  // Skip the instance of c.
  }
  return cnt;
}

/// Counts the number of occurrences of byte `c` in `data[len]`.
///
/// @param data Pointer to the data to search.
/// @param c    The byte to search for.
/// @param len  The length of `data`.
/// @returns the number of occurrences of `c` in `data[len]`.
size_t memcnt(const void *data, char c, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  size_t cnt = 0;
  const char *ptr = data, *end = ptr + len;
  while ((ptr = memchr(ptr, c, (size_t)(end - ptr))) != NULL) {
    cnt++;
    ptr++;  // Skip the instance of c.
  }
  return cnt;
}

/// Copies the string pointed to by src (including the terminating NUL
/// character) into the array pointed to by dst.
///
/// @returns pointer to the terminating NUL char copied into the dst buffer.
///          This is the only difference with strcpy(), which returns dst.
///
/// WARNING: If copying takes place between objects that overlap, the behavior
/// is undefined.
///
/// Nvim version of POSIX 2008 stpcpy(3). We do not require POSIX 2008, so
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

/// Copies not more than n bytes (bytes that follow a NUL character are not
/// copied) from the array pointed to by src to the array pointed to by dst.
///
/// If a NUL character is written to the destination, xstpncpy() returns the
/// address of the first such NUL character. Otherwise, it shall return
/// &dst[maxlen].
///
/// WARNING: If copying takes place between objects that overlap, the behavior
/// is undefined.
///
/// WARNING: xstpncpy will ALWAYS write maxlen bytes. If src is shorter than
/// maxlen, zeroes will be written to the remaining bytes.
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

/// xstrlcpy - Copy a NUL-terminated string into a sized buffer
///
/// Compatible with *BSD strlcpy: the result is always a valid NUL-terminated
/// string that fits in the buffer (unless, of course, the buffer size is
/// zero). It does not pad out the result like strncpy() does.
///
/// @param[out]  dst  Buffer to store the result.
/// @param[in]  src  String to be copied.
/// @param[in]  dsize  Size of `dst`.
///
/// @return Length of `src`. May be greater than `dsize - 1`, which would mean
///         that string was truncated.
size_t xstrlcpy(char *restrict dst, const char *restrict src, size_t dsize)
  FUNC_ATTR_NONNULL_ALL
{
  size_t slen = strlen(src);

  if (dsize) {
    size_t len = MIN(slen, dsize - 1);
    memcpy(dst, src, len);
    dst[len] = '\0';
  }

  return slen;  // Does not include NUL.
}

/// Appends `src` to string `dst` of size `dsize` (unlike strncat, dsize is the
/// full size of `dst`, not space left).  At most dsize-1 characters
/// will be copied.  Always NUL terminates. `src` and `dst` may overlap.
///
/// @see vim_strcat from Vim.
/// @see strlcat from OpenBSD.
///
/// @param[in,out]  dst  Buffer to be appended-to. Must have a NUL byte.
/// @param[in]  src  String to put at the end of `dst`.
/// @param[in]  dsize  Size of `dst` including NUL byte. Must be greater than 0.
///
/// @return Length of the resulting string as if destination size was #SIZE_MAX.
///         May be greater than `dsize - 1`, which would mean that string was
///         truncated.
size_t xstrlcat(char *const dst, const char *const src, const size_t dsize)
  FUNC_ATTR_NONNULL_ALL
{
  assert(dsize > 0);
  const size_t dlen = strlen(dst);
  assert(dlen < dsize);
  const size_t slen = strlen(src);

  if (slen > dsize - dlen - 1) {
    memmove(dst + dlen, src, dsize - dlen - 1);
    dst[dsize - 1] = '\0';
  } else {
    memmove(dst + dlen, src, slen + 1);
  }

  return slen + dlen;  // Does not include NUL.
}

/// strdup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char *xstrdup(const char *str)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
  FUNC_ATTR_NONNULL_ALL
{
  return xmemdupz(str, strlen(str));
}

/// strdup() wrapper
///
/// Unlike xstrdup() allocates a new empty string if it receives NULL.
char *xstrdupnul(const char *const str)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  if (str == NULL) {
    return xmallocz(0);
  }
  return xstrdup(str);
}

/// A version of memchr that starts the search at `src + len`.
///
/// Based on glibc's memrchr.
///
/// @param src The source memory object.
/// @param c   The byte to search for.
/// @param len The length of the memory object.
/// @returns a pointer to the found byte in src[len], or NULL.
void *xmemrchr(const void *src, uint8_t c, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  while (len--) {
    if (((uint8_t *)src)[len] == c) {
      return (uint8_t *)src + len;
    }
  }
  return NULL;
}

/// strndup() wrapper
///
/// @see {xmalloc}
/// @param str 0-terminated string that will be copied
/// @return pointer to a copy of the string
char *xstrndup(const char *str, size_t len)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
  FUNC_ATTR_NONNULL_ALL
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

/// Returns true if strings `a` and `b` are equal. Arguments may be NULL.
bool strequal(const char *a, const char *b)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (a == NULL && b == NULL) || (a && b && strcmp(a, b) == 0);
}

/// Case-insensitive `strequal`.
bool striequal(const char *a, const char *b)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (a == NULL && b == NULL) || (a && b && STRICMP(a, b) == 0);
}

// Avoid repeating the error message many times (they take 1 second each).
// Did_outofmem_msg is reset when a character is read.
void do_outofmem_msg(size_t size)
{
  if (did_outofmem_msg) {
    return;
  }

  // Don't hide this message
  emsg_silent = 0;

  // Must come first to avoid coming back here when printing the error
  // message fails, e.g. when setting v:errmsg.
  did_outofmem_msg = true;

  semsg(_("E342: Out of memory!  (allocating %" PRIu64 " bytes)"), (uint64_t)size);
}

/// Writes time_t to "buf[8]".
void time_to_bytes(time_t time_, uint8_t buf[8])
{
  // time_t can be up to 8 bytes in size, more than uintmax_t in 32 bits
  // systems, thus we can't use put_bytes() here.
  for (size_t i = 7, bufi = 0; bufi < 8; i--, bufi++) {
    buf[bufi] = (uint8_t)((uint64_t)time_ >> (i * 8));
  }
}

#define ARENA_BLOCK_SIZE 4096
#define REUSE_MAX 4

static struct consumed_blk *arena_reuse_blk;
static size_t arena_reuse_blk_count = 0;

static void arena_free_reuse_blks(void)
{
  while (arena_reuse_blk_count > 0) {
    struct consumed_blk *blk = arena_reuse_blk;
    arena_reuse_blk = arena_reuse_blk->prev;
    xfree(blk);
    arena_reuse_blk_count--;
  }
}

/// Finish the allocations in an arena.
///
/// This does not immediately free the memory, but leaves existing allocated
/// objects valid, and returns an opaque ArenaMem handle, which can be used to
/// free the allocations using `arena_mem_free`, when the objects allocated
/// from the arena are not needed anymore.
ArenaMem arena_finish(Arena *arena)
{
  struct consumed_blk *res = (struct consumed_blk *)arena->cur_blk;
  *arena = (Arena)ARENA_EMPTY;
  return res;
}

void alloc_block(Arena *arena)
{
  struct consumed_blk *prev_blk = (struct consumed_blk *)arena->cur_blk;
  if (arena_reuse_blk_count > 0) {
    arena->cur_blk = (char *)arena_reuse_blk;
    arena_reuse_blk = arena_reuse_blk->prev;
    arena_reuse_blk_count--;
  } else {
    arena_alloc_count++;
    arena->cur_blk = xmalloc(ARENA_BLOCK_SIZE);
  }
  arena->pos = 0;
  arena->size = ARENA_BLOCK_SIZE;
  struct consumed_blk *blk = arena_alloc(arena, sizeof(struct consumed_blk), true);
  blk->prev = prev_blk;
}

static size_t arena_align_offset(uint64_t off)
{
  return ((off + (ARENA_ALIGN - 1)) & ~(ARENA_ALIGN - 1));
}

/// @param arena if NULL, do a global allocation. caller must then free the value!
/// @param size if zero, will still return a non-null pointer, but not a usable or unique one
void *arena_alloc(Arena *arena, size_t size, bool align)
{
  if (!arena) {
    return xmalloc(size);
  }
  if (!arena->cur_blk) {
    alloc_block(arena);
  }
  size_t alloc_pos = align ? arena_align_offset(arena->pos) : arena->pos;
  if (alloc_pos + size > arena->size) {
    if (size > (ARENA_BLOCK_SIZE - sizeof(struct consumed_blk)) >> 1) {
      // if allocation is too big, allocate a large block with the requested
      // size, but still with block pointer head. We do this even for
      // arena->size / 2, as there likely is space left for the next
      // small allocation in the current block.
      arena_alloc_count++;
      size_t hdr_size = sizeof(struct consumed_blk);
      size_t aligned_hdr_size = (align ? arena_align_offset(hdr_size) : hdr_size);
      char *alloc = xmalloc(size + aligned_hdr_size);

      // to simplify free-list management, arena->cur_blk must
      // always be a normal, ARENA_BLOCK_SIZE sized, block
      struct consumed_blk *cur_blk = (struct consumed_blk *)arena->cur_blk;
      struct consumed_blk *fix_blk = (struct consumed_blk *)alloc;
      fix_blk->prev = cur_blk->prev;
      cur_blk->prev = fix_blk;
      return alloc + aligned_hdr_size;
    } else {
      alloc_block(arena);  // resets arena->pos
      alloc_pos = align ? arena_align_offset(arena->pos) : arena->pos;
    }
  }

  char *mem = arena->cur_blk + alloc_pos;
  arena->pos = alloc_pos + size;
  return mem;
}

void arena_mem_free(ArenaMem mem)
{
  struct consumed_blk *b = mem;
  // peel of the first block, as it is guaranteed to be ARENA_BLOCK_SIZE,
  // not a custom fix_blk
  if (arena_reuse_blk_count < REUSE_MAX && b != NULL) {
    struct consumed_blk *reuse_blk = b;
    b = b->prev;
    reuse_blk->prev = arena_reuse_blk;
    arena_reuse_blk = reuse_blk;
    arena_reuse_blk_count++;
  }

  while (b) {
    struct consumed_blk *prev = b->prev;
    xfree(b);
    b = prev;
  }
}

char *arena_memdupz(Arena *arena, const char *buf, size_t size)
{
  char *mem = arena_alloc(arena, size + 1, false);
  memcpy(mem, buf, size);
  mem[size] = NUL;
  return mem;
}

#if defined(EXITFREE)

# include "nvim/autocmd.h"
# include "nvim/buffer.h"
# include "nvim/cmdhist.h"
# include "nvim/diff.h"
# include "nvim/edit.h"
# include "nvim/eval/typval.h"
# include "nvim/ex_cmds.h"
# include "nvim/ex_docmd.h"
# include "nvim/ex_getln.h"
# include "nvim/file_search.h"
# include "nvim/getchar.h"
# include "nvim/grid.h"
# include "nvim/mark.h"
# include "nvim/msgpack_rpc/channel.h"
# include "nvim/ops.h"
# include "nvim/option.h"
# include "nvim/os/os.h"
# include "nvim/quickfix.h"
# include "nvim/regexp.h"
# include "nvim/search.h"
# include "nvim/spell.h"
# include "nvim/tag.h"
# include "nvim/window.h"

// Free everything that we allocated.
// Can be used to detect memory leaks, e.g., with ccmalloc.
// NOTE: This is tricky!  Things are freed that functions depend on.  Don't be
// surprised if Vim crashes...
// Some things can't be freed, esp. things local to a library function.
void free_all_mem(void)
{
  buf_T *buf, *nextbuf;

  // When we cause a crash here it is caught and Vim tries to exit cleanly.
  // Don't try freeing everything again.
  if (entered_free_all_mem) {
    return;
  }
  entered_free_all_mem = true;
  // Don't want to trigger autocommands from here on.
  block_autocmds();

  // Close all tabs and windows.  Reset 'equalalways' to avoid redraws.
  p_ea = false;
  if (first_tabpage->tp_next != NULL) {
    do_cmdline_cmd("tabonly!");
  }

  if (!ONE_WINDOW) {
    // to keep things simple, don't perform this
    // ritual inside a float
    curwin = firstwin;
    do_cmdline_cmd("only!");
  }

  // Free all spell info.
  spell_free_all();

  // Clear user commands (before deleting buffers).
  ex_comclear(NULL);

  // Clear menus.
  do_cmdline_cmd("aunmenu *");
  do_cmdline_cmd("tlunmenu *");
  do_cmdline_cmd("menutranslate clear");

  // Clear mappings, abbreviations, breakpoints.
  // NB: curbuf not used with local=false arg
  map_clear_mode(curbuf, MAP_ALL_MODES, false, false);
  map_clear_mode(curbuf, MAP_ALL_MODES, false, true);
  do_cmdline_cmd("breakdel *");
  do_cmdline_cmd("profdel *");
  do_cmdline_cmd("set keymap=");

  free_titles();
  free_findfile();

  // Obviously named calls.
  free_all_autocmds();
  free_all_marks();
  alist_clear(&global_alist);
  free_homedir();
  free_users();
  free_search_patterns();
  free_old_sub();
  free_last_insert();
  free_insexpand_stuff();
  free_prev_shellcmd();
  free_regexp_stuff();
  free_tag_stuff();
  free_cd_dir();
  free_signs();
  set_expr_line(NULL);
  diff_clear(curtab);
  clear_sb_text(true);            // free any scrollback text

  // Free some global vars.
  xfree(last_cmdline);
  xfree(new_last_cmdline);
  set_keep_msg(NULL, 0);

  // Clear cmdline history.
  p_hi = 0;
  init_history();

  free_quickfix();

  // Close all script inputs.
  close_all_scripts();

  // Destroy all windows.  Must come before freeing buffers.
  win_free_all();

  // Free all option values.  Must come after closing windows.
  free_all_options();

  free_arshape_buf();

  // Clear registers.
  clear_registers();
  ResetRedobuff();
  ResetRedobuff();

  // highlight info
  free_highlight();

  reset_last_sourcing();

  free_tabpage(first_tabpage);
  first_tabpage = NULL;

  // message history
  while (true) {
    if (delete_first_msg() == FAIL) {
      break;
    }
  }

  eval_clear();
  api_extmark_free_all_mem();
  ctx_free_all();

  // Free all buffers.  Reset 'autochdir' to avoid accessing things that
  // were freed already.
  // Must be after eval_clear to avoid it trying to access b:changedtick after
  // freeing it.
  p_acd = false;
  for (buf = firstbuf; buf != NULL;) {
    bufref_T bufref;
    set_bufref(&bufref, buf);
    nextbuf = buf->b_next;

    // Since options (in addition to other stuff) have been freed above we need to ensure no
    // callbacks are called, so free them before closing the buffer.
    buf_free_callbacks(buf);

    close_buffer(NULL, buf, DOBUF_WIPE, false, false);
    // Didn't work, try next one.
    buf = bufref_valid(&bufref) ? nextbuf : firstbuf;
  }

  // free screenlines (can't display anything now!)
  grid_free_all_mem();

  clear_hl_tables(false);

  check_quickfix_busy();

  decor_free_all_mem();

  ui_free_all_mem();
  nlua_free_all_mem();
  rpc_free_all_mem();

  // should be last, in case earlier free functions deallocates arenas
  arena_free_reuse_blks();
}

#endif
