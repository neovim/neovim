/// RPC VFS Backend Header
///
/// Exports the RPC (Remote Procedure Call) backend for mounting
/// into the VFS mount table.
///
/// Provides access to a remote filesystem via simple request/response protocol.

#pragma once

struct VFSBackend;

/// Get the RPC backend.
///
/// Returns a fully compliant VFSBackend that communicates with a remote
/// RPC server over TCP or Unix socket.
///
/// All operations are synchronous and blocking:
/// - Timeout: 5 seconds per operation (global)
/// - Failure: returned as POSIX errno
/// - No threads or callbacks
///
/// Suitable for:
/// - Remote workspace access (Phase 10.2+)
/// - Testing mount semantics with latency
/// - Proving generalization of VFSBackend contract
///
/// This backend works identically whether the RPC server is:
/// - A remote Neovim instance (Phase 11+)
/// - A deterministic mock server (Phase 10.2 testing)
/// - A browser-based server (WASM future)
const struct VFSBackend *vfs_backend_rpc(void);

/// Initialize RPC backend (for local/mock testing).
/// Called once before mounting RPC backend.
void vfs_backend_rpc_init(void);

/// Cleanup RPC backend.
/// Called once at shutdown.
void vfs_backend_rpc_cleanup(void);
