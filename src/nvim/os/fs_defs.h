#pragma once

#include <uv.h>

/// Currently supports Windows and is extensible.
/// @see https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
typedef enum {
  kPathUnknown = 0,
  kPathDOS,         ///< C:/foo/bar
  kPathUNC,         ///< //server/share/foo/bar
  kPathDevice,      ///< //?/C:/foo/bar or //?/Volume{xxx}/foo/bar
  kPathDeviceUNC,   ///< //?/UNC/server/share/foo/bar
} PathType;

/// Struct which encapsulates file stat and path information.
typedef struct {
  uv_stat_t stat;  ///< @private

  /// Offset of the root component after any path type prefix. Currently
  /// only used for Widnows device paths. e.g. "//?/" and "//?/UNC/"
  size_t root_off;
  PathType type;
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

// Values returned by os_nodetype()
#define NODE_NORMAL     0  // file or directory, check with os_isdir()
#define NODE_WRITABLE   1  // something we can write to (character
                           // device, fifo, socket, ..)
#define NODE_OTHER      2  // non-writable thing (e.g., block device)
