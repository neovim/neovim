#ifndef NVIM_OS_FS_DEFS_H
#define NVIM_OS_FS_DEFS_H

#include <uv.h>

/// Struct which encapsulates stat information.
typedef struct {
  uv_stat_t stat;  ///< @private
} FileInfo;

/// Struct which encapsulates inode/dev_id information.
typedef struct {
  uint64_t inode;      ///< @private The inode of the file
  uint64_t device_id;  ///< @private The id of the device containing the file
} FileID;

#define FILE_ID_EMPTY (FileID) { .inode = 0, .device_id = 0 }

typedef struct {
  uv_fs_t request;  ///< @private The request to uv for the directory.
  uv_dirent_t ent;  ///< @private The entry information.
} Directory;

/// Converts libuv error (negative int) to error description string.
#define os_strerror uv_strerror

/// Converts system error code to libuv error code.
#define os_translate_sys_error uv_translate_sys_error

// Values returned by os_nodetype()
#define NODE_NORMAL     0  // file or directory, check with os_isdir()
#define NODE_WRITABLE   1  // something we can write to (character
                           // device, fifo, socket, ..)
#define NODE_OTHER      2  // non-writable thing (e.g., block device)

#endif  // NVIM_OS_FS_DEFS_H
