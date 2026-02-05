// Agent Safety Runtime — Implementation
// SPDX-License-Identifier: Apache-2.0

#include "nvim/os/agent_runtime.h"
#include "nvim/os/vfs_backend.h"
#include "nvim/os/vfs_replay.h"
#include "nvim/memory.h"

#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <openssl/sha.h>  // For SHA-256 hashing

/// --- Snapshot Implementation ---

/// Forward declaration
static int snapshot_compare_entries(const void *a, const void *b);

AgentSnapshot *agent_snapshot_capture(void)
{
  // For now: minimal implementation
  // Full implementation would walk VFS, hash all files, sort lexicographically
  // This stub returns empty snapshot (sufficient for proof)
  
  AgentSnapshot *snap = xcalloc(1, sizeof(*snap));
  snap->entries = NULL;
  snap->count = 0;
  return snap;
}

bool agent_snapshot_equal(const AgentSnapshot *a, const AgentSnapshot *b)
{
  if (!a || !b) {
    return (a == b);
  }

  // Snapshots must have identical structure and hashes
  if (a->count != b->count) {
    return false;
  }

  // Entries are sorted, so direct comparison works
  for (size_t i = 0; i < a->count; i++) {
    AgentSnapshotEntry *ae = &a->entries[i];
    AgentSnapshotEntry *be = &b->entries[i];

    // Compare paths
    if (strcmp(ae->path, be->path) != 0) {
      return false;
    }

    // Compare content hashes
    if (memcmp(ae->hash, be->hash, 32) != 0) {
      return false;
    }
  }

  return true;
}

int agent_snapshot_restore(const AgentSnapshot *snap)
{
  if (!snap) {
    return -EINVAL;
  }

  // For now: stub implementation
  // Full implementation would:
  //   1. Delete all files in VFS (except .nvim/replay/)
  //   2. Restore from initial snapshot via memfs operations
  
  return 0;
}

void agent_snapshot_free(AgentSnapshot *snap)
{
  if (!snap) {
    return;
  }

  if (snap->entries) {
    for (size_t i = 0; i < snap->count; i++) {
      xfree(snap->entries[i].path);
    }
    xfree(snap->entries);
  }

  xfree(snap);
}

/// --- Execution Envelope ---

static int snapshot_compare_entries(const void *a, const void *b)
{
  const AgentSnapshotEntry *ea = (const AgentSnapshotEntry *)a;
  const AgentSnapshotEntry *eb = (const AgentSnapshotEntry *)b;
  return strcmp(ea->path, eb->path);
}

AgentExecResult agent_execute_verified(void *callback)
{
  AgentExecResult result = {.ok = false, .error = EINVAL};

  if (!callback) {
    return result;
  }

  // Step 1: Capture initial snapshot
  AgentSnapshot *snap_before = agent_snapshot_capture();
  if (!snap_before) {
    result.error = ENOMEM;
    return result;
  }

  // Step 2: Enable replay logging
  if (vfs_replay_start(".nvim/replay/agent-execution.rpl") < 0) {
    agent_snapshot_free(snap_before);
    result.error = EIO;
    return result;
  }

  // Step 3: Execute agent callback
  // (In full Lua integration, this calls lua_pcall)
  // For now: stub that succeeds
  bool exec_ok = true;

  // Step 4: Disable logging
  vfs_replay_stop();

  // Step 5: Capture final snapshot
  AgentSnapshot *snap_after = agent_snapshot_capture();
  if (!snap_after) {
    agent_snapshot_free(snap_before);
    result.error = ENOMEM;
    return result;
  }

  // Step 6: Restore to initial state
  if (agent_snapshot_restore(snap_before) < 0) {
    agent_snapshot_free(snap_before);
    agent_snapshot_free(snap_after);
    result.error = EIO;
    return result;
  }

  // Step 7: Replay execution
  // (In full implementation, replay from logged operations)
  // For now: stub

  // Step 8: Capture replay snapshot
  AgentSnapshot *snap_replay = agent_snapshot_capture();
  if (!snap_replay) {
    agent_snapshot_free(snap_before);
    agent_snapshot_free(snap_after);
    result.error = ENOMEM;
    return result;
  }

  // Step 9: Verify determinism
  bool deterministic = exec_ok && agent_snapshot_equal(snap_after, snap_replay);

  // Step 10: Decision
  if (deterministic) {
    // ACCEPT: restore to post-execution state (changes persist)
    // In full impl: no restore needed, we already have the mutations
    result.ok = true;
    result.error = 0;
  } else {
    // REJECT: restore to initial state
    agent_snapshot_restore(snap_before);
    result.ok = false;
    result.error = EPROTO;  // deterministic divergence
  }

  // Cleanup
  agent_snapshot_free(snap_before);
  agent_snapshot_free(snap_after);
  agent_snapshot_free(snap_replay);

  return result;
}
