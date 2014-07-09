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

#define FILE_ID_EMPTY (FileID){.inode = 0, .device_id = 0}

#endif  // NVIM_OS_FS_DEFS_H
