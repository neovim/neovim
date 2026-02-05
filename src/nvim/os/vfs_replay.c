// VFS Deterministic Replay — Implementation
// SPDX-License-Identifier: Apache-2.0
//
// Binary log format ensures deterministic replay.
// Logging happens at mount boundary (after permission checks, before backend delegation).

#include "nvim/os/vfs_replay.h"
#include "nvim/os/vfs_backend.h"
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <time.h>

/// Global replay session
static VFSReplaySession replay_session = {
  .enabled = 0,
  .fd = -1,
  .session_id = 0,
  .seq = 0,
  .ops_logged = 0,
  .bytes_logged = 0,
};

/// --- Recording ---

/// Generate a simple session UUID (time-based, not cryptographic)
static uint64_t vfs_replay_generate_session_id(void) {
  return (uint64_t)time(NULL) << 32;
}

/// Write data to log file with error handling
static int vfs_replay_write_all(const void *buf, size_t count) {
  if (!replay_session.enabled || replay_session.fd < 0) {
    return 0;  // Silently ignore if not recording
  }
  
  const uint8_t *p = (const uint8_t *)buf;
  size_t remaining = count;
  
  while (remaining > 0) {
    ssize_t written = write(replay_session.fd, p, remaining);
    if (written < 0) {
      // Silently disable on write error
      replay_session.enabled = 0;
      return -errno;
    }
    if (written == 0) {
      return -EIO;  // Unexpected EOF
    }
    p += written;
    remaining -= written;
  }
  
  return 0;
}

int vfs_replay_start(const char *log_path) {
  if (replay_session.enabled) {
    return -EALREADY;  // Already recording
  }
  
  if (!log_path) {
    return -EINVAL;
  }
  
  // Create log file
  int fd = open(log_path, O_CREAT | O_WRONLY | O_TRUNC, 0600);
  if (fd < 0) {
    return -errno;
  }
  
  // Write header
  VFSReplayHeader header = {
    .magic = VFS_REPLAY_MAGIC,
    .version = VFS_REPLAY_VERSION,
    .session_id = vfs_replay_generate_session_id(),
    .reserved = 0,
  };
  
  ssize_t written = write(fd, &header, sizeof(header));
  if (written < 0) {
    int err = errno;
    close(fd);
    return -err;
  }
  if (written != sizeof(header)) {
    close(fd);
    return -EIO;
  }
  
  // Activate
  replay_session.fd = fd;
  replay_session.session_id = header.session_id;
  replay_session.seq = 0;
  replay_session.ops_logged = 0;
  replay_session.bytes_logged = sizeof(header);
  replay_session.enabled = 1;
  
  return 0;
}

int vfs_replay_stop(void) {
  if (!replay_session.enabled || replay_session.fd < 0) {
    return 0;
  }
  
  replay_session.enabled = 0;
  int fd = replay_session.fd;
  replay_session.fd = -1;
  
  if (close(fd) < 0) {
    return -errno;
  }
  
  return 0;
}

int vfs_replay_is_enabled(void) {
  return replay_session.enabled;
}

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
) {
  if (!replay_session.enabled) {
    return 0;  // Not recording
  }
  
  // Build record
  VFSReplayRecord record = {
    .seq = replay_session.seq++,
    .op = op,
    .fd = fd,
    .offset = offset,
    .size = size,
    .flags = flags,
    .mode = mode,
    .ret = ret,
    .err = err,
    .data_len = data_len,
  };
  
  // Normalize path
  if (path) {
    strncpy(record.path, path, VFS_REPLAY_PATH_MAX - 1);
    record.path[VFS_REPLAY_PATH_MAX - 1] = '\0';
  } else {
    record.path[0] = '\0';
  }
  
  // Write record
  int write_result = vfs_replay_write_all(&record, sizeof(record));
  if (write_result < 0) {
    return write_result;
  }
  
  // Write data payload if present
  if (data && data_len > 0) {
    write_result = vfs_replay_write_all(data, data_len);
    if (write_result < 0) {
      return write_result;
    }
  }
  
  replay_session.ops_logged++;
  replay_session.bytes_logged += sizeof(record) + data_len;
  
  return 0;
}

/// --- Replay Backend ---

/// Replay session state
typedef struct {
  int log_fd;
  uint64_t current_pos;  // Position in log for seeking
  VFSReplayRecord current_record;
  uint8_t data_buffer[8192];  // Hold data payload between reads
  int mismatch_count;
} VFSReplayBackendState;

static VFSReplayBackendState replay_backend_state = {
  .log_fd = -1,
  .current_pos = 0,
  .mismatch_count = 0,
};

/// Verify next operation matches expected call
/// Returns 0 on match, -EPERM on mismatch, -EIO on read error
static int replay_verify_operation(VFSReplayOp expected_op,
                                     const char *expected_path) {
  // Read next record
  ssize_t nr = read(replay_backend_state.log_fd,
                    &replay_backend_state.current_record,
                    sizeof(VFSReplayRecord));
  
  if (nr < 0) {
    return -EIO;
  }
  if (nr == 0) {
    return -ENOENT;  // End of log
  }
  if (nr != sizeof(VFSReplayRecord)) {
    return -EIO;  // Partial read
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  
  // Verify operation type
  if (r->op != expected_op) {
    replay_backend_state.mismatch_count++;
    return -EPERM;  // Operation mismatch
  }
  
  // Verify path
  if (expected_path && strcmp(r->path, expected_path) != 0) {
    replay_backend_state.mismatch_count++;
    return -EPERM;  // Path mismatch
  }
  
  // Read data payload if present
  if (r->data_len > 0) {
    if (r->data_len > sizeof(replay_backend_state.data_buffer)) {
      return -EOVERFLOW;
    }
    ssize_t nr_data = read(replay_backend_state.log_fd,
                           replay_backend_state.data_buffer,
                           r->data_len);
    if (nr_data != (ssize_t)r->data_len) {
      return -EIO;
    }
  }
  
  return 0;
}

/// Replay backend: open
static int replay_backend_open(const char *path, int flags, int mode) {
  (void)flags; (void)mode;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_OPEN, path);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  return r->ret;  // Return recorded result
}

/// Replay backend: read
static ssize_t replay_backend_read(int fd, void *buf, size_t count) {
  (void)count;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_READ, NULL);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  
  if (r->ret < 0) {
    return r->ret;  // Error result
  }
  
  // Copy recorded data to buffer
  if (r->ret > 0 && r->data_len > 0) {
    memcpy(buf, replay_backend_state.data_buffer, r->data_len);
  }
  
  return r->ret;
}

/// Replay backend: write
static ssize_t replay_backend_write(int fd, const void *buf, size_t count) {
  (void)buf; (void)count;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_WRITE, NULL);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  return r->ret;
}

/// Replay backend: close
static int replay_backend_close(int fd) {
  (void)fd;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_CLOSE, NULL);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  return r->ret;
}

/// Replay backend: stat
static int replay_backend_stat(const char *path, struct stat *st) {
  (void)st;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_STAT, path);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  
  // Minimal stat info from log (future: store full stat in data)
  if (r->ret == 0 && r->data_len >= sizeof(struct stat)) {
    memcpy(st, replay_backend_state.data_buffer, sizeof(struct stat));
  }
  
  return r->ret;
}

/// Replay backend: readdir
static int replay_backend_readdir(const char *path, struct dirent **entries, size_t *count) {
  (void)entries; (void)count;
  
  int result = replay_verify_operation(VFS_REPLAY_OP_READDIR, path);
  if (result < 0) {
    return result;
  }
  
  VFSReplayRecord *r = &replay_backend_state.current_record;
  return r->ret;
}

/// Get replay backend accessor
const VFSBackend *vfs_backend_replay(void) {
  static const VFSBackend backend = {
    .open = replay_backend_open,
    .close = replay_backend_close,
    .read = replay_backend_read,
    .write = replay_backend_write,
    .stat = replay_backend_stat,
    .readdir = replay_backend_readdir,
  };
  return &backend;
}

int vfs_backend_replay_reset(void) {
  if (replay_backend_state.log_fd < 0) {
    return -EINVAL;
  }
  
  // Seek past header
  if (lseek(replay_backend_state.log_fd, sizeof(VFSReplayHeader), SEEK_SET) < 0) {
    return -errno;
  }
  
  replay_backend_state.mismatch_count = 0;
  return 0;
}

void vfs_backend_replay_get_stats(uint64_t *ops_replayed, uint64_t *mismatches) {
  if (ops_replayed) {
    *ops_replayed = 0;  // Would track during replay
  }
  if (mismatches) {
    *mismatches = (uint64_t)replay_backend_state.mismatch_count;
  }
}
