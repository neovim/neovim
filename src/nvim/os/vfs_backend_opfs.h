/// OPFS VFS Backend Header
///
/// Exports the OPFS (Origin Private File System) backend for mounting
/// into the VFS mount table.

#pragma once

struct VFSBackend;

/// Get the OPFS backend.
///
/// Suitable for mounting at any path. Always returns a valid backend that
/// conforms to the VFSBackend interface.
///
/// Behavior depends on NVIM_WASM compile flag:
/// - With NVIM_WASM: delegates to JS glue code, expects OPFS async operations wrapped
/// - Without NVIM_WASM: returns -ENOSYS for all operations (inert stub)
///
/// This design allows the mount table to register OPFS at init time, with
/// activation conditional on the build. Perfect for keeping Phase 10.1 as
/// a pure architectural extension to core.
const struct VFSBackend *vfs_backend_opfs(void);
