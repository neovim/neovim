# LSP Operations: Wiring Cancelable Operations to Language Server Semantics

## Problem Statement

LSP in Neovim today suffers from three related but distinct pain points:

### 1. Progress visibility
- LSP servers send progress via `$/progress` notifications
- Neovim has no unified way to query "what is currently happening?"
- Progress callbacks are protocol‑specific and fragmented
- UI has nowhere to put "LSP is working..." status

### 2. Cancellation semantics
- LSP spec defines cancellation via request ID, but cancellation is best‑effort
- If user presses Ctrl-C during `textDocument/definition`, we have no guarantee the request dies
- Different request types require different cancellation logic
- No way to know if a cancellation actually succeeded

### 3. Request lifecycle visibility
- Users cannot introspect running requestss
- No stable handle to a request once it's created
- Debugging multi‑request workflows (hover → signatureHelp → definition) is opaque
- Extensions cannot coordinate on "is LSP still initializing?"

All three stem from the same root: **LSP requests are created but immediately disappear into callbacks**. There is no queryable, persistent handle.

---

## Single Invariant

> **Every LSP request that may outlive an event loop tick owns exactly one `vim.op`.**

Implications:
- Request starts → `op = vim.op.start { title = "textDocument/definition" }`
- Request gets progress → `op:progress(current / total)`
- Request completes → `op:finish()` or `op:fail(err)`
- Request cancelled → `op:cancel()`
- UI queries → `vim.op.list()` returns visible requests

This is not a protocol change. It's a **registry discipline**: one operation handle per request.

---

## Concept Mapping

How LSP concepts map onto the operations primitive:

| LSP Concept | Current (Callback) | With `vim.op` |
|---|---|---|
| **Request Identity** | Opaque message ID | `Operation` handle (userdata) |
| **Progress** | `$/progress` → custom handler | `op:progress(current, total)` → `op:progress()` queries |
| **Status** | Implicit in handler state | `op:state()` ∈ {running, finished, canceled, failed} |
| **Cancellation** | Protocol best‑effort | `op:cancel()` → deterministic state change |
| **Error** | Handler receives error | `op:error()` returns error value/string |
| **Result** | Handler receives result | `op:result()` returns result (if finished) |
| **Observability** | None; handlers are opaque | `vim.op.list()` returns snapshot of all active requests |

---

## Lifecycle Example: `textDocument/hover`

```lua
-- User hovers over symbol
-- LSP client starts request
local op = vim.op.start {
  title = "hover:path/to/file.lua:42:10",
}

-- LSP sends progress (if server supports it)
-- Handler receives $/progress, calls:
op:progress(0.0)  -- started
op:progress(0.5)  -- processing
op:progress(1.0)  -- complete, awaiting response

-- User can query at any time:
print(op:state())     -- "running"
print(op:progress())  -- 1.0
print(vim.op.list())  -- [op, ...]

-- User presses Ctrl-C (requestCancellation)
op:cancel()           -- idempotent state transition

-- LSP server acknowledges, sends result anyway (spec allows this)
-- Client receives response:
if not op:is_canceled() then
  local result = op:result()
  vim.lsp.util.open_floating_preview(...)
else
  -- Request was canceled; discard result
end

-- Op auto-removed from registry after finish/cancel/fail
print(vim.op.list())  -- op no longer present
```

---

## What Changes in LSP Client Code

### Before: pure callback
```lua
client.request("textDocument/hover", params, function(err, result, ctx)
  -- Error means what? Canceled? Network? Timeout?
  -- No way to know if we're in progress
  -- No way to monitor from outside
  if err then return end
  display_hover(result)
end)
```

### After: with operation registry
```lua
local op = vim.op.start { 
  title = "hover:" .. vim.fn.expand("<cword>")
}

client.request("textDocument/hover", params, function(err, result, ctx)
  -- Handler still gets result
  -- But now has a persistent handle
  if err then 
    op:fail(err)
    return
  end
  op:finish()
  display_hover(op:result())
end, function(progress)  -- Optional progress callback
  op:progress(progress.value.percentage / 100.0)
end)
```

The callback still fires. The difference: the request is now **queryable**.

---

## Non-Goals (Explicitly Deferred)

### 🚫 LSP protocol changes
- We do NOT modify the LSP wire protocol
- We do NOT change how `$/progress` or `$/cancelRequest` work
- The protocol is unchanged; only Neovim's internal plumbing changes

### 🚫 Forced synchronous semantics
- Requests remain asynchronous
- We do NOT block the event loop waiting for LSP responses
- `op:result()` returns result if available, nil otherwise (non-blocking)

### 🚫 Permission/policy layer
- We do NOT decide which requests can be canceled
- We do NOT enforce timeout policies
- We do NOT throttle concurrent LSP requests
- **Policy is the caller's responsibility** (LSP client code decides what to cancel)

### 🚫 UI mandate
- We do NOT build a status bar display
- We do NOT mandate how progress is shown
- Plugins can read `vim.op.list()` and display as they wish
- Pure pull-based; UI owns the visualization

### 🚫 New LSP events/hooks
- We do NOT add `LspRequestCreated`, `LspRequestProgress` events
- Observers use `vim.op.list()` to query state
- Event architecture deferred to a future PR

---

## Follow-Up Integration Phases (Not This PR)

### Phase 1: LSP + Ops (follow-up #1)
- Add operation creation to `vim.lsp.rpc.notify()` and `vim.lsp.rpc.request()`
- Each request-response pair owns an operation
- Progress handlers update operation progress
- **Outcome**: LSP operations visible in vim.op.list()

### Phase 2: Cancellation UX (follow-up #2)
- User-facing command: `:LspRequestCancel` or `<C-c>` over operation
- Keybind to cancel request under cursor
- **Outcome**: Deterministic cancellation with feedback

### Phase 3: UI Integration (follow-up #3, deferred to plugins)
- Plugin reads `vim.op.list()` and renders statusline
- Example: `[LSP: definition...  50%]`
- **Outcome**: Visibility into async work

---

## Why This Invariant Works

1. **Minimal**: One operation per request. No aggregation, no grouping.
2. **Deterministic**: Operation state is queryable at any time; no surprise timing.
3. **Extensible**: LSP, jobs, builtin operations (make, grep) all use same mechanism.
4. **Conservative**: No new LSP protocol. No forced behavior. Pure registry addition.
5. **Debuggable**: Operators see their requests in `vim.op.list()` with full state.

---

## Comparison: Before and After

| Scenario | Before | After |
|----------|--------|-------|
| "Is LSP initializing?" | Guess based on events | `#vim.op.list() > 0` |
| "Cancel the hover request" | Hope protocol handles it | `op:cancel()` (deterministic) |
| "What is LSP doing?" | Check buffer output, pray | `vim.op.list()` snapshot |
| "Did this request timeout?" | No visibility | `op:state()`, `op:error()` |
| "Integrate with statusline" | Parse events (fragile) | Read `vim.op.list()` (stable API) |

---

## Implementation Readiness

The **operations substrate** is complete and testable:
- ✅ Core primitive (ops.c/ops.h) is merged
- ✅ Lua bindings (vim.op.*) available
- ✅ 28 unit tests covering contract

This document maps how LSP will use it. Implementation is straightforward:

1. Modify `vim.lsp.rpc.request()` to wrap calls in `vim.op`
2. Update progress handlers to call `op:progress()`
3. Update result/error handlers to call `op:finish()` / `op:fail()`
4. Wire cancellation to `op:cancel()`

No architectural changes. No protocol changes. Pure client‑side discipline.

---

## Conclusion

LSP cancellation, progress visibility, and request observability are not deep architectural problems—they're **registry visibility problems**. The operations primitive solves all three with a single invariant.

This design document serves as a bridge: it shows maintainers why the primitive exists (not just "nice to have," but "necessary for LSP correctness") and provides the mechanical mapping for follow-up integration work.
