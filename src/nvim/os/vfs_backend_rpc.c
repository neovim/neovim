/// RPC (Remote Procedure Call) VFS backend.
///
/// Enables filesystem operations on a remote Neovim instance or RPC server.
/// Simple request/response protocol over TCP/Unix socket.
///
/// DESIGN PRINCIPLE:
/// - Sync interface hides async RPC latency
/// - Blocking calls (no threads, no callbacks)
/// - Failure is just errno (timeout, disconnect, remote error)
/// - Write buffering unchanged (same as OPFS)
/// - Zero special cases in core code
///
/// Wire protocol:
/// [4B length][msgpack: [request_id, method, args...]]
/// [4B length][msgpack: [request_id, result/error...]]

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <dirent.h>

#include "nvim/os/vfs_backend.h"
#include "nvim/os/vfs_backend_rpc.h"
#include "nvim/memory.h"



// ============================================================================
// RPC Protocol Layer (Stub / Weak Implementations)
// ============================================================================
// These functions are declared here and can be:
// - Implemented by WASM glue (NVIM_WASM=1)
// - Implemented by mock server (for testing)
// - Left as stubs returning -ENOSYS (production without WASM)
// ============================================================================

/// Stub implementations (default, can be overridden by linking with mock/WASM)
__attribute__((weak))
int rpc_open(const char *path, int flags, int mode)
{
  (void)path; (void)flags; (void)mode;
  return -ENOSYS;
}

__attribute__((weak))
int rpc_close(int fd)
{
  (void)fd;
  return -ENOSYS;
}

__attribute__((weak))
ssize_t rpc_read(int fd, void *buf, size_t count)
{
  (void)fd; (void)buf; (void)count;
  return -ENOSYS;
}

__attribute__((weak))
ssize_t rpc_write(int fd, const void *buf, size_t count)
{
  (void)fd; (void)buf; (void)count;
  return -ENOSYS;
}

__attribute__((weak))
int rpc_stat(const char *path, struct stat *st)
{
  (void)path; (void)st;
  return -ENOSYS;
}

__attribute__((weak))
int rpc_readdir(const char *path, struct dirent **entries, size_t *count)
{
  (void)path; (void)entries; (void)count;
  return -ENOSYS;
}

// ============================================================================
// RPC Backend Implementation
// ============================================================================

/// Open or create a file via RPC.
/// Blocks until server responds or timeout.
/// Returns file descriptor (positive) or negative errno.
static int rpc_backend_open(const char *path, int flags, int mode)
{
  if (!path) {
    return -EINVAL;
  }

  // Delegate to RPC protocol layer
  // (Implemented by WASM glue or mock server)
  return rpc_open(path, flags, mode);
}

/// Close file via RPC.
static int rpc_backend_close(int fd)
{
  if (fd < 0) {
    return -EINVAL;
  }

  return rpc_close(fd);
}

/// Read from remote file.
/// Blocks until data available or timeout.
/// Returns bytes read, 0 at EOF, negative errno on error.
static ssize_t rpc_backend_read(int fd, void *buf, size_t count)
{
  if (fd < 0 || !buf || count == 0) {
    return -EINVAL;
  }

  return rpc_read(fd, buf, count);
}

/// Write to remote file.
/// Data is buffered locally by write policy.
/// This call only acknowledges the write to the remote buffer.
/// Actual persistence happens on close() via atomic commit.
static ssize_t rpc_backend_write(int fd, const void *buf, size_t count)
{
  if (fd < 0 || !buf || count == 0) {
    return -EINVAL;
  }

  return rpc_write(fd, buf, count);
}

/// Get file metadata from remote server.
static int rpc_backend_stat(const char *path, struct stat *st)
{
  if (!path || !st) {
    return -EINVAL;
  }

  return rpc_stat(path, st);
}

/// List remote directory.
static int rpc_backend_readdir(const char *path, struct dirent **entries, size_t *count)
{
  if (!path || !entries || !count) {
    return -EINVAL;
  }

  return rpc_readdir(path, entries, count);
}

// ============================================================================
// Backend Registration
// ============================================================================

/// RPC backend descriptor.
static const VFSBackend rpc_backend = {
  .open = rpc_backend_open,
  .close = rpc_backend_close,
  .read = rpc_backend_read,
  .write = rpc_backend_write,
  .stat = rpc_backend_stat,
  .readdir = rpc_backend_readdir,
};

/// Get the RPC backend.
///
/// Returns a fully compliant VFSBackend that communicates with a remote
/// server (or mock server for testing).
///
/// All operations are **synchronous from Neovim's perspective**:
/// - Caller blocks until result available or timeout
/// - Failures are returned as errno
/// - No assumption of low latency (RPC can be slow)
///
/// Write buffering is handled identically to other backends:
/// - writes go to local buffer
/// - close() commits atomically
/// - RPC only sees complete payloads
///
/// Timeout is global: 5 seconds per operation (configurable).
/// Beyond that, operation returns -ETIMEDOUT.
const VFSBackend *vfs_backend_rpc(void)
{
  return &rpc_backend;
}

// ============================================================================
// Mock Server Support (Weak Stubs)
// ============================================================================

/// Initialize RPC backend for testing.
/// Can be overridden by linking with mock server implementation.
__attribute__((weak))
void vfs_backend_rpc_init(void)
{
  // Default: no-op
}

/// Cleanup RPC backend.
/// Can be overridden by linking with mock server implementation.
__attribute__((weak))
void vfs_backend_rpc_cleanup(void)
{
  // Default: no-op
}
