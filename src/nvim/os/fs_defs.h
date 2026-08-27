#pragma once

#include <uv.h>

/// Currently supports Windows and is extensible.
/// @see https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
typedef enum {
  kPathUnknown = 0,
  kPathGeneric,     ///< foo/bar or /foo/bar
  kPathDrive,       ///< C:/foo/bar
  kPathUNC,         ///< //server/share/foo/bar
  kPathDevice,      ///< //?/C:/foo/bar or //?/Volume{xxx}/foo/bar
  kPathDeviceUNC,   ///< //?/UNC/server/share/foo/bar
} PathType;

/// Struct which encapsulates file stat and path information.
///
/// A path is divided into three parts: prefix, logical root, rest.
/// Examples:
///   foo/bar  generic relative path
///   ^------- rest
///
///   /foo/bar  generic absolute path
///   ^^------- rest
///   +-------- root & prefix
///
///   C:foo/bar  Windows drive path, relative path
///   ^ ^------- rest
///   +--------- root & prefix
///
///   C:/foo/bar  Windows drive path, absolute path
///   ^  ^------- rest
///   +---------- root & prefix
///
///   //?/C:/foo/bar  Windows device path
///   ^   ^  ^------- rest
///       +---------- root
///   +-------------- prefix
///
///   //server/share/foo/bar  Windows UNC path
///   ^              ^------- rest
///   +---------------------- root & prefix
///
///   //?/UNC/server/share/foo/bar  Windows device UNC path
///   ^       ^            ^------- rest
///           +-------------------- root
///   +---------------------------- prefix
typedef struct {
  uv_stat_t stat;  ///< @private

  size_t prefix_off;  ///< Offset where the type-determining prefix starts.
  size_t root_off;  ///< Offset where the logical root starts.
  size_t rest_off;  ///< Offset where the remaining path starts.
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
