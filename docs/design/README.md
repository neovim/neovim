# Neovim Design Documents

This folder contains architectural and design documentation for Neovim core substrates and integrations.

## Documents

### [ARCHITECTURE.md](ARCHITECTURE.md)

Comprehensive architectural foundation for deterministic verification of filesystem mutations.

**Scope:** VFS abstraction, atomic write semantics, replay infrastructure, verification runtime  
**Audience:** Core maintainers, substrate architects  
**Status:** Reference implementation; not all layers are active in production

**Key sections:**
- Purpose and non-goals (why this exists independently of agent work)
- Four substrate layers (VFS → atomic writes → replay → verification)
- Threat model and failure modes
- Implications and appropriate use cases

### [lsp-operations.md](lsp-operations.md)

Design sketch for LSP integration using the cancelable operations primitive.

**Scope:** Mapping LSP request lifecycle (progress, cancellation, observability) to `vim.op`  
**Audience:** LSP client maintainers, API reviewers  
**Status:** Design-only; no implementation; intended as follow-up to vim.op substrate PR

**Key sections:**
- Problem statement (progress visibility, cancellation opacity, request introspection)
- Single invariant (every LSP request owns exactly one operation)
- Concept mapping table (LSP concepts → vim.op)
- Lifecycle example and non-goals
- Phased integration roadmap

### [buffer-event-ordering.md](buffer-event-ordering.md)

Problem statement: Buffer events lack shared revision semantics.

**Scope:** Why buffer event ordering is currently unsound; concrete failure modes  
**Audience:** Core maintainers, plugin developers, async subsystems  
**Status:** Problem statement only; no solution proposed; foundation for future work

**Key sections:**
- Problem (events don't define ordering across LSP, plugins, formatters)
- Concrete failure modes (diagnostics racing, plugin coordination, code actions, undo)
- What's not guaranteed (event binding, causality, version information)
- Missing invariant (no monotonic queryable buffer revision)
- Explicit non-goals (no CRDT, no undo redesign, no performance promises)

## Reading Order

1. **For reviewers of `vim.op` primitive:** Start with lsp-operations.md to understand why the substrate exists.
2. **For infrastructure planning:** Read in order: vim.op (lifecycle) → LSP (integration justification) → buffer ordering (next structural gap)
3. **For architecture deep-dive:** Read ARCHITECTURE.md for the broader context on verification and determinism.
4. **For future design work:** Use buffer-event-ordering.md as foundation for proposing revision semantics.

## Design Discipline

These documents follow a consistent structure:

- **Problem Statement:** Concrete pain points, factual framing
- **Invariant:** Single core claim, non-negotiable
- **Scope Definition:** What's in, what's out, explicit non-goals
- **Examples:** Concrete walkthroughs of the invariant in action
- **Integration Path:** Phased plan for follow-up work

This discipline ensures:
- Clear justification for each design choice
- Reviewers know exactly what is and isn't being proposed
- Follow-up work has a stable foundation
