# yanvim — Helix Paradigm Specification

## The option

```lua
vim.opt.paradigm = 'vim'   -- default, classic Neovim behavior
vim.opt.paradigm = 'helix' -- selection-first, noun-verb
```

- Type: string
- Scope: global
- Default: `'vim'`
- Valid values: `'vim'`, `'helix'`

---

## Behavior when `paradigm = 'helix'`

### Resting state

- The cursor always represents an active selection of 1 character.
- This is the minimum selection — equivalent to the cursor position in classic Vim.
- Visually distinct from a normal cursor (different highlight group: `HelixCursor`).

### Motions

All motions — including `h`, `j`, `k`, `l`, `w`, `b`, `e`, `$`, `0`, `gg`, `G`, and all others — **create or extend a selection** from the current anchor point.

```
cursor at "hello world"
           ^
w  →  selects "hello " (anchor stays, head moves to next word)
w  →  extends to "hello world" (head moves again)
```

No motion moves the cursor without creating a selection. Navigation and selection are the same action.

### Verbs

Verbs (`d`, `c`, `y`, `>`, `<`, etc.) operate on the active selection.

```
w     →  selects next word
d     →  deletes selection
      →  cursor collapses to 1 char at resulting position
      →  mode remains active (does not return to classic Normal)
```

After a verb executes:
1. The operation is applied to the full selection.
2. The selection collapses to 1 character at the resulting cursor position.
3. The paradigm state remains active.

### Escape

`<Esc>` collapses the selection to 1 character (the head position) without executing any verb. This is the equivalent of "cancel selection, stay in mode".

---

## What does NOT change

- `mode()` returns `'n'` — plugins see Normal mode.
- Insert mode (`i`, `a`, `o`, etc.) works exactly as in classic Neovim.
- Visual mode (`v`, `V`, `<C-v>`) is still accessible and works as before.
- Command mode (`:`) works as before.
- The classic paradigm (`vim`) is completely unaffected.

---

## Internal selection model

The helix selection is **not** the Neovim Visual mode selection. It is a separate internal state:

```c
typedef struct {
  pos_T anchor;       // start of selection (fixed until verb or Esc)
  pos_T head;         // end of selection (moves with motions)
  bool  has_selection; // true if selection > 1 char
} HelixSelection;
```

This struct lives in `HelixState` and is never exposed as Visual mode to the outside world.

---

## Highlight groups

| Group | Purpose |
|---|---|
| `HelixCursor` | Cursor in resting state (1-char selection) |
| `HelixSelection` | Active selection > 1 char |

Both should be defined with sensible defaults and be overridable by colorschemes.
