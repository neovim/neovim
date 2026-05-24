# yanvim — Task Checklist

Ordered implementation checklist. Each task is self-contained and testable before moving to the next.

Work inside `./Yet-another-neovim/`.

---

## Phase 1 — Option infrastructure

### Task 1.1 — Declare `paradigm` option
**File:** `src/nvim/options.lua`

Add the `paradigm` option entry as specified in `REFACTOR.md`.
After adding, check if a code generation step is needed (look for `scripts/gen_options.py` or similar).

**Done when:** `vim.opt.paradigm` is recognized at runtime without error.

---

### Task 1.2 — Expose `p_paradigm` and `HELIX_MODE()` macro
**File:** `src/nvim/option.c` (and a suitable header, e.g. `src/nvim/option_defs.h`)

- Add `p_paradigm` global int.
- Add `PARADIGM_VIM` / `PARADIGM_HELIX` constants.
- Add `HELIX_MODE()` macro.
- Add validation: error on values other than `'vim'` / `'helix'`.

**Done when:** setting `vim.opt.paradigm = 'helix'` sets `p_paradigm = PARADIGM_HELIX` internally.

---

## Phase 2 — Helix state

### Task 2.1 — Define `HelixSelection` and `HelixState`
**File:** `src/nvim/state.c` (and `src/nvim/state.h`)

Add structs as specified in `REFACTOR.md`.
Add a global `current_helix_sel` of type `HelixSelection`.

**Done when:** structs compile cleanly.

---

### Task 2.2 — Implement helix state functions
**File:** `src/nvim/state.c`

Implement:
- `helix_selection_init(void)`
- `helix_selection_collapse(void)`
- `helix_selection_extend(pos_T new_head)`
- `helix_is_active(void)`

**Done when:** functions compile and unit tests cover init/collapse/extend transitions.

---

### Task 2.3 — Initialize helix state on mode entry
**File:** `src/nvim/state.c` or wherever Normal mode is entered

Call `helix_selection_init()` when entering Normal mode and `HELIX_MODE()` is true.

**Done when:** helix selection is initialized to cursor position whenever Normal mode is entered with `paradigm = 'helix'`.

---

## Phase 3 — Motion interception

### Task 3.1 — Patch `h` and `l` (`nv_left`, `nv_right`)
**File:** `src/nvim/normal.c`

Add helix branch: compute destination, call `helix_selection_extend`, return early.

**Done when:** with `paradigm = 'helix'`, pressing `l` extends selection rightward instead of moving cursor.

---

### Task 3.2 — Patch `j` and `k` (`nv_up`, `nv_down`)
**File:** `src/nvim/normal.c`

Same pattern as 3.1 for vertical motions.

**Done when:** `j` extends selection downward.

---

### Task 3.3 — Patch `w`, `b`, `e` family (`nv_wordcmd`)
**File:** `src/nvim/normal.c`

**Done when:** `w` selects to next word boundary.

---

### Task 3.4 — Patch `$`, `0`, `^`
**File:** `src/nvim/normal.c`

**Done when:** `$` extends selection to end of line.

---

### Task 3.5 — Patch `gg`, `G`
**File:** `src/nvim/normal.c`

**Done when:** `G` extends selection to last line.

---

### Task 3.6 — Patch `{` and `}` (paragraph motions)
**File:** `src/nvim/normal.c`

**Done when:** `}` extends selection to next paragraph.

---

### Task 3.7 — Patch `/`, `?`, `n`, `N` (search motions)
**File:** `src/nvim/normal.c`

**Done when:** `n` extends selection to next search match.

---

## Phase 4 — Verb interception

### Task 4.1 — Implement `helix_apply_operator`
**File:** `src/nvim/ops.c`

Implement dispatcher that translates helix selection to `oparg_T` and calls existing operators.

**Done when:** function compiles and correctly maps anchor/head to oparg start/end.

---

### Task 4.2 — Patch `nv_operator` to use helix selection
**File:** `src/nvim/normal.c`

When `helix_is_active()` and `has_selection`, call `helix_apply_operator` instead of entering operator-pending.

**Done when:** `w d` deletes the selected word in helix paradigm.

---

### Task 4.3 — Handle `c` (change) correctly
**File:** `src/nvim/normal.c` and `src/nvim/ops.c`

After `helix_apply_operator` for change: delete selection, collapse, enter Insert mode.

**Done when:** `w c` deletes selection and enters Insert mode.

---

### Task 4.4 — Handle `y` (yank) correctly
**File:** `src/nvim/ops.c`

After yank, collapse selection (do not delete). Cursor stays at anchor.

**Done when:** `w y` yanks selection without deleting it.

---

## Phase 5 — Escape behavior

### Task 5.1 — Patch `<Esc>` in helix mode
**File:** `src/nvim/normal.c`

When `helix_is_active()` and `has_selection`, `<Esc>` calls `helix_selection_collapse()` instead of the default Esc behavior.

**Done when:** pressing `<Esc>` after a selection collapses to 1 char without executing anything.

---

## Phase 6 — Rendering

### Task 6.1 — Add `HelixCursor` and `HelixSelection` highlight groups
**File:** `runtime/lua/vim/` (highlight defaults)

Link to `Cursor` and `Visual` as defaults.

**Done when:** groups exist and are overridable by colorschemes.

---

### Task 6.2 — Render helix selection in TUI
**File:** `src/nvim/tui/tui.c` or `src/nvim/screen.c`

When `helix_is_active()`, apply `HelixSelection` highlight from anchor to head. Apply `HelixCursor` for 1-char resting state.

**Done when:** selection is visually visible in the terminal without triggering Visual mode highlights.

---

## Phase 7 — Validation

### Task 7.1 — Smoke test: basic noun-verb flow
Manual test:
1. Set `vim.opt.paradigm = 'helix'`
2. Open a file
3. Press `w` → confirm selection appears
4. Press `d` → confirm word is deleted
5. Confirm cursor is at correct position with 1-char selection

---

### Task 7.2 — Plugin compatibility test
Manual test:
1. Open Telescope (`:Telescope find_files`)
2. Confirm it opens and functions normally
3. Confirm `mode()` returns `'n'` during helix paradigm

---

### Task 7.3 — Paradigm switching test
Manual test:
1. Start with `paradigm = 'vim'` → confirm classic behavior
2. Switch to `paradigm = 'helix'` → confirm selection-first behavior
3. Switch back → confirm classic behavior restored

---

## Notes for Claude Code

- Always check `HELIX_MODE()` before any behavioral change — never alter behavior unconditionally.
- The existing operator and motion implementations are correct and battle-tested. Reuse them; do not rewrite them.
- When in doubt about a motion handler's name, search for the key character in `normal.c`'s command table (`nv_cmds[]`).
- Build after each phase: `cmake --build build/`.
