/// In-memory virtual filesystem backend.
///
/// Deterministic, single-threaded filesystem implementation.
/// All operations are synchronous and reproducible.
///
/// Tree structure:
///   - Root node "/"
///   - Child nodes (files or directories)
///   - Files have content buffers
///
/// File descriptors:
///   - Numbered from 3 (following POSIX: 0=stdin, 1=stdout, 2=stderr)
///   - Track node, current offset, and open flags

#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "nvim/os/vfs_backend.h"
#include "nvim/os/vfs_mount.h"
#include "nvim/os/vfs_write.h"
#include "nvim/os/vfs_replay.h"
#include "nvim/memory.h"

#define VFS_MAX_FDS 256
#define VFS_MAX_NODES 10000
#define VFS_MAX_FILENAME 255

/// File/directory node in the VFS tree.
typedef struct VFSNode {
  char name[VFS_MAX_FILENAME + 1];  ///< File/directory name
  bool is_dir;                       ///< true = directory, false = file
  struct VFSNode *parent;            ///< Parent directory (NULL for root)
  struct VFSNode **children;         ///< Child nodes (only for directories)
  size_t child_count;
  size_t child_capacity;

  // For files only:
  uint8_t *content;                 ///< File content buffer
  size_t size;                       ///< Current file size
  size_t capacity;                   ///< Buffer capacity
} VFSNode;

/// Open file descriptor state.
typedef struct {
  VFSNode *node;                    ///< File node
  size_t offset;                    ///< Read/write offset
  int flags;                         ///< Open flags (O_RDONLY, O_WRONLY, etc.)
} VFSFile;

/// In-memory VFS state.
static struct {
  VFSNode *root;
  VFSFile fds[VFS_MAX_FDS];
  int fd_count;
  size_t file_count;
} vfs_mem_state = {
  .root = NULL,
  .fd_count = 0,
  .file_count = 0,
};

// Forward declarations
static VFSNode *vfs_mem_find_node(const char *path);
static VFSNode *vfs_mem_find_or_create_dir(const char *path);
static int vfs_mem_create_file(const char *path, int flags, int mode);
static void vfs_mem_free_node(VFSNode *node);

/// Parse a path into components.
/// Modifies a temporary copy of the path.
/// @param path Absolute path (must start with "/")
/// @param parts Output array of path components
/// @param max_parts Maximum components
/// @return Component count
static int vfs_mem_parse_path(const char *path, const char **parts, int max_parts)
{
  if (!path || path[0] != '/' || strlen(path) > 4096) {
    return -1;
  }

  int count = 0;
  char *copy = xstrdup(path);
  char *saveptr = NULL;
  const char *tok = strtok_r(copy + 1, "/", &saveptr);  // Skip leading /

  while (tok && count < max_parts) {
    if (strlen(tok) > 0 && strlen(tok) <= VFS_MAX_FILENAME) {
      parts[count++] = tok;
    }
    tok = strtok_r(NULL, "/", &saveptr);
  }

  xfree(copy);
  return count;
}

/// Find a node by absolute path.
/// @return Node pointer or NULL if not found
static VFSNode *vfs_mem_find_node(const char *path)
{
  if (!path || path[0] != '/') {
    return NULL;
  }

  // Root directory
  if (strcmp(path, "/") == 0) {
    return vfs_mem_state.root;
  }

  const char *parts[256];
  int part_count = vfs_mem_parse_path(path, parts, 256);
  if (part_count <= 0) {
    return NULL;
  }

  VFSNode *current = vfs_mem_state.root;
  for (int i = 0; i < part_count; i++) {
    if (!current->is_dir) {
      return NULL;  // Traversing through a file
    }
    bool found = false;
    for (size_t j = 0; j < current->child_count; j++) {
      if (strcmp(current->children[j]->name, parts[i]) == 0) {
        current = current->children[j];
        found = true;
        break;
      }
    }
    if (!found) {
      return NULL;
    }
  }

  return current;
}

/// Create a node with the given name.
static VFSNode *vfs_mem_create_node(const char *name, bool is_dir)
{
  VFSNode *node = xcalloc(1, sizeof(VFSNode));
  strncpy(node->name, name, VFS_MAX_FILENAME);
  node->name[VFS_MAX_FILENAME] = '\0';
  node->is_dir = is_dir;
  node->parent = NULL;

  if (is_dir) {
    node->child_capacity = 16;
    node->children = xcalloc(16, sizeof(VFSNode *));
    node->child_count = 0;
  } else {
    node->capacity = 1024;
    node->content = xcalloc(1024, sizeof(uint8_t));
    node->size = 0;
  }

  vfs_mem_state.file_count++;
  return node;
}

/// Ensure all parent directories exist.
static VFSNode *vfs_mem_find_or_create_dir(const char *path)
{
  if (!path || path[0] != '/') {
    return NULL;
  }

  if (strcmp(path, "/") == 0) {
    return vfs_mem_state.root;
  }

  const char *parts[256];
  int part_count = vfs_mem_parse_path(path, parts, 256);
  if (part_count <= 0) {
    return NULL;
  }

  VFSNode *current = vfs_mem_state.root;
  for (int i = 0; i < part_count; i++) {
    if (!current->is_dir) {
      return NULL;
    }

    // Find or create child
    VFSNode *child = NULL;
    for (size_t j = 0; j < current->child_count; j++) {
      if (strcmp(current->children[j]->name, parts[i]) == 0) {
        child = current->children[j];
        break;
      }
    }

    if (!child) {
      // Create new directory
      child = vfs_mem_create_node(parts[i], true);
      child->parent = current;

      // Add to parent's children
      if (current->child_count >= current->child_capacity) {
        current->child_capacity *= 2;
        current->children = xrealloc(current->children,
                                     current->child_capacity * sizeof(VFSNode *));
      }
      current->children[current->child_count++] = child;
    }

    if (!child->is_dir) {
      return NULL;  // Path component is a file
    }

    current = child;
  }

  return current;
}

/// Initialize the in-memory VFS.
static void vfs_mem_init(void)
{
  if (vfs_mem_state.root) {
    return;  // Already initialized
  }

  // Create root directory
  vfs_mem_state.root = vfs_mem_create_node("", true);
  vfs_mem_state.root->parent = NULL;

  // FDs 0, 1, 2 are reserved (stdin, stdout, stderr)
  // Start allocating from fd 3
  for (int i = 0; i < VFS_MAX_FDS; i++) {
    vfs_mem_state.fds[i].node = NULL;
    vfs_mem_state.fds[i].offset = 0;
    vfs_mem_state.fds[i].flags = 0;
  }
}

/// Allocate a file descriptor.
static int vfs_mem_alloc_fd(void)
{
  // Start from fd 3 (reserve 0, 1, 2)
  for (int fd = 3; fd < VFS_MAX_FDS; fd++) {
    if (vfs_mem_state.fds[fd].node == NULL) {
      return fd;
    }
  }
  return -EMFILE;  // Too many open files
}

/// VFS open implementation.
static int vfs_mem_open(const char *path, int flags, int mode)
{
  if (!path || path[0] != '/') {
    return -EINVAL;
  }

  vfs_mem_init();

  // Parse path: separate parent directory and filename
  char *copy = xstrdup(path);
  char *last_slash = strrchr(copy, '/');
  if (!last_slash) {
    xfree(copy);
    return -EINVAL;
  }

  // Split into directory and filename
  *last_slash = '\0';
  const char *dir_path = (last_slash == copy) ? "/" : copy;
  const char *filename = last_slash + 1;

  if (strlen(filename) == 0 || strlen(filename) > VFS_MAX_FILENAME) {
    xfree(copy);
    return -EINVAL;
  }

  // Get or create parent directory
  VFSNode *dir = vfs_mem_find_or_create_dir(dir_path);
  if (!dir) {
    xfree(copy);
    return -ENOENT;
  }

  // Find or create file
  VFSNode *file = NULL;
  for (size_t i = 0; i < dir->child_count; i++) {
    if (strcmp(dir->children[i]->name, filename) == 0) {
      file = dir->children[i];
      break;
    }
  }

  if (file) {
    if (file->is_dir) {
      xfree(copy);
      return -EISDIR;
    }
    // File exists
    if (flags & O_CREAT && flags & O_EXCL) {
      xfree(copy);
      return -EEXIST;
    }
    if (flags & O_TRUNC) {
      // Clear file content
      file->size = 0;
    }
  } else {
    // File doesn't exist
    if (!(flags & O_CREAT)) {
      xfree(copy);
      return -ENOENT;
    }
    // Create new file
    file = vfs_mem_create_node(filename, false);
    file->parent = dir;

    // Add to parent's children
    if (dir->child_count >= dir->child_capacity) {
      dir->child_capacity *= 2;
      dir->children = xrealloc(dir->children, dir->child_capacity * sizeof(VFSNode *));
    }
    dir->children[dir->child_count++] = file;
  }

  xfree(copy);

  // Allocate file descriptor
  int fd = vfs_mem_alloc_fd();
  if (fd < 0) {
    return fd;
  }

  vfs_mem_state.fds[fd].node = file;
  vfs_mem_state.fds[fd].offset = 0;
  vfs_mem_state.fds[fd].flags = flags;

  // Handle O_APPEND
  if (flags & O_APPEND) {
    vfs_mem_state.fds[fd].offset = file->size;
  }

  return fd;
}

/// VFS close implementation.
static int vfs_mem_close(int fd)
{
  if (fd < 3 || fd >= VFS_MAX_FDS) {
    return -EBADF;
  }

  vfs_mem_init();

  if (vfs_mem_state.fds[fd].node == NULL) {
    return -EBADF;
  }

  vfs_mem_state.fds[fd].node = NULL;
  vfs_mem_state.fds[fd].offset = 0;
  vfs_mem_state.fds[fd].flags = 0;

  return 0;
}

/// VFS read implementation.
static ssize_t vfs_mem_read(int fd, void *buf, size_t count)
{
  if (fd < 3 || fd >= VFS_MAX_FDS) {
    return -EBADF;
  }

  vfs_mem_init();

  VFSFile *file_desc = &vfs_mem_state.fds[fd];
  if (file_desc->node == NULL) {
    return -EBADF;
  }

  VFSNode *node = file_desc->node;
  if (node->is_dir) {
    return -EISDIR;
  }

  size_t remaining = node->size - file_desc->offset;
  if (remaining <= 0) {
    return 0;  // EOF
  }

  size_t bytes_to_read = (count > remaining) ? remaining : count;
  memcpy(buf, node->content + file_desc->offset, bytes_to_read);
  file_desc->offset += bytes_to_read;

  return (ssize_t)bytes_to_read;
}

/// VFS write implementation.
static ssize_t vfs_mem_write(int fd, const void *buf, size_t count)
{
  if (fd < 3 || fd >= VFS_MAX_FDS) {
    return -EBADF;
  }

  vfs_mem_init();

  VFSFile *file_desc = &vfs_mem_state.fds[fd];
  if (file_desc->node == NULL) {
    return -EBADF;
  }

  VFSNode *node = file_desc->node;
  if (node->is_dir) {
    return -EISDIR;
  }

  // Ensure buffer is large enough
  size_t new_pos = file_desc->offset + count;
  if (new_pos > node->capacity) {
    // Grow buffer
    size_t new_capacity = node->capacity * 2;
    while (new_capacity < new_pos) {
      new_capacity *= 2;
    }
    node->content = xrealloc(node->content, new_capacity);
    node->capacity = new_capacity;
  }

  // Write data
  memcpy(node->content + file_desc->offset, buf, count);
  file_desc->offset += count;

  // Update file size
  if (file_desc->offset > node->size) {
    node->size = file_desc->offset;
  }

  return (ssize_t)count;
}

/// VFS stat implementation.
static int vfs_mem_stat(const char *path, struct stat *st)
{
  if (!path || path[0] != '/') {
    return -EINVAL;
  }

  vfs_mem_init();

  VFSNode *node = vfs_mem_find_node(path);
  if (!node) {
    return -ENOENT;
  }

  // Minimal stat implementation
  memset(st, 0, sizeof(struct stat));
  st->st_ino = (ino_t)(uintptr_t)node;
  st->st_size = node->is_dir ? 0 : (off_t)node->size;
  st->st_mode = node->is_dir ? (S_IFDIR | 0755) : (S_IFREG | 0644);
  st->st_nlink = 1;
  st->st_uid = 0;
  st->st_gid = 0;
  st->st_atime = 0;
  st->st_mtime = 0;
  st->st_ctime = 0;

  return 0;
}

/// VFS readdir implementation.
static int vfs_mem_readdir(const char *path, struct dirent **entries, size_t *count)
{
  if (!path || path[0] != '/') {
    return -EINVAL;
  }

  vfs_mem_init();

  VFSNode *node = vfs_mem_find_node(path);
  if (!node) {
    return -ENOENT;
  }

  if (!node->is_dir) {
    return -ENOTDIR;
  }

  // Allocate array of dirent pointers
  struct dirent **ents = xcalloc(node->child_count + 2, sizeof(struct dirent *));

  size_t idx = 0;

  // Add "." entry
  struct dirent *dot = xcalloc(1, sizeof(struct dirent));
  dot->d_ino = (ino_t)(uintptr_t)node;
  dot->d_type = DT_DIR;
  strncpy(dot->d_name, ".", 255);
  ents[idx++] = dot;

  // Add ".." entry
  struct dirent *dotdot = xcalloc(1, sizeof(struct dirent));
  dotdot->d_ino = (ino_t)(uintptr_t)(node->parent ? node->parent : node);
  dotdot->d_type = DT_DIR;
  strncpy(dotdot->d_name, "..", 255);
  ents[idx++] = dotdot;

  // Add child entries
  for (size_t i = 0; i < node->child_count; i++) {
    VFSNode *child = node->children[i];
    struct dirent *ent = xcalloc(1, sizeof(struct dirent));
    ent->d_ino = (ino_t)(uintptr_t)child;
    ent->d_type = child->is_dir ? DT_DIR : DT_REG;
    strncpy(ent->d_name, child->name, 255);
    ents[idx++] = ent;
  }

  *entries = ents;
  *count = idx;

  return 0;
}

/// Helper: create an empty file at the given path if it doesn't already exist.
static void vfs_mem_create_empty_file(const char *path)
{
  VFSNode *existing = vfs_mem_find_node(path);
  if (existing) {
    return;  // Already exists
  }

  // Parse path into directory and filename
  char *copy = xstrdup(path);
  char *last_slash = strrchr(copy, '/');
  if (!last_slash) {
    xfree(copy);
    return;
  }

  *last_slash = '\0';
  const char *dir_path = (last_slash == copy) ? "/" : copy;
  const char *filename = last_slash + 1;

  // Get or create parent directory
  VFSNode *dir = vfs_mem_find_or_create_dir(dir_path);
  if (!dir || !dir->is_dir) {
    xfree(copy);
    return;
  }

  // Create empty file node
  VFSNode *file = vfs_mem_create_node(filename, false);
  file->parent = dir;
  file->size = 0;  // Empty file

  // Add to parent's children
  if (dir->child_count >= dir->child_capacity) {
    dir->child_capacity *= 2;
    dir->children = xrealloc(dir->children, dir->child_capacity * sizeof(VFSNode *));
  }
  dir->children[dir->child_count++] = file;

  xfree(copy);
}

/// Create a file with specific content
/// @param path File path
/// @param contents File contents
/// @param size Content size
static void vfs_mem_create_file_with_content(const char *path, const char *contents, size_t size)
{
  VFSNode *existing = vfs_mem_find_node(path);
  if (existing) {
    return;  // Already exists
  }

  // Parse path into directory and filename
  char *copy = xstrdup(path);
  char *last_slash = strrchr(copy, '/');
  if (!last_slash) {
    xfree(copy);
    return;
  }

  *last_slash = '\0';
  const char *dir_path = (last_slash == copy) ? "/" : copy;
  const char *filename = last_slash + 1;

  // Get or create parent directory
  VFSNode *dir = vfs_mem_find_or_create_dir(dir_path);
  if (!dir || !dir->is_dir) {
    xfree(copy);
    return;
  }

  // Create file node
  VFSNode *file = vfs_mem_create_node(filename, false);
  file->parent = dir;

  // Allocate and copy content
  if (size > 0 && contents) {
    file->content = xmalloc(size);
    memcpy(file->content, contents, size);
    file->size = size;
    file->capacity = size;
  }

  // Add to parent's children
  if (dir->child_count >= dir->child_capacity) {
    dir->child_capacity *= 2;
    dir->children = xrealloc(dir->children, dir->child_capacity * sizeof(VFSNode *));
  }
  dir->children[dir->child_count++] = file;

  xfree(copy);
}

/// Populate VFS with minimal runtime files needed for Neovim to boot.
/// Creates stub files so Neovim can find syntax/filetype/plugin infrastructure.
static void vfs_mem_populate_minimal_runtime(void)
{
  if (!vfs_mem_state.root) {
    return;  // Not initialized yet
  }

  // Create /runtime directory
  VFSNode *runtime_dir = vfs_mem_find_or_create_dir("/runtime");
  if (!runtime_dir || !runtime_dir->is_dir) {
    return;
  }

  // Create /runtime/syntax directory
  VFSNode *syntax_dir = vfs_mem_find_or_create_dir("/runtime/syntax");
  if (!syntax_dir || !syntax_dir->is_dir) {
    return;
  }

  // Create minimal runtime files
  vfs_mem_create_empty_file("/runtime/syntax/syntax.vim");
  vfs_mem_create_empty_file("/runtime/filetype.lua");
  vfs_mem_create_empty_file("/runtime/ftplugin.vim");
  vfs_mem_create_empty_file("/runtime/indent.vim");
  vfs_mem_create_empty_file("/runtime/plugin.vim");
}

/// Phase 9.4: Populate plugin mount directories
static void vfs_mem_populate_plugins(void)
{
  if (!vfs_mem_state.root) {
    return;  // Not initialized yet
  }

  // Create /plugins-readonly directory
  vfs_mem_find_or_create_dir("/plugins-readonly");
  
  // Create /plugins-local directory
  vfs_mem_find_or_create_dir("/plugins-local");
  
  // Populate /plugins-readonly with system example plugin
  VFSNode *ro_plugin_dir = vfs_mem_find_or_create_dir("/plugins-readonly/example");
  if (ro_plugin_dir) {
    // Create example plugin file that prints when loaded
    vfs_mem_create_file_with_content(
      "/plugins-readonly/example/init.lua",
      "print('Phase 9.4: System plugin loaded')\n",
      41
    );
  }
  
  // Create /plugins-local/override directory for test
  VFSNode *local_plugin_dir = vfs_mem_find_or_create_dir("/plugins-local/override");
  if (local_plugin_dir) {
    // Create override plugin that shadows the system plugin
    vfs_mem_create_file_with_content(
      "/plugins-local/override/init.lua",
      "print('Phase 9.4: Local plugin loaded (overrides system)')\n",
      57
    );
  }
}

/// VFS backend struct.
static const VFSBackend vfs_mem_backend = {
  .open = vfs_mem_open,
  .close = vfs_mem_close,
  .read = vfs_mem_read,
  .write = vfs_mem_write,
  .stat = vfs_mem_stat,
  .readdir = vfs_mem_readdir,
};

/// Currently active VFS backend.
static const VFSBackend *active_vfs_backend = &vfs_mem_backend;

void vfs_backend_init(const VFSBackend *backend)
{
  if (backend) {
    active_vfs_backend = backend;
  } else {
    active_vfs_backend = &vfs_mem_backend;
  }
  vfs_mem_init();
  vfs_mem_populate_minimal_runtime();
  vfs_mem_populate_plugins();  // Phase 9.4: Populate plugin mounts
  
  // Initialize mount table after backend is ready
  vfs_mount_table_init();
}

const VFSBackend *vfs_backend_get(void)
{
  return active_vfs_backend;
}

const VFSBackend *vfs_backend_mem(void)
{
  return &vfs_mem_backend;
}

/// ============================================================================
/// Phase 9.3: Write Context Table
/// ============================================================================

/// Global write context table, indexed by fd.
/// Sparse array: NULL if fd not tracked.
static VFSWriteContext **vfs_write_ctx_table = NULL;
static size_t vfs_write_ctx_table_cap = 0;

/// Test hook: Force commit failure for atomicity testing.
bool vfs_test_fail_commit_enabled = false;

/// Register write context for an fd.
/// @param fd File descriptor
/// @param ctx Write context to register
static void vfs_write_ctx_register(int fd, VFSWriteContext *ctx)
{
  if (fd < 0 || !ctx) {
    return;
  }

  // Grow table if needed
  if ((size_t)fd >= vfs_write_ctx_table_cap) {
    size_t new_cap = vfs_write_ctx_table_cap ? vfs_write_ctx_table_cap * 2 : 256;
    while ((size_t)fd >= new_cap) {
      new_cap *= 2;
    }
    vfs_write_ctx_table = xrealloc(vfs_write_ctx_table, new_cap * sizeof(VFSWriteContext *));
    // Zero new slots
    for (size_t i = vfs_write_ctx_table_cap; i < new_cap; i++) {
      vfs_write_ctx_table[i] = NULL;
    }
    vfs_write_ctx_table_cap = new_cap;
  }

  vfs_write_ctx_table[fd] = ctx;
}

/// Lookup write context for an fd.
/// @param fd File descriptor
/// @return Write context, or NULL if not registered
static VFSWriteContext *vfs_write_ctx_lookup(int fd)
{
  if (fd < 0 || (size_t)fd >= vfs_write_ctx_table_cap) {
    return NULL;
  }
  return vfs_write_ctx_table[fd];
}

/// Unregister write context for an fd.
/// @param fd File descriptor
static void vfs_write_ctx_unregister(int fd)
{
  if (fd < 0 || (size_t)fd >= vfs_write_ctx_table_cap) {
    return;
  }
  vfs_write_ctx_table[fd] = NULL;
}

/// ============================================================================
/// Mount-aware VFS wrappers (public API)
/// ============================================================================
/// These functions resolve paths to mounts, check permissions, and delegate
/// to the actual backend implementation.

int vfs_open(const char *path, int flags, int mode)
{
  if (!path) {
    return -EINVAL;
  }

  // Resolve path to mount point
  VFSMount *mount = NULL;
  const char *subpath = NULL;
  int ret = vfs_mount_resolve(path, &mount, &subpath);
  if (ret < 0) {
    return ret;
  }

  // Check write permission if applicable
  if ((flags & (O_WRONLY | O_RDWR | O_CREAT)) != 0) {
    if (!vfs_mount_check_perm(mount, VFS_PERM_WRITE)) {
      return -EACCES;  // Permission denied: fail BEFORE backend open
    }
  } else {
    if (!vfs_mount_check_perm(mount, VFS_PERM_READ)) {
      return -EACCES;
    }
  }

  // Delegate to backend (permission check passed)
  int fd = mount->backend->open(subpath, flags, mode);
  if (fd < 0) {
    return fd;  // Backend open failed
  }

  // Phase 9.3 invariant: Writable opens create write context
  if ((flags & (O_WRONLY | O_RDWR)) != 0) {
    VFSWriteContext *ctx = vfs_write_context_create(
      fd, path, flags, mount, mount->write_policy
    );
    if (!ctx) {
      // Context creation failed (e.g., allocation); close fd and return error
      mount->backend->close(fd);
      return -ENOMEM;
    }
    // Register context in global table
    vfs_write_ctx_register(fd, ctx);
  }

  // Phase 10.3: Log VFS operation (after permission checks, after backend succeeds)
  if (vfs_replay_is_enabled()) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_OPEN,
      path,
      fd,
      0, 0,           // offset, size N/A for open
      flags,
      mode,
      fd,             // ret: the fd itself (positive on success)
      0,              // err: no error
      NULL, 0         // no data
    );
  }

  return fd;
}

int vfs_close(int fd)
{
  // Phase 9.3 invariant: Atomic commit boundary
  VFSWriteContext *ctx = vfs_write_ctx_lookup(fd);
  
  if (ctx) {
    // Writable fd: commit buffer to backend atomically
    VFSWriteCommitResult commit_result = vfs_write_commit(ctx);
    
    // Test hook: VFS_TEST_FAIL_COMMIT forces failure for testing atomicity
    if (vfs_test_fail_commit_enabled && commit_result == VFS_WRITE_COMMIT_OK) {
      commit_result = VFS_WRITE_COMMIT_EIO;
    }
    
    // Unregister and destroy context (always, success or failure)
    vfs_write_ctx_unregister(fd);
    vfs_write_context_destroy(ctx);
    
    if (commit_result != VFS_WRITE_COMMIT_OK) {
      // Commit failed: close backend fd and return error
      // Buffer is already discarded; no retry possible
      const VFSBackend *backend = vfs_backend_get();
      backend->close(fd);  // Best-effort close
      return -EIO;
    }
    // Commit succeeded: continue to backend close
  }

  // Phase 9.3 invariant: Backend close always happens (success or failure path)
  const VFSBackend *backend = vfs_backend_get();
  int close_ret = backend->close(fd);

  // Phase 10.3: Log VFS operation
  if (vfs_replay_is_enabled()) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_CLOSE,
      NULL,           // path N/A for close
      fd,
      0, 0,           // offset, size N/A
      0, 0,           // flags, mode N/A
      close_ret,
      close_ret < 0 ? -close_ret : 0,
      NULL, 0
    );
  }

  return close_ret;
}

ssize_t vfs_read(int fd, void *buf, size_t count)
{
  if (!buf || count == 0) {
    return -EINVAL;
  }
  const VFSBackend *backend = vfs_backend_get();
  ssize_t read_ret = backend->read(fd, buf, count);

  // Phase 10.3: Log VFS operation
  if (vfs_replay_is_enabled() && read_ret >= 0) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_READ,
      NULL,           // path N/A for read
      fd,
      0,              // offset N/A (tracked by fd)
      read_ret,       // size: bytes read
      0, 0,           // flags, mode N/A
      (int)read_ret,
      0,              // no error
      buf, read_ret   // data: the read buffer
    );
  }

  return read_ret;
}

ssize_t vfs_write(int fd, const void *buf, size_t count)
{
  if (!buf || count == 0) {
    return -EINVAL;
  }

  // Phase 9.3 invariant: Check if fd has a write context
  VFSWriteContext *ctx = vfs_write_ctx_lookup(fd);
  ssize_t write_ret;
  if (ctx) {
    // Writable fd: append to buffer, never touch backend
    write_ret = vfs_write_buffer(ctx, buf, count);
  } else {
    // Read-only fd or not tracked: delegate directly to backend
    // (fallback for backward compatibility)
    const VFSBackend *backend = vfs_backend_get();
    write_ret = backend->write(fd, buf, count);
  }

  // Phase 10.3: Log VFS operation
  if (vfs_replay_is_enabled() && write_ret >= 0) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_WRITE,
      NULL,           // path N/A for write
      fd,
      0,              // offset N/A
      write_ret,      // size: bytes written
      0, 0,           // flags, mode N/A
      (int)write_ret,
      0,              // no error
      buf, write_ret  // data: the written buffer
    );
  }

  return write_ret;
}

int vfs_stat(const char *path, struct stat *st)
{
  if (!path || !st) {
    return -EINVAL;
  }

  // Resolve path to mount point
  VFSMount *mount = NULL;
  const char *subpath = NULL;
  int ret = vfs_mount_resolve(path, &mount, &subpath);
  if (ret < 0) {
    return ret;
  }

  // Check read permission
  if (!vfs_mount_check_perm(mount, VFS_PERM_READ)) {
    return -EACCES;
  }

  // Delegate to backend
  int stat_ret = mount->backend->stat(subpath, st);

  // Phase 10.3: Log VFS operation
  if (vfs_replay_is_enabled()) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_STAT,
      path,
      -1,             // fd N/A for stat
      0, 0,           // offset, size N/A
      0, 0,           // flags, mode N/A
      stat_ret,
      stat_ret < 0 ? -stat_ret : 0,
      stat_ret == 0 ? (const void *)st : NULL,
      stat_ret == 0 ? sizeof(struct stat) : 0
    );
  }

  return stat_ret;
}

int vfs_readdir(const char *path, struct dirent **entries, size_t *count)
{
  if (!path || !entries || !count) {
    return -EINVAL;
  }

  // Resolve path to mount point
  VFSMount *mount = NULL;
  const char *subpath = NULL;
  int ret = vfs_mount_resolve(path, &mount, &subpath);
  if (ret < 0) {
    return ret;
  }

  // Check read permission
  if (!vfs_mount_check_perm(mount, VFS_PERM_READ)) {
    return -EACCES;
  }

  // Delegate to backend
  int readdir_ret = mount->backend->readdir(subpath, entries, count);

  // Phase 10.3: Log VFS operation
  if (vfs_replay_is_enabled()) {
    vfs_replay_log_operation(
      VFS_REPLAY_OP_READDIR,
      path,
      -1,             // fd N/A for readdir
      0, 0,           // offset, size N/A (count is in output)
      0, 0,           // flags, mode N/A
      readdir_ret,
      readdir_ret < 0 ? -readdir_ret : 0,
      NULL, 0         // entries data too complex for now
    );
  }

  return readdir_ret;
}
