#pragma once

#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>

/// Virtual filesystem backend interface.
///
/// Higher-level abstraction for alternative filesystem implementations.
/// Used internally by fs_backend_vfs.c to adapt between Neovim's FSBackend
/// interface and various storage backends (in-memory, OPFS, IndexedDB, etc.).
///
/// All paths are relative to VFS root.
/// All error codes follow POSIX errno convention (negative = error, 0 = success).

typedef struct VFSBackend {
  /// Open or create a file.
  /// @param path File path (relative to VFS root)
  /// @param flags Open flags (O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, O_TRUNC, etc.)
  /// @param mode File mode (for creation)
  /// @return File descriptor (non-negative) or negative errno
  int (*open)(const char *path, int flags, int mode);

  /// Close a file descriptor.
  /// @param fd File descriptor from open
  /// @return 0 on success, negative errno on error
  int (*close)(int fd);

  /// Read data from a file descriptor.
  /// @param fd File descriptor
  /// @param buf Output buffer
  /// @param count Bytes to read
  /// @return Bytes read (0 at EOF), or negative errno on error
  ssize_t (*read)(int fd, void *buf, size_t count);

  /// Write data to a file descriptor.
  /// @param fd File descriptor
  /// @param buf Input buffer
  /// @param count Bytes to write
  /// @return Bytes written, or negative errno on error
  ssize_t (*write)(int fd, const void *buf, size_t count);

  /// Get file metadata (follows symlinks, not used in v1).
  /// @param path File path
  /// @param st Output stat buffer
  /// @return 0 on success, negative errno on error
  int (*stat)(const char *path, struct stat *st);

  /// List directory contents.
  /// @param path Directory path
  /// @param entries Output array of struct dirent* (caller must free)
  /// @param count Output entry count
  /// @return 0 on success, negative errno on error
  int (*readdir)(const char *path, struct dirent **entries, size_t *count);
} VFSBackend;

/// Initialize the VFS backend (called at startup).
/// @param backend Backend implementation to use
void vfs_backend_init(const VFSBackend *backend);

/// Get the active VFS backend.
const VFSBackend *vfs_backend_get(void);

/// In-memory VFS backend accessor (internal use).
const VFSBackend *vfs_backend_mem(void);

/// Mount-aware VFS operations (these check permissions and resolve mounts).

/// Open or create a file (mount-aware).
/// Resolves path to correct mount, checks write permission if applicable,
/// then delegates to appropriate backend.
/// @param path Absolute file path
/// @param flags Open flags
/// @param mode File mode
/// @return File descriptor or negative errno
int vfs_open(const char *path, int flags, int mode);

/// Close a file descriptor.
/// @param fd File descriptor
/// @return 0 on success, negative errno on error
int vfs_close(int fd);

/// Read from a file descriptor.
/// @param fd File descriptor
/// @param buf Output buffer
/// @param count Bytes to read
/// @return Bytes read, 0 at EOF, or negative errno
ssize_t vfs_read(int fd, void *buf, size_t count);

/// Write to a file descriptor.
/// @param fd File descriptor
/// @param buf Input buffer
/// @param count Bytes to write
/// @return Bytes written or negative errno
ssize_t vfs_write(int fd, const void *buf, size_t count);

/// Get file metadata.
/// @param path Absolute file path
/// @param st Output stat buffer
/// @return 0 on success, negative errno on error
int vfs_stat(const char *path, struct stat *st);

/// List directory contents.
/// @param path Absolute directory path
/// @param entries Output array of struct dirent* (caller must free)
/// @param count Output entry count
/// @return 0 on success, negative errno on error
int vfs_readdir(const char *path, struct dirent **entries, size_t *count);
