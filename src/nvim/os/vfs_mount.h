#pragma once

#include <stdint.h>
#include <stdbool.h>

/// Virtual filesystem mount table.
///
/// Semantic boundary: defines which backend owns each path and what operations
/// are allowed on it.
///
/// Design principles:
/// - Mount table is immutable during a session
/// - Longest-prefix match determines the owning mount
/// - "/" is always mounted (to some backend)
/// - Permissions are explicit, not implicit
/// - No dynamic remounting (can be added in v2)

/// Mount permissions (explicit model, not POSIX bits).
#define VFS_PERM_READ   (1 << 0)  ///< Read files
#define VFS_PERM_WRITE  (1 << 1)  ///< Write/create files
#define VFS_PERM_CREATE (1 << 2)  ///< Create new files/dirs
#define VFS_PERM_DELETE (1 << 3)  ///< Delete files/dirs
#define VFS_PERM_EXEC   (1 << 4)  ///< Execute files

/// Default permission sets.
#define VFS_PERM_RO     (VFS_PERM_READ | VFS_PERM_EXEC)
#define VFS_PERM_RW     (VFS_PERM_READ | VFS_PERM_WRITE | VFS_PERM_CREATE | VFS_PERM_DELETE | VFS_PERM_EXEC)
#define VFS_PERM_NONE   0

/// Forward declaration: VFSBackend (defined in vfs_backend.h).
struct VFSBackend;

/// Forward declaration: VFSWritePolicy (defined in vfs_write.h).
struct VFSWritePolicy;

/// Single mount point in the VFS.
///
/// Mounts are ordered by mountpoint length (longest first) for efficient
/// longest-prefix matching. The mount table is built at startup and
/// remains immutable.
typedef struct {
  char mountpoint[256];                  ///< Mount path: "/", "/runtime", "/workspace", etc.
  struct VFSBackend *backend;            ///< Backend implementation for this mount
  uint32_t perms;                        ///< Permission flags (VFS_PERM_*)
  void *backend_state;                   ///< Backend-specific state (e.g., in-memory VFS root)
  struct VFSWritePolicy *write_policy;   ///< Write policy (buffering, limits, atomicity)
} VFSMount;

/// Mount table (global, immutable during session).
typedef struct {
  VFSMount *mounts;           ///< Array of mount points (ordered by length, longest first)
  size_t count;               ///< Number of mounts
  size_t capacity;            ///< Allocated capacity
} VFSMountTable;

/// Get the global mount table.
VFSMountTable *vfs_mount_table_get(void);

/// Initialize the mount table with default mounts.
/// Called once at startup.
/// Sets up:
///   "/" -> in-memory backend (RW)
///   "/runtime" -> in-memory backend (RO)
///   "/workspace" -> in-memory backend (RW)
void vfs_mount_table_init(void);

/// Add a mount to the table.
/// Mounts are automatically sorted by length (longest first) for prefix matching.
/// Returns false if table is full or mount already exists.
bool vfs_mount_add(const char *mountpoint, const struct VFSBackend *backend,
                   uint32_t perms, void *backend_state,
                   struct VFSWritePolicy *write_policy);

/// Resolve a path to its mount point and relative path.
/// Uses longest-prefix matching.
///
/// @param path Absolute path to resolve
/// @param out_mount Output: pointer to the resolved mount
/// @param out_subpath Output: path relative to mount (if not NULL)
/// @return 0 on success, -EINVAL if path is invalid, -ENOENT if no mount found
int vfs_mount_resolve(const char *path, VFSMount **out_mount, const char **out_subpath);

/// Check if a mount allows a specific operation.
/// Permission checks happen at open() time, before any operation.
///
/// @param mount The mount point
/// @param perm Permission flag (VFS_PERM_READ, VFS_PERM_WRITE, etc.)
/// @return true if operation is allowed
bool vfs_mount_check_perm(const VFSMount *mount, uint32_t perm);

/// Cleanup mount table (called at shutdown).
void vfs_mount_table_cleanup(void);
