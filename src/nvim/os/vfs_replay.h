// VFS Deterministic Replay — Infrastructure
// SPDX-License-Identifier: Apache-2.0
//
// Logs all VFS operations crossing the mount boundary.
// Enables offline verification: record → reset → replay → verify.

#ifndef NVIM_OS_VFS_REPLAY_H
#define NVIM_OS_VFS_REPLAY_H

#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>

/// Replay operation types
typedef enum {
  VFS_REPLAY_OP_OPEN = 1,
  VFS_REPLAY_OP_READ = 2,
  VFS_REPLAY_OP_WRITE = 3,
  VFS_REPLAY_OP_CLOSE = 4,
  VFS_REPLAY_OP_STAT = 5,
  VFS_REPLAY_OP_READDIR = 6,
} VFSReplayOp;

#define VFS_REPLAY_MAGIC "NVIMRPL\0"
#define VFS_REPLAY_VERSION 1
#define VFS_REPLAY_PATH_MAX 256

/// Binary log header (fixed)
typedef struct {
  char magic[8];           // "NVIMRPL"
  uint32_t version;        // replay format version
  uint64_t session_id;     // UUID for this recording session
  uint64_t reserved;       // Future use
} VFSReplayHeader;

/// VFS operation record (variable-length)
typedef struct {
  uint64_t seq;            // Monotonic sequence number
  uint32_t op;             // VFSReplayOp enum
  int fd;                  // Synthetic fd (-1 if N/A)
  
  // Arguments (normalized)
  char path[VFS_REPLAY_PATH_MAX];
  uint64_t offset;         // For read/write
  uint64_t size;           // For read/write
  uint32_t flags;          // For open
  uint32_t mode;           // For open
  
  // Result
  int ret;                 // Return value
  int err;                 // errno (0 if success)
  
  // Data (variable-length, stored separately)
  uint64_t data_len;       // For read results, write payloads
} VFSReplayRecord;

/// Global replay session state
typedef struct {
  int enabled;             // Replay recording active
  int fd;                  // Log file descriptor
  uint64_t session_id;     // Current session UUID
  uint64_t seq;            // Sequence counter
  
  // Statistics
  uint64_t ops_logged;
  uint64_t bytes_logged;
} VFSReplaySession;

/// --- Public API ---

/// Start recording to a replay log
/// Returns 0 on success, -errno on failure
int vfs_replay_start(const char *log_path);

/// Stop recording, close log file
/// Returns 0 on success, -errno on failure
int vfs_replay_stop(void);

/// Check if recording is active
int vfs_replay_is_enabled(void);

/// Log a single VFS operation
/// Called by mount-aware VFS wrappers after permission checks
/// Returns 0 on success, -errno on failure (but does not block caller)
int vfs_replay_log_operation(
  VFSReplayOp op,
  const char *path,
  int fd,
  uint64_t offset,
  uint64_t size,
  uint32_t flags,
  uint32_t mode,
  int ret,
  int err,
  const void *data,
  uint64_t data_len
);

/// --- Replay Backend Interface ---

/// Get the replay backend
/// Replays operations from a log file instead of touching filesystem
const struct VFSBackend *vfs_backend_replay(void);

/// Reset replay backend to beginning of log
int vfs_backend_replay_reset(void);

/// Get replay statistics
void vfs_backend_replay_get_stats(
  uint64_t *ops_replayed,
  uint64_t *mismatches
);

#endif // NVIM_OS_VFS_REPLAY_H
