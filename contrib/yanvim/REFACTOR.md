# yanvim — Refactoring Guide

This document describes every file that needs to be touched, what currently lives there, and what needs to change.

---

## `src/nvim/options.lua`

### What lives here
Declarative definitions of all Neovim options. Each entry defines name, type, default, valid values, and documentation.

### What to add
A new string option `paradigm`:

```lua
{
  name = 'paradigm',
  type = 'string',
  default = 'vim',
  values = { 'vim', 'helix' },
  scope = 'global',
  desc = [[
    Sets the editing paradigm for Normal mode.
    'vim'   Traditional operator-first (verb-noun) editing. Default.
    'helix' Selection-first (noun-verb) editing, inspired by Helix.
            Every motion creates a selection. Verbs operate on the
            active selection. mode() still returns 'n' for plugin
            compatibility.
  ]],
}
```

### Notes
- After adding, run the code generation step so `option.c` picks up the new option automatically (Neovim generates parts of option.c from options.lua).

---

## `src/nvim/option.c`

### What lives here
Runtime option processing, validation, and the `p_*` global variables that C code uses to read option values.

### What to add
- A global `p_paradigm` variable (analogous to `p_bg` for `background`, etc.).
- A `PARADIGM_HELIX` constant for safe comparison:

```c
// option.c or a new header
#define PARADIGM_VIM   0
#define PARADIGM_HELIX 1

extern int p_paradigm;  // 0 = vim, 1 = helix
```

- Validation logic: reject values other than `'vim'` and `'helix'`.
- A helper macro for use across the codebase:

```c
#define HELIX_MODE() (p_paradigm == PARADIGM_HELIX)
```

---

## `src/nvim/state.c`

### What lives here
The core state machine for Neovim's modal editing. Defines how modes are entered, exited, and how input is dispatched to handlers.

### What to add
A `HelixSelection` struct and a `HelixState` that wraps the existing `NormalState`:

```c
typedef struct {
  pos_T anchor;        // selection start, fixed until verb or Esc
  pos_T head;          // selection end, moves with motions
  bool  has_selection; // true when selection spans > 1 char
} HelixSelection;

typedef struct {
  VimState     state;
  HelixSelection sel;
} HelixState;
```

Functions to add:
- `helix_selection_init(void)` — initializes selection to cursor position (1-char resting state).
- `helix_selection_collapse(void)` — collapses selection to 1 char at head.
- `helix_selection_extend(pos_T new_head)` — moves head to new_head.
- `helix_is_active(void)` — returns true if `HELIX_MODE()` and we are in Normal mode.

### Notes
- `HelixState` does not replace `NormalState`. It is a parallel structure activated only when `paradigm = 'helix'`.
- The existing Normal mode state machine is untouched when `paradigm = 'vim'`.

---

## `src/nvim/normal.c`

### What lives here
The largest file in the codebase. Handles all Normal mode input: every motion, every command, operator-pending logic.

### What to change
Every motion handler needs a helix branch. The pattern is consistent across all of them:

```c
// Example: nv_wordcmd (handles 'w', 'W', 'e', 'E', 'b', 'B')
static void nv_wordcmd(cmdarg_T *cap)
{
  if (helix_is_active()) {
    pos_T new_pos = /* compute destination as usual */;
    helix_selection_extend(new_pos);
    return;  // do not move cursor, do not enter operator-pending
  }
  // ... original implementation unchanged below
}
```

Motion handlers to patch (non-exhaustive):
- `nv_wordcmd` — `w`, `W`, `b`, `B`, `e`, `E`
- `nv_left`, `nv_right` — `h`, `l`
- `nv_up`, `nv_down` — `k`, `j`
- `nv_gotofile` — `gg`, `G`
- `nv_dollar` — `$`
- `nv_zero` — `0`
- `nv_search` — `/`, `?`, `n`, `N`
- `nv_findpar` — `{`, `}`

### Key insight
The motion destination computation already exists in each handler — that logic does not change. What changes is: instead of moving the cursor to the destination, we call `helix_selection_extend(destination)`.

### Verbs in Normal mode
Verb handlers (`nv_operator`) must check for an active helix selection and use it instead of entering operator-pending:

```c
static void nv_operator(cmdarg_T *cap)
{
  if (helix_is_active() && current_helix_sel.has_selection) {
    // apply operator to helix selection
    helix_apply_operator(cap->cmdchar);
    helix_selection_collapse();
    return;
  }
  // ... original operator-pending logic unchanged
}
```

---

## `src/nvim/ops.c`

### What lives here
Implementation of all operators: `op_delete`, `op_change`, `op_yank`, `op_shift`, etc.

### What to add
A dispatcher `helix_apply_operator(int op)` that:
1. Translates the helix selection (`anchor` → `head`) into the `oparg_T` format the existing operators expect.
2. Calls the existing operator function.
3. After return, calls `helix_selection_collapse()`.

```c
void helix_apply_operator(int op_char)
{
  oparg_T oap;
  clear_oparg(&oap);
  oap.start = current_helix_sel.anchor;
  oap.end   = current_helix_sel.head;
  oap.op_type = get_op_type(op_char, NUL);

  // reuse existing operator implementations
  op_delete(&oap);  // or op_yank, op_change, etc. based on op_type
}
```

### Notes
- This approach maximizes reuse of existing operator logic.
- Edge cases: `c` (change) must also enter Insert mode after collapsing, same as classic behavior.

---

## `src/nvim/tui/tui.c` and `src/nvim/screen.c` (or `grid.c`)

### What lives here
Terminal UI rendering, cursor drawing, highlight application.

### What to change
When `helix_is_active()`:
- The 1-char resting selection renders with `HelixCursor` highlight.
- A selection > 1 char renders with `HelixSelection` highlight.
- This must NOT trigger Visual mode highlights (`Visual` highlight group) — it uses its own groups.

### Approach
Add a helix rendering pass after the normal cursor rendering, conditioned on `helix_is_active()`. Apply highlights from `anchor` to `head` using the appropriate group.

---

## `runtime/lua/vim/` (highlight group defaults)

### What to add
Default highlight definitions for `HelixCursor` and `HelixSelection`, so they work out of the box with any colorscheme:

```lua
-- In the appropriate highlight initialization file
vim.api.nvim_set_hl(0, 'HelixCursor',    { link = 'Cursor' })
vim.api.nvim_set_hl(0, 'HelixSelection', { link = 'Visual' })
```

These are intentionally linked to existing groups as defaults, so colorschemes that don't know about yanvim still look reasonable.
