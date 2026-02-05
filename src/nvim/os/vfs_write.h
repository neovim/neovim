#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/// Virtual filesystem write semantics and buffering.
///
/// **Critical invariant: writes are buffered, close() commits atomically.**
///
/// This layer defines:
/// - Write context lifetime (open → write* → close)
/// - Buffer abstraction (memory, backend temp, or strategy-specific)
/// - Commit semantics (all-or-nothing on close)
/// - Failure handling (failed close = data lost, fd invalid)
///
/// Design rationale:
///
/// Why buffer? Atomicity. Without buffering, partial writes are visible.
/// Why per-mount policy? Constraints differ (browser RAM vs POSIX disk).
/// Why commit at close? POSIX semantics + transactional boundary.
/// Why fail at close? Matches close(2) behavior; caller must retry by reopening.

/// ============================================================================
/// Write Buffer Abstraction
/// ============================================================================

/// Buffer kind: memory vs backend-managed staging.
typedef enum {
  VFS_WRITE_BUF_MEM,          ///< Write to RAM (native POSIX, memfs, small files)
  VFS_WRITE_BUF_BACKEND,      ///< Write to backend temp (OPFS, remote staging)
} VFSWriteBufferKind;

/// Write buffer (opaque to callers).
/// Internals depend on kind (see vfs_write.c).
typedef struct VFSWriteBuffer {
  VFSWriteBufferKind kind;
  void *impl;                 ///< Backend-specific implementation
  size_t size;                ///< Current write position
  size_t capacity;            ///< Total allocated
} VFSWriteBuffer;

/// ============================================================================
/// Write Context (per fd)
/// ============================================================================

/// Write context: tracks buffer and metadata for an open file.
///
/// Created on open(), destroyed on close().
/// One per open file descriptor that was opened for writing.
typedef struct {
  int fd;                     ///< File descriptor from backend
  VFSWriteBuffer buffer;      ///< Private write buffer
  const char *path;           ///< Path (for error reporting)
  int flags;                  ///< O_WRONLY, O_APPEND, etc.
  struct VFSMount *mount;     ///< Which mount owns this fd
  
  // Limits (from mount policy)
  size_t per_fd_limit;        ///< Per-fd soft cap (e.g. 64MB)
  size_t per_mount_limit;     ///< Per-mount hard cap (e.g. 256MB)
  size_t mount_used;          ///< Current mount total (shared across fds)
} VFSWriteContext;

/// ============================================================================
/// Mount Write Policy
/// ============================================================================

/// Write policy for a mount: defines buffer strategy and limits.
///
/// Set once when mount is created, immutable after.
/// Controls whether writes are buffered, how they're buffered, and limits.
typedef struct {
  bool writable;              ///< Can this mount accept writes? (else fail at open)
  bool buffered;              ///< Must writes use buffering? (no bypass to backend)
  
  // Limits (per-fd and per-mount)
  size_t per_fd_limit;        ///< Soft limit per fd (0 = unbounded)
  size_t per_mount_limit;     ///< Hard limit total on mount (0 = unbounded)
  
  // Strategy
  enum {
    VFS_WRITE_STRATEGY_MEM,       ///< Buffer in RAM (default)
    VFS_WRITE_STRATEGY_BACKEND,   ///< Buffer in backend temp (OPFS, cloud)
  } buffer_strategy;
  
  // Optional: backend may override strategy (e.g., OPFS forces backend temp)
  void *strategy_hint;        ///< Backend-specific strategy context
} VFSWritePolicy;

/// ============================================================================
/// Write Semantics: Commit and Failure
/// ============================================================================

/// Commit result codes.
typedef enum {
  VFS_WRITE_COMMIT_OK,              ///< Success, data persisted
  VFS_WRITE_COMMIT_ENOSPC,          ///< No space (hard limit reached)
  VFS_WRITE_COMMIT_EIO,             ///< I/O error during commit
  VFS_WRITE_COMMIT_EACCES,          ///< Permission denied after recheck
  VFS_WRITE_COMMIT_BACKEND_FAILED,  ///< Backend-specific failure
} VFSWriteCommitResult;

/// ============================================================================
/// Close Semantics (CRITICAL)
/// ============================================================================

/// **Invariant: close() always invalidates the fd.**
///
/// This matches POSIX close(2) behavior:
/// - If commit succeeds: data persisted, fd invalid, return 0
/// - If commit fails: data NOT persisted, fd invalid, return error
///
/// **Caller must NOT retry using same fd.**
/// Caller must reopen if they wish to retry.
///
/// This is transactional: either all writes commit, or none do.
/// No partial state is left behind.

/// ============================================================================
/// Public API: Write Context Lifecycle
/// ============================================================================

/// Create a write context for a file opened for writing.
/// Called from vfs_open() when flags include O_WRONLY or O_RDWR with O_CREAT.
///
/// @param fd File descriptor from backend
/// @param path Path being opened (for error reporting)
/// @param flags Open flags (O_WRONLY, O_APPEND, etc.)
/// @param mount Mount that owns this fd
/// @param policy Write policy from mount
/// @return New write context, or NULL if allocation failed
VFSWriteContext *vfs_write_context_create(int fd, const char *path, int flags,
                                           struct VFSMount *mount,
                                           const VFSWritePolicy *policy);

/// Destroy a write context (called from vfs_close).
/// Does NOT commit; just frees resources.
///
/// @param ctx Write context to destroy
void vfs_write_context_destroy(VFSWriteContext *ctx);

/// ============================================================================
/// Public API: Write Operations
/// ============================================================================

/// Append data to write buffer (does NOT write to backend).
///
/// @param ctx Write context
/// @param buf Data to write
/// @param count Bytes to write
/// @return Bytes appended, or negative errno on error
ssize_t vfs_write_buffer(VFSWriteContext *ctx, const void *buf, size_t count);

/// Commit buffer to backend (atomic).
/// Called from vfs_close() before destroying context.
///
/// **After this call, data either fully persists or not at all.**
/// **On error, no partial state is left in the backend.**
///
/// @param ctx Write context
/// @return VFS_WRITE_COMMIT_OK on success, or error code
VFSWriteCommitResult vfs_write_commit(VFSWriteContext *ctx);

/// ============================================================================
/// Helper: Create default write policy for a mount
/// ============================================================================

/// Create a standard write policy for a mount.
/// Caller specifies behavior; we fill in defaults.
///
/// @param writable Can this mount accept writes?
/// @param per_fd_limit Per-fd soft limit (0 = 64MB default)
/// @param per_mount_limit Per-mount hard limit (0 = 256MB default)
/// @return Initialized policy
VFSWritePolicy vfs_write_policy_new(bool writable,
                                     size_t per_fd_limit,
                                     size_t per_mount_limit);

/// Read-only policy (e.g., /runtime).
VFSWritePolicy vfs_write_policy_readonly(void);

/// Read-write policy (e.g., /workspace, /plugins).
VFSWritePolicy vfs_write_policy_readwrite(void);
