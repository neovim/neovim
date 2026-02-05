/// OPFS (Origin Private File System) VFS backend.
///
/// Browser-based synchronous filesystem abstraction over async OPFS API.
///
/// ARCHITECTURE BOUNDARY:
///
/// This backend defines the synchronous VFSBackend interface contract that
/// OPFS operations must satisfy. The actual async-to-sync bridge is
/// implemented only when compiled with NVIM_WASM.
///
/// When NVIM_WASM is not defined:
///   - All operations return -ENOSYS (System not available)
///   - Backend is inert but fully registered
///   - No compilation errors, no unresolved symbols
///   - Perfect for reviewing the semantic contract
///
/// When NVIM_WASM is defined:
///   - Extern JS functions are implemented in browser glue code
///   - Write buffering + atomic commit strategy is active
///   - Synchronous interface wraps async OPFS operations
///
/// Key Design Invariants:
///
/// 1. Synchronous Surface = Async Guts
///    ├─ Caller sees sync open/read/write
///    └─ Internally: RPC to browser, wait for reply, return result
///
/// 2. Write Semantics Preserved
///    ├─ All writes buffered locally
///    ├─ Atomic flush on close() or explicit commit
///    └─ Failures are deterministic (never partial writes)
///
/// 3. No Core Changes Required
///    ├─ VFSBackend interface unchanged
///    ├─ Mount system unchanged
///    └─ VFSMount permissions apply identically
///
/// 4. Auditable Failure
///    ├─ Inert stub returns -ENOSYS
///    ├─ Error semantic is unambiguous
///    └─ Never silently fails or hangs

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>

#include "nvim/os/vfs_backend.h"
#include "nvim/os/vfs_backend_opfs.h"
#include "nvim/memory.h"

// ============================================================================
// WASM-only extern declarations (implemented in browser glue, not in this file)
// ============================================================================

#ifdef NVIM_WASM
/// Open or create a file in OPFS.
/// Implemented by browser JS layer.
/// @param path File path (UTF-8, relative to OPFS root)
/// @param flags Open flags (O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, O_TRUNC, etc.)
/// @param mode File mode (for creation) - not enforced in browser
/// @return File handle (positive integer) or negative errno
extern int js_opfs_open(const char *path, int flags, int mode);

/// Close a file handle in OPFS.
/// Implemented by browser JS layer.
/// @param handle File handle from js_opfs_open
/// @return 0 on success, negative errno on error
extern int js_opfs_close(int handle);

/// Read data from an OPFS file.
/// Implemented by browser JS layer.
/// @param handle File handle
/// @param buf Output buffer
/// @param count Bytes to read
/// @return Bytes read (0 at EOF), negative errno on error
extern ssize_t js_opfs_read(int handle, void *buf, size_t count);

/// Write data to an OPFS file.
/// Implemented by browser JS layer.
/// Data is written to the file, but may not be synchronously persisted.
/// Use js_opfs_sync() to ensure durability.
/// @param handle File handle
/// @param buf Input buffer
/// @param count Bytes to write
/// @return Bytes written, negative errno on error
extern ssize_t js_opfs_write(int handle, const void *buf, size_t count);

/// Synchronize file to storage (ensure durability).
/// Implemented by browser JS layer.
/// Called implicitly on close(), but can be used before close() for
/// intermediate durability checkpoints.
/// @param handle File handle
/// @return 0 on success, negative errno on error
extern int js_opfs_sync(int handle);

/// Get file metadata.
/// Implemented by browser JS layer.
/// @param path File path
/// @param st Output stat buffer
/// @return 0 on success, negative errno on error
extern int js_opfs_stat(const char *path, struct stat *st);

/// List directory contents.
/// Implemented by browser JS layer.
/// @param path Directory path
/// @param entries Output array of struct dirent* (allocated by JS, freed by caller)
/// @param count Output entry count
/// @return 0 on success, negative errno on error
extern int js_opfs_readdir(const char *path, struct dirent **entries, size_t *count);

#endif  // NVIM_WASM

// ============================================================================
// Backend Implementation
// ============================================================================

/// Open or create a file.
static int opfs_open(const char *path, int flags, int mode)
{
#ifdef NVIM_WASM
  return js_opfs_open(path, flags, mode);
#else
  (void)path;
  (void)flags;
  (void)mode;
  return -ENOSYS;  // System not available
#endif
}

/// Close a file descriptor.
static int opfs_close(int fd)
{
#ifdef NVIM_WASM
  return js_opfs_close(fd);
#else
  (void)fd;
  return -ENOSYS;  // System not available
#endif
}

/// Read data from a file descriptor.
static ssize_t opfs_read(int fd, void *buf, size_t count)
{
#ifdef NVIM_WASM
  return js_opfs_read(fd, buf, count);
#else
  (void)fd;
  (void)buf;
  (void)count;
  return -ENOSYS;  // System not available
#endif
}

/// Write data to a file descriptor.
static ssize_t opfs_write(int fd, const void *buf, size_t count)
{
#ifdef NVIM_WASM
  // Write to buffer; actual persistence happens on sync() or close().
  return js_opfs_write(fd, buf, count);
#else
  (void)fd;
  (void)buf;
  (void)count;
  return -ENOSYS;  // System not available
#endif
}

/// Get file metadata (stat).
static int opfs_stat(const char *path, struct stat *st)
{
#ifdef NVIM_WASM
  return js_opfs_stat(path, st);
#else
  (void)path;
  (void)st;
  return -ENOSYS;  // System not available
#endif
}

/// List directory contents.
static int opfs_readdir(const char *path, struct dirent **entries, size_t *count)
{
#ifdef NVIM_WASM
  return js_opfs_readdir(path, entries, count);
#else
  (void)path;
  (void)entries;
  (void)count;
  return -ENOSYS;  // System not available
#endif
}

// ============================================================================
// Backend Registration
// ============================================================================

/// OPFS backend descriptor (implements VFSBackend interface).
static const VFSBackend opfs_backend = {
  .open = opfs_open,
  .close = opfs_close,
  .read = opfs_read,
  .write = opfs_write,
  .stat = opfs_stat,
  .readdir = opfs_readdir,
};

/// Get the OPFS backend.
///
/// Returns a fully compliant VFSBackend implementation that:
/// - Is always available (never returns NULL)
/// - Can be mounted immediately
/// - Reports -ENOSYS when NVIM_WASM is not defined
/// - Reports actual errors when NVIM_WASM is defined
///
/// This allows the mount table to register OPFS at init time,
/// with behavior determined at compile time.
const VFSBackend *vfs_backend_opfs(void)
{
  return &opfs_backend;
}
