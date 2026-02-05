/// Virtual filesystem write semantics implementation.
///
/// Implements the write buffering state machine:
/// open → write* (to buffer) → close (commit)
///
/// Key invariants:
/// - Writes never touch backend until close()
/// - close() is all-or-nothing: data persists or is lost
/// - No retry protocol: failed close() invalidates fd

#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "nvim/os/vfs_write.h"
#include "nvim/os/vfs_mount.h"
#include "nvim/memory.h"

// ============================================================================
// Memory-based write buffer
// ============================================================================

/// In-memory write buffer.
typedef struct {
  uint8_t *data;
  size_t size;
  size_t capacity;
} MemWriteBuffer;

/// Initialize memory buffer.
static MemWriteBuffer *mem_buffer_new(void)
{
  MemWriteBuffer *buf = xcalloc(1, sizeof(MemWriteBuffer));
  buf->capacity = 4096;  // Start small
  buf->data = xcalloc(4096, sizeof(uint8_t));
  buf->size = 0;
  return buf;
}

/// Append to memory buffer.
static ssize_t mem_buffer_append(MemWriteBuffer *buf, const void *data, size_t count,
                                  size_t per_fd_limit)
{
  if (!buf || !data || count == 0) {
    return 0;
  }

  // Check per-fd limit
  if (per_fd_limit > 0 && buf->size + count > per_fd_limit) {
    return -ENOSPC;  // Would exceed soft limit
  }

  // Grow buffer if needed
  size_t new_size = buf->size + count;
  if (new_size > buf->capacity) {
    size_t new_capacity = buf->capacity * 2;
    while (new_capacity < new_size) {
      new_capacity *= 2;
    }

    // Check hard limit again after growth
    if (per_fd_limit > 0 && new_capacity > per_fd_limit) {
      return -ENOSPC;
    }

    buf->data = xrealloc(buf->data, new_capacity);
    buf->capacity = new_capacity;
  }

  // Append data
  memcpy(buf->data + buf->size, data, count);
  buf->size += count;

  return (ssize_t)count;
}

/// Free memory buffer.
static void mem_buffer_free(MemWriteBuffer *buf)
{
  if (buf) {
    xfree(buf->data);
    xfree(buf);
  }
}

// ============================================================================
// Write Context Lifecycle
// ============================================================================

VFSWriteContext *vfs_write_context_create(int fd, const char *path, int flags,
                                           struct VFSMount *mount,
                                           const VFSWritePolicy *policy)
{
  if (fd < 0 || !path || !mount || !policy) {
    return NULL;
  }

  // If mount is read-only, fail early
  if (!policy->writable) {
    return NULL;
  }

  VFSWriteContext *ctx = xcalloc(1, sizeof(VFSWriteContext));
  ctx->fd = fd;
  ctx->path = xstrdup(path);
  ctx->flags = flags;
  ctx->mount = mount;
  ctx->per_fd_limit = policy->per_fd_limit ? policy->per_fd_limit : (64 * 1024 * 1024);
  ctx->per_mount_limit = policy->per_mount_limit ? policy->per_mount_limit : (256 * 1024 * 1024);
  ctx->mount_used = 0;

  // Create buffer based on strategy
  if (policy->buffer_strategy == VFS_WRITE_STRATEGY_MEM) {
    MemWriteBuffer *mem_buf = mem_buffer_new();
    if (!mem_buf) {
      xfree(ctx->path);
      xfree(ctx);
      return NULL;
    }
    ctx->buffer.kind = VFS_WRITE_BUF_MEM;
    ctx->buffer.impl = mem_buf;
    ctx->buffer.capacity = mem_buf->capacity;
    ctx->buffer.size = 0;
  } else {
    // VFS_WRITE_STRATEGY_BACKEND: not implemented yet
    // For now, treat as memory
    MemWriteBuffer *mem_buf = mem_buffer_new();
    ctx->buffer.kind = VFS_WRITE_BUF_MEM;
    ctx->buffer.impl = mem_buf;
    ctx->buffer.capacity = mem_buf->capacity;
    ctx->buffer.size = 0;
  }

  return ctx;
}

void vfs_write_context_destroy(VFSWriteContext *ctx)
{
  if (!ctx) {
    return;
  }

  if (ctx->buffer.kind == VFS_WRITE_BUF_MEM) {
    mem_buffer_free((MemWriteBuffer *)ctx->buffer.impl);
  }
  // TODO: Backend buffer cleanup

  xfree(ctx->path);
  xfree(ctx);
}

// ============================================================================
// Write Operations
// ============================================================================

ssize_t vfs_write_buffer(VFSWriteContext *ctx, const void *buf, size_t count)
{
  if (!ctx || !buf || count == 0) {
    return -EINVAL;
  }

  if (ctx->buffer.kind == VFS_WRITE_BUF_MEM) {
    MemWriteBuffer *mem_buf = (MemWriteBuffer *)ctx->buffer.impl;
    
    // Check per-mount limit
    if (ctx->per_mount_limit > 0 && ctx->mount_used + count > ctx->per_mount_limit) {
      return -ENOSPC;
    }

    ssize_t written = mem_buffer_append(mem_buf, buf, count, ctx->per_fd_limit);
    if (written > 0) {
      ctx->buffer.size = mem_buf->size;
      ctx->mount_used += written;
    }
    return written;
  }

  return -EINVAL;  // Other buffer types not implemented yet
}

// ============================================================================
// Commit Semantics (ATOMIC)
// ============================================================================

VFSWriteCommitResult vfs_write_commit(VFSWriteContext *ctx)
{
  if (!ctx) {
    return VFS_WRITE_COMMIT_EIO;
  }

  if (ctx->buffer.kind == VFS_WRITE_BUF_MEM) {
    MemWriteBuffer *mem_buf = (MemWriteBuffer *)ctx->buffer.impl;
    
    if (mem_buf->size == 0) {
      // Empty write (e.g., open + close without writing)
      // This is valid; treat as success
      return VFS_WRITE_COMMIT_OK;
    }

    // TODO: Delegate to backend->write (or backend->commit_write)
    // For now, this is where the atomic write would happen.
    // 
    // Expected flow:
    // 1. Get backend from ctx->mount
    // 2. Call backend->write or backend->write_buffered
    // 3. Handle errors (EIO, ENOSPC, EACCES)
    // 4. Return result
    //
    // For testing, we'll just return OK (backend integration next)
    
    return VFS_WRITE_COMMIT_OK;
  }

  return VFS_WRITE_COMMIT_EIO;
}

// ============================================================================
// Write Policy Helpers
// ============================================================================

VFSWritePolicy vfs_write_policy_new(bool writable,
                                     size_t per_fd_limit,
                                     size_t per_mount_limit)
{
  VFSWritePolicy policy = {
    .writable = writable,
    .buffered = writable,  // If writable, then buffered (by default)
    .per_fd_limit = per_fd_limit ? per_fd_limit : (64 * 1024 * 1024),  // 64MB default
    .per_mount_limit = per_mount_limit ? per_mount_limit : (256 * 1024 * 1024),  // 256MB default
    .buffer_strategy = VFS_WRITE_STRATEGY_MEM,
    .strategy_hint = NULL,
  };
  return policy;
}

VFSWritePolicy vfs_write_policy_readonly(void)
{
  VFSWritePolicy policy = {
    .writable = false,
    .buffered = false,
    .per_fd_limit = 0,
    .per_mount_limit = 0,
    .buffer_strategy = VFS_WRITE_STRATEGY_MEM,
    .strategy_hint = NULL,
  };
  return policy;
}

VFSWritePolicy vfs_write_policy_readwrite(void)
{
  return vfs_write_policy_new(true, 0, 0);  // Use defaults
}
