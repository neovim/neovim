// Agent Safety Runtime — Deterministic Verification
// SPDX-License-Identifier: Apache-2.0
//
// Agents execute speculatively. Replay verifies determinism.
// Only verified mutations persist.

#ifndef NVIM_OS_AGENT_RUNTIME_H
#define NVIM_OS_AGENT_RUNTIME_H

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

/// --- Snapshot API ---

/// VFS snapshot entry (one file = one hash)
typedef struct {
  char *path;           // canonical absolute VFS path
  uint8_t hash[32];     // SHA-256 of file contents
} AgentSnapshotEntry;

/// VFS snapshot (minimal, hash-based)
typedef struct {
  AgentSnapshotEntry *entries;
  size_t count;
} AgentSnapshot;

/// Capture current VFS state as snapshot (tree + content hashes).
/// @return snapshot of current filesystem, or NULL on error
AgentSnapshot *agent_snapshot_capture(void);

/// Compare two snapshots for equality (identical tree + content hashes).
/// @return true if snapshots are identical (same tree, same contents)
bool agent_snapshot_equal(const AgentSnapshot *a, const AgentSnapshot *b);

/// Restore VFS to a previous snapshot (destructive).
/// @return 0 on success, -errno on failure
int agent_snapshot_restore(const AgentSnapshot *snap);

/// Free snapshot resources.
void agent_snapshot_free(AgentSnapshot *snap);

/// --- Execution Envelope API ---

/// Result of agent execution with verified determinism.
typedef struct {
  bool ok;              // true = deterministic, false = rejected
  int error;            // errno on failure (0 = success)
} AgentExecResult;

/// Execute Lua function with mandatory replay verification.
/// Execution steps:
///   1. Snapshot initial VFS state
///   2. Enable replay logging
///   3. Execute agent callback
///   4. Disable logging, snapshot final state
///   5. Restore to initial, replay execution
///   6. Snapshot replay state
///   7. Compare: if identical → persist, else → reject
///
/// @param callback Lua callback to execute
/// @return (ok, result) where ok indicates determinism verification passed
/// Note: if ok=false, VFS is restored and callback return value is discarded
AgentExecResult agent_execute_verified(void *callback);

#endif // NVIM_OS_AGENT_RUNTIME_H
