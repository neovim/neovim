# Neovim Agent Substrate Architecture

## 1. Purpose and Non-Goals

### Purpose

This document describes the architectural foundation that allows Neovim to accept, execute, and verify untrusted code (including agent-generated changes) with a mathematically-enforceable guarantee:

> **Any filesystem mutation that persists has passed deterministic verification.**

The design establishes a single trust boundary:

* **Execution is untrusted**
* **Verification is trusted**
* **The substrate exists solely to make verification enforceable**

This architecture enables safe agent integration without requiring the agent, model, or human judgment to be correct—only their *effects* need to be reproducible and verifiable. There is no concept of partial success: execution either verifies and persists entirely, or it is fully discarded.

### Non-Goals

This work does **not** attempt to:

- **Make agents smarter or more reliable.** It assumes agents are fallible, potentially adversarial, or misaligned. Verification does not judge correctness; it judges determinism.

- **Provide real-time safety.** Agents execute in a sandboxed snapshot. Verification happens after execution completes. This is inherently post-hoc, not preventive.

- **Secure model outputs or prompt design.** The substrate is indifferent to how the agent was instructed or what intentions it claimed. Only the filesystem effects matter.

- **Define UX for agent interaction.** How users trigger agents, inspect results, or approve changes is orthogonal to the verification substrate. Those are design choices, not architecture.

- **Replace human audit and review.** The substrate proves determinism. It does not prove correctness, safety for the user's actual intent, or alignment with project goals. Humans still make the final call.

- **Handle concurrency or race conditions in agent code.** Agents run in isolated snapshots. If user edits happen in parallel, they are serialized by snapshot boundaries, not merged.

- **Mandate any particular agent runtime, protocol, or language.** The substrate is backend-agnostic. Agents can be Lua, Wasm, RPC, or anything that translates to VFS operations.

### Why This Exists (Independent of AI Hype)

The problem predates agents:

- **Plugins execute arbitrary code.** Neovim has always allowed this. But Neovim had no mechanism to verify that a plugin's changes were reproducible or to roll back on divergence.

- **Distributed editing (RPC) has implicit ordering.** Commands might arrive out of order, be partially applied, or conflict. There was no way to enforce atomic application or prove consistency.

- **Undo and collaborative editing require determinism.** Modern editors (VSCode with Live Share, Figma, etc.) verify that effects are reproducible across machines by replaying operations. Neovim had no such mechanism.

Agents are a new *consumer* of this substrate, but the substrate solves old problems:

- Untrusted code execution (plugins)
- Distributed ordering (RPC, LSP)
- Auditability of changes (undo, history, collaboration)

The architecture is justified *without* agents. Agents simply make the problem urgent enough to implement.

---

## 2. The Substrate Layers

The substrate is a mechanical stack of four layers, each enforcing a specific invariant and refusing a specific class of trust.

---

### 2.1 VFS Abstraction — *The Mutation Boundary*

**Role**

The VFS (Virtual Filesystem) layer is the sole observable surface through which any persistent state change occurs. All backends—POSIX filesystems, in-memory stores, network RPC, browser OPFS—funnel through a single interface. No execution path can mutate observable state except through VFS operations.

**Invariant Enforced**

All persistent effects are reducible to VFS operations (open, write, close, delete, rename, mkdir, etc.). This list is illustrative, not exhaustive; any operation that mutates persistent state must transit the VFS boundary. State that does not flow through VFS is ephemeral and not subject to verification.

**What This Layer Refuses to Trust**

* Callers' claims about what they are doing
* Backend implementations' reliability or correctness
* Execution order of concurrent calls (ordering is explicit in the trace, not implicit)
* Memory-only side effects or state

**What This Layer Assumes**

* Byte-level file contents are the meaningful unit of state
* File paths and metadata are sufficient to describe structure
* Operations on the same path can be ordered strictly
* All backends implement the same VFS semantics

---

### 2.2 Atomic Write Semantics — *The Commitment Boundary*

**Role**

Writes are buffered in memory and committed only on close(). This prevents partial state leakage: either all changes to a file persist, or none persist. There is no intermediate state visible between write() and close().

**Invariant Enforced**

* Writes to a file descriptor do not immediately affect the filesystem
* State is committed atomically at close()
* Uncommitted writes are lost if close() fails or is interrupted
* No observer (including replay) can see partial writes

**What This Layer Refuses to Trust**

* Backend filesystem atomicity
* Network ordering during remote writes
* Process crash recovery
* Partial write detection by callers

**What This Layer Assumes**

* close() is a valid and final commit point
* Buffering in memory is sufficient for atomic semantics
* File handles have a defined lifecycle (open → write* → close)
* Callers are stateless between close() and next open()

---

### 2.3 Deterministic Replay — *The Proof Mechanism*

**Role**

All VFS operations are recorded in a binary trace during execution. The trace is sufficient to reproduce the final filesystem state from any identical initial state. Replay verifies that given identical input, identical execution produces identical output.

**Invariant Enforced**

* Same initial state + same trace ⇒ same final state
* Divergence during replay is a proof of non-determinism
* The trace is the canonical record of what happened
* Replay results must match byte-for-byte on file contents and path structure (ignoring timestamps and directory ordering), or fully failed (no partial match)

**What This Layer Refuses to Trust**

* Runtime behavior (timing, scheduler, thread order)
* Non-VFS side effects
* Implementation details of backend operations
* Correctness of the operations themselves

**What This Layer Assumes**

* VFS operations are sufficient to describe state transitions
* Initial filesystem state is semantically meaningful (snapshot)
* Byte equality of final state is sufficient to declare success
* Determinism is a property of the execution (not a property of output correctness)

---

### 2.4 Agent Verification Runtime — *The Acceptance Gate*

**Role**

Before any execution result persists, this layer enforces a three-step ceremony: create a snapshot, execute in isolation, replay against the snapshot, compare results byte-for-byte. Only exact matches persist. Any divergence causes full discard.

**Invariant Enforced**

* No execution result persists without verification
* Verification consists of snapshot → execute → replay → compare
* Comparison is binary: accept all, or reject all (no partial persistence, no curation)
* Failed verification leaves the filesystem unchanged

**What This Layer Refuses to Trust**

* The executor's output
* The executor's claims about correctness
* Partial success or best-effort results
* Heuristics, voting, or recovery strategies

**What This Layer Assumes**

* Snapshot state is frozen and reproducible
* Replay is deterministic (Layer 2.3)
* Byte equality of file contents and path structure (ignoring timestamps and directory ordering) is an acceptable definition of correctness
* Binary accept/reject semantics are enforceable

---

## Interdependencies

* Layer 2.4 *depends on* Layer 2.3 (replay must work)
* Layer 2.3 *depends on* Layer 2.2 (atomicity enables reproducibility)
* Layer 2.2 *depends on* Layer 2.1 (VFS is the only mutation surface)
* Layer 2.1 *depends on* nothing (it is the substrate)

---

## What Section 2 Establishes

Each layer is a single responsibility:

* **VFS Abstraction**: Define what can be observed
* **Atomic Writes**: Define how changes commit
* **Deterministic Replay**: Define how to verify
* **Verification Runtime**: Define when to accept

Collectively, they form the basis for the invariants stated in Section 3.

---

## 3. Threat Model and Failure Modes

This section describes what can fail, what cannot fail, and what the system does in each case.

---

### 3.1 The Invariants (Formally Stated)

These are the laws enforced by the four layers working together:

**Invariant 1: No Replay ⇒ No Persistence**

Any execution result that cannot be replayed is discarded. No partial success, no inspection window, no "best guess" recovery. The filesystem is unmodified.

**Invariant 2: Replay Mismatch ⇒ Full Rejection**

If replay diverges from initial execution at any point—byte mismatch, operation failure, timeout—the entire result is discarded. No recovery, no repair, no "close enough." Binary accept/reject only.

**Invariant 3: Only VFS-Observable Effects Persist**

State changes that do not flow through the VFS layer have no bearing on persistence. Memory, CPU cache, process state, metadata the caller did not trace—all are ephemeral and play no role in verification.

**Invariant 4: Atomicity at File Granularity**

A file either commits entirely or not at all. There is no intermediate state observable by any reader. Partial writes within a file cannot leak.

**Invariant 5: Determinism Is the Only Trust Boundary**

The system makes no judgment about whether the result is correct, safe, desirable, or aligned with intent. Only whether it is reproducible. That judgment lives at a higher layer (UX, audit, human decision).

---

### 3.2 What Can Fail (and What Happens)

#### 3.2.1 Execution Diverges During Replay

**What happens:**

Replay reaches a point where the execution trace says "open /tmp/file.txt" but the operation returns ENOENT instead of a file descriptor.

**System response:**

* Stop replay immediately
* Discard the entire execution result
* Leave filesystem unchanged
* Return error to caller: "replay divergence at operation N"

**Why this is correct:**

Divergence proves non-determinism. The system cannot distinguish between "the agent is using randomness" and "the agent encountered a timing-dependent bug." Rather than guess, it rejects. This is safe.

---

#### 3.2.2 Snapshot Corruption or Unreadable

**What happens:**

Snapshot file is truncated, missing, or cannot be read back.

**System response:**

* Abort verification
* Do not execute the agent (execution would have no baseline)
* Return error: "snapshot unreadable"

**Why this is correct:**

A snapshot is the only ground truth. If it is corrupted, verification is impossible. Proceeding would be worse than useless—it would be a false claim of verification.

---

#### 3.2.3 Backend Operation Fails

**What happens:**

During replay, a write() syscall returns EIO (I/O error) on the actual filesystem, but the original execution recorded success.

**System response:**

* Stop replay at that point
* Discard result
* Return error: "replay divergence at operation N"

**Why this is correct:**

The divergence is proof of non-determinism: the system state changed between execution and replay. Cause is irrelevant (network glitch, hardware failure, third-party modification). Effect is the same: cannot verify.

---

#### 3.2.4 Replay Completes but Bytes Don't Match

**What happens:**

Replay finishes without errors. All operations succeeded. But a file that originally contained "foo" now contains "bar".

**System response:**

* Discard entire execution
* Leave filesystem unchanged
* Return error: "verification failed: byte mismatch"

**Why this is correct:**

The bytes don't match. The system cannot and will not guess why: was it a race condition? Nondeterministic random number generation? A backend implementation difference? Doesn't matter. Verification failed. Rejection is the only safe response.

---

#### 3.2.5 Agent Execution Hangs (Infinite Loop)

**What happens:**

The agent enters an infinite loop. Replay starts and gets stuck at the same point.

**System response:**

* Replay timeout fires
* Stop execution
* Discard result
* Return error: "replay timeout"

**Why this is correct:**

Replay is meant to be fast (same operations, same environment). If it doesn't complete, something is wrong. We don't know if it will ever complete, so we stop. Liveness is not guaranteed.

---

#### 3.2.6 Agent Modifies State Outside the VFS Layer

**What happens:**

Agent modifies a Unix socket, sends a network packet, or calls setenv() to change process state.

**System response:**

* Those effects are not recorded in the VFS trace.
* They are not replayed.
* They do not affect persistence.
* They are lost.

**Why this is correct:**

If an agent effect doesn't flow through the VFS layer, it is not part of the verified state. It may be useful for side effects (logging, notifications), but it carries no persistence guarantee. The agent must communicate intended changes as filesystem mutations to be verified.

---

### 3.3 What Cannot Fail

#### 3.3.1 Silent Corruption During Persistence

**Why it cannot happen:**

Replay must pass byte-for-byte verification before persistence. If corruption occurs during commit, replay would have caught it (because init + replay must reproduce exactly). If corruption occurs after commit, it is a filesystem-level problem outside the scope of this architecture.

#### 3.3.2 Partial Persistence Leaking to Observers

**Why it cannot happen:**

Atomic write semantics (Layer 2.2) guarantee that writes are buffered until close(). Only at close() does state commit. Snapshot isolation prevents replay from observing partial writes.

#### 3.3.3 Accepted State That Didn't Pass Verification

**Why it cannot happen:**

Invariant 1 is enforced in code: if replay fails or is skipped, the result is discarded. There is no code path to persistence that bypasses verification.

---

### 3.4 What Is Not Guaranteed

#### 3.4.1 That the Result Is Correct

Verification proves determinism, not correctness. An agent could faithfully, deterministically produce the wrong result. Humans reviewing the change must judge intent.

#### 3.4.2 That the Result Finished

Replay timeout is a fallback, not a liveness guarantee. An agent that runs slowly may hit the timeout and be rejected, even if it would eventually produce correct output.

#### 3.4.3 That Performance Is Bounded

Replay can be expensive (copying filesystems, repeating operations). For large codebases or many files, verification time could be significant.

#### 3.4.4 That Concurrency Is Safe

If the user is actively editing while an agent is executing, the snapshot semantics mean the two operations don't merge. They serialize at snapshot boundaries. The second writer wins. This may be surprising but is not an error.

#### 3.4.5 That the Agent Will Run

If the snapshot is already stale or the environment changes, execution may fail immediately. This is expected and correct.

---

### 3.5 Summary: What Survives to Persistence

Only execution results that satisfy **all** of the following:

1. ✓ Execution completed (did not crash or hang past timeout)
2. ✓ Replay was attempted and completed
3. ✓ Replay produced identical bytes for all files in the verified set
4. ✓ All VFS operations succeeded both times
5. ✓ No external observer detected divergence

If any of these is violated, the result is discarded. No exceptions, no recovery, no forensics at the persistence layer. (Forensics happen at the layer above: UX, audit, logging—not here.)

---

## What Section 3 Establishes

The threat model is asymmetric:

* **Execution is untrusted and subject to rejection.**
* **Verification is trusted because it is simple: equality of bytes, success of operations, repeatability of effects.**
* **The system is biased toward rejection.**

This bias is intentional. It is easier to trust a mechanism that fails safely (discard) than one that tries to recover (inspect, repair, infer intent).

Human judgment lives at the layer above this substrate. This layer's job is only to prove determinism.

---

## 4. Implications and Non-Implications

This section clarifies what this architecture enables, what it constrains, and what it explicitly does not claim.

---

### 4.1 What This Architecture Changes

#### The Trust Model for Execution

**Before:** "Execute code. Hope the outcome is correct. Undo if wrong."

**After:** "Execute code. Prove the outcome is reproducible. Discard if non-deterministic. Humans judge if it's correct."

The first statement says code is trusted to be correct.
The second statement says only reproducibility is trusted; correctness is a human decision.

#### Auditability as a Substrate Property

Every filesystem change can be traced. The trace is a cryptographic record of *what happened*, not *what should have happened*. This enables:

- Audit trails that cannot be falsified (the trace is the authority)
- Rollback via snapshot restore
- Verification that "what I approved" matches "what persisted"
- Investigation of divergence (why did replay fail?)

This is new. Editors previously had no substrate-level record of why a state change occurred.

#### Verification as Post-Hoc, Mechanical

Verification is not human judgment; it is byte equality. It happens *after* execution, not before. This design choice is intentional:

- Real-time prevention requires predicting what the agent will do (impossible).
- Post-hoc verification only requires checking if it was deterministic (possible).
- The cost of false rejection (discarding a good result) is acceptable. The cost of false acceptance (persisting a bad result as if verified) is not.

---

### 4.2 What This Architecture Does Not Provide

#### Protection Against Model Misalignment

This substrate cannot prevent an agent from producing the wrong result, if it produces it consistently. A deterministic wrong answer will pass verification.

Example: An agent faithfully, reproducibly produces a refactoring that compiles but changes behavior. Verification succeeds. The substrate does not care. Worse, if the agent is trained to be deterministic, and the wrong refactoring is what it was trained to do, the substrate will happily verify every instance.

The defense is at a layer above: policy, review, careful prompting, and audit.

#### Prevention of Intentional Malice

An agent designed to be adversarial can pass substrate verification. If it encodes malice in deterministic code changes, the system sees a reproducible result and accepts it.

The substrate's guarantee is mechanical: "I proved this is what happened." It is not "I proved this is what you wanted."

#### Real-Time Safety

Verification happens after execution completes. If the agent crashes the system or corrupts state during execution, the damage is done. Replay proves what happened, but does not prevent it.

The design mitigates this: execution happens in a snapshot, isolated from live state. But isolation is not prevention. Isolation buys time for human judgment.

#### Correctness Guarantees

Verification proves determinism, not correctness. The substrate is indifferent to whether the code change is correct, efficient, idiomatic, or safe. It only cares whether it can be reproduced.

A mediocre agent producing mediocre code, consistently, will pass verification. Quality gates live at higher layers.

#### Performance Bounds

Replay can be expensive. For agents working on large codebases (thousands of files, gigabytes of state), verification time could be significant. There are no hard performance guarantees.

---

### 4.3 Where This Architecture Lives

#### It Is a Substrate

This architecture is *below* policy, UX, agent selection, and review workflows. It is not sufficient alone. It is a foundation.

Correct usage patterns:

* Substrate verifies reproducibility.
* Policy layer (separate) decides if reproducible results are worth accepting.
* UX layer (separate) decides how to show results to humans.
* Audit layer (separate) decides what to log and for how long.

#### It Does Not Invalidate Existing Code Paths

This architecture is opt-in. Existing plugins, RPC clients, and workflows that do not use verification continue to work unchanged. The substrate enforces verification *only* on code paths that explicitly request it.

#### It Is Composable

Verification works the same whether:

- The agent is Lua, WASM, or RPC
- The backend is POSIX, memfs, or OPFS
- The verification is triggered by command, API, or user action

The substrate does not care. It only cares about VFS operations and determinism.

---

### 4.4 Appropriate Use Cases

This architecture is appropriate for:

- **Agent-assisted coding** where reproducibility is a prerequisite for audit
- **Distributed collaborative editing** where operations must commute
- **Plugin execution** where untrusted code needs to be rolled back on divergence
- **RPC-based editing** where ordering and atomicity matter
- **Offline-first editors** that must reconcile changes later

This architecture is *not* appropriate for:

- **Real-time, interactive editing** where latency is critical (verification adds cost)
- **Streaming data processing** where final state is meaningless
- **Systems that require security (formal proofs, cryptography)** — this is auditability, not security

---

## What This Document Establishes (Summary)

Sections 1–3 define a substrate with one property:

> **Any persistent filesystem mutation has passed deterministic verification or has been discarded.**

Section 4 clarifies:

* This property is not a security guarantee; it is an auditability guarantee.
* It changes the trust model for execution, not the correctness of execution.
* It is a foundation. Policy, review, and human judgment live above it.
* It solves old problems (plugin verification, RPC ordering) using a new mechanism (determinism proof).

The substrate is complete. Everything else is integration, UX, and policy.
