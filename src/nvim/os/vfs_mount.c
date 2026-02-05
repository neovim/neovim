/// Virtual filesystem mount table implementation.
///
/// Manages the immutable mount table that defines namespace ownership.
/// Uses longest-prefix matching for efficient path resolution.

#include <string.h>
#include <errno.h>
#include <stdlib.h>

#include "nvim/os/vfs_mount.h"
#include "nvim/os/vfs_write.h"  // For write policies
#include "nvim/os/vfs_backend.h"  // For the real VFSBackend struct definition
#include "nvim/memory.h"

/// Global mount table (immutable after initialization).
static VFSMountTable mount_table = {
  .mounts = NULL,
  .count = 0,
  .capacity = 0,
};

/// Forward declaration.
static int vfs_mount_compare_by_length(const void *a, const void *b);

VFSMountTable *vfs_mount_table_get(void)
{
  return &mount_table;
}

bool vfs_mount_add(const char *mountpoint, const struct VFSBackend *backend,
                   uint32_t perms, void *backend_state,
                   struct VFSWritePolicy *write_policy)
{
  if (!mountpoint || !backend || mountpoint[0] != '/' || !write_policy) {
    return false;
  }

  // Check for duplicate
  for (size_t i = 0; i < mount_table.count; i++) {
    if (strcmp(mount_table.mounts[i].mountpoint, mountpoint) == 0) {
      return false;  // Mount already exists
    }
  }

  // Allocate more space if needed
  if (mount_table.count >= mount_table.capacity) {
    if (mount_table.capacity == 0) {
      mount_table.capacity = 8;
    } else {
      mount_table.capacity *= 2;
    }
    mount_table.mounts = xrealloc(mount_table.mounts,
                                   mount_table.capacity * sizeof(VFSMount));
  }

  // Add new mount
  size_t idx = mount_table.count;
  VFSMount *mount = &mount_table.mounts[idx];
  strncpy(mount->mountpoint, mountpoint, sizeof(mount->mountpoint) - 1);
  mount->mountpoint[sizeof(mount->mountpoint) - 1] = '\0';
  mount->backend = backend;
  mount->perms = perms;
  mount->backend_state = backend_state;
  mount->write_policy = write_policy;
  mount_table.count++;

  // Re-sort by length (longest first)
  // Using qsort with custom comparator
  qsort(mount_table.mounts, mount_table.count, sizeof(VFSMount),
        vfs_mount_compare_by_length);

  return true;
}

/// Comparator for qsort: sort mounts by path length (longest first).
static int vfs_mount_compare_by_length(const void *a, const void *b)
{
  const VFSMount *m1 = (const VFSMount *)a;
  const VFSMount *m2 = (const VFSMount *)b;

  size_t len1 = strlen(m1->mountpoint);
  size_t len2 = strlen(m2->mountpoint);

  // Descending order (longest first)
  if (len1 > len2) {
    return -1;
  } else if (len1 < len2) {
    return 1;
  } else {
    return 0;
  }
}

int vfs_mount_resolve(const char *path, VFSMount **out_mount, const char **out_subpath)
{
  if (!path || path[0] != '/' || !out_mount) {
    return -EINVAL;
  }

  // Longest-prefix match
  // Since mounts are sorted by length (longest first), we can do a linear scan
  for (size_t i = 0; i < mount_table.count; i++) {
    VFSMount *mount = &mount_table.mounts[i];
    const char *mountpoint = mount->mountpoint;
    size_t mp_len = strlen(mountpoint);

    // Check if path starts with this mountpoint
    if (strncmp(path, mountpoint, mp_len) == 0) {
      // Exact match or path continues with '/' or path is at end
      if (path[mp_len] == '\0' || path[mp_len] == '/') {
        *out_mount = mount;

        // Calculate subpath (path relative to mount)
        if (out_subpath) {
          if (strcmp(mountpoint, "/") == 0) {
            // Root mount: subpath is the whole path
            *out_subpath = path;
          } else {
            // Other mounts: subpath is path after mountpoint
            if (path[mp_len] == '\0') {
              // Path is exactly the mountpoint
              *out_subpath = "/";
            } else {
              // Path continues after mountpoint
              *out_subpath = &path[mp_len];
            }
          }
        }
        return 0;
      }
    }
  }

  // No mount found (shouldn't happen if "/" is always mounted)
  return -ENOENT;
}

bool vfs_mount_check_perm(const VFSMount *mount, uint32_t perm)
{
  if (!mount) {
    return false;
  }
  return (mount->perms & perm) == perm;
}

void vfs_mount_table_init(void)
{
  if (mount_table.count > 0) {
    return;  // Already initialized
  }

  // Initialize the in-memory VFS backend
  vfs_backend_init(NULL);
  const VFSBackend *mem_backend = vfs_backend_mem();

  // Create write policies for each mount
  
  // "/" - root, RW
  VFSWritePolicy *root_policy = xcalloc(1, sizeof(VFSWritePolicy));
  *root_policy = vfs_write_policy_readwrite();
  vfs_mount_add("/", mem_backend, VFS_PERM_RW, NULL, root_policy);

  // "/runtime" - read-only, for system runtime files
  VFSWritePolicy *runtime_policy = xcalloc(1, sizeof(VFSWritePolicy));
  *runtime_policy = vfs_write_policy_readonly();
  vfs_mount_add("/runtime", mem_backend, VFS_PERM_RO, NULL, runtime_policy);

  // "/workspace" - read-write, for workspace files
  VFSWritePolicy *workspace_policy = xcalloc(1, sizeof(VFSWritePolicy));
  *workspace_policy = vfs_write_policy_readwrite();
  vfs_mount_add("/workspace", mem_backend, VFS_PERM_RW, NULL, workspace_policy);

  // ============================================================================
  // Phase 9.4: Plugin Mounts (dual-layer architecture)
  // ============================================================================
  
  // "/plugins-readonly" - system plugins, immutable
  VFSWritePolicy *plugins_ro_policy = xcalloc(1, sizeof(VFSWritePolicy));
  *plugins_ro_policy = vfs_write_policy_readonly();
  vfs_mount_add("/plugins-readonly", mem_backend, VFS_PERM_RO, NULL, plugins_ro_policy);

  // "/plugins-local" - user plugins, writable
  VFSWritePolicy *plugins_local_policy = xcalloc(1, sizeof(VFSWritePolicy));
  *plugins_local_policy = vfs_write_policy_readwrite();
  vfs_mount_add("/plugins-local", mem_backend, VFS_PERM_RW, NULL, plugins_local_policy);
}

void vfs_mount_table_cleanup(void)
{
  if (mount_table.mounts) {
    xfree(mount_table.mounts);
    mount_table.mounts = NULL;
    mount_table.count = 0;
    mount_table.capacity = 0;
  }
}
