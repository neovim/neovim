# Buffer Event Ordering: Problem Statement

## Problem

Neovim emits many buffer-related events—`TextChanged`, `BufWritePre`, `BufWritePost`, LSP notifications, autocmd callbacks, plugin observers—but does not define a total ordering or shared notion of state across them.

As a result, plugins and subsystems cannot reliably determine:

- **Which buffer state does an event refer to?** An LSP diagnostic arrives after user types; does it apply to the current text or the text that was present when the request was sent?
- **Are two events causally related?** Plugin A observes `TextChanged`, Plugin B observes `LspDidChange`. Did they react to the same edit?
- **Does an async response match current state?** A language server sends a code action in response to a diagnostic. Is that action still valid after three more edits?

Events are observable, but their **meaning in time** is undefined. There is no shared ground truth about which version of the buffer each event refers to.

---

## Why This Matters Today

Modern Neovim workflows are composed of many concurrent subsystems:

- **User edits** (keypresses, mouse, recording)
- **LSP requests and responses** (diagnostics, completions, hover, code actions)
- **Async formatters and linters** (sometimes triggered on save, sometimes on idle)
- **Multiple plugins** (each with their own event handlers)
- **Undo/redo** (which may or may not trigger events in consistent order)

Without a shared ordering model, correct behavior becomes accidental. Bugs emerge not from single systems working incorrectly, but from their **interactions being undefined**.

The problem is not that individual events fire—it's that we don't know which events are responses to the *same logical change*.

---

## Concrete Failure Modes

### Failure Mode 1: LSP Diagnostics + Formatter Racing

```
t=0: User types "foo"
     → TextChanged event fires
     → Plugin A (diagnostics) receives event

t=1: LSP server processes the change (async)
     → Diagnostics computed for "foo"
     → Sent to client: error at line 3

t=2: User triggers :w (write)
     → BufWritePre fires
     → Plugin B (auto-format) runs
     → Replaces "foo" with formatted output

t=3: Client receives LSP diagnostics from t=1
     → Applies error highlight at line 3
     → But line 3 is now formatted code, not "foo"
     → Error is now in the wrong place, or nonsensical
```

**Why it happens:**
- No ordering relationship between TextChanged and the LSP response
- Diagnostics have no "valid from revision" marker
- Formatter has no way to say "I've made edits, invalidate stale LSP diagnostics for this version"

**Result:** The error highlight is now causally disconnected from the actual problem.

---

### Failure Mode 2: Multiple Plugins Observing the Same Edit

```
buffer content: "foo"

User edits → "foobar"

Plugin A (on TextChanged):
  observes "foobar"
  computes completions for "foobar"
  stores result in cache keyed by line:col

Plugin B (on TextChanged):
  observes "foobar" (same event batch? different event batch?)
  computes linter warnings for "foobar"
  applies highlights

Plugin C (somewhere else):
  queries Plugin A's cache
  but doesn't know if cache is valid for *this version*
```

**Why it's broken:**
- No shared notion of "edit version" across plugins
- Plugins can't coordinate on "which changes are we reacting to?"
- Each plugin must guess whether state is stale

**Result:** Plugin C applies out-of-date suggestions; subtle inconsistencies accumulate.

---

### Failure Mode 3: Undo and Event Replay

```
User does:
  1. type "foo" → TextChanged fires
  2. type "bar" → TextChanged fires
  3. press u (undo) → what fires?
     - BufModifiedSet?
     - TextChanged (with what content)?
     - Nothing?

Extensions want to react to undo, but:
  - buffer content is now "foo"
  - no event tells them "you're at edit version 1"
  - they can't reconstruct causality
```

**Why it's broken:**
- Undo/redo don't emit ordered events
- Plugins have no way to "replay" their own reactions
- No monotonic version counter

**Result:** Undo leaves plugin state out of sync with buffer state.

---

### Failure Mode 4: Asynchronous Code Actions

```
t=0: Buffer content: 
     function foo() { return 1 }

t=1: LSP analyzes, sends code action:
     "Extract to variable"
     (action computed for t=0 state)

t=2: User edits function while waiting:
     function foo() { return someCallThatFails() }

t=3: User clicks code action
     → Action tries to apply
     → Fails, or applies at wrong location
     → Or makes nonsensical change
```

**Why it's broken:**
- Code action is tied to buffer state at t=0
- No way to know if action is still valid at t=3
- No "apply at version N" semantics

**Result:** Code action corrupts or mutates unintended code.

---

## What Neovim Does Not Guarantee Today

The following are **not guaranteed** by Neovim's event model:

### ❌ Events correspond to a specific buffer state

An event may fire after buffer changes. The event handler receives the current buffer content, not necessarily the content that *caused* the event.

### ❌ Multiple events refer to the same edit

If two plugins each observe `TextChanged`, they may be observing the same edit or different edits. There is no way to tell.

### ❌ Async responses can be tied to a buffer version

When an async callback arrives (e.g., from LSP), there is no authoritative way to determine which buffer state it applies to. The buffer may have changed many times since the request was sent.

### ❌ Events have a total order across subsystems

`TextChanged` may fire for Plugin A before or after LSP processes the change. The order is not defined and may vary.

### ❌ Undo/redo is part of the event ordering

Undo can fire events, but there is no guarantee they are ordered consistently with other buffer edits. Plugins cannot reason about "is this change a forward edit or a revert?"

### ❌ Plugin reactions are idempotent

If a plugin reacts to an edit and then undo happens, re-doing that same edit may cause the plugin to react differently (or not at all), because there is no shared marker saying "this edit was already observed."

---

## The Missing Invariant

Stated clearly:

> **There is no monotonic, externally queryable notion of buffer revision that buffer events and async responses refer to.**

In other words:

- Events are emitted, but carry no revision information
- Async callbacks cannot be linked to a specific edit
- Plugins have no way to ask "which version of the buffer is this?"
- No mechanism exists to order edits causally across user, LSP, plugins, and internal subsystems

This is not a problem of *implementation*. Events fire correctly. The problem is one of **definition**: What does "this event refers to this state" even mean?

---

## How Other Editors Handle This

(For context; not proposed solutions in this PR.)

Some modern editors use:

- **Version numbers on buffer state** (VSCode, Lapce): each edit increments a version; events carry the version
- **Content hashes** (some LSP implementations): responses include a hash of the state they apply to
- **OT/CRDT versions** (collaborative editors): each edit has a unique identity; responses refer to edit IDs, not linear versions

Neovim has none of these. Events are "fire and forget."

---

## Non-Goals (Explicitly Deferred)

This document does **not** propose:

### 🚫 Operational Transformation or CRDT

We are not adopting OT/CRDT semantics. That is a separate architectural choice with implications for undo, history, collaboration. It is deferred.

### 🚫 Undo System Redesign

Undo is currently based on the undo tree. That is not broken. We are not proposing to change it or make undo events part of the ordering.

### 🚫 Merging Semantics

If two plugins make conflicting changes, we do not propose a merge strategy. Conflicts are out of scope.

### 🚫 Real-Time Causality Broadcast

We are not proposing that Neovim broadcast edit causality to plugins in real-time, or enforce any specific event scheduling.

### 🚫 Performance Guarantees

Versioning buffers has a cost. We are not proposing it; we are not promising performance under it.

### 🚫 Collaborative Editing

This problem exists independently of collaboration. We are not proposing multi-user semantics.

---

## What This Document Establishes

1. ✓ Buffer events lack a shared ordering
2. ✓ This causes real bugs in LSP + plugin + formatter workflows
3. ✓ The root cause is missing revision semantics
4. ✓ This is a design problem, not an implementation bug

**What this does NOT establish:**

* How to fix it (solution in follow-up)
* Whether to fix it (decision deferred)
* What impact fixing it would have (analysis deferred)

---

## Next Steps (Not This PR)

After this problem statement is accepted, future work would:

1. **Propose a minimal revision model** (single counter? lamport clock? content hash?)
2. **Identify which subsystems need version awareness** (LSP? plugins? user edits?)
3. **Sketch integration** (do events carry versions? do callbacks?)
4. **Measure impact** (undo consistency, plugin coordination, performance)

Each of those is a separate design and PR.

For now: **Acknowledge the problem exists. Make it impossible to ignore.**

---

## Comparison: Before and After Acknowledging This

| Today | After This Doc |
|-------|----------------|
| "Events are delivered" | "Events are delivered but lack ordering semantics" |
| "Bugs happen (coincidence)" | "Bugs are inevitable given undefined semantics" |
| "Fix it ad-hoc" | "Cannot fix ad-hoc; needs architectural choice" |
| "Trust it works" | "Understand why and where it breaks" |

This shifts from "it mostly works" to "we know exactly where it's broken."
