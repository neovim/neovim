/// @file nsfile.c
///
/// Line index over a Numstore u8 variable.
///
/// One Numstore database holds all buffers. Each buffer is one variable of
/// type u8, named after the buffer. The variable holds the text as bytes. Lines end with
/// '\n'. The last line can have no '\n' ("noeol"). An empty file has zero
/// lines.
///
/// This module keeps an in-memory index of the length of each line, so that
/// a line number maps to a byte offset without a read. All changes go to the
/// database at once, as queries ("insert", "write", "remove").
///
/// Transactions: a Numstore handle has one open transaction at most (a second
/// ns_begin() blocks). So all variables share one transaction. Its "owner" is
/// the variable that changed last. When another variable changes, the open
/// transaction is committed first. So a rollback only drops the changes of
/// the owner.
///
/// Text crosses this API in the Nvim memory format: a line has no '\n', and
/// a NUL byte in the file is a NL ('\n') in memory. This module does that
/// conversion in both directions.
///
/// Index layout: the line lengths (in bytes, including the '\n') sit in
/// chunks of at most NSF_CHUNK_MAX lines. Each chunk knows its line count and
/// its byte count. A lookup walks the chunks from a "hint" (the chunk of the
/// last lookup), so lookups near the last one are fast.

#include <assert.h>
#include <inttypes.h>
#include <numstore.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/nsfile.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/vim_defs.h"

/// Maximum number of lines in one chunk. A full chunk splits in two.
#define NSF_CHUNK_MAX 512

/// A line entry holds the byte length of the line in the low 31 bits. The top
/// bit marks the line (ml_setmarked(), used by ":global"). The mark moves with
/// the line when lines are inserted or deleted.
#define NSF_MARK 0x80000000U
#define NSF_LEN_MAX 0x7fffffffU
#define NSF_LEN(e) ((e) & NSF_LEN_MAX)

/// Bytes per read when the index is built.
#define NSF_READ_SIZE 65536

/// Size of the error message buffer.
#define kNsfErrLen 256

typedef struct {
  uint32_t *lens;   ///< each line: byte length including '\n', plus NSF_MARK
  int count;        ///< number of lines in this chunk
  int cap;          ///< allocated entries in "lens"
  uint64_t bytes;   ///< sum of the lengths in "lens"
} nsf_chunk_T;

struct nsfile {
  char *var;            ///< name of the u8 variable
  bool use_txn;         ///< changes go into the shared transaction

  nsf_chunk_T *chunks;
  int nchunks;
  int chunkcap;

  linenr_T line_count;
  uint64_t size;        ///< file size in bytes (sum of all chunks)
  bool noeol;           ///< the last line has no '\n'

  // Lookup hint: chunk "hint_chunk" starts at line "hint_lnum" and byte
  // "hint_off". A change in chunk N does not move the start of chunk N, so
  // the hint stays valid if it points at or before the changed chunk.
  int hint_chunk;
  linenr_T hint_lnum;
  uint64_t hint_off;

  // Cache of the last line returned by nsf_get().
  char *linebuf;
  size_t linebuf_cap;
  linenr_T linebuf_lnum;  ///< 0 when the cache is not valid
  size_t linebuf_len;

  // Work buffer for text in file format.
  char *scratch;
  size_t scratch_cap;

  char errmsg[kNsfErrLen];
};

/// The database that holds all variables.
static struct {
  nsdb_t *db;
  char *path;           ///< full path of the database file
  nsdb_txn_t *tx;       ///< the shared transaction, or NULL (each call commits)
  nsfile_T *owner;      ///< the variable whose changes are in "tx"
} nsdb;

#include "nsfile.c.generated.h"

// ---------------------------------------------------------------------------
// Small helpers

static void grow_buf(char **bufp, size_t *capp, size_t need)
{
  if (*capp >= need) {
    return;
  }
  size_t cap = MAX(*capp * 2, 64);
  while (cap < need) {
    cap *= 2;
  }
  *bufp = xrealloc(*bufp, cap);
  *capp = cap;
}

/// Copy the pending Numstore error into "buf", after "what".
static void ns_error_to(char *buf, size_t len, const char *what)
{
  const char *msg = nsdb.db != NULL ? ns_strerror(nsdb.db, false) : NULL;
  snprintf(buf, len, "%s: %s", what, msg != NULL ? msg : "unknown error");
  // Numstore messages can end in a newline.
  size_t n = strlen(buf);
  while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) {
    buf[--n] = NUL;
  }
}

/// Copy the pending Numstore error into f->errmsg.
static void set_ns_error(nsfile_T *f, const char *what)
{
  ns_error_to(f->errmsg, sizeof(f->errmsg), what);
}

/// Convert memory format to file format: NL becomes NUL.
static void mem_to_file(char *dst, const char *src, size_t len)
{
  for (size_t i = 0; i < len; i++) {
    dst[i] = src[i] == '\n' ? NUL : src[i];
  }
}

/// Convert file format to memory format in place: NUL becomes NL.
static void file_to_mem(char *buf, size_t len)
{
  for (size_t i = 0; i < len; i++) {
    if (buf[i] == NUL) {
      buf[i] = '\n';
    }
  }
}

static void invalidate_cache(nsfile_T *f)
{
  f->linebuf_lnum = 0;
}

// ---------------------------------------------------------------------------
// Transactions and Numstore wrappers. Each one returns OK or FAIL and sets
// an error message.

/// Commit the shared transaction (OK when none is open).
///
/// @param[out] errbuf  error message on failure
static int db_commit(char *errbuf, size_t errlen)
{
  if (nsdb.tx == NULL) {
    return OK;
  }
  nsdb_txn_t *tx = nsdb.tx;
  nsfile_T *owner = nsdb.owner;
  nsdb.tx = NULL;  // ns_commit() ends the transaction, also when it fails
  nsdb.owner = NULL;
  if (ns_commit(nsdb.db, tx) < 0) {
    ns_error_to(errbuf, errlen, "commit");
    if (owner != NULL) {
      recover_index(owner);
    }
    return FAIL;
  }
  return OK;
}

/// Get ready for a change of "f". A transaction of another variable is
/// committed first. When "f" uses transactions, one is begun for it.
static int prepare_change(nsfile_T *f)
{
  if (nsdb.tx != NULL && nsdb.owner != f) {
    if (db_commit(f->errmsg, sizeof(f->errmsg)) == FAIL) {
      return FAIL;
    }
  }
  if (f->use_txn && nsdb.tx == NULL) {
    nsdb.tx = ns_begin(nsdb.db);
    if (nsdb.tx == NULL) {
      set_ns_error(f, "begin");
      return FAIL;
    }
    nsdb.owner = f;
  }
  return OK;
}

static int ns_read_bytes(nsfile_T *f, char *dst, uint64_t off, size_t len)
{
  if (len == 0) {
    return OK;
  }
  sb_size n = ns_read(nsdb.db, nsdb.tx, dst, (b_size)len, "read %s[%" PRIu64 ":%" PRIu64 "]",
                      f->var, off, off + len);
  if (n != (sb_size)len) {
    set_ns_error(f, "read");
    return FAIL;
  }
  return OK;
}

static int ns_insert_bytes(nsfile_T *f, const char *src, uint64_t off, size_t len)
{
  if (len == 0) {
    return OK;
  }
  if (prepare_change(f) == FAIL) {
    return FAIL;
  }
  sb_size n = ns_write(nsdb.db, nsdb.tx, src, (b_size)len, "insert %s %" PRIu64 " %" PRIu64,
                       f->var, off, (uint64_t)len);
  if (n != (sb_size)len) {
    set_ns_error(f, "insert");
    return FAIL;
  }
  return OK;
}

static int ns_write_bytes(nsfile_T *f, const char *src, uint64_t off, size_t len)
{
  if (len == 0) {
    return OK;
  }
  if (prepare_change(f) == FAIL) {
    return FAIL;
  }
  sb_size n = ns_write(nsdb.db, nsdb.tx, src, (b_size)len, "write %s[%" PRIu64 ":%" PRIu64 "]",
                       f->var, off, off + len);
  if (n != (sb_size)len) {
    set_ns_error(f, "write");
    return FAIL;
  }
  return OK;
}

static int ns_remove_bytes(nsfile_T *f, uint64_t off, size_t len)
{
  if (len == 0) {
    return OK;
  }
  if (prepare_change(f) == FAIL) {
    return FAIL;
  }
  if (ns_execute(nsdb.db, nsdb.tx, "remove %s[%" PRIu64 ":%" PRIu64 "]",
                 f->var, off, off + len) < 0) {
    set_ns_error(f, "remove");
    return FAIL;
  }
  return OK;
}

/// @return the length of the variable in bytes, or -1 on failure
static sb_size ns_var_bytes(nsfile_T *f)
{
  nsdb_var_t *v = ns_get_var(nsdb.db, nsdb.tx, "get %s", f->var);
  if (v == NULL) {
    set_ns_error(f, "get");
    return -1;
  }
  b_size len = ns_var_len(v);
  ns_var_free(v);
  return (sb_size)len;
}

// ---------------------------------------------------------------------------
// Index operations. These only change memory, never the file.

static void idx_clear(nsfile_T *f)
{
  for (int i = 0; i < f->nchunks; i++) {
    xfree(f->chunks[i].lens);
  }
  xfree(f->chunks);
  f->chunks = NULL;
  f->nchunks = 0;
  f->chunkcap = 0;
  f->line_count = 0;
  f->size = 0;
  f->noeol = false;
  f->hint_chunk = 0;
  f->hint_lnum = 1;
  f->hint_off = 0;
  invalidate_cache(f);
}

/// Insert an empty chunk at index "ci".
static nsf_chunk_T *idx_new_chunk(nsfile_T *f, int ci)
{
  if (f->nchunks == f->chunkcap) {
    f->chunkcap = MAX(f->chunkcap * 2, 8);
    f->chunks = xrealloc(f->chunks, (size_t)f->chunkcap * sizeof(*f->chunks));
  }
  memmove(&f->chunks[ci + 1], &f->chunks[ci],
          (size_t)(f->nchunks - ci) * sizeof(*f->chunks));
  f->nchunks++;
  nsf_chunk_T *c = &f->chunks[ci];
  c->cap = NSF_CHUNK_MAX;
  c->lens = xmalloc((size_t)c->cap * sizeof(*c->lens));
  c->count = 0;
  c->bytes = 0;
  return c;
}

/// Append a line length at the end of the index (used when the index is built).
static void idx_push(nsfile_T *f, uint32_t len)
{
  if (f->nchunks == 0 || f->chunks[f->nchunks - 1].count == NSF_CHUNK_MAX) {
    idx_new_chunk(f, f->nchunks);
  }
  nsf_chunk_T *c = &f->chunks[f->nchunks - 1];
  c->lens[c->count++] = len;
  c->bytes += len;
  f->line_count++;
  f->size += len;
}

/// Find line "lnum". Return its chunk in "*cip", its index in that chunk in
/// "*iip", and the byte offset where the line starts in "*offp".
static void idx_locate(nsfile_T *f, linenr_T lnum, int *cip, int *iip, uint64_t *offp)
{
  assert(lnum >= 1 && lnum <= f->line_count);

  int ci = f->hint_chunk;
  linenr_T first = f->hint_lnum;
  uint64_t off = f->hint_off;
  if (ci >= f->nchunks) {
    ci = 0;
    first = 1;
    off = 0;
  }

  // Walk back or forward to the chunk that holds "lnum".
  if (lnum < first) {
    if (lnum < first / 2) {
      // Closer to the start: restart there.
      ci = 0;
      first = 1;
      off = 0;
    } else {
      while (lnum < first) {
        ci--;
        first -= f->chunks[ci].count;
        off -= f->chunks[ci].bytes;
      }
    }
  }
  while (lnum >= first + f->chunks[ci].count) {
    first += f->chunks[ci].count;
    off += f->chunks[ci].bytes;
    ci++;
  }

  f->hint_chunk = ci;
  f->hint_lnum = first;
  f->hint_off = off;

  const nsf_chunk_T *c = &f->chunks[ci];
  int ii = lnum - first;
  for (int i = 0; i < ii; i++) {
    off += NSF_LEN(c->lens[i]);
  }

  *cip = ci;
  *iip = ii;
  *offp = off;
}

/// Byte length of line "lnum", including its '\n' if it has one.
static uint32_t idx_len(nsfile_T *f, linenr_T lnum, uint64_t *offp)
{
  int ci;
  int ii;
  uint64_t off;
  idx_locate(f, lnum, &ci, &ii, &off);
  if (offp != NULL) {
    *offp = off;
  }
  return NSF_LEN(f->chunks[ci].lens[ii]);
}

/// Insert a line of "len" bytes so that it becomes line "lnum".
/// "lnum" is 1 .. line_count + 1.
static void idx_insert(nsfile_T *f, linenr_T lnum, uint32_t len)
{
  assert(lnum >= 1 && lnum <= f->line_count + 1);

  int ci;
  int ii;
  if (f->nchunks == 0) {
    idx_new_chunk(f, 0);
    ci = 0;
    ii = 0;
  } else if (lnum == f->line_count + 1) {
    ci = f->nchunks - 1;
    ii = f->chunks[ci].count;
  } else {
    uint64_t off;
    idx_locate(f, lnum, &ci, &ii, &off);
  }

  nsf_chunk_T *c = &f->chunks[ci];
  if (c->count == NSF_CHUNK_MAX) {
    // Split: move the upper half to a new chunk after this one.
    int half = c->count / 2;
    nsf_chunk_T *n = idx_new_chunk(f, ci + 1);
    c = &f->chunks[ci];  // idx_new_chunk() may move the array
    n->count = c->count - half;
    memcpy(n->lens, &c->lens[half], (size_t)n->count * sizeof(*c->lens));
    for (int i = 0; i < n->count; i++) {
      n->bytes += NSF_LEN(n->lens[i]);
    }
    c->count = half;
    c->bytes -= n->bytes;
    if (ii > half) {
      ii -= half;
      ci++;
      c = n;
    }
  }

  memmove(&c->lens[ii + 1], &c->lens[ii], (size_t)(c->count - ii) * sizeof(*c->lens));
  c->lens[ii] = len;
  c->count++;
  c->bytes += len;
  f->line_count++;
  f->size += len;

  // Chunks after "ci" moved; the hint stays valid only at or before "ci".
  if (f->hint_chunk > ci) {
    f->hint_chunk = 0;
    f->hint_lnum = 1;
    f->hint_off = 0;
  }
}

/// Remove line "lnum" from the index.
static void idx_remove(nsfile_T *f, linenr_T lnum)
{
  int ci;
  int ii;
  uint64_t off;
  idx_locate(f, lnum, &ci, &ii, &off);

  nsf_chunk_T *c = &f->chunks[ci];
  uint32_t len = NSF_LEN(c->lens[ii]);
  memmove(&c->lens[ii], &c->lens[ii + 1], (size_t)(c->count - ii - 1) * sizeof(*c->lens));
  c->count--;
  c->bytes -= len;
  f->line_count--;
  f->size -= len;

  if (c->count == 0) {
    // An empty chunk has no lines and no bytes, so the next chunk now
    // starts where this one started: the hint (at "ci") stays correct.
    xfree(c->lens);
    memmove(&f->chunks[ci], &f->chunks[ci + 1],
            (size_t)(f->nchunks - ci - 1) * sizeof(*f->chunks));
    f->nchunks--;
  }
  if (f->hint_chunk > ci || f->hint_chunk >= f->nchunks) {
    f->hint_chunk = 0;
    f->hint_lnum = 1;
    f->hint_off = 0;
  }
}

/// Add "delta" bytes to the length of line "lnum".
static void idx_adjust(nsfile_T *f, linenr_T lnum, int64_t delta)
{
  int ci;
  int ii;
  uint64_t off;
  idx_locate(f, lnum, &ci, &ii, &off);
  nsf_chunk_T *c = &f->chunks[ci];
  uint32_t mark = c->lens[ii] & NSF_MARK;
  c->lens[ii] = mark | (uint32_t)((int64_t)NSF_LEN(c->lens[ii]) + delta);
  c->bytes = (uint64_t)((int64_t)c->bytes + delta);
  f->size = (uint64_t)((int64_t)f->size + delta);
}

/// Build the index from the content of the variable.
static int idx_build(nsfile_T *f)
{
  idx_clear(f);

  sb_size fsize = ns_var_bytes(f);
  if (fsize < 0) {
    return FAIL;
  }

  char *buf = xmalloc(NSF_READ_SIZE);
  uint64_t off = 0;
  uint64_t linelen = 0;  // bytes of the current line seen so far
  int ret = OK;
  while (off < (uint64_t)fsize) {
    size_t n = (size_t)MIN((uint64_t)NSF_READ_SIZE, (uint64_t)fsize - off);
    if (ns_read_bytes(f, buf, off, n) == FAIL) {
      ret = FAIL;
      break;
    }
    const char *p = buf;
    const char *end = buf + n;
    while (p < end) {
      const char *nl = memchr(p, '\n', (size_t)(end - p));
      if (nl == NULL) {
        linelen += (uint64_t)(end - p);
        break;
      }
      linelen += (uint64_t)(nl - p) + 1;
      if (linelen > NSF_LEN_MAX) {
        snprintf(f->errmsg, sizeof(f->errmsg), "line too long");
        ret = FAIL;
        break;
      }
      idx_push(f, (uint32_t)linelen);
      linelen = 0;
      p = nl + 1;
    }
    if (ret == FAIL) {
      break;
    }
    off += n;
  }
  xfree(buf);

  if (ret == FAIL) {
    idx_clear(f);
    return FAIL;
  }
  if (linelen > 0) {
    if (linelen > NSF_LEN_MAX) {
      snprintf(f->errmsg, sizeof(f->errmsg), "line too long");
      idx_clear(f);
      return FAIL;
    }
    idx_push(f, (uint32_t)linelen);
    f->noeol = true;
  }
  assert(f->size == (uint64_t)fsize);
  return OK;
}

/// After a failed change the index may not match the file. Rebuild it.
static void recover_index(nsfile_T *f)
{
  char saved[kNsfErrLen];
  memcpy(saved, f->errmsg, sizeof(saved));
  idx_build(f);
  memcpy(f->errmsg, saved, sizeof(saved));
}

/// Does line "lnum" end with '\n'?
static bool has_eol(const nsfile_T *f, linenr_T lnum)
{
  return !(lnum == f->line_count && f->noeol);
}

/// An empty last line with no '\n' cannot exist in the file: "a\n" reads
/// back as one line. When a change leaves that state, give the last line its
/// '\n', so that the index matches what idx_build() finds.
static int fix_empty_noeol(nsfile_T *f)
{
  if (!f->noeol || f->line_count == 0 || idx_len(f, f->line_count, NULL) != 0) {
    return OK;
  }
  if (ns_insert_bytes(f, "\n", f->size, 1) == FAIL) {
    recover_index(f);
    return FAIL;
  }
  idx_adjust(f, f->line_count, 1);
  f->noeol = false;
  return OK;
}

// ---------------------------------------------------------------------------
// Public API

/// Set the path of the database that nsf_db_open() opens when it gets no path.
void nsf_set_db_path(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(nsdb.path);
  nsdb.path = FullName_save(path, false);
}

/// @return the full path of the database, or NULL when none is set
const char *nsf_db_path(void)
  FUNC_ATTR_PURE
{
  return nsdb.path;
}

/// @return true when the database is open
bool nsf_db_is_open(void)
  FUNC_ATTR_PURE
{
  return nsdb.db != NULL;
}

/// Open the database. No change if it is already open.
///
/// @param path  the database file; NULL for the path of nsf_set_db_path()
/// @param[out] errbuf  error message on failure (may be NULL)
/// @return OK or FAIL
int nsf_db_open(const char *path, char *errbuf, size_t errlen)
{
  if (nsdb.db != NULL) {
    return OK;
  }
  if (path != NULL) {
    nsf_set_db_path(path);
  }
  if (nsdb.path == NULL) {
    if (errbuf != NULL && errlen > 0) {
      snprintf(errbuf, errlen, "no database");
    }
    return FAIL;
  }
  char nserr[MAX_ERRSTR_LEN] = { 0 };
  nsdb.db = ns_open_with_error(nsdb.path, nserr, sizeof(nserr));
  if (nsdb.db == NULL) {
    if (errbuf != NULL && errlen > 0) {
      snprintf(errbuf, errlen, "%s: %s", nsdb.path,
               nserr[0] != NUL ? nserr : "cannot open database");
      size_t n = strlen(errbuf);
      while (n > 0 && (errbuf[n - 1] == '\n' || errbuf[n - 1] == '\r')) {
        errbuf[--n] = NUL;
      }
    }
    return FAIL;
  }
  return OK;
}

/// Commit the open transaction and close the database. The variables that
/// are still open must not be used after this.
///
/// @return OK or FAIL
int nsf_db_close(void)
{
  if (nsdb.db == NULL) {
    return OK;
  }
  char err[kNsfErrLen];
  int ret = db_commit(err, sizeof(err));
  if (ns_close(nsdb.db) < 0) {
    ret = FAIL;
  }
  nsdb.db = NULL;
  return ret;
}

/// Open the u8 variable "var" in the open database and build its line index.
/// Create the variable when it does not exist. Fail when it exists with
/// another type, or when Numstore does not accept "var" as a name.
///
/// @param[out] errbuf  error message on failure (may be NULL)
/// @return the file, or NULL on failure
nsfile_T *nsf_open(const char *var, char *errbuf, size_t errlen)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char err[kNsfErrLen] = "no database is open";
  if (nsdb.db == NULL) {
    goto fail;
  }

  // A new variable must not be in the transaction of another variable: a
  // rollback of that transaction would remove it again.
  if (db_commit(err, sizeof(err)) == FAIL) {
    goto fail;
  }
  // "create" does nothing when "var" is already a u8, and fails when "var"
  // has another type.
  if (ns_execute(nsdb.db, NULL, "create %s u8", var) < 0) {
    ns_error_to(err, sizeof(err), "create");
    goto fail;
  }

  nsfile_T *f = xcalloc(1, sizeof(*f));
  f->var = xstrdup(var);
  if (idx_build(f) == FAIL) {
    snprintf(err, sizeof(err), "%s", f->errmsg);
    nsf_close(f);
    goto fail;
  }
  return f;

fail:
  if (errbuf != NULL && errlen > 0) {
    snprintf(errbuf, errlen, "%s", err);
  }
  return NULL;
}

/// @return the name of the variable
const char *nsf_var(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->var;
}

/// Free the index of the variable. Its open transaction is committed first.
///
/// @return OK or FAIL (the file is freed in both cases)
int nsf_close(nsfile_T *f)
{
  if (f == NULL) {
    return OK;
  }
  int ret = nsf_commit(f);
  idx_clear(f);
  xfree(f->var);
  xfree(f->linebuf);
  xfree(f->scratch);
  xfree(f);
  return ret;
}

/// Begin a transaction. Until nsf_commit() or nsf_rollback(), changes go
/// into the shared transaction. It is begun at the first change.
///
/// @return OK
int nsf_begin(nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL
{
  f->use_txn = true;
  return OK;
}

/// Commit the changes of "f". OK when the open transaction is not of "f".
///
/// @return OK or FAIL
int nsf_commit(nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL
{
  f->use_txn = false;
  if (nsdb.tx == NULL || nsdb.owner != f) {
    return OK;
  }
  return db_commit(f->errmsg, sizeof(f->errmsg));
}

/// Roll back the changes of "f" since the last commit. Changes that a change
/// of another variable already committed stay. The index is built again.
///
/// @return OK or FAIL
int nsf_rollback(nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL
{
  f->use_txn = false;
  if (nsdb.tx == NULL || nsdb.owner != f) {
    return OK;
  }
  nsdb_txn_t *tx = nsdb.tx;
  nsdb.tx = NULL;
  nsdb.owner = NULL;
  int ret = OK;
  if (ns_rollback(nsdb.db, tx) < 0) {
    set_ns_error(f, "rollback");
    ret = FAIL;
  }
  if (idx_build(f) == FAIL) {
    ret = FAIL;
  }
  return ret;
}

/// @return true when changes go into a transaction
bool nsf_in_txn(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->use_txn;
}

/// @return the message of the last failure
const char *nsf_errmsg(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->errmsg;
}

/// @return the number of lines (0 for an empty file)
linenr_T nsf_line_count(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->line_count;
}

/// @return the size of the file in bytes
uint64_t nsf_size(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->size;
}

/// @return true when the last line has no '\n'
bool nsf_noeol(const nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  return f->noeol;
}

/// Get line "lnum" in memory format: no '\n', NUL bytes as NL, NUL-terminated.
///
/// The pointer stays valid until the next call that changes the file or the
/// next nsf_get() of another line.
///
/// @param[out] lenp  length of the line without the NUL (may be NULL)
/// @return the line, or NULL if "lnum" is out of range or the read fails
char *nsf_get(nsfile_T *f, linenr_T lnum, size_t *lenp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (lnum < 1 || lnum > f->line_count) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line %" PRId32 " out of range", lnum);
    return NULL;
  }
  if (f->linebuf_lnum != lnum) {
    uint64_t off;
    size_t len = idx_len(f, lnum, &off);
    if (has_eol(f, lnum)) {
      len--;
    }
    grow_buf(&f->linebuf, &f->linebuf_cap, len + 1);
    if (ns_read_bytes(f, f->linebuf, off, len) == FAIL) {
      invalidate_cache(f);
      return NULL;
    }
    file_to_mem(f->linebuf, len);
    f->linebuf[len] = NUL;
    f->linebuf_lnum = lnum;
    f->linebuf_len = len;
  }
  if (lenp != NULL) {
    *lenp = f->linebuf_len;
  }
  return f->linebuf;
}

/// @return length of line "lnum" without its '\n'. 0 when out of range.
size_t nsf_line_len(nsfile_T *f, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum < 1 || lnum > f->line_count) {
    return 0;
  }
  size_t len = idx_len(f, lnum, NULL);
  return has_eol(f, lnum) ? len - 1 : len;
}

/// @return byte offset where line "lnum" starts. For line_count + 1 this is
///         the file size. -1 when out of range.
int64_t nsf_line_offset(nsfile_T *f, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum < 1 || lnum > f->line_count + 1) {
    return -1;
  }
  if (lnum == f->line_count + 1) {
    return (int64_t)f->size;
  }
  int ci;
  int ii;
  uint64_t off;
  idx_locate(f, lnum, &ci, &ii, &off);
  return (int64_t)off;
}

/// Find the line that holds byte "off".
///
/// @param[out] colp  byte offset of "off" inside the line (may be NULL)
/// @return the line number, or 0 when "off" is out of range
linenr_T nsf_offset_line(nsfile_T *f, uint64_t off, size_t *colp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (off >= f->size) {
    return 0;
  }
  linenr_T first = 1;
  uint64_t start = 0;
  int ci = 0;
  while (off >= start + f->chunks[ci].bytes) {
    start += f->chunks[ci].bytes;
    first += f->chunks[ci].count;
    ci++;
  }
  const nsf_chunk_T *c = &f->chunks[ci];
  int ii = 0;
  while (off >= start + NSF_LEN(c->lens[ii])) {
    start += NSF_LEN(c->lens[ii]);
    ii++;
  }
  if (colp != NULL) {
    *colp = (size_t)(off - start);
  }
  return first + ii;
}

/// Insert a line after line "after" (0 inserts before the first line).
///
/// @param text  the line in memory format, without '\n'
/// @return OK or FAIL
int nsf_insert(nsfile_T *f, linenr_T after, const char *text, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  if (after < 0 || after > f->line_count) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line %" PRId32 " out of range", after);
    return FAIL;
  }
  if (len >= NSF_LEN_MAX) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line too long");
    return FAIL;
  }
  invalidate_cache(f);
  grow_buf(&f->scratch, &f->scratch_cap, len + 1);

  if (after == f->line_count && f->noeol) {
    // The old last line gets a '\n'. The new last line has none.
    f->scratch[0] = '\n';
    mem_to_file(f->scratch + 1, text, len);
    if (ns_insert_bytes(f, f->scratch, f->size, len + 1) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_adjust(f, after, 1);
    idx_insert(f, after + 1, (uint32_t)len);
    return fix_empty_noeol(f);
  } else {
    uint64_t off = after == f->line_count
                   ? f->size : (uint64_t)nsf_line_offset(f, after + 1);
    mem_to_file(f->scratch, text, len);
    f->scratch[len] = '\n';
    if (ns_insert_bytes(f, f->scratch, off, len + 1) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_insert(f, after + 1, (uint32_t)len + 1);
  }
  return OK;
}

/// Delete line "lnum".
///
/// @return OK or FAIL
int nsf_delete(nsfile_T *f, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum < 1 || lnum > f->line_count) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line %" PRId32 " out of range", lnum);
    return FAIL;
  }
  invalidate_cache(f);
  uint64_t off;
  uint32_t len = idx_len(f, lnum, &off);

  if (lnum == f->line_count && f->noeol && lnum > 1) {
    // Remove the '\n' of the line before too, so that the new last line
    // also has no '\n'.
    if (ns_remove_bytes(f, off - 1, (size_t)len + 1) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_remove(f, lnum);
    idx_adjust(f, lnum - 1, -1);
    return fix_empty_noeol(f);
  } else {
    if (ns_remove_bytes(f, off, len) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_remove(f, lnum);
    if (f->line_count == 0) {
      f->noeol = false;
    }
  }
  return OK;
}

/// Replace the text of line "lnum". Only the bytes that differ are written:
/// the common prefix and suffix of the old and new text stay as they are.
///
/// @param text  the new line in memory format, without '\n'
/// @return OK or FAIL
int nsf_replace(nsfile_T *f, linenr_T lnum, const char *text, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum < 1 || lnum > f->line_count) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line %" PRId32 " out of range", lnum);
    return FAIL;
  }
  if (len >= NSF_LEN_MAX) {
    snprintf(f->errmsg, sizeof(f->errmsg), "line too long");
    return FAIL;
  }

  // Get the old text. "text" can point into f->linebuf (a caller can change
  // the line it got from nsf_get()). Then the cache does not hold the old
  // text any more: read it again.
  // Grow f->scratch here once, so that it does not move below.
  grow_buf(&f->scratch, &f->scratch_cap, MAX(len, 1));
  if (f->linebuf != NULL && text >= f->linebuf && text < f->linebuf + f->linebuf_cap) {
    invalidate_cache(f);
    memcpy(f->scratch, text, len);
    text = NULL;  // use f->scratch below
  }
  size_t oldlen;
  const char *old = nsf_get(f, lnum, &oldlen);
  if (old == NULL) {
    return FAIL;
  }
  const char *new = text != NULL ? text : f->scratch;

  size_t pre = 0;
  size_t maxpre = MIN(oldlen, len);
  while (pre < maxpre && old[pre] == new[pre]) {
    pre++;
  }
  size_t suf = 0;
  size_t maxsuf = MIN(oldlen, len) - pre;
  while (suf < maxsuf && old[oldlen - 1 - suf] == new[len - 1 - suf]) {
    suf++;
  }
  size_t om = oldlen - pre - suf;  // old bytes that change
  size_t nm = len - pre - suf;     // new bytes that replace them

  if (om == 0 && nm == 0) {
    return OK;
  }

  // Convert the changed part of the new text to file format. When "new" is
  // f->scratch the conversion is done in place.
  mem_to_file(f->scratch + pre, new + pre, nm);
  const char *mid = f->scratch + pre;

  uint64_t off = (uint64_t)nsf_line_offset(f, lnum) + pre;
  invalidate_cache(f);

  size_t w = MIN(om, nm);
  if (ns_write_bytes(f, mid, off, w) == FAIL) {
    recover_index(f);
    return FAIL;
  }
  if (nm > om) {
    if (ns_insert_bytes(f, mid + w, off + w, nm - om) == FAIL) {
      recover_index(f);
      return FAIL;
    }
  } else if (om > nm) {
    if (ns_remove_bytes(f, off + w, om - nm) == FAIL) {
      recover_index(f);
      return FAIL;
    }
  }
  idx_adjust(f, lnum, (int64_t)nm - (int64_t)om);
  return fix_empty_noeol(f);
}

/// Give the last line a '\n' ("eol" true) or remove it ("eol" false).
/// No change for an empty file.
///
/// @return OK or FAIL
int nsf_set_eol(nsfile_T *f, bool eol)
  FUNC_ATTR_NONNULL_ALL
{
  if (f->line_count == 0 || eol == !f->noeol) {
    return OK;
  }
  if (!eol && idx_len(f, f->line_count, NULL) == 1) {
    // The last line is empty: it cannot lose its '\n' (see fix_empty_noeol()).
    return OK;
  }
  invalidate_cache(f);
  if (eol) {
    if (ns_insert_bytes(f, "\n", f->size, 1) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_adjust(f, f->line_count, 1);
    f->noeol = false;
  } else {
    if (ns_remove_bytes(f, f->size - 1, 1) == FAIL) {
      recover_index(f);
      return FAIL;
    }
    idx_adjust(f, f->line_count, -1);
    f->noeol = true;
  }
  return OK;
}

/// Remove the database at "path" (and the files Numstore keeps with it).
///
/// @return OK or FAIL
int nsf_cleanup(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  return ns_cleanup(path) < 0 ? FAIL : OK;
}

/// Mark line "lnum" (for ":global"). The mark moves with the line.
void nsf_setmarked(nsfile_T *f, linenr_T lnum)
  FUNC_ATTR_NONNULL_ALL
{
  if (lnum < 1 || lnum > f->line_count) {
    return;
  }
  int ci;
  int ii;
  uint64_t off;
  idx_locate(f, lnum, &ci, &ii, &off);
  f->chunks[ci].lens[ii] |= NSF_MARK;
}

/// Find the first marked line at or after "from" and clear its mark.
///
/// @return the line number, or 0 when no line is marked
linenr_T nsf_firstmarked(nsfile_T *f, linenr_T from)
  FUNC_ATTR_NONNULL_ALL
{
  from = MAX(from, 1);
  linenr_T first = 1;
  for (int ci = 0; ci < f->nchunks; ci++) {
    nsf_chunk_T *c = &f->chunks[ci];
    if (first + c->count > from) {
      for (int i = MAX(from - first, 0); i < c->count; i++) {
        if (c->lens[i] & NSF_MARK) {
          c->lens[i] &= NSF_LEN_MAX;
          return first + i;
        }
      }
    }
    first += c->count;
  }
  return 0;
}

/// Clear the marks of all lines.
void nsf_clearmarked(nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL
{
  for (int ci = 0; ci < f->nchunks; ci++) {
    nsf_chunk_T *c = &f->chunks[ci];
    for (int i = 0; i < c->count; i++) {
      c->lens[i] &= NSF_LEN_MAX;
    }
  }
}

/// Check that the index matches the file. For tests.
///
/// @return true when the index is correct
bool nsf_validate(nsfile_T *f)
  FUNC_ATTR_NONNULL_ALL
{
  nsfile_T check = { .var = f->var };
  if (idx_build(&check) == FAIL) {
    snprintf(f->errmsg, sizeof(f->errmsg), "validate: %s", check.errmsg);
    idx_clear(&check);
    return false;
  }

  bool ok = check.line_count == f->line_count
            && check.size == f->size
            && check.noeol == f->noeol;

  // Compare the line lengths one by one, and the chunk sums.
  linenr_T lnum = 1;
  uint64_t total = 0;
  for (int ci = 0; ok && ci < f->nchunks; ci++) {
    const nsf_chunk_T *c = &f->chunks[ci];
    uint64_t bytes = 0;
    ok = c->count > 0 && c->count <= NSF_CHUNK_MAX;
    for (int i = 0; ok && i < c->count; i++, lnum++) {
      bytes += NSF_LEN(c->lens[i]);
      int cci;
      int cii;
      uint64_t coff;
      idx_locate(&check, lnum, &cci, &cii, &coff);
      ok = check.chunks[cci].lens[cii] == NSF_LEN(c->lens[i]);
    }
    ok = ok && bytes == c->bytes;
    total += bytes;
  }
  ok = ok && total == f->size;

  if (!ok) {
    snprintf(f->errmsg, sizeof(f->errmsg), "validate: index does not match file");
  }
  idx_clear(&check);
  return ok;
}
