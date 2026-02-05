/// Deterministic RPC Mock Server for Testing
///
/// Simulates a remote RPC server with configurable failure modes:
/// - Normal operation (correct responses)
/// - Timeouts (delayed responses)
/// - Disconnects (socket closes)
/// - Corruption (malformed replies)
/// - Partial failures (some ops fail, others succeed)
///
/// All behavior is deterministic and reproducible.
/// Used to stress-test VFS backend under adversarial conditions.

#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>

#include "nvim/memory.h"

// ============================================================================
// Mock Server State
// ============================================================================

typedef enum {
  MOCK_MODE_NORMAL,         // All operations succeed normally
  MOCK_MODE_TIMEOUT,        // Simulate timeout on next N ops
  MOCK_MODE_DISCONNECT,     // Simulate disconnect/socket close
  MOCK_MODE_CORRUPTION,     // Return malformed responses
  MOCK_MODE_PARTIAL_FAIL,   // Some ops fail, others succeed
} MockMode;

typedef struct {
  MockMode mode;
  int ops_until_failure;    // For TIME_OUT, DISCONNECT modes
  int failure_probability;  // For PARTIAL_FAIL (0-100)
  
  // Tracking
  int open_count;
  int close_count;
  int read_count;
  int write_count;
  int stat_count;
  int readdir_count;
  
  // Fake filesystem (in-memory)
  struct {
    int next_fd;
    void *fake_files;  // Simple enough for testing
  } filesystem;
} MockServer;

static MockServer mock = {
  .mode = MOCK_MODE_NORMAL,
  .ops_until_failure = 0,
  .failure_probability = 0,
  .open_count = 0,
  .close_count = 0,
  .read_count = 0,
  .write_count = 0,
  .stat_count = 0,
  .readdir_count = 0,
  .filesystem = {
    .next_fd = 3,  // POSIX: 0=stdin, 1=stdout, 2=stderr
    .fake_files = NULL,
  },
};

// ============================================================================
// RPC Protocol Implementations (Mock)
// ============================================================================

/// Open file via mock RPC.
/// Overrides weak stub in vfs_backend_rpc.c
int rpc_open(const char *path, int flags, int mode)
{
  if (!path) {
    return -EINVAL;
  }

  mock.open_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT && mock.ops_until_failure-- <= 0) {
    return -EIO;  // Simulate disconnect
  }

  if (mock.mode == MOCK_MODE_TIMEOUT && mock.ops_until_failure-- <= 0) {
    return -ETIMEDOUT;  // Simulate timeout
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_CORRUPTION) {
    return -EIO;  // Corrupted response
  }

  // Normal operation: return a fake fd
  return mock.filesystem.next_fd++;
}

/// Close file via mock RPC.
int rpc_close(int fd)
{
  if (fd < 3) {
    return -EINVAL;
  }

  mock.close_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT && mock.ops_until_failure-- <= 0) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_TIMEOUT && mock.ops_until_failure-- <= 0) {
    return -ETIMEDOUT;
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  // Normal operation
  return 0;
}

/// Read from file via mock RPC.
ssize_t rpc_read(int fd, void *buf, size_t count)
{
  if (fd < 3 || !buf || count == 0) {
    return -EINVAL;
  }

  mock.read_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT && mock.ops_until_failure-- <= 0) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_TIMEOUT && mock.ops_until_failure-- <= 0) {
    return -ETIMEDOUT;
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  // Normal operation: return some test data
  size_t to_return = (count > 16) ? 16 : count;
  memset(buf, 'X', to_return);  // Fake data
  return (ssize_t)to_return;
}

/// Write to file via mock RPC.
ssize_t rpc_write(int fd, const void *buf, size_t count)
{
  if (fd < 3 || !buf || count == 0) {
    return -EINVAL;
  }

  mock.write_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT && mock.ops_until_failure-- <= 0) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_TIMEOUT && mock.ops_until_failure-- <= 0) {
    return -ETIMEDOUT;
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  // Normal operation: acknowledge the write
  return (ssize_t)count;
}

/// Stat file via mock RPC.
int rpc_stat(const char *path, struct stat *st)
{
  if (!path || !st) {
    return -EINVAL;
  }

  mock.stat_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_TIMEOUT) {
    return -ETIMEDOUT;
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  // Normal operation: return fake stats
  memset(st, 0, sizeof(struct stat));
  st->st_mode = S_IFREG | 0644;  // Regular file, r/w for owner
  st->st_size = 4096;
  st->st_mtime = 1609459200;  // 2021-01-01
  return 0;
}

/// Readdir via mock RPC.
int rpc_readdir(const char *path, struct dirent **entries, size_t *count)
{
  if (!path || !entries || !count) {
    return -EINVAL;
  }

  mock.readdir_count++;

  // Check failure modes
  if (mock.mode == MOCK_MODE_DISCONNECT) {
    return -EIO;
  }

  if (mock.mode == MOCK_MODE_TIMEOUT) {
    return -ETIMEDOUT;
  }

  if (mock.mode == MOCK_MODE_PARTIAL_FAIL && (rand() % 100) < mock.failure_probability) {
    return -EIO;
  }

  // Normal operation: return empty directory
  *entries = NULL;
  *count = 0;
  return 0;
}

// ============================================================================
// Mock Server Control API
// ============================================================================

void rpc_mock_server_init(void)
{
  mock.mode = MOCK_MODE_NORMAL;
  mock.filesystem.next_fd = 3;
  mock.open_count = 0;
  mock.close_count = 0;
  mock.read_count = 0;
  mock.write_count = 0;
  mock.stat_count = 0;
  mock.readdir_count = 0;
}

void rpc_mock_server_cleanup(void)
{
  // Nothing to clean up yet (no real socket)
}

/// Configure mock server for timeout testing.
void rpc_mock_server_set_timeout_after(int op_count)
{
  mock.mode = MOCK_MODE_TIMEOUT;
  mock.ops_until_failure = op_count;
}

/// Configure mock server for disconnect testing.
void rpc_mock_server_set_disconnect_after(int op_count)
{
  mock.mode = MOCK_MODE_DISCONNECT;
  mock.ops_until_failure = op_count;
}

/// Configure mock server for partial failure testing.
void rpc_mock_server_set_partial_fail(int probability)
{
  mock.mode = MOCK_MODE_PARTIAL_FAIL;
  mock.failure_probability = probability;  // 0-100
}

/// Reset mock server to normal mode.
void rpc_mock_server_reset(void)
{
  mock.mode = MOCK_MODE_NORMAL;
  mock.ops_until_failure = 0;
  mock.failure_probability = 0;
}

/// Get operation counts for assertions.
void rpc_mock_server_get_stats(int *opens, int *closes, int *reads, int *writes)
{
  if (opens) *opens = mock.open_count;
  if (closes) *closes = mock.close_count;
  if (reads) *reads = mock.read_count;
  if (writes) *writes = mock.write_count;
}
